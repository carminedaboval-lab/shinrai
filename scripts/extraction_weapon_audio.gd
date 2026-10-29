extends Node
## First-person mechanical foley. Gameplay owns whether an action succeeded;
## this node never changes ammo, timing, reload state or enemy hearing.

signal event_played(event_name: String, weapon_id: String)

const VOICE_COUNT := 6
const CLIP_ROOT := "res://assets/audio/weapon_mechanics/"
const EVENTS := ["magazine_out", "magazine_in", "bolt_open", "bolt_close", "dry_fire"]
const BASE_VOLUME_DB := -10.0

# Cache once for this player's lifetime. ResourceLoader shares streams with
# other live instances; no static reference keeps them alive after teardown.
var _stream_cache: Dictionary = {}
var enabled := true
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0

func _ready() -> void:
	_load_streams()
	if not _voices.is_empty():
		return
	for index: int in range(VOICE_COUNT):
		var voice := AudioStreamPlayer.new()
		voice.name = "MechanicalVoice%d" % index
		voice.bus = "Master"
		voice.max_polyphony = 1
		add_child(voice)
		_voices.append(voice)

func _load_streams() -> void:
	for event_name: String in EVENTS:
		if _stream_cache.has(event_name):
			continue
		var path := CLIP_ROOT + event_name + ".wav"
		if not ResourceLoader.exists(path):
			continue
		var stream := ResourceLoader.load(path) as AudioStream
		if stream != null:
			_stream_cache[event_name] = stream

func play_event(event_name: String, weapon_id: String) -> bool:
	if not enabled or weapon_id.is_empty() or not is_inside_tree() or _voices.is_empty() or not _stream_cache.has(event_name):
		return false
	# Reuse an idle voice first, then steal the oldest slot when the bounded pool
	# is saturated. No delayed sounds can play after a cancelled action.
	var selected := _next_voice
	for offset: int in range(_voices.size()):
		var index := (_next_voice + offset) % _voices.size()
		if not _voices[index].playing:
			selected = index
			break
	var voice := _voices[selected]
	_next_voice = (selected + 1) % _voices.size()
	voice.stop()
	voice.stream = _stream_cache[event_name]
	var profile := _profile(weapon_id)
	voice.pitch_scale = profile.x
	voice.volume_db = BASE_VOLUME_DB + profile.y - (2.0 if event_name == "dry_fire" else 0.0)
	voice.play()
	event_played.emit(event_name, weapon_id)
	return true

func reset() -> void:
	for voice: AudioStreamPlayer in _voices:
		if is_instance_valid(voice):
			voice.stop()
	_next_voice = 0

static func _profile(weapon_id: String) -> Vector2:
	match weapon_id:
		"uzi": return Vector2(1.09, -0.8)
		"shigure": return Vector2(1.04, -0.4)
		"kite": return Vector2(0.98, 0.0)
		"raiden_r56": return Vector2(1.0, 0.0)
		"tobikage": return Vector2(0.96, 0.0)
		"hayate": return Vector2(0.94, 0.3)
		"yuzuru": return Vector2(0.91, 0.4)
	return Vector2(1.0, 0.0)

func _exit_tree() -> void:
	reset()
	for voice: AudioStreamPlayer in _voices:
		if is_instance_valid(voice):
			voice.stream = null
	_stream_cache.clear()
	# A retained player can leave and re-enter the tree without recreating its
	# voices. Reload streams on re-entry instead of leaving a silent node.
	request_ready()
