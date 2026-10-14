#!/usr/bin/env python3
"""Release-source guard (single source of truth, docs/RELEASE_SOURCE.md).

Every published Mote build (OTA pack, playtester APK, desktop build) comes from ONE authoritative branch,
named in .github/release-source.json. This tool keeps that true, simply and deterministically:

  check --sha SHA [--remote origin] [--contains-published GLOB]
      exit 1 unless SHA is on the authoritative branch (an ancestor of, or equal to, its tip on the
      remote), so an abandoned or unmerged branch can never publish; and, with --contains-published,
      unless SHA contains the source of every earlier release whose tag matches GLOB (e.g. 'ota-dev-*'),
      so an outdated commit can never ship over newer work. (A rollback is a new commit that reverts.)
  provenance --sha SHA --platform P --version V --config C [--build N] [--run-url U] [--out FILE]
      write the build-provenance record (source SHA, branch, version, platform, config, engine version,
      native runtime, UTC timestamp, toolchain) that ships next to the artifact.
  lint
      exit 1 unless the workflows obey the policy: every publishing workflow push-triggers only the
      authoritative branch and runs `check`, every "dispatch_only" workflow (ota-publish.yml) has no
      trigger but workflow_dispatch, and every workflow pins the same Godot version.
  triggers --from A --to B
      which workflows a push moving the release branch from A to B would start (exit 1 if a publishing one).
  entry-points [--rev REV] [--workflow ota-publish.yml]
      simulate every GitHub event (pushes of game files, the request file, a version change, a merge, a tag;
      pull requests; schedule; workflow_run; release; repository_dispatch; workflow_call; manual run) against
      the workflow at REV; exit 1 unless the manual run is the only one that starts it.
  self-test
      prove `check` on a throwaway repository (an ancestor passes; a side branch and a stale tip fail), the
      lint rules, the push simulation, and the entry points of the real OTA workflow.
"""
import argparse, datetime, json, os, pathlib, platform, re, subprocess, sys, tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
CONFIG = ROOT / ".github" / "release-source.json"
WORKFLOWS = ROOT / ".github" / "workflows"


def config():
    return json.loads(CONFIG.read_text())


def git(*args, cwd=ROOT):
    return subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True)


def is_on_branch(sha, ref, cwd=ROOT):
    """True when `sha` is `ref` or one of its ancestors."""
    full = git("rev-parse", "--verify", sha + "^{commit}", cwd=cwd)
    if full.returncode != 0:
        return False, f"unknown commit {sha}"
    if git("rev-parse", "--verify", ref, cwd=cwd).returncode != 0:
        return False, f"unknown ref {ref} (fetch it with full history first)"
    ok = git("merge-base", "--is-ancestor", full.stdout.strip(), ref, cwd=cwd).returncode == 0
    return ok, ("" if ok else f"{sha} is not on {ref}")


def cmd_check(a):
    branch = config()["authoritative_branch"]
    ref = f"{a.remote}/{branch}" if a.remote else branch
    ok, why = is_on_branch(a.sha, ref)
    if not ok:
        print(f"::error::release source refused: {why}. Only commits on the authoritative branch "
              f"'{branch}' may be published (docs/RELEASE_SOURCE.md).")
        return 1
    if a.contains_published:
        tags = [x for x in git("tag", "--list", a.contains_published).stdout.split() if x]
        missing = [tag for tag in tags if not is_on_branch(tag, a.sha)[0]]
        if missing:
            print(f"::error::release source refused: {a.sha} is older than published work: it lacks the source of "
                  f"{', '.join(missing[:5])}{' …' if len(missing) > 5 else ''}. Publish a newer commit of '{branch}'.")
            return 1
        print(f"release source contains all {len(tags)} earlier releases matching {a.contains_published}")
    print(f"release source OK: {a.sha} is on {ref}")
    return 0


def engine_versions():
    found = {}
    for wf in sorted(WORKFLOWS.glob("*.yml")):
        for v in re.findall(r"GODOT_VERSION:\s*([0-9.]+)", wf.read_text()):
            found.setdefault(v, []).append(wf.name)
    return found


def runtime_id():
    m = re.search(r"const RUNTIME_REVISION := (\d+)", (ROOT / "scripts/boot/ota_config.gd").read_text())
    return f"r{m.group(1)}" if m else "unknown"


