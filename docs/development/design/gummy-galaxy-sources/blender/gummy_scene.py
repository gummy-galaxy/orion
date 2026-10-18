"""Gummy Galaxy concept renders for Blender 3.4.

Run: Blender -b -P gummy_scene.py -- --shot orrery --style gummy --out out.png
"""
import argparse
import math
import sys

import bmesh
import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
parser = argparse.ArgumentParser()
parser.add_argument("--shot", default="orrery")
parser.add_argument("--style", default="gummy")
parser.add_argument("--palette", default="pair")
parser.add_argument("--out", default="/tmp/out.png")
parser.add_argument("--width", type=int, default=1400)
parser.add_argument("--height", type=int, default=1400)
parser.add_argument("--samples", type=int, default=160)
parser.add_argument("--frames", type=int, default=0)
parser.add_argument("--bg", default="tide")
parser.add_argument("--save", default="", help="save the built scene as a .blend instead of rendering")
args = parser.parse_args(argv)


def linear(hex_color, alpha=1.0):
    values = [int(hex_color[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    return tuple(((v / 12.92) if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4) for v in values) + (alpha,)


F = {
    "cherry": "#ff3d6e", "blue": "#2e7dff", "apple": "#7be14a", "grape": "#8b3dff",
    "peach": "#ff9f45", "lemon": "#ffd84a", "cotton": "#ff8fd0", "sky": "#8fd0ff",
}
PALETTES = {
    "pair": {"core": "#ffd84a", "arms": ["#ffb08c", "#ff8fd0", "#ffc478"], "ring": "#ff8fd0", "planet": "#ff78c4", "band": "#ffd84a", "moon": "#ffd84a",
             "bear": "#ff8fd0", "star": "#ffd84a", "drop": "#ffd84a", "pop": ["#ff8fd0", "#ffd84a"], "belt": ["#ff8fd0", "#ffd84a", "#ff8fd0"], "string": "#ffd6ec"},
    "full": {"core": F["lemon"], "arms": [F["peach"], F["cherry"], F["cotton"]], "ring": F["cotton"], "planet": F["blue"], "band": F["sky"], "moon": F["apple"],
             "bear": F["cherry"], "star": F["lemon"], "drop": F["apple"], "pop": [F["blue"], F["cotton"]], "belt": [F["cherry"], F["lemon"], F["apple"]], "string": F["cotton"]},
}
P = PALETTES[args.palette]
BACKGROUNDS = {
    "tide": ["#ff8fd0", "#3b6cff", "#0a1d20", "#3b6cff", "#8b3dff"],
    "grape": ["#ff8fd0", "#5a2fd0", "#120a2c", "#5a2fd0", "#2e7dff"],
    "peach": ["#ffd84a", "#ff8fd0", "#1c0f24", "#3a1f6b", "#5a2fd0"],
    "studio": ["#f4d8ea", "#e9d6f7", "#f6eefc", "#e2e6fb", "#d9e8fb"],
}

# What the camera sees behind the subject: a soft radial glow, center to edge.
BACKDROPS = {
    "tide": ["#5a86ff", "#3346c8", "#1a1660", "#0b0f2a"],
    "grape": ["#b07bff", "#6a35d6", "#2d1170", "#120a2c"],
    "peach": ["#ffc18a", "#ff7fb0", "#7a2c78", "#1c0f24"],
    "studio": ["#ffffff", "#f6eefb", "#e6dcf2", "#cfc4e6"],
}

# ---------- Scene ----------
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
preferences = bpy.context.preferences.addons["cycles"].preferences
preferences.compute_device_type = "METAL"
preferences.get_devices()
for device in preferences.devices:
    device.use = True
scene.cycles.device = "GPU"
scene.cycles.samples = args.samples
scene.cycles.use_denoising = True
scene.cycles.max_bounces = 16
scene.cycles.transmission_bounces = 16
scene.cycles.volume_bounces = 4
scene.render.resolution_x = args.width
scene.render.resolution_y = args.height
scene.render.film_transparent = False
scene.view_settings.view_transform = "Standard"
scene.view_settings.exposure = -0.35
scene.render.image_settings.file_format = "PNG"


def world(stops):
    tree = bpy.data.worlds.new("World")
    scene.world = tree
    tree.use_nodes = True
    nodes, links = tree.node_tree.nodes, tree.node_tree.links
    nodes.clear()
    coord = nodes.new("ShaderNodeTexCoord")
    separate = nodes.new("ShaderNodeSeparateXYZ")
    remap = nodes.new("ShaderNodeMapRange")
    remap.inputs["From Min"].default_value = -0.3
    remap.inputs["From Max"].default_value = 0.3
    ramp = nodes.new("ShaderNodeValToRGB")
    elements = ramp.color_ramp.elements
    elements[0].position, elements[0].color = 0.0, linear(stops[0])
    elements[1].position, elements[1].color = 1.0, linear(stops[4])
    ramp.color_ramp.interpolation = "EASE"
    for position, hex_color in ((0.2, stops[1]), (0.44, stops[2]), (0.56, stops[2]), (0.8, stops[3])):
        element = elements.new(position)
        element.color = linear(hex_color)
    background = nodes.new("ShaderNodeBackground")
    background.inputs["Strength"].default_value = 1.0
    output = nodes.new("ShaderNodeOutputWorld")
    # Camera rays see a radial glow; lighting and refraction still use the vertical gradient.
    glow_stops = BACKDROPS[args.bg]
    center = nodes.new("ShaderNodeVectorMath")
    center.operation = "SUBTRACT"
    center.inputs[1].default_value = (0.5, 0.5, 0.0)
    aspect = nodes.new("ShaderNodeVectorMath")
    aspect.operation = "MULTIPLY"
    aspect.inputs[1].default_value = (args.width / args.height, 1.0, 0.0)
    distance = nodes.new("ShaderNodeVectorMath")
    distance.operation = "LENGTH"
    glow_ramp = nodes.new("ShaderNodeValToRGB")
    glow_ramp.color_ramp.interpolation = "EASE"
    glow_elements = glow_ramp.color_ramp.elements
    glow_elements[0].position, glow_elements[0].color = 0.0, linear(glow_stops[0])
    glow_elements[1].position, glow_elements[1].color = 0.95, linear(glow_stops[3])
    for position, hex_color in ((0.32, glow_stops[1]), (0.62, glow_stops[2])):
        glow_elements.new(position).color = linear(hex_color)
    glow = nodes.new("ShaderNodeBackground")
    light_path = nodes.new("ShaderNodeLightPath")
    mix = nodes.new("ShaderNodeMixShader")
    links.new(coord.outputs["Window"], center.inputs[0])
    links.new(center.outputs["Vector"], aspect.inputs[0])
    links.new(aspect.outputs["Vector"], distance.inputs[0])
    links.new(distance.outputs["Value"], glow_ramp.inputs["Fac"])
    links.new(glow_ramp.outputs["Color"], glow.inputs["Color"])
    links.new(light_path.outputs["Is Camera Ray"], mix.inputs["Fac"])
    links.new(background.outputs["Background"], mix.inputs[1])
    links.new(glow.outputs["Background"], mix.inputs[2])
    links.new(coord.outputs["Generated"], separate.inputs[0])
    links.new(separate.outputs["Z"], remap.inputs["Value"])
    links.new(remap.outputs["Result"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], background.inputs["Color"])
    links.new(mix.outputs["Shader"], output.inputs["Surface"])


world(BACKGROUNDS[args.bg])


def area_light(name, location, target, size, power, color="#ffffff"):
    data = bpy.data.lights.new(name, "AREA")
    data.size = size
    data.energy = power
    data.color = linear(color)[:3]
    light = bpy.data.objects.new(name, data)
    light.location = location
    direction = Vector(target) - Vector(location)
    light.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(light)
    return light


area_light("Key", (-3.5, -4.5, 4.0), (0, 0, 0), 3.5, 900)
area_light("Fill", (4.0, -5.0, -0.5), (0, 0, 0), 4.0, 260, "#e6ecff")
area_light("RimTop", (0.5, 3.5, 3.5), (0, 0, 0), 3.0, 700, "#9b6bff" if args.bg != "studio" else "#ffffff")
area_light("RimLow", (-0.5, 3.0, -3.0), (0, 0, 0), 3.0, 600, "#ff8fd0" if args.bg != "studio" else "#ffe6f2")

camera_data = bpy.data.cameras.new("Camera")
camera_data.lens = 60
camera = bpy.data.objects.new("Camera", camera_data)
camera.location = (0, -7.4, 0)
camera.rotation_euler = (math.radians(90), 0, 0)
scene.collection.objects.link(camera)
scene.camera = camera

# ---------- Materials ----------


def color_attribute_node(nodes):
    node = nodes.new("ShaderNodeAttribute")
    node.attribute_name = "Col"
    return node


def make_material(style):
    material = bpy.data.materials.new(style)
    material.use_nodes = True
    nodes, links = material.node_tree.nodes, material.node_tree.links
    shader = nodes["Principled BSDF"]
    attribute = color_attribute_node(nodes)
    links.new(attribute.outputs["Color"], shader.inputs["Base Color"])
    links.new(attribute.outputs["Color"], shader.inputs["Subsurface Color"])
    if style == "gummy":
        shader.inputs["Subsurface"].default_value = 1.0
        shader.inputs["Subsurface Radius"].default_value = (0.16, 0.09, 0.06)
        shader.inputs["Roughness"].default_value = 0.2
        shader.inputs["Specular"].default_value = 0.6
        shader.inputs["Clearcoat"].default_value = 0.8
        shader.inputs["Clearcoat Roughness"].default_value = 0.04
        shader.inputs["Transmission"].default_value = 0.12
        shader.inputs["IOR"].default_value = 1.42
        material.cycles.displacement_method = "BUMP"
    elif style == "plastic":
        shader.inputs["Transmission"].default_value = 1.0
        shader.inputs["Roughness"].default_value = 0.06
        shader.inputs["IOR"].default_value = 1.49
        shader.inputs["Specular"].default_value = 0.7
    elif style == "hardcandy":
        shader.inputs["Transmission"].default_value = 0.92
        shader.inputs["Roughness"].default_value = 0.03
        shader.inputs["IOR"].default_value = 1.52
        shader.inputs["Clearcoat"].default_value = 1.0
    elif style in ("clay", "plush", "sugar"):
        noise = nodes.new("ShaderNodeTexNoise")
        bump = nodes.new("ShaderNodeBump")
        links.new(noise.outputs["Fac"], bump.inputs["Height"])
        links.new(bump.outputs["Normal"], shader.inputs["Normal"])
        if style == "clay":
            noise.inputs["Scale"].default_value = 36.0
            noise.inputs["Detail"].default_value = 6.0
            bump.inputs["Strength"].default_value = 0.12
            shader.inputs["Roughness"].default_value = 0.72
            shader.inputs["Specular"].default_value = 0.3
            shader.inputs["Subsurface"].default_value = 0.08
            shader.inputs["Subsurface Radius"].default_value = (0.05, 0.03, 0.02)
            wave = nodes.new("ShaderNodeTexWave")
            wave.inputs["Scale"].default_value = 26.0
            wave.inputs["Distortion"].default_value = 9.0
            mix = nodes.new("ShaderNodeMath")
            mix.operation = "ADD"
            scale = nodes.new("ShaderNodeMath")
            scale.operation = "MULTIPLY"
            scale.inputs[1].default_value = 0.12
            links.new(wave.outputs["Fac"], scale.inputs[0])
            links.new(noise.outputs["Fac"], mix.inputs[0])
            links.new(scale.outputs["Value"], mix.inputs[1])
            links.new(mix.outputs["Value"], bump.inputs["Height"])
        elif style == "plush":
            noise.inputs["Scale"].default_value = 420.0
            noise.inputs["Detail"].default_value = 2.0
            bump.inputs["Strength"].default_value = 0.35
            shader.inputs["Roughness"].default_value = 1.0
            shader.inputs["Specular"].default_value = 0.1
            shader.inputs["Sheen"].default_value = 1.0
            shader.inputs["Sheen Tint"].default_value = 0.6
        else:
            noise.inputs["Scale"].default_value = 180.0
            bump.inputs["Strength"].default_value = 0.5
            shader.inputs["Subsurface"].default_value = 0.6
            shader.inputs["Subsurface Radius"].default_value = (0.25, 0.15, 0.1)
            shader.inputs["Roughness"].default_value = 0.55
    elif style == "glow":
        emission = nodes.new("ShaderNodeEmission")
        emission.inputs["Strength"].default_value = 3.0
        links.new(attribute.outputs["Color"], emission.inputs["Color"])
        mix = nodes.new("ShaderNodeMixShader")
        mix.inputs["Fac"].default_value = 0.45
        shader.inputs["Transmission"].default_value = 1.0
        shader.inputs["Roughness"].default_value = 0.15
        output = nodes["Material Output"]
        links.new(shader.outputs["BSDF"], mix.inputs[1])
        links.new(emission.outputs["Emission"], mix.inputs[2])
        links.new(mix.outputs["Shader"], output.inputs["Surface"])
    return material


def solid_material(name, hex_color, roughness=0.5):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    shader = material.node_tree.nodes["Principled BSDF"]
    shader.inputs["Base Color"].default_value = linear(hex_color)
    shader.inputs["Roughness"].default_value = roughness
    return material


STYLE = args.style
MATERIAL = make_material(STYLE)
PAPER = solid_material("Paper", "#f6f0f6", 0.6)
INK = solid_material("Ink", "#1a0710", 0.3)
crystal_material = make_material("hardcandy")

# ---------- Geometry ----------


def paint(obj, color_for):
    mesh = obj.data
    attribute = mesh.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for vertex in mesh.vertices:
        attribute.data[vertex.index].color = color_for(obj.matrix_world @ vertex.co)


def finish(obj, material=None, subsurf=0, smooth=True):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    if subsurf:
        modifier = obj.modifiers.new("Subsurf", "SUBSURF")
        modifier.levels = subsurf
        modifier.render_levels = subsurf
    if STYLE == "clay":
        texture = bpy.data.textures.new("Lumps", "CLOUDS")
        texture.noise_scale = 0.35
        displace = obj.modifiers.new("Lumps", "DISPLACE")
        displace.texture = texture
        displace.strength = 0.025
    if smooth:
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
    obj.data.materials.append(material or MATERIAL)
    obj.select_set(False)
    return obj


def link(obj):
    scene.collection.objects.link(obj)
    return obj


def blob(spheres, voxel=0.014, smoothing=6, name="Blob"):
    """Fuse overlapping spheres into one mesh and color it by the nearest sphere."""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    for (center, radius, _) in spheres:
        bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=16, radius=radius, matrix=__import__("mathutils").Matrix.Translation(center))
    bm.to_mesh(mesh)
    bm.free()
    obj = link(bpy.data.objects.new(name, mesh))
    bpy.context.view_layer.objects.active = obj
    remesh = obj.modifiers.new("Remesh", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = voxel
    smooth = obj.modifiers.new("Smooth", "SMOOTH")
    smooth.factor = 0.8
    smooth.iterations = smoothing
    bpy.ops.object.modifier_apply(modifier="Remesh")
    bpy.ops.object.modifier_apply(modifier="Smooth")

    def color_for(point):
        best, best_distance = spheres[0][2], 1e9
        for (center, radius, color) in spheres:
            distance = (point - Vector(center)).length - radius
            if distance < best_distance:
                best, best_distance = color, distance
        return linear(best)
    paint(obj, color_for)
    return finish(obj)


def sphere(center, radius, color_for, name="Sphere"):
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=64, v_segments=40, radius=radius)
    bm.to_mesh(mesh)
    bm.free()
    obj = link(bpy.data.objects.new(name, mesh))
    obj.location = center
    bpy.context.view_layer.update()
    paint(obj, color_for)
    return finish(obj)


def torus(major, minor, rotation, hex_color, name="Ring", location=(0, 0, 0)):
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    segments, sides = 160, 32
    rows = []
    for i in range(segments):
        u = i / segments * math.tau
        row = []
        for j in range(sides):
            v = j / sides * math.tau
            row.append(bm.verts.new(((major + minor * math.cos(v)) * math.cos(u), (major + minor * math.cos(v)) * math.sin(u), minor * math.sin(v))))
        rows.append(row)
    for i in range(segments):
        for j in range(sides):
            bm.faces.new((rows[i][j], rows[(i + 1) % segments][j], rows[(i + 1) % segments][(j + 1) % sides], rows[i][(j + 1) % sides]))
    bm.to_mesh(mesh)
    bm.free()
    obj = link(bpy.data.objects.new(name, mesh))
    obj.rotation_euler = rotation
    obj.location = location
    bpy.context.view_layer.update()
    paint(obj, lambda point: linear(hex_color))
    return finish(obj)


def star(center, radius, points, inner, depth, hex_color, spin=0.0, name="Star"):
    outline = []
    for i in range(points * 2):
        angle = spin + math.pi / 2 + i * math.pi / points
        r = radius if i % 2 == 0 else radius * inner
        outline.append((math.cos(angle) * r, math.sin(angle) * r))
    return puffy(outline, depth, hex_color, center, name)


def puffy(outline, depth, hex_color, center, name="Puffy", subsurf=3):
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    layers = []
    for (y, scale) in ((-depth, 0.82), (-depth * 0.5, 1.0), (0.0, 1.06), (depth * 0.5, 1.0), (depth, 0.82)):
        layers.append([bm.verts.new((x * scale, y, z * scale)) for (x, z) in outline])
    for a, b in zip(layers, layers[1:]):
        for i in range(len(outline)):
            bm.faces.new((a[i], a[(i + 1) % len(outline)], b[(i + 1) % len(outline)], b[i]))
    bm.faces.new(layers[0][::-1])
    bm.faces.new(layers[-1])
    bm.to_mesh(mesh)
    bm.free()
    obj = link(bpy.data.objects.new(name, mesh))
    obj.location = center
    bpy.context.view_layer.update()
    paint(obj, lambda point: linear(hex_color))
    return finish(obj, subsurf=subsurf)


def ray_hit(polygon, angle):
    dx, dz = math.cos(angle), math.sin(angle)
    best = 0.0
    for i in range(len(polygon)):
        (ax, az), (bx, bz) = polygon[i], polygon[(i + 1) % len(polygon)]
        ex, ez = bx - ax, bz - az
        denominator = dx * ez - dz * ex
        if abs(denominator) < 1e-9:
            continue
        t = (ax * ez - az * ex) / denominator
        u = (ax * dz - az * dx) / denominator
        if t > 0 and 0 <= u <= 1:
            best = max(best, t)
    return best


def companion_outline(scale, core):
    """The logo star: long vertical points, short side points, and a round core, as one outline."""
    vertical, horizontal, waist = 1.0, 104 / 182, 32 / 182
    polygon = [(0, vertical), (waist, waist), (horizontal, 0), (waist, -waist), (0, -vertical), (-waist, -waist), (-horizontal, 0), (-waist, waist)]
    outline = []
    for i in range(240):
        angle = i / 240 * math.tau
        r = max(ray_hit(polygon, angle), core) * scale
        outline.append((math.cos(angle) * r, math.sin(angle) * r))
    return outline


def tube(points, radius, hex_color, name="Tube"):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = 4
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for point, co in zip(spline.bezier_points, points):
        point.co = co
        point.handle_left_type = point.handle_right_type = "AUTO"
    obj = link(bpy.data.objects.new(name, curve))
    bpy.context.view_layer.objects.active = obj
    for other in scene.objects:
        other.select_set(False)
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.view_layer.objects.active
    obj.select_set(False)
    paint(obj, lambda point: linear(hex_color))
    return finish(obj)


def build_companion(origin=(0, 0, 0), scale=1.0, mood="pip"):
    body_color = P.get("companion", "#fff4fa")
    pieces = [puffy(companion_outline(scale, 66 / 182), 0.2 * scale, body_color, Vector((0, 0, 0)), "Companion", subsurf=2)]
    front = -0.21 * scale
    for side in (-1, 1):
        center = Vector((side * 0.94, 0.05, -0.375)) * scale
        pieces.append(puffy(companion_outline(scale * 0.53, 46 / 182), 0.12 * scale, body_color, center, "SideStar", subsurf=2))
        start = Vector((side * 0.22, 0.04, -0.12)) * scale
        sag = (start + center) / 2 + Vector((0, 0, -0.18)) * scale
        pieces.append(tube([start, sag, center], 0.022 * scale, "#ffe3f1", "Tether"))
        x = side * 0.13 * scale
        if mood == "happy":
            arc = [Vector((x - 0.06 * scale, front - 0.01, 0.04 * scale)), Vector((x, front - 0.02, -0.02 * scale)), Vector((x + 0.06 * scale, front - 0.01, 0.04 * scale))]
            eye = tube(arc, 0.016 * scale, "#1a1240", "Eye")
        else:
            eye = sphere(Vector((x, front + 0.012, 0.01 * scale)), 0.042 * scale, lambda point: linear("#1a1240"), "Eye")
            eye.scale = (1, 0.6, 1.15)
            glint = sphere(Vector((x + 0.013 * scale, front - 0.018, 0.03 * scale)), 0.012 * scale, lambda point: linear("#ffffff"), "Glint")
            glint.data.materials[0] = PAPER
            pieces.append(glint)
        eye.data.materials[0] = INK
        pieces.append(eye)
        cheek = sphere(Vector((side * 0.24 * scale, front + 0.02, -0.07 * scale)), 0.05 * scale, lambda point: linear("#ff8fd0"), "Cheek")
        cheek.scale = (1, 0.35, 0.7)
        pieces.append(cheek)
    group(pieces, origin)
    return pieces


def spiral_sun(scale=1.0, turn=0.4, offset=(0, 0, 0)):
    spheres = [(Vector(offset), 0.25 * scale, P["core"])]
    for arm in range(3):
        for k in range(44):
            t = k / 43
            angle = turn + arm * math.tau / 3 + t * 2.3
            r = (0.2 + t * 0.46) * scale
            spheres.append((Vector(offset) + Vector((math.cos(angle) * r, 0.0, math.sin(angle) * r)), (0.13 - t * 0.07) * scale, P["arms"][arm]))
    return blob(spheres, name="Sun")


def banded(center, radius):
    def color_for(point):
        local = (point - Vector(center)) / radius
        band = abs(local.z - 0.08 + 0.28 * math.sin(local.x * 2.2)) < 0.16
        return linear(P["band"] if band else P["planet"])
    return color_for


def tilt(obj, x=0.0, z=0.0):
    obj.rotation_euler = (obj.rotation_euler[0] + x, obj.rotation_euler[1], obj.rotation_euler[2] + z)
    return obj


def build_orrery(origin=(0, 0, 0), scale=1.0):
    pieces = []
    sun = spiral_sun(scale)
    pieces.append(sun)
    ring = torus(1.22 * scale, 0.075 * scale, (math.radians(-16), math.radians(-18), 0), P["ring"])
    pieces.append(ring)
    angle = -1.0
    local = Vector((math.cos(angle) * 1.22 * scale, math.sin(angle) * 1.22 * scale, 0))
    world = ring.matrix_world @ local
    pieces.append(sphere(world, 0.25 * scale, banded(world, 0.25 * scale), "Planet"))
    pieces.append(sphere(world + Vector((0.2, -0.1, 0.32)) * scale, 0.1 * scale, lambda point: linear(P["moon"]), "Moon"))
    group(pieces, origin)
    return pieces


def build_badge(origin=(0, 0, 0), scale=1.0):
    pieces = [spiral_sun(scale)]
    pieces.append(torus(1.0 * scale, 0.085 * scale, (math.radians(90 - 24), 0, math.radians(6)), P["ring"]))
    ring = pieces[-1]
    for (angle, radius, kind) in ((-0.7, 0.25, "planet"), (2.8, 0.13, "moon")):
        world = ring.matrix_world @ Vector((math.cos(angle) * scale, math.sin(angle) * scale, 0))
        pieces.append(sphere(world, radius * scale, banded(world, radius * scale) if kind == "planet" else (lambda point: linear(P["moon"])), kind))
    group(pieces, origin)
    return pieces


def build_bear(origin=(0, 0, 0), scale=1.0):
    color = P["bear"]
    parts = [((0, 0, 0.5), 0.37), ((-0.29, 0, 0.84), 0.15), ((0.29, 0, 0.84), 0.15), ((0, 0, -0.18), 0.46), ((0, 0, -0.32), 0.42),
             ((-0.46, -0.05, -0.02), 0.17), ((0.46, -0.05, -0.02), 0.17), ((-0.25, -0.05, -0.68), 0.2), ((0.25, -0.05, -0.68), 0.2), ((0, -0.3, 0.4), 0.13)]
    pieces = [blob([(Vector(c) * scale, r * scale, color) for c, r in parts], name="Bear")]
    for x in (-0.14, 0.14):
        eye = sphere(Vector((x, -0.33, 0.56)) * scale, 0.045 * scale, lambda point: linear("#1a0710"), "Eye")
        eye.data.materials[0] = INK
        pieces.append(eye)
    pieces.append(star(Vector((0, -0.4, -0.16)) * scale, 0.22 * scale, 5, 0.5, 0.05 * scale, P["star"], name="BellyStar"))
    group(pieces, origin)
    return pieces


def build_gumdrop(origin=(0, 0, 0), scale=1.0, ring=True):
    mesh = bpy.data.meshes.new("Gumdrop")
    bm = bmesh.new()
    profile = []
    for i in range(41):
        t = i / 40
        z = -0.5 + t * 1.05
        radius = 0.6 * (1 - t ** 2.2 * 0.62) if t < 0.92 else 0.6 * (1 - 0.92 ** 2.2 * 0.62) * math.sqrt(max(0.0, 1 - ((t - 0.92) / 0.08) ** 2))
        profile.append((radius, z))
    profile.insert(0, (0.0, -0.5))
    rings = []
    segments = 64
    for (radius, z) in profile:
        rings.append([bm.verts.new((radius * math.cos(a / segments * math.tau), radius * math.sin(a / segments * math.tau), z)) for a in range(segments)])
    for a, b in zip(rings, rings[1:]):
        for i in range(segments):
            bm.faces.new((a[i], a[(i + 1) % segments], b[(i + 1) % segments], b[i]))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.to_mesh(mesh)
    bm.free()
    drop = link(bpy.data.objects.new("Gumdrop", mesh))
    drop.scale = (scale, scale, scale)
    bpy.context.view_layer.update()
    paint(drop, lambda point: linear(P["drop"]))
    sugar_material = make_material("sugar") if STYLE == "gummy" else MATERIAL
    finish(drop, sugar_material, subsurf=2)
    pieces = [drop]
    if STYLE in ("gummy", "sugar"):
        crystal_mesh = bpy.data.meshes.new("Crystal")
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=0.022)
        bm.to_mesh(crystal_mesh)
        bm.free()
        crystal = link(bpy.data.objects.new("Crystal", crystal_mesh))
        paint(crystal, lambda point: linear("#ffffff"))
        crystal.data.materials.append(crystal_material)
        crystal.hide_render = True
        crystal.location = (50, 50, 50)
        system = drop.modifiers.new("Sugar", "PARTICLE_SYSTEM").particle_system
        settings = system.settings
        settings.type = "HAIR"
        settings.count = 9000
        settings.hair_length = 0.02
        settings.render_type = "OBJECT"
        settings.instance_object = crystal
        settings.particle_size = 1.0
        settings.size_random = 0.6
        settings.use_rotations = True
        settings.rotation_mode = "NOR"
        settings.phase_factor_random = 2.0
        settings.rotation_factor_random = 1.0
        settings.use_advanced_hair = True
    if ring:
        pieces.append(torus(1.08 * scale, 0.075 * scale, (math.radians(-16), math.radians(12), 0), P["ring"]))
    group(pieces, origin)
    return pieces


def build_pop(origin=(0, 0, 0), scale=1.0):
    mesh = bpy.data.meshes.new("Pop")
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=96, radius1=0.7, radius2=0.7, depth=0.24)
    bm.to_mesh(mesh)
    bm.free()
    disk = link(bpy.data.objects.new("Pop", mesh))
    disk.rotation_euler = (math.radians(90), 0, 0)
    disk.location = (0, 0, 0.3)
    disk.scale = (scale, scale, scale)
    bpy.context.view_layer.update()
    bevel = disk.modifiers.new("Bevel", "BEVEL")
    bevel.width = 0.11
    bevel.segments = 6
    bpy.context.view_layer.objects.active = disk
    bpy.ops.object.modifier_apply(modifier="Bevel")
    subdivide = disk.modifiers.new("Sub", "SUBSURF")
    subdivide.levels = 3
    bpy.ops.object.modifier_apply(modifier="Sub")
    center = Vector((0, 0, 0.3 * scale))

    def swirl(point):
        local = point - center
        stripe = math.sin(2.0 * math.atan2(local.z, local.x) - math.hypot(local.x, local.z) / scale * 11.0)
        return linear(P["pop"][0] if stripe < 0 else P["pop"][1])
    paint(disk, swirl)
    finish(disk)
    stick_mesh = bpy.data.meshes.new("Stick")
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=32, radius1=0.07, radius2=0.07, depth=1.1)
    bm.to_mesh(stick_mesh)
    bm.free()
    stick = link(bpy.data.objects.new("Stick", stick_mesh))
    stick.location = Vector((0, 0.04, -0.85)) * scale
    stick.scale = (scale, scale, scale)
    for polygon in stick.data.polygons:
        polygon.use_smooth = True
    stick.data.materials.append(PAPER)
    group([disk, stick], origin, tilt_x=-0.12)
    return [disk, stick]


