import os
import pathlib

import hy  # noqa: F401  -- enables importing .hy modules
import pytest

# Flask looks for templates/ relative to the current directory for these apps.
os.chdir(pathlib.Path(__file__).parent)


def pytest_collect_file(file_path, parent):
    """Let pytest collect Hy test files named test_*.hy."""
    if file_path.suffix == ".hy" and file_path.name.startswith("test_"):
        return pytest.Module.from_parent(parent, path=file_path)
