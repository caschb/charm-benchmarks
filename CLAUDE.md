# CLAUDE.md

<!-- docs-sync: git-sha=b1bc8b44b37c3c532c0a1f20fcbc485a32d30c7e -->

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
source checkout as `src/`. A program that needs post-run scripts keeps them
in its own `tools/`; only `changa/tools/` exists so far. Anything both
consume stays at the top level: `build-charm.sh`, `deps/`,
`docs/design-notes.org`.

When adding a third benchmark, copy that shape; don't reintroduce
root-level `bench-<name>.yml` or a shared `runs/` directory.

## Commands

There is no build/lint/test suite, and no generation step. Edit the files
directly.

On the cluster, the workflow is:

```sh
sbatch build-charm.sh                      # from the repo root; builds PAPI, Charm++ (base/Projections/Changa/Changa+Projections variants)
jube run leanmd/bench.yml --include-path <path-to-jube>/platform/slurm --tag base      # or --tag tracing
jube run changa/bench.yml --include-path <path-to-jube>/platform/slurm --tag tracing cosmo
jube continue leanmd/leanmd_bench --id <id>  # check/advance job status (changa/changa_bench for ChaNGa runs)
```

`changa/bench.yml` needs **one tag from each mandatory pair** — `base`/`tracing`
and `cosmo`/`poisson`. Omitting an IC tag leaves `ic_param_file`, `ic_infile`,
`ic_generate`, `nsteps` and `problem_size` undefined so JUBE fails rather than
silently picking one. Three optional tags stack on top: `dedicated`, `ppn` and
`ppnhyper` select a core layout (untagged is `taskpercore`), and `overhead`
turns the run into the base-vs-tracing measurement described below.

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
- `changa/bench.yml`: the `base`/`tracing` JUBE definition for
  ChaNGa, plus the initial-condition, layout and `overhead` tag axes above.
  Diverges from LeanMD where ChaNGa's build forces
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
  The two initial conditions are separate experiments, not a swept
  dimension: `cosmo` is ChaNGa's committed `cube300` LCDM condition and is
  the primary case, `poisson` is its control, synthesised per run by
  `testdata`'s generator at the swept `problem_size`. `cube300` has a fixed
  particle count and cannot be resized, so a `problem_size` cross product
  over both would be mostly meaningless cells.
- `changa/tools/`: post-run scripts, run off the cluster against a finished
  JUBE run directory. `collect_timings.py` scrapes `runs.csv` (one row per
  workpackage), `steps.csv` (one row per big step) and `lb.csv` (one row per
  load-balancer invocation) out of the numbered run directories;
  `steps.csv` is the grain the base-vs-tracing comparison wants, because
  step *i* does identical physics in both arms. `physics_to_parquet.py`
  converts ChaNGa's `<achOutName>.physics.csv` side file to Parquet.
  Neither writes Parquet from inside ChaNGa on purpose: that would mean
  linking Arrow into ChaNGa's build on Kabré and putting the write cost
  inside the run being timed.
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

**Editing a `bench.yml`.** Text inside a `_: |` block scalar becomes a JUBE
parameter value and JUBE splits parameter values on commas, so a single comma
anywhere in a preprocess body — including in a shell comment — chops the step
and only a fragment reaches `submit.job`. Keep block bodies comma-free;
YAML-level `#` comments are stripped before JUBE sees them and are safe. Also
note that tags never appear in `parameter.xml` or in `jube result`, which is
why `arm` and `layout` exist as parameters set from the tags: without them,
CSVs from two invocations differing only by tag are indistinguishable once
concatenated.

**JUBE paths.** `$jube_benchmark_home` is the directory holding the
`bench.yml`, i.e. `leanmd/` or `changa/` — *not* the repo root. Each
`bench.yml` therefore defines `repo_root: $jube_benchmark_home/..` and
reaches the shared `deps/` through it; only `source_dir`
(`$jube_benchmark_home/src`) is program-local. `outpath` is resolved the
same way, so a bare `leanmd_bench` puts JUBE's output directory inside
`leanmd/` — verified on Kabré, where `jube run leanmd/bench.yml` from the
repo root reports its handle relative to the invoking directory, not to the
`bench.yml`. Run-log entries from before 2026-08-07 name the old repo-root
location; those directories no longer exist on the cluster.

