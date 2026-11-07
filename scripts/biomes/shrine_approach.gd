extends RefCounted
## Sando 参道, the tended shrine approach round the south-east landmark plaza
## (docs/biome_concepts/after_shrine_approach.png and
## extra/after_shrine_approach_reverse.png). The one place in the lapsed park
## that is still kept. The ground look map already lays the rich, dark, short
## turf (care 0); this builder adds what stands on it:
##  - brushed, warm granite painted directly onto the ground from the arrival
##    point to the existing north plaza apron,
##  - a vermilion myojin torii at the original central monument socket, visible
##    through the north entrance and south court, with an open walk-through span,
##  - Kasuga stone lanterns lining the approach in irregular pairs, with a
##    soft static glow in the chamber (no light nodes, no per-frame scripts),
##  - clipped karikomi mounds (satsuki, boxwood, holly) in loose groups of
##    2 to 7: low red and pale-pink azalea drifts in the turf round the outer
##    end of the approach, banks behind the lanterns and groups scattered
##    round the crescent of turf,
##  - a few set garden stones by the torii and some groups, moss at their feet.
## The spiky fountain grass and woodland fill mostly go; lawn blades thin a
## little; wild ferns and floor bushes thin out. Nothing is laid on a grid or
## in a line, and all thinning is a dithered pick by weight, so edges feather.
const Biomes := preload("res://scripts/midori_biomes.gd")
const Kit := preload("res://scripts/biomes/biome_kit.gd")
const ClippedShrubs := preload("res://scripts/midori_clipped_shrubs.gd")
const ID := "sando"
const CENTRE := Vector2(168, 128)
const RADII := Vector2(46, 40)
# Region bounds plus the feather, for cheap early-outs.
const RECT := Rect2(113, 79, 110, 98)
# Plaza centre x, z and outer radius, used when the plaza mesh is not found.
const PLAZA_FALLBACK := Vector3(164, 136, 31.0)
const FLOOR := "res://assets/shinrai/parks/midori_park/models/forest_floor_20261026/"
const MOSS := "res://assets/shinrai/parks/midori_park/models/island_nature/moss_%02d.glb"
const LANTERN := "res://assets/shinrai/parks/midori_park/models/stone_lantern/kasuga_lantern.glb"
const LANTERN_DATA := "res://assets/shinrai/parks/midori_park/models/stone_lantern/measurements.json"
const THIN_ALL := "res://scripts/biomes/thin_all.gd"
# Ground-painted approach, from the large boulder's shoulder to the north apron.
const PAVE_HALF := 2.34
const MAX_LANTERNS := 18
const MAX_BANK_GROUPS := 10
const MAX_RING_GROUPS := 14
# Planting round the plaza's outer rim on the turf, seen from the plaza's south
# side (the reverse view): niwaki, azalea drifts and karikomi, some lanterns.
const MAX_RIM_GROUPS := 28
const MAX_RIM_LANTERNS := 6
# The reverse view (eye (164, 165) looking north): a second, smaller torii far
# across the plaza a little right of the monument, out of the approach view.
const REVERSE_EYE := Vector2(164, 165)
const APPROACH_EYE := Vector2(164, 95)
const NIWAKI_BARK := Color(0.2, 0.165, 0.135)
# Where the walk arrives at the approach (the review eye): lanterns keep this
# standing spot open, so no lamp stands at the walker's elbow.
const ARRIVAL := Vector2(164, 95)
const ARRIVAL_CLEAR := 2.2
# Azalea and karikomi drifts round the outer end of the approach, per side.
const MAX_DRIFTS_PER_SIDE := 6
# Mound group kinds.
const RING := 0
const BANK := 1
const DRIFT := 2
const RIM := 3
# Moss fronds are 2 to 4 cm pieces; island stones carry about 1,300 each.
const MOSS_CAP := 12000
# Torii proportions (metres): pillar spacing centre to centre.
const TORII_SPAN := 3.44
# Shell visibility, as the clipped shrubs use them: fringe first, core last.
const SHELL_RANGES := [160.0, 70.0, 40.0]

## Satsuki in flower: the clipped-shrub look with single round blooms in a
## coarser jittered world-space cell set, mostly on the upper faces.
const BLOOM_SHADER := """
shader_type spatial;
render_mode diffuse_burley, cull_disabled;
uniform float shell = 0.0;
uniform float leaf_size = 0.028;
uniform float flower_size = 0.080;
uniform float bloom = 0.55;
uniform vec3 petal_a : source_color = vec3(0.63, 0.16, 0.24);
uniform vec3 petal_b : source_color = vec3(0.74, 0.3, 0.38);
varying vec3 garden;
varying vec4 tint;

vec3 seed3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

// A cut through a jittered three-dimensional blossom, including on a vertical
// mound face. The soft, lobed head fits inside its cell, so adjacent cells join
// in foliage. The second set of centres fills the gaps at a different spacing.
vec2 floret(vec3 position, float chance, float softness) {
	vec3 pick = seed3(floor(position));
	vec3 offset = fract(position) - 0.5 - (pick - 0.5) * 0.23;
	float distance_to_seed = length(offset);
	vec3 lobes = cos(offset * 19.0 + pick.zxy * 4.0);
	float rim = 0.31 + 0.041 * lobes.x * lobes.y * lobes.z;
	float presence = step(fract(pick.x + pick.y * 2.73), chance);
	float petal = presence * (1.0 - smoothstep(rim - softness, rim + softness, distance_to_seed));
	return vec2(petal, 0.38 * smoothstep(0.03, 0.21, distance_to_seed) + 0.62 * pick.z);
}

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Rotate an orthonormal volume, preserving dot size in every direction.
	garden = vec3(dot(world, vec3(0.80, 0.48, -0.36)),
		dot(world, vec3(-0.60, 0.64, -0.48)), dot(world, vec3(0.0, 0.60, 0.80)));
	tint = COLOR;
}

void fragment() {
	vec3 leaf_grid = garden / leaf_size;
	vec3 leaf_seed = seed3(floor(leaf_grid));
	vec3 leaf_offset = fract(leaf_grid) - 0.5 - (leaf_seed - 0.5) * 0.22;
	float leaf = 1.0 - smoothstep(0.25, 0.48, length(leaf_offset * vec3(0.92, 1.14, 1.0)));
	float footprint = max(length(dFdx(garden)), length(dFdy(garden)));
	float leaf_resolved = 1.0 - smoothstep(0.35, 1.1, footprint / leaf_size);
	vec3 foliage = tint.rgb * mix(0.84, mix(0.69, 1.14, leaf) * mix(0.92, 1.08, leaf_seed.x), leaf_resolved);
	float petal = 0.0;
	vec3 flower = vec3(0.0);
	if (bloom > 0.0) {
		vec3 flowers = garden / flower_size;
		float up = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y;
		float spray = 0.5 + 0.5 * sin(garden.x * 5.1 + sin(garden.z * 4.3)) * sin(garden.y * 5.7 + garden.z * 2.2);
		float chance = clamp(bloom * mix(0.48, 1.28, spray) * smoothstep(-0.64, 0.22, up), 0.0, 1.0);
		float softness = clamp(footprint / flower_size * 0.45, 0.035, 0.115);
		vec2 first = floret(flowers, chance, softness);
		vec2 second = floret(flowers.yzx * 1.21 + vec3(0.37, 0.61, 0.43), chance * 0.81, softness);
		float overlap = max(first.x, second.x);
		float resolved = 1.0 - smoothstep(0.38, 0.96, footprint / flower_size);
		petal = mix(0.22 * chance, overlap, resolved);
		float tone = mix(0.50, mix(first.y, second.y, step(first.x, second.x)), resolved);
		flower = mix(petal_a, petal_b, tone) * 0.91;
	}
	if (shell > 0.5 && petal < 0.33 && (leaf < 0.35 || leaf_seed.z > 0.64)) discard;
	ALBEDO = mix(foliage, flower, petal);
	ROUGHNESS = 0.94;
	SPECULAR = 0.12;
}
"""

# This block is mixed into the existing terrain fragment, after the worn-ground pass.
# Only the narrow entrance footprint samples stone. The court uses these same scans.
const STONE_ROOT := preload("res://scripts/midori_court_materials.gd").STONE_ROOT
const PAVE_UNIFORMS := """
uniform sampler2D sando_stone : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec2 sando_a;
uniform vec2 sando_b;
uniform float sando_half;
"""
const PAVE_FRAGMENT := """
	{
		vec2 axis = sando_b - sando_a;
		float len = max(length(axis), 0.001);
		vec2 dir = axis / len;
		vec2 rel = world_pos.xz - sando_a;
		float along = dot(rel, dir);
		float side = dot(rel, vec2(-dir.y, dir.x));
		if (along > -0.3 && along < len + 0.5 && abs(side) < sando_half + 0.42) {
			float meander = 0.07 * sin(along * 1.43) + 0.045 * sin(along * 2.91 + 1.8);
			float width = sando_half + 0.24 * (1.0 - smoothstep(0.0, len, along));
			float paint = (1.0 - smoothstep(width - 0.07, width + 0.10, abs(side - meander)))
				* smoothstep(-0.3, 0.0, along) * (1.0 - smoothstep(len + 0.1, len + 0.5, along));
			vec3 grain = texture(sando_stone, world_pos.xz / 1.3).rgb;
			// Restrained worn joints in staggered, broad slabs. Adjacent stones meet.
			float course = floor(along / 0.83);
			float step_width = 1.05 + 0.29 * fract(sin(course * 9.23) * 1718.91);
			vec2 cell = vec2(side / step_width + fract(sin(course * 5.19) * 3161.73), along / 0.83);
			vec2 edge = min(fract(cell), 1.0 - fract(cell)) * vec2(step_width, 0.83);
			float seam = 1.0 - smoothstep(0.002, 0.014, min(edge.x, edge.y));
			float tone = 0.98 + 0.055 * fract(sin(dot(floor(cell), vec2(12.71, 7.31))) * 4136.2);
			float mineral = dot(grain, vec3(0.26, 0.56, 0.18));
			vec3 stone = mix(vec3(0.19, 0.174, 0.147), vec3(0.46, 0.425, 0.367), smoothstep(0.025, 0.48, mineral));
			stone *= (1.0 - seam * 0.20) * tone;
			ALBEDO = mix(ALBEDO, stone * scene_light_factor, paint);
			NORMAL_MAP = mix(NORMAL_MAP, vec3(0.5, 0.5, 1.0), paint * 0.88);
			ROUGHNESS = mix(ROUGHNESS, 0.89, paint);
			SPECULAR = mix(SPECULAR, 0.20, paint);
		}
	}
"""

