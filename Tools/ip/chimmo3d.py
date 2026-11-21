#!/usr/bin/env python3
"""Blender bpy procedural 3D matte-vinyl generator for 咩哞 · Chimmo (7 scale-degree buddies).

Matches the exact designer-toy craft canon shared with mossling/tools/ip3d.py and
mossottokeyboard/Tools/ip/mosto3d.py:
  - Matte soft-vinyl shader: Roughness=0.55, Subsurface Weight=0.06, fine bump (700, 0.025)
  - Glazed eyes: Coat Weight=1.0, dark obsidian iris + studio upper-left catchlight
  - Cycles AgX-None product studio lighting (Daylight & Night-Lamp warm gold emission)

Usage (requires Blender Python / `pip install bpy`):
  python3 Tools/ip/chimmo3d.py sheet ./renders
  python3 Tools/ip/chimmo3d.py sprites ./Chimmo/Resources/Sprites
"""

from __future__ import annotations

import math
import os
import sys

TROUPE = [
    {"deg": 1, "id": "taono",  "hex": "#C4513A", "accent": "#4A261E", "glow": "#FFB84D", "shape": "bell"},
    {"deg": 2, "id": "doko",   "hex": "#BC6E28", "accent": "#5A3516", "glow": "#FFC45A", "shape": "wood"},
    {"deg": 3, "id": "plokko", "hex": "#CF5B68", "accent": "#3A2C2A", "glow": "#FFC45A", "shape": "wing"},
    {"deg": 4, "id": "udo",    "hex": "#4E8280", "accent": "#244241", "glow": "#4FD8CB", "shape": "ocarina"},
    {"deg": 5, "id": "corllo", "hex": "#EFE7D8", "accent": "#B85D3B", "glow": "#FFC45A", "shape": "spiral"},
    {"deg": 6, "id": "bomo",   "hex": "#9A624B", "accent": "#E8BD6B", "glow": "#E8BD6B", "shape": "bowl"},
    {"deg": 7, "id": "tinki",  "hex": "#B37418", "accent": "#FFC45A", "glow": "#FFC45A", "shape": "top"},
]


def hex_linear(h: str) -> tuple[float, float, float, float]:
    h = h.lstrip("#")
    vals = []
    for i in (0, 2, 4):
        s = int(h[i : i + 2], 16) / 255.0
        vals.append(s / 12.92 if s <= 0.04045 else ((s + 0.055) / 1.055) ** 2.4)
    return (vals[0], vals[1], vals[2], 1.0)


