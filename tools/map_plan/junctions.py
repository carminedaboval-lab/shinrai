"""The junctions of Map 1: where the plan's roads meet, and how each meeting is run.

Japan drives on the left, so the turn that crosses oncoming traffic is the right turn, and
that is the one that needs its own lane on a busy road. The rules used here:

*  two main roads (avenue, ring, highway, ramp)      signals, right-turn lanes on roads 18 m or wider
*  a main road and a town street                     signals, a right-turn lane on a main road 20 m or wider
*  two town streets, both 12 m or wider              signals
*  two town streets, one narrower                    stop line on the narrower one
*  an old lane or a country road joining anything    stop line on the lane
*  the busiest crossings beside a tram station       all-way pedestrian crossing (a "scramble")

Every corner is cut back (the corner cut Japanese building law asks for), more on wider roads,
so lorries can turn and drivers can see round the corner.
"""
import math

MAJOR = {"arterial", "ring", "highway", "ramp"}
TOWN = {"grid", "collector"}
MINOR = {"old", "country"}
USED = MAJOR | TOWN | MINOR
CROSSING = (150, 150, 148)


def _cross(a, b, c, d):
    """Where segment a-b crosses c-d, or None."""
    r = (b[0] - a[0], b[1] - a[1])
    s = (d[0] - c[0], d[1] - c[1])
    den = r[0] * s[1] - r[1] * s[0]
    if abs(den) < 1e-9:
        return None
    t = ((c[0] - a[0]) * s[1] - (c[1] - a[1]) * s[0]) / den
    u = ((c[0] - a[0]) * r[1] - (c[1] - a[1]) * r[0]) / den
    if 0.0 <= t <= 1.0 and 0.0 <= u <= 1.0:
        return (a[0] + r[0] * t, a[1] + r[1] * t)
    return None


def _nearest(point, line):
    """(distance, closest point, unit direction) from a point to a polyline."""
    best = (1e9, None, None)
    for a, b in zip(line, line[1:]):
        dx, dz = b[0] - a[0], b[1] - a[1]
        length2 = dx * dx + dz * dz
        if length2 < 1e-9:
            continue
        t = max(0.0, min(1.0, ((point[0] - a[0]) * dx + (point[1] - a[1]) * dz) / length2))
        q = (a[0] + dx * t, a[1] + dz * t)
        dist = math.hypot(point[0] - q[0], point[1] - q[1])
        if dist < best[0]:
            length = math.sqrt(length2)
            best = (dist, q, (dx / length, dz / length))
    return best


def find(plan):
    roads = [r for r in plan["roads"] if r.get("class") in USED]
    meets = []     # (x, z, road index a, road index b)
    for i, a in enumerate(roads):
        for j in range(i + 1, len(roads)):
            b = roads[j]
            for p, q in zip(a["points"], a["points"][1:]):
                for r, s in zip(b["points"], b["points"][1:]):
                    hit = _cross(p, q, r, s)
                    if hit:
                        meets.append((hit[0], hit[1], i, j))
            for end_of, other, ei, oi in ((a, b, i, j), (b, a, j, i)):
                for end in (end_of["points"][0], end_of["points"][-1]):
                    dist, q, _ = _nearest(end, other["points"])
                    if dist < other["width"] / 2 + 4.0:
                        meets.append((q[0], q[1], ei, oi))
    clusters = []
    for x, z, i, j in meets:
        for c in clusters:
            if math.hypot(c["x"] - x, c["z"] - z) < 16.0:
                c["roads"].update((i, j))
                c["n"] += 1
                c["x"] += (x - c["x"]) / c["n"]
                c["z"] += (z - c["z"]) / c["n"]
                break
        else:
            clusters.append({"x": x, "z": z, "roads": {i, j}, "n": 1})
    stations = plan["stations"][:9]
    out = []
    for c in clusters:
        arms = []
        for i in sorted(c["roads"]):
            road = roads[i]
            dist, q, direction = _nearest((c["x"], c["z"]), road["points"])
            at_end = min(math.hypot(c["x"] - e[0], c["z"] - e[1]) for e in (road["points"][0], road["points"][-1])) < 9.0
            arms.append({"name": road["name"], "cls": road["class"], "w": float(road["width"]), "dir": direction, "through": not at_end})
        if sum(2 if a["through"] else 1 for a in arms) < 3:
            continue       # one road carrying on under another name
        # Two stretches of the same line (the ring's pieces) count as one road.
        kinds = {a["cls"] for a in arms}
        majors = [a for a in arms if a["cls"] in MAJOR]
        minors = [a for a in arms if a["cls"] in MINOR]
        town = [a for a in arms if a["cls"] in TOWN]
        turn = []
        if minors and len(minors) < len(arms):
            control = "stop"
        elif minors:
            control = "give way"
        elif len(majors) >= 2:
            control = "signals"
            turn = [a["name"] for a in majors if a["w"] >= 18]
        elif majors:
            control = "signals"
            turn = [a["name"] for a in majors if a["w"] >= 20]
        else:
            control = "signals" if min(a["w"] for a in town) >= 12 else "stop"
        out.append({"x": round(c["x"], 1), "z": round(c["z"], 1), "control": control, "turn_lanes": turn,
                    "roads": [a["name"] for a in arms], "_arms": arms, "_kinds": kinds})
    # The scrambles: the signalled crossing nearest each of the three busiest stations.
    for sid in ("S1", "S8", "S9"):
        station = next(s for s in stations if s["id"] == sid)
        lit = [j for j in out if j["control"] == "signals" and all(a["w"] >= 10 for a in j["_arms"])]
        if lit:
            best = min(lit, key=lambda j: math.hypot(j["x"] - station["x"], j["z"] - station["z"]))
            if math.hypot(best["x"] - station["x"], best["z"] - station["z"]) < 90:
                best["control"] = "scramble"
    return out


