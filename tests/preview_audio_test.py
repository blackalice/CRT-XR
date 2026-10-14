"""Compare committed audio with/without preview using the real Libretro core."""
import ctypes as C
import hashlib
from pathlib import Path
import sys


def compare(core_path, rom_path, directory):
    core = C.CDLL(str(Path(core_path).resolve()))
    directory = C.create_string_buffer(str(Path(directory).resolve()).encode())
    options = {}
    audio = bytearray()

    class Variable(C.Structure):
        _fields_ = [("key", C.c_char_p), ("value", C.c_void_p)]

    @C.CFUNCTYPE(C.c_bool, C.c_uint, C.c_void_p)
    def environment(command, data):
        if command in (9, 31):  # System/save directories, retained for callback lifetime.
            C.cast(data, C.POINTER(C.c_void_p))[0] = C.addressof(directory)
            return True
        if command == 16:  # SET_VARIABLES: select the same default as our native host.
            values = C.cast(data, C.POINTER(Variable))
            i = 0
            while values[i].key:
                description = C.string_at(values[i].value)
                default = description.split(b";", 1)[-1].strip().split(b"|")[0]
                options[values[i].key] = C.create_string_buffer(default)
                i += 1
            return True
        if command == 15:
            value = C.cast(data, C.POINTER(Variable)).contents
            if value.key not in options:
                return False
            value.value = C.addressof(options[value.key])
            return True
        if command == 17:
            C.cast(data, C.POINTER(C.c_bool))[0] = False
            return True
        if command == 3:
            C.cast(data, C.POINTER(C.c_bool))[0] = True
            return True
        if command == 52:
            C.cast(data, C.POINTER(C.c_uint))[0] = 0
            return True
        return command in (10, 18, 32, 37)

    @C.CFUNCTYPE(None, C.c_void_p, C.c_uint, C.c_uint, C.c_size_t)
    def video(*_):
        pass

    @C.CFUNCTYPE(None, C.c_int16, C.c_int16)
    def sample(left, right):
        audio.extend(bytes((C.c_int16 * 2)(left, right)))

    @C.CFUNCTYPE(C.c_size_t, C.c_void_p, C.c_size_t)
    def batch(data, count):
        audio.extend(C.string_at(data, count * 4))
        return count

    @C.CFUNCTYPE(None)
    def poll():
        pass

    @C.CFUNCTYPE(C.c_int16, C.c_uint, C.c_uint, C.c_uint, C.c_uint)
    def buttons(*_):
        return 0

    for name, callback in (("environment", environment), ("video_refresh", video),
                           ("audio_sample", sample), ("audio_sample_batch", batch),
                           ("input_poll", poll), ("input_state", buttons)):
        setter = getattr(core, "retro_set_" + name)
        setter.argtypes = [type(callback)]
        setter(callback)
    core.retro_serialize_size.restype = C.c_size_t
    for name in ("retro_serialize", "retro_unserialize"):
        fn = getattr(core, name)
        fn.argtypes = [C.c_void_p, C.c_size_t]
        fn.restype = C.c_bool
    core.retro_get_memory_data.argtypes = [C.c_uint]
    core.retro_get_memory_data.restype = C.c_void_p
    core.retro_get_memory_size.argtypes = [C.c_uint]
    core.retro_get_memory_size.restype = C.c_size_t

    class Game(C.Structure):
        _fields_ = [("path", C.c_char_p), ("data", C.c_void_p),
                    ("size", C.c_size_t), ("meta", C.c_char_p)]

    rom = C.create_string_buffer(Path(rom_path).read_bytes())
    game = Game(str(Path(rom_path).resolve()).encode(), C.addressof(rom), len(rom) - 1, None)
    core.retro_load_game.argtypes = [C.POINTER(Game)]
    core.retro_load_game.restype = C.c_bool

    def run(preview):
        core.retro_init()
        if not core.retro_load_game(C.byref(game)):
            raise RuntimeError("Core could not load audio-test ROM")
        state = C.create_string_buffer(core.retro_serialize_size())
        ram_ptr, ram_size = core.retro_get_memory_data(0), core.retro_get_memory_size(0)
        hashes = []
        for _ in range(480):
            audio.clear()
            core.retro_run()
            hashes.append(hashlib.sha256(audio).digest())
            if preview:
                ram = C.string_at(ram_ptr, ram_size) if ram_size else b""
                assert core.retro_serialize(state, len(state))
                core.retro_run()  # Discard speculative sound, just as the application does.
                assert core.retro_unserialize(state, len(state))
                if ram:
                    C.memmove(ram_ptr, ram, ram_size)
        core.retro_unload_game()
        core.retro_deinit()
        return hashes

    baseline, repeated = run(False), run(False)
    if baseline != repeated:
        raise RuntimeError("Control runs differ; audio comparison is inconclusive")
    preview = run(True)
    mismatches = sum(a != b for a, b in zip(baseline, preview))
    print(f"Committed audio: {mismatches} / 480 batches differ with input preview")
    return 0 if mismatches == 0 else 1


if __name__ == "__main__":
    raise SystemExit(compare(*sys.argv[1:4]))