def build_belt(origin=(0, 0, 0), scale=1.0):
    pieces = []
    stick_mesh = bpy.data.meshes.new("String")
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=24, radius1=0.04, radius2=0.04, depth=2.3)
    bm.to_mesh(stick_mesh)
    bm.free()
    string = link(bpy.data.objects.new("String", stick_mesh))
    string.rotation_euler = (0, math.radians(45), 0)
    string.location = (0, 0.06, 0)
    bpy.context.view_layer.update()
    paint(string, lambda point: linear(P["string"]))
    pieces.append(finish(string))
    for (center, radius, color, spin) in (((-0.78, 0, -0.78), 0.42, P["belt"][0], 0.3), ((0, 0, 0), 0.52, P["belt"][1], -0.15), ((0.78, 0, 0.78), 0.38, P["belt"][2], 0.2)):
        pieces.append(star(Vector(center), radius, 4, 0.42, 0.09, color, spin))
    group(pieces, origin, scale=scale)
    return pieces


def group(pieces, origin, scale=1.0, tilt_x=0.0):
    anchor = bpy.data.objects.new("Group", None)
    link(anchor)
    for piece in pieces:
        piece.parent = anchor
    anchor.location = origin
    anchor.scale = (scale, scale, scale)
    anchor.rotation_euler = (tilt_x, 0, 0)
    return anchor


