extends Node3D
## Stage-only helper. The combat owner supplies accepted lock events and validity.
## setup() parents a fresh helper to the bot or its raised weapon mount.
## Strictly increasing nonnegative cycle IDs are consumed once, including dropped cues.
## Duplicate/out-of-order IDs are ignored without cancelling a newer cycle.
## Call cancel_cycle() on attack/death/lock loss; shutdown() on permanent teardown.
## No bus/mixer changes. Four imported WAVs are required at the paths below.

signal cue_dropped(cycle_id: int, reason: String)
signal cue_started(cycle_id: int, gender: String, line_variant: String)

const LOCK_TO_SPEECH_SECONDS: float = 0.6
const VALIDITY_CHECK_SECONDS: float = 0.1
const MAX_SIMULTANEOUS_VOICES: int = 2
const CLIP_PATHS: Dictionary = {
	"male": {
		"deploy": "res://assets/audio/drone_tazer/male_deploy.wav",
		"disable": "res://assets/audio/drone_tazer/male_disable.wav",
	},
	"female": {
		"deploy": "res://assets/audio/drone_tazer/female_deploy.wav",
		"disable": "res://assets/audio/drone_tazer/female_disable.wav",
	},
}

# Shared by all instances of this script. Weak references cannot keep bots alive.
static var _global_voice_limit: int = MAX_SIMULTANEOUS_VOICES
static var _voice_slots: Dictionary = {}

var _configured: bool = false
var _stopped: bool = false
var _clearing: bool = false
var _gender: String = ""
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _actor_ref: WeakRef
var _still_valid: Callable
var _highest_consumed_cycle_id: int = -1
var _epoch: int = 0
var _pending_cycle_id: int = -1
var _pending_target: WeakRef
var _pending_variant: String = ""
var _playing_cycle_id: int = -1
var _playing_target: WeakRef
var _has_voice_slot: bool = false
var _delay_callback: Callable
var _delay_timer: Timer
var _active_guard: Timer
var _player: AudioStreamPlayer3D


## Configure once before spawning bots. Lowering the limit lets current clips finish.
## The hard global maximum is two voices. A full cap drops the eligible cue forever.
static func set_global_voice_limit(max_voices: int) -> void:
	_global_voice_limit = clampi(max_voices, 1, MAX_SIMULTANEOUS_VOICES)


## still_valid.call(cycle_id, target) must return bool and inspect owner combat state.
## It should cover current cycle/lock, both actors alive, attack, range and clear lane.
## Gender is selected once for this helper/bot life; optional_gender is male/female.
func setup(actor: Node3D, still_valid: Callable, optional_gender: String = "") -> void:
	if _configured or _stopped:
		push_warning("Drone tazer voice setup may only be called once per helper.")
		return
	if not is_instance_valid(actor) or not still_valid.is_valid():
		push_warning("Drone tazer voice requires a live actor and validity callable.")
		return
	if get_parent() != null and get_parent() != actor:
		push_warning("Parent drone tazer voice to its setup actor, or leave it unparented.")
		return
	_rng.randomize()
	_gender = optional_gender.strip_edges().to_lower()
	if _gender != "male" and _gender != "female":
		_gender = "male" if _rng.randi_range(0, 1) == 0 else "female"
	_actor_ref = weakref(actor)
	_still_valid = still_valid
	_create_children()
	_configured = true
	if get_parent() == null:
		actor.add_child(self)
	position = Vector3.ZERO
	actor.tree_exiting.connect(_on_actor_tree_exiting)


## The owner calls this after its confirmed targeting acquisition; no lift delay here.
## Duplicate notifications do not restart the delay or cancel a newer cycle.
func notify_lock_acquired(cycle_id: int, target: Node3D) -> void:
	if not _configured or _stopped or cycle_id < 0:
		return
	if cycle_id <= _highest_consumed_cycle_id:
		return
	_highest_consumed_cycle_id = cycle_id
	_clear_current_cue()
	var scheduled_epoch: int = _epoch
	if not _owner_still_valid(cycle_id, target):
		return
	if scheduled_epoch != _epoch or _stopped:
		return
	_pending_cycle_id = cycle_id
	_pending_target = weakref(target)
	_pending_variant = "deploy" if _rng.randi_range(0, 1) == 0 else "disable"
	_delay_callback = _on_delay_timeout.bind(scheduled_epoch)
	_delay_timer.timeout.connect(_delay_callback, CONNECT_ONE_SHOT)
	_delay_timer.start(LOCK_TO_SPEECH_SECONDS)
	_active_guard.start()


## A stale cancellation for an older cycle cannot stop the current cycle.
func cancel_cycle(cycle_id: int) -> void:
	if cycle_id == _pending_cycle_id or cycle_id == _playing_cycle_id:
		_clear_current_cue()


## Permanent, idempotent teardown; an exited helper cannot later replay a cue.
func shutdown() -> void:
	_stopped = true
	_clear_current_cue()
	var actor: Node3D = _get_node(_actor_ref)
	if actor != null and actor.tree_exiting.is_connected(_on_actor_tree_exiting):
		actor.tree_exiting.disconnect(_on_actor_tree_exiting)
	_still_valid = Callable()
	_actor_ref = null


