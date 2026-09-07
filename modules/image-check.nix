{
  config,
  lib,
  ...
}: {
  perSystem = {
    pkgs,
    system,
    ...
  }:
    lib.mkIf (system == "aarch64-linux") {
      checks.sd-image-layout = let
        image = config.flake.nixosConfigurations.beagley-ai.config.system.build.beagleyAiSdImage;
      in
        pkgs.runCommand "beagley-ai-sd-image-layout" {
          nativeBuildInputs = [pkgs.zstd pkgs.util-linux pkgs.mtools pkgs.jq pkgs.python3 pkgs.dtc];
        } ''
          zstd -d -c ${image}/sd-image/*.img.zst > image.img
          sfdisk --json image.img > layout.json
          test "$(jq '.partitiontable.partitions | length' layout.json)" -eq 2
          test "$(jq -r '.partitiontable.partitions[0].type' layout.json)" = e
          test "$(jq -r '.partitiontable.partitions[0].bootable' layout.json)" = true
          test "$(jq -r '.partitiontable.partitions[1].bootable // false' layout.json)" = false
          offset=$(( $(jq '.partitiontable.partitions[0].start' layout.json) * 512 ))
          test "$offset" -eq 8388608
          for file in tiboot3.bin tispl.bin u-boot.img; do
            mcopy -i image.img@@"$offset" "::/$file" "$file"
            test -s "$file"
          done
          mtype -i image.img@@"$offset" ::/extlinux/extlinux.conf > extlinux.conf
          grep -q 'console=ttyS2,115200n8' extlinux.conf
          rootOffset=$(( $(jq '.partitiontable.partitions[1].start' layout.json) * 512 ))
          test "$(blkid -p -O "$rootOffset" -s LABEL -o value image.img)" = BEAGLEY_ROOT
          # NixOS embeds root filesystem policy in the initrd; extlinux need not
          # repeat root= when it selects that matching generation's initrd.
          cat extlinux.conf
          python3 - "$offset" <<'PY'
          import pathlib, posixpath, re, struct, subprocess, sys
          import json
          partition = json.loads(pathlib.Path('layout.json').read_text())['partitiontable']['partitions'][0]
          with open('image.img', 'rb') as disk:
              disk.seek(int(sys.argv[1]))
              bpb = disk.read(512)
          assert bpb[510:512] == bytes([0x55, 0xaa]), 'invalid FAT boot signature'
          assert struct.unpack_from('<H', bpb, 11)[0] == 512, 'unexpected FAT sector size'
          sectors = struct.unpack_from('<H', bpb, 19)[0] or struct.unpack_from('<I', bpb, 32)[0]
          assert sectors == partition['size'], 'FAT does not fill partition (reference recipe uses mkfs.fat -a)'
          entries = re.split(r'(?m)^LABEL ', pathlib.Path('extlinux.conf').read_text())[1:]
          assert entries, 'no boot entries'
          for entry in entries:
              fields = dict(line.strip().split(None, 1) for line in entry.splitlines()[1:] if line.strip() and len(line.strip().split(None, 1)) == 2)
              extracted = {}
              for key in ('LINUX', 'INITRD', 'FDT'):
                  value = fields[key]
                  resolved = str(pathlib.PurePosixPath('/extlinux') / value)
                  # mtools resolves ../ relative to the extlinux directory.
                  extracted[key] = subprocess.check_output(['mtype', '-i', 'image.img@@'+sys.argv[1], '::'+posixpath.normpath(resolved)])
              dtb = pathlib.Path('selected.dtb')
              dtb.write_bytes(extracted['FDT'])
              def cells(node, prop):
                  return [int(x, 16) for x in subprocess.check_output(['fdtget', '-t', 'x', str(dtb), node, prop], text=True).split()]
              def regions(node):
                  words = cells(node, 'reg')
                  assert len(words) % 4 == 0
                  return [((words[i] << 32) + words[i+1], (words[i+2] << 32) + words[i+3]) for i in range(0, len(words), 4)]
              children = subprocess.check_output(['fdtget', '-l', str(dtb), '/'], text=True).split()
              ram = [r for n in children if n.startswith('memory@') for r in regions('/'+n)]
              reserved = []
              for n in subprocess.check_output(['fdtget', '-l', str(dtb), '/reserved-memory'], text=True).split():
                  node = '/reserved-memory/'+n
                  props = subprocess.check_output(['fdtget', '-p', str(dtb), node], text=True).split()
                  if 'reg' in props:
                      reserved.extend(regions(node))
              # Match the pinned U-Boot include/env/ti/ti_common.env defaults.
              loads = {'LINUX': 0x82000000, 'FDT': 0x88000000, 'INITRD': 0x88080000}
              used = []
              for key, start in loads.items():
                  size = len(extracted[key])
                  if key == 'LINUX':
                      assert extracted[key][56:60] == bytes([0x41, 0x52, 0x4d, 0x64]), 'expected uncompressed ARM64 Image'
                      size = max(size, struct.unpack_from('<Q', extracted[key], 16)[0])
                  end = start + size
                  assert any(base <= start and end <= base+length for base, length in ram), (key, 'outside RAM')
                  assert all(end <= base or start >= base+length for base, length in reserved), (key, 'reserved overlap')
                  assert all(end <= base or start >= other_end for base, other_end in used), (key, 'load overlap')
                  used.append((start, end))
              print('Validated boot references and load ranges against actual DT RAM/reservations')
          PY
          mkdir "$out"
          cp layout.json extlinux.conf "$out/"
          sha256sum image.img > "$out/image.sha256"
        '';
    };
}
