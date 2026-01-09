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
        
        # İndirilecek tüm kategoriler ve API uç noktaları (Endpoints)
        # Not: 'equipment' endpoint'i; Weapons, Armor, Adventuring Gear, Tools ve Mounts'u kapsar.
        # 'magic-items' ise tüm büyülü eşyaları kapsar. Bu ikisi toplam %100 eşya kapsamı sağlar.
        self.categories = {
            "monsters": tr("CAT_MONSTERS_PL"),
            "spells": tr("CAT_SPELLS_PL"),
            "equipment": tr("CAT_EQUIPMENT_ALL"), 
            "magic-items": tr("CAT_MAGIC_ITEMS_ALL"),
            "classes": tr("CAT_CLASSES_PL"),
            "races": tr("CAT_RACES_PL")
        }

    def run(self):
        self.log_signal.emit(tr("LOG_STARTING"))
        
        # 1. Klasörleri Hazırla
        lib_img_dir = os.path.join(LIBRARY_DIR, "images")
        for endpoint in self.categories.keys():
            path = os.path.join(LIBRARY_DIR, endpoint)
            if not os.path.exists(path): os.makedirs(path)
        if not os.path.exists(lib_img_dir): os.makedirs(lib_img_dir)

        session = requests.Session()
        
        # Adım 1: Tüm Listeleri (Index) Çek
        lists_to_process = {}
        total_items_to_download = 0
        
        for endpoint, label in self.categories.items():
            if not self.is_running: break
            self.log_signal.emit(tr("LOG_SCANNING", label=label))
            try:
                url = f"{API_BASE_URL}/{endpoint}"
                resp = session.get(url, timeout=10)
                if resp.status_code == 200:
                    items = resp.json().get("results", [])
                    lists_to_process[endpoint] = items
                    total_items_to_download += len(items)
                    self._save_index(endpoint, items) # Indexleri cache'e kaydet
                else:
                    self.log_signal.emit(f"❌ Error: {endpoint} list failed.")
            except Exception as e:
                self.log_signal.emit(f"❌ Conn Error: {str(e)}")

        # Adım 2: Detayları İndir (SADECE JSON - RESİMLER İSTEK ÜZERİNE İNECEK)
        current_count = 0
        for endpoint, items in lists_to_process.items():
            folder_path = os.path.join(LIBRARY_DIR, endpoint)
            label = self.categories[endpoint]
            self.log_signal.emit(tr("LOG_DOWNLOADING", label=label, count=len(items)))
            
            for item in items:
                if not self.is_running: break
                index = item["index"]
                file_path = os.path.join(folder_path, f"{index}.json")
                
                # Eğer dosya zaten varsa atla
                if os.path.exists(file_path):
                    current_count += 1
                    if current_count % 10 == 0: self._update_progress(current_count, total_items_to_download)
                    continue

                try:
                    url = f"{API_BASE_URL}/{endpoint}/{index}"
                    resp = session.get(url, timeout=5)
                    if resp.status_code == 200:
                        detail_data = resp.json()
                        
                        # JSON'ı kaydet
                        with open(file_path, "w", encoding="utf-8") as f:
                            json.dump(detail_data, f, indent=4)
                    
                    time.sleep(0.02) # API limitlerine takılmamak için (Resim yok, hızlı geçebiliriz)
                except Exception as e:
                    self.log_signal.emit(f"⚠️ Error {index}: {str(e)}")

                current_count += 1
                if current_count % 5 == 0: self._update_progress(current_count, total_items_to_download)

        self.finished_signal.emit()

    def _update_progress(self, current, total):
        if total > 0:
            percent = int((current / total) * 100)
            self.progress_signal.emit(percent)

    def _save_index(self, endpoint, new_items):
        """
        API'den gelen listeyi 'reference_indexes.json' dosyasına kaydeder.
        ÖNEMLİ: 'equipment' ve 'magic-items' kategorilerini 'Eşya (Equipment)' altında birleştirir.
        Böylece çevrimdışı aramada hepsi tek listede çıkar.
        """
        index_file = os.path.join(BASE_DIR, "cache", "reference_indexes.json")
        full_index = {}
        
        # Mevcut index dosyasını oku
        if os.path.exists(index_file):
            try:
                with open(index_file, "r", encoding="utf-8") as f:
                    full_index = json.load(f)
            except:
                full_index = {}

        # Bizim uygulamanın kullandığı kategori anahtarları
        key_map = {
            "monsters": "Canavar",
            "spells": "Büyü (Spell)",
            "equipment": "Eşya (Equipment)",
            "magic-items": "Eşya (Equipment)", # DİKKAT: İkisini de aynı yere kaydediyoruz
            "classes": "Sınıf (Class)",
            "races": "Irk (Race)"
        }
        
        app_key = key_map.get(endpoint)
        if app_key:
            # Eğer bu kategori zaten varsa, üzerine yazma mantığı
            if app_key == "Eşya (Equipment)":
                # Equipment ve Magic Items birleştirme mantığı
                existing_list = full_index.get(app_key, [])
                
                # Mevcut listedeki indexleri (ID) bir set'e at ki duplicate olmasın
                existing_ids = {i["index"] for i in existing_list}
                
                # Yeni gelenleri ekle
                for item in new_items:
                    if item["index"] not in existing_ids:
                        existing_list.append(item)
                        existing_ids.add(item["index"])
                
                full_index[app_key] = existing_list
            else:
                # Diğer kategoriler için direkt overwrite (güncel liste)
                full_index[app_key] = new_items

        # Dosyayı kaydet
        try:
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
        self.setFixedSize(600, 500)
        self.setStyleSheet("background-color: #1e1e1e; color: white;")
        
        self.worker = None
        self.init_ui()

    def init_ui(self):
        layout = QVBoxLayout(self)
        
        # Bilgi Etiketi
        lbl_info = QLabel(tr("LBL_DOWNLOADER_DESC"))
        lbl_info.setWordWrap(True)
        lbl_info.setStyleSheet("color: #e0e0e0; margin-bottom: 10px;")
        layout.addWidget(lbl_info)
        
        # İlerleme Çubuğu
        self.progress_bar = QProgressBar()
        self.progress_bar.setValue(0)
        self.progress_bar.setStyleSheet("""
            QProgressBar { 
                border: 2px solid #444; 
                border-radius: 5px; 
                text-align: center; 
                background-color: #222;
                color: white;
                height: 25px;
            }
            QProgressBar::chunk { 
                background-color: #2e7d32; 
                width: 20px; 
            }
        """)
        layout.addWidget(self.progress_bar)
        
        # Log Penceresi
        self.txt_log = QTextEdit()
        self.txt_log.setReadOnly(True)
        self.txt_log.setStyleSheet("""
            background-color: #121212; 
            border: 1px solid #333; 
            font-family: 'Consolas', monospace; 
            font-size: 12px; 
            color: #bbb;
        """)
        layout.addWidget(self.txt_log)
        
        # Başlat Butonu
        self.btn_start = QPushButton(tr("BTN_START_DOWNLOAD"))
        self.btn_start.setStyleSheet("""
            QPushButton {
                background-color: #0d47a1; 
                color: white; 
                padding: 12px; 
                font-weight: bold; 
                font-size: 14px;
                border-radius: 4px;
            }
            QPushButton:hover { background-color: #1565c0; }
            QPushButton:disabled { background-color: #444; color: #888; }
        """)
        self.btn_start.clicked.connect(self.start_download)
        layout.addWidget(self.btn_start)

    def start_download(self):
        self.btn_start.setEnabled(False)
        self.btn_start.setText(tr("MSG_DOWNLOADING_WAIT"))
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
        # Otomatik en alta kaydır
        sb = self.txt_log.verticalScrollBar()
        sb.setValue(sb.maximum())

    def on_finished(self):
        self.btn_start.setText(tr("MSG_DOWNLOAD_FINISHED"))
        self.btn_start.setEnabled(True)
        self.progress_bar.setValue(100)
        if self.parent() and hasattr(self.parent(), "dm"):
            self.parent().dm.reload_library_cache()
            
        QMessageBox.information(self, tr("MSG_SUCCESS"), tr("MSG_DOWNLOAD_COMPLETE"))

    def closeEvent(self, event):
        if self.worker and self.worker.isRunning():
            reply = QMessageBox.question(self, tr("BTN_CANCEL"), 
                                       tr("MSG_CONFIRM_CLOSE_DOWNLOAD"),
                                       QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No)
            if reply == QMessageBox.StandardButton.Yes:
                self.worker.stop()
                self.worker.wait()
                event.accept()
            else:
                event.ignore()
        else:
            event.accept()