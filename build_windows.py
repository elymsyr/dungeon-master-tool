import PyInstaller.__main__
import os
import shutil

APP_NAME = "DungeonMasterTool"

# Temizlik
if os.path.exists("dist"): shutil.rmtree("dist")
if os.path.exists("build"): shutil.rmtree("build")

# 1. PyInstaller Parametreleri
# --onedir: Tek klasör oluşturur.
# Not: --add-data kullanmıyoruz, klasörleri aşağıda manuel kopyalayacağız.
params = [
    'main.py',
    f'--name={APP_NAME}',
    '--onedir',
    '--noconsole',
    '--clean',
    '--noupx',
    '--version-file=version_info.txt',
    
    # Gerekli kütüphaneler
    '--hidden-import=PyQt6.QtWebEngineWidgets',
    '--hidden-import=PyQt6.QtWebEngineCore',
    '--hidden-import=PyQt6.QtPrintSupport', 
    '--hidden-import=PyQt6.QtNetwork',
    '--hidden-import=requests',
    '--hidden-import=i18n',
    '--hidden-import=yaml',
    '--hidden-import=json',
]

print(f"🔨 Building {APP_NAME} for Windows...")
PyInstaller.__main__.run(params)

# 2. Klasörleri Kopyala (Assets, Themes, Locales)
# Hedef: dist/DungeonMasterTool/
target_dir = os.path.join("dist", APP_NAME)

folders_to_copy = ["assets", "themes", "locales"]

print("\n📂 Copying external resources...")
for folder in folders_to_copy:
    src = os.path.join(".", folder)
    dst = os.path.join(target_dir, folder)
    
    if os.path.exists(src):
        # Hedefte varsa önce sil (temiz kopya)
        if os.path.exists(dst):
            shutil.rmtree(dst)
        shutil.copytree(src, dst)
        print(f"   ✅ Copied: {folder}")
    else:
        print(f"   ⚠️ Warning: Source folder not found: {folder}")

print("-" * 30)
print(f"🎉 SUCCESS! Build available at: {target_dir}")
print(f"   Run: {os.path.join(target_dir, APP_NAME + '.exe')}")