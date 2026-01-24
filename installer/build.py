import PyInstaller.__main__
import os
import shutil
import sys

# Uygulama Bilgileri
APP_NAME = "DungeonMasterTool"

def clean():
    """Build ve dist klasörlerini temizler."""
    for folder in ["dist", "build"]:
        if os.path.exists(folder):
            print(f"Cleaning {folder}...")
            shutil.rmtree(folder, ignore_errors=True)

def build():
    # Temel Hidden Importlar (PyInstaller'ın otomatik bulamadığı kütüphaneler)
    hidden_imports = [
        'PyQt6.QtWebEngineWidgets', 
        'PyQt6.QtWebEngineCore',
        'PyQt6.QtPrintSupport', 
        'PyQt6.QtNetwork', 
        'PyQt6.QtMultimedia',
        'PyQt6.QtMultimediaWidgets', # Video görünümü için kritik
        'PyQt6.sip',                 # PyQt6 çekirdek bağlantısı
        'msgpack', 
        'markdown', 
        'markdown.extensions.extra',
        'markdown.extensions.nl2br', 
        'requests', 
        'i18n', 
        'yaml', 
        'json'
    ]
    
    # Kolektif parametreler
    params = [
        'main.py',
        f'--name={APP_NAME}',
        '--onedir',      # Tek bir klasör içine her şeyi koy (folder system)
        '--windowed',    # Terminal açılmasın (GUI mode)
        '--clean',       # Önbelleği temizle
        '--noupx',       # Sıkıştırma yapma (Antivirüs hatalarını ve açılış hızını optimize eder)
    ]

    # Hidden importları listeye ekle
    for imp in hidden_imports:
        params.append(f'--hidden-import={imp}')

    # İkon ayarı
    # Not: assets/icon.png dosyasının var olduğundan emin oluyoruz.
    # PyInstaller Windows'ta PNG'yi ICO'ya, Mac'te ICNS'ye otomatik çevirmeye çalışır.
    if os.path.exists("assets/icon.png"):
        params.append('--icon=assets/icon.png')

    # Platforma özel eklemeler
    if sys.platform == "win32" and os.path.exists("version_info.txt"):
        params.append('--version-file=version_info.txt')

    print(f"--- Starting Build for {sys.platform} ---")
    
    try:
        PyInstaller.__main__.run(params)
    except Exception as e:
        print(f"Build failed: {e}")
        sys.exit(1)

    # --- KAYNAK DOSYALARI KOPYALA ---
    # Uygulamanın çalışması için gereken klasörleri 'dist' içindeki uygulama klasörüne taşırız.
    target_dir = os.path.join("dist", APP_NAME)
    
    # Mac .app paketi için hedef dizin farklıdır
    if sys.platform == "darwin":
        # Mac'te klasör yapısı: dist/DungeonMasterTool/DungeonMasterTool.app/Contents/MacOS/
        # Kaynaklar ise: DungeonMasterTool.app/Contents/Resources/ veya executable yanına konur.
        # Bizim config.py executable yanına baktığı için dist/DungeonMasterTool içine kopyalıyoruz.
        pass

    folders_to_copy = ["assets", "themes", "locales"]

    print("\n--- Copying Resources to Dist ---")
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

    print(f"\n--- SUCCESS: {APP_NAME} Build Completed ({sys.platform}) ---")

if __name__ == "__main__":
    clean()
    build()