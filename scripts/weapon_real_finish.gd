extends Node3D

# Applies the real-counterpart finishes to an assembly's imported materials by
# material name. Names listed in FINISHES get their tuned finish; other names
# are matched by keyword (anodised, parkerised, blued, laminate, rubber...) and
# keep their imported colour; anything else (bores, sight paint, followers)
# keeps its imported PBR values.
const SHADER = preload("res://scripts/weapon_real_finish.gdshader")

# pattern (see the shader): 0 moulded polymer, 1 raised grip texture,
# 2 stipple, 3 parkerised/phosphate/nitride, 4 blued/polished steel, 5 wood or
# laminate (ply_mm > 0), 6 hard-anodised aluminium, 7 rubber, 8 plain.
# color is sRGB albedo; wear is the bare material under the finish. edge_wear
# scales bevel wear, polish the handling sheen, dust the grime in recesses.
const FINISHES := {
	# AKANE = Glock 17 Gen 5: nDLC slide/barrel, black polymer frame.
	"A9 nDLC slide": {"color": Color(0.13, 0.135, 0.14), "metallic": 0.45, "roughness": 0.5, "pattern": 3, "mottle": 0.25, "grain": 0.6, "edge_wear": 0.45, "wear": Color(0.55, 0.55, 0.56)},
	"A9 nDLC barrel": {"color": Color(0.15, 0.155, 0.16), "metallic": 0.7, "roughness": 0.36, "pattern": 4, "grain": 0.5, "edge_wear": 0.6, "wear": Color(0.62, 0.62, 0.62)},
	"A9 frame polymer": {"color": Color(0.095, 0.097, 0.1), "metallic": 0.0, "roughness": 0.6, "pattern": 0, "grain": 0.7, "edge_wear": 0.35},
	"A9 grip texture": {"color": Color(0.098, 0.1, 0.103), "metallic": 0.0, "roughness": 0.72, "pattern": 1, "pitch": 0.0011, "bump": 0.65, "edge_wear": 0.2},
	"A9 magazine polymer": {"color": Color(0.13, 0.133, 0.136), "metallic": 0.0, "roughness": 0.52, "pattern": 0, "grain": 0.7, "edge_wear": 0.45},
	"A9 sight polymer": {"color": Color(0.12, 0.122, 0.125), "metallic": 0.0, "roughness": 0.58, "pattern": 0, "edge_wear": 0.3},
	"A9 blackened steel": {"color": Color(0.13, 0.134, 0.138), "metallic": 0.65, "roughness": 0.48, "pattern": 4, "grain": 0.5, "edge_wear": 0.45, "wear": Color(0.6, 0.6, 0.6)},
	"A9 bright steel": {"color": Color(0.74, 0.74, 0.73), "metallic": 1.0, "roughness": 0.3, "pattern": 4, "grain": 0.6},
	"A9 laser marking": {"color": Color(0.42, 0.43, 0.44), "metallic": 0.25, "roughness": 0.62, "pattern": 8},
	# RAIDEN = Colt M4A1: Type III hard-anodised aluminium (dark charcoal,
	# satin-matte, rubbed to grey/bare alloy on contact edges), manganese-
	# phosphate steel, black polymer furniture, FDE rail panels.
	"M4 hard anodized": {"color": Color(0.165, 0.168, 0.172), "metallic": 0.22, "roughness": 0.62, "pattern": 6, "edge_wear": 0.7, "wear": Color(0.64, 0.64, 0.62)},
	"M4 rail anodized": {"color": Color(0.15, 0.152, 0.156), "metallic": 0.22, "roughness": 0.6, "pattern": 6, "edge_wear": 0.8, "wear": Color(0.66, 0.66, 0.64)},
	"M4 phosphate steel": {"color": Color(0.19, 0.19, 0.182), "metallic": 0.3, "roughness": 0.7, "pattern": 3, "grain": 0.9, "edge_wear": 0.4, "wear": Color(0.55, 0.55, 0.54)},
	"M4 bolt carrier": {"color": Color(0.17, 0.17, 0.165), "metallic": 0.55, "roughness": 0.5, "pattern": 3, "mottle": 0.6, "grain": 0.6, "edge_wear": 0.75, "wear": Color(0.64, 0.64, 0.62)},
	"M4 rail cover": {"color": Color(0.52, 0.44, 0.32), "metallic": 0.0, "roughness": 0.68, "pattern": 0, "edge_wear": 0.4, "dust": 0.8},
	"M4 polymer": {"color": Color(0.115, 0.117, 0.12), "metallic": 0.0, "roughness": 0.64, "pattern": 0, "grain": 0.8, "edge_wear": 0.35},
	"M4 grip checkering": {"color": Color(0.115, 0.117, 0.12), "metallic": 0.0, "roughness": 0.7, "pattern": 1, "pitch": 0.0016, "bump": 0.7, "edge_wear": 0.25},
	"M4 PMAG polymer": {"color": Color(0.11, 0.112, 0.115), "metallic": 0.0, "roughness": 0.6, "pattern": 2, "pitch": 0.0009, "bump": 0.35, "edge_wear": 0.45},
	"M4 rubber pad": {"color": Color(0.085, 0.085, 0.085), "metallic": 0.0, "roughness": 0.9, "pattern": 7, "pitch": 0.0012, "bump": 0.5},
	"M4 sight steel": {"color": Color(0.15, 0.152, 0.155), "metallic": 0.4, "roughness": 0.58, "pattern": 3, "mottle": 0.5, "edge_wear": 0.55, "wear": Color(0.58, 0.58, 0.58)},
	"M4 engraving": {"color": Color(0.5, 0.5, 0.49), "metallic": 0.6, "roughness": 0.45, "pattern": 8},
	"M4 selector paint": {"color": Color(0.85, 0.85, 0.82), "metallic": 0.0, "roughness": 0.55, "pattern": 8},
	# TOBIKAGE = Dragunov SVD: blued steel, stained parallel-laminated birch
	# (plies stacked across the stock's width, grain along the gun).
	"SVD blued steel": {"color": Color(0.14, 0.145, 0.158), "metallic": 0.68, "roughness": 0.5, "pattern": 4, "grain": 0.6, "edge_wear": 0.55, "wear": Color(0.6, 0.61, 0.62)},
	"SVD black oxide": {"color": Color(0.12, 0.12, 0.125), "metallic": 0.6, "roughness": 0.52, "pattern": 4, "grain": 0.4, "edge_wear": 0.45, "wear": Color(0.55, 0.55, 0.55)},
	"SVD laminated birch": {"color": Color(0.24, 0.12, 0.075), "metallic": 0.0, "roughness": 0.44, "pattern": 5, "grain": 1.0, "grain_axis": Vector3(1, 0, 0), "ply_mm": 1.6, "ply_axis": Vector3(0, 0, 1), "edge_wear": 0.5, "polish": 0.8, "dust": 0.6},
	"SVD rubber butt pad": {"color": Color(0.085, 0.085, 0.085), "metallic": 0.0, "roughness": 0.9, "pattern": 7, "pitch": 0.0012, "bump": 0.5},
	"SVD magazine steel": {"color": Color(0.14, 0.14, 0.145), "metallic": 0.6, "roughness": 0.55, "pattern": 4, "grain": 0.4, "edge_wear": 0.35,"wear": Color(0.55, 0.55, 0.55)},
	"SVD lacquered steel case": {"color": Color(0.48, 0.43, 0.31), "metallic": 0.8, "roughness": 0.42, "pattern": 8},
	"SVD stamping": {"color": Color(0.4, 0.4, 0.41), "metallic": 0.7, "roughness": 0.45, "pattern": 8},
	# HAYATE = M40A5: parkerised action, black barrel, olive McMillan fibreglass.
	"M40 parkerised steel": {"color": Color(0.17, 0.175, 0.17), "metallic": 0.3, "roughness": 0.7, "pattern": 3, "grain": 0.9, "edge_wear": 0.45, "wear": Color(0.55, 0.55, 0.54)},
	"M40 black steel": {"color": Color(0.13, 0.132, 0.138), "metallic": 0.7, "roughness": 0.42, "pattern": 4, "grain": 0.5, "edge_wear": 0.5, "wear": Color(0.58, 0.58, 0.6)},
	"M40 polished bolt": {"color": Color(0.7, 0.7, 0.7), "metallic": 1.0, "roughness": 0.24, "pattern": 4, "grain": 0.6},
	# Moulded-in USMC OD green (the earlier 0.33/0.34/0.24 read pale khaki).
	"M40 McMillan olive": {"color": Color(0.22, 0.24, 0.18), "metallic": 0.0, "roughness": 0.6, "pattern": 2, "pitch": 0.004, "bump": 0.15, "grain": 1.2, "edge_wear": 0.35},
	"M40 McMillan texture": {"color": Color(0.21, 0.23, 0.17),"metallic": 0.0, "roughness": 0.72, "pattern": 2, "pitch": 0.0009, "bump": 0.7, "edge_wear": 0.3},
	"M40 recoil pad": {"color": Color(0.085, 0.085, 0.085), "metallic": 0.0, "roughness": 0.9, "pattern": 7, "pitch": 0.0012, "bump": 0.5},
	"M40 anodised alloy": {"color": Color(0.14, 0.143, 0.147), "metallic": 0.22, "roughness": 0.6, "pattern": 6, "edge_wear": 0.6, "wear": Color(0.64, 0.64, 0.62)},
	"M40 engraving": {"color": Color(0.5, 0.5, 0.49), "metallic": 0.6, "roughness": 0.45, "pattern": 8},
	# YUZURU = Accuracy International AW: black stock halves, alloy chassis.
	"AW black steel": {"color": Color(0.13, 0.132, 0.138), "metallic": 0.7, "roughness": 0.42, "pattern": 4, "grain": 0.5, "edge_wear": 0.5, "wear": Color(0.58, 0.58, 0.6)},
	"AW action finish": {"color": Color(0.16, 0.162, 0.165), "metallic": 0.35, "roughness": 0.62, "pattern": 3, "mottle": 0.5, "edge_wear": 0.45, "wear": Color(0.55, 0.55, 0.55)},
	"AW chassis alloy": {"color": Color(0.14, 0.143, 0.147), "metallic": 0.22, "roughness": 0.6, "pattern": 6, "edge_wear": 0.6, "wear": Color(0.64, 0.64, 0.62)},
	"AW stock polymer": {"color": Color(0.105, 0.107, 0.11), "metallic": 0.0, "roughness": 0.62, "pattern": 2, "pitch": 0.003, "bump": 0.12, "grain": 1.0, "edge_wear": 0.35},
	"AW grip texture": {"color": Color(0.105, 0.107, 0.11), "metallic": 0.0, "roughness": 0.72, "pattern": 2, "pitch": 0.0009, "bump": 0.7, "edge_wear": 0.25},
	"AW butt pad": {"color": Color(0.085, 0.085, 0.085), "metallic": 0.0, "roughness": 0.9, "pattern": 7, "pitch": 0.0012, "bump": 0.5},
	"AW bolt": {"color": Color(0.62, 0.62, 0.62), "metallic": 1.0, "roughness": 0.3, "pattern": 4, "grain": 0.6},
	"AW engraving": {"color": Color(0.5, 0.5, 0.49), "metallic": 0.6, "roughness": 0.45, "pattern": 8},
	"AW bullet jacket": {"color": Color(0.72, 0.42, 0.27), "metallic": 1.0, "roughness": 0.32, "pattern": 8},
	# SHIGURE = CZ Scorpion EVO 3 A1: anodised upper, glass-filled polymer
	# lower and furniture, smoked translucent magazine.
	"EVO anodised upper": {"color": Color(0.13, 0.132, 0.136), "metallic": 0.22, "roughness": 0.6, "pattern": 6, "edge_wear": 0.6, "wear": Color(0.62, 0.62, 0.6)},
	"EVO polymer": {"color": Color(0.105, 0.107, 0.11), "metallic": 0.0, "roughness": 0.62, "pattern": 2, "pitch": 0.0025, "bump": 0.12, "edge_wear": 0.35},
	"EVO grip texture": {"color": Color(0.105, 0.107, 0.11), "metallic": 0.0, "roughness": 0.74, "pattern": 1, "pitch": 0.0014, "bump": 0.7, "edge_wear": 0.2},
	"EVO steel": {"color": Color(0.16, 0.16, 0.165), "metallic": 0.55, "roughness": 0.5, "pattern": 3, "mottle": 0.4, "edge_wear": 0.45, "wear": Color(0.55, 0.55, 0.55)},
	"EVO smoke magazine": {"color": Color(0.17, 0.165, 0.155), "metallic": 0.0, "roughness": 0.3, "pattern": 0, "grain": 0.6, "edge_wear": 0.3},
	"EVO selector paint": {"color": Color(0.75, 0.12, 0.08), "metallic": 0.0, "roughness": 0.5, "pattern": 8},
	"EVO marking": {"color": Color(0.2, 0.2, 0.21), "metallic": 0.3, "roughness": 0.62, "pattern": 8},
	# KITE = FN SCAR 17S: FDE hard-anodised upper, FDE polymer lower/stock.
	"SCAR FDE anodised": {"color": Color(0.53, 0.46, 0.36), "metallic": 0.15, "roughness": 0.62, "pattern": 6, "edge_wear": 0.55, "wear": Color(0.7, 0.69, 0.66)},
	"SCAR FDE polymer": {"color": Color(0.42, 0.36, 0.29), "metallic": 0.0, "roughness": 0.64, "pattern": 2, "pitch": 0.0025, "bump": 0.12, "edge_wear": 0.35},
	"SCAR grip texture": {"color": Color(0.41, 0.35, 0.28), "metallic": 0.0, "roughness": 0.74, "pattern": 1, "pitch": 0.0014, "bump": 0.7, "edge_wear": 0.2},
	"SCAR black steel": {"color": Color(0.13, 0.132, 0.138), "metallic": 0.55, "roughness": 0.5, "pattern": 3, "mottle": 0.4, "edge_wear": 0.45, "wear": Color(0.55, 0.55, 0.55)},
	"SCAR stock polymer": {"color": Color(0.45, 0.39, 0.31), "metallic": 0.0, "roughness": 0.62, "pattern": 2, "pitch": 0.0025, "bump": 0.12, "edge_wear": 0.35},
	"SCAR phosphate steel": {"color": Color(0.42, 0.42, 0.40), "metallic": 0.55, "roughness": 0.6, "pattern": 3, "grain": 0.8, "edge_wear": 0.4, "wear": Color(0.6, 0.6, 0.58)},
	"SCAR magazine": {"color": Color(0.42, 0.36, 0.27), "metallic": 0.25, "roughness": 0.6, "pattern": 3, "mottle": 0.3, "edge_wear": 0.5, "wear": Color(0.62, 0.6, 0.56)},
	"SCAR rubber": {"color": Color(0.085, 0.085, 0.085), "metallic": 0.0, "roughness": 0.9, "pattern": 7, "pitch": 0.0012, "bump": 0.5},
	"SCAR magazine steel": {"color": Color(0.14, 0.14, 0.145), "metallic": 0.6, "roughness": 0.55, "pattern": 3, "edge_wear": 0.6, "wear": Color(0.5, 0.5, 0.5)},
	"SCAR marking": {"color": Color(0.36, 0.3, 0.22), "metallic": 0.2, "roughness": 0.6, "pattern": 8},
}

