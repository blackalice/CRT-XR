"""Offline, constrained rear-panel simplification in a separate Blender process.

Original GLB and the user's open Blender session are untouched. The output is a
geometry-only intermediate; the Godot converter reuses the original material.
"""
from pathlib import Path
import hashlib
import json
from collections import Counter

import bpy
import bmesh

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "build/crt-model/crt_tv.glb"
OUTPUT = ROOT / "build/crt-model/rear-detail"


def face_key(mesh, face):
    return tuple(sorted(tuple(mesh.vertices[index].co) for index in face.vertices))


def boundary_edges(mesh):
    # Weld UV/normal splits by position solely for the topology check.
    edges = Counter()
    for face in mesh.polygons:
        points = [tuple(round(value, 5) for value in mesh.vertices[i].co) for i in face.vertices]
        for a, b in zip(points, points[1:]+points[:1]):
            edges[tuple(sorted((a, b)))] += 1
    return {edge for edge, count in edges.items() if count == 1}


def run():
    digest = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))
    rear = next(obj for obj in bpy.context.scene.objects
                if obj.type == "MESH" and obj.parent.name == "rear_section")
    mesh = rear.data
    # The glTF splits vertices at UV/normal seams. Weld exact duplicates before
    # collapsing so adjacent panels cannot decimate apart and expose cracks.
    welded = bmesh.new()
    welded.from_mesh(mesh)
    bmesh.ops.remove_doubles(welded, verts=list(welded.verts), dist=1e-7)
    welded.to_mesh(mesh); welded.free(); mesh.update()
    # Blender's local +Y is the cabinet's rear. Lock EVERY vertex used by a
    # side/top/bottom/front-facing triangle, not merely the bounding-box corners.
    protected_faces = [face for face in mesh.polygons if face.normal.y <= .95]
    protected = {index for face in protected_faces for index in face.vertices}
    locked_faces = {face_key(mesh, face) for face in protected_faces}
    before = len(mesh.polygons)
    original_boundaries = boundary_edges(mesh)
    boundary_positions = {point for edge in original_boundaries for point in edge}
    bounds = [tuple(min(v.co[i] for v in mesh.vertices) for i in range(3)),
              tuple(max(v.co[i] for v in mesh.vertices) for i in range(3))]
    protected.update(v.index for v in mesh.vertices if any(
        abs(v.co[i] - limit[i]) < 1e-6 for i in range(3) for limit in bounds))
    protected.update(v.index for v in mesh.vertices
                     if tuple(round(value, 5) for value in v.co) in boundary_positions)
    locked_positions = {tuple(mesh.vertices[index].co) for index in protected}
    group = rear.vertex_groups.new(name="HiddenRearOnly")
    group.add([v.index for v in mesh.vertices if v.index not in protected], 1.0, "REPLACE")
    modifier = rear.modifiers.new("HiddenRearOnly", "DECIMATE")
    modifier.ratio = .5
    modifier.vertex_group = group.name
    modifier.vertex_group_factor = 1000
    bpy.context.view_layer.objects.active = rear
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    mesh = rear.data
    remaining = {tuple(v.co) for v in mesh.vertices}
    remaining_faces = {face_key(mesh, face) for face in mesh.polygons}
    if not locked_positions.issubset(remaining) or not locked_faces.issubset(remaining_faces):
        raise RuntimeError("Simplifier changed protected visible geometry")
    after_bounds = [tuple(min(v.co[i] for v in mesh.vertices) for i in range(3)),
                    tuple(max(v.co[i] for v in mesh.vertices) for i in range(3))]
    if bounds != after_bounds:
        raise RuntimeError("Simplifier changed the cabinet's bounds")
    if original_boundaries != boundary_edges(mesh):
        raise RuntimeError("Simplifier opened or changed a panel boundary")
    # Only this panel is exported. Materials/textures and the source scene stay
    # in the original; its positions are reconciled by the Godot converter.
    mesh.materials.clear()
    bpy.ops.object.select_all(action="DESELECT")
    rear.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT / "rear.glb"), use_selection=True,
                             export_format="GLB", export_materials="NONE")
    report = {"source_sha256": digest, "before_triangles": before,
              "output_sha256": hashlib.sha256((OUTPUT / "rear.glb").read_bytes()).hexdigest(),
              "after_triangles": len(mesh.polygons), "protected_faces": len(locked_faces),
              "protected_positions": len(locked_positions),
              "visible_geometry_preserved": True, "bounds_preserved": True,
              "boundary_edges_preserved": True}
    (OUTPUT / "manifest.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    if hashlib.sha256(SOURCE.read_bytes()).hexdigest() != digest:
        raise RuntimeError("Original GLB changed")
    print("REAR_SIMPLIFIED", json.dumps(report), flush=True)


run()
