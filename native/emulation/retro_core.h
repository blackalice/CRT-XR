#pragma once
#include "libretro_host.h"
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/audio_stream_generator_playback.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>

class RetroCore : public godot::RefCounted {
    GDCLASS(RetroCore, godot::RefCounted)
    retrocrt::LibretroHost host;
protected:
    static void _bind_methods();
public:
    bool load_core(const godot::String& path);
    bool load_game(const godot::String& path, const godot::String& saves);
    bool run_frame(int buttons);
    godot::PackedByteArray frame() const;
    godot::Dictionary info() const;
    godot::String last_error() const;
    int push_audio(const godot::Ref<godot::AudioStreamGeneratorPlayback>& playback);
    godot::PackedByteArray save_state();
    bool load_state(const godot::PackedByteArray& state);
    godot::PackedByteArray save_ram() const;
    bool load_ram(const godot::PackedByteArray& ram);
    void close_game();
    void close();
};
