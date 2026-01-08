import PyInstaller.__main__
import os
import shutil
import sys

# Name of the executable
APP_NAME = "DungeonMasterTool"

# Clean up previous builds
if os.path.exists("dist"): shutil.rmtree("dist")
if os.path.exists("build"): shutil.rmtree("build")

# PyInstaller parameters
params = [
    'main.py',
    f'--name={APP_NAME}',
    '--onedir',  # <-- DEĞİŞTİ: Klasör olarak çıkar
    '--noconsole',
    '--clean',
    # Gerekli importlar
    '--hidden-import=PyQt6',
    '--hidden-import=PyQt6.QtWebEngineWidgets',
    '--hidden-import=requests',
    '--hidden-import=i18n',
    '--hidden-import=yaml',
    
    # Data folders to bundle
    '--add-data=locales:locales',
    '--add-data=themes:themes',
]

print(f"Building {APP_NAME} for Linux (Directory Mode)...")
PyInstaller.__main__.run(params)

# İzinleri ayarla (Klasör içindeki çalıştırılabilir dosyayı bul)
# onedir modunda çıktı: dist/DungeonMasterTool/DungeonMasterTool
binary_folder = os.path.join("dist", APP_NAME)
binary_path = os.path.join(binary_folder, APP_NAME)

if os.path.exists(binary_path):
    os.chmod(binary_path, 0o755)
    print(f"Success! Final binary folder: {binary_folder}")
    print(f"Executable is at: {binary_path}")
else:
    print("Build failed. Executable not found.")