def cmd_provenance(a):
    cfg = config()
    versions = engine_versions()
    rec = {
        "product": cfg["product"],
        "source_sha": git("rev-parse", a.sha).stdout.strip() or a.sha,
        "source_branch": cfg["authoritative_branch"],
        "version": a.version,
        "build": a.build,
        "platform": a.platform,
        "config": a.config,
        "engine": "godot " + (",".join(sorted(versions)) or "unknown"),
        "native_runtime": runtime_id(),
        "built_at_utc": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "toolchain": {"os": platform.platform(), "python": platform.python_version(),
                      "runner": os.environ.get("RUNNER_NAME", "local")},
        "build_run_url": a.run_url,
    }
    text = json.dumps(rec, indent=2) + "\n"
    if a.out:
        pathlib.Path(a.out).write_text(text)
    print(text, end="")
    return 0


def _list_value(block, key):
    """A key's list in a trigger block: inline [a, b] or a block list of "- a" lines."""
    inline = re.search(rf"^\s*{re.escape(key)}:\s*\[([^\]]*)\]", block, re.M)
    if inline:
        return [b.strip().strip("'\"") for b in inline.group(1).split(",") if b.strip()]
    lst = re.search(rf"^\s*{re.escape(key)}:\s*\n((?:\s+-\s*.*\n?)+)", block, re.M)
    return [re.sub(r"\s*#.*", "", l).strip().lstrip("-").strip().strip("'\"") for l in lst.group(1).splitlines() if l.strip()] if lst else []


def triggers(text):
    """The workflow's triggers: {event: block text} (the `on:` mapping, two-space indented keys)."""
    m = re.search(r"^on:\s*\n(.*?)(?=^\S)", text + "\nEND", re.S | re.M)
    if not m:
        return {}
    out = {}
    for t in re.finditer(r"^  ([a-z_]+):[^\n]*\n((?:^    .*\n|^\s*\n)*)", m.group(1), re.M):
        out[t.group(1)] = t.group(2)
    return out


def push_spec(text):
    """None when the workflow has no push trigger, else its branches, paths and paths-ignore."""
    block = triggers(text).get("push")
    if block is None:
        return None
    return {"branches": _list_value(block, "branches"), "paths": _list_value(block, "paths"),
            "paths_ignore": _list_value(block, "paths-ignore"), "tags": _list_value(block, "tags")}


def push_branches(text):
    spec = push_spec(text)
    return spec["branches"] if spec else []


REQUEST_FILE = re.compile(r"^\.github/[a-z0-9-]+-request\.json$")


def _on_is_block(text):
    """True when the workflow declares its triggers once, as a block mapping (`on:` then indented events).
    The simulator reads only that form, so an inline `on: push`, `on: [push]` or a quoted/duplicate key
    is refused rather than misread."""
    keys = re.findall(r"^(on|\"on\"|'on'|true)\s*:(.*)$", text, re.M)
    return len(keys) == 1 and keys[0][0] == "on" and keys[0][1].strip().split("#")[0] == ""


def dispatch_only_errors(name, text):
    """A dispatch-only workflow (OTA publication) may start ONLY by hand."""
    if not _on_is_block(text):
        return [f"{name}: its `on:` must be one block mapping containing only workflow_dispatch"]
    other = [ev for ev in triggers(text) if ev != "workflow_dispatch"]
    errs = [f"{name}: may only start by hand (workflow_dispatch); found trigger(s) {other}"] if other else []
    if "workflow_dispatch" not in triggers(text):
        errs.append(f"{name}: has no workflow_dispatch trigger")
    return errs


def publishing_errors(name, text, branch, dispatch_only=False):
    """Why a publishing workflow could publish without an explicit request (empty when it cannot)."""
    errs = dispatch_only_errors(name, text) if dispatch_only else []
    if not _on_is_block(text):
        errs.append(f"{name}: its `on:` must be one block mapping (the guard cannot read other forms)")
    trig = triggers(text)
    for ev in trig:
        if ev not in ("push", "workflow_dispatch"):
            errs.append(f"{name}: publishing workflows may only start on a request-file push or by hand, not on '{ev}'")
    spec = push_spec(text)
    if spec is not None:
        if spec["branches"] != [branch]:
            errs.append(f"{name}: push-triggers {spec['branches'] or 'every branch'}; only '{branch}' may publish")
        if spec["paths_ignore"] or not spec["paths"] or not all(REQUEST_FILE.match(x) for x in spec["paths"]):
            errs.append(f"{name}: an ordinary push could publish (its push trigger must be limited to "
                        f"`paths: [.github/<name>-request.json]`; found paths {spec['paths']} ignore {spec['paths_ignore']})")
    if "tools/release_guard.py check" not in text:
        errs.append(f"{name}: does not run `tools/release_guard.py check` on the commit it publishes")
    return errs


