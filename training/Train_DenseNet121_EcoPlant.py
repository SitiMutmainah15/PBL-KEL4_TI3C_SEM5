"""Training dan evaluasi DenseNet121 untuk penyakit daun pisang.

Lokasi file yang disarankan:
    training/train_densenet121.py

Folder yang diperlukan:
    training/dataset_retrain/train/{cordana,healthy,pestalotiopsis,sigatoka}/
    training/dataset_retrain/val/{cordana,healthy,pestalotiopsis,sigatoka}/
    training/dataset_retrain/test/{cordana,healthy,pestalotiopsis,sigatoka}/

Jalankan dari terminal (di folder training):
    python train_densenet121.py

Opsional:
    python train_densenet121.py --epochs 20 --batch-size 16
    python train_densenet121.py --tflite

Instal dependensi jika belum ada:
    pip install tensorflow pillow numpy scikit-learn matplotlib

Model menggunakan pretrained ImageNet dan membekukan backbone untuk
perbandingan yang lebih sebanding dengan MobileNetV2 pada train_banana.ipynb.
Tidak melakukan pembagian ulang data dan tidak menimpa artifacts_retrain/.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import random
import time
from pathlib import Path

import numpy as np
from PIL import Image, ImageOps
import tensorflow as tf
from sklearn.metrics import (
    classification_report,
    confusion_matrix,
    precision_recall_fscore_support,
)

# Konfigurasi sesuai notebook MobileNetV2 yang ada di proyek.
SEED = 42
IMG_SIZE = 224
CLASSES = ["cordana", "healthy", "pestalotiopsis", "sigatoka"]
LABELS = [x.capitalize() for x in CLASSES]
EXTENSIONS = {".jpg", ".jpeg", ".png"}
BASE_DIR = Path(__file__).resolve().parent


def parse_args():
    p = argparse.ArgumentParser(description="Training DenseNet121 - EcoPlant AI")
    p.add_argument("--epochs", type=int, default=20)
    p.add_argument("--batch-size", type=int, default=16)
    p.add_argument("--dataset", type=Path, default=BASE_DIR / "dataset_retrain",
                   help="Folder dataset dengan train, val, test (default: dataset_retrain)")
    p.add_argument("--output", type=Path, default=BASE_DIR / "artifacts_densenet121",
                   help="Folder penyimpanan model, metrik, dan grafik")
    p.add_argument("--tflite", action="store_true",
                   help="Coba ekspor model float32 ke TFLite (opsional)")
    return p.parse_args()


def load_rgb(path: Path) -> np.ndarray:
    """Sama seperti MobileNetV2: RGB 224x224, nearest-floor, rentang 0..255."""
    with Image.open(path) as source:
        pixels = np.asarray(ImageOps.exif_transpose(source).convert("RGB"))
    ys = np.arange(IMG_SIZE) * pixels.shape[0] // IMG_SIZE
    xs = np.arange(IMG_SIZE) * pixels.shape[1] // IMG_SIZE
    return pixels[ys[:, None], xs[None, :]].astype(np.float32)


def collect_paths(dataset_dir: Path):
    splits = {}
    for split in ("train", "val", "test"):
        paths, targets = [], []
        for label_index, class_name in enumerate(CLASSES):
            folder = dataset_dir / split / class_name
            if not folder.is_dir():
                raise FileNotFoundError(f"Folder belum ada: {folder}")
            class_files = sorted(
                p for p in folder.iterdir()
                if p.is_file() and p.suffix.lower() in EXTENSIONS
            )
            if not class_files:
                raise ValueError(f"Tidak ada gambar dalam: {folder}")
            paths.extend(class_files)
            targets.extend([label_index] * len(class_files))
            print(f"  {split:5s} | {class_name:16s} | {len(class_files)} gambar")
        splits[split] = (paths, np.asarray(targets, dtype=np.int32))
    return splits


def make_dataset(splits, split: str, batch_size: int):
    paths, targets = splits[split]

    def generator():
        for path, label in zip(paths, targets):
            yield load_rgb(path), np.int32(label)

    ds = tf.data.Dataset.from_generator(
        generator,
        output_signature=(
            tf.TensorSpec((IMG_SIZE, IMG_SIZE, 3), dtype=tf.float32),
            tf.TensorSpec((), dtype=tf.int32),
        ),
    )
    ds = ds.apply(tf.data.experimental.assert_cardinality(len(paths)))
    if split == "train":
        ds = ds.shuffle(buffer_size=len(paths), seed=SEED,
                        reshuffle_each_iteration=True)
    return ds.batch(batch_size).prefetch(tf.data.AUTOTUNE)


def build_densenet121():
    inputs = tf.keras.Input(shape=(IMG_SIZE, IMG_SIZE, 3), name="rgb")
    # Augmentasi setara dengan model MobileNetV2 pada notebook asli.
    aug = tf.keras.Sequential([
        tf.keras.layers.RandomFlip("horizontal"),
        tf.keras.layers.RandomRotation(0.08),
    ], name="augmentation")
    x = aug(inputs)

    # Preprocessing DenseNet121/ImageNet: RGB / 255, lalu normalisasi
    # dengan mean dan standar deviasi ImageNet (mode 'torch').
    # Ditaruh DI DALAM model agar input tetap RGB float32 0..255.
    x = tf.keras.layers.Rescaling(1.0 / 255.0, name="rescale_0_1")(x)
    x = tf.keras.layers.Normalization(
        axis=-1,
        mean=[0.485, 0.456, 0.406],
        variance=[0.229 ** 2, 0.224 ** 2, 0.225 ** 2],
        name="imagenet_normalization",
    )(x)

    backbone = tf.keras.applications.DenseNet121(
        include_top=False,
        weights="imagenet",  # Unduh bobot otomatis saat training pertama.
        input_shape=(IMG_SIZE, IMG_SIZE, 3),
    )
    backbone.trainable = False
    x = backbone(x, training=False)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.Dropout(0.2)(x)
    outputs = tf.keras.layers.Dense(
        len(CLASSES), activation="softmax", name="probabilities"
    )(x)
    model = tf.keras.Model(inputs=inputs, outputs=outputs, name="BananaDenseNet121")
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=1e-3),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    return model


def draw_graphs(history, confusion, output_dir):
    # Matplotlib sengaja di-import ketika diperlukan saja.
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    hist = history.history
    fig, axes = plt.subplots(1, 2, figsize=(11, 4))
    axes[0].plot(hist["accuracy"], label="Train")
    axes[0].plot(hist["val_accuracy"], label="Validasi")
    axes[0].set_title("Akurasi DenseNet121")
    axes[0].set_xlabel("Epoch")
    axes[0].set_ylabel("Accuracy")
    axes[0].legend()
    axes[1].plot(hist["loss"], label="Train")
    axes[1].plot(hist["val_loss"], label="Validasi")
    axes[1].set_title("Loss DenseNet121")
    axes[1].set_xlabel("Epoch")
    axes[1].set_ylabel("Loss")
    axes[1].legend()
    fig.tight_layout()
    fig.savefig(output_dir / "training_curves.png", dpi=160)
    plt.close(fig)

    fig, ax = plt.subplots(figsize=(7, 6))
    ax.imshow(confusion, cmap="Blues")
    ax.set_xticks(range(len(LABELS)), labels=LABELS, rotation=30, ha="right")
    ax.set_yticks(range(len(LABELS)), labels=LABELS)
    ax.set_xlabel("Prediksi")
    ax.set_ylabel("Label sebenarnya")
    ax.set_title("Confusion Matrix - DenseNet121")
    threshold = confusion.max() / 2
    for (row, col), count in np.ndenumerate(confusion):
        ax.text(col, row, str(count), ha="center", va="center",
                color="white" if count > threshold else "black")
    fig.tight_layout()
    fig.savefig(output_dir / "confusion_matrix.png", dpi=160)
    plt.close(fig)


def metrics_from_confusion(cm):
    """Baca baseline MobileNetV2 dari confusion matrix pada artifacts_retrain/."""
    true, pred = [], []
    for i in range(len(CLASSES)):
        for j in range(len(CLASSES)):
            true.extend([i] * int(cm[i][j]))
            pred.extend([j] * int(cm[i][j]))
    precision, recall, f1, _ = precision_recall_fscore_support(
        true, pred, labels=list(range(len(CLASSES))),
        average="macro", zero_division=0,
    )
    accuracy = float(np.mean(np.asarray(true) == np.asarray(pred)))
    return accuracy, float(precision), float(recall), float(f1), len(true)


def save_comparison(output_dir, dense_confusion, dataset_dir):
    """Perbandingan terhadap evaluasi MobileNetV2 yang sudah tersedia."""
    rows = []
    base_eval = BASE_DIR / "artifacts_retrain" / "evaluation.json"
    if (dataset_dir.resolve() == (BASE_DIR / "dataset_retrain").resolve()
            and base_eval.is_file()):
        data = json.loads(base_eval.read_text(encoding="utf-8"))
        if data.get("confusion_matrix") and data.get("labels") == LABELS:
            accuracy, p, r, f1, n = metrics_from_confusion(data["confusion_matrix"])
            rows.append({
                "model": "MobileNetV2 (hasil sebelumnya)",
                "accuracy": accuracy, "macro_precision": p,
                "macro_recall": r, "macro_f1": f1,
                "test_images": n,
            })
            print(f"\nMobileNetV2: accuracy={accuracy:.4f}, macro F1={f1:.4f} (hasil tersimpan)")
        else:
            print("[INFO] Evaluasi MobileNetV2 tidak punya label yang cocok; dilewati.")
    else:
        print("[INFO] Baseline MobileNetV2 tidak ditemukan atau dataset berbeda.")

    accuracy, p, r, f1, n = metrics_from_confusion(dense_confusion)
    rows.append({
        "model": "DenseNet121", "accuracy": accuracy,
        "macro_precision": p, "macro_recall": r,
        "macro_f1": f1, "test_images": n,
    })
    path = output_dir / "comparison_models.csv"
    with path.open("w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    print("Tabel perbandingan:", path)


def export_tflite(model, output_dir, test_first_image):
    """Ekspor opsional; tidak memodifikasi model TFLite MobileNetV2 lama."""
    print("\nMengonversi DenseNet121 ke TFLite float32 ...")
    try:
        converter = tf.lite.TFLiteConverter.from_keras_model(model)
        converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS]
        tflite_bytes = converter.convert()
        interpreter = tf.lite.Interpreter(model_content=tflite_bytes)
        interpreter.allocate_tensors()
        input_info = interpreter.get_input_details()[0]
        output_info = interpreter.get_output_details()[0]
        image = load_rgb(test_first_image)[None, ...]
        if input_info["dtype"] != np.float32:
            raise ValueError("Output TFLite tidak memakai input float32 seperti model asli.")
        interpreter.set_tensor(input_info["index"], image)
        interpreter.invoke()
        actual = interpreter.get_tensor(output_info["index"])
        expected = model(image, training=False).numpy()
        np.testing.assert_allclose(actual, expected, rtol=1e-3, atol=1e-4)
        output_path = output_dir / "model.tflite"
        output_path.write_bytes(tflite_bytes)
        metadata = {
            "version": "densenet121-" + hashlib.sha256(tflite_bytes).hexdigest()[:12],
            "model": "DenseNet121", "input_shape": [1, IMG_SIZE, IMG_SIZE, 3],
            "input_dtype": "float32", "pixel_range": [0, 255],
            "color": "RGB", "normalization": "inside_model",
            "resize": "nearest_floor", "labels": LABELS,
        }
        (output_dir / "model_metadata.json").write_text(
            json.dumps(metadata, indent=2), encoding="utf-8"
        )
        print(f"TFLite sukses: {output_path}")
    except Exception as exc:
        print(f"[PERINGATAN] Ekspor/validasi TFLite belum berhasil: {exc}")
        print("Model .keras dan hasil evaluasi tetap tersimpan.")


def main():
    args = parse_args()
    if args.epochs < 1 or args.batch_size < 1:
        raise ValueError("--epochs dan --batch-size harus lebih dari 0")

    dataset_dir = args.dataset.expanduser().resolve()
    output_dir = args.output.expanduser().resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    random.seed(SEED)
    np.random.seed(SEED)
    tf.keras.utils.set_random_seed(SEED)
    print("TensorFlow:", tf.__version__)
    print("Dataset:", dataset_dir)
    print("Output:", output_dir)
    print("\nMemeriksa dataset (train / val / test):")
    splits = collect_paths(dataset_dir)
    train_ds = make_dataset(splits, "train", args.batch_size)
    val_ds = make_dataset(splits, "val", args.batch_size)
    test_ds = make_dataset(splits, "test", args.batch_size)

    model = build_densenet121()
    print(f"\nModel: DenseNet121 | parameter: {model.count_params():,}")
    print("Training backbone dibekukan (transfer learning), sama seperti notebook MobileNetV2.")

    best_model_path = output_dir / "banana_densenet121_best.keras"
    history = model.fit(
        train_ds, validation_data=val_ds, epochs=args.epochs, verbose=1,
        callbacks=[
            tf.keras.callbacks.ModelCheckpoint(
                str(best_model_path), monitor="val_loss", save_best_only=True
            ),
            tf.keras.callbacks.EarlyStopping(
                monitor="val_loss", patience=5, restore_best_weights=True
            ),
            tf.keras.callbacks.CSVLogger(str(output_dir / "training_history.csv")),
        ],
    )

    # Gunakan model checkpoint dengan validation loss terbaik.
    model = tf.keras.models.load_model(str(best_model_path))
    test_metrics = model.evaluate(test_ds, return_dict=True, verbose=1)
    t0 = time.perf_counter()
    probabilities = model.predict(test_ds, verbose=1)
    predict_seconds = time.perf_counter() - t0
    true = splits["test"][1]
    pred = np.argmax(probabilities, axis=1)
    cm = confusion_matrix(true, pred, labels=list(range(len(CLASSES))))
    per_class = classification_report(
        true, pred, target_names=LABELS,
        labels=list(range(len(CLASSES))),
        output_dict=True, zero_division=0,
    )
    print("\n=== HASIL TEST DENSENET121 ===")
    print(f"Test accuracy: {test_metrics['accuracy']:.2%}")
    print(f"Macro F1: {per_class['macro avg']['f1-score']:.4f}")
    print("Confusion matrix:\n", cm)

    evaluation = {
        "model": "DenseNet121", "dataset": str(dataset_dir),
        "epochs_requested": args.epochs,
        "epochs_completed": len(history.history["loss"]),
        "batch_size": args.batch_size, "seed": SEED,
        "metrics": {k: float(v) for k, v in test_metrics.items()},
        "labels": LABELS,
        "confusion_matrix": cm.tolist(),
        "classification_report": per_class,
        "prediction_seconds_total": float(predict_seconds),
        "prediction_seconds_per_image_approx": float(predict_seconds / len(true)),
    }
    (output_dir / "evaluation.json").write_text(
        json.dumps(evaluation, indent=2), encoding="utf-8"
    )
    (output_dir / "labels.json").write_text(
        json.dumps(LABELS, indent=2), encoding="utf-8"
    )
    model.save(str(output_dir / "banana_densenet121_model.keras"))
    draw_graphs(history, cm, output_dir)
    save_comparison(output_dir, cm, dataset_dir)

    if args.tflite:
        export_tflite(model, output_dir, splits["test"][0][0])

    print("\n=== SELESAI ===")
    print("Model terbaik:", best_model_path)
    print("Evaluasi:     ", output_dir / "evaluation.json")
    print("Grafik:       ", output_dir / "training_curves.png")
    print("Perbandingan: ", output_dir / "comparison_models.csv")
    print("Tidak ada file MobileNetV2 lama yang ditimpa.")


if __name__ == "__main__":
    main()
