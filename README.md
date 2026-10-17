# Charm Benchmarks

This repository defines LeanMD and ChaNGa runs on Kabré and records their
outcomes for the thesis. Tracing-tagged runs produce the Projections traces
consumed by CharmVZ.

## Repository layout

- [leanmd/bench.yml](leanmd/bench.yml) defines the LeanMD benchmark.
  [leanmd/runs.md](leanmd/runs.md) records its dated sessions;
  `leanmd/src/` is the instrumented application submodule.
- [changa/bench.yml](changa/bench.yml) defines the ChaNGa benchmark.
  [changa/runs.md](changa/runs.md) records its dated sessions;
  `changa/src/` is the instrumented application submodule. Its preprocess
  builds with `./configure` and `make` against `CHARM_DIR`, with the
  `deps/utility` submodule's `structures` library as `STRUCT_DIR`.
- [changa/tools/](changa/tools/) contains post-run scripts.
  `collect_timings.py` extracts per-run, per-big-step and per-load-balancer
  CSVs from a finished JUBE run directory. `physics_to_parquet.py` converts
  the per-substep physics side file to Parquet.
- [build-charm.sh](build-charm.sh) is the shared Slurm job that builds PAPI
  and four Charm++ variants into `deps/prefix`: base, Projections with PAPI,
  ChaNGa, and ChaNGa with Projections and PAPI. Submit it from the repo root.
- `deps/` contains the Charm++, PAPI and utility submodules.
- [docs/design-notes.md](docs/design-notes.md) explains build flags,
  benchmark parameters and instrumentation choices.

Both application submodules track private `thesis-instrumentation` forks
through SSH URLs. The ChaNGa fork emits `SimulationStep` and `GravityPhase`
brackets, per-substep statistics and a physics side file. The LeanMD fork
provides per-PE step tracking and per-cell domain rows.

Edit the scripts, benchmark definitions and Markdown documents directly.
READMEs have no separate export source. JUBE output directories, dependency
build products, and `*.err` / `*.out` logs are ignored by Git. The dated logs
retain historical commands and paths, including those used before the
2026-08-07 repository reorganization.

## Workflow

1. Submit `sbatch build-charm.sh` from the repo root to build dependencies.
2. Run the benchmark definition through JUBE. LeanMD needs `base` or `tracing`.
   ChaNGa needs one tag from each pair: `base` / `tracing` and `cosmo` / `poisson`.
   Optional ChaNGa tags are `dedicated`, `ppn`, `ppnhyper` and `overhead`.
3. Record the commands and outcomes in that benchmark's `runs.md`.

For example, from the repo root:

```sh
jube run leanmd/bench.yml --include-path <jube>/platform/slurm --tag tracing
jube run changa/bench.yml --include-path <jube>/platform/slurm --tag tracing cosmo
```

`outpath` is resolved relative to the benchmark definition. Outputs are under
`leanmd/leanmd_bench/` or `changa/changa_bench/`; `jube info` reports the run
path relative to the directory where JUBE was invoked. Trace archives initially
remain in those numbered run directories. Preserve required traces and side
files elsewhere before clearing a run directory for quota. The `overhead` tag
deletes trace archives after measuring their size and is unsuitable for trace
retention.
