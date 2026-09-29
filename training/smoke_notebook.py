"""Exercise notebook training/export on a single batch without publishing assets."""
import ast
import json
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parent
nb = json.loads((root / 'train_banana.ipynb').read_text(encoding='utf-8'))
for i, cell in enumerate(nb['cells']):
    if cell['cell_type'] == 'code':
        ast.parse(''.join(cell['source']), filename=f'cell_{i}')
print('All notebook code cells parse.', flush=True)
namespace = {}

def run(index):
    print(f'Running cell {index}', flush=True)
    exec(compile(''.join(nb['cells'][index]['source']), f'cell_{index}', 'exec'), namespace)

with tempfile.TemporaryDirectory(prefix='banana-smoke-', dir=root / 'artifacts') as temp:
    run(2)
    run(20)
    namespace['ARTIFACT_DIR'] = Path(temp)
    namespace['BEST_MODEL_PATH'] = Path(temp) / 'best.keras'
    run(22)
    namespace['train_ds'] = namespace['train_ds'].take(1)
    namespace['val_ds'] = namespace['val_ds'].take(1)
    namespace['EPOCHS'] = 1
    run(24)
    namespace['split_paths']['test'] = namespace['split_paths']['test'][:8]
    namespace['split_targets']['test'] = namespace['split_targets']['test'][:8]
    namespace['test_ds'] = namespace['make_dataset']('test')
    run(26)
    run(28)
    print('PASS: one-batch training, Keras reload, test evaluation, TFLite parity.', flush=True)