static func build(park: Node3D, terrain: Node) -> Dictionary:
	var root := Node3D.new()
	root.name = "BiomeShrineApproach"
	park.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20501107
	var inventory_before := Kit.inventory(park, RECT)
	# Footprints of everything this builder stands up: {Vector2i: [Vector3(x, z, r)]}.
	var taken := {}
	var plaza := _plaza(park)
	var approach := _approach(plaza)
	if not is_instance_valid(park): return {}
	var torii := {}
	var painted := false
	var lamps := _lantern_kit()
	if not approach.is_empty():
		torii = await _torii(park, terrain, root, approach, taken)
		if not torii.get("placed", false):
			root.free()
			return {"error": "Central torii replacement failed", "torii": torii}
		painted = _paving(park, approach)
		if not painted: return {"error": "Could not paint granite onto the live terrain"}
		await park.get_tree().process_frame
		if not is_instance_valid(park): return {}
		_lanterns(park, terrain, root, rng, approach, plaza, taken, lamps)
	var mounds: Dictionary = await _mound_groups(park, terrain, root, rng, plaza, approach, taken, lamps)
	if not is_instance_valid(park): return {}
	if not lamps.is_empty(): Kit.batch_parts(root, "SandoLanterns", lamps.proto, lamps.rows, 32.0, 170.0, true)
	var lanterns: Array = lamps.get("placed", [])
	var anchors: Array = []
	anchors.append_array(mounds.moss_anchors)
	for lamp: Dictionary in lanterns:
		if not bool(lamp.get("paved", false)): anchors.append([lamp.p, float(lamp.radius) * 0.95, float(lamp.radius) + 0.5, 260])
	var moss := _moss_cushions(park, terrain, root, rng, anchors)
	var thinned := _thin(park, terrain, plaza, approach, taken)
	var raid := park.get_node_or_null("ExtractionRun")
	if raid != null and torii.get("placed",false):
		await park.get_tree().physics_frame
		await park.get_tree().physics_frame
		torii["finished_walk"] = raid.navigation.inspect_ground_corridor(ARRIVAL,Vector2(torii.at[0],torii.at[1]))
		torii["rest_bay"] = _north_rest_report(park,raid)
	var line := {}
	if not approach.is_empty():
		var a: Vector2 = approach.a
		var b: Vector2 = approach.b
		line = {"from": [snappedf(a.x, 0.1), snappedf(a.y, 0.1)], "to": [snappedf(b.x, 0.1), snappedf(b.y, 0.1)], "half_width": PAVE_HALF, "joins_walk": approach.joins, "bearing": approach.bearing}
	return {
		"approach": line,
		"torii": torii,
		"terrain_painted": painted,
		"lantern_pairs": lamps.get("pairs", 0),
		"niwaki": mounds.niwaki,
		"rim_groups": mounds.rim,
		"court_beds": mounds.court_beds,
		"court_lantern_pair": mounds.court_pair,
		"foreground_mounds": mounds.front,
		"lanterns": lanterns.map(func(l: Dictionary) -> Array: return [snappedf(l.p.x, 0.1), snappedf(l.p.y, 0.1)]),
		"mound_groups": mounds.groups,
		"mounds": mounds.count,
		"flowering_red": mounds.red,
		"flowering_pale": mounds.pale,
		"garden_stones": mounds.boulders,
		"moss_fronds": moss,
		"thinned": thinned,
		"inventory": inventory_before,
	}

# --- Shared checks -----------------------------------------------------------

static func _w(p: Vector2, terrain: Node) -> float:
	return Biomes.weight(p, ID, terrain)

static func _reserve(taken: Dictionary, p: Vector2, r: float) -> void:
	var key := Vector2i(floori(p.x / 4.0), floori(p.y / 4.0))
	if not taken.has(key): taken[key] = []
	(taken[key] as Array).append(Vector3(p.x, p.y, r))

## True when a disc of radius r at p touches nothing this builder placed.
static func _free(taken: Dictionary, p: Vector2, r: float) -> bool:
	var key := Vector2i(floori(p.x / 4.0), floori(p.y / 4.0))
	for dz: int in range(-1, 2):
		for dx: int in range(-1, 2):
			for v: Vector3 in taken.get(key + Vector2i(dx, dz), []):
				if p.distance_to(Vector2(v.x, v.y)) < r + v.z: return false
	return true

static func _trunk_near(park: Node3D, p: Vector2, r: float) -> bool:
	if park.has_method("any_trunk_within"): return park.any_trunk_within(p, r)
	return Kit.trunk_distance(park, p, r + 1.0) < r

## True when nothing but the ground is under the point (no prop, deck or roof).
static func _bare(park: Node3D, terrain: Node, p: Vector2) -> bool:
	var space := park.get_world_3d().direct_space_state
	var ground: float = terrain.height_at(p)
	var query := PhysicsRayQueryParameters3D.create(Vector3(p.x, ground + 30.0, p.y), Vector3(p.x, ground - 2.0, p.y))
	var hit := space.intersect_ray(query)
	return hit.is_empty() or (hit.position as Vector3).y < ground + 0.35

## Lowest ground under a disc, so nothing floats on a slope.
static func _low_ground(terrain: Node, p: Vector2, r: float) -> float:
	var low: float = terrain.height_at(p)
	for k: int in range(6):
		var q := p + Vector2(r, 0).rotated(float(k) * TAU / 6.0 + 0.4)
		low = minf(low, float(terrain.height_at(q)))
	return low

## On or at the edge of a paved walk or a worn trail.
static func _on_walk(park: Node3D, p: Vector2, margin: float) -> bool:
	if park.has_method("path_edge_distance_world") and park.path_edge_distance_world(p) < margin: return true
	var trails := park.get_node_or_null("MidoriDesirePaths")
	if trails != null and trails.has_method("distance_to_path") and trails.distance_to_path(p) < margin + 0.4: return true
	return false

## Clear of the park's own garden stones, lanterns and azaleas.
static func _clear_of_gardens(park: Node3D, p: Vector2, r: float) -> bool:
	var gardens := park.get_node_or_null("MidoriGardenSpots")
	if gardens != null and gardens.get("footprints") != null:
		for footprint: Dictionary in gardens.get("footprints"):
			if p.distance_to(footprint.p) < r + float(footprint.radius) + 0.45: return false
	var lamps := park.get_node_or_null("MidoriStoneLanterns")
	if lamps != null and lamps.get("footprints") != null:
		for footprint: Dictionary in lamps.get("footprints"):
			if p.distance_to(footprint.p) < r + float(footprint.radius) + 0.8: return false
	var flowers := park.get_node_or_null("MidoriJapaneseFlowers")
	if flowers != null and flowers.get("azalea_positions") != null:
		for at: Vector3 in flowers.get("azalea_positions"):
			if p.distance_to(Vector2(at.x, at.z)) < r + 0.7: return false
	return true

## Plaza court centre (x, z) and outer radius, read from its own floor mesh.
static func _plaza(park: Node3D) -> Vector3:
	var court := park.find_child("PlazaGroundingCourt", true, false) as MeshInstance3D
	if court != null and court.mesh != null:
		var box: AABB = court.global_transform * court.get_aabb()
		if box.size.x > 4.0: return Vector3(box.get_center().x, box.get_center().z, maxf(box.size.x, box.size.z) * 0.5)
	return PLAZA_FALLBACK

static func _in_plaza(plaza: Vector3, p: Vector2, margin: float) -> bool:
	return p.distance_to(Vector2(plaza.x, plaza.y)) < plaza.z + margin

## Lateral distance from the approach centreline, or a large number when the
## point is beyond either end.
static func _band_gap(ap: Dictionary, p: Vector2) -> float:
	if ap.is_empty(): return 1.0e9
	var a: Vector2 = ap.a
	var dir: Vector2 = ap.dir
	var side: Vector2 = ap.side
	var s := (p - a).dot(dir)
	if s < -0.8 or s > float(ap.length) + 0.8: return 1.0e9
	return absf((p - a).dot(side))

## Distance from the open strip of turf between the arrival point and the
## outer end of the approach, or a large number when the arrival is beside
## the paving already or nowhere near it. Mounds and stones keep off it, so
## nothing stands across the entrance to the paving.
static func _entry_gap(ap: Dictionary, p: Vector2) -> float:
	if ap.is_empty(): return 1.0e9
	var a: Vector2 = ap.a
	var dir: Vector2 = ap.dir
	if (ARRIVAL - a).dot(dir) > -0.5 or a.distance_to(ARRIVAL) > 12.0: return 1.0e9
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, ARRIVAL, a))

# --- The approach line -------------------------------------------------------

## Props keep their footprint tests. Their silhouettes need not interrupt the ground paint.
static func _approach(plaza: Vector3) -> Dictionary:
	var centre := Vector2(plaza.x, plaza.y)
	var outward := (ARRIVAL - centre).normalized()
	return _line(ARRIVAL, centre + outward * (plaza.z - 0.45), outward, true)

## The approach record: a is the outer end, b the rim end, u points outward.
static func _line(a: Vector2, b: Vector2, u: Vector2, joins: bool) -> Dictionary:
	var length := a.distance_to(b)
	# The torii defaults to the plaza end; _torii moves it to where it fits.
	return {"a": a, "b": b, "dir": -u, "side": Vector2(u.y, -u.x), "length": length, "joins": joins, "bearing": snappedf(rad_to_deg(atan2(u.y, u.x)), 0.1), "torii_s": length}