def _glob_re(pattern):
    """GitHub path filter glob: ** crosses folders, * does not."""
    out, i = "", 0
    while i < len(pattern):
        if pattern.startswith("**/", i):
            out += "(?:.*/)?"
            i += 3
        elif pattern.startswith("**", i):
            out += ".*"
            i += 2
        elif pattern[i] == "*":
            out += "[^/]*"
            i += 1
        else:
            out += re.escape(pattern[i])
            i += 1
    return re.compile("^" + out + "$")


def push_would_run(spec, branch, files, message):
    """Whether a push of `files` to `branch` (head commit `message`) starts a workflow with this push spec."""
    if spec is None:
        return False
    if re.search(r"\[(skip ci|ci skip|no ci|skip actions|actions skip)\]", message, re.I):
        return False
    if spec["branches"] and not any(_glob_re(b).match(branch) for b in spec["branches"]):
        return False
    if spec["paths"]:
        return any(_glob_re(p).match(f) for p in spec["paths"] for f in files)
    if spec["paths_ignore"]:
        return any(not any(_glob_re(p).match(f) for p in spec["paths_ignore"]) for f in files)
    return True


def tag_push_would_run(spec, tag):
    """GitHub: a tag push starts a push workflow when its `tags` filter matches, or when it filters
    neither branches nor tags (path filters do not apply to tags)."""
    if spec is None:
        return False
    if spec["tags"]:
        return any(_glob_re(t).match(tag) for t in spec["tags"])
    return not spec["branches"]


def would_start(text, event, branch="", files=(), message="x", tag=""):
    """Whether `event` starts the workflow `text` (push: of `files` to `branch`, or of `tag`)."""
    trig = triggers(text)
    if event == "push":
        return push_would_run(push_spec(text), branch, list(files), message)
    if event == "tag":
        return tag_push_would_run(push_spec(text), tag)
    return event in trig


def entry_point_cases(branch):
    """Every way GitHub could start a workflow, as (what, event, kwargs)."""
    return [
        ("an ordinary push (game files)", "push", dict(branch=branch, files=["scripts/core/game.gd"])),
        ("a push changing .github/ota-publish-request.json", "push", dict(branch=branch, files=[".github/ota-publish-request.json"])),
        ("a push changing the request file and game files", "push", dict(branch=branch, files=[".github/ota-publish-request.json", "scripts/core/game.gd"])),
        ("a version change (scripts/core/version.gd)", "push", dict(branch=branch, files=["scripts/core/version.gd"])),
        ("a merge into the release branch (lands as a push)", "push", dict(branch=branch, files=["scripts/core/game.gd", ".github/workflows/ota-publish.yml"], message="Merge pull request #9")),
        ("a push to another branch", "push", dict(branch="feature/x", files=[".github/ota-publish-request.json"])),
        ("a tag push (ota-dev-000999)", "tag", dict(tag="ota-dev-000999")),
        ("a tag push (build-140)", "tag", dict(tag="build-140")),
        ("a pull request opened or updated", "pull_request", {}),
        ("a pull_request_target event", "pull_request_target", {}),
        ("a merged pull request (closed)", "pull_request", {}),
        ("a schedule", "schedule", {}),
        ("a native build completing (workflow_run)", "workflow_run", {}),
        ("another workflow calling it (workflow_call)", "workflow_call", {}),
        ("a release being published", "release", {}),
        ("repository_dispatch (API)", "repository_dispatch", {}),
        ("a deployment / status / check run", "check_run", {}),
        ("a manual run (Actions > Run workflow)", "workflow_dispatch", {}),
    ]


def entry_points(text, branch):
    """[(what, starts)] for every case; the manual run must be the only True for a dispatch-only workflow."""
    return [(what, would_start(text, ev, **kw)) for what, ev, kw in entry_point_cases(branch)]


