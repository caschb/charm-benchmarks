#!/usr/bin/env python3
"""Scrape the timings of finished JUBE workpackages into two tidy CSVs.

Usage:

    ./collect_timings.py OUTDIR RUNDIR [RUNDIR ...]

where each RUNDIR is a numbered JUBE run directory (changa_bench/000004 and
so on) and OUTDIR is where runs.csv and steps.csv are written.

Two files rather than one because the measurements have two grains and
flattening them would repeat the run-level columns sixteen times:

runs.csv
    One row per workpackage.  Carries the parameters that identify the cell
    -- arm, layout, rep, nodes, PE count -- and the two run-level timings:
    the `real` line bash's `time` keyword wrote around mpirun, and ChaNGa's
    own "KillAT: Stopping after" line bounding the simulation loop.

steps.csv
    One row per big step per workpackage.  This is the grain the
    base-vs-tracing comparison actually wants: step i does identical physics
    in both arms, so the two arms pair step by step and a cell yields as many
    paired differences as it ran steps.

`jube result` covers runs.csv's columns through the result table in
bench.yml and is the better route when that is all you need.  This script
exists for steps.csv, which JUBE can only aggregate, and it reads the same
files, so the two agree by construction.

Parameters come from the run directory's workpackages.xml rather than from
the "JUBE arm ..." echo in job.out: that echo is a convenience for reading a
job.out by eye, while workpackages.xml is what JUBE itself resolved.
"""

import argparse
import csv
import os
import re
import sys
import xml.etree.ElementTree as ET

# Parameters copied into both CSVs.  arm, layout and rep exist only because
# tags do not reach parameter.xml; see docs/design-notes.org.
WANTED = [
    "arm",
    "layout",
    "rep",
    "nodes",
    "taskspernode",
    "threadspertask",
    "total_pes",
    "ppn_flag",
    "problem_size",
    "nsteps",
    "killat",
    "deta",
    "ioutinterval",
]

PPN_RE = re.compile(r"\+ppn\s+(\d+)")

BIG_STEP_RE = re.compile(r"^Big step (\d+) took ([\d.eE+-]+) seconds\.")
KILLAT_RE = re.compile(r"^KillAT: Stopping after ([\d.eE+-]+) seconds")
REAL_RE = re.compile(r"^real\s+(\d+)m([\d.]+)s")
# Charm++ prints this when the Projections buffer filled mid-run.  A run that
# flushed is not a slow good run -- Charm++ disclaims its timing data -- so it
# must never be silently averaged in.  See design-notes.org on +logsize.
FLUSH_RE = re.compile(r"Projections log flushed to disk|performance data is likely invalid")


def workpackage_params(rundir):
    """Map workpackage id -> {parameter name: resolved value}."""
    tree = ET.parse(os.path.join(rundir, "workpackages.xml"))
    out = {}
    for wp in tree.getroot().iter("workpackage"):
        params = {}
        for p in wp.iter("parameter"):
            name = p.get("name")
            if name not in WANTED:
                continue
            # <selection> holds the value after JUBE resolved $references and
            # picked one element of a swept list; <value> is the raw text and
            # is all there is for a parameter that needed neither.
            sel = p.find("selection")
            node = sel if sel is not None else p.find("value")
            params[name] = node.text.strip() if node is not None and node.text else ""
        out[int(wp.get("id"))] = params
    return out


def worker_pes(params):
    """Charm++ worker threads, which `total_pes` is not.

    total_pes is nodes * taskspernode * oversubscription, i.e. what reaches
    mpirun as -np, and under the ppn layouts that is one rank per host driving
    N workers. A run labelled total_pes = 4 there is a 76-PE run. Comparing
    layouts on total_pes silently compares 4 PEs against 80.
    """
    try:
        ranks = int(params.get("total_pes", "") or 0)
    except ValueError:
        return ""
    m = PPN_RE.search(params.get("ppn_flag", "") or "")
    # Without +ppn each rank is one worker plus its own comm thread.
    return ranks * (int(m.group(1)) if m else 1)


