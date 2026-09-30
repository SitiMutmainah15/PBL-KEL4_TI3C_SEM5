"""Read class folders from OriginalSet and nested dataset collections."""
import hashlib
from collections import defaultdict
from pathlib import Path

from PIL import Image, ImageOps


def check_integrity(root, classes, extensions):
    counts = dict.fromkeys(classes, 0)
    source_counts = defaultdict(lambda: dict.fromkeys(classes, 0))
    hashes = defaultdict(list)
    corrupt, bad_ext, unknown = [], [], []
    for path in sorted(root.rglob("*")):
        if not path.is_file():
            continue
        relative = path.relative_to(root).as_posix()
        if path.suffix.lower() not in extensions:
            bad_ext.append(relative)
            continue
        parents = [p for p in path.parents if p != root and root in p.parents]
        class_dir = next((p for p in parents if p.name.lower() in classes), None)
        if class_dir is None:
            unknown.append(relative)
            continue
        cls = class_dir.name.lower()
        source = class_dir.parent.relative_to(root).as_posix()
        try:
            with Image.open(path) as image:
                image = ImageOps.exif_transpose(image).convert("RGB")
                payload = str(image.size).encode() + b":" + image.tobytes()
                digest = hashlib.sha256(payload).hexdigest()
        except (OSError, ValueError):
            corrupt.append(relative)
            continue
        counts[cls] += 1
        source_counts[source][cls] += 1
        hashes[digest].append((cls, relative))
    conflicts = {h: records for h, records in hashes.items()
                 if len({cls for cls, _ in records}) > 1}
    if unknown:
        raise ValueError(f"Folder kelas gambar tidak dikenali: {unknown[:10]}")
    valid = defaultdict(list)
    removed = []
    for digest, records in hashes.items():
        if digest in conflicts:
            continue
        cls, relative = records[0]
        valid[cls].append(relative)
        removed.extend(path for _, path in records[1:])
    for cls in classes:
        if len(valid[cls]) < 15:
            raise ValueError(f"Kelas {cls} membutuhkan minimal 15 gambar valid untuk split grup.")
    return {"class_counts_raw": counts, "source_counts": dict(source_counts),
            "label_conflicts": conflicts,
            "corrupt": corrupt, "bad_extension": bad_ext,
            "duplicates": {h: [p for _, p in records] for h, records in hashes.items()
                           if len(records) > 1},
            "removed_duplicates": removed, "valid_files": valid}


def build_leaf_groups(files):
    # Numeric proximity is only a heuristic for the original numbered images.
    by_parent = defaultdict(list)
    for relative in files:
        by_parent[Path(relative).parent].append(relative)
    groups = []
    for paths in by_parent.values():
        numbered, others = [], []
        for relative in paths:
            stem = Path(relative).stem
            if stem.isdigit():
                numbered.append((int(stem), relative))
            else:
                others.append(relative)
        current, previous = [], None
        for number, relative in sorted(numbered):
            if current and (number - previous > 1 or len(current) == 5):
                groups.append(current)
                current = []
            current.append(relative)
            previous = number
        if current:
            groups.append(current)
        groups.extend([relative] for relative in sorted(others))
    return groups
