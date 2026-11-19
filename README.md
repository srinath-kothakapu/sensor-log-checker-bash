# sensor-log-checker (bash)

A small Bash tool that checks a sensor log in CSV format (`timestamp_s,value`) and
prints a summary. I wrote it to practise Linux shell scripting (argument parsing
with `getopts`, exit codes, `awk` for the calculations) and to automate a check I
would otherwise do by eye on logged sensor data.

## What it checks

- malformed lines (wrong number of columns, non-numeric values)
- values below a minimum or above a maximum
- time gaps between samples that are larger than a limit
- summary: number of samples, minimum, maximum, mean

## Usage

```bash
bash logcheck.sh [-m MIN] [-M MAX] [-g MAX_GAP_S] FILE.csv
```

Example:

```console
$ bash logcheck.sh -M 50 -g 2 tests/data/bad.csv
line 3: value 99 above max 50
line 4: malformed: 2.0,abc
line 5: gap of 6.000 s before this sample (limit 2 s)
samples: 3  min: 21.5  max: 99  mean: 47.367
malformed: 1  below min: 0  above max: 1  gaps: 1
```

Exit codes: `0` all checks passed, `1` at least one check failed, `2` usage error.
This makes it easy to use in a pipeline or a CI job.

## Tests

```bash
bash tests/run_tests.sh
```

The tests run on small sample files in `tests/data/`. GitHub Actions runs
ShellCheck and the tests on every push.

## Limits

- Input must be two columns: timestamp in seconds, then a numeric value.
- It has only been run on the sample files in this repository, not on logs from real hardware.
