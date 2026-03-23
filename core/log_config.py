"""Logging configuration for the Dungeon Master Tool.

Call setup_logging() once at application startup to configure
all loggers. Individual modules should use:

    import logging
    logger = logging.getLogger(__name__)
"""

import logging
import logging.handlers
import os
import sys


def setup_logging(
    level: str = "INFO",
    log_dir: str | None = None,
    console: bool = True,
    max_bytes: int = 5 * 1024 * 1024,
    backup_count: int = 3,
) -> None:
    """Configure the root logger for the application.

    Args:
        level: Minimum log level as a string (DEBUG, INFO, WARNING, ERROR).
        log_dir: Directory for log files. If None, file logging is disabled.
        console: Whether to output to stderr.
        max_bytes: Maximum size of each log file before rotation.
        backup_count: Number of rotated log files to keep.
    """
    root = logging.getLogger()
    root.setLevel(getattr(logging, level.upper(), logging.INFO))

    formatter = logging.Formatter(
        fmt="%(asctime)s [%(levelname)-8s] %(name)s: %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    if console:
        console_handler = logging.StreamHandler(sys.stderr)
        console_handler.setFormatter(formatter)
        root.addHandler(console_handler)

    if log_dir:
        os.makedirs(log_dir, exist_ok=True)
        file_handler = logging.handlers.RotatingFileHandler(
            os.path.join(log_dir, "dm_tool.log"),
            maxBytes=max_bytes,
            backupCount=backup_count,
            encoding="utf-8",
        )
        file_handler.setFormatter(formatter)
        root.addHandler(file_handler)
