extends Node3D

# Applies the real-counterpart finishes to an assembly's imported materials by
# material name. Unknown materials keep their imported PBR values.
const SHADER = preload("res://scripts/weapon_real_finish.gdshader")

# pattern: 0 moulding, 1 raised grip texture, 2 stipple, 3 parkerised,
# 4 polished/blued steel, 5 wood. Values are colour, metallic, roughness.
const FINISHES := {
	# AKANE = Glock 17 Gen 5: nDLC slide/barrel, black polymer frame.
	"A9 nDLC slide": {"color": Color(0.115, 0.12, 0.125), "metallic": 0.62, "roughness": 0.42, "pattern": 3, "grain": 0.8, "edge_wear": 0.35, "wear": Color(0.36, 0.37, 0.38)},
	"A9 nDLC barrel": {"color": Color(0.13, 0.135, 0.14), "metallic": 0.75, "roughness": 0.32, "pattern": 4, "grain": 0.25, "edge_wear": 0.5, "wear": Color(0.55, 0.55, 0.55)},
	"A9 frame polymer": {"color": Color(0.088, 0.09, 0.092), "metallic": 0.0, "roughness": 0.58, "pattern": 0, "grain": 0.7},
	"A9 grip texture": {"color": Color(0.092, 0.094, 0.096), "metallic": 0.0, "roughness": 0.72, "pattern": 1, "pitch": 0.0011, "bump": 0.65},
	"A9 magazine polymer": {"color": Color(0.13, 0.133, 0.136), "metallic": 0.0, "roughness": 0.50, "pattern": 0, "grain": 0.7},
	"A9 sight polymer": {"color": Color(0.12, 0.122, 0.125), "metallic": 0.0, "roughness": 0.55, "pattern": 0},
	"A9 blackened steel": {"color": Color(0.12, 0.124, 0.128), "metallic": 0.7, "roughness": 0.48, "pattern": 3, "edge_wear": 0.4, "wear": Color(0.6, 0.6, 0.6)},
	"A9 bright steel": {"color": Color(0.74, 0.74, 0.73), "metallic": 1.0, "roughness": 0.30, "pattern": 4},
	"A9 laser marking": {"color": Color(0.42, 0.43, 0.44), "metallic": 0.25, "roughness": 0.62, "pattern": 0},
	# RAIDEN = Colt M4A1: Type III hard-anodised aluminium (dark grey, worn to
	# bare alloy on edges), manganese-phosphate steel, black polymer furniture.
	"M4 hard anodized": {"color": Color(0.155, 0.158, 0.162), "metallic": 0.35, "roughness": 0.55, "pattern": 3, "grain": 0.6, "edge_wear": 0.55, "wear": Color(0.58, 0.58, 0.57)},
	"M4 rail anodized": {"color": Color(0.14, 0.142, 0.146), "metallic": 0.35, "roughness": 0.52, "pattern": 3, "grain": 0.6, "edge_wear": 0.7, "wear": Color(0.6, 0.6, 0.59)},
	"M4 phosphate steel": {"color": Color(0.17, 0.172, 0.168), "metallic": 0.55, "roughness": 0.62, "pattern": 3, "grain": 0.9, "edge_wear": 0.35, "wear": Color(0.5, 0.5, 0.5)},
	"M4 bolt carrier": {"color": Color(0.2, 0.2, 0.2), "metallic": 0.8, "roughness": 0.42, "pattern": 4, "grain": 0.6, "edge_wear": 0.6, "wear": Color(0.62, 0.62, 0.6)},
	"M4 polymer": {"color": Color(0.11, 0.112, 0.115), "metallic": 0.0, "roughness": 0.62, "pattern": 0, "grain": 0.8},
	"M4 grip checkering": {"color": Color(0.11, 0.112, 0.115), "metallic": 0.0, "roughness": 0.7, "pattern": 1, "pitch": 0.0016, "bump": 0.7},
	"M4 PMAG polymer": {"color": Color(0.105, 0.107, 0.11), "metallic": 0.0, "roughness": 0.6, "pattern": 2, "pitch": 0.0009, "bump": 0.4},
	"M4 rubber pad": {"color": Color(0.08, 0.08, 0.08), "metallic": 0.0, "roughness": 0.88, "pattern": 2, "pitch": 0.0012, "bump": 0.5},
	"M4 sight steel": {"color": Color(0.14, 0.142, 0.145), "metallic": 0.6, "roughness": 0.5, "pattern": 3, "edge_wear": 0.5, "wear": Color(0.55, 0.55, 0.55)},
	"M4 engraving": {"color": Color(0.5, 0.5, 0.49), "metallic": 0.6, "roughness": 0.45, "pattern": 0},
	"M4 selector paint": {"color": Color(0.85, 0.85, 0.82), "metallic": 0.0, "roughness": 0.55, "pattern": 0},
	# TOBIKAGE = Dragunov SVD: blued steel, stained laminated birch.
	"SVD blued steel": {"color": Color(0.15, 0.155, 0.165), "metallic": 0.68, "roughness": 0.52, "pattern": 4, "grain": 0.6, "edge_wear": 0.55, "wear": Color(0.55, 0.56, 0.57)},
	"SVD black oxide": {"color": Color(0.12, 0.12, 0.125), "metallic": 0.65, "roughness": 0.5, "pattern": 3, "edge_wear": 0.4, "wear": Color(0.5, 0.5, 0.5)},
	"SVD laminated birch": {"color": Color(0.30, 0.125, 0.065), "metallic": 0.0, "roughness": 0.42, "pattern": 5, "grain": 1.0, "grain_axis": Vector3(1, 0, 0)},
	"SVD rubber butt pad": {"color": Color(0.08, 0.08, 0.08), "metallic": 0.0, "roughness": 0.88, "pattern": 2, "pitch": 0.0012, "bump": 0.5},
	"SVD magazine steel": {"color": Color(0.14, 0.14, 0.145), "metallic": 0.6, "roughness": 0.55, "pattern": 3, "edge_wear": 0.6, "wear": Color(0.5, 0.5, 0.5)},
	"SVD lacquered steel case": {"color": Color(0.5, 0.45, 0.33), "metallic": 0.8, "roughness": 0.45, "pattern": 0},
	"SVD stamping": {"color": Color(0.4, 0.4, 0.41), "metallic": 0.7, "roughness": 0.45, "pattern": 0},
	# HAYATE = M40A5: parkerised action, black barrel, olive McMillan fibreglass.
	"M40 parkerised steel": {"color": Color(0.16, 0.165, 0.16), "metallic": 0.55, "roughness": 0.62, "pattern": 3, "grain": 0.9, "edge_wear": 0.45, "wear": Color(0.5, 0.5, 0.5)},
	"M40 black steel": {"color": Color(0.12, 0.122, 0.128), "metallic": 0.72, "roughness": 0.42, "pattern": 4, "grain": 0.5, "edge_wear": 0.5, "wear": Color(0.5, 0.5, 0.52)},
	"M40 polished bolt": {"color": Color(0.7, 0.7, 0.7), "metallic": 1.0, "roughness": 0.24, "pattern": 4, "grain": 0.6},
	"M40 McMillan olive": {"color": Color(0.33, 0.34, 0.24), "metallic": 0.0, "roughness": 0.58, "pattern": 2, "pitch": 0.004, "bump": 0.15, "grain": 1.2},
	"M40 McMillan texture": {"color": Color(0.31, 0.32, 0.23), "metallic": 0.0, "roughness": 0.72, "pattern": 2, "pitch": 0.0009, "bump": 0.7},
	"M40 recoil pad": {"color": Color(0.08, 0.08, 0.08), "metallic": 0.0, "roughness": 0.88, "pattern": 2, "pitch": 0.0012, "bump": 0.5},
	"M40 anodised alloy": {"color": Color(0.13, 0.133, 0.137), "metallic": 0.4, "roughness": 0.5, "pattern": 3, "edge_wear": 0.6, "wear": Color(0.6, 0.6, 0.6)},
	"M40 engraving": {"color": Color(0.5, 0.5, 0.49), "metallic": 0.6, "roughness": 0.45, "pattern": 0},
	# YUZURU = Accuracy International AW: black stock halves, alloy chassis.
	"AW black steel": {"color": Color(0.12, 0.122, 0.128), "metallic": 0.72, "roughness": 0.42, "pattern": 4, "grain": 0.5, "edge_wear": 0.5, "wear": Color(0.5, 0.5, 0.52)},
	"AW action finish": {"color": Color(0.15, 0.152, 0.155), "metallic": 0.5, "roughness": 0.56, "pattern": 3, "edge_wear": 0.45, "wear": Color(0.5, 0.5, 0.5)},
	"AW chassis alloy": {"color": Color(0.14, 0.142, 0.146), "metallic": 0.4, "roughness": 0.5, "pattern": 3, "edge_wear": 0.6, "wear": Color(0.6, 0.6, 0.6)},
	"AW stock polymer": {"color": Color(0.105, 0.107, 0.11), "metallic": 0.0, "roughness": 0.6, "pattern": 2, "pitch": 0.003, "bump": 0.12, "grain": 1.0},
	"AW grip texture": {"color": Color(0.105, 0.107, 0.11), "metallic": 0.0, "roughness": 0.72, "pattern": 2, "pitch": 0.0009, "bump": 0.7},
	"AW butt pad": {"color": Color(0.08, 0.08, 0.08), "metallic": 0.0, "roughness": 0.88, "pattern": 2, "pitch": 0.0012, "bump": 0.5},
	"AW bolt": {"color": Color(0.62, 0.62, 0.62), "metallic": 1.0, "roughness": 0.3, "pattern": 4, "grain": 0.6},
	"AW engraving": {"color": Color(0.5, 0.5, 0.49), "metallic": 0.6, "roughness": 0.45, "pattern": 0},
	# SHIGURE = CZ Scorpion EVO 3 A1: anodised upper, glass-filled polymer
	# lower and furniture, smoked translucent magazine.
	"EVO anodised upper": {"color": Color(0.12, 0.122, 0.126), "metallic": 0.35, "roughness": 0.55, "pattern": 3, "grain": 0.6, "edge_wear": 0.55, "wear": Color(0.55, 0.55, 0.55)},
	"EVO polymer": {"color": Color(0.105, 0.107, 0.11), "metallic": 0.0, "roughness": 0.62, "pattern": 2, "pitch": 0.0025, "bump": 0.12},
	"EVO grip texture": {"color": Color(0.105, 0.107, 0.11), "metallic": 0.0, "roughness": 0.74, "pattern": 1, "pitch": 0.0014, "bump": 0.7},
	"EVO steel": {"color": Color(0.16, 0.16, 0.165), "metallic": 0.7, "roughness": 0.45, "pattern": 3, "edge_wear": 0.4, "wear": Color(0.5, 0.5, 0.5)},
	"EVO smoke magazine": {"color": Color(0.17, 0.165, 0.155), "metallic": 0.0, "roughness": 0.3, "pattern": 0, "grain": 0.6},
	"EVO marking": {"color": Color(0.55, 0.55, 0.55), "metallic": 0.3, "roughness": 0.5, "pattern": 0},
	# KITE = FN SCAR 17S: FDE hard-anodised upper, FDE polymer lower/stock.
	"SCAR FDE anodised": {"color": Color(0.53, 0.45, 0.33), "metallic": 0.25, "roughness": 0.55, "pattern": 3, "grain": 0.6, "edge_wear": 0.55, "wear": Color(0.68, 0.66, 0.62)},
	"SCAR FDE polymer": {"color": Color(0.52, 0.44, 0.32), "metallic": 0.0, "roughness": 0.62, "pattern": 2, "pitch": 0.0025, "bump": 0.12},
	"SCAR grip texture": {"color": Color(0.5, 0.42, 0.31), "metallic": 0.0, "roughness": 0.74, "pattern": 1, "pitch": 0.0014, "bump": 0.7},
	"SCAR black steel": {"color": Color(0.12, 0.122, 0.128), "metallic": 0.7, "roughness": 0.45, "pattern": 3, "edge_wear": 0.45, "wear": Color(0.5, 0.5, 0.5)},
	"SCAR rubber": {"color": Color(0.08, 0.08, 0.08), "metallic": 0.0, "roughness": 0.88, "pattern": 2, "pitch": 0.0012, "bump": 0.5},
	"SCAR magazine steel": {"color": Color(0.14, 0.14, 0.145), "metallic": 0.6, "roughness": 0.55, "pattern": 3, "edge_wear": 0.6, "wear": Color(0.5, 0.5, 0.5)},
	"SCAR marking": {"color": Color(0.36, 0.3, 0.22), "metallic": 0.2, "roughness": 0.6, "pattern": 0},
}

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
			if source == null or not FINISHES.has(source.resource_name):
				continue
			var key := source.resource_name
			if not made.has(key):
				made[key] = _material(key, FINISHES[key])
			mesh.set_surface_override_material(surface, made[key])
			changed += 1
	return changed

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
	return m