def scan_workpackage(workdir):
    """Pull the timings out of one workpackage's job.out and job.err."""
    steps, killat, real, flushed = [], "", "", False

    out_path = os.path.join(workdir, "job.out")
    if os.path.exists(out_path):
        with open(out_path, errors="replace") as fh:
            for line in fh:
                m = BIG_STEP_RE.match(line)
                if m:
                    steps.append((int(m.group(1)), float(m.group(2))))
                    continue
                m = KILLAT_RE.match(line)
                if m:
                    killat = float(m.group(1))
                    continue
                if FLUSH_RE.search(line):
                    flushed = True

    err_path = os.path.join(workdir, "job.err")
    if os.path.exists(err_path):
        with open(err_path, errors="replace") as fh:
            for line in fh:
                m = REAL_RE.match(line)
                if m:
                    real = int(m.group(1)) * 60 + float(m.group(2))
                if FLUSH_RE.search(line):
                    flushed = True

    return steps, killat, real, flushed


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("outdir")
    ap.add_argument("rundirs", nargs="+")
    args = ap.parse_args()

    os.makedirs(args.outdir, exist_ok=True)
    run_rows, step_rows = [], []

    for rundir in args.rundirs:
        rundir = rundir.rstrip("/")
        run_id = os.path.basename(rundir)
        params = workpackage_params(rundir)

        for wp_id in sorted(params):
            workdir = os.path.join(rundir, "%06d_run-program" % wp_id, "work")
            done = os.path.exists(os.path.join(workdir, "ready"))
            failed = os.path.exists(os.path.join(workdir, "error"))
            steps, killat, real, flushed = scan_workpackage(workdir)

            row = {"run_id": run_id, "wp": wp_id}
            row.update({k: params[wp_id].get(k, "") for k in WANTED})
            row.update({
                "worker_pes": worker_pes(params[wp_id]),
                "done": int(done),
                "failed": int(failed),
                # A cell that flushed its Projections buffer, or that ran a
                # different number of steps than its partner, is not
                # comparable; both are recorded rather than dropped here so
                # the exclusion is visible downstream.
                "flushed": int(flushed),
                "n_steps_logged": len(steps),
                "run_wall_s": real,
                "sim_loop_s": killat,
                "step_sum_s": round(sum(t for _, t in steps), 6) if steps else "",
            })
            run_rows.append(row)

            for step, seconds in steps:
                step_rows.append({
                    "run_id": run_id,
                    "wp": wp_id,
                    **{k: params[wp_id].get(k, "") for k in WANTED},
                    "worker_pes": worker_pes(params[wp_id]),
                    "step": step,
                    "seconds": seconds,
                })

    if not run_rows:
        sys.exit("no workpackages found")

    runs_csv = os.path.join(args.outdir, "runs.csv")
    with open(runs_csv, "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(run_rows[0].keys()))
        w.writeheader()
        w.writerows(run_rows)

    steps_csv = os.path.join(args.outdir, "steps.csv")
    with open(steps_csv, "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(step_rows[0].keys()))
        w.writeheader()
        w.writerows(step_rows)

    print("%s: %d rows" % (runs_csv, len(run_rows)))
    print("%s: %d rows" % (steps_csv, len(step_rows)))

    incomplete = [r for r in run_rows if not r["done"] or r["failed"]]
    if incomplete:
        print("WARNING: %d workpackage(s) not cleanly done: %s"
              % (len(incomplete), ", ".join("%s/%d" % (r["run_id"], r["wp"]) for r in incomplete)))
    flushed = [r for r in run_rows if r["flushed"]]
    if flushed:
        print("WARNING: %d workpackage(s) flushed the Projections buffer; their timings are invalid: %s"
              % (len(flushed), ", ".join("%s/%d" % (r["run_id"], r["wp"]) for r in flushed)))


if __name__ == "__main__":
    main()
