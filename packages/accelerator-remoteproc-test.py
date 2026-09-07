import importlib.util
import json
import pathlib
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("guard", sys.argv.pop(1))
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)


class LifecycleGuard(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = pathlib.Path(self.temp.name)
        guard.DT = self.root / "dt"
        guard.REMOTE = self.root / "remoteproc"
        guard.DT.mkdir()
        guard.REMOTE.mkdir()
        (guard.DT / "reserved-memory").mkdir()

    def core(self, name, index, state="offline", firmware="test-fw"):
        path = f"/bus@f0000/dsp@{name}"
        node = guard.DT / path.lstrip("/")
        node.mkdir(parents=True, exist_ok=True)
        (node / "memory-region").write_bytes(struct.pack(">I", index + 1))
        memory = guard.DT / "reserved-memory" / name
        memory.mkdir()
        (memory / "phandle").write_bytes(struct.pack(">I", index + 1))
        (memory / "reg").write_bytes(struct.pack(">4I", 0, 0xA0000000 + index * 0x100000, 0, 0x100000))
        (memory / "no-map").touch()
        remote = guard.REMOTE / f"remoteproc{index}"
        (remote / "device").mkdir(parents=True)
        (remote / "device/of_node").symlink_to(node)
        (remote / "state").write_text(state)
        (remote / "firmware").write_text(firmware)
        expected = {"path": path, "firmware": "test-fw", "regions": [[hex(0xA0000000 + index * 0x100000), "0x100000"]]}
        return remote, expected

    def test_device_manager_is_never_identified(self):
        with self.assertRaisesRegex(RuntimeError, "Device Manager"):
            guard.identify({"path": "/bus@f0000/r5f@78000000"})

    def test_live_memory_mismatch_blocks_identity(self):
        remote, expected = self.core("7e000000", 0)
        expected["regions"][0][1] = "0x200000"
        with self.assertRaisesRegex(RuntimeError, "ABI mismatch"):
            guard.identify(expected)
        self.assertEqual((remote / "state").read_text(), "offline")

    def test_later_foreign_core_prevents_all_writes(self):
        _, first = self.core("7e000000", 0)
        _, second = self.core("7e200000", 1, "running", "foreign-fw")
        contract = self.root / "contract.json"
        contract.write_text(json.dumps({"cores": {"first": first, "second": second}, "memory": {}}))
        with tempfile.TemporaryFile() as lock, patch("builtins.open", return_value=lock), patch.object(guard, "transition") as transition, patch.object(sys, "argv", ["guard", str(contract), "start"]):
            with self.assertRaisesRegex(RuntimeError, "different owner"):
                guard.main()
            transition.assert_not_called()

    def test_repeated_desired_state_is_noop(self):
        remote, expected = self.core("7e000000", 0, "running")
        guard.transition(remote, expected, "start")
        self.assertEqual((remote / "state").read_text(), "running")
        (remote / "state").write_text("offline")
        guard.transition(remote, expected, "stop")
        self.assertEqual((remote / "state").read_text(), "offline")

    def test_attached_processor_cannot_be_stopped(self):
        remote, expected = self.core("7e000000", 0, "attached")
        with self.assertRaisesRegex(RuntimeError, "Refusing transition"):
            guard.transition(remote, expected, "stop")
        self.assertEqual((remote / "state").read_text(), "attached")

    def test_disabled_shared_reservation_is_rejected(self):
        self.core("7e000000", 0)
        (guard.DT / "reserved-memory/7e000000/status").write_bytes(b"disabled\0")
        with self.assertRaisesRegex(RuntimeError, "reservation is disabled"):
            guard.validate_memory({"7e000000": {"reg": ["0", "0xa0000000", "0", "0x100000"]}})

    def test_disabled_ipc_reservation_blocks_identity(self):
        remote, expected = self.core("7e000000", 0)
        (guard.DT / "reserved-memory/7e000000/status").write_bytes(b"disabled\0")
        with self.assertRaisesRegex(RuntimeError, "reservation is disabled"):
            guard.identify(expected)
        self.assertEqual((remote / "state").read_text(), "offline")

    def test_vision_stop_refused_before_any_sysfs_access(self):
        contract = self.root / "contract.json"
        contract.write_text(json.dumps({"cores": {}, "memory": {}, "allowStop": False}))
        with patch.object(guard, "identify") as identify, patch.object(guard, "transition") as transition, patch.object(sys, "argv", ["guard", str(contract), "stop"]):
            with self.assertRaisesRegex(RuntimeError, "does not acknowledge shutdown"):
                guard.main()
            identify.assert_not_called()
            transition.assert_not_called()


unittest.main()
