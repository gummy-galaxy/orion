"""Assembles the concept gallery: finishes and resizes every piece into site/, and writes site/index.html."""
import json
import os

from PIL import Image

import treat
from worlds import WORLDS

HERE = os.path.dirname(os.path.abspath(__file__))
RENDERS = os.path.join(HERE, "..", "blender", "renders")
KIT = os.path.join(HERE, "..", "blender", "kit-renders")
SITE = os.path.join(HERE, "site")
os.makedirs(os.path.join(SITE, "img"), exist_ok=True)

VECTOR = "Hand-written SVG, rendered with Playwright"
CYCLES = "Blender 3.4 Cycles on Metal, film finish in Pillow"
RISO = "SVG, separated into spot inks with Pillow"
PIXEL = "Downscaled, Bayer-dithered to 14 colors with Pillow"
KITBASH = "Blender Cycles kitbash: CC0 Poly Haven and KayKit assets with the gummy marks"
TOON = "Blender EEVEE kitbash: KayKit space base, stepped toon ramp, Freestyle ink"
GC = "Blender Cycles, then a 480p 16-bit framebuffer pass in Pillow"

PIECES = [
    # Worlds
    ("galaxy-map.png", "Worlds", "Vector", "The Overworld", "World map", "Seven worlds on one orbit around the chewy spiral sun. Each stop on the dotted route is a world, and each world leaves an emblem behind.", VECTOR, ["map", "overworld", "game"], {"cover": True}),
]
for world in WORLDS:
    PIECES.append((f"world-{world['id']}.png", "Worlds", "Vector", world["name"], f"World {world['number']} · {world['orion']}", f"{world['idea']} Flavor: {world['flavor']}.", VECTOR, [world["id"], world["orion"].lower(), "environment"], {}))