static func _torii(park: Node3D, terrain: Node, root: Node3D, ap: Dictionary, taken: Dictionary) -> Dictionary:
	var owner := park.find_child("SoutheastLandmarkPlaza_NeonToriiInstalled", true, false) as Node3D
	if owner == null: return {"placed": false, "reason": "missing plaza owner"}
	var socket := owner.get_node_or_null("ARC04_NeonToriiPortalSocket_12m") as Marker3D
	var old := owner.get_node_or_null("ARC04_NeonToriiPortal") as Node3D
	if socket == null or old == null: return {"placed": false, "reason": "missing landmark or socket"}
	var spot := Vector2(socket.global_position.x, socket.global_position.z)
	var obsolete := ["ARC04_NeonToriiPortal", "NeonToriiPillarCollision_Left", "NeonToriiPillarCollision_Right",
		"NeonToriiPortalGlow", "NeonToriiThresholdGlow"]
	var scale := 1.35
	var width := 1.2
	var spread := TORII_SPAN * scale * width * 0.5
	var base_y := _court_y(park, spot, terrain.height_at(spot))
	var dir: Vector2 = ap.dir
	var side: Vector2 = ap.side
	_raise_torii(root, "SandoTorii", spot, dir, base_y, scale, width)
	var gate := root.get_node_or_null("SandoTorii") as Node3D
	var visual := root.get_node_or_null("SandoTorii/ToriiMesh") as MeshInstance3D
	var body := root.get_node_or_null("SandoTorii/ToriiCollision") as StaticBody3D
	if gate == null or visual == null or visual.mesh == null or visual.mesh.get_surface_count() != 3 or body == null or body.get_child_count() != 2:
		if gate != null: gate.free()
		return {"placed": false, "reason": "replacement geometry or collision incomplete"}
	# Keep the old model and bodies alive until the new contacts pass. Optional
	# old colliders/lights depend on the park edition and rendering settings.
	var original_visible := old.visible
	old.hide()
	var old_bodies := {}
	var removed_names: Array[String] = []
	var old_solid_shapes := 0
	for name: String in obsolete:
		var node := owner.get_node_or_null(NodePath(name))
		if node == null: continue
		removed_names.append(name)
		var colliders := node.find_children("*", "CollisionObject3D", true, false)
		if node is CollisionObject3D: colliders.append(node)
		old_solid_shapes += node.find_children("*", "CollisionShape3D", true, false).size()
		for collider: CollisionObject3D in colliders:
			old_bodies[collider] = Vector2i(collider.collision_layer, collider.collision_mask)
			collider.collision_layer = 0
			collider.collision_mask = 0
	await park.get_tree().physics_frame
	await park.get_tree().physics_frame
	var space := park.get_world_3d().direct_space_state
	var middle := Vector3(spot.x, base_y + 1.05, spot.y)
	var walk_clear := true
	for lateral: float in [-0.65, 0.0, 0.65]:
		var line := middle + Vector3(side.x, 0, side.y) * lateral
		var offset := Vector3(dir.x, 0, dir.y) * 1.1
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(line - offset, line + offset)).is_empty(): walk_clear = false
	var posts_hit := 0
	for sd: float in [-1.0, 1.0]:
		var xz := spot + side * sd * spread
		var probe := Vector3(xz.x, base_y + 1.0, xz.y)
		var depth := Vector3(dir.x, 0.0, dir.y) * 0.85
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(probe - depth, probe + depth))
		if hit.get("collider") == body: posts_hit += 1
	var navigation := {}
	var raid := park.get_node_or_null("ExtractionRun")
	var valid_ground_route := true
	if walk_clear and posts_hit == 2 and raid != null:
		# Check the changed nav while the old landmark can still be restored. The
		# remote control edge is diagnostic only: a custom layout can close it.
		navigation = raid.navigation.refresh_plaza_gate(spot)
		var approach_walk: Dictionary = raid.navigation.inspect_ground_corridor(ARRIVAL,spot)
		navigation["approach_walk"] = approach_walk
		valid_ground_route = navigation.get("corridor_clear", false) and navigation.get("supported", false) and approach_walk.get("pass",false)
	if not walk_clear or posts_hit != 2 or not valid_ground_route:
		gate.free()
		old.visible = original_visible
		for collider: CollisionObject3D in old_bodies:
			collider.collision_layer = old_bodies[collider].x
			collider.collision_mask = old_bodies[collider].y
		if not valid_ground_route:
			await park.get_tree().physics_frame
			await park.get_tree().physics_frame
			raid.navigation.refresh_plaza_gate(spot)
		return {"placed": false, "reason": "gate validation failed; original landmark restored", "walk_clear": walk_clear,
			"post_colliders_hit": posts_hit, "navigation": navigation}
	var old_meshes := old.find_children("*", "MeshInstance3D", true, false)
	if old is MeshInstance3D: old_meshes.append(old)
	var old_mesh_count := old_meshes.size()
	var retained_materials: Array = park.get("plaza_emissive_materials")
	for mesh: MeshInstance3D in old_meshes:
		if mesh.mesh == null: continue
		for surface: int in range(mesh.mesh.get_surface_count()):
			retained_materials.erase(mesh.get_surface_override_material(surface))
	var night_parts := _remove_monument_neon(park, spot)
	for name: String in removed_names: owner.get_node(NodePath(name)).free()
	for sd: float in [-1.0, 1.0]: _reserve(taken, spot + side * sd * spread, 0.65)
	socket.set_meta("status", "installed_vermilion_torii")
	return {"placed": true, "at": [snappedf(spot.x, 0.1), snappedf(spot.y, 0.1)], "height_m": 5.2 * scale,
		"span_m": spread * 2.0, "open_width_m": spread * 2.0 - 0.52 * scale, "removed_nodes": removed_names, "old_meshes": old_mesh_count,
		"old_solid_shapes": old_solid_shapes, "old_neon": night_parts, "post_colliders_hit": posts_hit, "walk_clear": walk_clear, "socket": String(socket.name),
		"navigation": navigation}

static func _north_rest_report(park: Node3D,raid: Node) -> Dictionary:
	var owner := park.get_node_or_null("Midori2050Identity")
	if owner == null: return {}
	var bay := owner.get_node_or_null("PlazaNorthRestGarden") as Node3D
	if bay == null: return {}
	var result: Dictionary = owner.get_meta("north_rest_bay",{}).duplicate()
	var seat := bay.get_node_or_null("PlazaBench_03") as Node3D
	result["bench_nodes"] = bay.find_children("*TimberBench*","Node3D",true,false).filter(func(n: Node)->bool: return n.name == "MeshyTimberBench").size()
	result["seat_colliders"] = bay.find_children("SeatCollision","StaticBody3D",true,false).size()
	result["planter_colliders"] = bay.find_children("Planter_North*","StaticBody3D",true,false).size()
	var bed := bay.find_child("Planter_NorthBack",true,false) as Node3D
	if bed != null: result["rear_bed_world"] = str(bed.global_position)
	var plants_near_beds := 0
	var plants := 0
	for row: Dictionary in owner.plant_report:
		if not str(row.id).begins_with("North"): continue
		plants += 1
		var local := bay.to_local(row.position)
		if absf(local.x) < 3.95 and local.z > -2.1 and local.z < 0.60: plants_near_beds += 1
	result["plants"] = plants
	result["plants_in_bay"] = plants_near_beds
	if seat != null:
		for site: Dictionary in raid.sites:
			if site.id == "PlazaBench_03":
				result["cache_id"] = site.id
				result["cache_world"] = str(site.position)
				result["cache_on_bench"] = seat.global_position.distance_to(site.position) < .015
				break
	return result

## NightOnly also owns distant corporate edges. Select only measured portal strips
## and local washes, including any auto-renamed siblings with the same mesh size.
static func _remove_monument_neon(park: Node3D, centre: Vector2) -> Dictionary:
	var owner := park.get_node_or_null("MidoriNeonPark/NightOnly")
	var report := {"strips": 0, "washes": 0}
	if owner == null: return report
	for child: Node in owner.get_children():
		if not child is Node3D: continue
		var p: Vector3 = child.global_position
		if centre.distance_to(Vector2(p.x, p.z)) > 5.5: continue
		if child is MeshInstance3D and child.mesh is BoxMesh:
			var extent: Vector3 = child.mesh.size
			if not (extent.is_equal_approx(Vector3(0.07, 5.9, 0.07)) or extent.is_equal_approx(Vector3(11.0, 0.08, 0.08)) or extent.is_equal_approx(Vector3(8.6, 0.05, 0.05))): continue
			report.strips += 1
		elif child is OmniLight3D and is_equal_approx(child.omni_range, 17.0):
			report.washes += 1
		else: continue
		owner.remove_child(child)
		child.free()
	return report

## The plaza discs have visible tops above the ground collider. In a terrace
## overlap the uppermost matching mesh, rather than the terrain, supports props.
static func _court_y(park: Node3D, p: Vector2, floor_y: float) -> float:
	for name: String in ["PlazaGroundingCourt", "PlazaOuterStoneTerrace", "PlazaMainStoneCourt", "PlazaInnerDarkStoneRing", "PlazaCenterpieceSocketCap_12mWorld"]:
		var court := park.find_child(name, true, false) as MeshInstance3D
		if court == null or court.mesh == null: continue
		var box: AABB = court.global_transform * court.get_aabb()
		if p.distance_to(Vector2(box.get_center().x, box.get_center().z)) <= box.size.x * 0.5:
			floor_y = maxf(floor_y, box.end.y)
	return floor_y

## Stands a torii at spot (base height base_y), its opening running along dir,
## scaled uniformly, with pillar collision.
static func _raise_torii(root: Node3D, label: String, spot: Vector2, dir: Vector2, base_y: float, scale: float, width: float = 1.0) -> void:
	var gate := Node3D.new()
	gate.name = label
	root.add_child(gate)
	# Local +Z runs along dir; local X across it.
	gate.global_transform = Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.y)).scaled(Vector3.ONE * scale), Vector3(spot.x, base_y, spot.y))
	var visual := MeshInstance3D.new()
	visual.name = "ToriiMesh"
	visual.mesh = _torii_mesh(width)
	visual.visibility_range_end = 450.0
	gate.add_child(visual)
	var body := StaticBody3D.new()
	body.name = "ToriiCollision"
	body.collision_layer = 1
	body.collision_mask = 1
	gate.add_child(body)
	for sd: float in [-1.0, 1.0]:
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = 0.26
		cylinder.height = 5.0
		shape.shape = cylinder
		shape.position = Vector3(sd * TORII_SPAN * width * 0.5, 2.2, 0.0)
		body.add_child(shape)

