#!/usr/bin/env python3
import json
import struct
import sys
from pathlib import Path

source, output, report = map(Path, sys.argv[1:4])
mode = sys.argv[4] if len(sys.argv) > 4 else "dylib"
data = bytearray(source.read_bytes())
if struct.unpack_from("<I", data, 0)[0] != 0xFEEDFACF:
    raise SystemExit("expected a thin little-endian 64-bit Mach-O")
_, _, _, filetype, ncmds, sizeofcmds, _, _ = struct.unpack_from("<IiiIIIII", data, 0)
new_filetype = 6 if mode == "dylib" else 8
struct.pack_into("<I", data, 12, new_filetype)
offset = 32
segments = []
weak_command_offset = None
weak_command_size = None
weak_ordinal = None
dependency_ordinal = 0
dyld_info = None
for _ in range(ncmds):
    cmd, cmdsize = struct.unpack_from("<II", data, offset)
    if cmd in (0xC, 0x80000018, 0x18):
        dependency_ordinal += 1
    if cmd == 0x80000022:
        dyld_info = struct.unpack_from("<12I", data, offset)
    if cmd == 0x80000018:
        weak_command_offset = offset
        weak_command_size = cmdsize
        weak_ordinal = dependency_ordinal
    if cmd == 0x19:
        segname = bytes(data[offset + 8:offset + 24]).split(b"\0", 1)[0].decode("ascii", "replace")
        vmaddr, vmsize = struct.unpack_from("<QQ", data, offset + 24)
        segments.append({"name": segname, "vmaddr": hex(vmaddr), "vmsize": hex(vmsize)})
        if segname == "__PAGEZERO":
            struct.pack_into("<Q", data, offset + 32, 0)
    if cmdsize < 8:
        raise SystemExit(f"invalid load command size at {offset}")
    offset += cmdsize
if offset != 32 + sizeofcmds:
    raise SystemExit("load-command walk did not match sizeofcmds")
for name in ("libxmp.4.dylib", "libopenal.1.dylib", "libSDL2-2.0.0.dylib", "libmpg123.dylib", "libsndfile.1.dylib", "libfmod.dylib"):
    old = f"@executable_path/../Frameworks/{name}".encode()
    new = f"@loader_path/Frameworks/{name}".encode()
    if data.count(old) != 1:
        raise SystemExit(f"expected one dependency string for {name}")
    data[data.index(old):data.index(old) + len(old)] = new + b"\0" * (len(old) - len(new))
if mode == "dylib":
    if weak_command_offset is None:
        raise SystemExit("no weak dylib command available for LC_ID_DYLIB insertion")
    struct.pack_into("<IIIIII", data, weak_command_offset, 0xD, weak_command_size, 24, 0, 0x10000, 0x10000)
    if weak_ordinal is None or dyld_info is None:
        raise SystemExit("missing weak dylib ordinal or dyld bind info")

    def read_uleb(pos, end):
        value = 0
        shift = 0
        start = pos
        while pos < end:
            byte = data[pos]
            value |= (byte & 0x7f) << shift
            pos += 1
            if byte < 0x80:
                return value, pos, pos - start
            shift += 7
        raise SystemExit("unterminated bind ULEB")

    def adjust_bind_stream(start, size):
        if not start or not size:
            return 0
        pos, end, changed = start, start + size, 0
        while pos < end:
            opcode = data[pos]
            pos += 1
            kind = opcode & 0xf0
            imm = opcode & 0x0f
            if kind == 0x00:
                continue
            if kind == 0x10:
                if imm > weak_ordinal:
                    data[pos - 1] = opcode - 1
                    changed += 1
            elif kind == 0x20:
                value, next_pos, encoded = read_uleb(pos, end)
                if value > weak_ordinal:
                    new_value = value - 1
                    if new_value >= 0x80 and encoded == 1:
                        raise SystemExit("cannot shrink bind ordinal encoding safely")
                    data[pos:next_pos] = bytes([new_value]) + b"\0" * (encoded - 1)
                    changed += 1
                pos = next_pos
            elif kind == 0x40:
                while pos < end and data[pos] != 0:
                    pos += 1
                pos += 1
            elif kind in (0x60, 0x70, 0x80, 0xA0, 0xC0):
                count = 2 if kind == 0xC0 else 1
                for _ in range(count):
                    _, pos, _ = read_uleb(pos, end)
            elif kind == 0xD0:
                if imm == 1:
                    _, pos, _ = read_uleb(pos, end)
                elif imm not in (0,):
                    raise SystemExit("unknown threaded bind subopcode")
        return changed

    adjusted = sum(adjust_bind_stream(off, size) for off, size in ((dyld_info[4], dyld_info[5]), (dyld_info[6], dyld_info[7]), (dyld_info[8], dyld_info[9])))
else:
    adjusted = 0
output.parent.mkdir(parents=True, exist_ok=True)
output.write_bytes(data)
Path(report).write_text(json.dumps({"source": str(source), "output": str(output), "mode": mode, "old_filetype": filetype, "new_filetype": new_filetype, "ncmds": ncmds, "segments": segments, "removed_dependency_ordinal": weak_ordinal if mode == "dylib" else None, "adjusted_bind_ordinals": adjusted}, indent=2) + "\n")
