"""Compare epoch budgets on the existing dataset_retrain split.

One training run at the longest budget, keeping a best val_loss checkpoint per
budget. Each snapshot is evaluated on validation and test. The winner is chosen
by val_loss, so the test numbers are not used for selection.

Does not touch artifacts_retrain/ or the Flutter assets.
"""
from __future__ import annotations

import argparse
import gc
import json
import math
from pathlib import Path

import numpy as np
import tensorflow as tf
from PIL import Image, ImageOps

try:
    import matplotlib.pyplot as plt
    HAS_MATPLOTLIB = True
except ImportError:
    HAS_MATPLOTLIB = False

BASE_DIR = Path(__file__).resolve().parent
CLASSES = ["cordana", "healthy", "pestalotiopsis", "sigatoka"]
VALID_EXTENSIONS = {".jpeg", ".jpg", ".png"}
SEED = 42
IMG_SIZE = 224
BATCH_SIZE = 16
SPLITS = ("train", "val", "test")


class BestWithinBudget(tf.keras.callbacks.Callback):
    """Save the model only while the epoch budget is still open."""

    def __init__(self, filepath, epoch_limit, monitor="val_loss"):
        super().__init__()
        self.filepath = Path(filepath)
        self.epoch_limit = epoch_limit
        self.monitor = monitor
        self.best = math.inf
        self.best_epoch = None

    def on_epoch_end(self, epoch, logs=None):
        current_epoch = epoch + 1
        if current_epoch > self.epoch_limit:
            return
        value = (logs or {}).get(self.monitor)
        if value is not None and value < self.best:
            self.best = value
            self.best_epoch = current_epoch
            self.model.save(self.filepath)


def load_rgb(path):
    with Image.open(path) as source:
        pixels = np.asarray(ImageOps.exif_transpose(source).convert("RGB"))
    ys = np.arange(IMG_SIZE) * pixels.shape[0] // IMG_SIZE
    xs = np.arange(IMG_SIZE) * pixels.shape[1] // IMG_SIZE
    return pixels[ys[:, None], xs[None, :]].astype(np.float32)


def collect_paths(dataset_dir, split, limit):
    paths, targets = [], []
    for index, name in enumerate(CLASSES):
        files = sorted(p for p in (dataset_dir / split / name).glob("*")
                       if p.suffix.lower() in VALID_EXTENSIONS)
        if limit:
            files = files[:limit]
        if not files:
            raise ValueError(f"Dataset kosong: {split}/{name} di {dataset_dir}")
        paths.extend(files)
        targets.extend([index] * len(files))
    return paths, targets


def make_dataset(paths, targets, shuffle, seed, batch_size):
    def samples():
        for path, target in zip(paths, targets):
            yield load_rgb(path), np.int32(target)

    ds = tf.data.Dataset.from_generator(samples, output_signature=(
        tf.TensorSpec((IMG_SIZE, IMG_SIZE, 3), tf.float32),
        tf.TensorSpec((), tf.int32)))
    ds = ds.apply(tf.data.experimental.assert_cardinality(len(paths)))
    if shuffle:
        ds = ds.shuffle(len(paths), seed=seed)
    return ds.batch(batch_size).prefetch(tf.data.AUTOTUNE)


def build_model(seed):
    tf.keras.utils.set_random_seed(seed)
    augmentation = tf.keras.Sequential([
        tf.keras.layers.RandomFlip("horizontal"),
        tf.keras.layers.RandomRotation(0.08),
    ], name="augmentation")
    backbone = tf.keras.applications.MobileNetV2(
        input_shape=(IMG_SIZE, IMG_SIZE, 3), include_top=False, weights="imagenet")
    backbone.trainable = False
    inputs = tf.keras.Input(shape=(IMG_SIZE, IMG_SIZE, 3), name="rgb")
    x = augmentation(inputs)
    x = tf.keras.layers.Rescaling(1.0 / 127.5, offset=-1)(x)
    x = backbone(x, training=False)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.Dropout(0.2)(x)
    outputs = tf.keras.layers.Dense(len(CLASSES), activation="softmax",
                                    name="probabilities")(x)
    model = tf.keras.Model(inputs, outputs)
    model.compile(optimizer=tf.keras.optimizers.Adam(1e-3),
                  loss="sparse_categorical_crossentropy", metrics=["accuracy"])
    return model


