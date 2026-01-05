import PyInstaller.__main__
import os
import shutil
import sys

# Name of the executable
APP_NAME = "DungeonMasterTool"

# Clean up previous builds
if os.path.exists("dist"): shutil.rmtree("dist")
if os.path.exists("build"): shutil.rmtree("build")

# PyInstaller parameters for Windows
params = [
    'main.py',
    f'--name={APP_NAME}',
    '--onefile',
    '--noconsole',
    '--clean',
    '--noupx',
    # '--manifest=win_compat.xml',
    # Gerekli importlar
    '--hidden-import=PyQt6',
    '--hidden-import=PyQt6.QtCore',
    '--hidden-import=PyQt6.QtGui',
    '--hidden-import=PyQt6.QtWidgets',
    '--hidden-import=PyQt6.QtWebEngineWidgets',
    '--hidden-import=PyQt6.QtWebEngineCore',
    '--hidden-import=requests',
    '--hidden-import=i18n',
    '--hidden-import=yaml',
    '--collect-submodules=PyQt6',
    
    # Data folders to bundle (Windows uses semicolon separator for add-data)
    '--add-data=locales;locales',
    '--add-data=themes;themes',
    # '--icon=assets/icon.ico', # Uncomment if an icon exists
]

print(f"Building {APP_NAME} for Windows...")
PyInstaller.__main__.run(params)

print(f"Process complete! Check the 'dist' folder for {APP_NAME}.exe")
