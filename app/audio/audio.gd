extends Node

## The sound bank: every sound effect the game plays, as the content database
## lists it (`sounds`, data/db/sounds/sounds.sql) — a row a sound, with where
## its file is, the prompt it is made from, and whether it is in use. A sound
## flagged in use with a file at its path is loaded at boot and played by its
## id (`play`); every other sound is silent — the bank knows it is there to be
## made (`has`), and says nothing until it is. Nothing is synthesised: the game
## carries exactly the sounds it has been given, one at a time.
##
## The music is the one sound still made in code (`_make_music`), and is off
## (`music_volume`).

const RATE := 22050

## The sounds there are to play: id -> its stream, for every sound in use with
## a file at its path (`_load_bank`).
var _sfx: Dictionary = {}
## Every sound the bank lists, in use or not: what `has` answers for.
var _known: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _next_player := 0

var sfx_volume: float = 0.7
## Music is off for now. Give this a value again — or move the Music slider in
## Settings, which works while the game is running — to bring it back.
var music_volume: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_bank()
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_players.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_music_player)
	_apply_volumes()

## The loop is a few hundred thousand samples to synthesise and about half a
## megabyte to hold, so it is built the first time it is actually wanted rather
## than at boot: with music off, that work never happens at all.
func _ensure_music() -> void:
	if _music_player.stream == null:
		_music_player.stream = _make_music()

## Release the streaming buffers on the way out, so shutdown is clean.
func _exit_tree() -> void:
	_music_player.stop()
	_music_player.stream = null
	for p in _players:
		p.stop()
		p.stream = null
	_sfx.clear()

func _apply_volumes() -> void:
	_music_player.volume_db = linear_to_db(maxf(music_volume, 0.0001))
	for p in _players:
		p.volume_db = linear_to_db(maxf(sfx_volume, 0.0001))

func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_volumes()

func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_volumes()
	# The slider acts at once in both directions. Without this, turning it down
	# leaves a silent stream running and turning it up does nothing until the
	# next screen change happens to call play_music().
	if music_volume <= 0.001:
		_music_player.stop()
	else:
		play_music()

func play(id: String, pitch: float = 1.0) -> void:
	if not _sfx.has(id) or sfx_volume <= 0.001:
		return
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.stream = _sfx[id]
	p.pitch_scale = clampf(pitch * randf_range(0.96, 1.05), 0.3, 3.0)
	p.play()

func play_music() -> void:
	if _music_player.playing or music_volume <= 0.001:
		return
	_ensure_music()
	_music_player.play()

func stop_music() -> void:
	_music_player.stop()

## --- the bank ----------------------------------------------------------------
## Every sound the table lists is known; each flagged in use with a file at its
## path is loaded, and plays. One flagged in use with no file there, or a file
## that is not a sound, warns and stays silent. A database without the table
## is a bank with nothing in it.
func _load_bank() -> void:
	_sfx.clear()
	_known.clear()
	if not Db.available() or not Db.has_table("sounds"):
		return
	for row in Db.rows("SELECT id, path, use_flag FROM sounds"):
		var id := String(row["id"])
		_known[id] = true
		if String(row["use_flag"]) != "Y":
			continue
		var path := String(row["path"])
		if not ResourceLoader.exists(path):
			push_warning("Audio: the sound %s is flagged in use, and there is no file at %s" % [id, path])
			continue
		var stream := load(path)
		if not (stream is AudioStream):
			push_warning("Audio: the file at %s is not a sound (%s)" % [path, id])
			continue
		_sfx[id] = stream

## Whether the bank lists a sound, for content that names one by id — in use
## and playing, or still to be made.
func has(id: String) -> bool:
	return _known.has(id)

## Whether `id` plays: in use, with its file loaded.
func plays(id: String) -> bool:
	return _sfx.has(id)

## --- the music, still made in code ------------------------------------------------
func _wave(kind: String, phase: float) -> float:
	match kind:
		"square":
			return 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		"saw":
			return fmod(phase, 1.0) * 2.0 - 1.0
		"tri":
			var t := fmod(phase, 1.0)
			return (t * 4.0 - 1.0) if t < 0.5 else (3.0 - t * 4.0)
		_:
			return sin(phase * TAU)

func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s

## A slow minor arpeggio over a drone. Eight bars, looped.
func _make_music() -> AudioStreamWAV:
	var bar := 1.6
	var bars := 8
	var n := int(bar * bars * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var scale := [220.0, 261.63, 329.63, 392.0, 440.0, 523.25]
	var drone_phase := 0.0
	var lead_phase := 0.0
	for i in n:
		var t := float(i) / float(RATE)
		var step := int(t / 0.4) % scale.size()
		var bar_idx := int(t / bar) % bars
		var lead_f: float = scale[(step + bar_idx) % scale.size()]
		var drone_f: float = 110.0 if bar_idx < 4 else 98.0
		drone_phase += drone_f / float(RATE)
		lead_phase += lead_f / float(RATE)
		var note_t := fmod(t, 0.4) / 0.4
		var lead_env: float = pow(1.0 - note_t, 2.0) * 0.22
		var s := _wave("tri", lead_phase) * lead_env
		s += _wave("tri", drone_phase) * 0.10
		s += sin(drone_phase * TAU * 0.5) * 0.06
		var v := int(clampf(s, -1.0, 1.0) * 28000.0)
		data.encode_s16(i * 2, v)
	var stream := _wav(data)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = n
	return stream
