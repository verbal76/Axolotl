#!/usr/bin/env python3
"""One coordinated build interface for Mote (studio standard §5-§8; docs/RELEASES.md).

  build.py build --platform linux|windows|all-desktop --sha SHA --build N [--out DIR]
      Exports the game at exactly SHA (refuses a dirty tree or another checkout) for the desktop
      platform(s) and packages them as "Mote Build N Linux.tar.gz" / "Mote Build N EXE.zip"
      (executable, THIRD_PARTY_NOTICES.txt, README.txt). The export preset is added to
      export_presets.cfg for the export only and the file is restored: it belongs to the Android
      runtime lock. Needs Godot (GODOT, default `godot`) and its export templates.
  build.py apk --apk FILE --build-info FILE --sha SHA --build N [--out DIR]
      Takes a verified APK from Build & Verify (its build-info.json: sha256, source_sha,
      android_build) and names it "Mote Build N APK.apk" after checking that it is the same source
      and build number.
  build.py manifest --dir DIR --sha SHA --build N
      Writes build-manifest.json and checksums.sha256 for every "Mote Build N ..." artifact in DIR,
      then verifies them against the files (exit 1 on any mismatch).
  build.py verify --dir DIR
      Re-verifies a manifest and checksums against the files.

The logical commands of the standard map to: android = Build & Verify (APK, needs the signing
secrets) + `apk`; windows / linux = `build`; all = both, from one SHA, then `manifest`.
"""
import argparse, datetime, hashlib, json, os, pathlib, re, shutil, subprocess, sys, tarfile, tempfile, zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
TITLE = "Mote"
PRESETS = ROOT / "export_presets.cfg"
EXCLUDE = "tools/*, assets/icon/icon_source.png, assets/icon/icon_1024.png, assets/icon/icon_adaptive_*, assets/glyphs/README.md"
DESKTOP = {
    "linux": {"preset": "Linux", "platform": "Linux", "exe": "Mote.x86_64", "kind": "Linux", "ext": ".tar.gz",
              "options": {"binary_format/embed_pck": "true", "binary_format/architecture": '"x86_64"',
                          "texture_format/s3tc_bptc": "true", "texture_format/etc2_astc": "false"}},
    "windows": {"preset": "Windows Desktop", "platform": "Windows Desktop", "exe": "Mote.exe", "kind": "EXE", "ext": ".zip",
                "options": {"binary_format/embed_pck": "true", "binary_format/architecture": '"x86_64"',
                            "texture_format/s3tc_bptc": "true", "texture_format/etc2_astc": "false",
                            "application/product_name": '"Mote"', "application/company_name": '"Hot Attic Games"',
                            "application/modify_resources": "false"}},
}


def artifact_name(build: int, kind: str, ext: str) -> str:
    return f"{TITLE} Build {build} {kind}{ext}"


def git(*args) -> str:
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True, check=True).stdout.strip()


