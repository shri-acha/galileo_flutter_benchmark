from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd


csv_path = Path("logs/benchmark_results.csv")
out_path = Path("logs/benchmark_graphs.png")

df = pd.read_csv(csv_path)

metrics = [
    "startup_ms",
    "cpu_percent",
    "gpu_percent",
    "gpu_mem_mb",
    "rss_mb",
    "avg_fps",
]
labels = {
    "startup_ms": "Startup (ms) — lower is better",
    "cpu_percent": "CPU (%) — lower is better",
    "gpu_percent": "GPU busy (%) — lower is better",
    "gpu_mem_mb": "GPU memory (MB) — lower is better",
    "rss_mb": "Process RSS (MB) — lower is better",
    "avg_fps": "Average FPS — higher is better",
}

for col in metrics:
    df[col] = df[col].replace(0, pd.NA)

grouped = df.groupby(["point_count", "engine"], as_index=False)[metrics].mean()

fig, axes = plt.subplots(2, 3, figsize=(16, 9))

for ax, col in zip(axes.flat, metrics):
    for engine, style, name in [
        ("flutter_map", "o-", "Flutter Map"),
        ("galileo_overlay", "s--", "Galileo OverlayWidget"),
    ]:
        series = grouped[grouped["engine"] == engine].dropna(subset=[col])
        ax.plot(series["point_count"], series[col], style, label=name)

    ax.set_xscale("log")
    ax.set_xlabel("Point count")
    ax.set_ylabel(labels[col])
    ax.set_title(labels[col])
    ax.grid(True, which="both", alpha=0.25)
    ax.legend()

fig.tight_layout()
out_path.parent.mkdir(parents=True, exist_ok=True)
fig.savefig(out_path, dpi=160)
print(out_path)
