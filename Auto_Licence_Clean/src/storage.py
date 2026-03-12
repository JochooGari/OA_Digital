"""
Simple JSON file-based persistence for schedule config and execution history.
Files are stored in Auto_Licence_Clean/data/.
"""

import json
import os
import logging

logger = logging.getLogger(__name__)

DATA_DIR = os.path.join(os.path.dirname(__file__), "..", "data")


def _ensure_data_dir():
    os.makedirs(DATA_DIR, exist_ok=True)


def read_json(filename: str, default=None):
    """Read a JSON file from the data directory. Returns default if missing."""
    filepath = os.path.join(DATA_DIR, filename)
    if not os.path.exists(filepath):
        return default if default is not None else {}
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            return json.load(f)
    except (json.JSONDecodeError, OSError) as e:
        logger.warning("Failed to read %s: %s", filepath, e)
        return default if default is not None else {}


def write_json(filename: str, data):
    """Write data to a JSON file in the data directory (atomic via tmp rename)."""
    _ensure_data_dir()
    filepath = os.path.join(DATA_DIR, filename)
    tmp_path = filepath + ".tmp"
    try:
        with open(tmp_path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        # Atomic rename (Windows: need to remove target first)
        if os.path.exists(filepath):
            os.replace(tmp_path, filepath)
        else:
            os.rename(tmp_path, filepath)
        return True
    except OSError as e:
        logger.error("Failed to write %s: %s", filepath, e)
        return False
