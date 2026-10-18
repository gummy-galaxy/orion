"""Kitbash concept scenes: CC0 kits (Poly Haven, KayKit) plus the gummy marks, each in a different art direction.

Run: Blender -b -P kitbash.py -- --scene dessert --out out.png [--width 1600 --height 1000 --samples 128]
"""
import argparse
import glob
import math
import os
import random
import sys

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(HERE, "..", "assets")
LIBRARY = os.path.join(HERE, "library")

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
parser = argparse.ArgumentParser()
parser.add_argument("--scene", default="dessert")
parser.add_argument("--out", default="/tmp/kitbash.png")
parser.add_argument("--width", type=int, default=1600)
parser.add_argument("--height", type=int, default=1000)
parser.add_argument("--samples", type=int, default=128)
args = parser.parse_args(argv)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
random.seed(7)


def linear(hex_color, alpha=1.0):
    values = [int(hex_color[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    return tuple(((v / 12.92) if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4) for v in values) + (alpha,)


def use_cycles(samples):
    scene.render.engine = "CYCLES"
    preferences = bpy.context.preferences.addons["cycles"].preferences
    preferences.compute_device_type = "METAL"
    preferences.get_devices()
    for device in preferences.devices:
        device.use = True
    scene.cycles.device = "GPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.cycles.max_bounces = 12
    scene.cycles.transparent_max_bounces = 64


def use_eevee():
    scene.render.engine = "BLENDER_EEVEE"
    scene.eevee.taa_render_samples = 64
    scene.eevee.use_gtao = True
    scene.eevee.use_bloom = True
    scene.eevee.use_soft_shadows = True
    scene.eevee.shadow_cube_size = "2048"
    scene.eevee.shadow_cascade_size = "4096"


def output(view="Filmic", look="Medium High Contrast", exposure=0.0):
    scene.render.resolution_x = args.width
    scene.render.resolution_y = args.height
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = view
    if view == "Filmic":
        scene.view_settings.look = look
    scene.view_settings.exposure = exposure
    scene.render.filepath = args.out


def world_hdri(name, strength=1.0, rotation=0.0, camera_color=None, camera_strength=1.0, camera_gradient=None):
    """Light from an HDRI; optionally show the camera a flat color instead."""
    world = bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    nodes, links = world.node_tree.nodes, world.node_tree.links
    nodes.clear()
    coord = nodes.new("ShaderNodeTexCoord")
    mapping = nodes.new("ShaderNodeMapping")
    mapping.inputs["Rotation"].default_value = (0, 0, rotation)
    environment = nodes.new("ShaderNodeTexEnvironment")
    environment.image = bpy.data.images.load(glob.glob(os.path.join(ASSETS, "hdri", name + "*.hdr"))[0])
    background = nodes.new("ShaderNodeBackground")
    background.inputs["Strength"].default_value = strength
    out = nodes.new("ShaderNodeOutputWorld")
    links.new(coord.outputs["Generated"], mapping.inputs["Vector"])
    links.new(mapping.outputs["Vector"], environment.inputs["Vector"])
    links.new(environment.outputs["Color"], background.inputs["Color"])
    final = background.outputs["Background"]
    if camera_color or camera_gradient:
        flat = nodes.new("ShaderNodeBackground")
        if camera_gradient:
            window = nodes.new("ShaderNodeTexCoord")
            split = nodes.new("ShaderNodeSeparateXYZ")
            ramp = nodes.new("ShaderNodeValToRGB")
            ramp.color_ramp.interpolation = "EASE"
            ramp.color_ramp.elements[0].color = linear(camera_gradient[1])
            ramp.color_ramp.elements[1].color = linear(camera_gradient[0])
            links.new(window.outputs["Window"], split.inputs[0])
            links.new(split.outputs["Y"], ramp.inputs["Fac"])
            links.new(ramp.outputs["Color"], flat.inputs["Color"])
        else:
            flat.inputs["Color"].default_value = linear(camera_color)
        flat.inputs["Strength"].default_value = camera_strength
        path = nodes.new("ShaderNodeLightPath")
        mix = nodes.new("ShaderNodeMixShader")
        links.new(path.outputs["Is Camera Ray"], mix.inputs["Fac"])
        links.new(background.outputs["Background"], mix.inputs[1])
        links.new(flat.outputs["Background"], mix.inputs[2])
        final = mix.outputs["Shader"]
    links.new(final, out.inputs["Surface"])
    return world


def world_gradient(top, bottom, strength=1.0):
    world = bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    nodes, links = world.node_tree.nodes, world.node_tree.links
    nodes.clear()
    coord = nodes.new("ShaderNodeTexCoord")
    separate = nodes.new("ShaderNodeSeparateXYZ")
    remap = nodes.new("ShaderNodeMapRange")
    remap.inputs["From Min"].default_value = -0.2
    remap.inputs["From Max"].default_value = 0.6
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = linear(bottom)
    ramp.color_ramp.elements[1].color = linear(top)
    background = nodes.new("ShaderNodeBackground")
    background.inputs["Strength"].default_value = strength
    out = nodes.new("ShaderNodeOutputWorld")
    links.new(coord.outputs["Generated"], separate.inputs[0])
    links.new(separate.outputs["Z"], remap.inputs["Value"])
    links.new(remap.outputs["Result"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], background.inputs["Color"])
    links.new(background.outputs["Background"], out.inputs["Surface"])


def camera(location, target, lens=50, focus=None, fstop=2.8, ortho=None):
    data = bpy.data.cameras.new("Camera")
    data.lens = lens
    data.clip_start = 0.01
    data.clip_end = 500
    if ortho:
        data.type = "ORTHO"
        data.ortho_scale = ortho
    obj = bpy.data.objects.new("Camera", data)
    scene.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (Vector(target) - Vector(location)).to_track_quat("-Z", "Y").to_euler()
    scene.camera = obj
    if focus is not None:
        data.dof.use_dof = True
        data.dof.focus_distance = focus if isinstance(focus, float) else (Vector(focus) - Vector(location)).length
        data.dof.aperture_fstop = fstop
    return obj


def light(kind, location, target, energy, color="#ffffff", size=1.0, angle=None):
    data = bpy.data.lights.new(kind, kind)
    data.energy = energy
    data.color = linear(color)[:3]
    if kind == "AREA":
        data.size = size
    if kind == "SUN" and angle is not None:
        data.angle = math.radians(angle)
    if kind in ("POINT", "SPOT"):
        data.shadow_soft_size = size
    obj = bpy.data.objects.new(kind, data)
    scene.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (Vector(target) - Vector(location)).to_track_quat("-Z", "Y").to_euler()
    return obj


def bounds(objects):
    points = [obj.matrix_world @ Vector(corner) for obj in objects if obj.type == "MESH" and not obj.hide_render for corner in obj.bound_box]
    low = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    high = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    return low, high


ANCHORS = []


def wrap(objects, location, size=None, height=None, rotation=0.0, sink=0.0, floating=False):
    """Parent loose objects under one empty, scale to a size, and stand them on `location`."""
    bpy.context.view_layer.update()
    anchor = bpy.data.objects.new("Piece", None)
    scene.collection.objects.link(anchor)
    low, high = bounds(objects)
    extent = high - low
    factor = 1.0
    if size:
        factor = size / max(extent.x, extent.y, extent.z)
    elif height:
        factor = height / extent.z
    pivot = Vector(((low.x + high.x) / 2, (low.y + high.y) / 2, low.z))
    for obj in objects:
        if obj.parent is None:
            obj.parent = anchor
            obj.matrix_parent_inverse = Matrix.Translation(-pivot)
    anchor.scale = (factor, factor, factor)
    anchor.rotation_euler = (0, 0, rotation)
    anchor.location = Vector(location) - Vector((0, 0, sink * factor))
    bpy.context.view_layer.update()
    ANCHORS.append((anchor, floating))
    return anchor


def footing(anchor):
    """The meshes a piece stands on: everything but rings, which hang below a gumdrop."""
    children = [obj for obj in anchor.children_recursive if obj.type == "MESH" and not obj.hide_render]
    solid = [obj for obj in children if not obj.name.startswith("Ring")]
    return solid or children


def settle(grounds, only=None, skip=(), sink=0.015):
    """Drop each standing piece onto the ground under it, sampling its footprint with downward rays."""
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    ground_names = {ground.name for ground in grounds}
    candidates = only if only is not None else [anchor for anchor, floating in ANCHORS if not floating]
    for anchor in candidates:
        try:
            anchor.name
        except ReferenceError:
            continue
        if anchor in skip:
            continue
        standing = footing(anchor)
        if not standing or any(obj.name in ground_names for obj in standing):
            continue
        low, high = bounds(standing)
        center_x, center_y = (low.x + high.x) / 2, (low.y + high.y) / 2
        reach_x, reach_y = (high.x - low.x) * 0.3, (high.y - low.y) * 0.3
        surface = None
        for offset_x, offset_y in ((0, 0), (reach_x, reach_y), (-reach_x, reach_y), (reach_x, -reach_y), (-reach_x, -reach_y)):
            origin = Vector((center_x + offset_x, center_y + offset_y, high.z + 50))
            for ground in grounds:
                inverse = ground.matrix_world.inverted()
                hit, location, _, _ = ground.ray_cast(inverse @ origin, (inverse.to_3x3() @ Vector((0, 0, -1))).normalized(), depsgraph=depsgraph)
                if hit:
                    height = (ground.matrix_world @ location).z
                    surface = height if surface is None else max(surface, height)
        if surface is None:
            continue
        anchor.location.z += surface - low.z - sink * (high.z - low.z)
        bpy.context.view_layer.update()


def gltf(path, location=(0, 0, 0), size=None, height=None, rotation=0.0, sink=0.0, floating=False):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    objects = [obj for obj in bpy.data.objects if obj not in before]
    return wrap(objects, location, size, height, rotation, sink, floating), objects


def polyhaven(asset_id, **placement):
    path = glob.glob(os.path.join(ASSETS, "polyhaven", asset_id, "*.gltf"))[0]
    return gltf(path, **placement)


KAYKIT = {}


def kaykit(name, **placement):
    if not KAYKIT:
        for path in glob.glob(os.path.join(ASSETS, "kaykit", "**", "*.gltf"), recursive=True):
            KAYKIT.setdefault(os.path.basename(path)[:-5], path)
    return gltf(KAYKIT[name], **placement)


def mark(name, location=(0, 0, 0), size=None, height=None, rotation=0.0, tilt=0.0, floating=False):
    """Append one of the gummy marks saved from gummy_scene.py."""
    with bpy.data.libraries.load(os.path.join(LIBRARY, name + ".blend")) as (source, target):
        target.objects = [obj_name for obj_name in source.objects]
    objects = [obj for obj in target.objects if obj is not None and obj.type not in ("CAMERA", "LIGHT")]
    for obj in objects:
        scene.collection.objects.link(obj)
    anchor = wrap(objects, location, size, height, rotation, floating=floating)
    anchor.rotation_euler = (tilt, 0, rotation)
    return anchor, objects


def meshes(objects):
    return [obj for obj in objects if obj.type == "MESH"]


def candify(objects, saturation=1.25, value=1.08, hue=0.5, sss=0.35, clearcoat=0.7):
    """Push a kit's materials toward candy: brighter, more saturated, a little subsurface and clearcoat."""
    seen = set()
    for obj in meshes(objects):
        for slot in obj.material_slots:
            material = slot.material
            if not material or material.name in seen or not material.use_nodes:
                continue
            seen.add(material.name)
            nodes, links = material.node_tree.nodes, material.node_tree.links
            shader = next((node for node in nodes if node.type == "BSDF_PRINCIPLED"), None)
            if not shader:
                continue
            adjust = nodes.new("ShaderNodeHueSaturation")
            adjust.inputs["Hue"].default_value = hue
            adjust.inputs["Saturation"].default_value = saturation
            adjust.inputs["Value"].default_value = value
            base = shader.inputs["Base Color"]
            if base.is_linked:
                source = base.links[0].from_socket
                links.new(source, adjust.inputs["Color"])
            else:
                adjust.inputs["Color"].default_value = base.default_value
            links.new(adjust.outputs["Color"], base)
            links.new(adjust.outputs["Color"], shader.inputs["Subsurface Color"])
            shader.inputs["Subsurface"].default_value = sss
            shader.inputs["Subsurface Radius"].default_value = (0.05, 0.03, 0.02)
            shader.inputs["Clearcoat"].default_value = clearcoat
            shader.inputs["Clearcoat Roughness"].default_value = 0.08
            shader.inputs["Roughness"].default_value = min(shader.inputs["Roughness"].default_value, 0.45)


def toonify(objects, steps=((0.0, 0.42), (0.32, 0.72), (0.62, 1.0)), rim="#ffffff"):
    """EEVEE cel shading: a stepped light ramp multiplied over each material's base color."""
    seen = set()
    for obj in meshes(objects):
        for slot in obj.material_slots:
            material = slot.material
            if not material or material.name in seen or not material.use_nodes:
                continue
            seen.add(material.name)
            nodes, links = material.node_tree.nodes, material.node_tree.links
            shader = next((node for node in nodes if node.type == "BSDF_PRINCIPLED"), None)
            out = next((node for node in nodes if node.type == "OUTPUT_MATERIAL"), None)
            if not shader or not out:
                continue
            base = shader.inputs["Base Color"]
            color_socket = base.links[0].from_socket if base.is_linked else None
            diffuse = nodes.new("ShaderNodeBsdfDiffuse")
            to_rgb = nodes.new("ShaderNodeShaderToRGB")
            ramp = nodes.new("ShaderNodeValToRGB")
            ramp.color_ramp.interpolation = "CONSTANT"
            elements = ramp.color_ramp.elements
            elements[0].position, elements[0].color = steps[0][0], (steps[0][1],) * 3 + (1,)
            elements[1].position, elements[1].color = steps[1][0], (steps[1][1],) * 3 + (1,)
            for position, level in steps[2:]:
                elements.new(position).color = (level,) * 3 + (1,)
            multiply = nodes.new("ShaderNodeMixRGB")
            multiply.blend_type = "MULTIPLY"
            multiply.inputs["Fac"].default_value = 1.0
            if color_socket:
                links.new(color_socket, multiply.inputs["Color2"])
            else:
                multiply.inputs["Color2"].default_value = base.default_value
            emission = nodes.new("ShaderNodeEmission")
            links.new(diffuse.outputs["BSDF"], to_rgb.inputs["Shader"])
            links.new(to_rgb.outputs["Color"], ramp.inputs["Fac"])
            links.new(ramp.outputs["Color"], multiply.inputs["Color1"])
            links.new(multiply.outputs["Color"], emission.inputs["Color"])
            links.new(emission.outputs["Emission"], out.inputs["Surface"])


def freestyle(thickness=2.0, color="#1a1240"):
    scene.render.use_freestyle = True
    scene.render.line_thickness_mode = "ABSOLUTE"
    scene.render.line_thickness = thickness
    settings = bpy.context.view_layer.freestyle_settings
    lineset = settings.linesets[0] if settings.linesets else settings.linesets.new("Lines")
    if lineset.linestyle is None:
        lineset.linestyle = bpy.data.linestyles.new("Ink")
    lineset.select_by_visibility = True
    lineset.select_silhouette = True
    lineset.select_border = True
    lineset.select_crease = True
    lineset.linestyle.color = linear(color)[:3]
    lineset.linestyle.thickness = thickness


def material(name, color, roughness=0.5, sss=0.0, emission=None, strength=0.0, transmission=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    shader = mat.node_tree.nodes["Principled BSDF"]
    shader.inputs["Base Color"].default_value = linear(color)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Subsurface"].default_value = sss
    shader.inputs["Subsurface Color"].default_value = linear(color)
    shader.inputs["Subsurface Radius"].default_value = (0.2, 0.1, 0.08)
    shader.inputs["Transmission"].default_value = transmission
    if emission:
        shader.inputs["Emission"].default_value = linear(emission)
        shader.inputs["Emission Strength"].default_value = strength
    return mat


def plane(size, location, mat, noise=None):
    bpy.ops.mesh.primitive_plane_add(size=size, location=location)
    obj = bpy.context.active_object
    obj.data.materials.append(mat)
    if noise:
        modifier = obj.modifiers.new("Subdivide", "SUBSURF")
        modifier.subdivision_type = "SIMPLE"
        modifier.levels = modifier.render_levels = 6
        texture = bpy.data.textures.new("Ground", "CLOUDS")
        texture.noise_scale = noise[0]
        displace = obj.modifiers.new("Displace", "DISPLACE")
        displace.texture = texture
        displace.strength = noise[1]
    return obj


def sphere(radius, location, mat, segments=96):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=location, segments=segments, ring_count=segments // 2)
    obj = bpy.context.active_object
    bpy.ops.object.shade_smooth()
    obj.data.materials.append(mat)
    return obj


def stars(count, radius, size, mat, seed=3):
    rng = random.Random(seed)
    for _ in range(count):
        direction = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.2, 1))).normalized()
        bpy.ops.mesh.primitive_ico_sphere_add(radius=size * rng.uniform(0.4, 1.2), subdivisions=1, location=direction * radius)
        bpy.context.active_object.data.materials.append(mat)


# ---------- Scenes ----------


def dessert():
    """Photoreal miniature: Gumdrop Highlands staged on a dessert table, macro lens and tilt-shift depth."""
    use_cycles(args.samples)
    world_hdri("christmas_photo_studio_01", 0.9, rotation=1.2)
    _, board = polyhaven("wooden_cutting_board", location=(0, 0, 0), size=0.62, rotation=math.radians(90))
    top = 0.018
    _, cake = polyhaven("strawberry_chocolate_cake", location=(0.06, 0.12, top), size=0.24)
    cake_top = bounds(meshes(cake))[1].z
    polyhaven("carrot_cake", location=(-0.17, 0.2, top), size=0.15, rotation=0.6)
    polyhaven("croissant", location=(0.2, -0.02, top), size=0.12, rotation=2.2)
    polyhaven("food_lychee_01", location=(-0.1, -0.08, top), size=0.035)
    polyhaven("food_kiwi_01", location=(-0.16, -0.02, top), size=0.05, rotation=1.0)
    polyhaven("lemon", location=(0.26, 0.2, top), size=0.07)
    polyhaven("tea_set_01", location=(0.05, 0.6, 0), size=0.45, rotation=-0.4)
    for index, (x, y, s) in enumerate(((-0.04, -0.12, 0.03), (0.0, -0.05, 0.022), (0.1, -0.1, 0.026), (-0.2, 0.06, 0.02), (0.14, 0.07, 0.018))):
        mark("emblem-gumdrop", location=(x, y, top), size=s, rotation=index)
    standing_companion, _ = mark("companion-happy", location=(0.05, 0.1, cake_top - 0.004), height=0.032, rotation=0.0)
    mark("emblem-spiral", location=(0.09, 0.16, cake_top + 0.05), size=0.04, tilt=0.0, floating=True)
    settle(meshes(board), skip={standing_companion})
    settle(meshes(cake), only=[standing_companion], sink=0.0)
    camera((0.02, -0.5, 0.2), (0.04, 0.08, 0.06), lens=70, focus=(0.05, 0.1, cake_top + 0.015), fstop=2.4)
    output("Filmic", "Medium High Contrast", 0.2)


def garden():
    """Pikmin scale: the companion among real flowers at sunset, a garden gnome as a distant giant."""
    use_cycles(args.samples)
    world_hdri("the_sky_is_on_fire", 1.2, rotation=2.4 + math.pi)
    soil = material("Soil", "#3d3322", 0.9)
    soil_plane = plane(6, (0, 0, 0), soil, noise=(0.08, 0.012))
    polyhaven("boulder_01", location=(0.14, 0.18, -0.004), size=0.12, rotation=0.6)
    polyhaven("moon_rock_02", location=(-0.16, 0.05, -0.004), size=0.06)
    rng = random.Random(4)
    for index in range(18):
        kind = ["flower_gazania", "shrub_01"][index % 2]
        x, y = rng.uniform(-0.45, 0.45), rng.uniform(0.0, 0.9)
        polyhaven(kind, location=(x, y, 0), height=rng.uniform(0.07, 0.2) if kind != "shrub_01" else rng.uniform(0.12, 0.22), rotation=rng.uniform(0, 6.28))
    polyhaven("garden_gnome", location=(0.3, 1.4, 0), height=0.9, rotation=-0.3)
    mark("companion", location=(-0.02, -0.02, 0.012), height=0.026, rotation=0.25)
    mark("emblem-cloud", location=(-0.1, 0.3, 0.16), size=0.06, floating=True)
    mark("emblem-gumdrop", location=(0.05, 0.05, 0.0), size=0.02)
    settle([soil_plane])
    camera((-0.05, -0.24, 0.035), (0.06, 0.3, 0.09), lens=24, focus=(-0.02, -0.02, 0.025), fstop=1.8)
    output("Filmic", "High Contrast", 0.0)


def moon():
    """Photoreal night: Geode Moon with scanned moon rocks and glowing gummy crystals."""
    use_cycles(args.samples)
    world_hdri("satara_night", 0.15, camera_color="#05061a", camera_strength=1.0)
    regolith = material("Regolith", "#4a4a5e", 0.95)
    ground = plane(40, (0, 0, 0), regolith, noise=(0.6, 0.12))
    rng = random.Random(9)
    for index in range(9):
        polyhaven(f"moon_rock_0{index % 5 + 1}", location=(rng.uniform(-3, 3), rng.uniform(0.5, 6), -0.05), size=rng.uniform(0.3, 1.4), rotation=rng.uniform(0, 6.28))
    glow = material("CrystalGlow", "#6aa8ff", 0.1, sss=0.6, emission="#4a90ff", strength=1.4, transmission=0.3)
    for index in range(7):
        _, crystal = mark("emblem-crystal", location=(rng.uniform(-1.6, 1.6), rng.uniform(0.6, 3), 0), height=rng.uniform(0.3, 0.9), rotation=rng.uniform(0, 6.28))
        for obj in meshes(crystal):
            obj.data.materials.clear()
            obj.data.materials.append(glow)
    mark("companion-happy", location=(0.1, 0.2, 0.05), height=0.35, rotation=-0.2)
    mark("emblem-ring", location=(-4, 34, 3.5), size=11, floating=True)
    settle([ground], sink=0.04)
    light("SUN", (5, -5, 6), (0, 0, 0), 0.7, "#c8d4ff", angle=1.5)
    light("POINT", (0.4, 1.2, 0.5), (0, 0, 0), 60, "#8fd0ff", size=0.3)
    stars(220, 80, 0.12, material("Star", "#ffffff", emission="#ffffff", strength=6))
    camera((0.0, -2.6, 0.55), (0.2, 1.5, 0.35), lens=35, focus=(0.1, 0.2, 0.25), fstop=2.0)
    output("Filmic", "High Contrast", 0.4)


def hex_tile_spacing(sample):
    low, high = bounds(meshes(sample))
    return high.x - low.x, high.y - low.y


def hexboard():
    """Tabletop strategy: a hex board of Gumdrop Highlands, candy-shifted KayKit pieces, orthographic."""
    use_cycles(args.samples)
    world_hdri("studio_small_09", 0.9, camera_color="#2a1a4a", camera_strength=1.0)
    anchor, sample = kaykit("hex_grass", location=(0, 0, 0))
    width, depth = hex_tile_spacing(sample)
    for obj in sample:
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.objects.remove(anchor, do_unlink=True)
    rng = random.Random(12)
    placed = []
    tiles = {}
    for q in range(-4, 5):
        for r in range(-4, 5):
            if abs(q + r) > 4:
                continue
            if depth > width:
                x, y = width * (q + r / 2), depth * 0.75 * r
            else:
                x, y = width * 0.75 * q, depth * (r + q / 2)
            distance = max(abs(q), abs(r), abs(q + r))
            kind = "hex_water" if distance == 4 and rng.random() < 0.6 else "hex_grass"
            tiles[(q, r)] = (x, y, kind)
    land_material = material("Apple", "#8fd66a", 0.35, sss=0.3)
    water_material = material("Blueberry", "#5aa4ff", 0.08, sss=0.2, transmission=0.4)
    board = []
    for (q, r), (x, y, kind) in tiles.items():
        _, objects = kaykit(kind, location=(x, y, 0))
        board += meshes(objects)
        for obj in meshes(objects):
            obj.data.materials.clear()
            obj.data.materials.append(water_material if kind == "hex_water" else land_material)
    features = ["building_windmill_green", "building_home_A_green", "building_market_green", "building_tavern_green", "trees_A_medium", "trees_B_large", "hills_A_trees", "mountain_A_grass_trees", "building_well_green", "building_castle_green"]
    land = [key for key, value in tiles.items() if value[2] == "hex_grass" and key != (0, 0)]
    rng.shuffle(land)
    for key, feature in zip(land, features):
        x, y, _ = tiles[key]
        _, objects = kaykit(feature, location=(x, y, 0.2), height=width * (0.95 if "building" in feature else 0.6), rotation=rng.choice((0, 1.05, 2.1)))
        placed += objects
    if os.environ.get("CANDY", "1") == "1":
        candify(placed, saturation=1.35, value=1.12)
    for key in land[len(features):len(features) + 6]:
        x, y, _ = tiles[key]
        mark("emblem-gumdrop", location=(x, y, 0.2), size=width * 0.45, rotation=rng.uniform(0, 6))
    mark("companion-happy", location=(0, 0, 0.2), height=width * 0.8)
    mark("emblem-gumdrop" if os.path.exists(os.path.join(LIBRARY, "emblem-gumdrop.blend")) else "emblem-spiral", location=(width * 1.5, depth * 3.4, 1.4 * width), size=width * 0.9, floating=True)
    settle(board, sink=0.0)
    light("SUN", (6, -8, 10), (0, 0, 0), 4.0, "#fff1d6", angle=3)
    size = width * 11
    camera((size, -size, size * 0.95), (0, 0, 0), ortho=size * 0.95)
    output("Filmic", "Medium High Contrast", 0.1)


def planetoid():
    """Mario Galaxy: a gummy planetoid you could walk around, with KayKit buildings planted on its surface."""
    use_cycles(args.samples)
    world_hdri("kloppenheim_06_puresky", 0.6, camera_color="#0b0a2a", camera_strength=1.0)
    radius = 2.0
    sphere(radius, (0, 0, 0), material("Planet", "#7be14a", 0.35, sss=0.4))
    rng = random.Random(21)
    pieces = ["building_windmill_green", "building_home_A_green", "building_home_B_green", "building_church_green", "trees_A_medium", "trees_B_large", "trees_A_small", "tree_single_A", "tree_single_B", "building_well_green", "flag_green", "building_tower_A_green", "building_market_green"]
    placed = []
    golden = math.pi * (3 - math.sqrt(5))
    count = 110
    for index in range(count):
        z = 1 - (index + 0.5) / count * 1.25
        ring = math.sqrt(max(0.0, 1 - z * z))
        theta = golden * index
        normal = Vector((math.cos(theta) * ring, math.sin(theta) * ring, z)).normalized()
        if normal.y > 0.55:
            continue
        name = pieces[index % len(pieces)]
        anchor, objects = kaykit(name, location=(0, 0, 0), height=rng.uniform(0.22, 0.45) if "building" in name else rng.uniform(0.14, 0.3), rotation=rng.uniform(0, 6.28))
        rotation = normal.to_track_quat("Z", "Y")
        anchor.matrix_world = Matrix.Translation(normal * (radius - 0.01)) @ rotation.to_matrix().to_4x4() @ Matrix.Rotation(rng.uniform(0, 6.28), 4, "Z") @ Matrix.Diagonal(anchor.scale.to_4d())
        placed += objects
    candify(placed, saturation=1.3, value=1.1)
    for index in range(10):
        direction = Vector((rng.uniform(-1, 1), rng.uniform(-1, 0.3), rng.uniform(-0.6, 1))).normalized()
        anchor, _ = mark("emblem-gumdrop", location=(0, 0, 0), size=0.2)
        anchor.matrix_world = Matrix.Translation(direction * (radius - 0.02)) @ direction.to_track_quat("Z", "Y").to_matrix().to_4x4() @ Matrix.Diagonal(anchor.scale.to_4d())
    top = Vector((0.15, -0.35, 1.0)).normalized()
    anchor, _ = mark("companion-happy", location=(0, 0, 0), height=0.8)
    anchor.matrix_world = Matrix.Translation(top * (radius + 0.02)) @ top.to_track_quat("Z", "Y").to_matrix().to_4x4() @ Matrix.Diagonal(anchor.scale.to_4d())
    ring = mark("emblem-ring", location=(5.5, 9, 3.2), size=3.2)
    mark("emblem-spiral", location=(-6.5, 12, 4.5), size=4)
    stars(260, 60, 0.1, material("Star", "#ffffff", emission="#fff6ea", strength=8))
    light("SUN", (-6, -6, 8), (0, 0, 0), 4.0, "#fff1d6", angle=2)
    light("AREA", (6, 4, -2), (0, 0, 0), 900, "#ff8fd0", size=6)
    camera((2.2, -10.5, 3.6), (0, 0, 0.5), lens=45)
    output("Filmic", "Medium High Contrast", 0.2)


def outpost():
    """Cel shading: a Taffy Belt mining outpost from KayKit's space base, inked with Freestyle."""
    use_eevee()
    world_gradient("#ffb0d8", "#ffe6c8", 1.0)
    placed = []
    layout = [("terrain_low", 0, 0), ("terrain_low", 2, 0), ("terrain_low", -2, 0), ("terrain_low", 0, 2), ("terrain_low", 2, 2), ("terrain_low", -2, 2), ("terrain_tall", -2, 4), ("terrain_tall", 0, 4), ("terrain_low", 2, 4), ("terrain_mining", 4, 2), ("terrain_low", 4, 0), ("terrain_low", -4, 0), ("terrain_low", -4, 2), ("terrain_tall", 4, 4), ("terrain_low", 0, -2), ("terrain_low", 2, -2), ("terrain_low", -2, -2)]
    terrain = []
    for name, x, y in layout:
        _, objects = kaykit(name, location=(x, y, 0), size=2.0)
        placed += objects
        terrain += meshes(objects)
    for name, x, y, size, rotation in (("basemodule_A", -1.6, 1.6, 1.6, 0), ("basemodule_C", 0.4, 2.2, 1.4, 1.57), ("lander_A", 2.4, -0.4, 1.8, 0.4), ("landingpad_large", 2.4, -0.4, 2.2, 0), ("cargodepot_A", -2.6, -0.8, 1.4, 0.7), ("drill_structure", 4, 2.2, 2.2, 0.2), ("windturbine_tall", -3.6, 3.2, 2.8, 0), ("spacetruck", 0.6, -1.4, 1.1, 2.4), ("containers_B", -0.8, -1.8, 0.9, 0.3), ("solarpanel", 1.8, 3.4, 1.0, 0.2), ("rocks_A", 3.6, -1.6, 1.0, 0)):
        _, objects = kaykit(name, location=(x, y, 0.5), size=size, rotation=rotation)
        placed += objects
    candies = []
    for index in range(9):
        _, objects = mark("emblem-candy", location=(random.uniform(-6, 6), random.uniform(6, 14), random.uniform(1.5, 6)), size=random.uniform(0.6, 1.6), rotation=random.uniform(0, 6.28), tilt=random.uniform(-0.6, 0.6), floating=True)
        candies += objects
    _, companion = mark("companion-happy", location=(-0.6, 0.0, 0.5), height=0.9)
    settle(terrain, sink=0.0)
    toonify(placed + candies + companion)
    light("SUN", (-5, -8, 10), (0, 0, 0), 4.0, "#ffffff", angle=1)
    freestyle(1.6, "#2a1030")
    camera((8.8, -11.5, 7.8), (0, 1.8, 1.0), lens=36)
    output("Standard", exposure=0.0)


def hollow():
    """Painterly night: Licorice Hollow in Noodle Reach, lanterns and fog, finished later with a Kuwahara filter."""
    use_eevee()
    scene.eevee.use_volumetric_lights = True
    scene.eevee.volumetric_tile_size = "4"
    world_gradient("#2b1060", "#0d0626", 0.6)
    fog = bpy.data.worlds["World"].node_tree.nodes.new("ShaderNodeVolumePrincipled")
    fog.inputs["Density"].default_value = 0.035
    fog.inputs["Color"].default_value = linear("#b48cff")
    bpy.data.worlds["World"].node_tree.links.new(fog.outputs["Volume"], bpy.data.worlds["World"].node_tree.nodes["World Output"].inputs["Volume"])
    ground = plane(60, (0, 0, 0), material("Licorice", "#2a1438", 0.6), noise=(1.5, 0.15))
    placed = []
    for name, x, y, size, rotation in (("crypt", 0, 4.5, 3.2, 0), ("arch_gate", 0, 1.8, 2.4, 0), ("tree_dead_large_decorated", -3.2, 3.5, 3.6, 0.4), ("tree_dead_medium", 3.4, 4.8, 2.8, 2), ("tree_pine_orange_large", 5.5, 8, 4, 0), ("tree_pine_yellow_medium", -5.4, 7.5, 3, 0), ("lantern_standing", -1.6, 1.4, 1.2, 0), ("lantern_standing", 1.6, 1.4, 1.2, 0), ("post_lantern", -2.8, -0.4, 1.4, 0), ("pumpkin_orange_jackolantern", 2.2, -0.2, 0.5, 2.6), ("pumpkin_yellow", 2.8, 0.5, 0.4, 0), ("fence", -4, 1.5, 2, 0), ("fence", 4, 1.5, 2, 0), ("shrine_candles", -2.4, 3.0, 1.0, 0.5), ("bench_decorated", 3.0, 2.8, 1.2, -0.6)):
        _, objects = kaykit(name, location=(x, y, 0), size=size, rotation=rotation)
        placed += objects
    candify(placed, saturation=1.2, value=1.0, hue=0.62)
    _, knot = mark("emblem-knot", location=(0, 1.8, 2.2), size=0.9, floating=True)
    _, companion = mark("companion", location=(0.2, -0.6, 0.0), height=0.8, rotation=0.2)
    settle([ground], sink=0.03)
    for x, y, z in ((-1.6, 1.4, 1.1), (1.6, 1.4, 1.1), (-2.8, -0.4, 1.3), (2.2, -0.2, 0.3), (0, 4.0, 1.5), (-2.4, 3.0, 0.8)):
        light("POINT", (x, y, z), (0, 0, 0), 120, "#ffb347", size=0.2)
    light("SUN", (6, 10, 8), (0, 0, 0), 1.2, "#8fb0ff", angle=2)
    light("POINT", (0.2, -1.4, 1.2), (0, 0, 0), 60, "#ff8fd0", size=0.4)
    camera((1.2, -5.8, 1.6), (0, 2.5, 1.2), lens=32)
    output("Filmic", "High Contrast", 0.5)


def checker_material(name, first, second, edge, scale=1.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    shader = nodes["Principled BSDF"]
    coord = nodes.new("ShaderNodeTexCoord")
    mapping = nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (scale, scale, scale)
    checker = nodes.new("ShaderNodeTexChecker")
    checker.inputs["Color1"].default_value = linear(first)
    checker.inputs["Color2"].default_value = linear(second)
    checker.inputs["Scale"].default_value = 1.0
    links.new(coord.outputs["Object"], mapping.inputs["Vector"])
    links.new(mapping.outputs["Vector"], checker.inputs["Vector"])
    # Faces pointing sideways get the edge color, like a stage's painted rim.
    geometry = nodes.new("ShaderNodeNewGeometry")
    separate = nodes.new("ShaderNodeSeparateXYZ")
    up = nodes.new("ShaderNodeMath")
    up.operation = "GREATER_THAN"
    up.inputs[1].default_value = 0.7
    mix = nodes.new("ShaderNodeMixRGB")
    mix.inputs["Color1"].default_value = linear(edge)
    links.new(geometry.outputs["Normal"], separate.inputs[0])
    links.new(separate.outputs["Z"], up.inputs[0])
    links.new(up.outputs["Value"], mix.inputs["Fac"])
    links.new(checker.outputs["Color"], mix.inputs["Color2"])
    links.new(mix.outputs["Color"], shader.inputs["Base Color"])
    shader.inputs["Roughness"].default_value = 0.22
    shader.inputs["Clearcoat"].default_value = 0.6
    return mat


def slab(location, size, rotation, mat, bevel=0.08):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.active_object
    obj.scale = size
    obj.rotation_euler = rotation
    bpy.ops.object.transform_apply(scale=True)
    modifier = obj.modifiers.new("Bevel", "BEVEL")
    modifier.width = bevel
    modifier.segments = 3
    obj.data.materials.append(mat)
    return obj


def monkeyball():
    """GameCube floating stage: a checkered course over the sky, the companion rolling inside a gummy ball."""
    use_cycles(args.samples)
    world_hdri("kloppenheim_06_puresky", 1.3, rotation=0.6, camera_gradient=("#1f6fff", "#bfe6ff"))
    deck = checker_material("Deck", "#ff8fd0", "#fff2f8", "#ffd84a", 0.9)
    alt = checker_material("DeckBlue", "#5aa4ff", "#eaf4ff", "#ffd84a", 0.9)
    slab((0, 0, -0.25), (4, 4, 0.5), (0, 0, 0), deck)
    slab((0, 6, -0.25), (2.4, 8, 0.5), (0, 0, 0), deck)
    slab((0, 10.6, 0.35), (2.4, 3.4, 0.5), (math.radians(-20), 0, 0), alt)
    slab((0, 14.2, 0.95), (6, 4.4, 0.5), (0, 0, 0), alt)
    slab((-3.2, 18.2, 0.95), (1.0, 6, 0.5), (0, 0, math.radians(-25)), deck)
    slab((-5.6, 23.4, 0.95), (5, 5, 0.5), (0, 0, 0), deck)
    rail = material("Rail", "#ffd84a", 0.25)
    for x in (-1.22, 1.22):
        slab((x, 6, 0.08), (0.12, 8, 0.18), (0, 0, 0), rail, 0.04)
    # The goal: a gate with a banner and a ribbon to break.
    gate = material("Gate", "#ff3d6e", 0.25)
    slab((-7.2, 24.4, 2.3), (0.35, 0.35, 2.4), (0, 0, 0), gate)
    slab((-4.0, 24.4, 2.3), (0.35, 0.35, 2.4), (0, 0, 0), gate)
    slab((-5.6, 24.4, 3.7), (3.9, 0.45, 0.7), (0, 0, 0), gate)
    bpy.ops.object.text_add(location=(-5.6, 24.12, 3.42))
    text = bpy.context.active_object
    text.data.body = "GOAL"
    text.data.align_x = "CENTER"
    text.data.size = 0.62
    text.data.extrude = 0.04
    text.rotation_euler = (math.radians(90), 0, 0)
    text.data.materials.append(material("GoalText", "#fff6ea", 0.3, emission="#fff6ea", strength=0.6))
    slab((-5.6, 24.4, 1.35), (3.0, 0.04, 0.08), (0, 0, 0), material("Tape", "#ffffff", 0.4), 0.01)
    # Wrapped candies stand in for bananas, bumpers are gumdrops.
    for x, y, z in ((0, 3.2, 0.5), (0.5, 5.2, 0.5), (-0.4, 7.4, 0.5), (0, 9.0, 0.6), (1.6, 14, 1.75), (-1.6, 14.6, 1.75), (-4.6, 21.5, 1.75), (-6.4, 22.3, 1.75)):
        mark("emblem-candy", location=(x, y, z), size=0.55, rotation=random.uniform(0, 6.28), tilt=0.3)
    for x, y in ((2.1, 13.2), (-2.2, 13.0), (0.2, 15.6)):
        mark("emblem-gumdrop", location=(x, y, 1.2), size=0.9)
    # The player: the companion inside a clear gummy ball.
    ball = sphere(0.62, (0, -0.4, 0.62), material("Ball", "#ffe6f4", 0.02, transmission=1.0))
    ball.data.materials[0].node_tree.nodes["Principled BSDF"].inputs["IOR"].default_value = 1.25
    mark("companion-happy", location=(0, -0.4, 0.22), height=0.82)
    # Far islands and clouds give the drop below some depth.
    for name, x, y, z, size in (("cloud_big", -9, 14, -3, 6), ("cloud_big", 8, 22, -1, 7), ("cloud_small", 6, 6, -4, 3), ("cloud_big", -2, 34, 4, 8)):
        kaykit(name, location=(x, y, z), size=size)
    planet = mark("orrery", location=(10, 42, 9), size=12)
    light("SUN", (-6, -10, 12), (0, 6, 0), 3.5, "#fff4dc", angle=2)
    camera((0, -6.2, 3.1), (0, 4, 0.4), lens=30)
    output("Filmic", "Medium High Contrast", 0.15)


SCENES = {"dessert": dessert, "garden": garden, "moon": moon, "hexboard": hexboard, "planetoid": planetoid, "outpost": outpost, "hollow": hollow, "monkeyball": monkeyball}
SCENES[args.scene]()
bpy.ops.render.render(write_still=True)
