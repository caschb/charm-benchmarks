#!/bin/bash
#SBATCH --partition=kura
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --time=00:10:00
#SBATCH --job-name=spatial-exporter-check
#SBATCH --output=/data/casch/charm-stuff/spatial-viz-20261005/exporter-check-%j.out
# Compile the post-run guard that avoids reading inactive potential values.
# Does not replace the run's executable, source patch, or checksum manifest.
set -euo pipefail
BENCH_ROOT=/data/casch/charm-stuff/charm-benchmarks
module purge
module load mpich/3.1.4-gcc-9.3.0 gcc/9.3.0
export LD_LIBRARY_PATH=$BENCH_ROOT/deps/prefix/lib:${LD_LIBRARY_PATH:-}
export CPATH=$BENCH_ROOT/deps/prefix/include:${CPATH:-}
export LIBRARY_PATH=$BENCH_ROOT/deps/prefix/lib:${LIBRARY_PATH:-}
export STRUCT_DIR=/data/casch/charm-stuff/spatial-viz-20261005/source/structures
export CHARM_DIR=$BENCH_ROOT/deps/prefix/charm-changa-projections
cd /data/casch/charm-stuff/spatial-viz-20261005/source
make -j8
echo GUARDED_EXPORTER_BUILD_COMPLETE
