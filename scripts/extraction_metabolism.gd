extends RefCounted
## Fictional per-raid reserves, not a physiological model. Rates are game balance.
const Food = preload("./extraction_food_condition.gd")
const Cans = preload("./extraction_canned_food.gd")
const BASE_ENERGY := 0.006
const BASE_FOOD := 0.004
const BASE_WATER := 0.007
const SOLID_IDS := ["garden_mikan", "garden_persimmon", "ration_bar"] + Cans.OPENED_IDS
const FOOD_INTOLERANCE_SECONDS := 60.0
const FOOD_TIMER_EPSILON := 0.000001
const PROVISIONS := {
	"canned_mackerel_open":{"food":35.0,"water":-5.0,"energy":12.0},
	"canned_peaches_open":{"food":25.0,"water":20.0,"energy":8.0},
	"garden_mikan":{"food":10.0,"water":10.0,"energy":4.0},
	"garden_persimmon":{"food":14.0,"water":8.0,"energy":5.0},
	"ration_bar":{"food":35.0,"water":0.0,"energy":25.0},
	"bottled_water_closed":{"food":0.0,"water":35.0,"energy":0.0},
	"bottled_water_open":{"food":0.0,"water":18.0,"energy":0.0},
	"sports_bottle_closed":{"food":0.0,"water":40.0,"energy":3.0},
	"sports_bottle_open":{"food":0.0,"water":20.0,"energy":2.0},
	"coffee_cup":{"food":0.0,"water":8.0,"energy":5.0}
}
# Persisted independently from transient raid cargo; no offline illness clock.
var food_poison_remaining := 0.0
var food_poison_severity := 0.0
var food_intolerance_remaining := 0.0
var last_meal_rejected := false
var _poison_pulse_elapsed := 0.0
var _pending_vomit_stamina := 0.0
var vomit_events := 0
var energy := 100.0
var food := 100.0
var hydration := 100.0
var heart_rate := 68.0
var cardiac_load := 0.0
var stress_remaining := 0.0
var consumption_multiplier := 1.0

func reset() -> void:
	food_poison_remaining=0.0
	food_poison_severity=0.0
	food_intolerance_remaining=0.0
	last_meal_rejected=false
	_poison_pulse_elapsed=0.0
	_pending_vomit_stamina=0.0
	vomit_events=0
	energy=100.0
	food=100.0
	hydration=100.0
	heart_rate=68.0
	cardiac_load=0.0
	stress_remaining=0.0
	consumption_multiplier=1.0

func stress(seconds: float = 6.0) -> void:
	if is_finite(seconds): stress_remaining=maxf(stress_remaining,clampf(seconds,0.0,30.0))

static func target_heart_rate(context: Dictionary) -> float:
	var health := clampf(float(context.get("health_ratio",1.0)),0.0,1.0)
	if health<=0.0:return 0.0
	var combat := bool(context.get("combat",false))
	if bool(context.get("healing",false)):return 118.0 if combat else 78.0
	var rate := (152.0 if health<.35 else 136.0 if health<.999 else 112.0) if combat else (100.0 if health<.35 else 88.0 if health<.999 else 68.0)
	if bool(context.get("sprinting",false)):rate+=18.0
	elif bool(context.get("moving",false)):rate+=6.0
	if bool(context.get("swimming",false)):rate+=14.0
	if bool(context.get("mantling",false)):rate+=20.0
	if bool(context.get("exhausted",false)):rate+=10.0
	return minf(rate,170.0)

