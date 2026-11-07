"""Print TV.ai graphics onto the existing opaque fascia; preserve authored mesh.

Run on the artist source in background Blender with -- --save-variants to create
editable silver/black copies. The normal exporter decorates temporary copies only.
Run extract-wide-tv-graphics.py and prepare-wide-tv-graphics.gd after artwork edits.
"""
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets/models/widescreen-crt'
ARTWORK = ROOT / 'artwork/widescreen-crt'
BODY = 'Graphite silver moulded plastic'
TRIM = BODY + '.001'
PRINT = 'Printed silver fascia'
BLACK = (.012, .014, .017, 1)
# Subdued pad printing rather than freshly applied, high-contrast lettering.
PRINT_STRENGTH = {'silver': .35, 'black': .18}


def srgb(value):
    return value*12.92 if value <= .0031308 else 1.055*value**(1/2.4)-.055


def colour_map(black=False):
    """Bake monochrome ink and plastic together: no alpha surfaces or overdraw."""
    name = 'fascia-black.png' if black else 'fascia-silver.png'
    mask = bpy.data.images.load(str(ARTWORK / 'graphics-mask.png'), check_existing=True)
    mask.colorspace_settings.name = 'Non-Color'
    pixels = list(mask.pixels[:])
    base = BLACK if black else (.16, .18, .21, 1)
    ink = (.78, .75, .68, 1) if black else (.003, .003, .003, 1)
    # Image.save writes the pixel buffer; encode the linear plastic explicitly.
    for i in range(0,len(pixels),4):
        alpha = pixels[i+3] * PRINT_STRENGTH['black' if black else 'silver']
        pixels[i:i+4] = [srgb(base[c]*(1-alpha)+ink[c]*alpha) for c in range(3)] + [1]
    image = bpy.data.images.new(name, width=mask.size[0], height=mask.size[1], alpha=False)
    image.pixels[:] = pixels
    image.filepath_raw = str((ASSETS if black else ARTWORK) / name)
    image.file_format = 'PNG'
    image.save()
    image.reload()
    image.pack()
    return image


def decorate(objects, black=False):
    source = bpy.data.materials[BODY]
    material = source.copy()
    material.name = PRINT
    bsdf = material.node_tree.nodes.get('Principled BSDF')
    tex = material.node_tree.nodes.new('ShaderNodeTexImage')
    tex.image = colour_map(black)
    tex.extension = 'EXTEND'
    material.node_tree.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    material['artwork_source'] = 'artwork/TV.ai'
    for ob in objects:
        if ob.type != 'MESH': continue
        # Only body plastic is printed; retain the original speaker and trim UVs.
        slots = [i for i,m in enumerate(ob.data.materials) if m == source]
        if not slots: continue
        uv = ob.data.uv_layers.active or ob.data.uv_layers.new(name='UVMap')
        # Joined export batches must share one UV name. Otherwise Blender keeps
        # separate UVMap/GrilleUV layers and the lower panel samples empty UVs.
        uv.name = 'UVMap'
        for polygon in ob.data.polygons:
            if polygon.material_index not in slots: continue
            normal = ob.matrix_world.to_3x3() @ polygon.normal
            front = normal.y < -.5 and ob.name.split('.')[0] in ['FrontFrame','LowerFascia']
            for index in polygon.loop_indices:
                p = ob.matrix_world @ ob.data.vertices[ob.data.loops[index].vertex_index].co
                # Pixel calibration matches the AI screenshot's LED and fascia.
                uv.data[index].uv = (.5+p.x/.7, (1267.5+p.z*(2900/.7))/544) if front else (0,0)
        for index in slots: ob.data.materials[index] = material
    if black:
        # These copies are single-scene authoring outputs, never the open source.
        bpy.data.materials[TRIM].node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value = (.026,.029,.034,1)
        bpy.data.materials['Charcoal rear and recess'].node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value = (.008,.009,.011,1)
        speaker = bpy.data.materials['Speaker mesh — tiled texture']
        node = next(n for n in speaker.node_tree.nodes if n.type=='TEX_IMAGE')
        image = node.image.copy()
        values = list(image.pixels[:])
        for i in range(0,len(values),4):
            values[i:i+3] = [srgb((v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4)*.09) for v in values[i:i+3]]
        image.pixels[:] = values
        image.filepath_raw = str(ASSETS/'speaker-black.png'); image.file_format='PNG'; image.save(); image.pack()
        node.image = image
    return material


if __name__ == '__main__':
    import sys
    if '--save-variants' not in sys.argv:
        raise SystemExit('Use -- --save-variants; the artist source is never overwritten.')
    bpy.context.preferences.filepaths.save_version = 0
    bpy.context.preferences.filepaths.file_preview_type = 'NONE'
    original = bpy.data.filepath
    for finish in ['silver','black']:
        if finish == 'black': bpy.ops.wm.open_mainfile(filepath=original)
        asset = next(c for c in bpy.context.scene.collection.children if c.name.startswith('CRT XR'))
        decorate(asset.all_objects, finish=='black')
        bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/f'artwork/widescreen-crt/crt-xr-26-wide-{finish}.blend'))
