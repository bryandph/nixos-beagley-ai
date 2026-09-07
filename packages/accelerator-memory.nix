{
  "main-r5fss-memory-region@a2100000" = {
    reg = ["0x0" "0xa2100000" "0x0" "0x01f00000"];
    label = "vision_apps_main_r5fss0_core0_memory_region";
  };
  "c7x-dma-memory@a3000000" = {
    reg = ["0x0" "0xad000000" "0x0" "0x00100000"];
    label = "vision_apps_c71_0_dma_memory_region";
  };
  "c7x-memory@a3100000" = {
    reg = ["0x0" "0xad100000" "0x0" "0x03f00000"];
    label = "vision_apps_c71_0_memory_region";
  };
  "c7x-dma-memory@a4000000" = {
    reg = ["0x0" "0xb1000000" "0x0" "0x00100000"];
    label = "vision_apps_c71_1_dma_memory_region";
  };
  "c7x-memory@a4100000" = {
    reg = ["0x0" "0xb1100000" "0x0" "0x03f00000"];
    label = "vision_apps_c71_1_memory_region";
  };
  "ipc-memories@a5000000" = {
    reg = ["0x0" "0xa5000000" "0x0" "0x01000000"];
    label = "vision_apps_rtos_ipc_memory_region";
  };
  "vision-apps-dma-memory@a6000000" = {
    reg = ["0x0" "0xa6000000" "0x0" "0x01c40000"];
    label = "vision_apps_memory_region";
  };
  "vision-apps-core-heap-memory-lo@b5000000" = {
    reg = ["0x0" "0xb5000000" "0x0" "0x02c00000"];
    label = "vision_apps_core_heaps_lo";
  };
  "vision-apps-r5f-virtual-eth-queues@b8000000" = {
    reg = ["0x0" "0xb8000000" "0x0" "0x00200000"];
    label = "vision_apps_main_r5fss0_core0_shared_memory_queue_region";
  };
  "vision-apps-r5f-virtual-eth-buffers@b8200000" = {
    reg = ["0x0" "0xb8200000" "0x0" "0x00e00000"];
    label = "vision_apps_main_r5fss0_core0_shared_memory_bufpool_region";
  };
  "c7x-ddr-heaps-hi@880000000" = {
    reg = ["0x8" "0x80000000" "0x0" "0x20000000"];
    label = "c7x_ddr_heaps_hi";
  };
  "vision_apps_shared-memories" = {
    reg = ["0x8" "0xa0000000" "0x0" "0x20000000"];
    label = "vision_apps_shared_region";
    compatible = "dma-heap-carveout";
    noMap = false;
  };
  "linux-cma-buffers@8c0000000" = {
    reg = ["0x8" "0xc0000000" "0x0" "0x38000000"];
    noMap = false;
    cma = true;
  };
}