func tick(delta: float, context: Dictionary) -> void:
	if not is_finite(delta) or delta<=0.0:return
	# Integrate ordinary and delayed frames identically; no render/UI clock input.
	var remaining := delta
	var stamina_spent := maxf(0.0,float(context.get("stamina_spent",0.0)))
	while remaining>0.000001:
		var step := minf(remaining,0.05)
		remaining-=step
		_tick_food_illness(step)
		var active := context.duplicate()
		active.combat=bool(active.get("combat",false)) or stress_remaining>0.0
		stress_remaining=maxf(0.0,stress_remaining-step)
		var target := target_heart_rate(active)
		heart_rate=move_toward(heart_rate,target,step*(32.0 if target>heart_rate else 18.0))
		var target_load := clampf((heart_rate-68.0)/102.0,0.0,1.0)
		cardiac_load=lerpf(cardiac_load,target_load,1.0-exp(-step/12.0))
		consumption_multiplier=1.0+0.6*cardiac_load
		var activity := 1.0 if bool(active.get("moving",false)) else 0.0
		if bool(active.get("sprinting",false)):activity=maxf(activity,3.0)
		if bool(active.get("swimming",false)):activity=maxf(activity,2.5)
		if bool(active.get("mantling",false)):activity=maxf(activity,4.0)
		var scarcity := 1.0+(0.2 if food<20.0 else 0.0)+(0.2 if hydration<20.0 else 0.0)
		var action_cost := stamina_spent/delta*0.012
		energy=clampf(energy-((BASE_ENERGY+activity*.005)*scarcity+action_cost)*consumption_multiplier*step,0.0,100.0)
		food=clampf(food-(BASE_FOOD+activity*.002)*consumption_multiplier*step,0.0,100.0)
		hydration=clampf(hydration-(BASE_WATER+activity*.006)*consumption_multiplier*step,0.0,100.0)

func can_consume(id: String) -> bool:
	return can_consume_item({"id":id})

func consume(id: String) -> bool:
	return consume_item({"id":id})

func can_consume_item(item: Dictionary) -> bool:
	var id := str(item.get("id",""))
	if not PROVISIONS.has(id): return false
	# A deliberate solid meal while nauseous is consumed, then rejected.
	if id in SOLID_IDS and nausea_remaining()>0.0: return true
	var gain: Dictionary=PROVISIONS[id]
	var effect: Dictionary=Food.effects(item)
	# Deliberately eating unsafe food is possible even at full reserves.
	if float(effect.get("sickness_seconds",0.0))>0.0: return true
	return (float(gain.food)>0.0 and food<100.0) or (float(gain.water)>0.0 and hydration<100.0) or (float(gain.energy)>0.0 and energy<100.0)

func consume_item(item: Dictionary) -> bool:
	last_meal_rejected=false
	if not can_consume_item(item): return false
	var id := str(item.id)
	var was_nauseous := nausea_remaining()>0.0
	var gain: Dictionary=PROVISIONS[id]
	var effect: Dictionary=Food.effects(item)
	var duration := float(effect.sickness_seconds)
	if duration>0.0:
		food_poison_remaining=minf(Food.MAX_SICKNESS_SECONDS,food_poison_remaining+duration)
		food_poison_severity=maxf(food_poison_severity,float(effect.sickness_severity))
	if was_nauseous and id in SOLID_IDS:
		last_meal_rejected=true
		_emit_vomit(nausea_severity())
		food_intolerance_remaining=FOOD_INTOLERANCE_SECONDS
		# This meal already caused one pulse; restart the periodic clock.
		_poison_pulse_elapsed=0.0
		return true
	food=clampf(food+float(gain.food)*float(effect.food_multiplier),0.0,100.0)
	hydration=clampf(hydration+float(gain.water)*float(effect.water_multiplier),0.0,100.0)
	energy=clampf(energy+float(gain.energy)*float(effect.energy_multiplier),0.0,100.0)
	return true