static func _torii_mesh(width: float) -> ArrayMesh:
	var red := SurfaceTool.new()
	red.begin(Mesh.PRIMITIVE_TRIANGLES)
	var black := SurfaceTool.new()
	black.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stone := SurfaceTool.new()
	stone.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pillar_h := 4.85
	var lean := 0.06 # top of each pillar sits this much further in
	var tilt := atan2(lean, pillar_h)
	for sd: float in [-1.0, 1.0]:
		var x := sd * TORII_SPAN * width * 0.5
		var pillar := CylinderMesh.new()
		pillar.top_radius = 0.17
		pillar.bottom_radius = 0.195
		pillar.height = pillar_h
		pillar.radial_segments = 24
		pillar.rings = 1
		var lean_basis := Basis(Vector3(0, 0, 1), sd * tilt)
		red.append_from(pillar, 0, Transform3D(lean_basis, Vector3(x - sd * lean * 0.5, -0.3 + pillar_h * 0.5, 0.0)))
		# Black sleeve (nemaki) over the foot of the pillar.
		var sleeve := CylinderMesh.new()
		sleeve.top_radius = 0.225
		sleeve.bottom_radius = 0.235
		sleeve.height = 0.85
		sleeve.radial_segments = 24
		sleeve.rings = 1
		black.append_from(sleeve, 0, Transform3D(lean_basis, Vector3(x - sd * lean * 0.07, 0.125, 0.0)))
		# A thin black collar where sleeve meets lacquer.
		var collar := CylinderMesh.new()
		collar.top_radius = 0.215
		collar.bottom_radius = 0.24
		collar.height = 0.05
		collar.radial_segments = 24
		collar.rings = 1
		black.append_from(collar, 0, Transform3D(lean_basis, Vector3(x - sd * lean * 0.12, 0.57, 0.0)))
		# Low dressed-stone footing (kamebara) half in the turf.
		var footing := CylinderMesh.new()
		footing.top_radius = 0.33
		footing.bottom_radius = 0.4
		footing.height = 0.3
		footing.radial_segments = 20
		footing.rings = 1
		stone.append_from(footing, 0, Transform3D(Basis.IDENTITY, Vector3(x, -0.07, 0.0)))
	# Nuki: the tie beam passing through both pillars, ends proud.
	var nuki := BoxMesh.new()
	nuki.size = Vector3(4.55 * width, 0.22, 0.15)
	red.append_from(nuki, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 3.86, 0.0)))
	# Gakuzuka strut and its plaque.
	var strut := BoxMesh.new()
	strut.size = Vector3(0.16, 0.52, 0.13)
	red.append_from(strut, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 4.21, 0.0)))
	var frame := BoxMesh.new()
	frame.size = Vector3(0.46, 0.5, 0.17)
	red.append_from(frame, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 4.2, 0.0)))
	var plaque := BoxMesh.new()
	plaque.size = Vector3(0.36, 0.4, 0.19)
	black.append_from(plaque, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 4.2, 0.0)))
	# Shimaki (lacquered) under the black kasagi; both lift at the ends.
	red.append_from(_bent_beam(4.95 * width, 0.22, 0.26, 0.1), 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 4.46, 0.0)))
	black.append_from(_bent_beam(5.8 * width, 0.25, 0.36, 0.28), 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 4.68, 0.0)))
	var red_look := StandardMaterial3D.new()
	red_look.albedo_color = Color(0.72, 0.215, 0.105)
	red_look.roughness = 0.78
	red_look.cull_mode = BaseMaterial3D.CULL_DISABLED
	var black_look := StandardMaterial3D.new()
	black_look.albedo_color = Color(0.05, 0.045, 0.042)
	black_look.roughness = 0.5
	black_look.cull_mode = BaseMaterial3D.CULL_DISABLED
	var stone_look := StandardMaterial3D.new()
	stone_look.albedo_color = Color(0.42, 0.41, 0.38)
	stone_look.roughness = 0.9
	var mesh := red.commit()
	black.commit(mesh)
	stone.commit(mesh)
	mesh.surface_set_material(0, red_look)
	mesh.surface_set_material(1, black_look)
	mesh.surface_set_material(2, stone_look)
	return mesh

## A beam of the given length, height and depth along X, bottom at y = 0 in
## the middle, rising by `lift` at both ends on a soft curve (sori).
static func _bent_beam(length: float, height: float, depth: float, lift: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 24
	var sections: Array[PackedVector3Array] = []
	var mids: Array[Vector3] = []
	for i: int in range(n + 1):
		var x := -length * 0.5 + length * float(i) / float(n)
		var y := lift * pow(absf(x) / (length * 0.5), 2.4)
		var ring := PackedVector3Array([Vector3(x, y, -depth * 0.5), Vector3(x, y, depth * 0.5), Vector3(x, y + height, depth * 0.5), Vector3(x, y + height, -depth * 0.5)])
		sections.append(ring)
		mids.append(Vector3(x, y + height * 0.5, 0.0))
	for i: int in range(n):
		var s0 := sections[i]
		var s1 := sections[i + 1]
		var mid := (mids[i] + mids[i + 1]) * 0.5
		for k: int in range(4):
			var k1 := (k + 1) % 4
			var a := s0[k]
			var b := s1[k]
			var c := s1[k1]
			var d := s0[k1]
			_quad(st, a, b, c, d, (a + b + c + d) * 0.25 - mid)
	_quad(st, sections[0][0], sections[0][1], sections[0][2], sections[0][3], Vector3.LEFT)
	_quad(st, sections[n][0], sections[n][1], sections[n][2], sections[n][3], Vector3.RIGHT)
	st.index()
	return st.commit()

## One flat quad with its face turned toward `out`, wound clockwise as seen
## from that side (Godot's front face).
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3) -> void:
	var normal := (b - a).cross(c - a)
	if normal.length_squared() < 1e-12: normal = (c - a).cross(d - a)
	if normal.dot(out) < 0.0:
		var swap := b
		b = d
		d = swap
		normal = -normal
	normal = normal.normalized()
	for v: Vector3 in [a, c, b, a, d, c]:
		st.set_normal(normal)
		st.set_uv(Vector2(v.x + v.z, v.y))
		st.add_vertex(v)

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3) -> void:
	var normal := (b - a).cross(c - a)
	if normal.dot(out) < 0.0:
		var swap := b
		b = c
		c = swap
		normal = -normal
	normal = normal.normalized()
	for v: Vector3 in [a, c, b]:
		st.set_normal(normal)
		st.set_uv(Vector2(v.x, v.z))
		st.add_vertex(v)

# --- Swept stone paving ------------------------------------------------------

## Paint only the entrance into the existing terrain, keeping the court and collision surfaces.
static func _paving(park: Node3D, ap: Dictionary) -> bool:
	var material := Biomes._ground_material(park)
	if material == null or material.shader == null: return false
	var code := material.shader.code
	if not code.contains("uniform sampler2D sando_stone"):
		var declarations := code.find("varying vec3 world_pos;")
		if declarations < 0: return false
		code = code.insert(declarations, PAVE_UNIFORMS)
		var end := code.rfind("}")
		if end < 0: return false
		code = code.insert(end, PAVE_FRAGMENT)
		var previous := {}
		for entry: Dictionary in material.shader.get_shader_uniform_list():
			previous[entry.name] = material.get_shader_parameter(entry.name)
		var shader := Shader.new()
		shader.code = code
		material.shader = shader
		for key: StringName in previous: material.set_shader_parameter(key, previous[key])
	material.set_shader_parameter("sando_stone", load(STONE_ROOT + "BaseColor.png"))
	material.set_shader_parameter("sando_a", ap.a)
	material.set_shader_parameter("sando_b", ap.b)
	material.set_shader_parameter("sando_half", PAVE_HALF)
	return true

# --- Kasuga lanterns in irregular pairs --------------------------------------

## The lantern prototype, its measurements and the shared glow, plus the rows
## every placement adds to (batched once at the end of the build).
static func _lantern_kit() -> Dictionary:
	var proto := Kit.file_parts(LANTERN)
	if proto.parts.is_empty(): return {}
	var data: Dictionary = {}
	if FileAccess.file_exists(LANTERN_DATA):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LANTERN_DATA))
		if parsed is Dictionary: data = parsed
	var fire := Vector3(0.0, 0.89, 0.0)
	if data.has("fire_origin"):
		var o: Array = data.fire_origin
		fire = Vector3(float(o[0]), float(o[1]), float(o[2]))
	var parts: Array = data.get("collision_parts", [])
	if parts.is_empty(): parts = [{"centre": [0.0, 0.7, 0.0], "size": [0.5, 1.4, 0.5]}]
	return {"proto": proto, "base_r": float(data.get("base_radius", 0.28)), "roof_r": float(data.get("clearance_radius", 0.41)), "fire": fire, "parts": parts, "glow": _glow_material(), "rows": [], "placed": [], "pairs": 0}

## One lantern at spot on base_y, turned so its open front faces `toward`.
static func _add_lantern(root: Node3D, rng: RandomNumberGenerator, kit: Dictionary, taken: Dictionary, spot: Vector2, base_y: float, toward: Vector2, size: float, paved: bool) -> void:
	var placed: Array = kit.placed
	var yaw := atan2(toward.x, toward.y) + rng.randf_range(-0.06, 0.06)
	var origin := Vector3(spot.x, base_y, spot.y)
	(kit.rows as Array).append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * size), origin))
	var body := StaticBody3D.new()
	body.name = "SandoLanternCollision_%02d" % placed.size()
	body.collision_layer = 1
	body.collision_mask = 1
	root.add_child(body)
	body.global_transform = Transform3D(Basis(Vector3.UP, yaw), origin)
	for part: Dictionary in kit.parts:
		var collider := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var part_size: Array = part.size
		var centre: Array = part.centre
		box.size = Vector3(float(part_size[0]), float(part_size[1]), float(part_size[2])) * size
		collider.shape = box
		collider.position = Vector3(float(centre[0]), float(centre[1]), float(centre[2])) * size
		body.add_child(collider)
	# A soft warm glow in the chamber: a static card, no light, no script.
	var card := MeshInstance3D.new()
	card.name = "SandoLanternGlow_%02d" % placed.size()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.104, 0.128) * size
	card.mesh = quad
	card.material_override = kit.glow
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	card.visibility_range_end = 90.0
	root.add_child(card)
	# The measured open face is local +Z. Its clear luminous area is 0.11 × 0.145 m.
	card.global_transform = Transform3D(Basis(Vector3.UP, yaw), origin + Basis(Vector3.UP, yaw) * (((kit.fire as Vector3) + Vector3(0.0, 0.071, 0.105)) * size))
	_reserve(taken, spot, float(kit.roof_r) * size + 0.35)
	placed.append({"p": spot, "radius": float(kit.base_r) * size, "paved": paved})

## Pairs line the approach from just outside the torii back to its outer end,
## about every 2 to 2.8 m, each lamp of a pair set its own distance off the
## paving and a little ahead or behind its partner; one more pair stands on the
## plaza's outer stone ring beyond the torii, flanking the axis.
static func _lanterns(park: Node3D, terrain: Node, root: Node3D, rng: RandomNumberGenerator, ap: Dictionary, plaza: Vector3, taken: Dictionary, kit: Dictionary) -> void:
	if kit.is_empty(): return
	var a: Vector2 = ap.a
	var dir: Vector2 = ap.dir
	var side: Vector2 = ap.side
	var base_r: float = kit.base_r
	var roof_r: float = kit.roof_r
	var torii_s: float = float(ap.torii_s)
	# Work out both seats before adding either collider, so every approach station is a pair.
	for station: float in [23.5, 18.4, 13.3, torii_s - 1.70, 4.8]:
		if station < 0.8: continue
		var paved := station > float(ap.length) + 0.4
		var size := rng.randf_range(1.04, 1.16)
		for attempt: int in range(30):
			var along := station + rng.randf_range(-0.65, 0.65)
			var lateral := PAVE_HALF + 0.55 + roof_r * size + float(attempt % 6) * 0.24
			var seats: Array[Vector3] = []
			for sd: float in [-1.0, 1.0]:
				var p := a + dir * along + side * sd * lateral
				if p.distance_to(ARRIVAL) < ARRIVAL_CLEAR: break
				var y := _plaza_lantern_seat(park, terrain, p, base_r * size, roof_r * size, plaza, taken) if paved else _lantern_seat(park, terrain, p, base_r * size, roof_r * size, plaza, taken)
				if is_nan(y): break
				seats.append(Vector3(p.x, y, p.y))
			if seats.size() < 2: continue
			for seat: Vector3 in seats:
				var p := Vector2(seat.x, seat.z)
				_add_lantern(root, rng, kit, taken, p, seat.y, ARRIVAL - p, size, paved)
			kit.pairs += 1
			break

