{
  runCommand,
  zstd,
  util-linux,
  mtools,
  jq,
  python3,
  dtc,
  image,
  configurationLimit,
}:
runCommand "beagley-ai-sd-image-layout" {
  nativeBuildInputs = [zstd util-linux mtools jq python3 dtc];
} ''
  zstd -d -c ${image}/sd-image/*.img.zst > image.img
  sfdisk --json image.img > layout.json
  test "$(jq '.partitiontable.partitions | length' layout.json)" -eq 2
  test "$(jq -r '.partitiontable.partitions[0].type' layout.json)" = e
  test "$(jq -r '.partitiontable.partitions[0].bootable' layout.json)" = true
  test "$(jq -r '.partitiontable.partitions[1].type' layout.json)" = 83
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
  blkid -p -O "$offset" -o export image.img > boot.identity
  blkid -p -O "$rootOffset" -o export image.img > root.identity
  # NixOS embeds root filesystem policy in the initrd; extlinux need not
  # repeat root= when it selects that matching generation's initrd.
  cat extlinux.conf
  python3 - "$offset" ${toString configurationLimit} <<'PY'
  import pathlib, posixpath, re, struct, subprocess, sys
  import json
  partitions = json.loads(pathlib.Path('layout.json').read_text())['partitiontable']['partitions']
  partition = partitions[0]
  assert partition['start'] + partition['size'] <= partitions[1]['start'], 'overlapping partitions'
  assert all(p['size'] > 0 and (p['start'] + p['size']) * 512 <= pathlib.Path('image.img').stat().st_size for p in partitions), 'partition outside image'
  identities = [dict(line.split('=', 1) for line in pathlib.Path(name + '.identity').read_text().splitlines()) for name in ('boot', 'root')]
  assert [(i['LABEL'], i['TYPE']) for i in identities] == [('BEAGLEYBOOT', 'vfat'), ('BEAGLEY_ROOT', 'ext4')]
  assert all(i.get('UUID') for i in identities) and identities[0]['UUID'] != identities[1]['UUID'], 'ambiguous filesystem identity'
  with open('image.img', 'rb') as disk:
      assert disk.read(512)[510:512] == bytes([0x55, 0xaa]), 'invalid MBR signature'
      disk.seek(int(sys.argv[1]))
      bpb = disk.read(512)
      reserved_sectors = struct.unpack_from('<H', bpb, 14)[0]
      fat_sectors = struct.unpack_from('<H', bpb, 22)[0]
      disk.seek(int(sys.argv[1]) + reserved_sectors * 512)
      fat = disk.read(fat_sectors * 512)
  assert bpb[510:512] == bytes([0x55, 0xaa]), 'invalid FAT boot signature'
  assert struct.unpack_from('<H', bpb, 11)[0] == 512, 'unexpected FAT sector size'
  sectors = struct.unpack_from('<H', bpb, 19)[0] or struct.unpack_from('<I', bpb, 32)[0]
  assert sectors == partition['size'], 'FAT does not fill partition (reference recipe uses mkfs.fat -a)'
  cluster_bytes = bpb[13] * 512
  root_sectors = (struct.unpack_from('<H', bpb, 17)[0] * 32 + 511) // 512
  cluster_count = (sectors - reserved_sectors - bpb[16] * fat_sectors - root_sectors) // bpb[13]
  assert 4085 <= cluster_count < 65525, 'expected FAT16 cluster count'
  free_bytes = sum(struct.unpack_from('<H', fat, i * 2)[0] == 0 for i in range(2, cluster_count + 2)) * cluster_bytes
  entries = re.split(r'(?m)^LABEL ', pathlib.Path('extlinux.conf').read_text())[1:]
  assert entries, 'no boot entries'
  generation_sizes = []
  for entry in entries:
      fields = dict(line.strip().split(None, 1) for line in entry.splitlines()[1:] if line.strip() and len(line.strip().split(None, 1)) == 2)
      extracted = {}
      for key in ('LINUX', 'INITRD', 'FDT'):
          value = fields[key]
          resolved = str(pathlib.PurePosixPath('/extlinux') / value)
          # mtools resolves ../ relative to the extlinux directory.
          extracted[key] = subprocess.check_output(['mtype', '-i', 'image.img@@'+sys.argv[1], '::'+posixpath.normpath(resolved)])
      generation_sizes.append(sum((len(data) + cluster_bytes - 1) // cluster_bytes * cluster_bytes for data in extracted.values()))
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
  retention = int(sys.argv[2])
  assert retention >= 2, 'rollback requires at least two retained generations'
  # Budget independent copies of the largest current generation. This
  # does not assume deduplication or predict unlimited future growth.
  reserve = 4 * 1024 * 1024
  additional = max(0, retention - len(entries))
  assert free_bytes >= additional * (max(generation_sizes) + 1024 * 1024) + reserve, 'FAT lacks space for retained generations'
  print(f'FAT free bytes {free_bytes}; reserved {retention} similarly sized generations plus directory/metadata margin')
  PY
  mkdir "$out"
  cp layout.json extlinux.conf boot.identity root.identity "$out/"
  sha256sum image.img > "$out/image.sha256"
''