def sha256(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def engine_version() -> str:
    m = re.search(r"GODOT_VERSION:\s*([0-9.]+)", (ROOT / ".github/workflows/build.yml").read_text())
    return m.group(1)


def runtime_revision() -> str:
    m = re.search(r"const RUNTIME_REVISION := (\d+)", (ROOT / "scripts/boot/ota_config.gd").read_text())
    return f"r{m.group(1)}"


def check_source(sha: str) -> str:
    """The checkout must be exactly SHA with nothing uncommitted (no unrecorded local source)."""
    head = git("rev-parse", "HEAD")
    want = git("rev-parse", sha + "^{commit}")
    if head != want:
        sys.exit(f"refused: checkout is {head[:12]}, requested {want[:12]} (check out the exact commit)")
    dirty = git("status", "--porcelain", "--untracked-files=no")
    if dirty:
        sys.exit("refused: uncommitted changes in the checkout:\n" + dirty)
    return want


def preset_block(index: int, spec: dict, export_path: str) -> str:
    lines = ["", f"[preset.{index}]", "", f'name="{spec["preset"]}"', f'platform="{spec["platform"]}"',
             "runnable=false", "dedicated_server=false", 'custom_features=""', 'export_filter="all_resources"',
             'include_filter=""', f'exclude_filter="{EXCLUDE}"', f'export_path="{export_path}"',
             'encryption_include_filters=""', 'encryption_exclude_filters=""', "encrypt_pck=false",
             "encrypt_directory=false", "", f"[preset.{index}.options]", ""]
    for k, v in spec["options"].items():
        lines.append(f"{k}={v}")
    lines += ["shader_baker/enabled=true", 'version/name="0.1.0"', ""]
    return "\n".join(lines)


def godot(*args, check=True):
    exe = os.environ.get("GODOT", "godot")
    return subprocess.run([exe, *args], cwd=ROOT, check=check)


GENERATED = ROOT / "scripts" / "generated" / "native_build_info.gd"


def export_desktop(plat: str, workdir: pathlib.Path, sha: str, build: int) -> pathlib.Path:
    spec = DESKTOP[plat]
    original = PRESETS.read_bytes()
    had_info = GENERATED.read_bytes() if GENERATED.exists() else None
    n = len(re.findall(r"^\[preset\.\d+\]$", original.decode(), re.M))
    out_dir = workdir / plat
    out_dir.mkdir(parents=True, exist_ok=True)
    exe = out_dir / spec["exe"]
    try:
        PRESETS.write_bytes(original + preset_block(n, spec, str(exe)).encode())
        # The build's identity (About > Technical: build number, source SHA, run), as for the APK.
        run = os.environ.get("GITHUB_RUN_ID", "local")
        url = f"{os.environ.get('GITHUB_SERVER_URL', '')}/{os.environ.get('GITHUB_REPOSITORY', '')}/actions/runs/{run}" if run != "local" else ""
        subprocess.run([sys.executable, str(ROOT / "tools/write_native_build_info.py"), spec["preset"], "desktop", str(build), sha, run, url],
                       cwd=ROOT, check=True)
        godot("--headless", "--path", ".", "--export-release", spec["preset"], str(exe))
    finally:
        PRESETS.write_bytes(original)   # the Android runtime lock is never left changed
        if had_info is None:
            GENERATED.unlink(missing_ok=True)
        else:
            GENERATED.write_bytes(had_info)
    if not exe.is_file() or exe.stat().st_size < 1_000_000:
        sys.exit(f"export failed: {exe} missing or too small")
    return exe


def write_notices(dest: pathlib.Path) -> None:
    godot("--headless", "--path", ".", "-s", "tools/write_notices.gd", "--", f"out={dest}")
    if not dest.is_file() or dest.stat().st_size < 10_000:
        sys.exit("notices were not written")


def package_desktop(plat: str, exe: pathlib.Path, sha: str, build: int, out: pathlib.Path) -> pathlib.Path:
    spec = DESKTOP[plat]
    folder = f"{TITLE} Build {build}"
    stage = exe.parent / "stage" / folder
    stage.mkdir(parents=True, exist_ok=True)
    shutil.copy2(exe, stage / spec["exe"])
    write_notices(stage / "THIRD_PARTY_NOTICES.txt")
    how = ("Run ./Mote.x86_64. Steam Deck (Desktop Mode): Steam > Add a Non-Steam Game > Mote.x86_64, then play it "
           "from Game Mode.") if plat == "linux" else "Run Mote.exe."
    (stage / "README.txt").write_text(f"{TITLE} Build {build} for {'Linux x86-64' if plat == 'linux' else 'Windows x86-64'}.\n"
                                      f"Source commit {sha}.\n{how}\nLicences: THIRD_PARTY_NOTICES.txt.\n")
    target = out / artifact_name(build, spec["kind"], spec["ext"])
    if plat == "linux":
        os.chmod(stage / spec["exe"], 0o755)
        with tarfile.open(target, "w:gz") as tf:
            for f in sorted(stage.iterdir()):
                info = tf.gettarinfo(str(f), arcname=f"{folder}/{f.name}")
                info.mode = 0o755 if f.name == spec["exe"] else 0o644
                info.uid = info.gid = 0
                info.uname = info.gname = ""
                with open(f, "rb") as fh:
                    tf.addfile(info, fh)
    else:
        with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as zf:
            for f in sorted(stage.iterdir()):
                zf.write(f, f"{folder}/{f.name}")
    return target


def cmd_build(a) -> None:
    sha = check_source(a.sha)
    plats = ["linux", "windows"] if a.platform == "all-desktop" else [a.platform]
    out = pathlib.Path(a.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for p in plats:
            exe = export_desktop(p, pathlib.Path(tmp), sha, a.build)
            print("PACKAGED", package_desktop(p, exe, sha, a.build, out))
    if git("status", "--porcelain", "--untracked-files=no"):
        sys.exit("the build left the checkout changed")


def cmd_apk(a) -> None:
    info = json.loads(pathlib.Path(a.build_info).read_text())
    apk = pathlib.Path(a.apk)
    full = git("rev-parse", a.sha + "^{commit}")
    problems = []
    if sha256(apk) != info["apk"]["sha256"]:
        problems.append("APK sha256 differs from build-info.json")
    if info.get("source_sha") != full:
        problems.append(f"APK source {info.get('source_sha')} is not the requested {full}")
    if int(info.get("android_build", -1)) != a.build:
        problems.append(f"APK android build {info.get('android_build')} is not build {a.build}")
    if problems:
        sys.exit("refused: " + "; ".join(problems))
    out = pathlib.Path(a.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    target = out / artifact_name(a.build, "APK", ".apk")
    shutil.copy2(apk, target)
    (out / "android-build-info.json").write_text(json.dumps(info, indent=2) + "\n")
    print("PACKAGED", target)


def artifacts(d: pathlib.Path, build: int) -> list:
    pre = f"{TITLE} Build {build} "
    return sorted(p for p in d.iterdir() if p.name.startswith(pre) and p.suffix in (".apk", ".zip", ".gz"))


def cmd_manifest(a) -> None:
    d = pathlib.Path(a.dir).resolve()
    full = git("rev-parse", a.sha + "^{commit}")
    files = artifacts(d, a.build)
    if not files:
        sys.exit(f"no '{TITLE} Build {a.build} ...' artifacts in {d}")
    kinds = {"apk": "android", "zip": "windows", "gz": "linux"}
    man = {
        "game": TITLE, "build": a.build, "title": f"{TITLE} Build {a.build}", "source_sha": full,
        "source_branch": json.loads((ROOT / ".github/release-source.json").read_text())["authoritative_branch"],
        "engine": f"godot {engine_version()}", "native_runtime_android": runtime_revision(), "configuration": "release",
        "built_at_utc": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "build_run_url": os.environ.get("BUILD_RUN_URL", "local"),
        "artifacts": [{"file": f.name, "platform": kinds[f.suffix.lstrip(".")], "sha256": sha256(f), "size": f.stat().st_size}
                      for f in files],
    }
    (d / "build-manifest.json").write_text(json.dumps(man, indent=2) + "\n")
    (d / "checksums.sha256").write_text("".join(f"{x['sha256']}  {x['file']}\n" for x in man["artifacts"]))
    verify(d)


def verify(d: pathlib.Path) -> None:
    man = json.loads((d / "build-manifest.json").read_text())
    sums = {}
    for line in (d / "checksums.sha256").read_text().splitlines():
        h, name = line.split("  ", 1)
        sums[name] = h
    bad = []
    for x in man["artifacts"]:
        f = d / x["file"]
        if not f.is_file():
            bad.append(f"{x['file']}: missing")
            continue
        h = sha256(f)
        if h != x["sha256"] or sums.get(x["file"]) != h or f.stat().st_size != x["size"]:
            bad.append(f"{x['file']}: does not match the manifest/checksums")
        if x["platform"] == "linux":
            with tarfile.open(f) as tf:
                exes = [m for m in tf.getmembers() if m.name.endswith("/Mote.x86_64")]
                if not exes or not (exes[0].mode & 0o111):
                    bad.append(f"{x['file']}: no executable Mote.x86_64")
        if x["platform"] == "windows":
            with zipfile.ZipFile(f) as zf:
                if not any(n.endswith("/Mote.exe") for n in zf.namelist()):
                    bad.append(f"{x['file']}: no Mote.exe")
    if len(sums) != len(man["artifacts"]):
        bad.append("checksums.sha256 and build-manifest.json list different files")
    if bad:
        sys.exit("VERIFY FAILED:\n  " + "\n  ".join(bad))
    print(f"VERIFIED {man['title']}: {', '.join(x['file'] for x in man['artifacts'])} (source {man['source_sha'][:12]})")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    b = sub.add_parser("build")
    b.add_argument("--platform", required=True, choices=["linux", "windows", "all-desktop"])
    b.add_argument("--sha", required=True)
    b.add_argument("--build", required=True, type=int)
    b.add_argument("--out", default="dist")
    p = sub.add_parser("apk")
    p.add_argument("--apk", required=True)
    p.add_argument("--build-info", required=True)
    p.add_argument("--sha", required=True)
    p.add_argument("--build", required=True, type=int)
    p.add_argument("--out", default="dist")
    m = sub.add_parser("manifest")
    m.add_argument("--dir", required=True)
    m.add_argument("--sha", required=True)
    m.add_argument("--build", required=True, type=int)
    v = sub.add_parser("verify")
    v.add_argument("--dir", required=True)
    a = ap.parse_args()
    {"build": cmd_build, "apk": cmd_apk, "manifest": cmd_manifest}.get(a.cmd, lambda a: verify(pathlib.Path(a.dir)))(a)


if __name__ == "__main__":
    main()
