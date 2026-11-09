import os

import hy  # noqa: F401  -- enables importing .hy modules
import pytest

# Use a non-interactive backend so plt.show() does not open a window.
os.environ["MPLBACKEND"] = "Agg"


def pytest_collect_file(file_path, parent):
    """Let pytest collect Hy test files named test_*.hy."""
    if file_path.suffix == ".hy" and file_path.name.startswith("test_"):
        return pytest.Module.from_parent(parent, path=file_path)
