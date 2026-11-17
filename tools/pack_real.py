#!/usr/bin/env python3
"""把 image job 解包出的 macOS 27.2 真实产物装箱成 DroidVM 可导入的 .vmpkg。

相对 make_vmpkg.py 的关键修正：
- 构建仓的 manifest.json 是「产品清单」(product/tag/kc/trusted/boot_img...)，
  不是 vmpkg 导入清单。本脚本按 PackageManifest 权威格式**重新构造**导入清单，
  而不是把产品清单当导入清单用（那样 App 不认）。
- 文件映射来自 image.yml 实际打进 image.tar 的 6 个文件：
  boot.img / manifest.json / kernel.macho.trustcache / data-store.img /
  scratch-data.img / disk.json。磁盘镜像进 disks[]，引导文件进 boots[]。

用法：
  python3 pack_real.py --srcdir <ci-blob.sh unpack 后的目录> --output system.vmpkg
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
PACK = HERE / "pack_vmpkg.py"
VERIFY = HERE / "verify_vmpkg.py"

# image.tar 里除 manifest.json 外的真实文件；按 DroidVM 角色归类
DISK_FILES = ["data-store.img", "scratch-data.img"]
BOOT_FILES = [
    ("boot.img", "boot.img", "uefi"),
    # FIX: kernel.macho.trustcache is a Mach-O code-signing trust cache, NOT a
    # loadable kernel image. Marking it kind="kernel" makes crosvm try to load
    # it via --kernel -> "invalid magic number" -> VM exits code 1.
    # macOS is booted purely by boot.img (UEFI/DarwinBoot); no separate kernel.
]


def sha256_of(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def build(srcdir: Path, output: Path, compression: str, vm_name: str) -> int:
    product = {}
    pman = srcdir / "manifest.json"
    if pman.is_file():
        product = json.loads(pman.read_bytes())

    disks, boots, entries = [], [], []
    for i, name in enumerate(DISK_FILES):
        p = srcdir / name
        if not p.is_file():
            print(f"缺少磁盘文件: {p}", file=sys.stderr)
            return 2
        size = p.stat().st_size
        if size == 0:
            continue
        print(f"[hash] {name} ({size} bytes)...", flush=True)
        disks.append({
            "archive_path": name,
            "name": name,
            "path": "/" if i == 0 else f"/{name}",
            "size": size,
            "index": i,
            "readonly": False,
            "bus": "virtio",
            "format": "raw",
            "attached": True,
            "sha256": sha256_of(p),
        })
        entries.append(name)

    for src, name, kind in BOOT_FILES:
        p = srcdir / src
        if not p.is_file():
            print(f"缺少引导文件: {p}", file=sys.stderr)
            return 2
        size = p.stat().st_size
        if size == 0:
            continue
        print(f"[hash] {src} ({size} bytes)...", flush=True)
        boots.append({
            "archive_path": name,
            "name": name,
            "path": name,
            "kind": kind,
            "size": size,
            "sha256": sha256_of(p),
        })
        entries.append(src)

    if not any(d["size"] for d in disks):
        print("没有非空磁盘", file=sys.stderr)
        return 2

    vmpkg_manifest = {
        "manifest_version": 1,
        "format": "vmpkg",
        "created_at": int(time.time() * 1000),
        "app_version": "1.0",
        "app_version_code": 100,
        "app_build_type": "release",
        "compression": compression,
        "vm": {"name": vm_name or "macOS 27.2", "extra_options": []},
        "disks": disks,
        "boots": boots,
        "networks": [],
    }
    mpath = srcdir / "vmpkg-manifest.generated.json"
    mpath.write_text(json.dumps(vmpkg_manifest, ensure_ascii=False, indent=1))

    srcmap = {}
    for ap, src in zip([d["archive_path"] for d in disks] + [b["archive_path"] for b in boots],
                       [d["archive_path"] for d in disks] + [b["archive_path"] for b in boots]):
        srcmap[ap] = str((srcdir / src).resolve())
    spath = srcdir / "vmpkg-sourcemap.generated.json"
    spath.write_text(json.dumps(srcmap, ensure_ascii=False, indent=1))

    print(f"[manifest] {mpath}")
    print(json.dumps(vmpkg_manifest, ensure_ascii=False, indent=1))

    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        output.unlink()
    print(f"[pack] -> {output}", flush=True)
    import subprocess
    r = subprocess.run([sys.executable, str(PACK), "--manifest", str(mpath),
                        "--sources", str(spath), "--output", str(output),
                        "--compression", compression], text=True)
    if r.returncode != 0:
        return r.returncode

    print("[verify] ...", flush=True)
    v = subprocess.run([sys.executable, str(VERIFY), "--package", str(output)], text=True)
    if v.returncode != 0:
        return v.returncode
    gb = output.stat().st_size / (1024 ** 3)
    print(f"\n完成: {output} ({gb:.2f} GB)")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--srcdir", required=True)
    ap.add_argument("--output", required=True)
    ap.add_argument("--compression", default="gzip", choices=("gzip", "none"))
    ap.add_argument("--vm-name", default="macOS 27.2")
    a = ap.parse_args()
    return build(Path(a.srcdir).resolve(), Path(a.output).resolve(), a.compression, a.vm_name)


if __name__ == "__main__":
    raise SystemExit(main())
