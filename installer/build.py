import PyInstaller.__main__
import os
import shutil
import sys

APP_NAME = "DungeonMasterTool"

def clean():
    for folder in ["dist", "build"]:
        if os.path.exists(folder):
            print(f"Cleaning {folder}...")
            shutil.rmtree(folder, ignore_errors=True)

def build():
    hidden_imports = [
        'PyQt6.QtWebEngineWidgets', 'PyQt6.QtWebEngineCore',
        'PyQt6.QtPrintSupport', 'PyQt6.QtNetwork', 
        'PyQt6.QtMultimedia', 'PyQt6.QtMultimediaWidgets',
        'PyQt6.sip', 'msgpack', 'markdown', 
        'markdown.extensions.extra', 'markdown.extensions.nl2br', 
        'requests', 'i18n', 'yaml', 'json'
    ]
    
    params = [
        'main.py',
        f'--name={APP_NAME}',
        '--onedir',
        '--windowed', # MacOS'ta .app bundle oluşturur, Windows'ta konsolu gizler
        '--clean',
        '--noupx',
    ]

    for imp in hidden_imports:
        params.append(f'--hidden-import={imp}')

    if os.path.exists("assets/icon.png"):
        params.append('--icon=assets/icon.png')

    if sys.platform == "win32" and os.path.exists("version_info.txt"):
        params.append('--version-file=version_info.txt')

    print(f"--- Starting Build for {sys.platform} ---")
    
    try:
        PyInstaller.__main__.run(params)
    except Exception as e:
        print(f"Build failed: {e}")
        sys.exit(1)

    # --- KAYNAK DOSYALARI KOPYALA ---
    # MacOS .app paketi yapısı farklıdır. Executable 'Contents/MacOS' içindedir.
    if sys.platform == "darwin":
        target_dir = os.path.join("dist", f"{APP_NAME}.app", "Contents", "MacOS")
    else:
        target_dir = os.path.join("dist", APP_NAME)

    folders_to_copy = ["assets", "themes", "locales"]

    print(f"\n--- Copying Resources to {target_dir} ---")
    for folder in folders_to_copy:
        src = os.path.join(".", folder)
        dst = os.path.join(target_dir, folder)
        
        if os.path.exists(src):
            if os.path.exists(dst):
                shutil.rmtree(dst)
            shutil.copytree(src, dst)
            print(f"Success: Copied {folder}")
        else:
            print(f"Warning: Source folder {folder} not found!")

if __name__ == "__main__":
    clean()
    build()