#!/usr/bin/env python3
"""Validates an OTA publication request (owner decisions 2026-10-12: OTAs are published only on an explicit,
manual request; studio standard §9-§10). Used by BOTH jobs of ota-publish.yml (resolve, then again in
publish before anything is built or signed) and by the tests.

OTA publication starts ONLY from Actions > OTA publish > Run workflow (workflow_dispatch). No push, merge,
pull request, tag, schedule, request-file change or other workflow can start it (release_guard.py lint
and self-test prove this on the real workflow file). The form's fields become the request:

    {
      "source_sha": "<full 40-hex commit on the release branch>",
      "runtime_id": "android-godot-4.7.2-r5",      # must be the runtime that commit builds
      "channel": "dev",                             # the only channel the app has
      "ota_revision": "dev-000112",                 # the exact next revision on the channel
      "ota_name": "polish-pass",                    # optional: title "Mote vN-polish-pass"
      "authorized_by": "<GitHub login>",            # must equal the authenticated actor
      "reason": "..."                               # optional
    }

The typed "authorized_by" is never proof by itself: the AUTHORIZATION CONTEXT comes from GitHub, not from
the form: the authenticated actor (github.actor), the actor who started this attempt
(github.triggering_actor), that actor's repository permission (read from the API with the run's token),
the ref the workflow was dispatched from, and the typed confirmation. All must agree:
actor == triggering actor == authorized_by, the actor is listed in release-source.json "ota_publishers"
and is a repository admin, the run was dispatched from the release branch, and confirm == PUBLISH.

  validate --request FILE --actor A --triggering-actor T --permission P --ref R --confirm C
                               exit 1 (with the reasons) unless the request is well formed, authorized as
                               above, the commit exists and is on the authoritative branch, it builds exactly
                               the requested runtime, the channel is supported, the revision is the next one
                               and not already published, and that commit has not already been published.
                               Prints key=value lines for the workflow.
  next-revision [--channel dev] the next OTA revision on the channel (from the ota-<channel>-NNNNNN tags).
  self-test                    negative and positive cases on throwaway requests.

Limitation (documented in docs/OTA_PUBLISHING.md): GitHub identifies accounts, not people. Anyone who can
act as an allowed admin account can pass these checks. Owner-only enforcement at the GitHub level is the
`ota-dev` environment's required reviewer (the owner configures it in Settings > Environments).
"""
import argparse, json, pathlib, re, subprocess, sys, tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
CHANNELS = ("dev",)
KEYS = {"source_sha", "runtime_id", "channel", "ota_revision", "ota_name", "authorized_by", "reason"}
CONFIRM = "PUBLISH"
ADMIN = "admin"


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


def next_revision(channel: str) -> str:
    """One more than the highest ota-<channel>-NNNNNN tag (the publish job computes the same from the
    release list and refuses to continue if they differ)."""
    seqs = [int(t.rsplit("-", 1)[1]) for t in git("tag", "--list", f"ota-{channel}-*").stdout.split()
            if re.fullmatch(rf"ota-{re.escape(channel)}-\d{{6}}", t)]
    return f"{channel}-{(max(seqs) if seqs else 0) + 1:06d}"


def config() -> dict:
    return json.loads((ROOT / ".github/release-source.json").read_text())


def check_auth(req: dict, ctx: dict) -> list:
    """Who started this run, established by GitHub (never by the typed name alone)."""
    errs = []
    actor = str(ctx.get("actor") or "").strip()
    trig = str(ctx.get("triggering_actor") or "").strip()
    if not actor:
        return ["no authenticated GitHub actor (publication starts only from a manual run)"]
    if trig.lower() != actor.lower():
        errs.append(f"the run was started (or re-run) by {trig or 'nobody'}, not {actor}; each attempt must be started by the authorizer")
    allowed = [a.lower() for a in config().get("ota_publishers", [])]
    if actor.lower() not in allowed:
        errs.append(f"{actor} is not an allowed OTA publisher (release-source.json ota_publishers)")
    if str(ctx.get("permission") or "") != ADMIN:
        errs.append(f"{actor} has repository permission '{ctx.get('permission') or 'unknown'}', publishing needs '{ADMIN}'")
    if str(req.get("authorized_by", "")).strip().lower() != actor.lower():
        errs.append(f"authorized_by '{req.get('authorized_by', '')}' is not the authenticated actor '{actor}'")
    want_ref = "refs/heads/" + config()["authoritative_branch"]
    if ctx.get("ref") != want_ref:
        errs.append(f"the workflow must be run from {want_ref}, not {ctx.get('ref') or 'an unknown ref'}")
    if ctx.get("confirm") != CONFIRM:
        errs.append(f"confirm must be {CONFIRM}")
    return errs


def check(req: dict, ctx: dict, remote: str = "origin") -> list:
    errs = []
    if not isinstance(req, dict):
        return ["the request is not a JSON object"]
    errs += check_auth(req, ctx)
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
    rev = str(req.get("ota_revision", ""))
    if not re.fullmatch(r"[a-z]+-\d{6}", rev) or not rev.startswith(channel + "-"):
        errs.append(f"ota_revision must be the exact revision to publish, e.g. {channel or 'dev'}-000112")
    if errs:
        return errs
    nxt = next_revision(channel)
    if git("rev-parse", "-q", "--verify", f"refs/tags/ota-{rev}").returncode == 0:
        errs.append(f"{rev} is already published (OTA revisions are immutable); the next is {nxt}")
    elif rev != nxt:
        errs.append(f"ota_revision {rev} is not the next revision on the {channel} channel ({nxt})")
    if git("cat-file", "-e", f"{sha}^{{commit}}").returncode != 0:
        return [f"commit {sha} is not in this repository"]
    branch = config()["authoritative_branch"]
    ref = f"{remote}/{branch}" if remote else branch
    if git("merge-base", "--is-ancestor", sha, ref).returncode != 0:
        errs.append(f"{sha[:12]} is not on the release branch {branch}")
    want = runtime_at(sha)
    if want != rt:
        errs.append(f"runtime mismatch: the request says {rt}, commit {sha[:12]} builds {want or 'an unknown runtime'}")
    if sha in published_sources(channel):
        errs.append(f"{sha[:12]} is already published on the {channel} channel")
    return errs


