extends RefCounted
## Per-raid health. Tarkov's seven-part maxima + 3 HP; user-set head is 30 HP.
## Wound rates/chances are Shinrai game balance, not medical advice.
const PARTS := ["head", "thorax", "stomach", "left_arm", "right_arm", "left_leg", "right_leg"]
const MAX_HP := {"head":30.0, "thorax":88.0, "stomach":73.0, "left_arm":63.0, "right_arm":63.0, "left_leg":68.0, "right_leg":68.0}
const LABELS := {"head":"Head", "thorax":"Thorax", "stomach":"Stomach", "left_arm":"Left arm", "right_arm":"Right arm", "left_leg":"Left leg", "right_leg":"Right leg"}
const TOTAL_HP := 453.0
const TREATMENTS := {
	"bandage":{"title":"Bandage", "seconds":3.0, "effect":"Stops light bleeding"},
	"tourniquet":{"title":"Tourniquet", "seconds":5.0, "effect":"Stops heavy bleeding"},
	"splint":{"title":"Splint", "seconds":5.0, "effect":"Treats a fractured limb"},
	"medkit":{"title":"Medkit", "seconds":2.5, "effect":"Restores up to 55 HP to one part"}
}
var blood := 100.0
var hp: Dictionary = {}
var bleeding: Dictionary = {}
var fractures: Dictionary = {}

func _init() -> void:
	reset()

func reset() -> void:
	blood = 100.0
	hp = MAX_HP.duplicate()
	bleeding.clear()
	fractures.clear()
	for part: String in PARTS:
		bleeding[part] = 0
		fractures[part] = false

func total_hp() -> float:
	var value := 0.0
	for part: String in PARTS: value += float(hp[part])
	return value

func effective_hp() -> float:
	return 0.0 if is_dead() else total_hp() * clampf(blood / 100.0,0.0,1.0)

func is_dead() -> bool:
	return blood <= 0.0 or float(hp.head) <= 0.0 or float(hp.thorax) <= 0.0

static func is_limb(part: String) -> bool:
	return part.ends_with("_arm") or part.ends_with("_leg")

static func hit_part(roll: float) -> String:
	# Legacy capsule-only callers have no anatomical hit point. Weighted fallback;
	# new callers should pass the real part to player.take_damage(amount, part).
	var r := clampf(roll, 0.0, 1.0)
	if r < .08: return "head"
	if r < .36: return "thorax"
	if r < .52: return "stomach"
	if r < .64: return "left_arm"
	if r < .76: return "right_arm"
	if r < .88: return "left_leg"
	return "right_leg"

func damage(part: String, amount: float, wound_roll: float = 1.0, fracture_roll: float = 1.0) -> float:
	if not hp.has(part) or not is_finite(amount) or amount <= 0.0 or is_dead(): return 0.0
	var before := total_hp()
	var local_damage := minf(float(hp[part]), amount)
	hp[part] = maxf(0.0, float(hp[part]) - local_damage)
	var overflow := amount - local_damage
	if overflow > 0.0 and part not in ["head", "thorax"]:
		_distribute(overflow)
	if amount >= 8.0 and wound_roll < .35:
		bleeding[part] = maxi(int(bleeding[part]), 2 if amount >= 16.0 else 1)
	if is_limb(part) and amount >= 15.0 and fracture_roll < .30:
		fractures[part] = true
	return before - total_hp()

func _distribute(amount: float) -> void:
	# Equal overflow across remaining nonzero parts, retaining damage conservation.
	var pending := amount
	for _pass: int in range(PARTS.size()):
		var living: Array[String] = []
		for part: String in PARTS:
			if float(hp[part]) > 0.0: living.append(part)
		if living.is_empty() or pending <= .00001: break
		var share := pending / living.size()
		pending = 0.0
		for part: String in living:
			var dealt := minf(float(hp[part]), share)
			hp[part] = maxf(0.0, float(hp[part]) - dealt)
			pending += share - dealt

func _recover_tissue(amount: float) -> void:
	# Share one total healing budget; never regrow destroyed parts or mend fractures.
	var pending := amount
	for _pass: int in range(PARTS.size()):
		var injured: Array[String] = []
		for part: String in PARTS:
			if float(hp[part]) > 0.0 and float(hp[part]) < float(MAX_HP[part]) and not bool(fractures[part]): injured.append(part)
		if injured.is_empty() or pending <= .00001: break
		var share := pending / injured.size()
		pending = 0.0
		for part: String in injured:
			var gain := minf(float(MAX_HP[part])-float(hp[part]),share)
			hp[part] = minf(float(MAX_HP[part]),float(hp[part])+gain)
			pending += share-gain

