extends RefCounted
## How a drone gets about on broken legs. Each combination of lost legs has its own
## gait. One lost leg still runs, but in lurching pushes that can tip it over; two
## lost legs reduce it to a crawl whose shape depends on which pair is gone.
## Speeds are metres per second of chassis travel.
const PROFILES := {
	# One front leg gone: the nose has lost a prop, so each push pitches it forward.
	"three_front": {"speed":5.0,"lurch":.55,"period":.62,"stumble":.14,"turn":.85,"veer":.25,"pitch":2.6,"roll":2.2,"drop":.035,"lunge":.75,"rock":0.0},
	# One rear leg gone: it shoves off the good rear leg in short hops.
	"three_rear": {"speed":5.3,"lurch":.45,"period":.55,"stumble":.08,"turn":.9,"veer":.15,"pitch":2.2,"roll":2.2,"drop":.03,"lunge":.6,"rock":0.0},
	# Both front legs gone: nose down, the rear pair shoves it along in surges.
	"front_pair": {"speed":1.2,"lurch":.8,"period":1.15,"stumble":.05,"turn":.55,"veer":0.0,"pitch":7.5,"roll":0.0,"drop":.10,"lunge":.9,"rock":.02},
	# Both rear legs gone: the front pair hauls it forward, tail dragging.
	"rear_pair": {"speed":1.0,"lurch":.75,"period":1.0,"stumble":.04,"turn":.6,"veer":0.0,"pitch":7.0,"roll":0.0,"drop":.09,"lunge":.7,"rock":.02},
	# Both legs on one side gone: it lies on its stumps and crabs, pulling to that side.
	"same_side": {"speed":.85,"lurch":.6,"period":.9,"stumble":.10,"turn":.5,"veer":.55,"pitch":0.0,"roll":6.5,"drop":.08,"lunge":.55,"rock":.03},
	# Diagonal pair gone: nothing balances, so it rocks corner to corner and falls often.
	"diagonal": {"speed":1.3,"lurch":.7,"period":.8,"stumble":.22,"turn":.6,"veer":0.0,"pitch":2.0,"roll":2.0,"drop":.07,"lunge":.7,"rock":.09},
	# One leg left: it inches along on its belly.
	"one_leg": {"speed":.35,"lurch":.9,"period":1.6,"stumble":0.0,"turn":.35,"veer":.3,"pitch":3.0,"roll":3.0,"drop":.16,"lunge":.5,"rock":.03},
}
const STUMBLE_MIN := .9
const STUMBLE_MAX := 1.4
var style := "none"
var top_speed := INF
var lurch := 0.0
var period := 1.0
var stumble_chance := 0.0
var turn_scale := 1.0
var veer := 0.0
var pitch_scale := 1.0
var roll_scale := 1.0
var drop := 0.0
var lunge := 0.0
var rock := 0.0
# +1 when the lost legs are mostly on the left, -1 on the right, 0 balanced.
var side := 0.0
var phase := 0.0
var surge := 1.0
var stumble_time := 0.0
var stumble_duration := 0.0
var stumbles := 0

func active() -> bool:
	return style!="none"

func configure(broken: Array) -> void:
	var front:=0;var rear:=0;var left:=0;var right:=0
	for leg: String in broken:
		if leg.begins_with("F"): front+=1
		else: rear+=1
		if leg.ends_with("L"): left+=1
		else: right+=1
	side=signf(float(left-right))
	match broken.size():
		0: style="none"
		1: style="three_front" if front==1 else "three_rear"
		2:
			if front==2: style="front_pair"
			elif rear==2: style="rear_pair"
			elif left==2 or right==2: style="same_side"
			else: style="diagonal"
		_: style="one_leg"
	if style=="none":
		top_speed=INF;lurch=0.0;stumble_chance=0.0;turn_scale=1.0;veer=0.0;drop=0.0;rock=0.0;surge=1.0
		return
	var profile: Dictionary=PROFILES[style]
	top_speed=profile.speed;lurch=profile.lurch;period=profile.period
	stumble_chance=profile.stumble;turn_scale=profile.turn;veer=profile.veer
	pitch_scale=profile.pitch;roll_scale=profile.roll;drop=profile.drop;lunge=profile.lunge;rock=profile.rock

## Advance the push cycle. Returns true on the tick a new push starts.
func step(delta: float, speed_fraction: float, driving: bool) -> bool:
	if not active(): return false
	if stumble_time>0.0:
		stumble_time=maxf(0.0,stumble_time-delta)
		surge=0.0
		return false
	if not driving:
		# Standing, it settles; the next push starts fresh.
		phase=0.0;surge=1.0-lurch*.85
		return false
	var before:=phase
	phase=fposmod(phase+delta/period,1.0)
	# A sharp push through the first 40% of the cycle, then a dragging glide.
	var push:=sin(PI*phase/.4) if phase<.4 else 0.0
	surge=(1.0-lurch*.85)+lurch*1.5*push
	var started:=phase<before
	if started and speed_fraction>.6 and randf()<stumble_chance:
		stumble_duration=randf_range(STUMBLE_MIN,STUMBLE_MAX);stumble_time=stumble_duration
		stumbles+=1
	return started

func stumbling() -> bool:
	return stumble_time>0.0

## 0 standing, 1 flat on the ground: a quick collapse, a beat down, a push back up.
func stumble_weight() -> float:
	if stumble_time<=0.0 or stumble_duration<=0.0: return 0.0
	var u:=1.0-stumble_time/stumble_duration
	return smoothstep(0.0,.15,u)*(1.0-smoothstep(.55,1.0,u))