def _ctx(a) -> dict:
    return {"actor": a.actor, "triggering_actor": a.triggering_actor, "permission": a.permission,
            "ref": a.ref, "confirm": a.confirm}


def cmd_validate(a) -> int:
    try:
        req = json.loads(pathlib.Path(a.request).read_text())
    except Exception as e:  # noqa: BLE001 (any unreadable request is refused)
        print(f"::error::OTA request refused: cannot read {a.request}: {e}")
        return 1
    errs = check(req, _ctx(a), a.remote)
    if errs:
        for e in errs:
            print(f"::error::OTA request refused: {e}")
        return 1
    print(f"sha={req['source_sha']}\nruntime_id={req['runtime_id']}\nchannel={req['channel']}\n"
          f"ota_revision={req['ota_revision']}\nota_name={req.get('ota_name', '')}\nauthorized_by={req['authorized_by']}")
    return 0


def cmd_next_revision(a) -> int:
    print(next_revision(a.channel))
    return 0


def cmd_self_test(_a) -> int:
    head = git("rev-parse", "HEAD").stdout.strip()
    branch = config()["authoritative_branch"]
    tip = git("rev-parse", f"origin/{branch}").stdout.strip()
    rt = runtime_at(tip)
    published = sorted(published_sources("dev"))
    nxt = next_revision("dev")
    owner = (config().get("ota_publishers") or ["owner"])[0]
    good = {"source_sha": tip, "runtime_id": rt, "channel": "dev", "ota_revision": nxt, "authorized_by": owner}
    ctx = {"actor": owner, "triggering_actor": owner, "permission": "admin", "ref": f"refs/heads/{branch}", "confirm": "PUBLISH"}
    tags = sorted(t for t in git("tag", "--list", "ota-dev-*").stdout.split())
    cases = [
        ("missing authorization", {k: v for k, v in good.items() if k != "authorized_by"}, ctx, False),
        ("typed authorized_by is not the authenticated actor", dict(good, authorized_by="owner-approved"), ctx, False),
        ("no authenticated actor (not a manual run)", good, dict(ctx, actor="", triggering_actor=""), False),
        ("actor not an allowed publisher", dict(good, authorized_by="someone-else"),
         dict(ctx, actor="someone-else", triggering_actor="someone-else"), False),
        ("re-run started by another account", good, dict(ctx, triggering_actor="someone-else"), False),
        ("actor without admin permission", good, dict(ctx, permission="write"), False),
        ("dispatched from another branch", good, dict(ctx, ref="refs/heads/feature"), False),
        ("dispatched from a tag", good, dict(ctx, ref="refs/tags/ota-dev-000111"), False),
        ("not confirmed", good, dict(ctx, confirm="publish"), False),
        ("branch name instead of a SHA", dict(good, source_sha=branch), ctx, False),
        ("short SHA", dict(good, source_sha=tip[:12]), ctx, False),
        ("unknown commit", dict(good, source_sha="0" * 40), ctx, False),
        ("wrong runtime", dict(good, runtime_id="android-godot-4.7.2-r6"), ctx, False),
        ("unsupported channel", dict(good, channel="stable"), ctx, False),
        ("unknown field", dict(good, publish_now=True), ctx, False),
        ("bad name", dict(good, ota_name="Polish Pass!"), ctx, False),
        ("missing revision", {k: v for k, v in good.items() if k != "ota_revision"}, ctx, False),
        ("revision for another channel", dict(good, ota_revision="stable-000112"), ctx, False),
        ("skipped revision", dict(good, ota_revision=f"dev-{int(nxt[4:]) + 1:06d}"), ctx, False),
    ]
    if tags:
        cases.append(("already-published revision", dict(good, ota_revision=tags[-1][4:]), ctx, False))
    if published:
        cases.append(("already-published source", dict(good, source_sha=published[-1], runtime_id=runtime_at(published[-1])), ctx, False))
    side = git("rev-list", "-n1", f"{head}", "--not", f"origin/{branch}").stdout.strip()
    if side:
        cases.append(("commit not on the release branch", dict(good, source_sha=side, runtime_id=runtime_at(side)), ctx, False))
    if tip not in published:
        cases.append(("a valid, authorized request for the release-branch tip", good, ctx, True))
    bad = 0
    for what, req, c, want in cases:
        errs = check(req, c)
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
    # The authorization context: from GitHub (github.actor, github.triggering_actor, the API, github.ref).
    for k in ("--actor", "--triggering-actor", "--permission", "--ref", "--confirm"):
        v.add_argument(k, required=True)
    n = sub.add_parser("next-revision")
    n.add_argument("--channel", default="dev")
    sub.add_parser("self-test")
    a = ap.parse_args()
    return {"validate": cmd_validate, "next-revision": cmd_next_revision, "self-test": cmd_self_test}[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main())