func tick(delta: float, recover_blood: bool = false, blood_multiplier: float = 1.0, tissue_rate: float = 0.0) -> float:
	if is_dead() or not is_finite(delta) or delta <= 0.0: return 0.0
	var rate := 0.0
	for part: String in PARTS:
		rate += 1.5 if int(bleeding[part]) == 2 else .4 if int(bleeding[part]) == 1 else 0.0
	var before := effective_hp()
	blood = clampf(blood - rate / TOTAL_HP * 100.0 * delta,0.0,100.0)
	_distribute(rate * delta)
	# Wound treatment stops the source; it does not refill lost blood.
	if rate <= 0.0 and recover_blood and not is_dead():
		if is_finite(blood_multiplier):
			blood = minf(100.0,blood + 0.006 * clampf(blood_multiplier,0.0,3.0) * delta)
	# Stable, well-supplied survivors recover slowly; severe injuries need treatment.
	var condition := total_hp()/TOTAL_HP
	if rate <= 0.0 and not is_dead() and condition >= 0.60 and blood >= 75.0 and is_finite(tissue_rate) and tissue_rate > 0.0:
		var body_factor := lerpf(0.5,1.0,clampf((condition-0.60)/0.40,0.0,1.0))
		var blood_factor := lerpf(0.5,1.0,clampf((blood-75.0)/25.0,0.0,1.0))
		_recover_tissue(clampf(tissue_rate,0.0,0.10)*body_factor*blood_factor*delta)
	return before - effective_hp()

func can_treat(item: String, part: String) -> bool:
	if is_dead() or not hp.has(part): return false
	match item:
		"bandage": return int(bleeding[part]) == 1
		"tourniquet": return int(bleeding[part]) == 2
		"splint": return is_limb(part) and bool(fractures[part])
		"medkit": return float(hp[part]) > 0.0 and float(hp[part]) < float(MAX_HP[part])
	return false

func treat(item: String, part: String) -> bool:
	if not can_treat(item, part): return false
	match item:
		"bandage", "tourniquet": bleeding[part] = 0
		"splint": fractures[part] = false
		"medkit": hp[part] = minf(float(MAX_HP[part]), float(hp[part]) + 55.0)
	return true

func treatment_target(item: String) -> String:
	var target := ""
	var lowest := INF
	for part: String in PARTS:
		if not can_treat(item, part): continue
		var ratio := float(hp[part]) / float(MAX_HP[part])
		if item == "medkit" and part in ["head", "thorax"]: ratio -= 1.0
		if ratio < lowest:
			lowest = ratio
			target = part
	return target

func leg_impaired() -> bool:
	return bool(fractures.left_leg) or bool(fractures.right_leg) or float(hp.left_leg) <= 0.0 or float(hp.right_leg) <= 0.0

func arm_impaired() -> bool:
	return bool(fractures.left_arm) or bool(fractures.right_arm) or float(hp.left_arm) <= 0.0 or float(hp.right_arm) <= 0.0

func part_status(part: String) -> String:
	if not hp.has(part): return ""
	var states: PackedStringArray = []
	if float(hp[part]) <= 0.0: states.append("DESTROYED")
	if int(bleeding[part]) == 2: states.append("HEAVY BLEED")
	elif int(bleeding[part]) == 1: states.append("LIGHT BLEED")
	if bool(fractures[part]): states.append("FRACTURE")
	return " / ".join(states) if not states.is_empty() else "INJURED" if float(hp[part]) < float(MAX_HP[part]) else "HEALTHY"

func summary() -> String:
	var light := 0
	var heavy := 0
	var broken := 0
	var destroyed := 0
	var injured := 0
	for part: String in PARTS:
		if int(bleeding[part]) == 1: light += 1
		if int(bleeding[part]) == 2: heavy += 1
		if bool(fractures[part]): broken += 1
		if float(hp[part]) <= 0.0: destroyed += 1
		elif float(hp[part]) < float(MAX_HP[part]): injured += 1
	var labels: PackedStringArray = []
	if heavy > 0: labels.append("HEAVY BLEED %d" % heavy)
	if light > 0: labels.append("LIGHT BLEED %d" % light)
	if broken > 0: labels.append("FRACTURE %d" % broken)
	if destroyed > 0: labels.append("DESTROYED %d" % destroyed)
	if injured > 0: labels.append("INJURED %d" % injured)
	return " / ".join(labels) if not labels.is_empty() else "HEALTHY"
