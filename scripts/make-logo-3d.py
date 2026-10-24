"""Turns the animated logo's After Effects export into 3D geometry for CRT XR.

Reads assets/logo/animated-logo-2.json (exported from the 'Animated Logo 2'
composition: each letter's shape paths, fills, transforms and keyframes) and
writes assets/logo/logo-3d.json for scripts/ui/logo_3d.gd: per letter, the
front face as triangles (its black outline and its coloured face), the
outline rings its sides extrude along, and its animation keys.

In After Effects each letter is two shape groups: a black outline (outer
path minus inner path, and the same around any hole) drawn above a coloured
face. Paths combine by even-odd, as Merge Paths does here.

    python scripts/make-logo-3d.py
"""
from pathlib import Path
import json

import shapely
from shapely.geometry import Polygon, MultiPolygon
from shapely.geometry.polygon import orient
from shapely.ops import unary_union

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets/logo/animated-logo-2.json"
OUT = ROOT / "assets/logo/logo-3d.json"


def region(paths, offset):
    """The group's filled area: its closed paths combined even-odd."""
    shape = Polygon()
    for path in paths:
        ring = Polygon([(x + offset[0], y + offset[1]) for x, y in path]).buffer(0)
        shape = shape.symmetric_difference(ring)
    return shape.buffer(0)


def polygons(shape):
    if shape.is_empty:
        return []
    if isinstance(shape, Polygon):
        return [shape]
    if isinstance(shape, MultiPolygon):
        return list(shape.geoms)
    return [g for g in getattr(shape, "geoms", []) if isinstance(g, Polygon)]


def triangles(shape):
    """Flat [x, y, x, y, ...] triangles covering the shape, holes respected."""
    flat = []
    for polygon in polygons(shape):
        for triangle in shapely.constrained_delaunay_triangles(polygon).geoms:
            points = list(triangle.exterior.coords)[:3]
            # Counter-clockwise in After Effects' y-down space, consistently.
            (ax, ay), (bx, by), (cx, cy) = points
            if (bx - ax) * (cy - ay) - (by - ay) * (cx - ax) < 0:
                points = [points[0], points[2], points[1]]
            for x, y in points:
                flat += [round(x, 2), round(y, 2)]
    return flat


def rings(shape):
    """Every boundary of the silhouette, for the extruded sides. Outlines run
    with a positive signed area and holes the other way, so each edge's
    (dy, -dx) points out of the solid."""
    out = []
    for polygon in polygons(shape):
        polygon = orient(polygon, sign=1.0)
        for ring in [polygon.exterior, *polygon.interiors]:
            coords = list(ring.coords)[:-1]
            out.append([round(v, 2) for point in coords for v in point])
    return out


def main():
    source = json.loads(SOURCE.read_text(encoding="utf-8"))
    letters = []
    for letter in source["letters"]:
        anchor = letter["anchor"]
        outline, face = letter["groups"][0], letter["groups"][1]
        # Group positions are in layer space; the layer's anchor is its centre.
        offset = lambda group: (group["transform"]["position"][0] - anchor[0], group["transform"]["position"][1] - anchor[1])
        black = region(outline["paths"], offset(outline))
        colour = region(face["paths"], offset(face)).difference(black)
        silhouette = unary_union([black, colour]).buffer(0)
        keys = letter["position_keys"]
        letters.append({
            "name": letter["name"],
            "position": keys[0]["v"][:2],
            "colour": face["fill"][:3],
            "outline_triangles": triangles(black),
            "face_triangles": triangles(colour),
            "rings": rings(silhouette),
            "z_keys": [[k["t"], k["v"][2], k["in_influence"], k["out_influence"]] for k in keys],
            "extrusion_keys": [[k["t"], k["v"], k["in_influence"], k["out_influence"]] for k in letter["extrusion_keys"]],
        })
    OUT.write_text(json.dumps({
        "source": source["source"],
        "loop_seconds": source["loop_seconds"],
        "null_rotation_xyz": source["null_rotation_xyz"],
        "letters": letters,
    }, separators=(",", ":")), encoding="utf-8")
    print("Wrote", OUT, sum(len(l["outline_triangles"]) + len(l["face_triangles"]) for l in letters) // 6, "triangles")


if __name__ == "__main__":
    main()
