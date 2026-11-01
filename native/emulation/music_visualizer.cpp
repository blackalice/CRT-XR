#include "music_visualizer.h"
#include <algorithm>
#include <cstring>
#include <godot_cpp/core/class_db.hpp>
#ifdef _WIN32
#include <windows.h>
#else
#include <dlfcn.h>
#endif
using namespace godot;
void MusicVisualizer::_bind_methods() {
 ClassDB::bind_method(D_METHOD("start","library","preset"), &MusicVisualizer::start);
 ClassDB::bind_method(D_METHOD("submit","samples"), &MusicVisualizer::submit);
 ClassDB::bind_method(D_METHOD("select","preset"), &MusicVisualizer::select);
 ClassDB::bind_method(D_METHOD("frame"), &MusicVisualizer::frame);
 ClassDB::bind_method(D_METHOD("last_error"), &MusicVisualizer::last_error);
 ClassDB::bind_method(D_METHOD("close"), &MusicVisualizer::close);
}
MusicVisualizer::~MusicVisualizer(){ close(); }
void MusicVisualizer::close(){ {std::lock_guard<std::mutex> lock(mutex); stopping=true;} wake.notify_one(); if(worker.joinable()) worker.join(); }
void MusicVisualizer::start(const String &path,const String &data){ close(); stopping=false; error.clear(); pixels.clear(); audio.clear(); pending=false; library=path.utf8().get_data(); preset=data.utf8().get_data(); worker=std::thread(&MusicVisualizer::run,this); }
void MusicVisualizer::select(const String &data){ std::lock_guard<std::mutex> lock(mutex); preset=data.utf8().get_data(); }
void MusicVisualizer::submit(const PackedVector2Array &samples){
 std::lock_guard<std::mutex> lock(mutex);
 audio.clear();
 const int64_t begin=std::max<int64_t>(0,samples.size()-1024);
 for(int64_t i=begin;i<samples.size();++i){audio.push_back(samples[i].x);audio.push_back(samples[i].y);}
 pending=true; wake.notify_one();
}
Ref<Image> MusicVisualizer::frame(){
 std::lock_guard<std::mutex> lock(mutex); if(pixels.empty()) return {};
 PackedByteArray bytes; bytes.resize(pixels.size()); memcpy(bytes.ptrw(),pixels.data(),pixels.size()); pixels.clear();
 return Image::create_from_data(640,480,false,Image::FORMAT_RGBA8,bytes);
}
String MusicVisualizer::last_error(){std::lock_guard<std::mutex> lock(mutex);return String::utf8(error.c_str());}
void MusicVisualizer::run(){
#ifdef _WIN32
 auto dll=LoadLibraryW(reinterpret_cast<const wchar_t*>(String::utf8(library.c_str()).utf16().get_data()));
 auto symbol=[&](const char *name)->void* {return dll?reinterpret_cast<void*>(GetProcAddress(dll,name)):nullptr;};
#else
 auto dll=dlopen(library.c_str(),RTLD_NOW|RTLD_LOCAL);
 auto symbol=[&](const char *name)->void* {return dll?dlsym(dll,name):nullptr;};
#endif
 auto create=reinterpret_cast<void*(*)()>(symbol("projectm_create"));
 auto destroy=reinterpret_cast<void(*)(void*)>(symbol("projectm_destroy"));
 auto render=reinterpret_cast<void(*)(void*)>(symbol("projectm_opengl_render_frame"));
 auto load=reinterpret_cast<void(*)(void*,const char*,bool)>(symbol("projectm_load_preset_data"));
 auto pcm=reinterpret_cast<void(*)(void*,const float*,unsigned,int)>(symbol("projectm_pcm_add_float"));
 auto size=reinterpret_cast<void(*)(void*,size_t,size_t)>(symbol("projectm_set_window_size"));
 auto fps=reinterpret_cast<void(*)(void*,int32_t)>(symbol("projectm_set_fps"));
 auto locked=reinterpret_cast<void(*)(void*,bool)>(symbol("projectm_set_preset_locked"));
 auto init=reinterpret_cast<int(*)()>(symbol("crt_projectm_init"));
 std::string failure;
 {
 crt_xr::GlContext gl;
 if(!create||!destroy||!render||!load||!pcm||!size||!fps||!locked||!init) failure="projectM library missing or incompatible. Rebuild the visualiser libraries.";
 else if(gl.create(3,3,true,failure)&&gl.resize(640,480,false,false,failure)) {
  if(init()!=0) failure="projectM could not initialise OpenGL.";
  else {
   void *instance=create();
   if(!instance) failure="projectM could not start.";
   else {
    size(instance,640,480);fps(instance,30);locked(instance,true);
#ifdef _WIN32
    using Bind=void(__stdcall*)(unsigned,unsigned);
#else
    using Bind=void(*)(unsigned,unsigned);
#endif
    auto bind=reinterpret_cast<Bind>(crt_xr::GlContext::proc("glBindFramebuffer"));
    while(true){
     std::vector<float> samples; std::string next;
     {std::unique_lock<std::mutex> lock(mutex);wake.wait(lock,[&]{return stopping||pending;});if(stopping)break;pending=false;samples.swap(audio);next.swap(preset);}
     if(!next.empty())load(instance,next.c_str(),false);
     if(!samples.empty())pcm(instance,samples.data(),static_cast<unsigned>(samples.size()/2),2);
     bind(0x8CA9,gl.framebuffer());render(instance);
     std::vector<uint8_t> output;gl.read(640,480,true,output);
     {std::lock_guard<std::mutex> lock(mutex);pixels.swap(output);}
    }
    destroy(instance);
   }
  }
 }
 }
 {std::lock_guard<std::mutex> lock(mutex);error=failure;}
#ifdef _WIN32
 if(dll)FreeLibrary(dll);
#else
 if(dll)dlclose(dll);
#endif
}
