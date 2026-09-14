#!/usr/bin/env python3
"""Build the full-depth SHINRAI Yakitori shop artwork replica as one GLB."""

from __future__ import annotations

import io
import json
import math
import struct
from pathlib import Path

import numpy as np
from PIL import Image


HERE = Path(__file__).resolve().parent
OUT_DIR = HERE.parent
V2_DIR = OUT_DIR.parent
V2_GLB = V2_DIR / "ProjectShinrai_YakitoriShop_BuildingShell_v2.glb"
OUT_GLB = OUT_DIR / "ProjectShinrai_YakitoriShop_ArtworkReplica_v3.glb"
TEX_DIR = OUT_DIR / "textures"
PREFIX = "ProjectShinrai_YakitoriShop_BuildingShell_v2_Yakitori_"

FILES = {
    "wood_base": V2_DIR / f"{PREFIX}DarkCedar_BaseColor.png",
    "wood_normal": V2_DIR / f"{PREFIX}DarkCedar_NormalGL.png",
    "wood_orm": V2_DIR / f"{PREFIX}DarkCedar_ORM.png",
    "plaster_base": V2_DIR / f"{PREFIX}AgedPlaster_BaseColor.png",
    "plaster_normal": V2_DIR / f"{PREFIX}AgedPlaster_NormalGL.png",
    "plaster_orm": V2_DIR / f"{PREFIX}AgedPlaster_ORM.png",
    "stone_base": V2_DIR / f"{PREFIX}ThresholdConcrete_BaseColor.png",
    "stone_normal": V2_DIR / f"{PREFIX}ThresholdConcrete_NormalGL.png",
    "stone_orm": V2_DIR / f"{PREFIX}ThresholdConcrete_ORM.png",
    "roof_base": V2_DIR / f"{PREFIX}DarkRoof_BaseColor.png",
    "roof_normal": V2_DIR / f"{PREFIX}DarkRoof_NormalGL.png",
    "roof_orm": V2_DIR / f"{PREFIX}DarkRoof_ORM.png",
}

