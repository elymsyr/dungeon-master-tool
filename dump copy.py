import os
import fnmatch

# -------------------------
# Settings
# -------------------------
ROOT_DIR = "cache"     # Folder to scan
OUTPUT_FILE = "output.txt"

# Convert "py" → ".py"
EXTENSIONS = {}
EXTENSIONS = {"." + ext if not ext.startswith(".") else ext for ext in EXTENSIONS}

# Base exclusions
EXCLUDE_DIRS = {".git", ".github", "build", ".vscode", "__pycache__", "worlds", "venv"}

# Wildcards added (handled manually)
EXCLUDE_PATTERNS = ["*.mp3", "*.wav"]
# -------------------------

def matches_exclude_pattern(path):
    """Return True if the full path matches any wildcard exclude pattern."""
    norm = path.replace("\\", "/")  # Normalize for Windows/Linux consistency
    for pattern in EXCLUDE_PATTERNS:
        if fnmatch.fnmatch(norm, f"*/{pattern}") or fnmatch.fnmatch(norm, pattern):
            return True
    return False

def is_excluded_dir(dirpath):
    """Return True if directory should be excluded based on exact match or wildcard path match."""
    # Normalize
    normalized = dirpath.replace("\\", "/")

    # Direct directory name block
    for part in normalized.split("/"):
        if part in EXCLUDE_DIRS:
            return True

    # Wildcard pattern on full path
    if matches_exclude_pattern(normalized):
        return True

    return False

def build_tree(root):
    tree_lines = []

    for dirpath, dirnames, filenames in os.walk(root):
        # Remove excluded dirs (full-path aware)
        dirnames[:] = [
            d for d in dirnames
            if not is_excluded_dir(os.path.join(dirpath, d))
        ]

        level = dirpath.replace(root, "").count(os.sep)
        indent = "    " * level
        dirname = os.path.basename(dirpath) if level > 0 else os.path.basename(root)
        tree_lines.append(f"{indent}{dirname}/")

        sub_indent = "    " * (level + 1)
        for f in filenames:
            tree_lines.append(f"{sub_indent}{f}")

    return "\n".join(tree_lines)

def collect_files(root, extensions):
    file_paths = []

    for dirpath, dirnames, filenames in os.walk(root):
        # Do not enter excluded dirs
        dirnames[:] = [
            d for d in dirnames
            if not is_excluded_dir(os.path.join(dirpath, d))
        ]

        for f in filenames:
            full_path = os.path.join(dirpath, f)
            full_norm = full_path.replace("\\", "/")

            # NEW RULE → Skip if directory or file path matches exclude patterns
            if is_excluded_dir(dirpath) or matches_exclude_pattern(full_norm):
                continue

            # Match extension
            if os.path.splitext(f)[1] in extensions:
                file_paths.append(full_path)

    return file_paths

def write_output(file_paths, output_file, tree_text):
    with open(output_file, "w", encoding="utf8") as out:

        out.write("Directory tree:\n\n")
        out.write(tree_text)
        out.write("\n\n" + "=" * 80 + "\n\n")

        for path in file_paths:
            relative_path = os.path.relpath(path, ROOT_DIR)
            out.write(f"{relative_path}:\n\n")

            try:
                with open(path, "r", encoding="utf8") as f:
                    out.write(f.read())
            except Exception as e:
                out.write(f"[Error reading file: {e}]")

            out.write("\n\n" + "-" * 80 + "\n\n")

if __name__ == "__main__":
    tree = build_tree(ROOT_DIR)
    files = collect_files(ROOT_DIR, EXTENSIONS)
    write_output(files, OUTPUT_FILE, tree)
    print(f"Done. Dumped directory tree and {len(files)} files into {OUTPUT_FILE}")