def evaluate(model, ds, targets):
    metrics = model.evaluate(ds, return_dict=True, verbose=0)
    probabilities = model.predict(ds, verbose=0)
    predictions = probabilities.argmax(axis=1)
    confusion = tf.math.confusion_matrix(
        targets, predictions, num_classes=len(CLASSES)).numpy()
    return ({k: float(v) for k, v in metrics.items()}, confusion.tolist())


def print_confusion_matrix(confusion, labels, title):
    matrix = np.asarray(confusion)
    width = max(len(name) for name in labels) + 2
    print(title)
    print(f"{'':>{width}s}"
          + "".join(f"{name:>{width}s}" for name in labels)
          + f"{'total':>{width}s}")
    for index, name in enumerate(labels):
        cells = "".join(f"{int(v):>{width}d}" for v in matrix[index])
        print(f"{name:>{width}s}" + cells + f"{int(matrix[index].sum()):>{width}d}")

    print()
    print(f"{'kelas':>{width}s} {'precision':>9s} {'recall':>9s} {'f1':>9s} {'support':>8s}")
    for index, name in enumerate(labels):
        support = int(matrix[index].sum())
        predicted = int(matrix[:, index].sum())
        true_positive = int(matrix[index, index])
        precision = true_positive / predicted if predicted else 0.0
        recall = true_positive / support if support else 0.0
        denominator = precision + recall
        f1 = 2 * precision * recall / denominator if denominator else 0.0
        print(f"{name:>{width}s} {precision:9.3f} {recall:9.3f} {f1:9.3f} {support:8d}")

    total = int(matrix.sum())
    accuracy = float(np.trace(matrix)) / total if total else 0.0
    print(f"{'akurasi':>{width}s} {'':>9s} {'':>9s} {accuracy:9.3f} {total:8d}")


def plot_confusion_matrix(confusion, labels, title="Confusion Matrix",
                          normalize=False, save_path=None):
    if not HAS_MATPLOTLIB:
        print("  [!] Matplotlib tidak tersedia. Jalankan pip install matplotlib untuk menampilkan grafik.")
        return
    matrix = np.asarray(confusion)
    if normalize:
        sums = matrix.sum(axis=1)[:, np.newaxis]
        display_matrix = np.divide(matrix.astype("float"), sums, out=np.zeros_like(matrix, dtype=float), where=sums != 0)
        fmt = ".2f"
    else:
        display_matrix = matrix
        fmt = "d"

    fig, ax = plt.subplots(figsize=(6, 5))
    cax = ax.imshow(display_matrix, cmap="Blues", interpolation="nearest")
    fig.colorbar(cax, fraction=0.046, pad=0.04)

    ax.set_xticks(range(len(labels)))
    ax.set_yticks(range(len(labels)))
    ax.set_xticklabels(labels, rotation=35, ha="right", fontsize=10)
    ax.set_yticklabels(labels, fontsize=10)
    ax.set_xlabel("Prediksi (Predicted)", fontsize=11, fontweight="bold", labelpad=8)
    ax.set_ylabel("Aktual (True)", fontsize=11, fontweight="bold", labelpad=8)
    ax.set_title(title, fontsize=12, pad=12, fontweight="bold")

    threshold = display_matrix.max() / 2.0 if display_matrix.size else 0.5
    for i in range(len(labels)):
        for j in range(len(labels)):
            val = display_matrix[i, j]
            color = "white" if val > threshold else "black"
            text_str = f"{val:{fmt}}" if not normalize else f"{val:.2f}"
            ax.text(j, i, text_str, ha="center", va="center",
                    color=color, fontsize=11, fontweight="bold")

    plt.tight_layout()
    if save_path:
        p = Path(save_path)
        p.parent.mkdir(parents=True, exist_ok=True)
        plt.savefig(p, dpi=150)
        print(f"  [OK] Grafik disimpan ke: {p}")
    plt.close(fig)


def write_history_csv(path, history):
    keys = ["epoch", "loss", "accuracy", "val_loss", "val_accuracy"]
    lines = [",".join(keys)]
    for epoch in range(len(history["loss"])):
        row = [str(epoch + 1)] + [repr(float(history[k][epoch])) for k in keys[1:]]
        lines.append(",".join(row))
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def read_history_csv(path):
    keys = ["loss", "accuracy", "val_loss", "val_accuracy"]
    history = {key: [] for key in keys}
    for line in path.read_text(encoding="utf-8").splitlines()[1:]:
        if not line.strip():
            continue
        parts = line.split(",")
        for key, value in zip(keys, parts[1:]):
            history[key].append(float(value))
    return history


