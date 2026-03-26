"""Shared fixtures for UI tests.

Ensures Qt widgets are properly cleaned up between tests to prevent
event-loop hangs caused by GC running during Qt operations.
"""

import gc
import pytest


@pytest.fixture(autouse=True)
def _qt_cleanup():
    """Run GC before and after each test to collect stale Qt wrapper objects."""
    gc.collect()
    yield
    gc.collect()