def cmd_entry_points(a):
    branch = config()["authoritative_branch"]
    text = git("show", f"{a.rev}:.github/workflows/{a.workflow}").stdout if a.rev else (WORKFLOWS / a.workflow).read_text()
    if not text:
        print(f"::error::{a.workflow} not found at {a.rev or 'the working tree'}")
        return 1
    bad = list(dispatch_only_errors(a.workflow, text))
    print(f"{a.workflow} at {a.rev or 'working tree'}: what can start it")
    for what, starts in entry_points(text, branch):
        manual = what.startswith("a manual run")
        print(f"  {'STARTS ' if starts else 'no     '} {what}")
        if starts != manual:
            bad.append(f"{what}: {'starts it' if starts else 'does not start it'}")
    for e in bad:
        print("::error::" + e)
    print("entry points: " + ("manual dispatch only" if not bad else "NOT dispatch-only"))
    return 1 if bad else 0


def cmd_triggers(a):
    """Which workflows a push moving the release branch from FROM to TO would start (the definitions
    GitHub uses are the ones in TO, the pushed head)."""
    branch = config()["authoritative_branch"]
    files = [f for f in git("diff", "--name-only", a.frm, a.to).stdout.split("\n") if f]
    message = git("log", "-1", "--format=%B", a.to).stdout
    names = [n for n in git("ls-tree", "--name-only", f"{a.to}:.github/workflows").stdout.split() if n.endswith((".yml", ".yaml"))]
    started = []
    for n in names:
        text = git("show", f"{a.to}:.github/workflows/{n}").stdout
        if push_would_run(push_spec(text), branch, files, message):
            started.append(n)
    publishing = set(config()["publishing_workflows"])
    print(f"push {a.frm[:12]}..{a.to[:12]} to {branch}: {len(files)} files changed")
    print("starts: " + (", ".join(started) if started else "nothing"))
    bad = [n for n in started if n in publishing]
    if bad:
        print(f"::error::this push would start publishing workflow(s): {', '.join(bad)}")
        return 1
    return 0


def cmd_lint(_a):
    cfg = config()
    branch = cfg["authoritative_branch"]
    errors = []
    only = set(cfg.get("dispatch_only", []))
    if "ota-publish.yml" not in only:
        errors.append("release-source.json: ota-publish.yml must be listed in dispatch_only (OTAs start only by hand)")
    if not cfg.get("ota_publishers"):
        errors.append("release-source.json: ota_publishers is empty (no account could publish an OTA)")
    for name in cfg["publishing_workflows"]:
        wf = WORKFLOWS / name
        if not wf.exists():
            errors.append(f"{name}: listed as a publishing workflow but missing")
            continue
        errors += publishing_errors(name, wf.read_text(), branch, name in only)
    for name in only - set(cfg["publishing_workflows"]):
        errors.append(f"{name}: dispatch_only but not listed in publishing_workflows")
    versions = engine_versions()
    if len(versions) != 1:
        errors.append(f"workflows pin different Godot versions: {versions}")
    for e in errors:
        print("::error::" + e)
    if not errors:
        print(f"release workflows OK: {', '.join(cfg['publishing_workflows'])} publish only on an explicit request, from {branch}; "
              f"{', '.join(sorted(only))} only by hand; "
              f"engine {', '.join(versions)}")
    return 1 if errors else 0


