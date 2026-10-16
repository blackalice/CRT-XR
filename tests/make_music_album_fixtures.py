"""Make ignored album fixtures from a user-supplied/permissive test MP3.
Usage: python tests/make_music_album_fixtures.py [source.mp3]
The default source is the project's existing ignored CC0 CRT preview.
"""
from pathlib import Path
import struct, sys
root = Path("build/album-fixture")
root.mkdir(parents=True, exist_ok=True)
audio = Path(sys.argv[1] if len(sys.argv)>1 else "build/crt-power-original-preview.mp3").read_bytes()
if audio[:3] == b"ID3":
    size = 0
    for value in audio[6:10]: size = (size << 7) | value
    audio = audio[10+size:]
def sync(value): return bytes((value >> shift) & 127 for shift in [21,14,7,0])
def tag(version, fields):
    frames = b""
    for key, value in fields.items():
        data = b"\x01"+value.encode("utf-16") if version==3 else b"\x03"+value.encode("utf-8")
        frames += key.encode()+(struct.pack(">I",len(data)) if version==3 else sync(len(data)))+b"\0\0"+data
    return b"ID3"+bytes([version,0,0])+sync(len(frames))+frames
(root/"z.mp3").write_bytes(tag(3,{"TIT2":"First café","TPE1":"An Artist","TALB":"Bedroom Album","TRCK":"1/3","TPOS":"1/2"})+audio)
(root/"a.mp3").write_bytes(tag(4,{"TIT2":"Second song","TPE1":"Other Artist","TALB":"Bedroom Album","TRCK":"2","TPOS":"1"})+audio)
(root/"b.mp3").write_bytes(tag(4,{"TIT2":"Disc Two","TRCK":"1","TPOS":"2"})+audio)
for name in ["2.mp3","10.mp3"]: (root/name).write_bytes(audio)
legacy = b"TAG"+b"Legacy title".ljust(30,b"\0")+b"Legacy artist".ljust(30,b"\0")+b"Old album".ljust(30,b"\0")+b"1998"+b"\0"*28+b"\0\x03\0"
(root/"legacy.mp3").write_bytes(audio+legacy)
(root/"broken.mp3").write_bytes(b"ID3\x04\0\0\x7f\x7f\x7f\x7fJUNK")
