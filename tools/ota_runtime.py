#!/usr/bin/env python3
"""Native-runtime compatibility gate for OTA publication.

The installed APK can only run OTA packs built for the runtime it contains. Anything that
changes the native layer (engine version, export/manifest/permissions config, project
settings, the bootstrap under scripts/boot/) cannot be delivered by OTA. This tool
fingerprints those inputs and compares them with ota/runtime_lock.json:

  --check          exit 1 if the native layer changed without a runtime bump
  --bump           increment RUNTIME_REVISION in scripts/boot/ota_config.gd and relock
                   (then build and install a new APK)
  --print          show the current fingerprint
"""
import hashlib, json, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LOCK = ROOT / "ota" / "runtime_lock.json"
CONFIG = ROOT / "scripts" / "boot" / "ota_config.gd"
BUILD_WORKFLOW = ROOT / ".github" / "workflows" / "build.yml"


def native_files():
    files = [ROOT / "project.godot", ROOT / "export_presets.cfg"]
    files += sorted((ROOT / "scripts" / "boot").glob("*.gd"))
    return files


def godot_version():
    m = re.search(r"GODOT_VERSION:\s*([0-9.]+)", BUILD_WORKFLOW.read_text())
    return m.group(1)


def revision():
    return int(re.search(r"const RUNTIME_REVISION := (\d+)", CONFIG.read_text()).group(1))


def fingerprint(rev=None):
    h = hashlib.sha256()
    h.update(f"godot {godot_version()}\n".encode())
    for f in native_files():
        text = f.read_text()
        if f == CONFIG:
            # The revision number itself is not part of what it guards.
            text = re.sub(r"const RUNTIME_REVISION := \d+", "const RUNTIME_REVISION := N", text)
        h.update(f"{f.relative_to(ROOT)}\n".encode())
        h.update(text.encode())
    return h.hexdigest()


def write_lock():
    LOCK.parent.mkdir(exist_ok=True)
    LOCK.write_text(json.dumps({
        "runtime_revision": revision(),
        "godot_version": godot_version(),
        "fingerprint": fingerprint(),
        "files": [str(f.relative_to(ROOT)) for f in native_files()],
    }, indent=2) + "\n")


def main():
    arg = sys.argv[1] if len(sys.argv) > 1 else "--check"
    if arg == "--print":
        print(revision(), fingerprint())
    elif arg == "--bump":
        text = CONFIG.read_text()
        new = revision() + 1
        CONFIG.write_text(re.sub(r"const RUNTIME_REVISION := \d+", f"const RUNTIME_REVISION := {new}", text))
        write_lock()
        print(f"runtime revision bumped to r{new}: build and install a new APK before publishing OTAs")
    elif arg == "--relock":
        write_lock()
        print("lock rewritten (pre-release only: no APK with this revision was ever distributed)")
    elif arg == "--check":
        lock = json.loads(LOCK.read_text())
        fp = fingerprint()
        if lock["runtime_revision"] != revision():
            print(f"FAIL: ota_config.gd says r{revision()} but runtime_lock.json says r{lock['runtime_revision']}")
            sys.exit(1)
        if lock["fingerprint"] != fp:
            print("NATIVE UPDATE REQUIRED: the native layer changed since runtime "
                  f"r{lock['runtime_revision']} was locked.\n"
                  "Files guarded: " + ", ".join(lock["files"]) + "\n"
                  "These changes cannot reach installed APKs by OTA. Run "
                  "`python3 tools/ota_runtime.py --bump`, commit, and build/install a new APK.")
            sys.exit(1)
        print(f"runtime r{revision()} unchanged (godot {godot_version()}): OTA-compatible")
    else:
        print(__doc__)
        sys.exit(2)


if __name__ == "__main__":
    main()
