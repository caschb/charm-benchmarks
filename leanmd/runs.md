# LeanMD run log

Session log of actual `jube` invocations against LeanMD's `bench.yml`
on Kabré: what was submitted, whether it finished, and anything
unusual. See [bench.yml](bench.yml) for the benchmark definition itself
and [README.md](../README.md) for how the pieces of this repo fit together.

Entries dated before \[2026-08-07\] were written when this file was
`runs/leanmd.org` and the benchmark definition was `bench-leanmd.yml` at the
repo root. Their paths are left as they were recorded. One ChaNGa session
that had been logged here, \[2026-07-24 Fri\], moved to [changa/runs.md](../changa/runs.md) in that
same reorganization.

## \[2026-07-23 Thu\]

I've installed and added jube to the PATH variable

``` bash
jube --version
```

    JUBE, version 2.7.1

Let's check our queue just in case

``` bash
squeue -u casch
```

    JOBID PARTITION     NAME     USER ST       TIME  NODES NODELIST(REASON)

We first run the base version of the benchmarks, that is, without
using projections.

``` bash
jube run ../bench-leanmd.yml \
     --include-path /data/casch/JUBE/platform/slurm \
     --tag base
```

    ######################################################################
    # benchmark: leanmd
    # id: 0
    #
    #
    ######################################################################

    Running workpackages (#=done, 0=wait, E=error):
    000000000000000000000000000000000000000000000000000000000000 (  0/  3)

      |    stepname | all | open | wait | error | done |
      |-------------|-----|------|------|-------|------|
      | run-program |   3 |    0 |    3 |     0 |    0 |

    >>>> Benchmark information and further useful commands:
    >>>>       id: 0
    >>>>   handle: ../leanmd_bench
    >>>>      dir: ../leanmd_bench/000000
    >>>> continue: jube continue ../leanmd_bench --id 0
    >>>>  analyse: jube analyse ../leanmd_bench --id 0
    >>>>   result: jube result ../leanmd_bench --id 0
    >>>>     info: jube info ../leanmd_bench --id 0
    >>>>      log: jube log ../leanmd_bench --id 0
    ######################################################################

``` bash
jube continue ../leanmd_bench --id 0
```

    ######################################################################
    # benchmark: leanmd
    # id: 0
    #
    #
    ######################################################################

    Running workpackages (#=done, 0=wait, E=error):
    ########################################00000000000000000000 (  2/  3)

      |    stepname | all | open | wait | error | done |
      |-------------|-----|------|------|-------|------|
      | run-program |   3 |    0 |    1 |     0 |    2 |

    >>>> Benchmark information and further useful commands:
    >>>>       id: 0
    >>>>   handle: ../leanmd_bench
    >>>>      dir: ../leanmd_bench/000000
    >>>> continue: jube continue ../leanmd_bench --id 0
    >>>>  analyse: jube analyse ../leanmd_bench --id 0
    >>>>   result: jube result ../leanmd_bench --id 0
    >>>>     info: jube info ../leanmd_bench --id 0
    >>>>      log: jube log ../leanmd_bench --id 0
    ######################################################################

There is one job stuck because of resources, that's okay for now

``` bash
squeue -u casch
```

    JOBID PARTITION     NAME     USER ST       TIME  NODES NODELIST(REASON)
                595960 kura-wide leanmd_r    casch PD       0:00      4 (Resources)
                595958 kura-wide leanmd_r    casch  R       0:19      1 kura-1d.cnca
                595959 kura-wide leanmd_r    casch  R       0:19      2 kura-2a.cnca,kura-2b.cnca

Base version works. Now that we know that the base version is
working, we'll run the Projections version.

``` bash
jube run ../bench-leanmd.yml \
     --include-path /data/casch/JUBE/platform/slurm \
     --tag tracing
```

    ######################################################################
    # benchmark: leanmd
    # id: 1
    #
    #
    ######################################################################

    Running workpackages (#=done, 0=wait, E=error):
    000000000000000000000000000000000000000000000000000000000000 (  0/  3)

      |    stepname | all | open | wait | error | done |
      |-------------|-----|------|------|-------|------|
      | run-program |   3 |    0 |    3 |     0 |    0 |

    >>>> Benchmark information and further useful commands:
    >>>>       id: 1
    >>>>   handle: ../leanmd_bench
    >>>>      dir: ../leanmd_bench/000001
    >>>> continue: jube continue ../leanmd_bench --id 1
    >>>>  analyse: jube analyse ../leanmd_bench --id 1
    >>>>   result: jube result ../leanmd_bench --id 1
    >>>>     info: jube info ../leanmd_bench --id 1
    >>>>      log: jube log ../leanmd_bench --id 1
    ######################################################################

``` bash
jube continue ../leanmd_bench --id 1
```

    ######################################################################
    # benchmark: leanmd
    # id: 1
    #
    #
    ######################################################################

    Running workpackages (#=done, 0=wait, E=error):
    000000000000000000000000000000000000000000000000000000000000 (  0/  3)

      |    stepname | all | open | wait | error | done |
      |-------------|-----|------|------|-------|------|
      | run-program |   3 |    0 |    3 |     0 |    0 |

    >>>> Benchmark information and further useful commands:
    >>>>       id: 1
    >>>>   handle: ../leanmd_bench
    >>>>      dir: ../leanmd_bench/000001
    >>>> continue: jube continue ../leanmd_bench --id 1
    >>>>  analyse: jube analyse ../leanmd_bench --id 1
    >>>>   result: jube result ../leanmd_bench --id 1
    >>>>     info: jube info ../leanmd_bench --id 1
    >>>>      log: jube log ../leanmd_bench --id 1
    ######################################################################

It seems like this is stuck

``` bash
cat ../leanmd_bench/000001/000000_run-program/work/job.err
```

    + export OMP_NUM_THREADS=1
    + OMP_NUM_THREADS=1
    + module purge
    ++ /opt/Modules/3.2.10/bin/modulecmd bash purge
    + eval MODULEPATH=/opt/libs/modulefiles:/opt/tools/modulefiles:/opt/compilers/modulefiles:/opt/python/modulefiles:/opt/bioinf/modulefiles ';export' 'MODULEPATH;'
    ++ MODULEPATH=/opt/libs/modulefiles:/opt/tools/modulefiles:/opt/compilers/modulefiles:/opt/python/modulefiles:/opt/bioinf/modulefiles
    ++ export MODULEPATH
    + module load mpich/3.1.4-gcc-9.3.0 gcc/9.3.0
    ++ /opt/Modules/3.2.10/bin/modulecmd bash load mpich/3.1.4-gcc-9.3.0 gcc/9.3.0
    + eval CPATH=/opt/compilers/gcc-9.3.0/include:/opt/tools/mpich-3.1.4-gcc-9.3.0/include ';export' 'CPATH;INCLUDE=/opt/compilers/gcc-9.3.0/include' ';export' 'INCLUDE;INFOPATH=/opt/compilers/gcc-9.3.0/share/info' ';export' 'INFOPATH;LD_LIBRARY_PATH=/opt/compilers/gcc-9.3.0/lib64:/opt/compilers/gcc-9.3.0/lib:/opt/tools/mpich-3.1.4-gcc-9.3.0/lib' ';export' 'LD_LIBRARY_PATH;LIBRARY_PATH=/opt/compilers/gcc-9.3.0/lib64:/opt/compilers/gcc-9.3.0/lib:/opt/tools/mpich-3.1.4-gcc-9.3.0/lib' ';export' 'LIBRARY_PATH;LOADEDMODULES=mpich/3.1.4-gcc-9.3.0:gcc/9.3.0' ';export' 'LOADEDMODULES;MANPATH=/opt/compilers/gcc-9.3.0/share/man:/opt/tools/mpich-3.1.4-gcc-9.3.0/share/man/:/usr/share/man' ';export' 'MANPATH;MPI_BIN=/opt/tools/mpich-3.1.4-gcc-9.3.0/bin' ';export' 'MPI_BIN;MPI_FORTRAN_MOD_DIR=/opt/tools/mpich-3.1.4-gcc-9.3.0/lib' ';export' 'MPI_FORTRAN_MOD_DIR;MPI_HOME=/opt/tools/mpich-3.1.4-gcc-9.3.0' ';export' 'MPI_HOME;MPI_INC=/opt/tools/mpich-3.1.4-gcc-9.3.0/include' ';export' 'MPI_INC;MPI_LIB=/opt/tools/mpich-3.1.4-gcc-9.3.0/lib' ';export' 'MPI_LIB;MPI_MAN=/opt/tools/mpich-3.1.4-gcc-9.3.0/share/man' ';export' 'MPI_MAN;PATH=/opt/compilers/gcc-9.3.0/bin:/opt/tools/mpich-3.1.4-gcc-9.3.0/bin:/home/casch/.local/bin:/usr/bin:/bin:/sbin:/usr/sbin:/usr/local/bin:/usr/local/sbin' ';export' 'PATH;_LMFILES_=/opt/tools/modulefiles/mpich/3.1.4-gcc-9.3.0:/opt/compilers/modulefiles/gcc/9.3.0' ';export' '_LMFILES_;'
    ++ CPATH=/opt/compilers/gcc-9.3.0/include:/opt/tools/mpich-3.1.4-gcc-9.3.0/include
    ++ export CPATH
    ++ INCLUDE=/opt/compilers/gcc-9.3.0/include
    ++ export INCLUDE
    ++ INFOPATH=/opt/compilers/gcc-9.3.0/share/info
    ++ export INFOPATH
    ++ LD_LIBRARY_PATH=/opt/compilers/gcc-9.3.0/lib64:/opt/compilers/gcc-9.3.0/lib:/opt/tools/mpich-3.1.4-gcc-9.3.0/lib
    ++ export LD_LIBRARY_PATH
    ++ LIBRARY_PATH=/opt/compilers/gcc-9.3.0/lib64:/opt/compilers/gcc-9.3.0/lib:/opt/tools/mpich-3.1.4-gcc-9.3.0/lib
    ++ export LIBRARY_PATH
    ++ LOADEDMODULES=mpich/3.1.4-gcc-9.3.0:gcc/9.3.0
    ++ export LOADEDMODULES
    ++ MANPATH=/opt/compilers/gcc-9.3.0/share/man:/opt/tools/mpich-3.1.4-gcc-9.3.0/share/man/:/usr/share/man
    ++ export MANPATH
    ++ MPI_BIN=/opt/tools/mpich-3.1.4-gcc-9.3.0/bin
    ++ export MPI_BIN
    ++ MPI_FORTRAN_MOD_DIR=/opt/tools/mpich-3.1.4-gcc-9.3.0/lib
    ++ export MPI_FORTRAN_MOD_DIR
    ++ MPI_HOME=/opt/tools/mpich-3.1.4-gcc-9.3.0
    ++ export MPI_HOME
    ++ MPI_INC=/opt/tools/mpich-3.1.4-gcc-9.3.0/include
    ++ export MPI_INC
    ++ MPI_LIB=/opt/tools/mpich-3.1.4-gcc-9.3.0/lib
    ++ export MPI_LIB
    ++ MPI_MAN=/opt/tools/mpich-3.1.4-gcc-9.3.0/share/man
    ++ export MPI_MAN
    ++ PATH=/opt/compilers/gcc-9.3.0/bin:/opt/tools/mpich-3.1.4-gcc-9.3.0/bin:/home/casch/.local/bin:/usr/bin:/bin:/sbin:/usr/sbin:/usr/local/bin:/usr/local/sbin
    ++ export PATH
    ++ _LMFILES_=/opt/tools/modulefiles/mpich/3.1.4-gcc-9.3.0:/opt/compilers/modulefiles/gcc/9.3.0
    ++ export _LMFILES_
    + export LD_LIBRARY_PATH=/data/casch/charm-stuff/charm-benchmarks/deps/prefix/lib:/opt/compilers/gcc-9.3.0/lib64:/opt/compilers/gcc-9.3.0/lib:/opt/tools/mpich-3.1.4-gcc-9.3.0/lib
    + LD_LIBRARY_PATH=/data/casch/charm-stuff/charm-benchmarks/deps/prefix/lib:/opt/compilers/gcc-9.3.0/lib64:/opt/compilers/gcc-9.3.0/lib:/opt/tools/mpich-3.1.4-gcc-9.3.0/lib
    + export PKG_CONFIG_PATH=/data/casch/charm-stuff/charm-benchmarks/deps/prefix/lib/pkgconfig:
    + PKG_CONFIG_PATH=/data/casch/charm-stuff/charm-benchmarks/deps/prefix/lib/pkgconfig:
    + export PATH=/data/casch/charm-stuff/charm-benchmarks/deps/prefix/bin:/opt/compilers/gcc-9.3.0/bin:/opt/tools/mpich-3.1.4-gcc-9.3.0/bin:/home/casch/.local/bin:/usr/bin:/bin:/sbin:/usr/sbin:/usr/local/bin:/usr/local/sbin
    + PATH=/data/casch/charm-stuff/charm-benchmarks/deps/prefix/bin:/opt/compilers/gcc-9.3.0/bin:/opt/tools/mpich-3.1.4-gcc-9.3.0/bin:/home/casch/.local/bin:/usr/bin:/bin:/sbin:/usr/sbin:/usr/local/bin:/usr/local/sbin
    + sed 4d Makefile -i
    + sed 4iCHARMBASE=/data/casch/charm-stuff/charm-benchmarks/deps/prefix/charm-projections Makefile -i
    ++ pkgconf --libs papi
    + make projections 'OPTS=-I/data/casch/charm-stuff/charm-benchmarks/deps/prefix/include -L/data/casch/charm-stuff/charm-benchmarks/deps/prefix/lib -lpapi ' -j
    + JUBE_ERR_CODE=0
    + '[' 0 -ne 0 ']'
    + mpirun -np 20 ./leanmd.prj 10 10 10 100 20 20 +logsize 32000000

## \[2026-08-14 Fri\] LeanMD does not run on the current Charm++

Attempted the first traced LeanMD run since the SMP Charm++ rebuild, as the
generality check for the CCGrid paper. It does not run, and has probably
not run since that rebuild.

LeanMD segfaults in `ConverseInit`, inside `MPI_Comm_dup_with_info`,
before any application code executes. Isolated by controlled comparison,
one variable at a time:

| Configuration                                     | Result             |
|---------------------------------------------------|--------------------|
| Instrumented LeanMD, 2 hosts, 8 ranks             | segfault           |
| Pristine upstream LeanMD, same                    | identical segfault |
| Pristine, 1 host, 4 ranks                         | identical segfault |
| Pristine against `charm-changa-projections`       | identical segfault |
| Pristine with `+ppn 1` (this Charm++ is SMP)      | identical segfault |
| Plain `leanmd` target on `charm-base`, no tracing | identical segfault |
| ChaNGa on `charm-changa-projections`              | runs normally      |

Jobs 600496 through 600501. So it is not the instrumentation, not the node
count, not the Charm++ variant, not the missing `+ppn`, and not tracing.
Charm++ is sound: ChaNGa runs on the same build.

The instrumentation itself builds clean and is committed to
`caschb/leanmd` branch `thesis-instrumentation`. It has never produced a
trace, and the commit message says so.

Next step for whoever picks this up: bisect Charm++ versions, or build
LeanMD against something close to the CARLA-era Charm++. The traces behind
that paper carry job IDs around 198000 against today's 600000. Do not
start by re-examining the instrumentation – it is excluded by the
pristine-source rows above. See `docs/design-notes.md`, "LeanMD does not
currently run on this Charm++".

## \[2026-08-14 Fri\] Follow-up: the segfault above was a local test-script bug

The entry above is wrong and is left as written, per this file's own rule
against rewriting a dated record; this is the correction.

Every configuration in that elimination table was launched from ad hoc
scripts, not `bench.yml`, and every one of those scripts loaded
`gcc/12.4.0 openmpi/4.0.5`. `deps/prefix`'s Charm++ is built against
`mpich/3.1.4-gcc-9.3.0` (`bench.yml` loads it correctly; grep the `module load` line in either program's `bench.yml`). MPICH and OpenMPI are
ABI-incompatible, so launching an MPICH-linked Charm++ under OpenMPI's
`mpirun` was expected to crash exactly where it did, in
`MPI_Comm_dup_with_info`, on the first real MPI call – and to do so
identically across every variation, since none of the six varied the one
thing that mattered. Rebuilt and reran under the correct module (job
600508): LeanMD ran 20 steps, passed its own energy-conservation check,
and exited cleanly. ChaNGa's earlier "runs normally" control was not
special – it happened to always be launched through `bench.yml`, and
so happened to always get the right module.

Two further, real bugs surfaced once LeanMD was actually running – see
`docs/design-notes.md`, "the `LeanMD does not run` segfault was a local
test-script bug" – both in the domain-CSV flush, both silent (a
`CkExit()` race that dropped the flush's reduction with no error, and a
macro that never reached the `.ci` file's own translation step so the
flush code was never compiled in at all). Fixed in the same session; a
clean rerun (job 600519) wrote all 1280 rows to `leanmd.domain.csv` and
exited normally. LeanMD is unblocked as the generality check.

## \[2026-08-26 Wed\] Tracing sweep regenerated; archive moved off-cluster

The raw traces of the 2026-08-14 `tracing` sweep (jobs 600520-600522) were
deleted in cluster cleanups; the sweep was re-run so raw data exists again,
alongside the ChaNGa regeneration of the same day (see
`../changa/runs.md`). The committed `ccgrid2027/phase2/data/leanmd*` tables
remain the authoritative source of the paper's and the thesis's numbers.

**Numbering warning.** `leanmd_bench/` had been removed entirely, so JUBE
restarted at `000000`. This id is a new epoch; it is not the 2026-08-14 run
`000000` that produced jobs 600520-600522.

Run `000000`, tag `tracing`, jobs 605951-605953: 20/40/80 PEs on 1/2/4
hosts, 10x10x10 cells, 100 steps, tarballs 0.8/0.85/0.85 GB. Converted with
`charmvz-cpp/builddir-kabre/charmvz` (default `-s SimulationStep` split).

Archived on the laptop under `/data/ccgrid/leanmd_bench/`: per cell the
trace tarball, `leanmd.domain.csv`, `job.out`, `job.err`, `submit.job`,
`convert.log`, and the full `out/`. Cluster copies of tarballs and `out/`
were deleted after verified transfer; `jube continue` was run, so JUBE
reports the run finished.

## \[2026-10-06 Tue\] Placement intervention pilot launched on node-local scratch

User authorized up to four Kabré nodes for testing. Isolated experiment code
and generated snapshot live in `../ccgrid2027/experiments/leanmd-placement/`;
`leanmd/src` remains unchanged. Original fixed-window placement is compared
with a deterministic six-coordinate Compute hash; automatic balancing is
suppressed in both arms. Original and reversed particle-count ramps are built.

Build job `618044` completed successfully (46 seconds), using the installed
MPICH 3.1.4 / GCC 9.3 toolchain and copied Charm++/PAPI dependencies in
compute-node `/tmp`. Build archive (23,763,038 bytes) is preserved at
`/data/casch/ccgrid2027/leanmd-placement/20261006-pilot1-build.tar.gz`.

Two-node preliminary pilot `618047` precedes four-node pilot `618045` via
`afterany:618047`, so allocations never exceed four concurrent nodes. The
preliminary pilot tests 20/40-PE endpoints; the full pilot tests 20/80 and a
four-host 20/30/38/40/60/80-PE diagnostic sweep. Five randomized clean timing
pairs at each endpoint, separate Projections/domain/kernel diagnostics, and
reversed-ramp holdouts. Short 20/10-step runs are testing, not final paper data.

Run scratch is `/tmp/casch-leanmd-placement-pilot-<jobid>` on each node.
Per-node archives go to `/data/casch/ccgrid2027/leanmd-placement/`, or
`/work/casch/ccgrid2027/leanmd-placement/` if /data cannot accommodate them.
Source/manifests, stage logs and receipts are under
`/data/casch/ccgrid2027/leanmd-placement/staging/20261006-pilot1/`.
See `../ccgrid2027/notes/leanmd-placement-pilot-2026-10-06.md` for outcomes.

Outcome update: `618047` completed all 40 runs (4m11s, exit 0). Exact
Compute mapping and paired candidate/accepted work checks passed. Five clean
pairs gave original/hash time ratios 0.9908 at 20 PEs and 1.1685 at 40 PEs
(about 14.4% less time at 40 PEs). Single-allocation short-run pilot only.

Initial raw Projections output went beside the absolute binary path and was
overwritten between diagnostics; per-run CSVs and timings were preserved.
Corrected with explicit `+traceroot` and reran 14 diagnostic cases in job
`618048` (1m52s, exit 0). Compute-node archive verifier `618049` checked
SHA-256, mapping, work equality and all 384 rank logs plus 14 STS/PROJRC
pairs (8s, exit 0). Recovery archives (718,170,010 and 514,358,926 bytes)
are in `/data/casch/ccgrid2027/leanmd-placement/` under names
`20261006-pilot1-618048-kura-2b.cnca.tar.gz` and
`20261006-pilot1-618048-kura-2c.cnca.tar.gz`.

The four-node `618045` remains queued for resources, now sequenced after
`618049`; its runtime runner has the trace-path correction. Dependent verifier
`618051` will validate its archives after it exits. Results and small summary
are automatically retained in /data, with /work fallback for archive capacity.

## \[2026-10-12 Mon\] Four-node placement pilot completion verified

Jobs `618045` and `618051` had completed successfully on October 6, at
18:55:18 and 18:55:29 cluster time (4m20s and 11s, both exit 0). Retrieved
summary and archive-validation JSONs to `ccgrid2027/experiments/leanmd-placement/results/`.
All 44 runs passed; exact placement, energy and paired scientific work checks
passed. Eighteen diagnostic runs have 744 rank logs and complete STS/PROJRC.
SHA-256 checks passed for all four node archives, totaling 1,684,009,991 bytes,
under `/data/casch/ccgrid2027/leanmd-placement/`; /work fallback was unnecessary.

Five paired 80-PE clean runs give original/hash geometric mean time ratio
1.3920 (about 28.2% less time with hash), versus 0.9862 at 20 PEs (hash about
1.4% slower). Fixed-four-host 80-PE diagnostic kernel max/mean falls from
1.5687 to 1.1646. Candidate-work forecasts match measured sums/max/mean exactly.
Reversed-ramp single 80-PE clean pair is 3.381489s versus 2.858319s (15.5%
less time); no replication claim. Short pilot runs need independent allocations
and longer validation before paper speedup claims. No new runs submitted.