PIECES += [
    ("platformer.png", "Worlds", "Vector", "Sugar Terraces, 3-2", "Gameplay mock", "Gumdrop Highlands as a side-scroller. Ready cards float as collectibles, dependency links are the bridges between platforms, and a finished card dims behind you.", VECTOR, ["gameplay", "hud", "ready-work"], {}),
    ("px-platformer.png", "Worlds", "Pixel", "Sugar Terraces, 16-bit", "Gameplay mock", "The same level pushed through a 320-pixel canvas and a 14-color palette, to see whether the world survives as a retro game.", PIXEL, ["pixel", "gameplay"], {}),
    ("px-swirlheart.png", "Worlds", "Pixel", "Swirlheart, 16-bit", "World 1 · Home", "The hub world as a pixel backdrop.", PIXEL, ["pixel", "swirlheart"], {}),
    ("px-noodle.png", "Worlds", "Pixel", "Noodle Reach, 16-bit", "World 4 · Dependencies", "The islands and licorice bridges at 300 pixels wide.", PIXEL, ["pixel", "noodle-reach"], {}),
    # Game era
    ("kit:monkeyball", "Game era", "3D", "Stage 1-1, Floating Course", "Kitbash · GameCube era", "Super Monkey Ball on Gummy Galaxy: a checkered course over the sky, wrapped candies for bananas, gumdrop bumpers, and the companion rolling inside a clear gummy ball toward the goal.", KITBASH, ["monkey-ball", "gamecube", "stage"], {}),
    ("gc:monkeyball", "Game era", "3D", "Stage 1-1, 480p", "Kitbash · GameCube era", "The same frame through a 640 by 400 framebuffer, 16-bit color with ordered dither, soft upscale, bloom, and faint field lines.", GC, ["gamecube", "480p", "dither"], {}),
    ("channel-menu.png", "Game era", "Vector", "Gummy Galaxy Channels", "Console menu", "The worlds as channels on a glossy white menu, plus Focus Music and a shop. The pointer hovers Gumdrop Highlands.", VECTOR, ["wii", "menu", "ui"], {}),
    ("microgames.png", "Game era", "Vector", "Microgames", "WarioWare-style", "Four-second games where every command is an Orion action: link two cards, sort the inbox, finish a card, unwrap what just arrived.", VECTOR, ["warioware", "microgames", "ui"], {}),
    # Kitbash
    ("kit:dessert", "Kitbash", "3D", "Gumdrop Highlands, Tabletop", "Photoreal miniature", "Scanned cakes, fruit, and a cutting board from Poly Haven become terrain. The companion stands on a strawberry cake with the spiral sun over it, shot at 70mm with shallow focus.", KITBASH, ["miniature", "photoreal", "tilt-shift"], {}),
    ("kit:garden", "Kitbash", "3D", "Pikmin Scale", "Photoreal garden", "The companion at two centimeters among scanned flowers at sunset, with a garden gnome as a distant giant.", KITBASH, ["pikmin", "macro", "scale"], {}),
    ("kit:moon", "Kitbash", "3D", "Geode Moon, Night", "Photoreal", "Scanned moon rocks, glowing gummy crystals, and Ringwell rising over the horizon.", KITBASH, ["geode-moon", "night"], {}),
    ("kit:hexboard", "Kitbash", "3D", "Gumdrop Highlands, Board", "Tabletop strategy", "A hex board from KayKit's medieval pack with apple and blueberry tiles, candy-shifted buildings, gumdrop hills, and the companion as a game piece. Orthographic.", KITBASH, ["hex", "board-game", "isometric"], {}),
    ("kit:planetoid", "Kitbash", "3D", "Walkable Planetoid", "Galaxy-style", "A gummy planet small enough to walk around in a minute, with KayKit buildings and trees planted along its surface.", KITBASH, ["planetoid", "mario-galaxy"], {}),
    ("kit:outpost", "Kitbash", "3D", "Taffy Belt Outpost", "Cel-shaded", "KayKit's space base, cel-shaded with Freestyle ink lines, under a sky of wrapped candy.", TOON, ["toon", "cel", "taffy-belt"], {}),
    ("kit:hollow", "Kitbash", "3D", "Licorice Hollow", "Volumetric night", "Noodle Reach at night: KayKit's Halloween kit shifted toward grape, lantern light through fog, and the linked-loops emblem over the gate.", "Blender EEVEE kitbash with volumetrics", ["noodle-reach", "night", "fog"], {}),
    ("paint:hollow", "Kitbash", "3D", "Licorice Hollow, Painted", "Painterly pass", "The same frame through a Kuwahara filter, which flattens it into brushy color blocks.", "Blender EEVEE, then ImageMagick Kuwahara", ["painterly", "kuwahara"], {}),
    # Emblems
    ("emblems-gummy-full-grape", "Emblems", "3D", "The Seven Emblems", "Collectibles", "Every world's symbol as a gummy you could pick up: the spiral sun, the ringed planet, the gumdrop, the linked loops, the cloud, the wrapped candy, and the rock-candy crystal.", CYCLES, ["emblems", "collectibles", "gummy"], {}),
    ("emblem-sheet.png", "Emblems", "Vector", "World Emblems", "Medals and marks", "Each emblem as a glossy medal in its world's flavor, with a one-color mark for small sizes. The caption maps each flavor to the Orion idea it stands for.", VECTOR, ["emblems", "system"], {}),
    ("riso-emblems.png", "Emblems", "Riso", "World Emblems, riso", "Print test", "The emblem sheet in pink, blue, and yellow spot inks, knocked slightly out of register.", RISO, ["riso", "emblems"], {}),
    ("emblem-knot-gummy-full-tide", "Emblems", "3D", "Linked Loops", "Noodle Reach · Dependencies", "Two gummy rings that really link. The dependency emblem: one thing holding onto another.", CYCLES, ["knot", "dependencies"], {}),
    ("emblem-candy-gummy-full-peach", "Emblems", "3D", "Wrapped Candy", "Taffy Belt · Inbox", "The inbox emblem: something that arrives wrapped, waiting to be opened and sorted.", CYCLES, ["candy", "inbox"], {}),
    ("emblem-crystal-gummy-full-grape", "Emblems", "3D", "Rock Candy", "Geode Moon · Done", "Finished work crystallizes. Faceted gummy, flat-shaded so the cuts catch the light.", CYCLES, ["crystal", "done"], {}),
    ("emblem-cloud-gummy-full-studio", "Emblems", "3D", "Cloud Puff", "Cotton Shoals · Notes", "Seven fused spheres, flattened. The notes emblem.", CYCLES, ["cloud", "notes"], {}),
    ("emblem-ring-gummy-full-tide", "Emblems", "3D", "Ringed Planet", "Ringwell · Groups", "A ring around a world. The groups emblem.", CYCLES, ["ring", "groups"], {}),
    # Companion
    ("model-sheet.png", "Companion", "Vector", "The Companion, Model Sheet", "Character", "Construction from CompanionStar.tsx, the proportions that matter, and nine expressions with poses: pip, happy, starstruck, surprised, wink, smitten, focused, idle, and blocked.", VECTOR, ["character", "expressions", "model-sheet"], {}),
    ("companion-gummy-pair-tide", "Companion", "3D", "Companion, Gummy", "Character", "The companion as a translucent gummy, two-flavor palette, under the shared scene light.", CYCLES, ["character", "gummy"], {"avatar": True}),
    ("trading-card.png", "Companion", "Vector", "Orion Star, 001/150", "Trading card", "A holo trading card. The moves are what the companion does in Orion: hop when a group finishes, and keep watch without interrupting.", VECTOR, ["card", "holo", "character"], {}),
    ("blueprint.png", "Companion", "Vector", "ORN-001 Companion", "Technical drawing", "Front and side elevations with the real proportions from the component: 182 tall, 104 wide, a 66 core, side stars at 0.45 scale.", VECTOR, ["blueprint", "spec"], {}),
    ("companion-happy-plush-full-studio", "Companion", "3D", "Companion, Plush", "Character", "The happy face in felt: sheen and a dense hair-particle fuzz.", CYCLES, ["character", "plush"], {}),
    ("companion-clay-full-peach", "Companion", "3D", "Companion, Clay", "Character", "The same rig in a matte clay pass on the peach backdrop.", CYCLES, ["character", "clay"], {}),
    ("stickers.png", "Companion", "Vector", "Sticker Sheet 01", "Merch", "Die-cut stickers with a morphology-filter border: three moods, a DONE burst, a ship-it banner, and the worlds' shapes.", VECTOR, ["stickers", "merch"], {}),
    ("neon.png", "Companion", "Vector", "Open Late", "Signage", "The companion as a neon sign on a brick wall, the silhouette stroked once as a union so the tube reads as one line.", VECTOR, ["neon", "signage"], {}),
    ("storybook.png", "Companion", "Vector", "The Last Card", "Storybook spread", "And when the last card was done, the little star did a hop. A picture-book page about finishing a group.", VECTOR, ["storybook", "done"], {}),
    ("storybook-riso.png", "Companion", "Riso", "The Last Card, riso", "Print test", "The storybook spread in pink and teal.", RISO, ["riso", "storybook"], {}),
    ("companion-pixel.png", "Companion", "Pixel", "Companion, 16-bit", "Sprite test", "The gummy render shrunk to a sprite and dithered.", PIXEL, ["pixel", "sprite"], {}),
    # Key art
    ("blair-poster.png", "Key art", "Vector", "A Confectionery of Worlds", "Poster", "Mid-century gouache in the spirit of Mary Blair: flat shapes, wobbly edges, paper grain, and the whole cast on one page.", VECTOR, ["poster", "gouache", "mid-century"], {}),
    ("deco-poster.png", "Key art", "Vector", "The Belt", "Travel poster", "An art deco travel poster for the Taffy Belt, with the companion as tour guide.", VECTOR, ["poster", "art-deco"], {}),
    ("woodblock.png", "Key art", "Vector", "Companion over the Gummy Sea", "Woodblock print", "Seigaiha waves, cloud bands, a spiral sun, and a vertical cartouche reading グミ銀河, Gummy Galaxy.", VECTOR, ["ukiyo-e", "print"], {}),
    ("wrapper.png", "Key art", "Vector", "Space Gummies", "Packaging", "A pillow-pack candy wrapper with the companion as mascot: six flavors, net weight one galaxy.", VECTOR, ["packaging", "retro"], {}),
    ("diorama-gummy-full-tide", "Key art", "3D", "The Shelf", "Diorama", "Every mark on one glossy floor with depth of field: the orrery, the bear, the gumdrop, the pop, the belt, and the companion overhead.", CYCLES, ["diorama", "gummy"], {}),
    ("diorama-clay-full-studio", "Key art", "3D", "The Shelf, Clay", "Diorama", "The same diorama as a white clay study.", CYCLES, ["diorama", "clay"], {}),
    # Materials
    ("orrery-gummy-full-tide", "Materials", "3D", "Orrery, Gummy", "Material study", "The spiral sun, its ring, a banded planet, and a moon, all six flavors.", CYCLES, ["orrery", "gummy"], {}),
    ("orrery-gummy-pair-grape", "Materials", "3D", "Orrery, Two Flavors", "Material study", "The two-flavor palette on grape.", CYCLES, ["orrery", "gummy"], {}),
    ("orrery-plastic-full-tide", "Materials", "3D", "Orrery, Glass", "Material study", "Full transmission. Reads as glass or acrylic rather than candy, which is the point of the comparison.", CYCLES, ["orrery", "glass"], {}),
    ("orrery-clay-full-studio", "Materials", "3D", "Orrery, Clay", "Material study", "Matte clay with fingerprint waves and lumps.", CYCLES, ["orrery", "clay"], {}),
    ("orrery-plush-full-peach", "Materials", "3D", "Orrery, Plush", "Material study", "Felt and fuzz on peach.", CYCLES, ["orrery", "plush"], {}),
    ("bear-gummy-full-grape", "Materials", "3D", "Gummy Bear", "Material study", "The classic, with a star on its belly.", CYCLES, ["bear", "gummy"], {}),
    ("gumdrop-gummy-full-tide", "Materials", "3D", "Sugared Gumdrop", "Material study", "Nine thousand instanced sugar crystals on a gumdrop with a ring.", CYCLES, ["gumdrop", "sugar"], {}),
    ("pop-hardcandy-full-peach", "Materials", "3D", "Swirl Pop", "Material study", "Hard candy: high transmission and clearcoat.", CYCLES, ["lollipop", "hard-candy"], {}),
    ("belt-gummy-full-grape", "Materials", "3D", "Candy Belt", "Material study", "Three puffy stars on a string.", CYCLES, ["belt", "gummy"], {}),
]


