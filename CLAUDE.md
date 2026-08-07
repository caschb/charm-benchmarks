# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A record of Charm++ benchmark runs (LeanMD, ChaNGa) for a thesis, run on the
Kabré cluster (CeNAT). The performance numbers are secondary — the actual
goal is the Projections *traces* the `tracing`-tagged runs produce, which
feed a separate trace-analysis program.

`build-charm.sh`, `leanmd/bench.yml` and `changa/bench.yml` are edited
directly and tracked in git. They used to be tangled out of literate
Org-mode sources; that indirection was removed (see "History" below), and
the reasoning those documents carried now lives in comments next to the
thing it explains, with the longer derivations in `docs/design-notes.org`.
Read that file before changing a flag that looks arbitrary — several of
them were paid for with failed cluster runs. The per-benchmark `runs.org`
session logs are still Org, because they never generated anything.

## Layout

One directory per benchmark program — `leanmd/` and `changa/` — each
holding that program's `bench.yml`, its `runs.org` session log, and its
source checkout as `src/`. Anything both consume stays at the top level:
`build-charm.sh`, `deps/`, `docs/design-notes.org`.

When adding a third benchmark, copy that shape; don't reintroduce
root-level `bench-<name>.yml` or a shared `runs/` directory.

## Commands

There is no build/lint/test suite, and no generation step. Edit the files
directly.

On the cluster, the workflow is:

```sh
sbatch build-charm.sh                      # from the repo root; builds PAPI, Charm++ (base/Projections/Changa/Changa+Projections variants)
jube run leanmd/bench.yml --include-path <path-to-jube>/platform/slurm --tag base      # or changa/bench.yml, --tag tracing
jube continue leanmd_bench --id <id>       # check/advance job status (changa_bench for ChaNGa runs)
```

## Architecture

**The three artifacts.**

- `build-charm.sh`: a single SLURM job that builds PAPI, then four Charm++
  variants — `charm-base`, `charm-projections`, `charm-changa`,
  `charm-changa-projections` (consistently named: base variant name,
  `-projections` suffix for the PAPI-instrumented tracing build) — into
  `deps/prefix/`, each skipped if already built. Deliberately *not* split
  per program even though variants 3-4 are ChaNGa-only: all four share one
  `deps/prefix` and one PAPI build, so two half-scripts would duplicate
  that stanza and race on the prefix.
- `leanmd/bench.yml`: a JUBE benchmark definition with two tags — `base`
  (plain) and `tracing` (built with `-tracemode projections`, runs with
  `+logsize`, archives the trace on completion). The tag-gated
  preprocess/executable/args pattern, and shared system/input/exec
  parameter sets, is the template `changa/bench.yml` follows.
