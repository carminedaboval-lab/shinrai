extends RefCounted
## Optional diagnostic output, activated only with --profile-startup after --.
static var enabled := "--profile-startup" in OS.get_cmdline_user_args()
static var events: Array[Dictionary] = []

static func begin() -> int:
	return Time.get_ticks_usec() if enabled else 0

static func finish(stage: String, started: int) -> int:
	if not enabled: return 0
	var now := Time.get_ticks_usec()
	var event := {"stage":stage,"duration_ms":float(now-started)/1000.0,"engine_elapsed_ms":float(now)/1000.0}
	events.append(event)
	print("STARTUP_PROFILE ",JSON.stringify(event))
	return now
