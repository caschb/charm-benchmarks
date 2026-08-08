#!/usr/bin/env python3
"""Convert ChaNGa's per-TreePiece physics side file from CSV to Parquet.

ChaNGa writes `<achOutName>.physics.csv`, one row per TreePiece per *substep*,
when built with -DCHANGA_TRACE_TIMESTEPS. This turns it into a Parquet table
that joins against the trace-derived tables on (index, phase), where `phase` is
the run-global substep counter carried by the GravityPhase user-event bracket.

The grain is the substep, not the big step: a big step under multistepping runs
several gravity phases with different active rungs, and active_rung/n_active
only have a value within one of them.

Kept out of ChaNGa itself deliberately: emitting Parquet from the application
would mean linking Apache Arrow into ChaNGa's autoconf/charmc build on the
cluster, and putting that write cost inside the run whose timings are being
measured. CSV out, convert here.

Usage:
    uv run --with polars physics_to_parquet.py <in.csv> [-o out.parquet]
"""

import argparse
import pathlib
import sys

import polars as pl

# SFC keys are unsigned 64-bit and do use the top bit, so they must not be
# inferred as Int64 -- a key above 2^63 would come back negative.
SCHEMA_OVERRIDES = {
    "key_first": pl.UInt64,
    "key_last": pl.UInt64,
    "node_inter_local": pl.UInt64,
    "node_inter_remote": pl.UInt64,
    "part_inter_local": pl.UInt64,
    "part_inter_remote": pl.UInt64,
}


def convert(src: pathlib.Path, dst: pathlib.Path) -> pl.DataFrame:
    df = pl.read_csv(src, schema_overrides=SCHEMA_OVERRIDES)

    df = df.with_columns(
        # Fraction of this element's particles that were active. The whole
        # point of the multistep load balancer, and flat at 1.0 until
        # multistepping engages.
        (pl.col("n_active") / pl.col("n_particles")).alias("active_fraction"),
        # Total interactions, the closest thing to a direct work count.
        (
            pl.col("node_inter_local")
            + pl.col("node_inter_remote")
            + pl.col("part_inter_local")
            + pl.col("part_inter_remote")
        ).alias("interactions_total"),
        # Width of the element's slice of the space-filling curve. ChaNGa
        # splits an SFC-ordered list into equal-count pieces, so a wide slice
        # means a sparse region and a narrow one means a dense region --
        # which is the density proxy that survives equal-count decomposition,
        # unlike particle count or box volume.
        (pl.col("key_last") - pl.col("key_first")).alias("key_span"),
        (
            (pl.col("bb_max_x") - pl.col("bb_min_x"))
            * (pl.col("bb_max_y") - pl.col("bb_min_y"))
            * (pl.col("bb_max_z") - pl.col("bb_min_z"))
        ).alias("bb_volume"),
    )

    df.write_parquet(dst, compression="zstd")
    return df


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("csv", type=pathlib.Path, help="ChaNGa .physics.csv")
    ap.add_argument("-o", "--output", type=pathlib.Path, default=None)
    args = ap.parse_args()

    if not args.csv.is_file():
        print(f"no such file: {args.csv}", file=sys.stderr)
        return 1

    dst = args.output or args.csv.with_suffix(".parquet")
    df = convert(args.csv, dst)

    steps = df["step"].n_unique()
    phases = df["phase"].n_unique()
    pieces = df["index"].n_unique()
    print(f"{args.csv} -> {dst}")
    print(f"  {df.height} rows  {df.width} columns")
    print(f"  {steps} big steps, {phases} substeps x {pieces} TreePieces")

    # phase is the join key against the GravityPhase bracket's nestedID, so a
    # duplicate (phase, index) would fan the join out silently. Check the key
    # rather than a row-count identity: the substeps per big step vary with the
    # rung distribution, so there is no expected total to compare against.
    dups = df.height - df.select("phase", "index").n_unique()
    if dups:
        print(
            f"  WARNING: {dups} duplicate (phase, index) rows -- the join key"
            " is not unique",
            file=sys.stderr,
        )
    if df.height != phases * pieces:
        print(
            f"  WARNING: expected {phases * pieces} rows, found {df.height}"
            " -- some (phase, index) pairs are missing",
            file=sys.stderr,
        )
    # Multistepping is the premise of the whole experiment, so a run that never
    # varies the active rung should say so here rather than downstream.
    rungs = sorted(df["active_rung"].unique().to_list())
    print(f"  active rungs present: {rungs}")
    if len(rungs) == 1:
        print(
            f"  WARNING: every row is rung {rungs[0]} -- this run did not"
            " multistep",
            file=sys.stderr,
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
