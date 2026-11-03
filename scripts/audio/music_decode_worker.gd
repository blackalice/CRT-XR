extends RefCounted
## Only this worker touches the MP3 playback. One bounded PCM block is published
## at a time; a new command invalidates every older seek and decoded block.
var thread := Thread.new()
var mutex := Mutex.new()
var wake := Semaphore.new()
var serial := 0
var audio: AudioStreamMP3
var target := 0.0
var rate := 48000
var block := PackedVector2Array()
var ended := false
var quitting := false
var bookmark: ConfigFile
var save_serial := 0
var saved_serial := 0
var save_error := OK
var save_done := Semaphore.new()

func save(config: ConfigFile, wait: bool) -> Error:
	mutex.lock()
	if quitting:
		mutex.unlock()
		return preload("res://scripts/ui/settings_store.gd").write("user://music-resume.cfg", config)
	bookmark = config; save_serial += 1
	var ticket := save_serial
	mutex.unlock(); wake.post()
	if not wait: return OK
	while true:
		mutex.lock()
		var finished := saved_serial >= ticket
		var error := save_error
		mutex.unlock()
		if finished: return error
		save_done.wait()
	return OK

func last_save_error() -> Error:
	mutex.lock()
	var error := save_error
	mutex.unlock()
	return error

func start() -> void:
	thread.start(run)

func request(stream: AudioStreamMP3, seconds: float, mix_rate: int) -> void:
	mutex.lock()
	audio = stream; target = seconds; rate = mix_rate
	serial += 1; block = PackedVector2Array(); ended = false
	mutex.unlock()
	wake.post()

func take() -> Dictionary:
	mutex.lock()
	var result := {"frames": block, "ended": ended}
	block = PackedVector2Array()
	mutex.unlock()
	wake.post()
	return result

func close() -> void:
	mutex.lock(); quitting = true; mutex.unlock()
	wake.post()
	if thread.is_started(): thread.wait_to_finish()

func run() -> void:
	var version := -1
	var decoder: AudioStreamPlayback
	var remaining := 0
	while true:
		wake.wait()
		mutex.lock()
		var quit := quitting
		var config := bookmark
		var ticket := save_serial
		bookmark = null
		var changed := version != serial
		var generation := serial
		var stream := audio
		var seconds := target
		var mix_rate := rate
		var occupied := not block.is_empty()
		mutex.unlock()
		if config != null:
			var error := preload("res://scripts/ui/settings_store.gd").write("user://music-resume.cfg", config)
			mutex.lock(); saved_serial = ticket; save_error = error; mutex.unlock()
			save_done.post()
		if quit: return
		if changed:
			version = generation
			decoder = stream.instantiate_playback() if stream != null else null
			remaining = ceili(maxf(0.0, stream.get_length() - seconds) * mix_rate) if stream != null else 0
			if decoder != null: decoder.start(seconds) # Potentially expensive scan, worker only.
		if occupied and not changed: continue
		var frames := decoder.mix_audio(1.0, mini(2048, remaining)) if decoder != null and remaining > 0 else PackedVector2Array()
		remaining -= frames.size()
		mutex.lock()
		if version == serial:
			block = frames
			ended = remaining <= 0 or frames.is_empty()
		mutex.unlock()