def cmd_self_test(_a):
    with tempfile.TemporaryDirectory() as d:
        env = dict(os.environ, GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@t", GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@t")

        def run(*args):
            subprocess.run(["git", *args], cwd=d, env=env, check=True, capture_output=True)

        def commit(msg):
            run("commit", "--allow-empty", "-q", "-m", msg)
            return git("rev-parse", "HEAD", cwd=d).stdout.strip()

        run("init", "-q", "-b", "main")
        c1 = commit("one")
        c2 = commit("two")
        run("checkout", "-q", "-b", "side", c1)
        side = commit("side work")
        run("checkout", "-q", "main")
        c3 = commit("three")
        cases = [(c3, "main", True, "the tip"), (c2, "main", True, "an ancestor"),
                 (side, "main", False, "a side branch"), (c3, "side", False, "a newer commit against a stale branch"),
                 ("deadbeef", "main", False, "an unknown commit")]
        run("tag", "rel-1", c2)
        # (release tag, candidate): the candidate must contain the release's source.
        cases.append(("rel-1", c1, False, "an outdated commit (older than release rel-1)"))
        cases.append(("rel-1", c3, True, "a commit containing release rel-1"))
        bad = 0
        for sha, ref, want, what in cases:
            got, why = is_on_branch(sha, ref, cwd=d)
            ok = got == want
            bad += 0 if ok else 1
            print(f"{'PASS' if ok else 'FAIL'} {what}: on_branch={got} {why}")
    # Publishing workflows: only a request-file push or a manual run may start them.
    b = "release"
    head = "on:\n  push:\n    branches: [release]\n"
    lint_cases = [
        ("an ordinary game-file push publishes", head + "    paths-ignore: [\"docs/**\"]\n  workflow_dispatch:\njobs:\n", False),
        ("every push publishes", head + "  workflow_dispatch:\njobs:\n", False),
        ("a request file plus game files", head + "    paths: [\".github/x-request.json\", \"scripts/**\"]\njobs:\n", False),
        ("publishing on a pull request", "on:\n  pull_request:\n  workflow_dispatch:\njobs:\n", False),
        ("another branch publishes", "on:\n  push:\n    branches: [old]\n    paths: [\".github/x-request.json\"]\njobs:\n", False),
        ("request file only, or by hand", head + "    paths: [\".github/x-request.json\"]\n  workflow_dispatch:\njobs:\n", True),
        ("by hand only", "on:\n  workflow_dispatch:\njobs:\n", True),
    ]
    for what, text, want in lint_cases:
        errs = publishing_errors("wf.yml", text + "  # tools/release_guard.py check\n", b)
        ok = (not errs) == want
        bad += 0 if ok else 1
        print(f"{'PASS' if ok else 'FAIL'} lint, {what}: {'accepted' if not errs else 'refused'}")
    spec = push_spec(head + "    paths: [\".github/ota-publish-request.json\"]\njobs:\n")
    run_cases = [
        ("game files only", ["scripts/core/game.gd"], "x", False),
        ("the request file", [".github/ota-publish-request.json"], "x", True),
        ("the request file with [skip ci]", [".github/ota-publish-request.json"], "x [skip ci]", False),
    ]
    for what, files, msg, want in run_cases:
        got = push_would_run(spec, b, files, msg)
        ok = got == want
        bad += 0 if ok else 1
        print(f"{'PASS' if ok else 'FAIL'} trigger, {what}: {'starts' if got else 'does not start'}")
    old = push_spec(head + "    paths-ignore: [\"**/*.md\", \"docs/**\", \".github/**\"]\njobs:\n")
    for what, files, want in [("old rule: a game file", ["scripts/a.gd"], True), ("old rule: docs only", ["docs/a.md", "x/README.md"], False)]:
        got = push_would_run(old, b, files, "x")
        ok = got == want
        bad += 0 if ok else 1
        print(f"{'PASS' if ok else 'FAIL'} trigger, {what}: {'starts' if got else 'does not start'}")
    # Dispatch-only rule (OTA publication): any trigger but a manual run is refused, in any spelling.
    tail = "  # tools/release_guard.py check\n"
    d_cases = [
        ("dispatch-only: by hand", "on:\n  workflow_dispatch:\n    inputs:\n      x:\n        required: true\njobs:\n", True),
        ("dispatch-only: plus a request-file push", head + "    paths: [\".github/ota-publish-request.json\"]\n  workflow_dispatch:\njobs:\n", False),
        ("dispatch-only: plus a tag push", "on:\n  push:\n    tags: [\"ota-*\"]\n  workflow_dispatch:\njobs:\n", False),
        ("dispatch-only: plus a schedule", "on:\n  schedule:\n    - cron: \"0 3 * * *\"\n  workflow_dispatch:\njobs:\n", False),
        ("dispatch-only: plus workflow_run", "on:\n  workflow_run:\n    workflows: [\"Build & Verify\"]\n  workflow_dispatch:\njobs:\n", False),
        ("dispatch-only: plus pull_request", "on:\n  pull_request:\n  workflow_dispatch:\njobs:\n", False),
        ("dispatch-only: inline list on: [push, workflow_dispatch]", "on: [push, workflow_dispatch]\njobs:\n", False),
        ("dispatch-only: inline on: push", "on: push\njobs:\n", False),
        ("dispatch-only: quoted \"on\" key", "\"on\":\n  push:\n  workflow_dispatch:\njobs:\n", False),
        ("dispatch-only: a second on: block", "on:\n  workflow_dispatch:\non:\n  push:\njobs:\n", False),
    ]
    for what, text, want in d_cases:
        errs = publishing_errors("ota-publish.yml", text + tail, b, dispatch_only=True)
        ok = (not errs) == want
        bad += 0 if ok else 1
        print(f"{'PASS' if ok else 'FAIL'} lint, {what}: {'accepted' if not errs else 'refused'}")
    tag_spec = push_spec("on:\n  push:\n    branches: [release]\n    paths: [\".github/x-request.json\"]\njobs:\n")
    for what, sp, tag, want in [("tag push vs branch-only push trigger", tag_spec, "v1", False),
                                ("tag push vs a tags filter", push_spec("on:\n  push:\n    tags: [\"v*\"]\njobs:\n"), "v1", True),
                                ("tag push vs an unfiltered push", push_spec("on:\n  push:\njobs:\n"), "v1", True)]:
        got = tag_push_would_run(sp, tag)
        ok = got == want
        bad += 0 if ok else 1
        print(f"{'PASS' if ok else 'FAIL'} trigger, {what}: {'starts' if got else 'does not start'}")
    # Regression (2026-10-12): the REAL ota-publish.yml. A push changing .github/ota-publish-request.json, or
    # any other event, must not start it; only a manual run may.
    real = (WORKFLOWS / "ota-publish.yml").read_text()
    branch = config()["authoritative_branch"]
    for what, starts in entry_points(real, branch):
        want = what.startswith("a manual run")
        ok = starts == want
        bad += 0 if ok else 1
        print(f"{'PASS' if ok else 'FAIL'} ota-publish.yml, {what}: {'starts' if starts else 'does not start'}")
    errs = publishing_errors("ota-publish.yml", real, branch, dispatch_only=True)
    bad += 1 if errs else 0
    print(f"{'PASS' if not errs else 'FAIL'} ota-publish.yml passes the dispatch-only lint {errs or ''}")
    # The rule bites: the same file with the old request-file push trigger put back is refused and starts.
    old_ota = real.replace("on:\n  workflow_dispatch:", "on:\n  push:\n    branches:\n      - " + branch +
                           "\n    paths: [\".github/ota-publish-request.json\"]\n  workflow_dispatch:", 1)
    regressed = publishing_errors("ota-publish.yml", old_ota, branch, dispatch_only=True)
    starts = would_start(old_ota, "push", branch=branch, files=[".github/ota-publish-request.json"])
    ok = old_ota != real and bool(regressed) and starts
    bad += 0 if ok else 1
    print(f"{'PASS' if ok else 'FAIL'} the old request-file push trigger, if restored, is refused by lint (and would start)")
    print("self-test " + ("OK" if bad == 0 else f"FAILED ({bad})"))
    return 1 if bad else 0


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("check")
    c.add_argument("--sha", required=True)
    c.add_argument("--remote", default="origin", help="'' to use the local branch")
    c.add_argument("--contains-published", default="", help="tag glob of earlier releases SHA must contain")
    p = sub.add_parser("provenance")
    p.add_argument("--sha", required=True)
    p.add_argument("--platform", required=True)
    p.add_argument("--version", required=True)
    p.add_argument("--config", required=True)
    p.add_argument("--build", default="")
    p.add_argument("--run-url", default="")
    p.add_argument("--out", default="")
    sub.add_parser("lint")
    tr = sub.add_parser("triggers")
    tr.add_argument("--from", dest="frm", required=True)
    tr.add_argument("--to", required=True)
    e = sub.add_parser("entry-points")
    e.add_argument("--rev", default="", help="commit to read the workflow from (default: the working tree)")
    e.add_argument("--workflow", default="ota-publish.yml")
    sub.add_parser("self-test")
    a = ap.parse_args()
    return {"check": cmd_check, "provenance": cmd_provenance, "lint": cmd_lint, "self-test": cmd_self_test,
            "triggers": cmd_triggers, "entry-points": cmd_entry_points}[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main())