# Generic finishes for names not listed above, picked by keyword (first match
# wins). The imported albedo colour is kept so builders can add new parts
# without touching this table.
const KEYWORD_FINISHES := [
	[["bore", "paint", "white", "follower", "glass", "lens", "tritium", "fiber", "fibre", "marking", "engrav", "stamp", "laser", "emissive"], {}],
	[["brass", "copper"], {"metallic": 1.0, "roughness": 0.32, "pattern": 8}],
	[["rubber", " pad"], {"metallic": 0.0, "roughness": 0.9, "pattern": 7, "pitch": 0.0012, "bump": 0.5}],
	[["laminat", "birch", "wood", "walnut", "beech"], {"metallic": 0.0, "roughness": 0.4, "pattern": 5, "edge_wear": 0.5, "polish": 0.8}],
	[["anodi"], {"metallic": 0.22, "roughness": 0.6, "pattern": 6, "edge_wear": 0.6, "wear": Color(0.64, 0.64, 0.62)}],
	[["parker", "phosphate", "nitrid", "dlc", "cerakote"], {"metallic": 0.3, "roughness": 0.68, "pattern": 3, "edge_wear": 0.45, "wear": Color(0.55, 0.55, 0.54)}],
	[["blued", "oxide", "steel", "bolt"], {"metallic": 0.7, "roughness": 0.44, "pattern": 4, "edge_wear": 0.5, "wear": Color(0.6, 0.6, 0.6)}],
	[["texture", "stipple", "checker"], {"metallic": 0.0, "roughness": 0.72, "pattern": 2, "pitch": 0.0012, "bump": 0.6, "edge_wear": 0.25}],
	[["polymer", "plastic", "nylon", "fiberglass", "fibreglass", "mcmillan"], {"metallic": 0.0, "roughness": 0.62, "pattern": 0, "edge_wear": 0.35}],
]