DTYPE = {5121: np.uint8, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
WIDTH = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


class MeshData:
    def __init__(self) -> None:
        self.p: list[np.ndarray] = []
        self.n: list[np.ndarray] = []
        self.uv: list[np.ndarray] = []
        self.i: list[np.ndarray] = []
        self.count = 0

    def add(self, p, n, uv, i) -> None:
        p = np.asarray(p, np.float32).reshape(-1, 3)
        n = np.asarray(n, np.float32).reshape(-1, 3)
        uv = np.asarray(uv, np.float32).reshape(-1, 2)
        i = np.asarray(i, np.uint32).reshape(-1) + self.count
        self.p.append(p); self.n.append(n); self.uv.append(uv); self.i.append(i)
        self.count += len(p)

    def arrays(self):
        if not self.p:
            return (np.empty((0, 3), np.float32), np.empty((0, 3), np.float32),
                    np.empty((0, 2), np.float32), np.empty(0, np.uint32))
        return tuple(np.concatenate(x) for x in (self.p, self.n, self.uv, self.i))


class Binary:
    def __init__(self) -> None:
        self.data = bytearray(); self.views: list[dict] = []; self.accessors: list[dict] = []

    def add_bytes(self, payload: bytes, target=None) -> int:
        while len(self.data) % 4: self.data.append(0)
        view = {"buffer": 0, "byteOffset": len(self.data), "byteLength": len(payload)}
        if target is not None: view["target"] = target
        self.data.extend(payload); self.views.append(view)
        return len(self.views) - 1

    def accessor(self, array, component: int, kind: str, target: int, bounds=False) -> int:
        a = np.ascontiguousarray(array, dtype=np.dtype(DTYPE[component]).newbyteorder("<"))
        view = self.add_bytes(a.tobytes(), target)
        item = {"bufferView": view, "componentType": component, "count": len(a), "type": kind}
        if bounds and len(a):
            shaped = a.reshape(len(a), WIDTH[kind])
            item["min"] = shaped.min(0).astype(float).tolist()
            item["max"] = shaped.max(0).astype(float).tolist()
        self.accessors.append(item)
        return len(self.accessors) - 1


def load_glb(path: Path):
    with path.open("rb") as f:
        magic, version, _ = struct.unpack("<4sII", f.read(12))
        assert magic == b"glTF" and version == 2
        jl, jt = struct.unpack("<I4s", f.read(8)); assert jt == b"JSON"
        doc = json.loads(f.read(jl))
        bl, bt = struct.unpack("<I4s", f.read(8)); assert bt == b"BIN\0"
        return doc, f.read(bl)


def get_accessor(doc, blob, index):
    a = doc["accessors"][index]; v = doc["bufferViews"][a["bufferView"]]
    dtype = np.dtype(DTYPE[a["componentType"]]).newbyteorder("<"); width = WIDTH[a["type"]]
    offset = v.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = v.get("byteStride", dtype.itemsize * width)
    if stride == dtype.itemsize * width:
        return np.frombuffer(blob, dtype, a["count"] * width, offset).reshape(-1, width).copy()
    return np.ndarray((a["count"], width), dtype, blob, offset,
                      strides=(stride, dtype.itemsize)).copy()


def components(p, index):
    tri = index.reshape(-1, 3); parent = np.arange(len(tri)); size = np.ones(len(tri), int)
    def root(x):
        while parent[x] != x: parent[x] = parent[parent[x]]; x = int(parent[x])
        return x
    def union(a, b):
        a, b = root(a), root(b)
        if a == b: return
        if size[a] < size[b]: a, b = b, a
        parent[b] = a; size[a] += size[b]
    seen = {}
    for ti, t in enumerate(tri):
        for vi in t:
            key = tuple(np.rint(p[vi] * 100000).astype(np.int64))
            if key in seen: union(ti, seen[key])
            else: seen[key] = ti
    found = {}
    for ti in range(len(tri)): found.setdefault(root(ti), []).append(ti)
    return tri, [np.asarray(v, np.int32) for v in found.values()]


def append_component(dst, p, n, uv, triangles):
    used = np.unique(triangles.reshape(-1)); remap = np.full(len(p), -1, np.int64)
    remap[used] = np.arange(len(used))
    dst.add(p[used], n[used], uv[used], remap[triangles].reshape(-1))


def rot_xyz(r):
    x, y, z = r; cx, sx = math.cos(x), math.sin(x); cy, sy = math.cos(y), math.sin(y); cz, sz = math.cos(z), math.sin(z)
    rx = np.array([[1,0,0],[0,cx,-sx],[0,sx,cx]], float)
    ry = np.array([[cy,0,sy],[0,1,0],[-sy,0,cy]], float)
    rz = np.array([[cz,-sz,0],[sz,cz,0],[0,0,1]], float)
    return rz @ ry @ rx


def add_poly(v, n, uv, idx, points, normal, tile):
    points = np.asarray(points, float); normal = np.asarray(normal, float); normal /= np.linalg.norm(normal)
    if np.dot(np.cross(points[1]-points[0], points[2]-points[0]), normal) < 0: points = points[::-1]
    base = len(v); axis = int(np.argmax(np.abs(normal)))
    for p in points:
        v.append(p.tolist()); n.append(normal.tolist())
        uv.append(([p[2]/tile, p[1]/tile] if axis == 0 else
                   [p[0]/tile, p[2]/tile] if axis == 1 else [p[0]/tile, p[1]/tile]))
    for k in range(1, len(points)-1): idx.extend([base, base+k, base+k+1])


def box_geom(center, size, bevel=0.0, rotation=(0,0,0), tile=0.72):
    h = np.asarray(size, float)/2; bevel = max(0.0, min(bevel, float(h.min())-0.0001)); q = h-bevel
    hx,hy,hz=h; ix,iy,iz=q; v=[]; n=[]; uv=[]; idx=[]
    faces = [
        ([[hx,-iy,-iz],[hx,iy,-iz],[hx,iy,iz],[hx,-iy,iz]],[1,0,0]),
        ([[-hx,-iy,iz],[-hx,iy,iz],[-hx,iy,-iz],[-hx,-iy,-iz]],[-1,0,0]),
        ([[-ix,hy,-iz],[-ix,hy,iz],[ix,hy,iz],[ix,hy,-iz]],[0,1,0]),
        ([[-ix,-hy,iz],[-ix,-hy,-iz],[ix,-hy,-iz],[ix,-hy,iz]],[0,-1,0]),
        ([[ix,-iy,hz],[ix,iy,hz],[-ix,iy,hz],[-ix,-iy,hz]],[0,0,1]),
        ([[-ix,-iy,-hz],[-ix,iy,-hz],[ix,iy,-hz],[ix,-iy,-hz]],[0,0,-1]),
    ]
    for p, normal in faces: add_poly(v,n,uv,idx,p,normal,tile)
    for sy in (-1.,1.):
        for sz in (-1.,1.): add_poly(v,n,uv,idx,[[-ix,sy*hy,sz*iz],[ix,sy*hy,sz*iz],[ix,sy*iy,sz*hz],[-ix,sy*iy,sz*hz]],[0,sy,sz],tile)
    for sx in (-1.,1.):
        for sz in (-1.,1.): add_poly(v,n,uv,idx,[[sx*hx,-iy,sz*iz],[sx*hx,iy,sz*iz],[sx*ix,iy,sz*hz],[sx*ix,-iy,sz*hz]],[sx,0,sz],tile)
    for sx in (-1.,1.):
        for sy in (-1.,1.): add_poly(v,n,uv,idx,[[sx*hx,sy*iy,-iz],[sx*hx,sy*iy,iz],[sx*ix,sy*hy,iz],[sx*ix,sy*hy,-iz]],[sx,sy,0],tile)
    for sx in (-1.,1.):
        for sy in (-1.,1.):
            for sz in (-1.,1.): add_poly(v,n,uv,idx,[[sx*hx,sy*iy,sz*iz],[sx*ix,sy*hy,sz*iz],[sx*ix,sy*iy,sz*hz]],[sx,sy,sz],tile)
    p=np.asarray(v,float); normals=np.asarray(n,float); r=rot_xyz(rotation)
    p=p@r.T+np.asarray(center); normals=normals@r.T
    return p.astype(np.float32),normals.astype(np.float32),np.asarray(uv,np.float32),np.asarray(idx,np.uint32)


def cylinder_geom(center, radius, height, segments=12, rotation=(0,0,0)):
    v=[];n=[];uv=[];idx=[]; hh=height/2
    for s in range(segments):
        a0=math.tau*s/segments;a1=math.tau*(s+1)/segments;b=len(v)
        v += [[radius*math.cos(a0),-hh,radius*math.sin(a0)],[radius*math.cos(a1),-hh,radius*math.sin(a1)],[radius*math.cos(a1),hh,radius*math.sin(a1)],[radius*math.cos(a0),hh,radius*math.sin(a0)]]
        n += [[math.cos(a0),0,math.sin(a0)],[math.cos(a1),0,math.sin(a1)],[math.cos(a1),0,math.sin(a1)],[math.cos(a0),0,math.sin(a0)]]
        uv += [[s/segments,0],[(s+1)/segments,0],[(s+1)/segments,1],[s/segments,1]];idx += [b,b+1,b+2,b,b+2,b+3]
    for sign in (-1.,1.):
        c=len(v);v.append([0,sign*hh,0]);n.append([0,sign,0]);uv.append([.5,.5]);ring=len(v)
        for s in range(segments):
            a=math.tau*s/segments;v.append([radius*math.cos(a),sign*hh,radius*math.sin(a)]);n.append([0,sign,0]);uv.append([.5+.5*math.cos(a),.5+.5*math.sin(a)])
        for s in range(segments):
            a=ring+s;b=ring+(s+1)%segments;idx += [c,b,a] if sign>0 else [c,a,b]
    p=np.asarray(v,float);norm=np.asarray(n,float);r=rot_xyz(rotation);p=p@r.T+np.asarray(center);norm=norm@r.T
    return p.astype(np.float32),norm.astype(np.float32),np.asarray(uv,np.float32),np.asarray(idx,np.uint32)


def tangents(p,n,uv,index):
    ts=np.zeros_like(p,float);bs=np.zeros_like(p,float)
    for a,b,c in index.reshape(-1,3):
        e1=p[b]-p[a];e2=p[c]-p[a];d1=uv[b]-uv[a];d2=uv[c]-uv[a];den=float(d1[0]*d2[1]-d1[1]*d2[0])
        if abs(den)<1e-10: continue
        t=(e1*d2[1]-e2*d1[1])/den;bt=(e2*d1[0]-e1*d2[0])/den
        for x in (a,b,c):ts[x]+=t;bs[x]+=bt
    out=np.zeros((len(p),4),np.float32)
    for k in range(len(p)):
        nn=n[k].astype(float);t=ts[k]-nn*np.dot(nn,ts[k]);length=np.linalg.norm(t)
        if length<1e-10:t=np.cross([0,1,0] if abs(nn[1])<.9 else [1,0,0],nn);length=np.linalg.norm(t)
        t/=max(length,1e-10);out[k,:3]=t;out[k,3]=-1 if np.dot(np.cross(nn,t),bs[k])<0 else 1
    return out


def variant(source, target, output):
    arr=np.asarray(Image.open(source).convert("RGB"),float);target=np.asarray(target,float);out=arr.copy()
    for _ in range(8):out=np.clip(out*(target/np.maximum(out.mean((0,1)),1)),0,255)
    image=Image.fromarray(np.rint(out).astype(np.uint8),"RGB");buf=io.BytesIO();image.save(buf,"PNG",optimize=True);payload=buf.getvalue();output.write_bytes(payload);return payload


def build():
    for path in [V2_GLB,*FILES.values()]:
        if not path.exists(): raise FileNotFoundError(path)
    TEX_DIR.mkdir(parents=True,exist_ok=True)
    keys=("plaster","stone","exterior_wood","canopy_wood","upper_wood","frame_wood","glass","interior","roof","metal","lens","collision")
    g={k:MeshData() for k in keys};doc,blob=load_glb(V2_GLB)

    def retain(mesh, classify):
        prim=doc["meshes"][mesh]["primitives"][0];p=get_accessor(doc,blob,prim["attributes"]["POSITION"]);n=get_accessor(doc,blob,prim["attributes"]["NORMAL"]);uv=get_accessor(doc,blob,prim["attributes"]["TEXCOORD_0"]);index=get_accessor(doc,blob,prim["indices"]).reshape(-1);tri,parts=components(p,index)
        for part in parts:
            t=tri[part];points=p[t.reshape(-1)];target=classify(points.min(0),points.max(0))
            if target:append_component(g[target],p,n,uv,t)
    def cedar(lo,hi):
        if lo[1]>=2.665:return None
        if lo[1]>=2.40:return "canopy_wood"
        return "exterior_wood" if hi[1]<=.60 and (hi-lo)[0]>.20 else "frame_wood"
    retain(2,cedar);retain(3,lambda lo,hi:"glass");retain(5,lambda lo,hi:"roof" if lo[1]<3 else None)
    retain(6,lambda lo,hi:None if np.all(lo>=(-.55,.55,-1.05)) and np.all(hi<=(.55,2.10,-.50)) else "metal")

    def box(k,c,s,b=0,r=(0,0,0),tile=.72):g[k].add(*box_geom(c,s,b,r,tile))
    def cyl(k,c,rad,h,seg=12,r=(0,0,0)):g[k].add(*cylinder_geom(c,rad,h,seg,r))
    front=-.60;rear=3.76;depth=rear-front;zc=(front+rear)/2
    # Concrete shell and seams.
    box("plaster",(-2.01,2.88,zc),(.18,5.44,depth),.012,tile=1);box("plaster",(2.01,2.88,zc),(.18,5.44,depth),.012,tile=1);box("plaster",(0,2.88,rear-.09),(4.2,5.44,.18),.012,tile=1)
    for x in (-1.985,1.985):box("plaster",(x,1.47,-.615),(.23,2.58,.19),.012,tile=1);box("plaster",(x,4.34,-.615),(.23,2.62,.19),.012,tile=1)
    for x in (-2.107,2.107):
        for z in (.48,1.70,2.92):box("metal",(x,2.92,z),(.01,5.05,.012))
    for x in (-.72,.62):box("metal",(x,2.90,3.858),(.012,5.02,.01))
    for x in (-2.115,2.115):box("exterior_wood",(x,2.91,1.57),(.10,.16,4.35),.012)
    box("exterior_wood",(0,2.91,3.865),(4.28,.16,.10),.012)
    # Stone plinth.
    box("stone",(0,.13,-.67),(4.40,.26,.26),.025,tile=.78);box("stone",(0,.12,-.92),(4.56,.14,.48),.018,tile=.78)
    for x in (-2.13,2.13):box("stone",(x,.13,1.55),(.24,.26,4.56),.018,tile=.78);box("stone",(x,.285,1.55),(.28,.05,4.60),.01,tile=.78)
    box("stone",(0,.13,3.80),(4.52,.26,.24),.018,tile=.78);box("stone",(0,.285,3.80),(4.56,.05,.28),.01,tile=.78)
    # Upper glazed façade and timber screen.
    bot=3.24;top=5.40;cy=(bot+top)/2;hh=top-bot;box("interior",(0,cy,-.42),(3.66,hh,.055))
    for x,w in ((-1.27,1.02),(-.07,1.24),(1.20,1.14)):box("glass",(x,cy,-.625),(w,hh-.14,.022))
    box("upper_wood",(0,3.13,-.70),(3.84,.17,.18),.018);box("upper_wood",(0,5.49,-.70),(3.84,.18,.18),.018)
    for x,w in ((-1.84,.17),(-.72,.12),(.58,.12),(1.84,.17)):box("frame_wood",(x,cy,-.715),(w,hh+.26,.16),.012)
    box("upper_wood",(1.20,bot+.04,-.805),(1.18,.09,.07),.01);box("upper_wood",(1.20,top-.04,-.805),(1.18,.09,.07),.01)
    for x in np.linspace(.70,1.70,9):box("frame_wood",(float(x),cy,-.805),(.05,hh-.10,.065),.008)
    # Dark placeholder shell only; final interior remains deferred.
    box("interior",(0,1.43,.34),(3.72,2.45,.055));box("interior",(0,.22,1.52),(3.72,.055,4.20));box("interior",(0,2.62,1.52),(3.72,.055,4.20))
    # Compact paired door pulls.
    for x in (-.18,.18):
        cyl("metal",(x,1.28,-.850),.018,.240,14)
        for y in (1.18,1.38):cyl("metal",(x,y,-.795),.014,.08,12,(math.pi/2,0,0));cyl("metal",(x,y,-.752),.03,.018,12,(math.pi/2,0,0))
    # Layered upper eave, true low-slope roof and flashing.
    pitch=math.radians(-3.5);box("canopy_wood",(0,5.60,-.82),(4.42,.14,.46),.018,(pitch,0,0));box("roof",(0,5.73,1.58),(4.44,.16,4.62),.015,(pitch,0,0),.86);box("metal",(0,5.70,-1.055),(4.54,.13,.07),.008);box("metal",(0,5.78,-1.035),(4.60,.045,.15),.006)
    for x in (-2.245,2.245):box("metal",(x,5.75,1.57),(.055,.09,4.60),.006,(pitch,0,0))
    box("metal",(0,5.89,3.86),(4.54,.09,.065),.006)
    # Canopy detail, three lenses, and end brackets.
    for x in np.linspace(-1.75,1.75,7):box("canopy_wood",(float(x),2.535,-1.03),(.06,.055,.68),.008)
    for x in (-1.32,0,1.32):cyl("lens",(x,2.515,-1.16),.085,.022,18)
    for x in (-1.93,1.93):box("canopy_wood",(x,2.39,-.91),(.095,.48,.10),.01,(math.radians(-36),0,0))
    # Rear window.
    wx=.86;wy=4.22;box("metal",(wx,wy,3.862),(.76,1.02,.03),.008);box("glass",(wx,wy,3.884),(.54,.78,.022))
    for x in (wx-.33,wx+.33):box("frame_wood",(x,wy,3.905),(.07,.96,.075),.01)
    box("frame_wood",(wx,wy+.445,3.905),(.72,.07,.075),.01);box("frame_wood",(wx,wy-.445,3.925),(.78,.08,.14),.01)
    # Asymmetric rear piers and inset two-rail guard.
    for x,h in ((-1.91,.74),(1.91,.58)):
        py=5.60+h/2;box("plaster",(x,py,3.48),(.25,h,.38),.012,tile=1);box("metal",(x,py+h/2+.025,3.48),(.29,.05,.42),.006)
    rx=1.74;rz=3.30;fz=-.10
    for x in (-rx,rx):
        for z in np.linspace(fz,rz,4):box("metal",(x,6.05,float(z)),(.05,.54,.05),.004)
        for y in (5.96,6.30):box("metal",(x,y,(fz+rz)/2),(.05,.05,rz-fz),.004)
    for x in np.linspace(-rx,rx,5):box("metal",(float(x),6.05,rz),(.05,.54,.05),.004)
    for y in (5.96,6.30):box("metal",(0,y,rz),(rx*2,.05,.05),.004)
    cyl("metal",(-2.135,2.80,3.43),.03,5.05,12);cyl("metal",(-2.135,5.34,3.30),.03,.30,12,(math.pi/2,0,0))
    # Collision leaves the future interactive-door opening clear.
    box("collision",(-2.01,2.88,zc),(.22,5.44,depth));box("collision",(2.01,2.88,zc),(.22,5.44,depth));box("collision",(0,2.88,rear-.09),(4.2,5.44,.22));box("collision",(-1.24,1.43,-.66),(1.30,2.46,.12));box("collision",(1.24,1.43,-.66),(1.30,2.46,.12));box("collision",(0,cy,-.66),(3.70,2.30,.12));box("collision",(0,5.73,1.58),(4.44,.20,4.62),r=(pitch,0,0))

    # Embedded texture payloads and exact artwork swatches.
    payloads=[("ExteriorWood_BaseColor",FILES["wood_base"].read_bytes()),
      ("CanopyEaveWood_BaseColor",variant(FILES["wood_base"],(0x5B,0x38,0x24),TEX_DIR/"Yakitori_CanopyEaveWood_BaseColor.png")),
      ("UpperWoodCladding_BaseColor",variant(FILES["wood_base"],(0x36,0x2A,0x20),TEX_DIR/"Yakitori_UpperWoodCladding_BaseColor.png")),
      ("WoodFrame_BaseColor",variant(FILES["wood_base"],(0x35,0x24,0x1B),TEX_DIR/"Yakitori_WoodFrame_BaseColor.png")),
      ("Wood_NormalGL",FILES["wood_normal"].read_bytes()),("Wood_ORM",FILES["wood_orm"].read_bytes()),
      ("Plaster_BaseColor",FILES["plaster_base"].read_bytes()),("Plaster_NormalGL",FILES["plaster_normal"].read_bytes()),("Plaster_ORM",FILES["plaster_orm"].read_bytes()),
      ("Stone_BaseColor",FILES["stone_base"].read_bytes()),("Stone_NormalGL",FILES["stone_normal"].read_bytes()),("Stone_ORM",FILES["stone_orm"].read_bytes()),
      ("Roof_BaseColor",FILES["roof_base"].read_bytes()),("Roof_NormalGL",FILES["roof_normal"].read_bytes()),("Roof_ORM",FILES["roof_orm"].read_bytes())]
    order=list(keys);names={"plaster":"SM_YakitoriShop_AgedPlasterShell","stone":"SM_YakitoriShop_StoneThreshold","exterior_wood":"SM_YakitoriShop_ExteriorWoodMain","canopy_wood":"SM_YakitoriShop_CanopyEaveWood","upper_wood":"SM_YakitoriShop_UpperWoodCladding","frame_wood":"SM_YakitoriShop_WoodFrames","glass":"SM_YakitoriShop_GlazingPlaceholder","interior":"SM_YakitoriShop_InteriorPlaceholder","roof":"SM_YakitoriShop_RoofEdgeFlashing","metal":"SM_YakitoriShop_ArchitecturalMetal","lens":"SM_YakitoriShop_CanopyLightLenses","collision":"PS_YakitoriShop_ArtworkReplica_Collision-colonly"}
    mkeys=order[:-1];mindex={k:i for i,k in enumerate(mkeys)};binary=Binary();meshes=[];nodes=[]
    for k in order:
        p,n,uv,index=g[k].arrays();pa=binary.accessor(p,5126,"VEC3",34962,True);na=binary.accessor(n,5126,"VEC3",34962);ua=binary.accessor(uv,5126,"VEC2",34962);ta=binary.accessor(tangents(p,n,uv,index),5126,"VEC4",34962);ia=binary.accessor(index.reshape(-1,1),5125,"SCALAR",34963)
        prim={"attributes":{"POSITION":pa,"NORMAL":na,"TEXCOORD_0":ua,"TANGENT":ta},"indices":ia,"mode":4}
        if k!="collision":prim["material"]=mindex[k]
        meshes.append({"name":names[k],"primitives":[prim]});nodes.append({"name":names[k],"mesh":len(meshes)-1})
    images=[];textures=[];lookup={}
    for name,payload in payloads:
        images.append({"name":name,"bufferView":binary.add_bytes(payload),"mimeType":"image/png"});textures.append({"name":name,"sampler":0,"source":len(images)-1});lookup[name]=len(textures)-1
    def mat(name,base,normal,orm,metal,rough,scale,spec):return {"name":name,"pbrMetallicRoughness":{"baseColorTexture":{"index":lookup[base]},"metallicRoughnessTexture":{"index":lookup[orm]},"metallicFactor":metal,"roughnessFactor":rough},"normalTexture":{"index":lookup[normal],"scale":scale},"occlusionTexture":{"index":lookup[orm]},"extensions":{"KHR_materials_specular":{"specularFactor":spec}}}
    materials=[mat("MAT_Yakitori_04_PlasterConcrete","Plaster_BaseColor","Plaster_NormalGL","Plaster_ORM",0,1,.34,.22),mat("MAT_Yakitori_05_StoneThreshold","Stone_BaseColor","Stone_NormalGL","Stone_ORM",0,1,.42,.22),mat("MAT_Yakitori_01_ExteriorWoodMain","ExteriorWood_BaseColor","Wood_NormalGL","Wood_ORM",0,1,.48,.30),mat("MAT_Yakitori_02_CanopyEaveWood","CanopyEaveWood_BaseColor","Wood_NormalGL","Wood_ORM",0,.86,.45,.32),mat("MAT_Yakitori_03_UpperWoodCladding","UpperWoodCladding_BaseColor","Wood_NormalGL","Wood_ORM",0,1,.44,.28),mat("MAT_Yakitori_07_WoodFrames","WoodFrame_BaseColor","Wood_NormalGL","Wood_ORM",0,.92,.42,.32),
      {"name":"MAT_Yakitori_06_Glass_PLACEHOLDER","pbrMetallicRoughness":{"baseColorFactor":[.902,.882,.839,.18],"metallicFactor":0,"roughnessFactor":.08},"alphaMode":"BLEND","doubleSided":True,"extensions":{"KHR_materials_ior":{"ior":1.48},"KHR_materials_transmission":{"transmissionFactor":.82},"KHR_materials_specular":{"specularFactor":.38}},"extras":{"PS_scope":"placeholder for later glazing pass"}},
      {"name":"MAT_Yakitori_Interior_PLACEHOLDER","pbrMetallicRoughness":{"baseColorFactor":[.03,.02,.014,1],"metallicFactor":0,"roughnessFactor":.92},"doubleSided":True,"extras":{"PS_scope":"shadow shell only; no interior props"}},
      mat("MAT_Yakitori_09_RoofEdgeFlashing","Roof_BaseColor","Roof_NormalGL","Roof_ORM",.55,1,.30,.42),
      {"name":"MAT_Yakitori_08_MetalTrimHandles","pbrMetallicRoughness":{"baseColorFactor":[.0103,.0103,.0103,1],"metallicFactor":.92,"roughnessFactor":.35},"extensions":{"KHR_materials_specular":{"specularFactor":.46}}},
      {"name":"MAT_Yakitori_CanopyLightLens","pbrMetallicRoughness":{"baseColorFactor":[1,.58,.28,1],"metallicFactor":0,"roughnessFactor":.22},"emissiveFactor":[1,.36,.12],"extensions":{"KHR_materials_emissive_strength":{"emissiveStrength":2.2}}}]
    sockets=[("SOCKET_Entrance",[0,0,-.72]),("SOCKET_CanopyLight_00",[-1.32,2.49,-1.16]),("SOCKET_CanopyLight_01",[0,2.49,-1.16]),("SOCKET_CanopyLight_02",[1.32,2.49,-1.16]),("SOCKET_Lantern_Right_LATER",[1.78,2.18,-1.34]),("SOCKET_VerticalSign_Right_LATER",[2.10,3.18,-.68]),("SOCKET_Noren_LATER",[0,2.34,-.74]),("SOCKET_InteriorOrigin_LATER",[0,.22,-.42]),("SOCKET_Roof",[0,5.90,1.58])]
    nodes += [{"name":name,"translation":pos} for name,pos in sockets];root=len(nodes);nodes.append({"name":"ProjectShinrai_YakitoriShop_ArtworkReplica_v3_ROOT","children":list(range(root)),"extras":{"PS_dimensions_m":[4.2,6.4,4.58],"PS_front_axis":"-Z","PS_building_only":True,"PS_excluded":["signage","lanterns","plants","props","AC units","finished interior"],"PS_placeholder_glass":True,"PS_game_ready":True}})
    scene_extras={"PS_scope":"building architecture only","PS_material_swatches":{"01_exterior_wood":"#2B1D16","02_canopy_eave_wood":"#5B3824","03_upper_wood_cladding":"#362A20","04_plaster_concrete":"#78766F","05_stone_threshold":"#6D6964","06_glass_placeholder":"#E6E1D6","07_wood_frames":"#35241B","08_metal_trim":"#1A1A1A","09_roof_flashing":"#232333"}}
    output={"asset":{"version":"2.0","generator":"Project SHINRAI Yakitori Artwork Replica Builder v3"},"extensionsUsed":["KHR_materials_emissive_strength","KHR_materials_ior","KHR_materials_specular","KHR_materials_transmission"],"scene":0,"scenes":[{"name":"YakitoriShop_ArtworkReplica","nodes":[root],"extras":scene_extras}],"nodes":nodes,"meshes":meshes,"materials":materials,"samplers":[{"magFilter":9729,"minFilter":9987,"wrapS":10497,"wrapT":10497}],"textures":textures,"images":images,"bufferViews":binary.views,"accessors":binary.accessors,"buffers":[{"byteLength":len(binary.data)}]}
    jp=json.dumps(output,separators=(",",":"),ensure_ascii=False).encode();jp+=b" "*((-len(jp))%4);bp=bytes(binary.data);bp+=b"\0"*((-len(bp))%4);total=12+8+len(jp)+8+len(bp);OUT_GLB.write_bytes(struct.pack("<4sII",b"glTF",2,total)+struct.pack("<I4s",len(jp),b"JSON")+jp+struct.pack("<I4s",len(bp),b"BIN\0")+bp)
    counts={k:len(g[k].arrays()[3])//3 for k in order};manifest={"asset":OUT_GLB.name,"version":"3.0","dimensions_m":[4.2,6.4,4.58],"front_axis":"-Z","scope":"building only","excluded":["signage","lanterns","plants","props","AC units","finished interior"],"placeholder_glass":True,"triangle_counts":counts,"total_triangles_including_collision":sum(counts.values()),"material_slots":[m["name"] for m in materials],"sockets":[s[0] for s in sockets]};(OUT_DIR/"asset_manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
    print(f"Wrote {OUT_GLB} ({OUT_GLB.stat().st_size/1024/1024:.2f} MiB); {sum(counts.values()):,} triangles")


if __name__ == "__main__": build()
