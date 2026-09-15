# galileo_flutter_benchmark

Benchmarks Flutter Map markers against Galileo Flutter `OverlayWidget`
points at 1K, 10K, 100K, and 1M points.

## Run benchmark

```bash
fvm flutter run -d linux
```

Results are appended to:

```text
logs/benchmark_results.csv
```

## Graph results

```bash
uv venv --system-site-packages .venv
.venv/bin/python graph_benchmark.py
```

For Nushell:

```nu
overlay use .venv/bin/activate.nu
```

Output:

```text
logs/benchmark_graphs.png
```

## Reading the CSV

`0` in `startup_ms`, `cpu_percent`, `gpu_percent`, `gpu_mem_mb`, `rss_mb`,
or `avg_fps` means the benchmark did not get a valid render/sample for that
scenario — usually the map did not become ready before the 120s timeout.
It does not mean the renderer measured a true zero.
