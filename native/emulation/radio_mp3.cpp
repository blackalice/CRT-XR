#define DR_MP3_FLOAT_OUTPUT
#define DR_MP3_IMPLEMENTATION
#define DR_MP3_NO_STDIO
#include "radio_mp3.h"
#include <godot_cpp/core/class_db.hpp>
#include <algorithm>
using namespace godot;
void RadioMP3Decoder::_bind_methods() {
 ClassDB::bind_method(D_METHOD("reset"), &RadioMP3Decoder::reset);
 ClassDB::bind_method(D_METHOD("append", "data"), &RadioMP3Decoder::append);
 ClassDB::bind_method(D_METHOD("decode", "max_frames"), &RadioMP3Decoder::decode);
 ClassDB::bind_method(D_METHOD("get_sample_rate"), &RadioMP3Decoder::get_sample_rate);
 ClassDB::bind_method(D_METHOD("get_buffered_bytes"), &RadioMP3Decoder::get_buffered_bytes);
}
bool RadioMP3Decoder::append(const PackedByteArray &data) {
 if (pending.size() + data.size() > 262144) return false;
 if (data.size()) pending.insert(pending.end(), data.ptr(), data.ptr()+data.size());
 return true;
}
PackedVector2Array RadioMP3Decoder::decode(int max_frames) {
 PackedVector2Array result;
 size_t offset=0;
 max_frames=std::clamp(max_frames,1,32);
 float pcm[DRMP3_MAX_SAMPLES_PER_FRAME];
 // A complete maximum-sized MP3 frame plus lookahead is always retained.
 // This keeps fragmented network reads from consuming an incomplete frame.
 for (int n=0;n<max_frames && pending.size()-offset>=8192;++n) {
  drmp3dec_frame_info info{};
  int samples=drmp3dec_decode_frame(&decoder,pending.data()+offset,
      (int)(pending.size()-offset),pcm,&info);
  if (info.frame_bytes<=0) { offset=pending.size()-8192; break; }
  offset+=info.frame_bytes;
  if (!samples || info.layer!=3 || (info.channels!=1 && info.channels!=2)) continue;
  if (rate && rate!=info.sample_rate) { reset(); return PackedVector2Array(); }
  rate=info.sample_rate;
  int start=result.size(); result.resize(start+samples);
  auto dst=result.ptrw();
  for(int i=0;i<samples;++i) dst[start+i]=Vector2(pcm[i*info.channels],pcm[i*info.channels+(info.channels==2?1:0)]);
 }
 pending.erase(pending.begin(),pending.begin()+offset);
 return result;
}
