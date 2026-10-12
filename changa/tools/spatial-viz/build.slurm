#!/bin/bash
#SBATCH --partition=kura
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=20
#SBATCH --hint=nomultithread
#SBATCH --time=00:40:00
#SBATCH --job-name=changa-spatial-build
#SBATCH --output=/data/casch/charm-stuff/spatial-viz-20261005/build-%j.out
set -euo pipefail
TASK_ROOT=/data/casch/charm-stuff/spatial-viz-20261005
BENCH_ROOT=/data/casch/charm-stuff/charm-benchmarks
module purge
module load mpich/3.1.4-gcc-9.3.0 gcc/9.3.0
export LD_LIBRARY_PATH=$BENCH_ROOT/deps/prefix/lib:${LD_LIBRARY_PATH:-}
export PKG_CONFIG_PATH=$BENCH_ROOT/deps/prefix/lib/pkgconfig:${PKG_CONFIG_PATH:-}
export PATH=$BENCH_ROOT/deps/prefix/bin:$PATH
export CPATH=$BENCH_ROOT/deps/prefix/include:${CPATH:-}
export LIBRARY_PATH=$BENCH_ROOT/deps/prefix/lib:${LIBRARY_PATH:-}
cd "$TASK_ROOT/source"
git apply "$TASK_ROOT/source.patch"
cp -r "$BENCH_ROOT/deps/utility/structures" ./structures
export STRUCT_DIR=$PWD/structures
export CHARM_DIR=$BENCH_ROOT/deps/prefix/charm-changa-projections
# Give the binary's version stamp the dirty suffix, with the exact patch
# retained beside the run. No commits or changes to shared cluster sources.
sed -i 's/git describe --long --always/git describe --long --always --dirty/' Makefile.in
CXXFLAGS=-DCHANGA_VIZ_SNAPSHOTS ./configure --enable-projections
make -j16
mkdir -p "$TASK_ROOT/run"
cp -L ChaNGa "$TASK_ROOT/run/ChaNGa"
cp testcosmo/cube300.tbin "$TASK_ROOT/run/"
cp testcosmo/cube300.param "$TASK_ROOT/run/spatial.param"
python3 - <<'PY'
from pathlib import Path
p = Path('../run/spatial.param')
updates = dict(achInFile='cube300.tbin', achOutName='spatial', nSteps='128',
               dEta='0.03', killAt='17', iOutInterval='128', bParaWrite='0')
lines = [line for line in p.read_text().splitlines()
         if line.split('=')[0].strip() not in updates]
p.write_text('\n'.join(lines + [f'{k} = {v}' for k,v in updates.items()])+'\n')
PY
git rev-parse HEAD > "$TASK_ROOT/source-revision.txt"
sha256sum "$TASK_ROOT/source.patch" "$TASK_ROOT/run/ChaNGa" "$TASK_ROOT/run/spatial.param" > "$TASK_ROOT/build-sha256.txt"
echo BUILD_COMPLETE
