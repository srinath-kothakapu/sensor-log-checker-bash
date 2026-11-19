#!/usr/bin/env bash
# logcheck.sh - check a sensor log in CSV format (timestamp_s,value).
#
# Checks: malformed lines, values outside [min,max], time gaps larger than a limit.
# Prints a summary (count, min, max, mean). Exit codes: 0 = all checks passed,
# 1 = at least one check failed, 2 = usage error.
set -euo pipefail

usage() {
    cat <<USAGE
Usage: $(basename "$0") [-m MIN] [-M MAX] [-g MAX_GAP_S] FILE.csv

  -m MIN        lowest allowed value        (default: no limit)
  -M MAX        highest allowed value       (default: no limit)
  -g MAX_GAP_S  largest allowed time gap between two samples in seconds
                (default: no limit)

Input: one sample per line, "timestamp_s,value". A header line is skipped.
USAGE
}

min=""
max=""
gap=""
while getopts ":m:M:g:h" opt; do
    case "$opt" in
        m) min="$OPTARG" ;;
        M) max="$OPTARG" ;;
        g) gap="$OPTARG" ;;
        h) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done
shift $((OPTIND - 1))

if [[ $# -ne 1 ]]; then
    usage >&2
    exit 2
fi
file="$1"
if [[ ! -r "$file" ]]; then
    echo "error: cannot read '$file'" >&2
    exit 2
fi

# awk does the number crunching; bash handles arguments and the exit code.
awk -F',' -v min="$min" -v max="$max" -v gap="$gap" '
function isnum(s) { return s ~ /^[-+]?[0-9]+([.][0-9]+)?([eE][-+]?[0-9]+)?$/ }
NR == 1 && !isnum($1) { next }          # skip header
{
    line = NR
    if (NF != 2 || !isnum($1) || !isnum($2)) {
        printf "line %d: malformed: %s\n", line, $0
        bad++
        next
    }
    t = $1 + 0; v = $2 + 0
    n++
    sum += v
    if (n == 1 || v < vmin) vmin = v
    if (n == 1 || v > vmax) vmax = v
    if (min != "" && v < min + 0) { printf "line %d: value %s below min %s\n", line, v, min; low++ }
    if (max != "" && v > max + 0) { printf "line %d: value %s above max %s\n", line, v, max; high++ }
    if (gap != "" && n > 1 && (t - tprev) > gap + 0) {
        printf "line %d: gap of %.3f s before this sample (limit %s s)\n", line, t - tprev, gap
        gaps++
    }
    tprev = t
}
END {
    if (n == 0) { print "no valid samples"; exit 1 }
    printf "samples: %d  min: %g  max: %g  mean: %.3f\n", n, vmin, vmax, sum / n
    problems = bad + low + high + gaps
    printf "malformed: %d  below min: %d  above max: %d  gaps: %d\n", bad, low, high, gaps
    exit (problems > 0 ? 1 : 0)
}' "$file"
