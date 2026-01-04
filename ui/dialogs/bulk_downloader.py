import os
import json
import requests
import time
from PyQt6.QtWidgets import (QDialog, QVBoxLayout, QLabel, QProgressBar, 
                             QPushButton, QTextEdit, QMessageBox)
from PyQt6.QtCore import Qt, QThread, pyqtSignal
from config import BASE_DIR, API_BASE_URL
from core.locales import tr

# Kütüphane deposu
LIBRARY_DIR = os.path.join(BASE_DIR, "cache", "library")

class DownloadWorker(QThread):
    progress_signal = pyqtSignal(int)
    log_signal = pyqtSignal(str)
    finished_signal = pyqtSignal()

    def __init__(self):
        super().__init__()
        self.is_running = True
        # İndirilecek kategoriler ve endpointleri
        self.categories = {
            "monsters": "Canavarlar",
            "spells": "Büyüler",
            "equipment": "Ekipmanlar",
            "magic-items": "Büyülü Eşyalar",
            "classes": "Sınıflar",
            "races": "Irklar"
        }

    def run(self):
        self.log_signal.emit("🚀 İndirme işlemi başlatılıyor...")
        
        # Toplam işlem sayısını tahmin et (Listeleri çekince güncellenecek)
        total_items = 0
        current_count = 0
        
        session = requests.Session()
        
        # 1. Adım: Listeleri Çek
        lists = {}
        for endpoint, name in self.categories.items():
            if not self.is_running: break
            self.log_signal.emit(f"📂 Liste indiriliyor: {name}...")
            try:
                url = f"{API_BASE_URL}/{endpoint}"
                resp = session.get(url)
                if resp.status_code == 200:
                    data = resp.json()
                    items = data.get("results", [])
                    lists[endpoint] = items
                    total_items += len(items)
                    
                    # Listeyi kaydet (Index Cache)
                    self._save_index(endpoint, items)
                else:
                    self.log_signal.emit(f"❌ Hata: {name} listesi alınamadı.")
            except Exception as e:
                self.log_signal.emit(f"❌ Bağlantı hatası: {e}")

        self.log_signal.emit(f"✅ Toplam {total_items} veri indirilecek.")
        
        # 2. Adım: Detayları İndir
        for endpoint, items in lists.items():
            category_dir = os.path.join(LIBRARY_DIR, endpoint)
            if not os.path.exists(category_dir):
                os.makedirs(category_dir)
            
            self.log_signal.emit(f"⬇️ İndiriliyor: {self.categories[endpoint]}...")
            
            for item in items:
                if not self.is_running: break
                
                index = item["index"]
                file_path = os.path.join(category_dir, f"{index}.json")
                
                # Eğer dosya zaten varsa indirme (Zaman kazanmak için)
                if os.path.exists(file_path):
                    current_count += 1
                    progress = int((current_count / total_items) * 100)
                    self.progress_signal.emit(progress)
                    continue

                try:
                    url = f"{API_BASE_URL}/{endpoint}/{index}"
                    resp = session.get(url)
                    if resp.status_code == 200:
                        with open(file_path, "w", encoding="utf-8") as f:
                            json.dump(resp.json(), f, indent=4)
                    
                    # Çok hızlı yaparsak API engelleyebilir, minik bekleme
                    time.sleep(0.05) 
                    
                except Exception as e:
                    self.log_signal.emit(f"⚠️ Atlandı: {item['name']}")

                current_count += 1
                progress = int((current_count / total_items) * 100)
                self.progress_signal.emit(progress)

        self.finished_signal.emit()

    def _save_index(self, category, data):
        # Index dosyasını da güncelle (ApiBrowser için)
        index_file = os.path.join(BASE_DIR, "cache", "reference_indexes.json")
        try:
            if os.path.exists(index_file):
                with open(index_file, "r", encoding="utf-8") as f:
                    full_index = json.load(f)
            else:
                full_index = {}
            
            # Kategori isim eşleştirmesi (Bizim app -> API endpoint)
            # data_manager.py içinde kullandığımız keylere çevirmeliyiz
            key_map = {
                "monsters": "Canavar",
                "spells": "Büyü (Spell)",
                "equipment": "Eşya (Equipment)", # Magic itemleri de buna ekleyeceğiz
                "magic-items": "Magic Item",
                "classes": "Sınıf (Class)",
                "races": "Irk (Race)"
            }
            
            app_key = key_map.get(category)
            if app_key:
                # Eşya ve Magic Item birleşimi için kontrol
                if app_key == "Eşya (Equipment)" and "Eşya (Equipment)" in full_index:
                     # Magic item ise var olan listeye ekle, equipment ise üzerine yaz (sıra önemli değil)
                     # Basitçe overwrite veya append yapalım.
                     # Şimdilik direkt atayalım, data_manager zaten yönetiyor.
                     if category == "magic-items":
                         if "Eşya (Equipment)" in full_index:
                             full_index["Eşya (Equipment)"].extend(data)
                         else:
                             full_index["Eşya (Equipment)"] = data
                     else:
                         full_index[app_key] = data
                else:
                    full_index[app_key] = data

            with open(index_file, "w", encoding="utf-8") as f:
                json.dump(full_index, f, indent=4)
        except Exception as e:
            print(f"Index kayıt hatası: {e}")

    def stop(self):
        self.is_running = False

