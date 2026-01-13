import PyInstaller.__main__
import os
import shutil

APP_NAME = "DungeonMasterTool"

# Clean
if os.path.exists("dist"):
    shutil.rmtree("dist")
if os.path.exists("build"):
    shutil.rmtree("build")

params = [
    'main.py',
    f'--name={APP_NAME}',
    '--onedir',
    '--noconsole',
    '--clean',
    '--noupx',
    
    # PyQt6 Modules
    '--hidden-import=PyQt6.QtWebEngineWidgets',
    '--hidden-import=PyQt6.QtWebEngineCore',
    '--hidden-import=PyQt6.QtPrintSupport', 
    '--hidden-import=PyQt6.QtNetwork',
    '--hidden-import=PyQt6.QtMultimedia',
    
    # Logic & Data Modules
    '--hidden-import=msgpack',
    '--hidden-import=markdown',
    '--hidden-import=markdown.extensions.extra',
    '--hidden-import=markdown.extensions.nl2br',
    
    # General Utils
    '--hidden-import=requests',
    '--hidden-import=i18n',
    '--hidden-import=yaml',
    '--hidden-import=json',
]

print(f"--- Building {APP_NAME} for Linux ---")
PyInstaller.__main__.run(params)

target_dir = os.path.join("dist", APP_NAME)
folders_to_copy = ["assets", "themes", "locales"]

print("\n--- Copying external resources ---")
for folder in folders_to_copy:
    src = os.path.join(".", folder)
    dst = os.path.join(target_dir, folder)
    if os.path.exists(src):
        if os.path.exists(dst):
            shutil.rmtree(dst)
        shutil.copytree(src, dst)
        print(f"Copied: {folder}")

print("-" * 30)
print(f"SUCCESS: {target_dir}")