def emblem_ring(origin, scale):
    pieces = [torus(0.86, 0.085, (math.radians(-20), math.radians(-16), 0), F["sky"])]
    pieces.append(sphere(Vector((0, 0, 0)), 0.52, banded(Vector((0, 0, 0)), 0.52), "Planet"))
    return group(pieces, origin, scale)


def emblem_knot(origin, scale):
    pieces = [torus(0.5, 0.13, (math.radians(90), 0, 0), F["grape"], location=(-0.3, 0, 0))]
    pieces.append(torus(0.5, 0.13, (0, math.radians(-12), 0), F["cotton"], location=(0.3, 0, 0)))
    return group(pieces, origin, scale, tilt_x=math.radians(-14))


def emblem_cloud(origin, scale):
    spheres = [(Vector((x, 0, z)), radius, F["cotton"]) for x, z, radius in ((-0.55, -0.1, 0.32), (-0.2, 0.15, 0.42), (0.25, 0.22, 0.46), (0.6, -0.04, 0.34), (0.05, -0.16, 0.36), (-0.35, -0.2, 0.28), (0.4, -0.2, 0.3))]
    cloud = blob(spheres, voxel=0.018, smoothing=10, name="Cloud")
    cloud.scale = (1, 0.62, 1)
    return group([cloud], origin, scale)


