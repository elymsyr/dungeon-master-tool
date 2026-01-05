import PyInstaller.__main__
import os
import shutil

APP_NAME = "DungeonMasterTool"

# Temizlik
if os.path.exists("dist"): shutil.rmtree("dist")
if os.path.exists("build"): shutil.rmtree("build")

params = [
    'main.py',
    f'--name={APP_NAME}',
    '--onefile',
    '--noconsole',
    '--clean',
    '--noupx',
    
    # --- OPTİMİZASYON: collect-all yerine hooks kullanıyoruz ---
    # PyInstaller'ın kendi hook'ları artık PyQt6'yı tanıyor.
    # Sadece gerekli modülleri import ediyoruz.
    
    '--hidden-import=PyQt6.QtWebEngineWidgets',
    '--hidden-import=PyQt6.QtWebEngineCore',
    '--hidden-import=PyQt6.QtPrintSupport', 
    '--hidden-import=PyQt6.QtNetwork',
    '--hidden-import=requests',
    '--hidden-import=i18n',
    '--hidden-import=yaml',
    '--hidden-import=json',
    
    # Veri Dosyaları
    '--add-data=locales;locales',
    '--add-data=themes;themes',
]

print(f"Building optimized Windows Exe for {APP_NAME}...")
PyInstaller.__main__.run(params)

print("-" * 30)
print(f"SUCCESS! File: dist/{APP_NAME}.exe")