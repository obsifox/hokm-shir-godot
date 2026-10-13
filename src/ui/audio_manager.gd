extends Node
## Audio manager (autoload: Snd) — music crossfade + SFX pool.

var music_a: AudioStreamPlayer
var music_b: AudioStreamPlayer
var _use_a := true
var _current_track := ""
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_i := 0
var _sfx_cache := {}
var _music_cache := {}

const SFX_DIR := "res://assets/sfx/"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Create buses: Music, SFX
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
	music_a = AudioStreamPlayer.new()
	music_b = AudioStreamPlayer.new()
	music_a.bus = "Music"
	music_b.bus = "Music"
	music_a.process_mode = Node.PROCESS_MODE_ALWAYS
	music_b.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music_a)
	add_child(music_b)
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_sfx_pool.append(p)
	apply_volumes()


func apply_volumes() -> void:
	var master_idx := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master_idx, S.muted)
	AudioServer.set_bus_volume_db(master_idx, linear_to_db(clampf(S.master_vol, 0.0001, 1.0)))
	var m := AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_db(m, linear_to_db(clampf(S.music_vol, 0.0001, 1.0)))
	var s := AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_volume_db(s, linear_to_db(clampf(S.sfx_vol, 0.0001, 1.0)))


func toggle_mute() -> void:
	S.muted = not S.muted
	S.save_settings()
	apply_volumes()


## Crossfade to a music track. name: "main","hokm","gameplay","victory","defeat"
func play_music(track: String) -> void:
	if _current_track == track:
		return
	_current_track = track
	var files := {
		"main": "res://assets/sounds/hokm_main.mp3",
		"hokm": "res://assets/sounds/hokm_hokmselection.mp3",
		"gameplay": "res://assets/sounds/hokm_gameplay.mp3",
		"victory": "res://assets/sounds/Hokm_victory.mp3",
		"defeat": "res://assets/sounds/Hokm_defeat.mp3",
	}
	if not files.has(track):
		stop_music()
		return
	var path: String = files[track]
	if not _music_cache.has(path):
		if not ResourceLoader.exists(path):
			return
		_music_cache[path] = load(path)
	var stream: AudioStream = _music_cache[path]
	var fade_out := music_b if _use_a else music_a
	var fade_in := music_a if _use_a else music_b
	_use_a = not _use_a
	fade_in.stream = stream
	fade_in.volume_db = -30.0
	fade_in.play()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(fade_in, "volume_db", -6.0, 1.0)
	if fade_out.playing:
		tw.tween_property(fade_out, "volume_db", -40.0, 1.0)
		tw.chain().tween_callback(fade_out.stop)


func stop_music() -> void:
	_current_track = ""
	for p in [music_a, music_b]:
		if p.playing:
			var tw := create_tween()
			tw.tween_property(p, "volume_db", -40.0, 0.5)
			tw.tween_callback(p.stop)


func sfx(name: String, pitch := 1.0, vol_db := 0.0) -> void:
	var path := SFX_DIR + name + ".wav"
	if not _sfx_cache.has(path):
		if not ResourceLoader.exists(path):
			push_warning("missing sfx: " + path)
			return
		_sfx_cache[path] = load(path)
	var p := _sfx_pool[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _sfx_pool.size()
	p.stream = _sfx_cache[path]
	p.pitch_scale = pitch * randf_range(0.97, 1.04)
	p.volume_db = vol_db
	p.play()


func click() -> void:
	sfx("button")