def emblem_candy(origin, scale):
    candy = blob([(Vector((0, 0, 0)), 0.44, F["cherry"])], voxel=0.016, smoothing=4, name="Candy")
    candy.scale = (1.15, 0.8, 0.9)
    pieces = [candy]
    for side in (-1, 1):
        # A pleated fan: narrow at the twist, wide and scalloped at the end.
        fan = [(0.34, -0.1), (0.34, 0.1)]
        for k in range(9):
            t = k / 8
            fan.append((0.98 + 0.05 * math.sin(t * math.pi * 4), 0.46 - t * 0.92))
        fan = [(x * side, z) for x, z in fan]
        if side < 0:
            fan.reverse()
        pieces.append(puffy(fan, 0.06, F["lemon"], (0, 0, 0), "Wrapper", subsurf=2))
    return group(pieces, origin, scale)


def emblem_crystal(origin, scale):
    pieces = []
    for (x, z, height, radius, lean, color) in ((0, -0.55, 1.25, 0.24, 0, F["sky"]), (-0.34, -0.55, 0.8, 0.17, 24, "#c9a6ff"), (0.32, -0.55, 0.9, 0.18, -22, F["sky"])):
        mesh = bpy.data.meshes.new("Shard")
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=radius, radius2=radius, depth=height * 0.75, matrix=__import__("mathutils").Matrix.Translation((0, 0, height * 0.375)))
        bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=radius, radius2=0.0, depth=height * 0.25, matrix=__import__("mathutils").Matrix.Translation((0, 0, height * 0.875)))
        bm.to_mesh(mesh)
        bm.free()
        shard = link(bpy.data.objects.new("Shard", mesh))
        shard.location = (x, 0, z)
        shard.rotation_euler = (0, math.radians(lean), math.radians(30))
        bpy.context.view_layer.update()
        paint(shard, lambda point, color=color: linear(color))
        bevel = shard.modifiers.new("Bevel", "BEVEL")
        bevel.width = 0.02
        bevel.segments = 2
        pieces.append(finish(shard, smooth=False))
    return group(pieces, origin, scale)


