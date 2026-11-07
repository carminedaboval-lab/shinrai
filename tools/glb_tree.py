"""Print a GLB's node tree, mesh vertex counts and materials. python tools/glb_tree.py file.glb"""
import json, struct, sys


def load(path):
    data = open(path, "rb").read()
    length = struct.unpack_from("<I", data, 12)[0]
    return json.loads(data[20:20 + length])


def main(path):
    g = load(path)
    nodes, meshes, acc = g.get("nodes", []), g.get("meshes", []), g.get("accessors", [])
    mats = g.get("materials", [])
    child = {c for n in nodes for c in n.get("children", [])}
    total = 0

    def verts(mi):
        return sum(acc[p["attributes"]["POSITION"]]["count"] for p in meshes[mi]["primitives"])

    def walk(i, depth):
        nonlocal total
        n = nodes[i]
        extra = ""
        if "mesh" in n:
            v = verts(n["mesh"])
            total += v
            m = sorted({mats[p["material"]]["name"] for p in meshes[n["mesh"]]["primitives"] if "material" in p})
            extra = f"  v={v} mats={m}"
        t = n.get("translation")
        print("  " * depth + n.get("name", "?") + (f" t={[round(x, 4) for x in t]}" if t else "") + extra)
        for c in n.get("children", []):
            walk(c, depth + 1)

    for i in range(len(nodes)):
        if i not in child:
            walk(i, 0)
    print("TOTAL VERTS", total, "materials", len(mats), "images", len(g.get("images", [])))


main(sys.argv[1])
