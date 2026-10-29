extends Node
## Body HP and the four leg pools are independent; leg hits never drain body HP.
signal health_changed(total: float)
signal leg_damaged(leg: String, remaining: float)
signal leg_destroyed(leg: String)
signal destroyed
const LEG_HP := 25.0
const MAX_HP := 100.0
const LEGS := ["FL","FR","RL","RR"]
var leg_hp: Dictionary = {"FL":LEG_HP,"FR":LEG_HP,"RL":LEG_HP,"RR":LEG_HP}
var body_hp := MAX_HP
var dead := false

func total_hp() -> float:
	return body_hp

func damage_body(amount: float) -> float:
	if dead or not is_finite(amount) or amount<=0: return 0.0
	var applied:=minf(body_hp,amount)
	body_hp-=applied;dead=body_hp<=0
	health_changed.emit(body_hp)
	if dead: destroyed.emit()
	return applied

func intact_legs() -> int:
	var count:=0
	for leg: String in LEGS:
		if float(leg_hp[leg])>0: count+=1
	return count

func damage_leg(leg: String, amount: float) -> float:
	if dead or not leg_hp.has(leg) or not is_finite(amount) or amount<=0: return 0.0
	var before:=float(leg_hp[leg])
	var applied:=minf(before,amount)
	if applied<=0: return 0.0
	leg_hp[leg]=before-applied
	leg_damaged.emit(leg,float(leg_hp[leg]))
	if float(leg_hp[leg])<=0: leg_destroyed.emit(leg)
	return applied