def emblem_spiral(origin, scale):
    return group([spiral_sun(1.0)], origin, scale)


def emblem_gumdrop(origin, scale):
    build_gumdrop(origin, scale, ring=False)


EMBLEMS = {"spiral": emblem_spiral, "ring": emblem_ring, "gumdrop": emblem_gumdrop, "knot": emblem_knot, "cloud": emblem_cloud, "candy": emblem_candy, "crystal": emblem_crystal}


def build_emblems():
    """All seven world emblems as gummy collectibles: four over three."""
    camera.location = (0, -12.5, 0)
    layout = [("spiral", -2.55, 0.92, 1.05), ("ring", -0.85, 0.92, 0.95), ("gumdrop", 0.85, 0.82, 1.15), ("knot", 2.55, 0.92, 0.92),
              ("cloud", -1.95, -1.05, 1.0), ("candy", -0.05, -1.05, 0.88), ("crystal", 1.7, -0.9, 1.3)]
    for kind, x, z, scale in layout:
        EMBLEMS[kind]((x, 0, z), scale)


BUILDERS = {"companion": build_companion, "companion-happy": lambda: build_companion(mood="happy"), "orrery": build_orrery, "badge": build_badge, "bear": build_bear, "gumdrop": build_gumdrop, "pop": build_pop, "belt": build_belt, "emblems": build_emblems, **{f"emblem-{kind}": (lambda kind=kind: EMBLEMS[kind]((0, 0, 0), 1.6)) for kind in ("spiral", "ring", "gumdrop", "knot", "cloud", "candy", "crystal")}}


