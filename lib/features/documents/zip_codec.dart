import 'dart:convert';
import 'dart:typed_data';

/// Shared minimal stored-ZIP writer (no new dependency).
class ZipEntry {
  const ZipEntry({required this.name, required this.data});

  final String name;
  final List<int> data;
}

/// Encodes stored (uncompressed) ZIP entries.
Uint8List encodeZip(List<ZipEntry> entries) {
  final BytesBuilder out = BytesBuilder();
  final BytesBuilder central = BytesBuilder();
  var offset = 0;
  for (final ZipEntry entry in entries) {
    final List<int> name = utf8.encode(entry.name);
    final int crc = crc32(entry.data);
    final int size = entry.data.length;
    _u32(out, 0x04034b50);
    _u16(out, 20);
    _u16(out, 0x0800);
    _u16(out, 0);
    _u16(out, 0);
    _u16(out, 0);
    _u32(out, crc);
    _u32(out, size);
    _u32(out, size);
    _u16(out, name.length);
    _u16(out, 0);
    out.add(name);
    out.add(entry.data);
    _u32(central, 0x02014b50);
    _u16(central, 20);
    _u16(central, 20);
    _u16(central, 0x0800);
    _u16(central, 0);
    _u16(central, 0);
    _u16(central, 0);
    _u32(central, crc);
    _u32(central, size);
    _u32(central, size);
    _u16(central, name.length);
    _u16(central, 0);
    _u16(central, 0);
    _u16(central, 0);
    _u16(central, 0);
    _u32(central, 0);
    _u32(central, offset);
    central.add(name);
    offset += 30 + name.length + size;
  }
  final Uint8List centralBytes = central.takeBytes();
  final int centralOffset = offset;
  out.add(centralBytes);
  _u32(out, 0x06054b50);
  _u16(out, 0);
  _u16(out, 0);
  _u16(out, entries.length);
  _u16(out, entries.length);
  _u32(out, centralBytes.length);
  _u32(out, centralOffset);
  _u16(out, 0);
  return out.takeBytes();
}

final List<int> _crcTable = List<int>.generate(256, (int index) {
  var value = index;
  for (var round = 0; round < 8; round++) {
    value = (value & 1) != 0 ? 0xedb88320 ^ (value >>> 1) : value >>> 1;
  }
  return value;
});

int crc32(List<int> data) {
  var crc = 0xffffffff;
  for (final int byte in data) {
    crc = _crcTable[(crc ^ byte) & 0xff] ^ ((crc >>> 8) & 0xffffff);
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}

void _u16(BytesBuilder out, int value) {
  out.add(<int>[value & 0xff, (value >> 8) & 0xff]);
}

void _u32(BytesBuilder out, int value) {
  out.add(<int>[value & 0xff, (value >> 8) & 0xff, (value >> 16) & 0xff, (value >> 24) & 0xff]);
}
