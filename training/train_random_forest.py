"""Latih Random Forest 64 fitur histogram RGB + hue dan ekspor ke forest.json.

Contoh:
    python training/train_random_forest.py --copy-to ecoplant/assets/models
"""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
import sklearn
from PIL import Image, ImageOps
from sklearn.ensemble import RandomForestClassifier
from sklearn.impute import SimpleImputer
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix
from sklearn.pipeline import make_pipeline

BASE_DIR = Path(__file__).resolve().parent
CLASSES = ["Cordana", "Healthy", "Pestalotiopsis", "Sigatoka"]
IMAGE_SIZE = (64, 64)
BINS = 16
SEED = 42
N_TREES = 300
EXTENSIONS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}


def hue_histogram(pixels):
    """Hue 0-1 dari RGB uint8, aturan sama dengan leaf_features.dart."""
    rgb = pixels.astype(np.int32)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    maxc = rgb.max(axis=2)
    delta = (maxc - rgb.min(axis=2)).astype(np.float64)
    with np.errstate(divide="ignore", invalid="ignore"):
        # Urutan cabang R, G, B harus sama dengan hue di Dart.
        hue = np.where(
            maxc == r,
            ((g - b) / delta) % 6,
            np.where(maxc == g, (b - r) / delta + 2, (r - g) / delta + 4),
        )
    hue[delta == 0] = 0
    bins = np.minimum((hue / 6 * BINS).astype(np.int64), BINS - 1)
    return np.bincount(bins.ravel(), minlength=BINS) * BINS / maxc.size


def leaf_features(image):
    """PIL image -> 64 angka. Sampling nearest harus sama dengan copyResize di Dart."""
    pixels = np.asarray(ImageOps.exif_transpose(image).convert("RGB"))
    rows = np.arange(IMAGE_SIZE[1]) * pixels.shape[0] // IMAGE_SIZE[1]
    cols = np.arange(IMAGE_SIZE[0]) * pixels.shape[1] // IMAGE_SIZE[0]
    pixels = pixels[np.ix_(rows, cols)]
    scaled = pixels.astype(np.float32) / 255.0
    return np.concatenate(
        [
            np.histogram(scaled[:, :, ch], bins=BINS, range=(0, 1), density=True)[0]
            for ch in range(3)
        ]
        + [hue_histogram(pixels)]
    )


def load_split(split_dir):
    X, y = [], []
    for folder in sorted(p for p in split_dir.iterdir() if p.is_dir()):
        label = folder.name.capitalize()
        if label not in CLASSES:
            raise ValueError(f"Folder kelas tidak dikenal: {folder}")
        for path in sorted(folder.iterdir()):
            if path.suffix.lower() not in EXTENSIONS:
                continue
            with Image.open(path) as image:
                X.append(leaf_features(image))
            y.append(CLASSES.index(label))
    if not X:
        raise ValueError(f"Tidak ada gambar di {split_dir}")
    return np.asarray(X), np.asarray(y)


def load_one(path):
    with Image.open(path) as image:
        return leaf_features(image)


def export_forest(clf, labels):
    trees = []
    for estimator in clf.estimators_:
        tree = estimator.tree_
        values = tree.value.reshape(len(tree.feature), -1)
        leaf = tree.children_left == -1
        probabilities = np.zeros_like(values)
        probabilities[leaf] = values[leaf] / values[leaf].sum(axis=1, keepdims=True)
        trees.append(
            {
                "f": tree.feature.tolist(),
                # Tanpa pembulatan: threshold bisa hanya 1e-7 di bawah nilai fitur.
                "t": tree.threshold.tolist(),
                "l": tree.children_left.tolist(),
                "r": tree.children_right.tolist(),
                "p": [[round(float(v), 9) for v in row] for row in probabilities],
            }
        )
    payload = {"features": BINS * 4, "labels": labels, "trees": trees}
    digest = hashlib.sha256(json.dumps(payload, sort_keys=True).encode()).hexdigest()
    payload["version"] = f"banana-rf-{digest[:12]}"
    return payload


def predict_forest(forest, features):
    """Traversal yang sama dengan implementasi Dart, untuk memeriksa ekspor."""
    totals = np.zeros(len(forest["labels"]))
    for tree in forest["trees"]:
        node = 0
        while tree["l"][node] != -1:
            node = (
                tree["l"][node]
                if features[tree["f"][node]] <= tree["t"][node]
                else tree["r"][node]
            )
        totals += tree["p"][node]
    return totals / len(forest["trees"])


