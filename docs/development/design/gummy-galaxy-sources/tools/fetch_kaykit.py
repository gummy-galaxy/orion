"""Downloads the KayKit kits the kitbash scenes use from their GitHub repositories into assets/kaykit/."""
import io
import json
import os
import urllib.request
import zipfile

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "kaykit")
KITS = ["KayKit-Space-Base-Bits-1.0", "KayKit-Medieval-Hexagon-Pack-1.0", "KayKit-Restaurant-Bits-1.0", "KayKit-Halloween-Bits-1.0", "KayKit-City-Builder-Bits-1.0"]


def get(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "gummy-galaxy-concepts"})) as response:
        return response.read()


if __name__ == "__main__":
    for kit in KITS:
        branch = json.loads(get(f"https://api.github.com/repos/KayKit-Game-Assets/{kit}"))["default_branch"]
        archive = get(f"https://codeload.github.com/KayKit-Game-Assets/{kit}/zip/refs/heads/{branch}")
        zipfile.ZipFile(io.BytesIO(archive)).extractall(os.path.join(ROOT, kit))
        print(f"{kit}: {len(archive) / 1e6:.1f} MB")