def publish_image(source, target_name, finish):
    target = os.path.join(SITE, "img", target_name)
    if finish:
        treat.film(source, target)
        source = target
    image = Image.open(source).convert("RGB")
    image.thumbnail((1600, 1600), Image.LANCZOS)
    image.save(target, quality=86, optimize=True, progressive=True)
    return image.size


entries, missing = [], []
for (name, section, medium, title, subject, about, tool, tags, flags) in PIECES:
    prefix, _, rest = name.partition(":")
    if rest:
        source = os.path.join(KIT, rest + ".png") if prefix == "kit" else os.path.join(KIT, f"{rest}-{prefix}.png")
        name = f"{prefix}-{rest}"
        is_render = prefix == "kit"
    else:
        is_render = not name.endswith(".png")
        source = os.path.join(RENDERS, name + ".png") if is_render else os.path.join(HERE, name)
    if not os.path.exists(source):
        missing.append(name)
        continue
    target_name = (name if is_render or rest else name[:-4]) + ".jpg"
    width, height = publish_image(source, target_name, is_render)
    entry = {"src": "img/" + target_name, "set": section, "medium": medium, "title": title, "subject": subject, "about": about, "tool": tool, "size": f"{width} × {height}", "tags": tags}
    entry.update(flags)
    entries.append(entry)

template = open(os.path.join(HERE, "index.src.html")).read()
open(os.path.join(SITE, "index.html"), "w").write(template.replace("/*PIECES*/[]", json.dumps(entries, ensure_ascii=False)))
print(len(entries), "pieces;", "missing:", ", ".join(missing) or "none")
