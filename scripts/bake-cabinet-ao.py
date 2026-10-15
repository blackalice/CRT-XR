"""Run with Blender 5.2 --background --factory-startup --python this_file.

Deterministic local Cycles bake of the user-supplied cabinet. Never uploads
assets, changes the source GLB, or touches another Blender session.
"""
from pathlib import Path
import hashlib
import json
import time
import sys

import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "build/crt-model/crt_tv.glb"
OUTPUT = ROOT / "build/crt-model/ao"
SIZE = 2048
SAMPLES = 192
DISTANCE = 0.16  # metres at the app's 1.32 m virtual tube width


def run():
    started = time.monotonic()
    original_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))
    scene = bpy.context.scene
    meshes = [obj for obj in scene.objects if obj.type == "MESH"]
    if "--omit-logo" in sys.argv:
        # The app replaces this raised badge with the user's printed artwork.
        # Avoid retaining the original wordmark's shadow beneath the new logo.
        for obj in meshes:
            if obj.parent and obj.parent.name == "Logo":
                obj.hide_render = True
    screen = next(obj for obj in meshes if obj.parent and obj.parent.name == "Screen")
    corners = [screen.matrix_world @ Vector(v) for v in screen.bound_box]
    width = max(v.x for v in corners) - min(v.x for v in corners)
    master = bpy.data.objects.new("VirtualSize_1_32m", None)
    scene.collection.objects.link(master)
    for obj in list(scene.objects):
        if obj != master and obj.parent is None:
            obj.parent = master
    master.scale = (1.32 / width,) * 3
    bpy.context.view_layer.update()

    scene.render.engine = "CYCLES"
    scene.cycles.samples = SAMPLES
    scene.cycles.use_denoising = False
    scene.cycles.seed = 42
    scene.render.bake.margin = 16
    scene.render.bake.margin_type = "EXTEND"
    scene.render.bake.use_selected_to_active = False
    scene.render.bake.use_clear = False
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.render.image_settings.color_depth = "8"
    prefs = bpy.context.preferences.addons["cycles"].preferences
    device = "CPU"
    try:
        prefs.compute_device_type = "OPTIX"
        prefs.get_devices()
        for item in prefs.devices:
            item.use = item.type == "OPTIX"
        if any(item.use for item in prefs.devices):
            scene.cycles.device = "GPU"
            device = "OPTIX"
    except (RuntimeError, TypeError):
        scene.cycles.device = "CPU"

    records = []
    for material_name, filename, parts in [
        ("TVfront", "tvfront_ao.png", {"Front_section", "Front_buttons"}),
        ("TVback", "tvback_ao.png", {"rear_section"}),
    ]:
        material = bpy.data.materials[material_name]
        nodes = material.node_tree.nodes
        links = material.node_tree.links
        output = next(node for node in nodes if node.type == "OUTPUT_MATERIAL" and node.is_active_output)
        old_links = [(link.from_socket, link.to_socket) for link in output.inputs["Surface"].links]
        image = bpy.data.images.new(material_name + "_AO_2048", width=SIZE, height=SIZE,
                                    alpha=False, float_buffer=True)
        image.generated_color = (1, 1, 1, 1)
        image.colorspace_settings.name = "Non-Color"
        target = nodes.new("ShaderNodeTexImage")
        target.image = image
        target.label = "Local AO bake target (original UVs)"
        target.location = (-600, -500)
        for node in nodes:
            node.select = False
        target.select = True
        nodes.active = target
        ao = nodes.new("ShaderNodeAmbientOcclusion")
        ao.samples = 32
        ao.only_local = False  # Include bezel/buttons/other cabinet parts.
        ao.inputs["Distance"].default_value = DISTANCE
        ao.location = (-600, -750)
        emission = nodes.new("ShaderNodeEmission")
        emission.inputs["Strength"].default_value = 1
        emission.location = (-300, -750)
        links.new(ao.outputs["AO"], emission.inputs["Color"])
        links.new(emission.outputs["Emission"], output.inputs["Surface"])
        selected = [obj for obj in meshes if obj.parent and obj.parent.name in parts]
        if not selected or any(not obj.data.uv_layers for obj in selected):
            raise RuntimeError("Expected casing geometry with existing UVs: " + material_name)
        bpy.ops.object.select_all(action="DESELECT")
        for obj in selected:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = selected[0]
        print("AO_BAKE_START", material_name, "objects", [obj.parent.name for obj in selected], flush=True)
        bpy.ops.object.bake(type="EMIT", use_clear=False, margin=16)
        image.filepath_raw = str(OUTPUT / filename)
        image.file_format = "PNG"
        image.save()
        pixels = np.empty(SIZE * SIZE * 4, dtype=np.float32)
        image.pixels.foreach_get(pixels)
        values = pixels.reshape(-1, 4)[:, 0]
        stats = {"min": float(values.min()), "mean": float(values.mean()),
                 "p01": float(np.quantile(values, .01)),
                 "fraction_below_095": float((values < .95).mean())}
        if not np.isfinite(values).all() or stats["fraction_below_095"] < .005:
            raise RuntimeError("Bake is invalid or effectively blank: " + material_name)
        records.append({"material": material_name, "file": filename, "statistics": stats,
                        "sha256": hashlib.sha256((OUTPUT / filename).read_bytes()).hexdigest()})
        # Restore the imported surface for a useful editable working copy.
        for link in list(output.inputs["Surface"].links):
            links.remove(link)
        for source_socket, target_socket in old_links:
            links.new(source_socket, target_socket)
        print("AO_BAKE_DONE", json.dumps(records[-1]), flush=True)

    if hashlib.sha256(SOURCE.read_bytes()).hexdigest() != original_hash:
        raise RuntimeError("Source GLB changed unexpectedly")
    bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT / "crt-ao-bake.blend"))
    manifest = {"blender": bpy.app.version_string, "original_logo_excluded": "--omit-logo" in sys.argv, "source_sha256": original_hash,
                "resolution": SIZE, "cycles_samples": SAMPLES, "ao_node_samples": 32,
                "distance_at_virtual_scale_m": DISTANCE, "device": device,
                "duration_seconds": time.monotonic() - started, "maps": records}
    (OUTPUT / "bake.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print("AO_BAKE_COMPLETE", json.dumps(manifest), flush=True)


run()
