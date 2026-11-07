"""Shared Blender helpers for the real-counterpart weapon rebuilds.

All public functions take Godot coordinates in metres: -X forward (muzzle),
+Y up, +Z = the weapon's left side. Blender is Z-up; the glTF exporter's
+Y-up conversion turns Blender (x, -z, y) back into Godot (x, y, z).
"""
import bpy, bmesh, math
from mathutils import Vector, Matrix


def cv(p):
    return Vector((p[0], -p[2], p[1]))


def reset():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.curves):
        for item in list(block):
            if item.users == 0:
                block.remove(item)


_MATS = {}


def mat(name, color=(0.05, 0.05, 0.05), metal=0.0, rough=0.6):
    if name in _MATS:
        return _MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bs = m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = (*color, 1)
    bs.inputs['Metallic'].default_value = metal
    bs.inputs['Roughness'].default_value = rough
    m.diffuse_color = (*color, 1)
    _MATS[name] = m
    return m


def _obj(name, bm, material=None):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    if material is not None:
        o.data.materials.append(material)
    return o


def _fix_normals(o):
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(o.data)
    bm.free()


def extrude_xy(name, pts, z0, z1, material=None):
    """Side-view polygon [(x, y)] extruded across Z from z0 to z1."""
    bm = bmesh.new()
    a = [bm.verts.new(cv((x, y, z0))) for x, y in pts]
    b = [bm.verts.new(cv((x, y, z1))) for x, y in pts]
    n = len(pts)
    bm.faces.new(a)
    bm.faces.new(list(reversed(b)))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[i], a[j], b[j], b[i]))
    o = _obj(name, bm, material)
    _fix_normals(o)
    return o


def extrude_zy(name, pts, x0, x1, material=None):
    """Front-view polygon [(z, y)] extruded along X from x0 to x1."""
    bm = bmesh.new()
    a = [bm.verts.new(cv((x0, y, z))) for z, y in pts]
    b = [bm.verts.new(cv((x1, y, z))) for z, y in pts]
    n = len(pts)
    bm.faces.new(a)
    bm.faces.new(list(reversed(b)))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[i], a[j], b[j], b[i]))
    o = _obj(name, bm, material)
    _fix_normals(o)
    return o


def extrude_xz(name, pts, y0, y1, material=None):
    """Top-view polygon [(x, z)] extruded along Y from y0 to y1."""
    bm = bmesh.new()
    a = [bm.verts.new(cv((x, y0, z))) for x, z in pts]
    b = [bm.verts.new(cv((x, y1, z))) for x, z in pts]
    n = len(pts)
    bm.faces.new(a)
    bm.faces.new(list(reversed(b)))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[i], a[j], b[j], b[i]))
    o = _obj(name, bm, material)
    _fix_normals(o)
    return o


def loft(name, rings, material=None, cap=True):
    """rings: list of lists of Godot points, same count per ring, in order."""
    bm = bmesh.new()
    vs = [[bm.verts.new(cv(p)) for p in ring] for ring in rings]
    n = len(rings[0])
    for r in range(len(rings) - 1):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((vs[r][i], vs[r][j], vs[r + 1][j], vs[r + 1][i]))
    if cap:
        bm.faces.new(vs[0])
        bm.faces.new(list(reversed(vs[-1])))
    o = _obj(name, bm, material)
    _fix_normals(o)
    return o


def rounded_rect(cx, cy, w, h, r, seg=4):
    """2D rounded rectangle centred at (cx, cy); returns CCW points."""
    r = min(r, w / 2 - 1e-6, h / 2 - 1e-6)
    pts = []
    for k, (ox, oy) in enumerate(((w / 2 - r, h / 2 - r), (-w / 2 + r, h / 2 - r), (-w / 2 + r, -h / 2 + r), (w / 2 - r, -h / 2 + r))):
        for s in range(seg + 1):
            a = math.pi / 2 * k + math.pi / 2 * s / seg
            pts.append((cx + ox + r * math.cos(a), cy + oy + r * math.sin(a)))
    return pts


def superellipse(cx, cy, w, h, n=3.2, count=32):
    pts = []
    for i in range(count):
        a = 2 * math.pi * i / count
        c, s = math.cos(a), math.sin(a)
        pts.append((cx + w / 2 * math.copysign(abs(c) ** (2 / n), c), cy + h / 2 * math.copysign(abs(s) ** (2 / n), s)))
    return pts


def cylinder(name, a, b, radius, material=None, seg=32, radius_b=None):
    """Cylinder from Godot point a to Godot point b."""
    radius_b = radius if radius_b is None else radius_b
    A, B = cv(a), cv(b)
    axis = (B - A)
    length = axis.length
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=radius, radius2=radius_b, depth=length)
    o = _obj(name, bm, material)
    rot = axis.normalized().to_track_quat('Z', 'Y').to_matrix().to_4x4()
    o.matrix_world = Matrix.Translation((A + B) / 2) @ rot
    apply(o)
    smooth(o)
    return o


