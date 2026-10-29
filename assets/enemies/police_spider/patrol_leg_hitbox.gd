extends Area3D
## Ray weapons must enable collide_with_areas and include layer 3 (mask value 4).
var actor: CharacterBody3D
var leg := ""

func take_damage(amount: float, source: Node = null) -> void:
	if not is_instance_valid(actor) or actor.dead: return
	if leg.is_empty(): actor.take_damage(amount,source)
	else: actor.damage_leg(leg,amount,source)