def plush_fuzz(objects):
    for obj in objects:
        if obj.type != "MESH" or obj.name.startswith(("Eye", "Stick")):
            continue
        system = obj.modifiers.new("Fuzz", "PARTICLE_SYSTEM").particle_system
        settings = system.settings
        settings.type = "HAIR"
        settings.count = 90000
        settings.hair_length = 0.04
        settings.child_type = "NONE"
        settings.root_radius = 0.0022
        settings.tip_radius = 0.0
        settings.use_advanced_hair = True
        settings.material = 1
        obj.data.materials.append(MATERIAL)


if args.shot == "diorama":
    camera.location = (0, -9.2, 1.4)
    camera.rotation_euler = (math.radians(82), 0, 0)
    camera_data.lens = 50
    camera_data.dof.use_dof = True
    camera_data.dof.focus_distance = 9.0
    camera_data.dof.aperture_fstop = 2.2
    floor_mesh = bpy.data.meshes.new("Floor")
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=30)
    bm.to_mesh(floor_mesh)
    bm.free()
    floor = link(bpy.data.objects.new("Floor", floor_mesh))
    floor.location = (0, 0, -1.25)
    floor_material = bpy.data.materials.new("Floor")
    floor_material.use_nodes = True
    shader = floor_material.node_tree.nodes["Principled BSDF"]
    shader.inputs["Base Color"].default_value = linear("#1a1036" if args.bg != "studio" else "#f3e6f4")
    shader.inputs["Roughness"].default_value = 0.12
    shader.inputs["Specular"].default_value = 0.6
    floor.data.materials.append(floor_material)
    build_orrery((0.0, 1.6, 0.55), 0.95)
    build_bear((-2.6, -0.4, -0.37), 0.85)
    build_gumdrop((2.55, -0.2, -0.75), 0.9)
    build_pop((-4.6, 2.6, 0.2), 0.8)
    build_belt((4.4, 2.8, 0.6), 0.7)
    build_companion((-1.25, 0.2, 1.75), 0.42, "happy")
else:
    BUILDERS[args.shot]()

if STYLE == "plush":
    plush_fuzz([obj for obj in scene.objects])

if args.save:
    bpy.ops.wm.save_as_mainfile(filepath=args.save)
elif args.frames:
    anchor = [obj for obj in scene.objects if obj.name.startswith("Group")][0]
    anchor.rotation_mode = "XYZ"
    scene.frame_start, scene.frame_end = 1, args.frames
    anchor.rotation_euler = (0, 0, 0)
    anchor.keyframe_insert("rotation_euler", frame=1)
    anchor.rotation_euler = (0, 0, math.tau)
    anchor.keyframe_insert("rotation_euler", frame=args.frames + 1)
    for curve in anchor.animation_data.action.fcurves:
        for point in curve.keyframe_points:
            point.interpolation = "LINEAR"
    scene.render.filepath = args.out
    bpy.ops.render.render(animation=True)
else:
    scene.render.filepath = args.out
    bpy.ops.render.render(write_still=True)