def tube(name, a, b, r_out, r_in, material=None, seg=40):
    """Hollow tube built explicitly (outer wall, bore wall, two annular ends)."""
    A, B = cv(a), cv(b)
    axis = (B - A).normalized()
    rot = axis.to_track_quat('Z', 'Y').to_matrix()
    u, v = rot.col[0], rot.col[1]
    bm = bmesh.new()
    rings = []
    for centre in (A, B):
        for r in (r_out, r_in):
            rings.append([bm.verts.new(centre + (u * math.cos(2 * math.pi * i / seg) + v * math.sin(2 * math.pi * i / seg)) * r) for i in range(seg)])
    oa, ia, ob, ib = rings
    for i in range(seg):
        j = (i + 1) % seg
        bm.faces.new((oa[i], oa[j], ob[j], ob[i]))
        bm.faces.new((ia[i], ib[i], ib[j], ia[j]))
        bm.faces.new((oa[i], ia[i], ia[j], oa[j]))
        bm.faces.new((ob[i], ob[j], ib[j], ib[i]))
    o = _obj(name, bm, material)
    _fix_normals(o)
    smooth(o)
    return o


def box(name, center, size, material=None):
    x, y, z = center
    sx, sy, sz = size
    pts = [(x - sx / 2, y - sy / 2), (x + sx / 2, y - sy / 2), (x + sx / 2, y + sy / 2), (x - sx / 2, y + sy / 2)]
    return extrude_xy(name, pts, z - sz / 2, z + sz / 2, material)


def apply(o):
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def _apply_mod(o, m):
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier=m.name)


def boolean(target, cutter, op='DIFFERENCE', keep=False, solver='EXACT'):
    m = target.modifiers.new('bool', 'BOOLEAN')
    m.operation = op
    try:
        m.solver = solver
    except TypeError:
        m.solver = 'EXACT'
    if isinstance(cutter, (list, tuple)):
        coll = bpy.data.collections.new('cutters')
        bpy.context.scene.collection.children.link(coll)
        for c in cutter:
            for uc in list(c.users_collection):
                uc.objects.unlink(c)
            coll.objects.link(c)
        m.operand_type = 'COLLECTION'
        m.collection = coll
        _apply_mod(target, m)
        if not keep:
            for c in list(coll.objects):
                bpy.data.objects.remove(c, do_unlink=True)
        bpy.data.collections.remove(coll)
    else:
        m.object = cutter
        _apply_mod(target, m)
        if not keep:
            bpy.data.objects.remove(cutter, do_unlink=True)
    return target


BEVEL_SCALE = 3.0  # real machined/moulded edges are rounder than CAD-sharp boxes
# Moulded, laminated and rubber parts come out of the mould or the sander with
# much softer radii than machined metal; at first-person distance a 1 mm edge
# is under a pixel and the part reads as a flat cut-out, so they round more.
SOFT_BEVEL = 1.6
SOFT_WORDS = ('polymer', 'stock', 'grip', 'texture', 'mcmillan', 'fibreglass', 'fiberglass',
              'laminat', 'birch', 'wood', 'rubber', 'pad', 'pmag', 'magazine polymer', 'smoke magazine')


def _soft(o):
    names = [m.name.lower() for m in o.data.materials if m] if o.type == 'MESH' else []
    return any(w in n for n in names for w in SOFT_WORDS) and not any('steel' in n or 'anodi' in n for n in names[:1])


def bevel(o, width=0.0004, segments=2, angle=35.0, harden=True):
    m = o.modifiers.new('bevel', 'BEVEL')
    soft = _soft(o)
    m.width = width * BEVEL_SCALE * (SOFT_BEVEL if soft else 1.0)
    m.segments = max(segments, 4 if soft else 3)
    m.use_clamp_overlap = True
    m.limit_method = 'ANGLE'
    m.angle_limit = math.radians(angle)
    m.harden_normals = harden
    m.miter_outer = 'MITER_ARC'
    co = [v.co.copy() for v in o.data.vertices]
    lo = Vector([min(c[i] for c in co) for i in range(3)]) if co else None
    hi = Vector([max(c[i] for c in co) for i in range(3)]) if co else None
    _apply_mod(o, m)
    if co:
        # A bevel over sliver faces can throw a vertex to the origin; drop any
        # geometry that left the part's own bounds rather than ship a spike.
        pad = 0.0005
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bad = [v for v in bm.verts if any(v.co[i] < lo[i] - pad or v.co[i] > hi[i] + pad for i in range(3))]
        if bad:
            print('BEVEL_SPIKES', o.name, len(bad))
            bmesh.ops.delete(bm, geom=bad, context='VERTS')
            bm.to_mesh(o.data)
        bm.free()
    smooth(o, angle)
    # Flat machined faces stay flat; only the bevels carry the shading turn.
    n = o.modifiers.new('weighted', 'WEIGHTED_NORMAL')
    n.mode = 'FACE_AREA'
    n.weight = 100
    n.keep_sharp = True
    _apply_mod(o, n)
    return o


