#!/bin/bash
#SBATCH --partition=kura-wide
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=20
#SBATCH --hint=nomultithread
#SBATCH --exclusive
#SBATCH --time=00:30:00
#SBATCH --job-name=changa-spatial
#SBATCH --output=/data/casch/charm-stuff/spatial-viz-20261005/run-%j.out
set -euo pipefail
TASK_ROOT=/data/casch/charm-stuff/spatial-viz-20261005
BENCH_ROOT=/data/casch/charm-stuff/charm-benchmarks
module purge
module load mpich/3.1.4-gcc-9.3.0 gcc/9.3.0
export LD_LIBRARY_PATH=$BENCH_ROOT/deps/prefix/lib:${LD_LIBRARY_PATH:-}
cd "$TASK_ROOT/run"
printf 'job=%s hosts=%s workers=38 ppn=19\n' "$SLURM_JOB_ID" "$SLURM_JOB_NODELIST" > run-metadata.txt
time mpirun -np 2 ./ChaNGa spatial.param +ppn 19 +logsize 32000000 > job.out 2> job.err
if grep -E 'Projections log flushed to disk|performance data is likely invalid' job.out job.err; then
  echo 'INVALID: trace buffer flushed'; exit 2
fi
test "$(grep -c '^\[spatial\]' job.out)" -eq 8
tar -czf "trace_${SLURM_JOB_ID}.tar.gz" ChaNGa.*.log* ChaNGa.sts ChaNGa.projrc
echo RUN_COMPLETE
