import os

# ---------------- AYARLAR ----------------

# Çıktının yazılacağı dosya adı
OUTPUT_FILENAME = "tum_icerik.txt"

# İçine girilmeyecek ve taranmayacak KLASÖRLER
IGNORE_DIRS = {
    ".git", 
    ".gitignore", 
    "__pycache__", 
    "node_modules", 
    "venv", 
    ".idea", 
    ".vscode",
    "build",
    "dist",
    "cache"
}

# İşleme alınmayacak DOSYA İSİMLERİ (Tam eşleşme)
IGNORE_FILES = {
    OUTPUT_FILENAME,  # Çıktı dosyasının kendisi
    "dump.py",        # Bu scriptin kendisi
    ".DS_Store",      # Mac sistem dosyası
    "package-lock.json",
    "yarn.lock",
    "dump.py",
    "LICENSE"
}

# İçeriği okunmayacak DOSYA UZANTILARI
# (Genellikle binary/resim dosyaları veya çok büyük loglar)
IGNORE_EXTENSIONS = {
    ".exe", ".dll", ".so", ".bin", 
    ".png", ".jpg", ".jpeg", ".gif", ".ico", ".svg",
    ".zip", ".tar", ".gz", ".rar", ".7z",
    ".pyc", ".db", ".sqlite", ".pdf"
}

# -----------------------------------------

def is_ignored(filename):
    """Dosya isminin veya uzantısının yasaklı listede olup olmadığını kontrol eder."""
    # 1. Tam dosya ismi kontrolü
    if filename in IGNORE_FILES:
        return True
    
    # 2. Uzantı kontrolü
    # Dosya uzantısını al (örn: .py, .txt) ve küçük harfe çevir
    _, ext = os.path.splitext(filename)
    if ext.lower() in IGNORE_EXTENSIONS:
        return True
        
    return False

def main():
    current_dir = os.getcwd()
    
    try:
        with open(OUTPUT_FILENAME, "w", encoding="utf-8") as out_file:
            # os.walk ile gezinti
            for root, dirs, files in os.walk(current_dir):
                
                # --- KLASÖR FİLTRELEME ---
                # dirs listesini yerinde (in-place) güncelleyerek
                # os.walk'ın yasaklı klasörlerin içine girmesini engelliyoruz.
                dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]
                
                for filename in files:
                    # --- DOSYA FİLTRELEME ---
                    if is_ignored(filename):
                        continue
                    
                    file_path = os.path.join(root, filename)
                    relative_path = os.path.relpath(file_path, current_dir)
                    
                    # Başlıkları yaz
                    out_file.write("-" * 50 + "\n")
                    out_file.write(f"Path: {relative_path}\n")
                    out_file.write("-" * 50 + "\n")
                    
                    # İçeriği oku ve yaz
                    try:
                        with open(file_path, "r", encoding="utf-8", errors='replace') as f:
                            content = f.read()
                            # Eğer dosya boşsa belirtelim (isteğe bağlı)
                            if not content:
                                out_file.write("[DOSYA BOŞ]\n")
                            else:
                                out_file.write(content + "\n")
                                
                    except Exception as e:
                        out_file.write(f"[HATA: Dosya okunamadı. Hata: {e}]\n")
                    
                    out_file.write("\n") # Dosyalar arası boşluk

        print(f"Bitti! İçerik '{OUTPUT_FILENAME}' dosyasına, filtreler uygulanarak kaydedildi.")
        
    except IOError as e:
        print(f"Dosya yazma hatası: {e}")

if __name__ == "__main__":
    main()