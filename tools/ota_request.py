#!/usr/bin/env python3
"""Validates an OTA publication request (owner decision 2026-10-12: OTAs are published only on an explicit
request; studio standard §9-§10). Used by ota-publish.yml before anything is built, and by the tests.

A request names exactly what may be published:

    .github/ota-publish-request.json
    {
      "source_sha": "<full 40-hex commit on the release branch>",
      "runtime_id": "android-godot-4.7.2-r5",      # must be the runtime that commit builds
      "channel": "dev",                             # the only channel the app has
      "ota_name": "polish-pass",                    # optional: title "Mote vN-polish-pass"
      "authorized_by": "owner",                     # who asked (recorded in the run)
      "reason": "..."                               # optional
    }

  validate --request FILE      exit 1 (with the reasons) unless the request is well formed, the commit
                               exists and is on the authoritative branch, it builds exactly the
                               requested runtime, the channel is supported, and that commit has not
                               already been published as an OTA. Prints key=value lines for the workflow.
  self-test                    negative and positive cases on throwaway requests.
"""
import argparse, json, pathlib, re, subprocess, sys, tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
CHANNELS = ("dev",)
KEYS = {"source_sha", "runtime_id", "channel", "ota_name", "authorized_by", "reason"}


def git(*args, check=False):
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True, check=check)


def runtime_at(sha: str) -> str:
    """The runtime id the commit builds: android-godot-<engine pinned in build.yml>-r<RUNTIME_REVISION>."""
    cfg = git("show", f"{sha}:scripts/boot/ota_config.gd").stdout
    wf = git("show", f"{sha}:.github/workflows/build.yml").stdout
    rev = re.search(r"const RUNTIME_REVISION := (\d+)", cfg)
    ver = re.search(r"GODOT_VERSION:\s*([0-9.]+)", wf)
    if not rev or not ver:
        return ""
    return f"android-godot-{ver.group(1)}-r{rev.group(1)}"


def published_sources(channel: str) -> set:
    """Commits already published as OTAs on the channel (their release tags point at them)."""
    out = set()
    for tag in git("tag", "--list", f"ota-{channel}-*").stdout.split():
        r = git("rev-list", "-n1", tag)
        if r.returncode == 0:
            out.add(r.stdout.strip())
    return out


def check(req: dict, remote: str = "origin") -> list:
    errs = []
    if not isinstance(req, dict):
        return ["the request is not a JSON object"]
    extra = set(req) - KEYS
    if extra:
        errs.append(f"unknown fields: {sorted(extra)}")
    sha = str(req.get("source_sha", ""))
    if not re.fullmatch(r"[0-9a-f]{40}", sha):
        errs.append("source_sha must be a full 40-character commit SHA (not a branch, tag or short SHA)")
    channel = str(req.get("channel", ""))
    if channel not in CHANNELS:
        errs.append(f"channel must be one of {list(CHANNELS)}")
    if not str(req.get("authorized_by", "")).strip():
        errs.append("authorized_by is required (who asked for this OTA)")
    name = str(req.get("ota_name", ""))
    if name and not re.fullmatch(r"[a-z0-9-]{1,40}", name):
        errs.append("ota_name may only use a-z, 0-9 and '-' (at most 40)")
    rt = str(req.get("runtime_id", ""))
    if not re.fullmatch(r"android-godot-\d+\.\d+\.\d+-r\d+", rt):
        errs.append("runtime_id must look like android-godot-4.7.2-r5")
    if errs:
        return errs
    if git("cat-file", "-e", f"{sha}^{{commit}}").returncode != 0:
        return [f"commit {sha} is not in this repository"]
    branch = json.loads((ROOT / ".github/release-source.json").read_text())["authoritative_branch"]
    ref = f"{remote}/{branch}" if remote else branch
    if git("merge-base", "--is-ancestor", sha, ref).returncode != 0:
        errs.append(f"{sha[:12]} is not on the release branch {branch}")
    want = runtime_at(sha)
    if want != rt:
        errs.append(f"runtime mismatch: the request says {rt}, commit {sha[:12]} builds {want or 'an unknown runtime'}")
    if sha in published_sources(channel):
        errs.append(f"{sha[:12]} is already published on the {channel} channel")
    return errs


def cmd_validate(a) -> int:
    try:
        req = json.loads(pathlib.Path(a.request).read_text())
    except Exception as e:  # noqa: BLE001 (any unreadable request is refused)
        print(f"::error::OTA request refused: cannot read {a.request}: {e}")
        return 1
    errs = check(req, a.remote)
    if errs:
        for e in errs:
            print(f"::error::OTA request refused: {e}")
        return 1
    print(f"sha={req['source_sha']}\nruntime_id={req['runtime_id']}\nchannel={req['channel']}\n"
          f"ota_name={req.get('ota_name', '')}\nauthorized_by={req['authorized_by']}")
    return 0


def cmd_self_test(_a) -> int:
    head = git("rev-parse", "HEAD").stdout.strip()
    branch = json.loads((ROOT / ".github/release-source.json").read_text())["authoritative_branch"]
    tip = git("rev-parse", f"origin/{branch}").stdout.strip()
    rt = runtime_at(tip)
    published = sorted(published_sources("dev"))
    good = {"source_sha": tip, "runtime_id": rt, "channel": "dev", "authorized_by": "owner"}
    cases = [
        ("missing authorization", {k: v for k, v in good.items() if k != "authorized_by"}, False),
        ("branch name instead of a SHA", dict(good, source_sha=branch), False),
        ("short SHA", dict(good, source_sha=tip[:12]), False),
        ("unknown commit", dict(good, source_sha="0" * 40), False),
        ("wrong runtime", dict(good, runtime_id="android-godot-4.7.2-r6"), False),
        ("unsupported channel", dict(good, channel="stable"), False),
        ("unknown field", dict(good, publish_now=True), False),
        ("bad name", dict(good, ota_name="Polish Pass!"), False),
    ]
    if published:
        cases.append(("already published", dict(good, source_sha=published[-1], runtime_id=runtime_at(published[-1])), False))
    side = git("rev-list", "-n1", f"{head}", "--not", f"origin/{branch}").stdout.strip()
    if side:
        cases.append(("commit not on the release branch", dict(good, source_sha=side, runtime_id=runtime_at(side)), False))
    if tip not in published:
        cases.append(("a valid request for the release-branch tip", good, True))
    bad = 0
    for what, req, want in cases:
        errs = check(req)
        ok = (not errs) == want
        bad += 0 if ok else 1
        print(f"{'PASS' if ok else 'FAIL'} {what}: {'accepted' if not errs else 'refused (' + errs[0] + ')'}")
    print("ota request self-test " + ("OK" if bad == 0 else f"FAILED ({bad})"))
    return 1 if bad else 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    v = sub.add_parser("validate")
    v.add_argument("--request", required=True)
    v.add_argument("--remote", default="origin")
    sub.add_parser("self-test")
    a = ap.parse_args()
    return {"validate": cmd_validate, "self-test": cmd_self_test}[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main())
