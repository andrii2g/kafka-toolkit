#!/usr/bin/env python3
import argparse
import csv
from collections import defaultdict


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate a Markdown lag trend report from snapshot CSV.")
    parser.add_argument("snapshot_csv")
    parser.add_argument("--group")
    parser.add_argument("--topic")
    parser.add_argument("--out", default="-")
    args = parser.parse_args()

    totals = defaultdict(int)
    with open(args.snapshot_csv, newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            if args.group and row.get("group") != args.group:
                continue
            if args.topic and row.get("topic") != args.topic:
                continue
            lag = row.get("lag") or "0"
            totals[row["timestamp_utc"]] += int(lag)

    lines = ["# Kafka Lag Trend", ""]
    if args.group:
        lines.append(f"Consumer group: `{args.group}`")
    if args.topic:
        lines.append(f"Topic: `{args.topic}`")
    lines.extend(["", "| Timestamp UTC | Total Lag |", "|---|---:|"])
    for timestamp in sorted(totals):
        lines.append(f"| {timestamp} | {totals[timestamp]} |")
    output = "\n".join(lines) + "\n"

    if args.out == "-":
        print(output, end="")
    else:
        with open(args.out, "w", encoding="utf-8") as handle:
            handle.write(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