- `changa/bench.yml`: the same `base`/`tracing` JUBE definition for
  ChaNGa. Diverges from LeanMD where ChaNGa's build forces
  it to: preprocess runs `git clone --local` from the `changa/src`
  submodule into the workpackage instead of using a JUBE `fileset` copy (ChaNGa
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
- `docs/design-notes.org`: the rationale behind the three artifacts above,
  organized by artifact. Anything that needed more than a few lines of
  explanation lives here rather than as a comment; the files cross-reference
  it. Update it in the same commit as the change it explains. Kept whole and
  shared rather than split into the two program directories, because its
  "Building Charm++" section is what both benchmarks consume and the ChaNGa
  section leans on it throughout.
- `<benchmark>/runs.org`: dated log of actual JUBE sessions on Kabré (what
  was submitted, whether it completed). This is where session transcripts
  belong — never paste them back into `README.org`, which is kept as pure
  orientation (purpose/layout/workflow only). Both `leanmd/runs.org` and
  `changa/runs.org` exist. These are historical records: correct a stale
  *link* in the orientation header, but don't rewrite what a dated entry
  says happened — append a follow-up note instead. Entries predating
  2026-08-07 describe the pre-reorganization layout (root-level
  `bench-*.yml`, `runs/`); that is recorded in each file's header rather
  than patched into the transcripts.

**JUBE paths.** `$jube_benchmark_home` is the directory holding the
`bench.yml`, i.e. `leanmd/` or `changa/` — *not* the repo root. Each
`bench.yml` therefore defines `repo_root: $jube_benchmark_home/..` and
reaches the shared `deps/` through it; only `source_dir`
(`$jube_benchmark_home/src`) is program-local. `outpath` is resolved the
same way and is set to `../<name>_bench`, keeping JUBE's output directories
at the repo root where every recorded trace path already points.

**Trace path.** The `-projections` Charm++ variants are built with `-DZLIB=1`,
so the runtime writes **gzipped** logs (`.log.gz`). The explicit numeric `1`
matters and is not the same as leaving `ZLIB` at its default — see the long
derivation in `docs/design-notes.org` before touching that flag. The consuming
tool (`charmvz-cpp`, a sibling repo) reads plain and gzipped logs
transparently, so this is a size win with no downstream cost.

Tracing-tagged runs' postprocess step tars up `*.log*
*.sts *.projrc` from the work directory — the `*.log*` glob deliberately
covers both `.log` and `.log.gz` — verified against
`deps/charm/src/ck-perf/trace-projections.C` (`createLog`/`createSts`/
`createRC`) to be the complete file set Projections writes, so that glob
is exhaustive by construction, not just "probably enough". Trace archives
are deliberately left inside JUBE's own numbered run directory (reported
by `jube run`/`jube info`, e.g. `leanmd_bench/<id>/...`) — nothing copies
or indexes them elsewhere, so that reported path is the real way to find a
given run's trace.

**Submodules.** `leanmd/src`, `changa/src` are the benchmark program
sources; `deps/charm`, `deps/papi` are build dependencies; `deps/utility` is
a third build dependency — ChaNGa links against its `structures`
subdirectory (Tipsy I/O, `libTipsy.a`) but doesn't vendor it, and it isn't
part of the `charm`/`papi` build in `build-charm.sh` — ChaNGa's own
`./configure` builds it (via `STRUCT_DIR`) as part of `make`. All are
pulled in as git submodules, not vendored. `deps/utility` stays under
`deps/` despite being ChaNGa-only: `deps/` is the build-dependency axis,
not the per-program one.

The two program submodules were moved into `<program>/src` on 2026-08-07;
their `.gitmodules` *section names* are still `leanmd` and `changa` (git mv
rewrites `path`, not the section name), so `.git/modules/leanmd` is
`leanmd/src`'s git dir. That mismatch is expected. A checkout that predates
the move needs `git submodule sync --recursive` after pulling, or it will
look for them at the old paths.

**Gitignore boundary.** What's ignored is what a run *produces*: job logs
(`*.err`, `*.out`), build byproducts (`deps/build*`, `deps/prefix`), and
JUBE's benchmark output directories (`leanmd_bench/`, `changa_bench/`;
those patterns have no leading slash, so they match at any depth).
Everything a run *consumes* is tracked, including `build-charm.sh` and the
two `bench.yml` files. Do not re-add `*.yml` / `*.sh` globs — they were
there when those files were tangled output, and reinstating them would
silently untrack the real sources.

## History

The three artifacts were generated by `org-babel-tangle` from
`building-charm.org`, `bench-leanmd.org` and `bench-changa.org` until
2026-08-07, when those sources were removed (commits `4fe63e7`, `1714cb6`,
`9ac2872`). Two consequences worth knowing:

- Kabré has no `emacs`, so the `.yml` files previously had to be tangled
  locally and `rsync`ed up. That is no longer true; `git pull` is enough.
  Run logs written before that date may still say otherwise.
- If you need the pre-migration prose in its original form, it is in git
  history, not in a working file.

Later the same day the repo was reorganized into the per-program directories
described under "Layout". Before that, both definitions sat at the root as
`bench-leanmd.yml` and `bench-changa.yml`, the two submodules were checked
out at `leanmd/` and `changa/`, and the session logs were `runs/leanmd.org`
and `runs/changa.org`. Anything written before 2026-08-07 — run-log entries,
commit messages, notes in sibling repos — uses those paths.
