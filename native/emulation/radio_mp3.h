#pragma once
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include "third_party/dr_mp3.h"
#include <vector>
namespace godot {
class RadioMP3Decoder : public RefCounted {
 GDCLASS(RadioMP3Decoder, RefCounted)
 drmp3dec decoder{};
 std::vector<unsigned char> pending;
 int rate=0;
protected:
 static void _bind_methods();
public:
 RadioMP3Decoder() { drmp3dec_init(&decoder); }
 void reset() { pending.clear(); rate=0; drmp3dec_init(&decoder); }
 bool append(const PackedByteArray &data);
 PackedVector2Array decode(int max_frames);
 int get_sample_rate() const { return rate; }
 int get_buffered_bytes() const { return (int)pending.size(); }
};
}
