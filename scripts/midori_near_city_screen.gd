extends Node
## Plays the rooftop screen. Change what it shows by changing PLAYLIST and its sheet.
## The loop is a stand-in. Once trains and stations exist the screen becomes a live board:
## when the next train reaches which station, then the direction to it from this screen.
const FADE := 1.1
# Still in the sheet, seconds on screen.
const PLAYLIST: Array[Array] = [[0, 9.0], [1, 8.0], [2, 8.0], [3, 8.0]]

var _look: ShaderMaterial
var _clip := 0
var _clock := 0.0

func play_on(look: ShaderMaterial) -> void:
	_look = look

func _process(delta: float) -> void:
	if _look == null: return
	_clock += delta
	var hold: float = PLAYLIST[_clip][1]
	if _clock >= hold:
		_clock -= hold
		_clip = (_clip + 1) % PLAYLIST.size()
		hold = PLAYLIST[_clip][1]
	_look.set_shader_parameter("still_a", float(PLAYLIST[_clip][0]))
	_look.set_shader_parameter("still_b", float(PLAYLIST[(_clip + 1) % PLAYLIST.size()][0]))
	_look.set_shader_parameter("wipe", clampf((_clock - hold + FADE) / FADE, 0.0, 1.0))
