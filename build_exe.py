import PyInstaller.__main__
import os
import shutil

# Temizlik
if os.path.exists("dist"): shutil.rmtree("dist")
if os.path.exists("build"): shutil.rmtree("build")

# PyInstaller parametreleri
params = [
    'main.py',
    '--name=DungeonMasterTool',
    '--onefile',
    '--noconsole',
    '--clean',
    '--icon=assets/icon.ico', # Added icon parameter
    # Gerekli importlar (bazen otomatik algılamaz)
    '--hidden-import=PyQt6',
    '--hidden-import=requests',
    '--hidden-import=PyQt6.QtWebEngineWidgets', # PDF Projection support
    
    # Data dosyaları: (src, dest)
    # config.py, core vs kodun içine gömülür.
    # Ancak eğer asset, icon vs varsa buraya eklenmeli.
    # Şu anlık ekstra asset dosyamız proje kökünde yok gibi (assets klasörü user docs'ta olacak).
    # Eğer proje içinde dağıtılması gereken sabit data (örn default icons) olsaydı:
    # '--add-data=assets;assets',
]

print("EXE Hazirlaniyor...")
PyInstaller.__main__.run(params)
print("Islem Tamamlandi! 'dist' klasorunu kontrol edin.")
