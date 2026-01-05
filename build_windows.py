import PyInstaller.__main__
import os
import shutil

# Uygulama Adı
APP_NAME = "DungeonMasterTool"

# Önceki build artıklarını temizle
if os.path.exists("dist"): shutil.rmtree("dist")
if os.path.exists("build"): shutil.rmtree("build")

# PyInstaller parametreleri
params = [
    'main.py',                      # Ana dosya
    f'--name={APP_NAME}',           # Exe adı
    '--onefile',                    # Tek bir .exe dosyası üret
    '--noconsole',                  # Siyah terminal penceresini gizle (GUI uygulaması olduğu için)
    '--clean',                      # Build cache'ini temizle
    '--noupx',                      # UPX sıkıştırmasını kapat (Qt DLL hatalarını önler)
    
    # --- PyQt6 ve WebEngine Bağımlılıkları ---
    # WebEngine (PDF ve modern arayüzler için) çok fazla yan dosya içerir.
    # --collect-all diyerek tüm gerekli binary'leri içine almasını garanti ediyoruz.
    '--collect-all=PyQt6',
    '--collect-all=PyQt6.QtWebEngineCore',
    '--collect-all=PyQt6.QtWebEngineWidgets',
    
    # --- Gizli Importlar ---
    # PyInstaller'ın otomatik bulamadığı kütüphaneler
    '--hidden-import=requests',
    '--hidden-import=i18n',
    '--hidden-import=yaml',
    '--hidden-import=json',
    '--hidden-import=PyQt6.QtPrintSupport', 
    '--hidden-import=PyQt6.QtNetwork',
    
    # --- Veri Dosyaları ---
    # (Kaynak Klasör ; Hedef Klasör) formatında
    '--add-data=locales;locales',
    '--add-data=themes;themes',
    
    # Eğer bir ikonunuz varsa assets klasörüne koyup bu satırı açabilirsiniz:
    # '--icon=assets/icon.ico', 
]

print(f"{APP_NAME} için Windows Exe oluşturuluyor...")
print("Bu işlem PyQt6 ve WebEngine dosyalarının büyüklüğü nedeniyle biraz sürebilir...")

PyInstaller.__main__.run(params)

print("-" * 30)
print(f"BAŞARILI! Dosyanız şurada: dist/{APP_NAME}.exe")
print("Bu dosyayı bir USB'ye atıp başka bir bilgisayarda çalıştırabilirsiniz.")