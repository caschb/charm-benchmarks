# AGENTS.md

This repository defines LeanMD and ChaNGa benchmark runs on Kabré. Its main
output is Projections traces for the thesis, not standalone benchmark results.

## Layout

| Path | Purpose |
|---|---|
| `build-charm.sh` | builds PAPI and required Charm++ variants into `deps/prefix/` |
| `leanmd/bench.yml`, `changa/bench.yml` | JUBE definitions |
| `<program>/src` | benchmark program submodule |
| `changa/tools/` | post-run timing and physics conversion scripts |
| `<program>/runs.org` | append-only run-session log |
| `docs/design-notes.org` | rationale for non-obvious settings |

Edit `bench.yml` and `build-charm.sh` directly. Keep generated artifacts out of
git. When changing a non-obvious setting, read and update `docs/design-notes.org`
in the same commit.

## Cluster workflow

Follow the `kabre-cluster` skill for access and allocation details.

```sh
sbatch build-charm.sh
jube run leanmd/bench.yml --include-path <jube>/platform/slurm --tag base
jube run leanmd/bench.yml --include-path <jube>/platform/slurm --tag tracing
jube run changa/bench.yml --include-path <jube>/platform/slurm --tag tracing cosmo
jube continue <program>/<program>_bench --id <id>
```

ChaNGa requires one tag from each pair: `base`/`tracing` and `cosmo`/`poisson`.
Optional layout tags are `dedicated`, `ppn`, and `ppnhyper`; `overhead` enables
the base-versus-tracing measurement. Preserve the tag-derived `arm` and
`layout` parameters so exported CSVs remain distinguishable.

## Critical JUBE and source rules

- `$jube_benchmark_home` is the program directory, not the repository root.
  Set `repo_root` relative to it and keep shared dependencies under `deps/`.
- Keep commas out of JUBE `_: |` block scalars: JUBE splits parameter values on
  commas, including comments inside the block.
- ChaNGa preprocessing must clone its source with `.git` intact because its
  build uses `git describe`. Configure each workpackage with its own
  `deps/utility/structures` copy to avoid concurrent-build races.
- `changa/src` is the private `thesis-instrumentation` fork. Keep the tracing
  changes additive and preserve its `upstream` remote.
- All dependencies under `deps/` and program sources are submodules. Run
  `git submodule sync --recursive` and `git submodule update --init --recursive`
  after path or checkout changes.

## Trace and physics contracts

- The Projections variants use `-DZLIB=1`; archive `.log` or `.log.gz`, `.sts`,
  and `.projrc` from tracing runs. Treat JUBE run directories as temporary and
  pull artifacts that must survive quota cleanup.
- `SimulationStep` and `GravityPhase` are event-name contracts with
  `charmvz-cpp`. Their `nestedID` is the run-global phase counter; do not rename
  either without updating the consumer and the physics join.
- The instrumentation writes `ActiveRung`, `SubstepDt`, and `HeapBytes` user
  statistics. Keep IDs `readonly` in `ParallelGravity.ci`; record `HeapBytes`
  once per process from `/proc/self/statm`.
- `physics_to_parquet.py` converts `<achOutName>.physics.csv`. The downstream
  join is on `(index, phase)`.

## Run records and overhead

Append outcomes to the appropriate `runs.org`; do not rewrite dated entries.
The `overhead` tag measures the whole tracing stack. It uses repetitions and
deletes trace archives after reporting their size to control cluster storage;
those runs are not trace-retention runs.