## Base height for a lantern on the plaza's outer stone ring (between the
## raised inner court and the rim), or NAN when the spot is not clear.
static func _plaza_lantern_seat(park: Node3D, terrain: Node, p: Vector2, base_r: float, roof_r: float, plaza: Vector3, taken: Dictionary) -> float:
	var r := p.distance_to(Vector2(plaza.x, plaza.y))
	if r < plaza.z * 0.57 or r > plaza.z - roof_r - 0.3: return NAN
	if _trunk_near(park, p, base_r + 1.0) or not _clear_of_gardens(park, p, roof_r) or not _free(taken, p, roof_r + 0.2): return NAN
	var space := park.get_world_3d().direct_space_state
	var ground: float = terrain.height_at(p)
	var top := -INF
	for k: int in range(5):
		var q := p if k == 0 else p + Vector2(roof_r, 0).rotated(float(k) * TAU / 4.0 + 0.4)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(q.x, ground + 30.0, q.y), Vector3(q.x, ground - 2.0, q.y)))
		var y: float = (hit.position as Vector3).y if not hit.is_empty() else float(terrain.height_at(q))
		if y > ground + 0.35: return NAN
		if top > -INF and absf(y - top) > 0.05: return NAN
		top = maxf(top, y)
	return top - 0.01

static func _glow_material() -> StandardMaterial3D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.86, 0.6, 0.95))
	gradient.set_color(1, Color(0.62, 0.26, 0.05, 0.18))
	gradient.add_point(0.58, Color(1.0, 0.72, 0.32, 0.93))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.55)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 32
	texture.height = 32
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.albedo_texture = texture
	look.albedo_color = Color(1.0, 0.72, 0.4, 0.8)
	look.cull_mode = BaseMaterial3D.CULL_DISABLED
	look.emission_enabled = true
	look.emission = Color(1.0, 0.58, 0.20)
	look.emission_texture = texture
	look.emission_energy_multiplier = 2.5
	return look

## Base height for a lantern at p, or NAN when the spot is not clear or flat.
static func _lantern_seat(park: Node3D, terrain: Node, p: Vector2, base_r: float, roof_r: float, plaza: Vector3, taken: Dictionary) -> float:
	if _w(p, terrain) < 0.35: return NAN
	if _in_plaza(plaza, p, roof_r + 0.25): return NAN
	if not Kit.open_ground(park, terrain, p, roof_r + 0.15): return NAN
	if _trunk_near(park, p, base_r + 1.0): return NAN
	if not _clear_of_gardens(park, p, roof_r): return NAN
	if not _free(taken, p, roof_r + 0.2): return NAN
	var low: float = terrain.height_at(p)
	var high := low
	for k: int in range(8):
		var q := p + Vector2(base_r, 0).rotated(float(k) * TAU / 8.0)
		if terrain.water_at(q): return NAN
		var h: float = terrain.height_at(q)
		low = minf(low, h)
		high = maxf(high, h)
	if high - low > 0.1: return NAN
	if not _bare(park, terrain, p): return NAN
	for k: int in range(4):
		if not _bare(park, terrain, p + Vector2(roof_r, 0).rotated(float(k) * TAU / 4.0 + 0.6)): return NAN
	return low - 0.01

# --- Clipped mounds, azaleas and garden stones -------------------------------

static func _stone_parts() -> Array:
	var protos: Array = []
	for i: int in range(6):
		var proto := Kit.file_parts(FLOOR + "stone_%02d.glb" % i)
		if not proto.parts.is_empty(): protos.append(proto)
	return protos

