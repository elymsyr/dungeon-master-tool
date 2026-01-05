import os

ROOT_DIR = "./"   # Taranacak ana klasör
OUTPUT_FILE = "all_files_dump.txt"  # Çıkış dosyası

def is_binary(file_path):
    try:
        with open(file_path, "rb") as f:
            chunk = f.read(1024)
            return b'\0' in chunk
    except:
        return True

with open(OUTPUT_FILE, "w", encoding="utf-8") as out:
    for root, dirs, files in os.walk(ROOT_DIR):
        for file in files:
            file_path = os.path.join(root, file)

            # Binary dosyaları atla (png, exe, vs.)
            if is_binary(file_path):
                continue

            try:
                with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
                    content = f.read()

                out.write("===== FILE PATH =====\n")
                out.write(file_path + "\n")
                out.write("===== FILE CONTENT =====\n")
                out.write(content + "\n\n")

            except Exception as e:
                out.write("===== FILE PATH =====\n")
                out.write(file_path + "\n")
                out.write("===== FILE CONTENT =====\n")
                out.write(f"[ERROR READING FILE: {e}]\n\n")

print("Bitti. Tüm dosyalar tek bir txt dosyasına yazıldı.")