func _ready() -> void:
	var geometry := get_node_or_null("Geometry")
	if geometry != null:
		apply(geometry)

static func apply(root: Node) -> int:
	var changed := 0
	var made := {}
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(surface)
			if source == null:
				continue
			var key := source.resource_name
			if not made.has(key):
				var finish: Dictionary = FINISHES.get(key, _infer(key, source))
				made[key] = _material(key, finish) if not finish.is_empty() else null
			if made[key] == null:
				continue
			mesh.set_surface_override_material(surface, made[key])
			changed += 1
	return changed

static func _infer(key: String, source: Material) -> Dictionary:
	var lower := key.to_lower()
	for entry: Array in KEYWORD_FINISHES:
		for word: String in entry[0]:
			if lower.contains(word):
				var f: Dictionary = (entry[1] as Dictionary).duplicate()
				if not f.is_empty() and not f.has("color") and source is BaseMaterial3D:
					f["color"] = (source as BaseMaterial3D).albedo_color
				return f
	return {}

static func _material(key: String, f: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.resource_name = key
	m.shader = SHADER
	m.set_shader_parameter("albedo_color", f.get("color", Color(0.05, 0.05, 0.05)))
	m.set_shader_parameter("metallic", f.get("metallic", 0.0))
	m.set_shader_parameter("roughness", f.get("roughness", 0.6))
	m.set_shader_parameter("pattern", f.get("pattern", 0))
	m.set_shader_parameter("pitch", f.get("pitch", 0.0016))
	m.set_shader_parameter("bump", f.get("bump", 1.0))
	m.set_shader_parameter("grain", f.get("grain", 1.0))
	m.set_shader_parameter("edge_wear", f.get("edge_wear", 0.0))
	var wear: Color = f.get("wear", Color(0.32, 0.33, 0.34))
	m.set_shader_parameter("wear_color", Vector3(wear.r, wear.g, wear.b))
	m.set_shader_parameter("grain_axis", f.get("grain_axis", Vector3(1, 0, 0)))
	m.set_shader_parameter("ply_axis", f.get("ply_axis", Vector3(0, 0, 1)))
	m.set_shader_parameter("ply_mm", f.get("ply_mm", 0.0))
	m.set_shader_parameter("mottle", f.get("mottle", 1.0))
	m.set_shader_parameter("dust", f.get("dust", 0.5))
	m.set_shader_parameter("polish", f.get("polish", 0.5))
	return m