static func _mound_groups(park: Node3D, terrain: Node, root: Node3D, rng: RandomNumberGenerator, plaza: Vector3, ap: Dictionary, taken: Dictionary, lamps: Dictionary) -> Dictionary:
	var out := {"groups": 0, "count": 0, "red": 0, "pale": 0, "boulders": 0, "niwaki": 0, "rim": 0, "rim_lanterns": 0, "court_beds": 0, "court_pair": false, "front": 0, "moss_anchors": []}
	# Group centres: [centre, kind, niwaki] with kind RING, BANK, DRIFT or RIM;
	# a niwaki centre grows one cloud-pruned shrub instead of a mound group.
	var centres: Array = []
	if not ap.is_empty():
		var a: Vector2 = ap.a
		var dir: Vector2 = ap.dir
		var side: Vector2 = ap.side
		var length: float = ap.length
		var torii_s: float = ap.torii_s
		# Drifts first: azalea, karikomi and niwaki groups filling the turf either
		# side of the approach between the walk and the torii (the foreground of
		# the concept). Scattered, never in step across the paving; the park's
		# own boulders, lanterns and azaleas are kept clear. When the paving runs
		# on past the arrival point, the drifts stay ahead of it, where the walker
		# (and the review camera) looks.
		var drift_lo := -3.0
		var drift_hi := minf(torii_s + 0.4, length)
		var s_arrival := (ARRIVAL - a).dot(dir)
		if absf((ARRIVAL - a).dot(side)) < 4.0 and s_arrival + 0.6 < drift_hi - 1.0:
			drift_lo = maxf(drift_lo, s_arrival + 0.6)
		for sd: float in [-1.0, 1.0]:
			var here := 0
			var trees := 0
			for attempt: int in range(80):
				if here >= MAX_DRIFTS_PER_SIDE: break
				var p := a + dir * rng.randf_range(drift_lo, drift_hi) + side * sd * (PAVE_HALF + rng.randf_range(1.3, 7.8))
				var spaced := true
				for row: Array in centres:
					if (row[0] as Vector2).distance_to(p) < 2.4: spaced = false
				if not spaced: continue
				if _w(p, terrain) < 0.4 or _in_plaza(plaza, p, 1.2): continue
				if not Kit.open_ground(park, terrain, p, 0.9) or _trunk_near(park, p, 1.3): continue
				if not _clear_of_gardens(park, p, 0.7) or not _free(taken, p, 0.8) or not _bare(park, terrain, p): continue
				# One or two niwaki stand among each side's drifts.
				var tree := p.distance_to(ARRIVAL) > 9.0 and trees < 1 and (here == 2 or rng.randf() < 0.12)
				if tree: trees += 1
				centres.append([p, DRIFT, tree])
				here += 1
		await park.get_tree().process_frame
		if not is_instance_valid(park) or not is_instance_valid(root): return out
		# Banks behind the lanterns, each side on its own irregular rhythm.
		var banks := 0
		for sd: float in [-1.0, 1.0]:
			var s := rng.randf_range(0.5, 3.0)
			while s < length + 1.5:
				if banks >= MAX_BANK_GROUPS: break
				# Set back by a different amount each time, so the banks never
				# read as a hedge line parallel to the paving.
				var p := a + dir * s + side * sd * (PAVE_HALF + rng.randf_range(2.6, 5.4))
				s += rng.randf_range(4.0, 7.5)
				var spaced := true
				for row: Array in centres:
					if (row[0] as Vector2).distance_to(p) < 2.6: spaced = false
				if not spaced: continue
				if _w(p, terrain) < 0.45 or _in_plaza(plaza, p, 1.6): continue
				if not Kit.open_ground(park, terrain, p, 1.4) or _trunk_near(park, p, 1.6): continue
				if not _clear_of_gardens(park, p, 1.0) or not _free(taken, p, 1.0) or not _bare(park, terrain, p): continue
				centres.append([p, BANK, false])
				banks += 1
	# The plaza's outer rim, west round through north to east (what the reverse
	# view sees past the plaza): niwaki, azalea drifts and karikomi on the turf
	# just off the paving, at uneven distances from the rim and uneven gaps.
	var c0 := Vector2(plaza.x, plaza.y)
	var rim_centres: Array = []
	for attempt: int in range(700):
		if rim_centres.size() >= MAX_RIM_GROUPS: break
		if attempt % 100 == 99:
			await park.get_tree().process_frame
			if not is_instance_valid(park) or not is_instance_valid(root): return out
		# Most trials on the east and west flanks, which the reverse view sees
		# nearest (about 35 to 45 m); the rest round the far, northern rim.
		var phi := rng.randf_range(-PI - 0.14, 0.14)
		if rng.randf() < 0.6: phi = rng.randf_range(-0.95, 0.14) if rng.randf() < 0.5 else rng.randf_range(-PI - 0.14, -PI + 0.95)
		var p := c0 + Vector2(cos(phi), sin(phi)) * (plaza.z + rng.randf_range(1.5, 6.5))
		if _w(p, terrain) < 0.3: continue
		if _band_gap(ap, p) < PAVE_HALF + 2.2 or _entry_gap(ap, p) < PAVE_HALF + 2.0: continue
		var spaced := true
		for row: Array in centres:
			if (row[0] as Vector2).distance_to(p) < 4.2: spaced = false
		if not spaced: continue
		if not Kit.open_ground(park, terrain, p, 1.1) or _trunk_near(park, p, 1.4): continue
		if not _clear_of_gardens(park, p, 0.9) or not _free(taken, p, 1.0) or not _bare(park, terrain, p): continue
		centres.append([p, RIM, rng.randf() < 0.38])
		rim_centres.append(p)
	out.rim = rim_centres.size()
	# Loose groups round the crescent of turf.
	var ring := 0
	for attempt: int in range(900):
		if ring >= MAX_RING_GROUPS: break
		# Spread the trials over frames whether or not they succeed; each one
		# samples the biome weight (a shoreline search) and casts a ray.
		if attempt % 100 == 99:
			await park.get_tree().process_frame
			if not is_instance_valid(park) or not is_instance_valid(root): return out
		var ang := rng.randf() * TAU
		var p := CENTRE + Vector2(cos(ang) * RADII.x, sin(ang) * RADII.y) * sqrt(rng.randf()) * 0.97
		if _w(p, terrain) < 0.5 or _in_plaza(plaza, p, 2.0): continue
		if _band_gap(ap, p) < PAVE_HALF + 2.4 or _entry_gap(ap, p) < PAVE_HALF + 2.4: continue
		var spaced := true
		for row: Array in centres:
			if (row[0] as Vector2).distance_to(p) < 7.5: spaced = false
		if not spaced: continue
		if not Kit.open_ground(park, terrain, p, 1.8) or _trunk_near(park, p, 1.8): continue
		if not _clear_of_gardens(park, p, 1.2) or not _free(taken, p, 1.2) or not _bare(park, terrain, p): continue
		centres.append([p, RING, rng.randf() < 0.2])
		ring += 1
	var green_rows: Array = []
	var red_rows: Array = []
	var pale_rows: Array = []
	var bark_rows: Array = []
	var boulder_rows: Array = []
	var boulders := _stone_parts()
	_front_drifts(park, terrain, ap, taken, rng, green_rows, red_rows, pale_rows, out)
	for gi: int in range(centres.size()):
		if gi % 3 == 2:
			await park.get_tree().process_frame
			if not is_instance_valid(park) or not is_instance_valid(root): return out
		var c: Vector2 = centres[gi][0]
		var kind: int = centres[gi][1]
		if bool(centres[gi][2]):
			if _niwaki(park, terrain, rng, c, plaza, ap, taken, green_rows, bark_rows, 1.35 if kind == RIM else 1.0):
				out.niwaki += 1
				out.groups += 1
				continue
		var drift := kind == DRIFT
		var roll := rng.randf()
		var size := 3
		if kind == BANK: size = 2 if roll < 0.3 else (3 if roll < 0.65 else 5)
		elif drift: size = 3 if roll < 0.3 else (4 if roll < 0.65 else 6)
		elif kind == RIM: size = 2 if roll < 0.35 else (3 if roll < 0.75 else 4)
		else: size = 3 if roll < 0.45 else (5 if roll < 0.85 else 7)
		var flower_roll := rng.randf()
		# 0 green, 1 red satsuki, 2 pale-pink satsuki. Drifts are mostly in
		# flower, red a little more often than pale.
		var bloom_kind := 0
		if drift: bloom_kind = 1 if flower_roll < 0.48 else (2 if flower_roll < 0.85 else 0)
		elif kind == RIM: bloom_kind = 1 if flower_roll < 0.32 else (2 if flower_roll < 0.6 else 0)
		else: bloom_kind = 1 if flower_roll < 0.3 else (2 if flower_roll < 0.5 else 0)
		var species: int = [0, 0, 2, 2, 3, 1][rng.randi() % 6]
		var members: Array = [] # [Vector2, width]
		for m: int in range(size):
			var w := 0.0
			if drift: w = rng.randf_range(1.15, 1.7) if m == 0 else rng.randf_range(0.75, 1.3)
			else: w = rng.randf_range(1.2, 1.9) if m == 0 else rng.randf_range(0.65, 1.3)
			for attempt: int in range(28):
				var q := c
				if m > 0:
					var host: Array = members[rng.randi() % members.size()]
					var ang := rng.randf() * TAU
					q = (host[0] as Vector2) + Vector2(cos(ang), sin(ang)) * (float(host[1]) * 0.5 + w * 0.5) * rng.randf_range(0.62, 0.95)
				elif attempt > 0:
					q = c + Vector2(rng.randf_range(-1.4, 1.4), rng.randf_range(-1.4, 1.4))
				if not _free(taken, q, w * 0.4): continue
				if _in_plaza(plaza, q, w * 0.5 + 0.5): continue
				if _band_gap(ap, q) < PAVE_HALF + 0.6 + w * 0.5: continue
				if _entry_gap(ap, q) < PAVE_HALF + 0.3 + w * 0.5: continue
				if _w(q, terrain) < 0.3 or not Kit.open_ground(park, terrain, q, w * 0.5 + 0.25): continue
				if _trunk_near(park, q, w * 0.5 + 0.45): continue
				if not _clear_of_gardens(park, q, w * 0.5): continue
				if q.distance_to(ARRIVAL) < w * 0.5 + 1.2: continue
				if not _bare(park, terrain, q): continue
				# The rim too, so no mound climbs the flank of a boulder or prop.
				var flank_clear := true
				for k: int in range(3):
					if not _bare(park, terrain, q + Vector2(w * 0.45, 0.0).rotated(float(k) * TAU / 3.0 + 0.5)):
						flank_clear = false
						break
				if not flank_clear: continue
				members.append([q, w])
				_reserve(taken, q, w * 0.4)
				break
		if members.is_empty(): continue
		out.groups += 1
		for member: Array in members:
			var q: Vector2 = member[0]
			var w: float = member[1]
			# Tended mounds: fuller and rounder than the moss garden's; the
			# azalea drifts lower and spreading.
			var h := w * (rng.randf_range(0.45, 0.6) if drift and bloom_kind > 0 else rng.randf_range(0.55, 0.72))
			var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(w, h, w * rng.randf_range(0.82, 1.0)))
			var t := Transform3D(basis, Vector3(q.x, _low_ground(terrain, q, w * 0.4) - 0.05, q.y))
			# Now and then a green mound stands among the flowering ones.
			if bloom_kind > 0 and rng.randf() < 0.85:
				var leaf := Color(0.085, 0.15, 0.055) * rng.randf_range(0.9, 1.1)
				leaf.a = 0.03
				# In a drift the other colour slips in now and then, so red and
				# pale stand side by side as in the concept.
				var colour := bloom_kind
				if drift and rng.randf() < 0.25: colour = 3 - bloom_kind
				if colour == 1:
					red_rows.append([t, leaf])
					out.red += 1
				else:
					pale_rows.append([t, leaf])
					out.pale += 1
			else:
				var look: Array = ClippedShrubs.SPECIES[species if bloom_kind == 0 else 2]
				var leaf: Color = (look[0] as Color) * rng.randf_range(0.88, 1.1)
				# Kept shrubs: hardly any autumn bronze.
				leaf.a = float(look[1]) * 0.4
				green_rows.append([t, leaf])
			out.count += 1
		# A set stone at the edge of some ring groups (not crowding the banks).
		if boulders.is_empty() or kind != RING or rng.randf() > 0.4: continue
		var host_row: Array = members[rng.randi() % members.size()]
		var ang := rng.randf() * TAU
		var height := rng.randf_range(0.45, 0.85)
		var spot: Vector2 = (host_row[0] as Vector2) + Vector2(cos(ang), sin(ang)) * (float(host_row[1]) * 0.5 + height * 1.0)
		var reach := _place_stone(park, terrain, root, rng, boulders, boulder_rows, taken, plaza, ap, spot, height)
		if reach > 0.0:
			out.boulders += 1
			out.moss_anchors.append([spot, reach * 0.75, reach + 0.45, 320])
	# One or two larger set stones beside the torii, on the approach side of it.
	if not ap.is_empty() and not boulders.is_empty():
		var a: Vector2 = ap.a
		var dir: Vector2 = ap.dir
		var side: Vector2 = ap.side
		var torii_s: float = ap.torii_s
		var big := 0
		for k: int in range(10):
			if big >= 2: break
			var sd := -1.0 if k % 2 == 0 else 1.0
			var spot := a + dir * (torii_s - rng.randf_range(0.3, 2.6)) + side * sd * (PAVE_HALF + rng.randf_range(2.6, 3.8))
			var height := rng.randf_range(0.6, 0.95)
			var reach := _place_stone(park, terrain, root, rng, boulders, boulder_rows, taken, plaza, ap, spot, height)
			if reach > 0.0:
				big += 1
				out.moss_anchors.append([spot, reach * 0.75, reach + 0.55, 420])
		out.boulders += big
	# Lanterns among some rim groups, on their plaza side, facing the plaza.
	if not lamps.is_empty():
		var base_r: float = lamps.base_r
		var roof_r: float = lamps.roof_r
		for p: Vector2 in rim_centres:
			if out.rim_lanterns >= MAX_RIM_LANTERNS: break
			if rng.randf() > 0.55: continue
			var size := rng.randf_range(1.0, 1.25)
			var inward := (c0 - p).normalized()
			for attempt: int in range(6):
				var q := p + inward.rotated(rng.randf_range(-0.9, 0.9)) * rng.randf_range(1.2, 2.6)
				if q.distance_to(c0) < plaza.z + roof_r * size + 0.5: continue
				var seat := _lantern_seat(park, terrain, q, base_r * size, roof_r * size, plaza, taken)
				if is_nan(seat): continue
				_add_lantern(root, rng, lamps, taken, q, seat, c0 - q, size, false)
				out.rim_lanterns += 1
				break
	_court_beds(park, terrain, root, rng, plaza, taken, lamps, green_rows, red_rows, pale_rows, out)
	_batch_mounds(root, green_rows, red_rows, pale_rows)
	if not bark_rows.is_empty():
		var bark := StandardMaterial3D.new()
		bark.albedo_color = NIWAKI_BARK
		bark.roughness = 0.95
		Kit.cell_batches(root, "SandoNiwakiBark", _limb_mesh(), bark, bark_rows, 24.0, 160.0, true)
	var by_piece: Array = []
	for k: int in range(boulders.size()): by_piece.append([])
	for row: Array in boulder_rows: by_piece[row[0]].append(row[1])
	for k: int in range(boulders.size()):
		Kit.batch_parts(root, "SandoStones%d" % k, boulders[k], by_piece[k], 24.0, 130.0, true)
	return out

## Fold low flowering drifts around the existing boulder garden. A shrub can grow
## between visual foliage footprints, but never inside a stone or across the paving.
static func _front_drifts(park: Node3D, terrain: Node, ap: Dictionary, taken: Dictionary, rng: RandomNumberGenerator, greens: Array, reds: Array, pinks: Array, report: Dictionary) -> void:
	var patches := [Vector2(160.1, 98.5), Vector2(159.2, 101.2), Vector2(167.9, 98.6), Vector2(169.4, 101.0), Vector2(158.5, 103.7)]
	for n: int in range(patches.size()):
		var centre: Vector2 = patches[n]
		var members := 0
		for attempt: int in range(52):
			if members >= 5: break
			var p := centre + Vector2(rng.randf_range(-1.48, 1.48), rng.randf_range(-1.22, 1.22))
			var w := rng.randf_range(0.85, 1.40)
			if _band_gap(ap, p) < PAVE_HALF + w * 0.5 or not _free(taken, p, w * 0.32): continue
			if not Kit.open_ground(park, terrain, p, 0.36) or _trunk_near(park, p, 0.64): continue
			var clear := true
			for delta: Vector2 in [Vector2.ZERO, Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
				if not _bare(park, terrain, p + delta * w * 0.4): clear = false
			if not clear: continue
			var y := _low_ground(terrain, p, w * 0.38) - 0.04
			var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(w, w * rng.randf_range(0.38, 0.59), w * 0.84))
			var row := [Transform3D(basis, Vector3(p.x, y, p.y)), Color(0.078, 0.125, 0.040, 0.017)]
			if members == 3:
				greens.append(row)
			elif n == 2 or n == 4 or members == 4:
				pinks.append(row)
				report.pale += 1
			else:
				reds.append(row)
				report.red += 1
			_reserve(taken, p, w * 0.27)
			members += 1
			report.front += 1
			report.count += 1
		if members > 0: report.groups += 1