def best_epoch_within(history, budget):
    """Epoch dengan val_loss terkecil pada rentang 1..budget."""
    window = history["val_loss"][:budget]
    if not window:
        return None
    return int(np.argmin(window)) + 1


def release_model(model):
    """Tutup model dan bersihkan sesi Keras sebelum memuat checkpoint berikutnya."""
    del model
    gc.collect()
    tf.keras.backend.clear_session()


def write_comparison_csv(path, results):
    keys = ["budget", "best_epoch", "val_loss", "val_accuracy",
            "test_loss", "test_accuracy"]
    lines = [",".join(keys)]
    for r in results:
        lines.append(",".join([
            str(r["budget"]), str(r["best_epoch"]),
            f"{r['val_loss']:.6f}", f"{r['val_accuracy']:.6f}",
            f"{r['test_loss']:.6f}", f"{r['test_accuracy']:.6f}",
        ]))
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_curves_svg(path, history, marker_epoch):
    epochs = list(range(1, len(history["loss"]) + 1))
    panels = [
        ("Loss", [("loss", "train", "#1f77b4"), ("val_loss", "val", "#d62728")]),
        ("Accuracy", [("accuracy", "train", "#1f77b4"),
                      ("val_accuracy", "val", "#d62728")]),
    ]
    width, height = 780, 560
    left, right, top, gap = 70, 560, 40, 70
    panel_h = (height - top - 40 - gap) / 2
    e_min, e_max = min(epochs), max(epochs)

    def x_of(epoch):
        if e_max == e_min:
            return (left + right) / 2
        return left + (epoch - e_min) / (e_max - e_min) * (right - left)

    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" '
        f'height="{height}" viewBox="0 0 {width} {height}">',
        f'<rect width="{width}" height="{height}" fill="#ffffff"/>',
        f'<g font-family="sans-serif" font-size="12" fill="#222222">',
    ]
    for index, (title, series) in enumerate(panels):
        y0 = top + index * (panel_h + gap)
        y1 = y0 + panel_h
        values = [history[key][e - 1] for key in (s[0] for s in series)
                  for e in epochs]
        lo, hi = min(values), max(values)
        pad = (hi - lo) * 0.08 or 0.01
        lo, hi = lo - pad, hi + pad

        def y_of(value, lo=lo, hi=hi, y0=y0, y1=y1):
            return y1 - (value - lo) / (hi - lo) * (y1 - y0)

        parts.append(f'<text x="{left}" y="{y0 - 10}" font-size="14">{title}</text>')
        for fraction in (0.0, 0.5, 1.0):
            value = lo + (hi - lo) * fraction
            y = y_of(value)
            parts.append(f'<line x1="{left}" y1="{y:.1f}" x2="{right}" '
                         f'y2="{y:.1f}" stroke="#e6e6e6"/>')
            parts.append(f'<text x="{left - 8}" y="{y + 4:.1f}" '
                         f'text-anchor="end" fill="#666666">{value:.3f}</text>')
        parts.append(f'<line x1="{left}" y1="{y1}" x2="{right}" y2="{y1}" '
                     f'stroke="#999999"/>')
        parts.append(f'<line x1="{left}" y1="{y0}" x2="{left}" y2="{y1}" '
                     f'stroke="#999999"/>')

        for key, label, color in series:
            points = " ".join(f"{x_of(e):.1f},{y_of(history[key][e - 1]):.1f}"
                              for e in epochs)
            parts.append(f'<polyline points="{points}" fill="none" '
                         f'stroke="{color}" stroke-width="2"/>')
            legend_y = y0 + 14 + series.index((key, label, color)) * 18
            parts.append(f'<line x1="{right + 12}" y1="{legend_y}" '
                         f'x2="{right + 34}" y2="{legend_y}" stroke="{color}" '
                         f'stroke-width="2"/>')
            parts.append(f'<text x="{right + 40}" y="{legend_y + 4}" '
                         f'fill="#333333">{label}</text>')

        if marker_epoch is not None:
            mx = x_of(marker_epoch)
            parts.append(f'<line x1="{mx:.1f}" y1="{y0}" x2="{mx:.1f}" y2="{y1}" '
                         f'stroke="#888888" stroke-dasharray="4 3"/>')
            parts.append(f'<text x="{mx + 4:.1f}" y="{y0 + 12}" '
                         f'fill="#666666">epoch {marker_epoch}</text>')

    parts.append(f'<text x="{left}" y="{height - 12}" fill="#666666">'
                 f'epoch (1..{e_max})</text>')
    parts.append("</g></svg>")
    path.write_text("\n".join(parts) + "\n", encoding="utf-8")


