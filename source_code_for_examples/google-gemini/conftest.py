import os

import hy  # noqa: F401  -- enables importing .hy modules
import pytest

# genai.Client() is created when the modules are imported and needs a key;
# the tests never call the real API, so a placeholder is enough.
os.environ.setdefault("GOOGLE_API_KEY", "test-key")


def pytest_collect_file(file_path, parent):
    """Let pytest collect Hy test files named test_*.hy."""
    if file_path.suffix == ".hy" and file_path.name.startswith("test_"):
        return pytest.Module.from_parent(parent, path=file_path)