## Two planted pockets at the south lip of the existing main court. Seat against the
## actual terrace mesh, which is fractionally above the terrain physics surface.
static func _court_beds(park: Node3D, terrain: Node, root: Node3D, rng: RandomNumberGenerator, plaza: Vector3, taken: Dictionary, lamps: Dictionary, greens: Array, reds: Array, pinks: Array, report: Dictionary) -> void:
	var court := park.find_child("PlazaMainStoneCourt", true, false) as MeshInstance3D
	if court == null or court.mesh == null: return
	var bounds: AABB = court.global_transform * court.get_aabb()
	var centre := Vector2(bounds.get_center().x, bounds.get_center().z)
	var radius := bounds.size.x * 0.5
	var berms := []
	# Try mirrored sites as a pair. The service-kiosk side may need a different
	# lateral offset: inspect each true collision footprint before creating either lamp.
	var pair := []
	if not lamps.is_empty():
		for sd: float in [-1.0, 1.0]:
			var selected := Vector3.INF
			for dz: float in [17.5, 16.8, 18.3, 15.9, 19.0]:
				for width: float in [8.9, 8.1, 9.9, 7.2, 10.8]:
					var lp := centre + Vector2(sd * width, dz)
					var y := _plaza_lantern_seat(park, terrain, lp, lamps.base_r * 1.17, lamps.roof_r * 1.17, plaza, taken)
					if is_nan(y): continue
					selected = Vector3(lp.x, _court_y(park, lp, y) - 0.008, lp.y)
					break
				if selected != Vector3.INF: break
			if selected != Vector3.INF: pair.append(selected)
		if pair.size() == 2:
			for l: Vector3 in pair:
				var lp := Vector2(l.x, l.z)
				_add_lantern(root, rng, lamps, taken, lp, l.y, REVERSE_EYE - lp, 1.17, true)
			report.court_pair = true
	for sign_x: float in [-1.0, 1.0]:
		var spot := Vector2.INF
		for angle: float in [0.62, 0.67, 0.56, 0.72, 0.51, 0.78]:
			var p := centre + Vector2(sign_x * sin(angle), cos(angle)) * (radius - 1.0)
			if not _free(taken, p, 2.2) or not _clear_of_gardens(park, p, 1.9): continue
			var clear := true
			for delta: Vector2 in [Vector2.ZERO, Vector2(2.1, 0), Vector2(-2.1, 0), Vector2(0, 1.43), Vector2(0, -1.43)]:
				if not _bare(park, terrain, p + delta): clear = false
			if clear:
				spot = p
				break
		if spot == Vector2.INF: continue
		var bed_y := maxf(bounds.end.y, float(terrain.height_at(spot)))
		var tangent := (spot - centre).normalized().orthogonal()
		var outward := (spot - centre).normalized()
		var yaw := atan2(-tangent.y, tangent.x)
		var earth := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(6.8, 0.21, 3.35))
		berms.append([Transform3D(earth, Vector3(spot.x, bed_y - 0.025, spot.y))])
		for i: int in range(6):
			var along := [-1.50, -0.85, -0.30, 0.26, 0.98, 1.50]
			var across := [-0.14, 0.20, -0.42, 0.36, -0.20, 0.15]
			var p: Vector2 = spot + tangent * float(along[i]) * sign_x * 1.39 + outward * float(across[i]) * 1.32
			var w := rng.randf_range(1.42, 1.95)
			var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(w, w * rng.randf_range(0.50, 0.72), w * 0.82))
			var row := [Transform3D(basis, Vector3(p.x, bed_y + 0.03, p.y)), Color(0.085, 0.14, 0.055, 0.02)]
			if i < 2:
				greens.append(row)
			elif (i < 5) == (sign_x < 0.0):
				pinks.append(row)
				report.pale += 1
			else:
				reds.append(row)
				report.red += 1
			report.count += 1
		report.court_beds += 1
		report.groups += 1
		_reserve(taken, spot, 2.1)
	if not berms.is_empty():
		var soil := StandardMaterial3D.new()
		soil.albedo_color = Color(0.16, 0.13, 0.083)
		soil.roughness = 0.99
		Kit.cell_batches(root, "SandoCourtBeds", ClippedShrubs._mound(0.0), soil, berms, 24.0, 90.0, false)

## A niwaki 庭木: a short, gently crooked trunk carrying a crowning cloud pad
## and two to four side pads on bare limbs, clipped flat beneath. The pads are
## the karikomi mound (dark pine green), the trunk and limbs tapered cylinders.
## Returns false when the site is not clear.
static func _niwaki(park: Node3D, terrain: Node, rng: RandomNumberGenerator, c: Vector2, plaza: Vector3, ap: Dictionary, taken: Dictionary, pad_rows: Array, bark_rows: Array, grow: float = 1.0) -> bool:
	var tall := rng.randf_range(1.20, 1.82) * grow
	var spread := tall * 0.55
	if not _free(taken, c, spread * 0.75) or _in_plaza(plaza, c, spread + 0.5): return false
	if _band_gap(ap, c) < PAVE_HALF + 0.7 + spread or _entry_gap(ap, c) < PAVE_HALF + 0.4 + spread: return false
	if _w(c, terrain) < 0.3 or not Kit.open_ground(park, terrain, c, spread * 0.6): return false
	if _trunk_near(park, c, spread + 0.3) or not _clear_of_gardens(park, c, spread * 0.7) or not _bare(park, terrain, c): return false
	if c.distance_to(ARRIVAL) < spread + 1.2: return false
	for k: int in range(4):
		if not _bare(park, terrain, c + Vector2(spread * 0.8, 0.0).rotated(float(k) * TAU / 4.0 + 0.3)): return false
	var ground := _low_ground(terrain, c, 0.3)
	var lean := Vector2.RIGHT.rotated(rng.randf() * TAU)
	var pts: Array[Vector3] = [Vector3(c.x, ground - 0.05, c.y)]
	var at := c
	for k: int in range(3):
		var wob := lean.rotated(rng.randf_range(-1.1, 1.1)) * rng.randf_range(0.06, 0.2) * (-0.7 if k == 1 else 1.0)
		at += wob
		pts.append(Vector3(at.x, ground + tall * [0.36, 0.7, 1.0][k], at.y))
	var r0 := rng.randf_range(0.075, 0.11)
	for k: int in range(3):
		_limb(bark_rows, pts[k], pts[k + 1], r0 * (1.0 - 0.22 * float(k)))
	var leaf := Color(0.062, 0.1, 0.045) * rng.randf_range(0.9, 1.12)
	leaf.a = 0.0
	# Crowning pad.
	var w := rng.randf_range(1.02, 1.38)
	var h := w * rng.randf_range(0.38, 0.48)
	_pad(pad_rows, rng, pts[3] + Vector3.UP * (h * 0.25), w, h, leaf)
	# Side pads at irregular heights, turned round the trunk.
	var count := rng.randi_range(3, 4)
	var az := rng.randf() * TAU
	var levels: Array = []
	for k: int in range(count): levels.append(rng.randf_range(0.34, 0.86))
	levels.sort()
	for k: int in range(count):
		var t: float = levels[k]
		var y := ground + tall * t
		# Point on the trunk at that height.
		var tp := pts[0]
		for j: int in range(3):
			if y <= pts[j + 1].y or j == 2:
				tp = pts[j].lerp(pts[j + 1], clampf((y - pts[j].y) / maxf(pts[j + 1].y - pts[j].y, 0.01), 0.0, 1.0))
				break
		az += rng.randf_range(1.8, 2.8)
		var out := Vector3(cos(az), 0.0, sin(az))
		var reach := rng.randf_range(0.68, 1.08) * (1.15 - t * 0.4)
		var pw := rng.randf_range(0.6, 1.0) * (1.12 - t * 0.35)
		var ph := pw * rng.randf_range(0.36, 0.46)
		var centre := tp + out * reach + Vector3.UP * rng.randf_range(0.06, 0.2)
		_limb(bark_rows, tp, centre - Vector3.UP * ph * 0.2, r0 * 0.38)
		_pad(pad_rows, rng, centre, pw, ph, leaf)
	_reserve(taken, c, spread * 0.7)
	return true

static func _pad(rows: Array, rng: RandomNumberGenerator, centre: Vector3, w: float, h: float, leaf: Color) -> void:
	var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(w, h, w * rng.randf_range(0.8, 1.0)))
	rows.append([Transform3D(basis, centre - Vector3.UP * h * 0.5), leaf * rng.randf_range(0.92, 1.08)])

## One tapered cylinder instance from a to b of radius r (the unit limb mesh
## stands on its base, 1 m tall, radius 1).
static func _limb(rows: Array, a: Vector3, b: Vector3, r: float) -> void:
	var y := b - a
	if y.length() < 0.01: return
	a -= y.normalized() * 0.015
	y += y.normalized() * 0.03
	var ref := Vector3.FORWARD if absf(y.normalized().dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := y.cross(ref).normalized() * r
	var z := x.normalized().cross(y.normalized()) * r
	rows.append([Transform3D(Basis(x, y, z), a)])

static func _limb_mesh() -> ArrayMesh:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.72
	cylinder.bottom_radius = 1.0
	cylinder.height = 1.0
	cylinder.radial_segments = 8
	cylinder.rings = 1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(cylinder, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.5, 0.0)))
	return st.commit()

## Sets one stone of the given height at spot. Returns its footprint radius
## (half its longest plan extent once scaled), or 0 when the spot is not clear.
## The forest-floor stones are 1.3 to 2.6 times wider than tall, so every
## clearance is taken from that real footprint, not from the height.
static func _place_stone(park: Node3D, terrain: Node, root: Node3D, rng: RandomNumberGenerator, boulders: Array, rows: Array, taken: Dictionary, plaza: Vector3, ap: Dictionary, spot: Vector2, height: float) -> float:
	var k := rng.randi() % boulders.size()
	var box: AABB = (boulders[k] as Dictionary).box
	var scale := height / maxf(box.size.y, 0.001)
	var reach := maxf(box.size.x, box.size.z) * 0.5 * scale
	var mean := (box.size.x + box.size.z) * 0.25 * scale
	if not _free(taken, spot, reach * 0.7) or _in_plaza(plaza, spot, reach + 0.4): return 0.0
	if _band_gap(ap, spot) < PAVE_HALF + 0.5 + reach or _entry_gap(ap, spot) < PAVE_HALF + 0.3 + reach: return 0.0
	if _w(spot, terrain) < 0.35 or not Kit.open_ground(park, terrain, spot, reach + 0.3): return 0.0
	if _trunk_near(park, spot, reach + 0.4) or not _clear_of_gardens(park, spot, reach) or not _bare(park, terrain, spot): return 0.0
	var tilt := Basis(Vector3.RIGHT, rng.randf_range(-0.12, 0.12)) * Basis(Vector3.FORWARD, rng.randf_range(-0.12, 0.12))
	rows.append([k, Kit.seat(boulders[k], terrain, spot, height, rng.randf() * TAU, height * 0.35, tilt)])
	_reserve(taken, spot, reach * 0.85)
	var body := StaticBody3D.new()
	body.name = "SandoStone"
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = mean * 0.85
	cylinder.height = height * 0.75
	shape.shape = cylinder
	body.add_child(shape)
	root.add_child(body)
	body.global_position = Vector3(spot.x, float(terrain.height_at(spot)) + height * 0.375 - 0.1, spot.y)
	return reach