func _tick_food_illness(delta: float) -> void:
	# Settling blocks solids/recovery but has no automatic losses or pulses.
	food_intolerance_remaining=maxf(0.0,food_intolerance_remaining-delta)
	if food_intolerance_remaining<=FOOD_TIMER_EPSILON: food_intolerance_remaining=0.0
	if food_poison_remaining<=0.0:
		_poison_pulse_elapsed=0.0
		return
	var severity := food_poison_severity
	var poisoned := minf(delta,food_poison_remaining)
	food=maxf(0.0,food-poisoned*.025*food_poison_severity)
	hydration=maxf(0.0,hydration-poisoned*.04*food_poison_severity)
	energy=maxf(0.0,energy-poisoned*.02*food_poison_severity)
	food_poison_remaining=maxf(0.0,food_poison_remaining-delta)
	if food_poison_remaining<=FOOD_TIMER_EPSILON: food_poison_remaining=0.0
	_poison_pulse_elapsed+=poisoned
	while _poison_pulse_elapsed+FOOD_TIMER_EPSILON>=30.0:
		_poison_pulse_elapsed=maxf(0.0,_poison_pulse_elapsed-30.0)
		_emit_vomit(severity)
	if food_poison_remaining<=0.0:
		food_poison_severity=0.0
		_poison_pulse_elapsed=0.0

func _emit_vomit(severity: float) -> void:
	if not is_finite(severity) or severity<=0.0: return
	var strength := clampf(severity,0.0,2.0)
	food=maxf(0.0,food-3.0*strength)
	hydration=maxf(0.0,hydration-4.0*strength)
	energy=maxf(0.0,energy-2.0*strength)
	vomit_events+=1
	_pending_vomit_stamina+=12.0*strength

func take_vomit_stamina() -> float:
	var pending := _pending_vomit_stamina
	_pending_vomit_stamina=0.0
	return pending

func nausea_remaining() -> float:
	return maxf(food_poison_remaining,food_intolerance_remaining)

func nausea_severity() -> float:
	if food_poison_remaining>0.0: return food_poison_severity
	return 1.0 if food_intolerance_remaining>0.0 else 0.0

func illness_label() -> String:
	return "NAUSEA" if nausea_remaining()>0.0 else ""

func illness_snapshot() -> Dictionary:
	return {"remaining":food_poison_remaining,"severity":food_poison_severity,"pulse_elapsed":_poison_pulse_elapsed,"intolerance_remaining":food_intolerance_remaining} if nausea_remaining()>0.0 else {}

func restore_illness(snapshot: Dictionary) -> void:
	var duration := float(snapshot.get("remaining",0.0))
	var severity := float(snapshot.get("severity",0.0))
	var pulse := float(snapshot.get("pulse_elapsed",0.0))
	var intolerance := float(snapshot.get("intolerance_remaining",0.0))
	food_poison_remaining=clampf(duration,0.0,Food.MAX_SICKNESS_SECONDS) if is_finite(duration) else 0.0
	food_poison_severity=clampf(severity,0.0,2.0) if is_finite(severity) else 0.0
	food_intolerance_remaining=clampf(intolerance,0.0,FOOD_INTOLERANCE_SECONDS) if is_finite(intolerance) else 0.0
	_poison_pulse_elapsed=clampf(pulse,0.0,30.0) if is_finite(pulse) else 0.0
	_pending_vomit_stamina=0.0
	last_meal_rejected=false
	if food_poison_remaining<=0.0 or food_poison_severity<=0.0:
		food_poison_remaining=0.0
		food_poison_severity=0.0
		_poison_pulse_elapsed=0.0

func can_recover_blood() -> bool:
	return nausea_remaining()<=0.0 and food >= 35.0 and hydration >= 35.0 and energy >= 20.0

func blood_recovery_multiplier() -> float:
	if not can_recover_blood(): return 0.0
	# The lower reserve limits recovery: food cannot compensate for dehydration.
	return lerpf(1.0,3.0,clampf((minf(food,hydration)-35.0)/65.0,0.0,1.0))

func health_recovery_rate() -> float:
	if nausea_remaining()>0.0 or food < 65.0 or hydration < 65.0 or energy < 30.0: return 0.0
	# Total tissue HP per second, before body-condition and blood modifiers.
	return lerpf(0.03,0.10,clampf((minf(food,hydration)-65.0)/35.0,0.0,1.0))
