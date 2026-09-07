"""Audit assembled HS-FS certificates, binman payload inventory and load spans."""
import datetime
import hashlib
from pathlib import Path
import subprocess
import sys
from cryptography import x509
from cryptography.x509.oid import ObjectIdentifier

bundle = Path(sys.argv[1])
configs = [dict(line.split('=', 1) for line in Path(p).read_text().splitlines() if line.startswith('CONFIG_')) for p in sys.argv[2:4]]


def tlv(data, offset=0):
    tag, length = data[offset:offset + 2]
    start = offset + 2
    if length & 128:
        width = length & 127
        assert width and width <= 4
        length = int.from_bytes(data[start:start + width], 'big')
        start += width
    end = start + length
    assert end <= len(data)
    value = data[start:end]
    if tag == 0x30:
        value, pos = [], start
        while pos < end:
            item, pos = tlv(data, pos)
            value.append(item)
        assert pos == end
    elif tag == 2:
        value = int.from_bytes(value, 'big')
    return value, end


def certificate(data):
    _, length = tlv(data)
    cert = x509.load_der_x509_certificate(data[:length])
    cert.verify_directly_issued_by(cert)
    assert cert.serial_number == 1
    assert cert.not_valid_before_utc == datetime.datetime(2020, 1, 1, tzinfo=datetime.timezone.utc)
    assert cert.not_valid_after_utc == datetime.datetime(2040, 1, 1, tzinfo=datetime.timezone.utc)
    payload = data[length:]
    if not any(extension.oid.dotted_string == '1.3.6.1.4.1.294.1.9' for extension in cert.extensions):
        # Binman's x509_cert() uses this TI image-integrity extension for FIT
        # payloads. A valid certificate alone does not authenticate the bytes
        # following it; check the declared digest and length as well.
        extension = cert.extensions.get_extension_for_oid(ObjectIdentifier('1.3.6.1.4.1.294.1.34')).value.value
        (algorithm, digest, size), end = tlv(extension)
        assert end == len(extension)
        assert algorithm == bytes.fromhex('608648016503040203')
        assert size == len(payload)
        assert hashlib.sha512(payload).digest() == digest
    return cert, payload


cert, payload = certificate((bundle / 'tiboot3.bin').read_bytes())
extension = cert.extensions.get_extension_for_oid(ObjectIdentifier('1.3.6.1.4.1.294.1.9')).value.value
inventory, _ = tlv(extension)
size, count, *components = inventory
assert size == len(payload) and count == len(components) == 5
components = {component[0]: component for component in components}
assert set(components) == {1, 2, 18, 17, 3}
expected_loads = {1: 0x43c00000, 2: 0x40000, 18: 0x67000, 17: 0x43c7a800, 3: 0}
offset, ranges = 0, []
for kind in (1, 2, 18, 3, 17):
    _, core, _, address, length, algorithm, digest = components[kind]
    address = int.from_bytes(address, 'big')
    assert address == expected_loads[kind]
    assert length > 0 and offset + length <= len(payload)
    assert algorithm == bytes.fromhex('608648016503040203'), 'expected SHA-512'
    assert hashlib.sha512(payload[offset:offset + length]).digest() == digest
    offset += length
    if kind != 3:  # Inner TIFS certificate is authentication metadata, not a load at zero.
        end = address + length
        assert all(end <= start or address >= stop for start, stop in ranges)
        ranges.append((address, end))
    if kind == 1:
        assert length <= int(configs[0]['CONFIG_SPL_MAX_SIZE'], 0)
    if kind == 17:
        assert address + length <= 0x43c80000
    print(f'ROM component {kind}: core {core}, address {address:#x}, bytes {length}, SHA-512 verified')
assert offset == len(payload)


def get(fit, node, prop, kind='s'):
    return subprocess.check_output(['fdtget', '-t', kind, str(fit), node, prop], text=True).strip()


for filename, expected in [('tispl.bin', {'atf', 'tee', 'dm', 'spl', 'fdt-0'}), ('u-boot.img', {'uboot', 'fdt-0'})]:
    fit = bundle / filename
    names = subprocess.check_output(['fdtget', '-l', str(fit), '/images'], text=True).split()
    assert set(names) == expected, names
    ranges = []
    for name in names:
        node = '/images/' + name
        raw = bytes(int(word, 16) for word in get(fit, node, 'data', 'bx').split())
        assert raw, (filename, name, 'missing payload')
        if name == 'fdt-0':
            if raw[0] == 0x30:
                _, raw = certificate(raw)
            assert raw[:4] == bytes.fromhex('d00dfeed')
            continue
        cert, data = certificate(raw)
        if name == 'atf':
            altered = raw[:-1] + bytes([raw[-1] ^ 1])
            try:
                certificate(altered)
            except AssertionError:
                pass
            else:
                raise AssertionError('corrupted FIT payload accepted')
        load = int(get(fit, node, 'load', 'x'), 16)
        props = subprocess.check_output(['fdtget', '-p', str(fit), node], text=True).split()
        if 'entry' in props:
            assert int(get(fit, node, 'entry', 'x'), 16) == load
        else:
            assert name == 'uboot'  # U-Boot FIT uses the standard load-address entry fallback.
        limits = {'atf': (0x80000000, 0x80000), 'tee': (0x9e800000, 0x1800000), 'dm': (0x89000000, 0x1000000), 'spl': (0x80080000, int(configs[1]['CONFIG_SPL_MAX_SIZE'], 0)), 'uboot': (0x80800000, 0x1800000)}
        start, capacity = limits[name]
        assert load == start and len(data) <= capacity
        end = load + len(data)
        assert all(end <= lo or load >= hi for lo, hi in ranges)
        ranges.append((load, end))
        print(f'{filename}/{name}: {load:#x}..{end:#x}, deterministic certificate verified')
print('Binman inventory, ROM hashes, deterministic certificates and staged load spans passed')
