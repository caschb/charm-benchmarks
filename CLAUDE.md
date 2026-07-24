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
emacs --batch -l org --eval '(org-babel-tangle-file "bench-leanmd.org")'
emacs --batch -l org --eval '(org-babel-tangle-file "bench-changa.org")'
```

This produces `build-charm.sh`, `bench-leanmd.yml`, and `bench-changa.yml`
respectively (all gitignored — never hand-edit the tangled output, edit the
`.org` source and re-tangle). Tangle only blocks with a `:tangle <file>`
header; blocks using `:session *Shell* :async yes` are historical run
transcripts (now living under `runs/`), not generators — don't try to
tangle or batch-evaluate those.

On the cluster, the actual workflow is:

```sh
sbatch build-charm.sh                      # builds PAPI, Charm++ (base/Projections/Changa/Changa+Projections variants)
jube run bench-leanmd.yml --include-path <path-to-jube>/platform/slurm --tag base      # or bench-changa.yml, --tag tracing
jube continue leanmd_bench --id <id>       # check/advance job status (changa_bench for ChaNGa runs)
```

## Architecture

**Literate generation pipeline.** Each `.org` file at the repo root is the
source of truth for one generated artifact, assembled from named,
noweb-referenced (`<<name>>`) source blocks (see `bench-leanmd.org`'s
`global_parameters`, `system_parameters`, etc. building up the final
`parameterset:`/`step:` blocks). Reading just the final tangled YAML/shell
script loses this structure — to understand *why* a parameter has a given
value, read the corresponding named block and its surrounding prose in the
`.org` file.

- `building-charm.org` → `build-charm.sh`: a single SLURM job that builds
  PAPI, then four Charm++ variants — `charm-base`, `charm-projections`,
  `charm-changa`, `charm-changa-projections` (consistently named: base
  variant name, `-projections` suffix for the PAPI-instrumented tracing
  build) — into `deps/prefix/`, each skipped if already built.
- `bench-leanmd.org` → `bench-leanmd.yml`: a JUBE benchmark definition with
  two tags — `base` (plain) and `tracing` (built with `-tracemode
  projections`, runs with `+logsize`, archives the trace on completion).
  The tag-gated preprocess/executable/args pattern, and shared
  system/input/exec parameter sets, is the template `bench-changa.org`
  follows.
- `bench-changa.org` → `bench-changa.yml`: the same `base`/`tracing` JUBE
  definition for ChaNGa. Diverges from LeanMD where ChaNGa's build forces
  it to: preprocess runs `git clone --local` from the `changa` submodule
  into the workpackage instead of using a JUBE `fileset` copy (ChaNGa
  generates `cha_commitid.c` via `git describe` at build time, which needs
  an intact `.git`, and a plain file copy also can't guarantee the source
  tree is free of build byproducts from other work); then `./configure`
  is pointed at the right Charm++ variant via `CHARM_DIR` and at a
  per-workpackage copy of the `deps/utility` submodule's `structures`
  library via `STRUCT_DIR` (isolating each workpackage's build — the
  alternative, configuring in place inside `deps/utility`, would race
  across concurrently running node-count/problem-size combinations).
  Input scaling uses `testdata`'s synthetic Poisson-cube generator (the
  ChaNGa README's own recommendation for performance benchmarking),
  swept via a `problem_size` parameter analogous to LeanMD's `nodes`
  sweep.
- `runs/<benchmark>.org`: dated log of actual JUBE sessions on Kabré (what
  was submitted, whether it completed). This is where session transcripts
  belong — never paste them back into `README.org`, which is kept as pure
  orientation (purpose/layout/workflow only). Only `runs/leanmd.org` exists
  so far; a `runs/changa.org` follows the same convention once ChaNGa runs
  actually happen on Kabré.

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
`deps/charm`, `deps/papi` are build dependencies; `deps/utility` is a
third build dependency — ChaNGa links against its `structures`
subdirectory (Tipsy I/O, `libTipsy.a`) but doesn't vendor it, and it isn't
part of the `charm`/`papi` build in `building-charm.org` — ChaNGa's own
`./configure` builds it (via `STRUCT_DIR`) as part of `make`. All are
pulled in as git submodules, not vendored.

**Gitignore boundary.** Everything generated is ignored: tangled outputs
(`*.yml`, `*.sh`), job logs (`*.err`, `*.out`), build byproducts
(`deps/build*`, `deps/prefix`), and JUBE's benchmark output directories
(`leanmd_bench/`, `changa_bench/`). Only `.org` sources and `runs/*.org`
logs are tracked — if you find yourself wanting to commit anything else,
check whether it belongs in `.gitignore` instead.
