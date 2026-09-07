"""Compile and exercise the patched upstream C functions with failed IPC mocks."""
import os
from pathlib import Path
import re
import subprocess
import tempfile


def function(path, name):
    source = Path(path).read_text()
    start = re.search(r"(?:static )?int32_t " + name + r"\([^;]*?\)\s*\{", source).start()
    opening = source.index("{", start)
    level = 1
    end = opening + 1
    while level:
        level += (source[end] == "{") - (source[end] == "}")
        end += 1
    return source[start:end]


common_path = "vision_apps/platform/j722s/linux/app_init.c"
common = r'''
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <pthread.h>
#define ENABLE_IPC
#define APP_LOG_MEM_ADDR 0
#define APP_FILEIO_MEM_ADDR 0
#define TIOVX_OBJ_DESC_MEM_ADDR 0
#define TIOVX_OBJ_DESC_MEM_SIZE 0
#define TIOVX_LOG_RT_MEM_ADDR 0
#define TIOVX_LOG_RT_MEM_SIZE 0
#define APP_IPC_CPU_MPU1_0 0
#define APP_LOG_MAX_CPU_NAME 16
typedef void app_log_shared_mem_t;
typedef void app_fileio_shared_mem_t;
typedef struct {void *shared_mem; int self_cpu_index; char self_cpu_name[16];} app_log_init_prm_t;
typedef app_log_init_prm_t app_fileio_init_prm_t;
typedef struct {int enabled_cpu_id_list[4], num_cpus, self_cpu_id;
  void *tiovx_obj_desc_mem, *tiovx_log_rt_mem; int tiovx_obj_desc_mem_size, tiovx_log_rt_mem_size;} app_ipc_init_prm_t;
typedef int app_remote_service_init_prms_t;
static struct {int cpu;} core_config[] = {{1}, {2}};
static int num_cpus = 2, fail_ipc = 1, ipc_calls, service_calls, ipc_cleanup, mem_cleanup, file_cleanup, log_cleanup, timer_cleanup;
static pthread_mutex_t gMutex = PTHREAD_MUTEX_INITIALIZER;
static uint32_t gInitCount;
static int openvx_calls;
static void tivxInit(void) {openvx_calls++;}
static void tivxHostInit(void) {openvx_calls++;}
static int32_t appCommonInitLocal(void), appCommonDeInitLocal(void);
#define OK(name) static int name(void) {return 0;}
OK(appLogGlobalTimeInit) OK(appPerfStatsInit) OK(appPerfStatsRemoteServiceInit)
#define DEFAULT(name, type) static void name(type *p) {(void)p;}
DEFAULT(appLogInitPrmSetDefault, app_log_init_prm_t)
DEFAULT(appFileIOInitPrmSetDefault, app_fileio_init_prm_t)
DEFAULT(appIpcInitPrmSetDefault, app_ipc_init_prm_t)
DEFAULT(appRemoteServiceInitSetDefault, app_remote_service_init_prms_t)
static int appLogWrInit(app_log_init_prm_t *p) {(void)p; return 0;}
static int appFileIOWrInit(app_fileio_init_prm_t *p) {(void)p; return 0;}
static int appMemInit(void *p) {(void)p; return 0;}
static int appIpcInit(app_ipc_init_prm_t *p) {(void)p; ipc_calls++; return fail_ipc ? -7 : 0;}
static int appRemoteServiceInit(app_remote_service_init_prms_t *p) {(void)p; service_calls++; return 0;}
static void appLogPrintGtcFreq(void) {}
static void appRemoteServiceDeInit(void) {}
static void appIpcDeInit(void) {ipc_cleanup++;}
static void appMemDeInit(void) {mem_cleanup++;}
static void appFileIOWrDeInit(void) {file_cleanup++;}
static void appLogWrDeInit(void) {log_cleanup++;}
static int appLogGlobalTimeDeInit(void) {timer_cleanup++; return 0;}
'''
common += "\n".join(function(common_path, name) for name in ["appCommonInit", "appCommonDeInit", "appCommonInitLocal", "appCommonDeInitLocal"])
common += function("vision_apps/utils/app_init/src/app_init.c", "appInit")
common += r'''
int main(void) {
  assert(appInit() == -7);
  assert(openvx_calls == 0);
  assert(gInitCount == 0 && ipc_calls == 1 && service_calls == 0);
  assert(ipc_cleanup == 1 && mem_cleanup == 1 && file_cleanup == 1 && log_cleanup == 1 && timer_cleanup == 1);
  assert(appCommonDeInit() == -1);
  fail_ipc = 0;
  assert(appCommonInit() == 0 && gInitCount == 1 && ipc_calls == 2 && service_calls == 1);
  assert(appCommonInit() == 0 && gInitCount == 2 && ipc_calls == 2);
  assert(appCommonDeInit() == 0 && ipc_cleanup == 1);
  assert(appCommonDeInit() == 0 && gInitCount == 0 && ipc_cleanup == 2);
  return 0;
}
'''
partial = r'''
#include <assert.h>
#include <stdint.h>
#include <stddef.h>
typedef struct {int unblockfd, task; void *rcdev[3];} app_ipc_obj_t;
static app_ipc_obj_t g_app_ipc_obj;
static int joins, closes, deletes, exits, wakes;
#define APP_IPC_CPU_MAX 3
#define appLogPrintf(...) ((void)0)
static int appIpcIsCpuEnabled(int i) {(void)i; return 1;}
static int appIpcGetSelfCpuId(void) {return 0;}
static void appIpcUnblockRpmsgTask(app_ipc_obj_t *obj) {(void)obj; wakes++;}
static int pthread_join(int task, void **status) {(void)task; (void)status; joins++; return 0;}
static int close(int fd) {assert(fd >= 0); closes++; return 0;}
static int appIpcDeleteCh(void *channel) {assert(channel != NULL); deletes++; return 0;}
static void rpmsg_char_exit(void) {exits++;}
'''
partial += function("app_utils/utils/ipc/src/app_ipc_linux_rpmsg_char.c", "appIpcDeleteRpmsgRxTask")
partial += function("app_utils/utils/ipc/src/app_ipc_linux.c", "appIpcDeInit")
partial += r'''
int main(void) {
  g_app_ipc_obj.unblockfd = -1;
  g_app_ipc_obj.rcdev[1] = NULL;
  g_app_ipc_obj.rcdev[2] = (void *)1;
  assert(appIpcDeInit() == 0);
  assert(joins == 0 && closes == 0 && wakes == 0 && deletes == 1 && exits == 1);
  g_app_ipc_obj.unblockfd = 9;
  assert(appIpcDeleteRpmsgRxTask(&g_app_ipc_obj) == 0);
  assert(joins == 1 && closes == 1 && wakes == 1 && g_app_ipc_obj.unblockfd == -1);
  assert(appIpcDeleteRpmsgRxTask(&g_app_ipc_obj) == 0 && joins == 1);
  return 0;
}
'''
with tempfile.TemporaryDirectory() as directory:
    for name, source in [("init-failure-retry", common), ("partial-ipc-cleanup", partial)]:
        path = Path(directory) / name
        path.with_suffix(".c").write_text(source)
        subprocess.run([os.environ["BUILD_CC"], "-pthread", str(path.with_suffix(".c")), "-o", str(path)], check=True)
        subprocess.run([str(path)], check=True)
print("Patched upstream IPC failure/retry and partial cleanup regression passed")
