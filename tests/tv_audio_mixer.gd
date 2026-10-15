extends SceneTree
const TVAudio = preload("res://scripts/emulation/tv_audio.gd")
var player := AudioStreamPlayer.new()
var audio := TVAudio.new()
var capture := AudioEffectCapture.new()
var failures := 0
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	print("PASS: " if ok else "FAIL: ",message)
	if not ok: failures+=1
func record(mode: int, pan: float) -> PackedVector2Array:
	player.stop(); audio.mode=mode; audio.apply(); audio.clear_tail(); audio.panner.pan=pan
	await create_timer(.15).timeout
	capture.clear_buffer(); player.play()
	await create_timer(.32).timeout
	return capture.get_buffer(capture.get_frames_available())
func energy(samples: PackedVector2Array, after := 0) -> Vector2:
	var total := Vector2.ZERO
	for i in range(after,samples.size()):
		total.x+=samples[i].x*samples[i].x
		total.y+=samples[i].y*samples[i].y
	return total
func first_signal(samples: PackedVector2Array) -> int:
	for i in range(samples.size()):
		if samples[i].length_squared()>0.0000001: return i
	return -1
func run():
	# Capture after all processing, then mute this process's Master output.
	# No diagnostic sound reaches the user's speakers.
	AudioServer.add_bus_effect(0,capture)
	AudioServer.set_bus_mute(0,true)
	root.add_child(player); root.add_child(audio); audio.setup(player)
	var stream := AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS; stream.stereo=true; stream.mix_rate=48000
	var bytes := PackedByteArray(); bytes.resize(48000*4/2)
	for i in range(8): bytes.encode_s16(i*4,8000); bytes.encode_s16(i*4+2,8000)
	stream.data=bytes; player.stream=stream
	audio.speaker_character=0; audio.room_amount=.2
	var original := await record(0,0)
	var direct := await record(1,0)
	check(original.size()>4000 and energy(original).length()>0,"Real audio mixer produces captured samples")
	var original_start := first_signal(original)
	var direct_start := first_signal(direct)
	check(original_start>=0 and direct_start>=0,"Original and TV modes retain the immediate impulse")
	var spatial := await record(2,.5)
	var spatial_energy := energy(spatial)
	check(spatial_energy.y>spatial_energy.x*1.5,"Processed waveform pans towards the expected ear")
	var start := first_signal(spatial)
	check(start>=0 and energy(spatial,start+2000).length()>0.000001,"Room mode produces a quiet reflection tail")
	audio.room_amount=0
	var dry := await record(2,0)
	check(energy(dry,first_signal(dry)+2000).length()<0.000001,"Room bypass removes the reflection tail")
	var peak := 0.0
	for sample in spatial: peak=maxf(peak,maxf(absf(sample.x),absf(sample.y)))
	check(peak<1.0,"Diagnostic signal remains below clipping")
	print("TV AUDIO MIXER CHECKS COMPLETE: ",failures," failures")
	player.stop(); audio.free(); player.free()
	AudioServer.remove_bus_effect(0,0)
	capture=null
	for i in range(3): await process_frame
	quit.call_deferred(1 if failures else 0)