**The ChaNGa instrumentation.** The fork adds tracing calls on
`ProjectionsControl`, the group ChaNGa already uses for per-PE
`traceBegin()`/`traceEnd()`, broadcast from `Main` — it cannot live in `Main`
itself, which is a mainchare and exists only on PE 0. Two nested user-event
brackets: `SimulationStep` around a big step and `GravityPhase` around one
iteration of `advanceBigStep()`'s rung loop, the inner one because a big step
under multistepping runs several gravity phases with different active rungs.
Their `nestedID` carries a run-global monotonic counter. **The two event names
are the contract with `charmvz-cpp`**, which resolves them through the STS
`EVENT` registry; renaming either here means passing `-s <name>` there.
`beginPhase()` also records three user statistics — `ActiveRung`, `SubstepDt`
and `HeapBytes`. Everything is guarded by ChaNGa's own
`-DCHANGA_TRACE_TIMESTEPS`, not Charm++'s `CMK_TRACE_ENABLED`, which the CMake
build sets to the token `TRUE` and `#if` would evaluate as `0`.

Two failures here are worth not repeating, both derived at length in
`docs/design-notes.org`. Charm++'s `traceMemoryUsage()` was removed rather
than kept: it reaches glibc's `mallinfo()`, whose byte count is an `int` that
overflows past 2 GB, and every one of 5415 samples in a 19-PE `cube300` run
held exactly 2^63. `HeapBytes` reads `/proc/self/statm` instead, once per
*process* (`CkMyRank() == 0`), since RSS belongs to the process. And the three
stat ids must be declared `readonly` in `ParallelGravity.ci`: a plain global
is per-process in an SMP build, so every process not hosting `Main` recorded
all three statistics under stat id 0. The record *count* stays exactly right,
so **a single-node run cannot detect this** — two hosts is the smallest
configuration that can.

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
by `jube run`/`jube info`, e.g. `leanmd/leanmd_bench/<id>/...`) — nothing
copies or indexes them elsewhere, so that reported path is the real way to
find a given run's trace. JUBE prints it relative to the invoking
directory, not to the `bench.yml`.

**That makes the run directory the only copy, which is a retention problem
rather than a lookup one.** On 2026-08-12 the `work/` directories of
`changa_bench/000000`-`000008` were deleted to reclaim Lustre quota, taking
every trace archive in them; the run skeletons and JUBE metadata were kept so
the IDs in `changa/runs.org` still resolve and so JUBE keeps numbering from
`000009` rather than restarting at `000000`. Nothing about the layout above
changed — but treat a trace you still need as something to pull off the cluster
deliberately, because the quota will force this again. See the `[2026-08-12]`
entry in `changa/runs.org`.

The one exception is `tracing+overhead`, whose postprocess prints the trace's
size and then deletes it. That sweep exists to produce timings, not traces,
and its three repetitions would otherwise cost roughly 14 GB at `ppn19` and
three times that at `taskpercore` against a 100 GB quota. The logs are still
*written* — the cost of writing them is part of what is being measured.

**Measuring the instrumentation overhead.** The `base`/`tracing` pair is the
measurement, not a separate experiment, so what it reports is the whole
instrumentation stack at once: Charm++'s tracing runtime, the user-event
brackets and the side-file write all sit behind the single
`--enable-projections` flag. Three nested spans are collected, and their
differences are the interesting quantities — the sum of the `Big step N took`
lines is the simulation loop, ChaNGa's `KillAT` line minus that sum is setup,
and the `real` line minus `KillAT` is Charm++ startup plus the exit-time log
write. `real` comes from bash's `time` keyword, because `/usr/bin/time` is not
installed on Kabré. The `overhead` tag also sets `rep` to `1,2,3`; outside it
`rep` stays `1`, since a second trace of the same cell is not a second
observation of anything.

**Submodules.** `leanmd/src`, `changa/src` are the benchmark program
sources. `changa/src` is **not upstream**: it tracks `caschb/changa` on
branch `thesis-instrumentation`, forked from `N-BodyShop/changa` at `v3.5`,
because ChaNGa is modified here (see "The ChaNGa instrumentation" above). The fork
is private, so its `.gitmodules` entry is the one **SSH** URL among the five
— a private repo over HTTPS would need stored credentials and
`git submodule update --init` would fail on Kabré without them. A patch
applied by the preprocess was rejected as the alternative: `Makefile.in`
stamps every run's log with `git describe`, so an uncommitted patch would
have each instrumented run self-identify as unmodified `v3.5`. Upstream is
kept as a second remote (`upstream`) and the diff is additions-only, so a
version bump stays a cheap rebase — keep it that way.

`deps/charm`, `deps/papi` are build dependencies; `deps/utility` is
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