def parse_args():
    parser = argparse.ArgumentParser(
        description="Bandingkan budget epoch pada split dataset_retrain.")
    parser.add_argument("--epochs", default="20,100",
                        help="Daftar budget epoch, dipisah koma (default 20,100).")
    parser.add_argument("--patience", type=int, default=10,
                        help="Patience EarlyStopping pada val_loss. 0 = mati.")
    parser.add_argument("--limit", type=int, default=0,
                        help="Batasi jumlah gambar per kelas per split (uji cepat).")
    parser.add_argument("--seed", type=int, default=SEED)
    parser.add_argument("--batch-size", type=int, default=BATCH_SIZE)
    parser.add_argument("--dataset", default=str(BASE_DIR / "dataset_retrain"))
    parser.add_argument("--out", default=str(BASE_DIR / "artifacts_retrain_cmp"))
    parser.add_argument("--evaluate-only", action="store_true",
                        help="Lewati training, pakai checkpoint dan history.csv di --out.")
    return parser.parse_args()


def main():
    args = parse_args()
    budgets = sorted({int(b) for b in args.epochs.split(",") if b.strip()})
    if not budgets or budgets[0] < 1:
        raise ValueError("Budget epoch harus bilangan bulat positif.")
    max_epochs = budgets[-1]
    dataset_dir = Path(args.dataset).resolve()
    out_dir = Path(args.out).resolve()
    if not dataset_dir.is_dir():
        raise FileNotFoundError(f"Dataset tidak ditemukan: {dataset_dir}")

    print("=" * 64)
    print("  PERBANDINGAN BUDGET EPOCH")
    print("=" * 64)
    print(f"  Dataset    : {dataset_dir}")
    print(f"  Output     : {out_dir}")
    print(f"  Budget     : {budgets}")
    print(f"  Seed       : {args.seed}   Patience: {args.patience}")
    print(f"  Mode       : {'evaluasi saja' if args.evaluate_only else 'training + evaluasi'}")

    print("\n[1/4] Memuat dataset ...")
    split_paths, split_targets = {}, {}
    for split in SPLITS:
        paths, targets = collect_paths(dataset_dir, split, args.limit)
        split_paths[split], split_targets[split] = paths, targets
        print(f"  {split:5s}: {len(paths)} gambar")

    train_ds = make_dataset(split_paths["train"], split_targets["train"], True,
                            args.seed, args.batch_size)
    val_ds = make_dataset(split_paths["val"], split_targets["val"], False,
                          args.seed, args.batch_size)
    test_ds = make_dataset(split_paths["test"], split_targets["test"], False,
                           args.seed, args.batch_size)

    history_path = out_dir / "history.csv"
    out_dir.mkdir(parents=True, exist_ok=True)

    if args.evaluate_only:
        print("\n[2/4] Melewati training, membaca riwayat dari disk ...")
        if not history_path.is_file():
            raise FileNotFoundError(
                f"Mode evaluasi butuh {history_path}. Jalankan tanpa mode ini lebih dulu.")
        history_data = read_history_csv(history_path)
        epochs_run = len(history_data["loss"])
        stopped_early = epochs_run < max_epochs
        best_epochs = {b: best_epoch_within(history_data, b) for b in budgets}
    else:
        print("\n[2/4] Membangun model dan training ...")
        model = build_model(args.seed)
        snapshots = {}
        callbacks = []
        for budget in budgets:
            target = out_dir / f"e{budget}" / "banana_best.keras"
            target.parent.mkdir(parents=True, exist_ok=True)
            snapshot = BestWithinBudget(target, budget)
            snapshots[budget] = snapshot
            callbacks.append(snapshot)
        if args.patience > 0:
            callbacks.append(tf.keras.callbacks.EarlyStopping(
                monitor="val_loss", patience=args.patience, restore_best_weights=False))
        callbacks.append(tf.keras.callbacks.CSVLogger(str(history_path)))

        history = model.fit(train_ds, validation_data=val_ds, epochs=max_epochs,
                            shuffle=False, verbose=1, callbacks=callbacks)
        history_data = dict(history.history)
        epochs_run = len(history_data["loss"])
        stopped_early = epochs_run < max_epochs
        best_epochs = {b: snapshots[b].best_epoch for b in budgets}
        release_model(model)

    print("\n[3/4] Mengevaluasi checkpoint tiap budget ...")
    results = []
    for budget in budgets:
        checkpoint = out_dir / f"e{budget}" / "banana_best.keras"
        if not checkpoint.is_file():
            print(f"  e{budget}: tidak ada checkpoint, dilewati.")
            continue
        best_epoch = best_epochs[budget]
        expected_epoch = best_epoch_within(history_data, budget)
        if expected_epoch != best_epoch:
            print(f"  [!] e{budget}: checkpoint dari epoch {best_epoch}, "
                  f"padahal val_loss terbaik ada di epoch {expected_epoch}.")
        restored = tf.keras.models.load_model(checkpoint)
        val_metrics, _ = evaluate(restored, val_ds, split_targets["val"])
        test_metrics, confusion = evaluate(restored, test_ds, split_targets["test"])
        evaluation = {"budget": budget, "best_epoch": best_epoch,
                      "checkpoint": str(checkpoint.relative_to(out_dir)),
                      "labels": [c.capitalize() for c in CLASSES],
                      "validation": val_metrics, "test": test_metrics,
                      "confusion_matrix": confusion}
        (checkpoint.parent / "evaluation.json").write_text(
            json.dumps(evaluation, indent=2), encoding="utf-8")
        results.append({
            "budget": budget,
            "best_epoch": best_epoch,
            "val_loss": val_metrics["loss"],
            "val_accuracy": val_metrics["accuracy"],
            "test_loss": test_metrics["loss"],
            "test_accuracy": test_metrics["accuracy"],
            "confusion_matrix": confusion,
            "checkpoint": str(checkpoint.relative_to(out_dir)),
        })
        print(f"  e{budget}: epoch terbaik {best_epoch}, "
              f"val_loss {val_metrics['loss']:.4f}")
        release_model(restored)

    if not results:
        raise RuntimeError("Tidak ada checkpoint yang bisa dievaluasi.")

    print("\n[4/4] Menulis laporan ...")
    write_history_csv(history_path, history_data)
    write_comparison_csv(out_dir / "comparison.csv", results)
    write_curves_svg(out_dir / "curves.svg", history_data, budgets[0])

    selected = min(results, key=lambda r: r["val_loss"])
    comparison = {
        "seed": args.seed,
        "batch_size": args.batch_size,
        "patience": args.patience,
        "epochs_requested": max_epochs,
        "epochs_run": epochs_run,
        "stopped_early": stopped_early,
        "budgets": budgets,
        "selection_metric": "val_loss",
        "selected_budget": selected["budget"],
        "results": results,
    }
    (out_dir / "comparison.json").write_text(
        json.dumps(comparison, indent=2), encoding="utf-8")

    print("\n" + "=" * 64)
    print("  HASIL")
    print("=" * 64)
    print(f"  Epoch dijalankan : {epochs_run} dari {max_epochs}"
          + ("  (berhenti awal)" if stopped_early else ""))

    labels = [c.capitalize() for c in CLASSES]
    for r in results:
        print()
        print_confusion_matrix(r["confusion_matrix"], labels,
                               f"Confusion matrix test (budget {r['budget']} epoch, "
                               f"epoch terbaik {r['best_epoch']})")
        cm_png = out_dir / f"e{r['budget']}" / "confusion_matrix.png"
        plot_confusion_matrix(r["confusion_matrix"], labels,
                              title=f"Confusion Matrix (Budget {r['budget']} Epoch - Best Ep {r['best_epoch']})",
                              save_path=cm_png)

    print(f"\n  {'Budget':>6s} {'BestEp':>6s} {'ValLoss':>9s} {'ValAcc':>8s} "
          f"{'TestLoss':>9s} {'TestAcc':>8s}")
    print("  " + "-" * 50)
    for r in results:
        print(f"  {r['budget']:6d} {r['best_epoch']:6d} {r['val_loss']:9.4f} "
              f"{r['val_accuracy']:8.4f} {r['test_loss']:9.4f} "
              f"{r['test_accuracy']:8.4f}")
    print("  " + "-" * 50)
    print(f"  Dipilih lewat val_loss: {selected['budget']} epoch "
          f"(val_loss {selected['val_loss']:.4f})")
    print("\n  File:")
    print(f"    history    : {out_dir / 'history.csv'}")
    print(f"    perbandingan: {out_dir / 'comparison.csv'}")
    print(f"    kurva      : {out_dir / 'curves.svg'}")
    print(f"    detail     : {out_dir / 'comparison.json'}")


if __name__ == "__main__":
    main()
