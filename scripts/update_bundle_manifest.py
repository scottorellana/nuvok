#!/usr/bin/env python3
"""update_bundle_manifest.py — Regenerate the bundled library manifest.

Scans assets/bundled_library/{maps,zim,models}/ for files that exist
and generates manifest.json with their sizes and SHA-256 checksums.
Files not present are simply omitted from the manifest.
"""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).parent.parent
BUNDLE_DIR = ROOT / 'assets' / 'bundled_library'
MANIFEST_PATH = BUNDLE_DIR / 'manifest.json'

# Metadata for known files
KNOWN = {
    'maps/honduras.pmtiles': {'kind': 'maps', 'label': 'Mapa offline Honduras', 'target': 'maps/honduras.pmtiles'},
    'maps/el-salvador.pmtiles': {'kind': 'maps', 'label': 'Mapa offline El Salvador', 'target': 'maps/el-salvador.pmtiles'},
    'maps/guatemala.pmtiles': {'kind': 'maps', 'label': 'Mapa offline Guatemala', 'target': 'maps/guatemala.pmtiles'},
    'maps/nicaragua.pmtiles': {'kind': 'maps', 'label': 'Mapa offline Nicaragua', 'target': 'maps/nicaragua.pmtiles'},
    'maps/costa-rica.pmtiles': {'kind': 'maps', 'label': 'Mapa offline Costa Rica', 'target': 'maps/costa-rica.pmtiles'},
    'maps/panama.pmtiles': {'kind': 'maps', 'label': 'Mapa offline Panamá', 'target': 'maps/panama.pmtiles'},
    'maps/mexico.pmtiles': {'kind': 'maps', 'label': 'Mapa offline México', 'target': 'maps/mexico.pmtiles'},
    'maps/haiti.pmtiles': {'kind': 'maps', 'label': 'Mapa offline Haïti', 'target': 'maps/haiti.pmtiles'},
    'maps/dominican-republic.pmtiles': {'kind': 'maps', 'label': 'Mapa offline República Dominicana', 'target': 'maps/dominican-republic.pmtiles'},
    'maps/usa-northeast.pmtiles': {'kind': 'maps', 'label': 'Mapa offline USA Northeast', 'target': 'maps/usa-northeast.pmtiles'},
    'zim/wikipedia_es_medicine_maxi_2026-04.zim': {'kind': 'zim', 'label': 'Wikipedia médica offline en español', 'target': 'zim/wikipedia_es_medicine_maxi_2026-04.zim'},
    'zim/wikipedia_en_medicine_maxi_2026-04.zim': {'kind': 'zim', 'label': 'Medical Wikipedia offline (English)', 'target': 'zim/wikipedia_en_medicine_maxi_2026-04.zim'},
    'zim/wikipedia_mini.zim': {'kind': 'zim', 'label': 'Wikipedia mini offline', 'target': 'zim/wikipedia_mini.zim'},
    'models/qwen2.5-0.5b-instruct-q4_k_m.gguf': {'kind': 'models', 'label': 'Modelo IA Qwen 0.5B GGUF offline', 'target': 'models/qwen2.5-0.5b-instruct-q4_k_m.gguf'},
}

def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(4 * 1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()

def main():
    entries = []
    for subdir in ['maps', 'zim', 'models']:
        dir_path = BUNDLE_DIR / subdir
        if not dir_path.exists():
            continue
        for f in sorted(dir_path.iterdir()):
            if not f.is_file() or f.name.startswith('.'):
                continue
            rel = f'{subdir}/{f.name}'
            meta = KNOWN.get(rel, {
                'kind': subdir,
                'label': f.name,
                'target': rel,
            })
            entry = {
                'kind': meta['kind'],
                'label': meta['label'],
                'asset': f'assets/bundled_library/{rel}',
                'target': meta['target'],
                'bytes': f.stat().st_size,
                'sha256': sha256(f),
            }
            entries.append(entry)

    manifest = {
        'version': 1,
        'description': 'Contenido offline incluido en la instalación única de Nuvok.',
        'entries': entries,
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + '\n')
    print(f'Manifest: {len(entries)} entries')
    for e in entries:
        print(f'  {e["kind"]:8} {e["asset"]:60} {e["bytes"]:>12,}')

if __name__ == '__main__':
    main()