def smooth(o, angle=35.0):
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    try:
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(angle))
    except Exception:
        bpy.ops.object.shade_smooth()
    return o


def flat(o):
    for p in o.data.polygons:
        p.use_smooth = False
    return o


def moulded(o, voxel=0.00035, smooth_factor=0.5, smooth_iter=4, ratio=0.12):
    """Voxel-union overlapping parts, soften like an injection moulding, decimate."""
    m = o.modifiers.new('remesh', 'REMESH')
    m.mode = 'VOXEL'
    m.voxel_size = voxel
    m.adaptivity = 0.0
    _apply_mod(o, m)
    if smooth_iter:
        s = o.modifiers.new('soften', 'SMOOTH')
        s.factor = smooth_factor
        s.iterations = smooth_iter
        _apply_mod(o, s)
    if ratio < 1.0:
        d = o.modifiers.new('decimate', 'DECIMATE')
        d.ratio = ratio
        d.use_collapse_triangulate = True
        _apply_mod(o, d)
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def join(name, objs):
    objs = [o for o in objs if o is not None]
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = name
    o.data.name = name
    return o


def set_material(o, material):
    o.data.materials.clear()
    o.data.materials.append(material)
    return o


def clean_slots(o, default):
    """Faces inherited from material-less cutters fall back to `default`."""
    names = [m.name if m else None for m in o.data.materials]
    if default.name not in names:
        o.data.materials.append(default)
        names.append(default.name)
    d = names.index(default.name)
    for p in o.data.polygons:
        if p.material_index >= len(names) or names[p.material_index] is None:
            p.material_index = d
    return o


def assign_faces(o, material, test):
    """Give faces whose Godot-space centre passes test(x, y, z) a second material."""
    if material.name not in [m.name for m in o.data.materials if m]:
        o.data.materials.append(material)
    idx = [m.name if m else None for m in o.data.materials].index(material.name)
    mw = o.matrix_world
    for p in o.data.polygons:
        c = mw @ p.center
        if test(c.x, c.z, -c.y):
            p.material_index = idx


def text(name, body, center, size, material, side=1, depth=0.00004, rotate=0.0, align='CENTER', font_path=None):
    """Flat engraved-looking text on a side face; side=+1 left (+Z), -1 right."""
    bpy.ops.object.text_add()
    o = bpy.context.object
    o.data.body = body
    o.data.size = size
    o.data.extrude = depth
    o.data.align_x = align
    o.data.align_y = 'CENTER'
    if font_path:
        o.data.font = bpy.data.fonts.load(font_path, check_existing=True)
    # Text is authored in Blender XY; stand it on the side and read muzzle-left
    # on the left side, muzzle-right on the right side, as real markings do.
    if side > 0:
        o.rotation_euler = (math.pi / 2, rotate, 0)
    else:
        o.rotation_euler = (math.pi / 2, -rotate, math.pi)
    o.location = cv(center)
    bpy.ops.object.convert(target='MESH')
    o = bpy.context.object
    o.name = name
    apply(o)
    o.data.materials.clear()
    o.data.materials.append(material)
    return o


def text_top(name, body, center, size, material, depth=0.00004):
    bpy.ops.object.text_add()
    o = bpy.context.object
    o.data.body = body
    o.data.size = size
    o.data.extrude = depth
    o.data.align_x = 'CENTER'
    o.data.align_y = 'CENTER'
    o.rotation_euler = (0, 0, -math.pi / 2)
    o.location = cv(center)
    bpy.ops.object.convert(target='MESH')
    o = bpy.context.object
    o.name = name
    apply(o)
    o.data.materials.clear()
    o.data.materials.append(material)
    return o


def parent(child, parent_obj):
    child.parent = parent_obj
    child.matrix_parent_inverse = parent_obj.matrix_world.inverted()


def empty(name, at=(0, 0, 0)):
    o = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(o)
    o.location = cv(at)
    return o


def export(path, objects):
    for o in objects:
        for c in [o] + list(o.children_recursive):
            if c.type == 'MESH':
                first = next((m for m in c.data.materials if m), None)
                if first is not None:
                    clean_slots(c, first)
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:
        o.select_set(True)
        for c in o.children_recursive:
            c.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=True, export_yup=True,
                              export_apply=True, export_materials='EXPORT', export_cameras=False, export_lights=False,
                              export_normals=True, export_tangents=False)


def stats(objs):
    total = 0
    for o in objs:
        for c in [o] + list(o.children_recursive):
            if c.type == 'MESH':
                total += len(c.data.vertices)
    return total
