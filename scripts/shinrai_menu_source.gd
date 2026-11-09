extends RefCounted
## Operations-menu source for the boot phase, before ExtractionRun exists.
## It reads the profile without ever writing it (ExtractionRun owns all saves),
## keeps the player's time-of-day / graphics choice and a requested deploy, and
## hands those over to ExtractionRun the moment it takes the menu.
signal handed_over(raid: Node)

const Profile = preload("./extraction_profile.gd")
const LoadState = preload("./shinrai_load_state.gd")
## Kept in profile.last_error for the whole lifetime of this source: save_profile()
## refuses to write while any error is set, so nothing here can touch the save.
const READ_ONLY_GUARD := "Menu preview: the profile is read only until the park is ready."
const EARLY_ACTIONS := ["deploy", "time", "graphics", "controls", "quit_confirm", "quit_cancel", "quit_desktop"]

var profile := Profile.new()
var load_error := ""
var night := false
var high_quality := false
var deploy_requested := false
## Set by the boot host when the window loses focus while deploy_requested;
## ExtractionRun then starts the raid paused (as for its own queued deploys).
var focus_lost := false
## The early quit confirmation is open; ExtractionRun reopens its own on handover.
var quit_open := false
## Same name as ExtractionRun's flag, read by the menu for "DEPLOY QUEUED".
var deploy_queued: bool:
	get: return deploy_requested
var raid: Node

func load_from(path: String) -> void:
	profile.save_path = path
	profile.last_error = READ_ONLY_GUARD
	profile.load_profile()
	load_error = "" if profile.last_error == READ_ONLY_GUARD else profile.last_error
	profile.last_error = READ_ONLY_GUARD

func hand_over(target: Node) -> void:
	raid = target
	handed_over.emit(target)

func menu_profile() -> Dictionary:
	return profile.data

func menu_world_ready() -> bool:
	return false

func menu_can(action: String) -> bool:
	# DEPLOY is available early: pressing it queues until the park is ready.
	# An unreadable save keeps it disabled, exactly as in the HQ menu.
	if action == "deploy": return load_error.is_empty()
	return action in EARLY_ACTIONS

func menu_night() -> bool:
	return night

func menu_high_quality() -> bool:
	return high_quality

func menu_last_error() -> String:
	return load_error

func menu_recovered_interrupted_run() -> bool:
	return profile.recovered_interrupted_run

func menu_progress() -> float:
	return LoadState.fraction

func menu_stage() -> String:
	return LoadState.stage