static func _batch_mounds(root: Node3D, green_rows: Array, red_rows: Array, pale_rows: Array) -> void:
	var bloom_shader := Shader.new()
	bloom_shader.code = BLOOM_SHADER
	for s: int in range(2):
		var mesh := ClippedShrubs._mound(float(ClippedShrubs.SHELLS[s]))
		var range_end: float = SHELL_RANGES[s]
		if not green_rows.is_empty():
			var look := ShaderMaterial.new()
			look.shader = bloom_shader
			look.set_shader_parameter("bloom", 0.0)
			look.set_shader_parameter("shell", float(s))
			Kit.cell_batches(root, "SandoMounds%d" % s, mesh, look, green_rows, 24.0, range_end, s == 0)
		if not red_rows.is_empty():
			var red := ShaderMaterial.new()
			red.shader = bloom_shader
			red.set_shader_parameter("shell", float(s))
			red.set_shader_parameter("bloom", 0.74)
			red.set_shader_parameter("petal_a", Color(0.66, 0.085, 0.14))
			red.set_shader_parameter("petal_b", Color(0.82, 0.20, 0.23))
			Kit.cell_batches(root, "SandoRedAzaleas%d" % s, mesh, red, red_rows, 24.0, range_end, s == 0)
		if not pale_rows.is_empty():
			var pale := ShaderMaterial.new()
			pale.shader = bloom_shader
			pale.set_shader_parameter("shell", float(s))
			pale.set_shader_parameter("bloom", 0.76)
			pale.set_shader_parameter("petal_a", Color(0.79, 0.53, 0.59))
			pale.set_shader_parameter("petal_b", Color(0.90, 0.72, 0.73))
			Kit.cell_batches(root, "SandoPaleAzaleas%d" % s, mesh, pale, pale_rows, 24.0, range_end, s == 0)

# --- Moss at the feet of lanterns and stones ---------------------------------

## Moss fronds (the island moss pieces) in soft rings round each anchor:
## [centre, inner radius, outer radius, count].
static func _moss_cushions(park: Node3D, terrain: Node, root: Node3D, rng: RandomNumberGenerator, anchors: Array) -> int:
	var meshes: Array[Mesh] = []
	var look: StandardMaterial3D = null
	for i: int in [0, 3, 6, 9]:
		var path := MOSS % i
		if not ResourceLoader.exists(path): continue
		var scene: Node3D = load(path).instantiate()
		var found := scene.find_children("*", "MeshInstance3D", true, false)
		if found.is_empty():
			scene.free()
			continue
		var mesh := ((found[0] as MeshInstance3D).mesh).duplicate() as Mesh
		for s: int in range(mesh.get_surface_count()):
			if look == null:
				var source := mesh.surface_get_material(s)
				if source is StandardMaterial3D:
					look = source.duplicate() as StandardMaterial3D
					look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
					look.alpha_scissor_threshold = 0.35
					look.cull_mode = BaseMaterial3D.CULL_DISABLED
			if look != null: mesh.surface_set_material(s, look)
		meshes.append(mesh)
		scene.free()
	if meshes.is_empty(): return 0
	var rows: Array = []
	for i: int in range(meshes.size()): rows.append([])
	var total := 0
	for anchor: Array in anchors:
		var c: Vector2 = anchor[0]
		var inner: float = anchor[1]
		var outer: float = anchor[2]
		var count: int = anchor[3]
		for k: int in range(count):
			if total >= MOSS_CAP: break
			var ang := rng.randf() * TAU
			var r := lerpf(inner, outer, pow(rng.randf(), 1.6)) * rng.randf_range(0.9, 1.15)
			var p := c + Vector2(cos(ang), sin(ang)) * r
			if terrain.water_at(p) or _on_walk(park, p, 0.1): continue
			var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.2, 0.2))
			basis = basis.scaled(Vector3.ONE * rng.randf_range(1.4, 2.4))
			rows[rng.randi() % meshes.size()].append([Transform3D(basis, Vector3(p.x, float(terrain.height_at(p)) + 0.002, p.y))])
			total += 1
	for i: int in range(meshes.size()):
		if rows[i].is_empty(): continue
		Kit.cell_batches(root, "SandoMoss%d" % i, meshes[i], null, rows[i], 16.0, 32.0, false)
	return total

# --- Thinning ----------------------------------------------------------------

## Spiky beds almost all go; lawn blades thin a little (the turf itself is in
## the ground look); wild ferns and floor bushes thin out, but never inside
## the plaza or beside its gardens and azaleas. Nothing pokes up through the
## paving, a mound, a lantern or a stone this builder set down.
static func _thin(park: Node3D, terrain: Node, plaza: Vector3, ap: Dictionary, taken: Dictionary) -> Dictionary:
	var report := {}
	# keep() runs once per planting instance in the rect (tens of thousands of
	# lawn blades). The biome weight (a shoreline search here, by the lake) and
	# the garden check are cached on a half-metre grid; the dithered pick still
	# decides each instance, so edges stay feathered.
	var weights := {}
	var gardens := {}
	var wt := func(p: Vector2) -> float:
		var key := Vector2i(floori(p.x * 2.0), floori(p.y * 2.0))
		if not weights.has(key): weights[key] = _w((Vector2(key) + Vector2(0.5, 0.5)) * 0.5, terrain)
		return float(weights[key])
	var near_garden := func(p: Vector2) -> bool:
		var key := Vector2i(floori(p.x * 2.0), floori(p.y * 2.0))
		if not gardens.has(key): gardens[key] = not _clear_of_gardens(park, (Vector2(key) + Vector2(0.5, 0.5)) * 0.5, 2.5)
		return bool(gardens[key])
	# The paving's ragged edge reaches about PAVE_HALF + 0.25 m.
	var under := func(p: Vector2) -> bool:
		return _band_gap(ap, p) < PAVE_HALF + 0.6 or not _free(taken, p, 0.06)
	var is_spiky := func(label: String) -> bool:
		var l := label.to_lower()
		return l.contains("fountain") or l.contains("emerald") or l.contains("woodlandfill") or l.contains("spiky") or l.contains("forestgrass")
	var is_lawn := func(label: String) -> bool:
		var l := label.to_lower()
		if is_spiky.call(l): return false
		return l.contains("grass") or l.contains("blade") or l.contains("tuft") or l.contains("lawn") or l.contains("clump")
	var is_wild := func(label: String) -> bool:
		var l := label.to_lower()
		if l.contains("azalea") or l.contains("iris") or l.contains("lilac"): return false
		return l.contains("fern") or l.contains("forest_floor_bush") or l.contains("forestfloorbush") or l.contains("dense_grass") or l.contains("densegrass") or l.contains("transition")
	var keep_spiky := func(p: Vector2) -> bool:
		if not RECT.has_point(p): return true
		if under.call(p): return false
		return not Biomes.pick(p, smoothstep(0.2, 0.7, float(wt.call(p))) * 0.94, 61)
	var keep_lawn := func(p: Vector2) -> bool:
		if not RECT.has_point(p): return true
		if under.call(p): return false
		return not Biomes.pick(p, smoothstep(0.3, 0.8, float(wt.call(p))) * 0.35, 63)
	var keep_wild := func(p: Vector2) -> bool:
		if not RECT.has_point(p): return true
		if _in_plaza(plaza, p, 0.5): return true
		# Nothing pokes up through the paving, garden or not.
		if under.call(p): return false
		if near_garden.call(p): return true
		return not Biomes.pick(p, smoothstep(0.35, 0.85, float(wt.call(p))) * 0.75, 67)
	# The wild lilac masses in the turf either side of the approach give way to
	# the azalea drifts and niwaki (the concept's foreground); elsewhere they stay.
	var is_lilac := func(label: String) -> bool:
		return label.to_lower().contains("lilac")
	var keep_lilac := func(p: Vector2) -> bool:
		if not RECT.has_point(p) or ap.is_empty(): return true
		var a: Vector2 = ap.a
		var s := (p - a).dot(ap.dir as Vector2)
		var lateral := absf((p - a).dot(ap.side as Vector2))
		if s < -7.0 or s > float(ap.torii_s) + 1.0 or lateral > PAVE_HALF + 10.0: return true
		return not Biomes.pick(p, 0.9, 69)
	if ResourceLoader.exists(THIN_ALL):
		# Also reaches the distance-detail copies, which a node-name filter misses.
		var helper := load(THIN_ALL) as Script
		report["spiky"] = helper.hide_low_planting(park, is_spiky, keep_spiky, RECT)
		report["lawn"] = helper.hide_low_planting(park, is_lawn, keep_lawn, RECT)
		report["wild"] = helper.hide_low_planting(park, is_wild, keep_wild, RECT)
		report["lilac"] = helper.hide_low_planting(park, is_lilac, keep_lilac, RECT)
		report["via"] = "thin_all"
		return report
	var grass := park.get_tree().root.get_node_or_null("MidoriGrassDetail")
	var label_of := func(node: MultiMeshInstance3D) -> String:
		return String(node.name) + " " + (node.multimesh.mesh.resource_name if node.multimesh.mesh else "")
	var spiky_nodes := func(node: MultiMeshInstance3D) -> bool: return is_spiky.call(label_of.call(node))
	var lawn_nodes := func(node: MultiMeshInstance3D) -> bool: return is_lawn.call(label_of.call(node))
	var wild_nodes := func(node: MultiMeshInstance3D) -> bool: return is_wild.call(label_of.call(node))
	var roots: Array = [park, grass]
	report["spiky"] = Kit.thin_multimeshes(roots, spiky_nodes, keep_spiky)
	report["lawn"] = Kit.thin_multimeshes(roots, lawn_nodes, keep_lawn)
	report["wild"] = Kit.thin_multimeshes(roots, wild_nodes, keep_wild)
	report["via"] = "kit"
	return report
