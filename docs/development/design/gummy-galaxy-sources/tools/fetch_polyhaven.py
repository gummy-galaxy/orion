"""Downloads Poly Haven glTF models (1k textures) and HDRIs into assets/."""
import json
import os
import sys
import urllib.request

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")


def get_json(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "gummy-galaxy-concepts"})) as response:
        return json.load(response)


def download(url, path):
    if os.path.exists(path):
        return 0
    os.makedirs(os.path.dirname(path), exist_ok=True)
    urllib.request.urlretrieve(url, path)
    return os.path.getsize(path)


def model(asset_id, resolution="1k"):
    files = get_json(f"https://api.polyhaven.com/files/{asset_id}")
    entry = files["gltf"][resolution]["gltf"]
    folder = os.path.join(ROOT, "polyhaven", asset_id)
    total = download(entry["url"], os.path.join(folder, os.path.basename(entry["url"])))
    for relative, include in entry.get("include", {}).items():
        total += download(include["url"], os.path.join(folder, relative))
    return total


def hdri(asset_id, resolution="2k"):
    files = get_json(f"https://api.polyhaven.com/files/{asset_id}")
    entry = files["hdri"][resolution]["hdr"]
    return download(entry["url"], os.path.join(ROOT, "hdri", f"{asset_id}_{resolution}.hdr"))


if __name__ == "__main__":
    kind, *ids = sys.argv[1:]
    grand = 0
    for asset_id in ids:
        try:
            size = (model if kind == "model" else hdri)(asset_id)
            grand += size
            print(f"{asset_id}: {size / 1e6:.1f} MB")
        except Exception as error:
            print(f"{asset_id}: failed, {error}")
    print(f"total {grand / 1e6:.1f} MB")
