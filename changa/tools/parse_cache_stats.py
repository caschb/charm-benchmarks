#!/usr/bin/env python3
"""Extract ChaNGa CkCache counters from one or more job.err files.

With the ``cachestats`` benchmark tag, ChaNGa is compiled with
``-DCOSMO_STATS=1``. It then prints a cumulative CkCacheStatistics block for
the node, gravity-particle, and smooth-particle caches after each gravity
phase. This script makes those otherwise human-readable counters available as
CSV for the CCGrid layout experiment.

Usage:
    python parse_cache_stats.py job.err [...] -o cache_stats.csv
"""

import argparse
import csv
import pathlib
import re


CACHE_NAMES = ("node", "gravity_particle", "smooth_particle")
HEADER = re.compile(r"Total statistics (?:initial )?iteration (?P<phase>[^\n]+)")
BLOCK = re.compile(
    r"Cache:\s+(?P<data_arrived>\d+) data arrived \(corresponding to "
    r"(?P<messages>\d+) messages\),\s+(?P<local>\d+) from local Chares\s+"
    r"(?:Cache:.*?\n)?"
    r"\s*Cache:\s+(?P<misses>\d+) misses during computation\s+"
    r"\s*Cache:\s+Maximum of\s+(?P<max_stored>\d+) data stored at a time in processor\s+(?P<max_pe>-?\d+)\s+"
    r"\s*Cache:\s+local Chares made\s+(?P<requests>\d+) requests",
    re.MULTILINE,
)


def rows_for(path: pathlib.Path) -> list[dict[str, str]]:
    text = path.read_text(errors="replace")
    headers = list(HEADER.finditer(text))
    rows: list[dict[str, str]] = []
    for i, header in enumerate(headers):
        end = headers[i + 1].start() if i + 1 < len(headers) else len(text)
        blocks = list(BLOCK.finditer(text, header.end(), end))
        if len(blocks) != 3:
            raise ValueError(
                f"{path}: phase {header.group('phase')!r} has {len(blocks)} "
                "cache-statistics blocks, expected three"
            )
        for cache, block in zip(CACHE_NAMES, blocks):
            row = {"source": str(path), "phase": header.group("phase"), "cache": cache}
            row.update(block.groupdict())
            rows.append(row)
    if not rows:
        raise ValueError(f"{path}: no CkCache statistics found; use a cachestats run")
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("inputs", nargs="+", type=pathlib.Path)
    parser.add_argument("-o", "--output", type=pathlib.Path, required=True)
    args = parser.parse_args()

    rows = [row for path in args.inputs for row in rows_for(path)]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=(
            "source", "phase", "cache", "data_arrived", "messages", "local",
            "misses", "max_stored", "max_pe", "requests",
        ))
        writer.writeheader()
        writer.writerows(rows)
    print(f"wrote {len(rows)} cache-statistics rows to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
