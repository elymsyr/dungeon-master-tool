import PyInstaller.__main__
import os
import shutil

# Uygulama Adı
APP_NAME = "DungeonMasterTool"

# Clean up previous builds
if os.path.exists("dist"): shutil.rmtree("dist")
if os.path.exists("build"): shutil.rmtree("build")

# PyInstaller parameters
params = [
    'main.py',
    f'--name={APP_NAME}',
    '--onefile',
    '--noconsole',
    '--clean',
    '--noupx',
    
    # Dependencies
    '--collect-all=PyQt6',
    '--collect-all=PyQt6.QtWebEngineCore',
    '--collect-all=PyQt6.QtWebEngineWidgets',
    
    # Hidden Imports
    '--hidden-import=requests',
    '--hidden-import=i18n',
    '--hidden-import=yaml',
    '--hidden-import=json',
    '--hidden-import=PyQt6.QtPrintSupport', 
    '--hidden-import=PyQt6.QtNetwork',
    
    # Data Files
    '--add-data=locales;locales',
    '--add-data=themes;themes',
    
    # '--icon=assets/icon.ico', 
]

print(f"Building Windows Exe for {APP_NAME}...")
print("This process may take a while due to PyQt6 and WebEngine files...")

PyInstaller.__main__.run(params)

print("-" * 30)
print(f"SUCCESS! File located at: dist/{APP_NAME}.exe")
print("You can now distribute this file.")