#!/usr/bin/env python3
"""parse.py DIR  -> per-version per-phase medians/spread from [STARTUP] lines in DIR/<ver>_<i>.log"""
import sys, re, glob, os, statistics as st
from collections import defaultdict, OrderedDict
d = sys.argv[1]
runs = defaultdict(list)
for f in sorted(glob.glob(os.path.join(d, '*.log'))):
    base = os.path.basename(f)[:-4]
    ver = base.rsplit('_', 1)[0]
    marks = OrderedDict()
    for line in open(f, errors='replace'):
        m = re.match(r'\[STARTUP\]\s+([\d.]+) ms\s+(.*)$', line.rstrip())
        if m:
            lab = re.sub(r'\(.*?\)', '()', m.group(2))
            lab = re.sub(r'\d+ ms', 'N ms', lab)
            if lab not in marks:
                marks[lab] = float(m.group(1))
    if marks:
        runs[ver].append(marks)
for ver, rs in runs.items():
    print(f"\n=== {ver}: {len(rs)} runs")
    labels = list(rs[0].keys())
    prev = None
    for lab in labels:
        vals = [r[lab] for r in rs if lab in r]
        if prev is not None:
            deltas = [r[lab] - r[prev] for r in rs if lab in r and prev in r]
        else:
            deltas = [0]
        print(f"  {st.median(vals):9.1f} ms (min {min(vals):8.1f} max {max(vals):8.1f})  d={st.median(deltas):7.1f} [{min(deltas):7.1f}..{max(deltas):7.1f}]  {lab}")
        prev = lab