def main():
    parser = argparse.ArgumentParser(description="Train Random Forest EcoPlant")
    parser.add_argument("--dataset", default=str(BASE_DIR / "dataset_retrain"))
    parser.add_argument("--output", default=str(BASE_DIR / "artifacts_rf"))
    parser.add_argument("--copy-to", default=None)
    args = parser.parse_args()

    dataset = Path(args.dataset).resolve()
    output = Path(args.output).resolve()
    output.mkdir(parents=True, exist_ok=True)

    print(f"Dataset: {dataset}")
    X_train, y_train = load_split(dataset / "train")
    X_val, y_val = load_split(dataset / "val")
    X_test, y_test = load_split(dataset / "test")
    print(f"Train {X_train.shape} | Val {X_val.shape} | Test {X_test.shape}")

    pipeline = make_pipeline(
        SimpleImputer(strategy="median"),
        RandomForestClassifier(
            n_estimators=N_TREES,
            class_weight="balanced_subsample",
            random_state=SEED,
            n_jobs=-1,
        ),
    )
    pipeline.fit(X_train, y_train)

    for name, X, y in (("val", X_val, y_val), ("test", X_test, y_test)):
        predictions = pipeline.predict(X)
        print(f"\n[{name}] accuracy={accuracy_score(y, predictions):.4f}")
        print(
            classification_report(
                y, predictions, labels=range(len(CLASSES)),
                target_names=CLASSES, zero_division=0,
            )
        )

    test_predictions = pipeline.predict(X_test)
    forest = export_forest(pipeline.named_steps["randomforestclassifier"], CLASSES)

    for features, expected in zip(X_test[:200], test_predictions[:200]):
        got = int(np.argmax(predict_forest(forest, features)))
        if got != expected:
            raise AssertionError("Ekspor forest.json tidak cocok dengan sklearn")

    assert forest["features"] == 64
    assert len(forest["labels"]) == 4 and len(set(forest["labels"])) == 4
    assert len(forest["trees"]) == N_TREES
    assert all(
        abs(sum(p) - 1) < 1e-6
        for tree in forest["trees"]
        for p in tree["p"]
        if any(p)
    )

    evaluation = {
        "model": "Random Forest",
        "metrics": {"accuracy": float(accuracy_score(y_test, test_predictions))},
        "labels": CLASSES,
        "confusion_matrix": confusion_matrix(
            y_test, test_predictions, labels=range(len(CLASSES))
        ).tolist(),
    }
    metadata = {
        "version": forest["version"],
        "features": BINS * 4,
        "resize": list(IMAGE_SIZE),
        "interpolation": "nearest",
        "color": "RGB",
        "normalization": "outside_model",
        "pixel_range": [0, 1],
        "labels": CLASSES,
        "n_estimators": N_TREES,
        "test_metrics": {"accuracy": evaluation["metrics"]["accuracy"]},
        "sklearn_version": sklearn.__version__,
    }

    files = {
        "forest.json": json.dumps(forest, separators=(",", ":")),
        "labels.json": json.dumps(CLASSES, indent=2),
        "model_metadata.json": json.dumps(metadata, indent=2),
        "evaluation.json": json.dumps(evaluation, indent=2),
    }

    # Disimpan sebagai PNG karena decoder JPEG Dart dan Pillow tidak identik.
    parity_candidates = sorted((dataset / "test").rglob("*.jpeg"))
    if parity_candidates:
        reference = output / "parity.png"
        with Image.open(parity_candidates[0]) as image:
            ImageOps.exif_transpose(image).convert("RGB").save(reference)
        features = load_one(reference)
        expected = CLASSES[int(np.argmax(predict_forest(forest, features)))]
        if expected != CLASSES[int(pipeline.predict([features])[0])]:
            raise AssertionError("Paritas fitur gagal untuk foto uji")
        files["parity.json"] = json.dumps(
            {
                "image": reference.relative_to(BASE_DIR.parent).as_posix(),
                "features": [round(float(v), 9) for v in features],
                "expected": expected,
            },
            indent=2,
        )
    for name, content in files.items():
        (output / name).write_text(content, encoding="utf-8")
        print("Menulis", output / name, f"({len(content) / 1e6:.2f} MB)")

    if args.copy_to:
        target = Path(args.copy_to).resolve()
        target.mkdir(parents=True, exist_ok=True)
        for name in ("forest.json", "labels.json", "model_metadata.json"):
            (target / name).write_text(files[name], encoding="utf-8")
        print("Disalin ke", target)


if __name__ == "__main__":
    main()