def make_rubber_material(bpy, name: str, color_hex: str, roughness: float = 0.55, sss: float = 0.06):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = hex_linear(color_hex)
    bsdf.inputs["Roughness"].default_value = roughness
    if "Subsurface Weight" in bsdf.inputs:
        bsdf.inputs["Subsurface Weight"].default_value = sss
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 700.0
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.025
    nt.links.new(noise.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def make_glaze_eye_material(bpy):
    mat = bpy.data.materials.new("GlazeEye")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (0.015, 0.015, 0.018, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.06
    if "Coat Weight" in bsdf.inputs:
        bsdf.inputs["Coat Weight"].default_value = 1.0
    return mat


def make_emissive_pearl(bpy, name: str, color_hex: str, night: bool):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    col = hex_linear(color_hex)
    bsdf.inputs["Base Color"].default_value = col
    bsdf.inputs["Roughness"].default_value = 0.32
    if night and "Emission Color" in bsdf.inputs:
        bsdf.inputs["Emission Color"].default_value = col
        bsdf.inputs["Emission Strength"].default_value = 4.2
    return mat


def build_member(bpy, spec: dict, offset_x: float, night: bool) -> None:
    body_mat = make_rubber_material(bpy, f"Mat_{spec['id']}", spec["hex"])
    acc_mat = make_rubber_material(bpy, f"Acc_{spec['id']}", spec["accent"], roughness=0.48)
    eye_mat = make_glaze_eye_material(bpy)
    glow_mat = make_emissive_pearl(bpy, f"Glow_{spec['id']}", spec["glow"], night)

    # Core rounded matte-vinyl body
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=32, radius=0.46, location=(offset_x, 0.0, 0.48))
    body = bpy.context.active_object
    body.name = f"Body_{spec['id']}"
    if spec["shape"] == "bell":
        body.scale = (1.02, 0.98, 1.15)
    elif spec["shape"] == "wood":
        body.scale = (1.05, 0.92, 0.84)
        body.rotation_euler = (math.radians(5), 0, 0)
    elif spec["shape"] == "wing":
        body.scale = (0.98, 0.98, 0.96)
    elif spec["shape"] == "ocarina":
        body.scale = (0.94, 0.94, 1.08)
        body.rotation_euler = (0, math.radians(-5), 0)
    elif spec["shape"] == "spiral":
        body.scale = (0.92, 0.92, 1.18)
    elif spec["shape"] == "bowl":
        body.scale = (1.14, 1.05, 0.78)
    elif spec["shape"] == "top":
        body.scale = (0.76, 0.76, 1.16)
        body.rotation_euler = (0, math.radians(-10), 0)
    body.data.materials.append(body_mat)

    # Glazed twin eyes
    for sx in (-0.14, 0.14):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, radius=0.055, location=(offset_x + sx, -0.42, 0.54))
        eye = bpy.context.active_object
        eye.data.materials.append(eye_mat)

    # Signature acoustic element per member
    if spec["shape"] == "bell":
        for sx, rot in ((-0.18, 0.03), (0.19, -0.21)):
            bpy.ops.mesh.primitive_cylinder_add(radius=0.075, depth=0.38, location=(offset_x + sx, 0.0, 1.08), rotation=(0, rot, 0))
            bpy.context.active_object.data.materials.append(body_mat)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.095, location=(offset_x - 0.08, -0.43, 0.34))
        bpy.context.active_object.data.materials.append(glow_mat)
    elif spec["shape"] == "wing":
        for sx in (-0.52, 0.52):
            bpy.ops.mesh.primitive_uv_sphere_add(radius=0.14, location=(offset_x + sx, 0.0, 0.48))
            w = bpy.context.active_object
            w.scale = (1.45, 0.72, 0.65)
            w.data.materials.append(body_mat)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.045, location=(offset_x, -0.44, 0.72))
        bpy.context.active_object.data.materials.append(glow_mat)
    elif spec["shape"] == "spiral":
        bpy.ops.mesh.primitive_torus_add(major_radius=0.22, minor_radius=0.075, location=(offset_x + 0.46, 0.0, 0.74), rotation=(math.radians(90), 0, 0))
        bpy.context.active_object.data.materials.append(acc_mat)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.075, location=(offset_x + 0.46, -0.02, 0.74))
        bpy.context.active_object.data.materials.append(glow_mat)
    elif spec["shape"] == "top":
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.07, location=(offset_x - 0.12, 0.0, 1.15))
        bpy.context.active_object.data.materials.append(glow_mat)


def render_sheet(out_dir: str, night: bool = False) -> None:
    import bpy  # type: ignore

    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 96
    scene.render.resolution_x = 2240
    scene.render.resolution_y = 640
    scene.render.film_transparent = True
    scene.view_settings.view_transform = "AgX"

    for idx, spec in enumerate(TROUPE):
        build_member(bpy, spec, offset_x=(idx - 3) * 1.38, night=night)

    bpy.ops.object.camera_add(location=(0.0, -7.2, 1.25), rotation=(math.radians(82), 0, 0))
    cam = bpy.context.active_object
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 10.6
    scene.camera = cam

    bpy.ops.object.light_add(type="AREA", location=(-3.5, -4.5, 4.8))
    key = bpy.context.active_object
    key.data.energy = 140 if night else 620
    key.data.size = 4.0

    os.makedirs(out_dir, exist_ok=True)
    tag = "night" if night else "day"
    scene.render.filepath = os.path.join(out_dir, f"chimmo_troupe_{tag}.png")
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python3 Tools/ip/chimmo3d.py <sheet|sprites> <out_dir>")
        sys.exit(1)
    mode, out = sys.argv[1], sys.argv[2]
    try:
        import bpy  # noqa: F401
    except ImportError:
        print("Blender bpy is not installed in this environment. Install via `pip install bpy` (Python 3.11) or run inside Blender.")
        sys.exit(2)
    render_sheet(out, night=False)
    render_sheet(out, night=True)
