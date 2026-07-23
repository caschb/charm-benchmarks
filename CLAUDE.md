# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A record of Charm++ benchmark runs (LeanMD, ChaNGa) for a thesis, run on the
Kabré cluster (CeNAT). The performance numbers are secondary — the actual
goal is the Projections *traces* the `tracing`-tagged runs produce, which
feed a separate trace-analysis program. Everything here — build steps,
JUBE benchmark definitions, session logs — is written as literate Org-mode
files so the reasoning behind each decision stays attached to the
generated artifact, not just the artifact itself.

## Commands

There is no traditional build/lint/test suite. The only "build" step is
tangling Org files into the scripts/config they define:

```sh
emacs --batch -l org --eval '(org-babel-tangle-file "building-charm.org")'
emacs --batch -l org --eval '(org-babel-tangle-file "bench_leanmd.org")'
```

This produces `build-charm.sh` and `bench_leanmd.yml` respectively (both
gitignored — never hand-edit the tangled output, edit the `.org` source and
re-tangle). Tangle only blocks with a `:tangle <file>` header; blocks using
`:session *Shell* :async yes` are historical run transcripts (now living
under `runs/`), not generators — don't try to tangle or batch-evaluate those.

On the cluster, the actual workflow is:

```sh
sbatch build-charm.sh                      # builds PAPI, Charm++ (base/Projections/Changa variants)
jube run bench_leanmd.yml --include-path <path-to-jube>/platform/slurm --tag base      # or --tag tracing
jube continue leanmd_bench --id <id>       # check/advance job status
```

## Architecture

**Literate generation pipeline.** Each `.org` file at the repo root is the
source of truth for one generated artifact, assembled from named,
noweb-referenced (`<<name>>`) source blocks (see `bench_leanmd.org`'s
`global_parameters`, `system_parameters`, etc. building up the final
`parameterset:`/`step:` blocks). Reading just the final tangled YAML/shell
script loses this structure — to understand *why* a parameter has a given
value, read the corresponding named block and its surrounding prose in the
`.org` file.

- `building-charm.org` → `build-charm.sh`: a single SLURM job that builds
  PAPI, then four Charm++ variants (base, Projections+PAPI-instrumented,
  Changa target, Changa+Projections target) into `deps/prefix/`, each
  skipped if already built.
- `bench_leanmd.org` → `bench_leanmd.yml`: a JUBE benchmark definition with
  two tags — `base` (plain) and `tracing` (built with `-tracemode
  projections`, runs with `+logsize`, archives the trace on completion).
  The same pattern (tag-gated preprocess/executable/args, shared
  system/input/exec parameter sets) is the template to follow for adding
  benchmarks beyond LeanMD (e.g. a future `bench_changa.org`).
- `runs/<benchmark>.org`: dated log of actual JUBE sessions on Kabré (what
  was submitted, whether it completed). This is where session transcripts
  belong — never paste them back into `README.org`, which is kept as pure
  orientation (purpose/layout/workflow only).

**Trace path.** Tracing-tagged runs' postprocess step tars up `*.log*
*.sts *.projrc` from the work directory — verified against
`deps/charm/src/ck-perf/trace-projections.C` (`createLog`/`createSts`/
`createRC`) to be the complete file set Projections writes, so that glob
is exhaustive by construction, not just "probably enough". Trace archives
are deliberately left inside JUBE's own numbered run directory (reported
by `jube run`/`jube info`, e.g. `leanmd_bench/<id>/...`) — nothing copies
or indexes them elsewhere, so that reported path is the real way to find a
given run's trace.

**Submodules.** `leanmd/`, `changa/` are the benchmark program sources;
`deps/charm`, `deps/papi` are build dependencies. All are pulled in as git
submodules, not vendored.

**Gitignore boundary.** Everything generated is ignored: tangled outputs
(`*.yml`, `*.sh`), job logs (`*.err`, `*.out`), build byproducts
(`deps/build*`, `deps/prefix`), and JUBE's benchmark output directories
(`leanmd_bench/`). Only `.org` sources and `runs/*.org` logs are tracked —
if you find yourself wanting to commit anything else, check whether it
belongs in `.gitignore` instead.
