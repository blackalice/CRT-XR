#pragma once
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include "gl_context.h"
#include <thread>
#include <mutex>
#include <condition_variable>
namespace godot {
class MusicVisualizer : public RefCounted {
 GDCLASS(MusicVisualizer, RefCounted)
 std::thread worker;
 std::mutex mutex;
 std::condition_variable wake;
 bool stopping=false, pending=false;
 std::string library, preset, error;
 std::vector<float> audio;
 std::vector<uint8_t> pixels;
 void run();
protected: static void _bind_methods();
public:
 ~MusicVisualizer();
 void start(const String &path, const String &data);
 void submit(const PackedVector2Array &samples);
 void select(const String &data);
 Ref<Image> frame();
 String last_error();
 void close();
};
}