class BulkDownloadDialog(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle(tr("TITLE_DOWNLOADER"))
        self.setFixedSize(500, 400)
        self.setStyleSheet("background-color: #1e1e1e; color: white;")
        
        self.worker = None
        self.init_ui()

    def init_ui(self):
        layout = QVBoxLayout(self)
        
        lbl_info = QLabel(f"{tr('TITLE_DOWNLOADER')}: {tr('MSG_WARNING')} (2-5 min)") # Basit bir mesaj
        lbl_info.setWordWrap(True)
        lbl_info.setStyleSheet("color: #ccc; font-size: 14px; margin-bottom: 10px;")
        layout.addWidget(lbl_info)
        
        self.progress_bar = QProgressBar()
        self.progress_bar.setValue(0)
        self.progress_bar.setStyleSheet("""
            QProgressBar { border: 2px solid #444; border-radius: 5px; text-align: center; }
            QProgressBar::chunk { background-color: #007acc; width: 20px; }
        """)
        layout.addWidget(self.progress_bar)
        
        self.txt_log = QTextEdit()
        self.txt_log.setReadOnly(True)
        self.txt_log.setStyleSheet("background-color: #111; border: 1px solid #333; font-family: Consolas;")
        layout.addWidget(self.txt_log)
        
        self.btn_start = QPushButton(tr("BTN_START_DOWNLOAD"))
        self.btn_start.setStyleSheet("background-color: #2e7d32; color: white; padding: 10px; font-weight: bold;")
        self.btn_start.clicked.connect(self.start_download)
        layout.addWidget(self.btn_start)

    def start_download(self):
        self.btn_start.setEnabled(False)
        self.btn_start.setText(f"{tr('MSG_LOADING')}...")
        self.txt_log.clear()
        
        self.worker = DownloadWorker()
        self.worker.progress_signal.connect(self.update_progress)
        self.worker.log_signal.connect(self.update_log)
        self.worker.finished_signal.connect(self.on_finished)
        self.worker.start()

    def update_progress(self, val):
        self.progress_bar.setValue(val)

    def update_log(self, text):
        self.txt_log.append(text)

    def on_finished(self):
        self.btn_start.setText(tr("MSG_SUCCESS"))
        self.btn_start.setEnabled(True)
        QMessageBox.information(self, tr("MSG_SUCCESS"), tr("MSG_DOWNLOAD_COMPLETE"))