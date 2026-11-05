"""Extract intact embedded 7z streams from a pinned offline Qt IFW installer.

No installer code is executed. Both the 7z start header and next header CRCs
are validated, and all archive ranges must be inside the input file.
"""
import mmap
import pathlib
import struct
import sys
import zlib

source, target = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
target.mkdir(parents=True, exist_ok=True)
magic = b"7z\xbc\xaf\x27\x1c"
count = 0
with source.open("rb") as stream, mmap.mmap(stream.fileno(), 0, access=mmap.ACCESS_READ) as data:
    cursor = 0
    while (offset := data.find(magic, cursor)) >= 0:
        cursor = offset + len(magic)
        if offset + 32 > len(data):
            continue
        start_crc, next_offset, next_size, next_crc = struct.unpack_from("<IQQI", data, offset + 8)
        if zlib.crc32(data[offset + 12:offset + 32]) != start_crc:
            continue
        start = offset + 32 + next_offset
        end = start + next_size
        if end > len(data) or zlib.crc32(data[start:end]) != next_crc:
            continue
        output = target / f"archive-{count:02d}.7z"
        output.write_bytes(data[offset:end])
        print(f"{output.name}: offset={offset} length={end-offset}")
        count += 1
        cursor = end
if count == 0:
    raise SystemExit("No valid 7z payloads found")
print(f"Validated and extracted {count} archives")
