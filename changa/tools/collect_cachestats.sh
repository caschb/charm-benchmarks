#!/usr/bin/env bash
# Collect the paired one-host cache-statistics runs after Slurm has completed
# their workpackages. Run through sbatch with afterok dependencies, not from a
# polling loop.
set -eu

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <default-run-id> <ppn-run-id>" >&2
  exit 2
fi

default_id=$1
ppn_id=$2
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$repo_root"

jube continue changa/changa_bench --id "$default_id"
jube continue changa/changa_bench --id "$ppn_id"

outdir="changa/cachestats/${default_id}-${ppn_id}"
mkdir -p "$outdir"

python changa/tools/collect_timings.py "$outdir" \
  "changa/changa_bench/${default_id}" \
  "changa/changa_bench/${ppn_id}"

errs=()
while IFS= read -r err; do
  errs+=("$err")
done < <(find "changa/changa_bench/${default_id}" "changa/changa_bench/${ppn_id}" \
  -path '*/work/job.err' -type f | sort)

if [ "${#errs[@]}" -ne 6 ]; then
  echo "expected six job.err files, found ${#errs[@]}" >&2
  exit 1
fi

python changa/tools/parse_cache_stats.py "${errs[@]}" -o "$outdir/cache_stats.csv"
jube result changa/changa_bench --id "$default_id" > "$outdir/jube-result-${default_id}.txt"
jube result changa/changa_bench --id "$ppn_id" > "$outdir/jube-result-${ppn_id}.txt"
touch "$outdir/complete"
echo "collected cache-statistics runs into $outdir"
