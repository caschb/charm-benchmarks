#!/bin/bash
#SBATCH --partition=kura
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --time=00:40:00
#SBATCH --job-name=changa-spatial-convert
#SBATCH --output=/data/casch/charm-stuff/spatial-viz-20261005/convert-%j.out
set -euo pipefail
TASK_ROOT=/data/casch/charm-stuff/spatial-viz-20261005
RUN_ROOT=$TASK_ROOT/run
CVZ=/data/casch/charm-stuff/charmvz-cpp/builddir-kabre/charmvz
LOCAL_OUT=$(mktemp -d /tmp/changa-spatial-convert.XXXXXX)
export LD_LIBRARY_PATH=/data/casch/tools/envs/charmvz/lib:${LD_LIBRARY_PATH:-}
"$CVZ" -l "$RUN_ROOT" -o "$LOCAL_OUT/out" -s GravityPhase > "$TASK_ROOT/convert.log" 2>&1
export UV_CACHE_DIR=/data/casch/.cache/uv
export UV_PYTHON_INSTALL_DIR=/data/casch/.local/share/uv/python
uv run --with polars python "$TASK_ROOT/join_phase2.py" "$LOCAL_OUT/out" "$RUN_ROOT/spatial.physics.csv" -o "$TASK_ROOT/joined.parquet" > "$TASK_ROOT/join.log" 2>&1
mkdir -p "$TASK_ROOT/tables"
cp "$LOCAL_OUT/out/"{chare_instance,chare_collection,simulation_step,entry_method}.parquet "$TASK_ROOT/tables/"
# Full conversion is node-local scratch; raw logs and archive remain durable.
echo CONVERT_COMPLETE