func get_voice_gender() -> String:
	return _gender


func _create_children() -> void:
	_player = AudioStreamPlayer3D.new()
	_player.name = "DroneTazerSpeech"
	_player.volume_db = -6.0
	_player.max_db = -6.0
	_player.unit_size = 3.0
	_player.max_distance = 32.0
	_player.max_polyphony = 1
	_player.finished.connect(_on_voice_finished)
	add_child(_player)
	_delay_timer = Timer.new()
	_delay_timer.name = "LockSpeechDelay"
	_delay_timer.one_shot = true
	_delay_timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	add_child(_delay_timer)
	_active_guard = Timer.new()
	_active_guard.name = "SpeechValidityGuard"
	_active_guard.wait_time = VALIDITY_CHECK_SECONDS
	_active_guard.one_shot = false
	_active_guard.process_callback = Timer.TIMER_PROCESS_PHYSICS
	_active_guard.timeout.connect(_on_active_validity_timeout)
	add_child(_active_guard)


func _on_delay_timeout(scheduled_epoch: int) -> void:
	if scheduled_epoch != _epoch or _stopped:
		return
	_delay_callback = Callable()
	_active_guard.stop()
	var cycle_id: int = _pending_cycle_id
	var target: Node3D = _get_node(_pending_target)
	var line_variant: String = _pending_variant
	_pending_cycle_id = -1
	_pending_target = null
	_pending_variant = ""
	if not _owner_still_valid(cycle_id, target):
		return
	if scheduled_epoch != _epoch or _stopped:
		return
	var clip_path: String = CLIP_PATHS[_gender][line_variant]
	if not ResourceLoader.exists(clip_path):
		cue_dropped.emit(cycle_id, "missing_clip")
		return
	var clip: AudioStream = load(clip_path) as AudioStream
	if clip == null:
		cue_dropped.emit(cycle_id, "invalid_clip")
		return
	if not _try_acquire_voice_slot():
		cue_dropped.emit(cycle_id, "voice_cap_full")
		return
	_playing_cycle_id = cycle_id
	_playing_target = weakref(target)
	_player.stream = clip
	_player.play()
	_active_guard.start()
	cue_started.emit(cycle_id, _gender, line_variant)


# Pending delay and active speech check validity at 10 Hz; no idle/per-frame work.
func _on_active_validity_timeout() -> void:
	var current_epoch: int = _epoch
	var cycle_id: int = _playing_cycle_id
	var target_ref: WeakRef = _playing_target
	if cycle_id < 0:
		cycle_id = _pending_cycle_id
		target_ref = _pending_target
	if cycle_id < 0:
		_active_guard.stop()
		return
	var target: Node3D = _get_node(target_ref)
	var valid: bool = _owner_still_valid(cycle_id, target)
	if current_epoch != _epoch:
		return
	if not valid:
		_clear_current_cue()


func _owner_still_valid(cycle_id: int, target: Node3D) -> bool:
	if not _configured or _stopped or cycle_id < 0 or not is_inside_tree():
		return false
	var actor: Node3D = _get_node(_actor_ref)
	if actor == null or not actor.is_inside_tree() or not is_instance_valid(target):
		return false
	if not target.is_inside_tree() or not _still_valid.is_valid():
		return false
	return bool(_still_valid.call(cycle_id, target))


func _try_acquire_voice_slot() -> bool:
	for slot_id in _voice_slots.keys():
		var holder: WeakRef = _voice_slots[slot_id]
		var holder_node: Node = holder.get_ref() as Node
		if not is_instance_valid(holder_node) or not holder_node.is_inside_tree():
			_voice_slots.erase(slot_id)
	if _voice_slots.size() >= _global_voice_limit:
		return false
	_voice_slots[get_instance_id()] = weakref(self)
	_has_voice_slot = true
	return true


func _release_voice_slot() -> void:
	if _has_voice_slot:
		_voice_slots.erase(get_instance_id())
		_has_voice_slot = false


func _clear_current_cue() -> void:
	if _clearing:
		return
	_clearing = true
	_epoch += 1
	if is_instance_valid(_delay_timer):
		_delay_timer.stop()
		if _delay_callback.is_valid() and _delay_timer.timeout.is_connected(_delay_callback):
			_delay_timer.timeout.disconnect(_delay_callback)
	_delay_callback = Callable()
	if is_instance_valid(_active_guard):
		_active_guard.stop()
	if is_instance_valid(_player):
		_player.stop()
		_player.stream = null
	_release_voice_slot()
	_pending_cycle_id = -1
	_pending_target = null
	_pending_variant = ""
	_playing_cycle_id = -1
	_playing_target = null
	_clearing = false


func _on_voice_finished() -> void:
	_clear_current_cue()


func _on_actor_tree_exiting() -> void:
	shutdown()


func _exit_tree() -> void:
	if _configured:
		shutdown()


func _get_node(reference: WeakRef) -> Node3D:
	if reference == null:
		return null
	return reference.get_ref() as Node3D
