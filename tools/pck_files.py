#!/usr/bin/env python3
"""Lists the files inside a Godot 4 PCK (formats 2-4) with sizes and SHA-256s.

  pck_files.py <pack.pck>                 list every file
  pck_files.py <pack.pck> --require-baked fail unless the shader baker's caches are inside
                                          (engine core shaders and the scene/material shaders)
  pck_files.py <a.pck> --diff <b.pck>     files that differ between two packs
"""
import hashlib, struct, sys


def read(path):
    b = open(path, "rb").read()
    if b[:4] != b"GDPC":
        sys.exit(f"{path}: not a Godot pack")
    fmt = struct.unpack_from("<I", b, 4)[0]
    base = struct.unpack_from("<Q", b, 24)[0]
    diroff = struct.unpack_from("<Q", b, 32)[0] if fmt >= 3 else 32 + 16 * 4
    n = struct.unpack_from("<I", b, diroff)[0]
    o = diroff + 4
    files = {}
    for _ in range(n):
        ln = struct.unpack_from("<I", b, o)[0]
        o += 4
        p = b[o:o + ln].rstrip(b"\0").decode()
        o += ln
        off, size = struct.unpack_from("<QQ", b, o)
        o += 16 + 16 + 4  # offset/size, md5, flags
        files[p] = (size, hashlib.sha256(b[base + off:base + off + size]).hexdigest())
    return files


def main():
    files = read(sys.argv[1])
    if "--require-baked" in sys.argv:
        baked = [p for p in files if p.startswith(".godot/shader_cache/")]
        scene = [p for p in baked if "/SceneForwardMobileShaderRD/" in p]
        print(f"baked shader caches: {len(baked)} (scene/material: {len(scene)})")
        if len(baked) < 30 or not scene:
            sys.exit("FAIL: the shader baker's caches are missing from this pack")
        print("baked shaders present")
    elif "--diff" in sys.argv:
        other = read(sys.argv[sys.argv.index("--diff") + 1])
        for p in sorted(set(files) | set(other)):
            if files.get(p, (None, None))[1] != other.get(p, (None, None))[1]:
                print(p)
    else:
        for p, (size, sha) in sorted(files.items()):
            print(f"{size:10d}  {sha}  {p}")


if __name__ == "__main__":
    main()