def _shape(junction):
    """The paved shape of a junction: the crossing of its two widest roads, corners cut."""
    arms = sorted(junction["_arms"], key=lambda a: -a["w"])
    first = arms[0]
    second = next((a for a in arms[1:] if abs(a["dir"][0] * first["dir"][0] + a["dir"][1] * first["dir"][1]) < 0.85), None)
    if second is None:
        return None
    d1, d2 = first["dir"], second["dir"]
    a, b = first["w"] / 2, second["w"] / 2
    cut = 6.0 if min(first["w"], second["w"]) >= 16 else 4.0 if min(first["w"], second["w"]) >= 10 else 2.5
    x, z = junction["x"], junction["z"]
    local = [(b + cut, a), (b, a + cut), (-b, a + cut), (-b - cut, a), (-b - cut, -a), (-b, -a - cut), (b, -a - cut), (b + cut, -a)]
    # d1 runs along the first road; the second road's width is measured along d1, and so on.
    n1 = (-d1[1], d1[0])
    return [(x + d1[0] * u + n1[0] * v, z + d1[1] * u + n1[1] * v) for u, v in local], first, second


def paint(m, junctions, mark):
    """Paints the junctions into the ground. mark=True also keeps buildings off them."""
    roads = {r["name"]: r for r in m.PLAN["roads"]}
    for j in junctions:
        made = _shape(j)
        if made is None:
            continue
        poly, first, second = made
        colour = m.ASPHALT if first["cls"] in MAJOR else m.STREET
        # A right-turn lane: the road is a lane wider for 45 m before the stop line.
        for name in j["turn_lanes"]:
            road = roads[name]
            dist, q, direction = _nearest((j["x"], j["z"]), road["points"])
            reach = second["w"] / 2 + 6
            for sign in (1, -1):
                a = (q[0] + direction[0] * sign * reach, q[1] + direction[1] * sign * reach)
                b = (q[0] + direction[0] * sign * (reach + 45), q[1] + direction[1] * sign * (reach + 45))
                if _nearest(b, road["points"])[0] > 3.0:
                    continue        # the road ends or bends away before then
                m.gd.line(m.pts([a, b]), fill=m.ASPHALT, width=round(road["width"]) + 3)
                if mark:
                    m.od.line(m.pts([a, b]), fill=255, width=round(road["width"]) + 5)
        m.gd.polygon(m.pts(poly), fill=CROSSING if j["control"] == "scramble" else colour)
        if mark:
            m.od.polygon(m.pts(poly), fill=255)


def furnish(m, junctions):
    """Signal posts at the corners of every signalled junction, for the walkable blockout."""
    for j in junctions:
        if j["control"] not in ("signals", "scramble"):
            continue
        made = _shape(j)
        if made is None:
            continue
        poly = made[0]
        for k in (0, 2, 4, 6):
            ax, az = poly[k]
            bx, bz = poly[k + 1]
            cx, cz = (ax + bx) / 2, (az + bz) / 2
            out = math.hypot(cx - j["x"], cz - j["z"]) or 1.0
            m.add_box(cx + (cx - j["x"]) / out * 1.4, cz + (cz - j["z"]) / out * 1.4, 0.3, 0.3, 6.2, kind="signal", force=True, stamp=False)


def export(junctions):
    return [{k: v for k, v in j.items() if not k.startswith("_")} for j in junctions]
