import os
import requests
from PyQt6.QtCore import QThread, pyqtSignal

class ApiSearchWorker(QThread):
    finished = pyqtSignal(bool, object, str) # success, data, message

    def __init__(self, data_manager, category, query, parent=None):
        super().__init__(parent)
        self.data_manager = data_manager
        self.category = category
        self.query = query

    def run(self):
        try:
            # fetch_from_api artık ya (True, msg, ID) dönüyor (zaten varsa)
            # ya da (True, msg, DATA_DICT) dönüyor (yeni çekildiyse)
            success, msg, result = self.data_manager.fetch_from_api(self.category, self.query)
            self.finished.emit(success, result, msg)
        except Exception as e:
            self.finished.emit(False, {}, str(e))

class ApiListWorker(QThread):
    finished = pyqtSignal(object) # list or dict

    def __init__(self, api_client, category, page=1, filters=None, parent=None):
        super().__init__(parent)
        self.api_client = api_client
        self.category = category
        self.page = page
        self.filters = filters

    def run(self):
        data = self.api_client.get_list(self.category, page=self.page, filters=self.filters)
        self.finished.emit(data)

class ImageDownloadWorker(QThread):
    """
    Resmi arka planda indirir ve kaydedilen yerel yolu sinyal olarak döner.
    UI donmasını engellemek için NpcSheet tarafından kullanılır.
    """
    finished = pyqtSignal(bool, str) # success, local_abs_path

    def __init__(self, url, save_dir, filename):
        super().__init__()
        self.url = url
        self.save_dir = save_dir
        self.filename = filename

    def run(self):
        try:
            if not os.path.exists(self.save_dir):
                os.makedirs(self.save_dir)
            
            full_path = os.path.join(self.save_dir, self.filename)
            
            # Dosya zaten varsa indirme (Cache kontrolü)
            if os.path.exists(full_path):
                self.finished.emit(True, full_path)
                return

            # Resmi indir
            response = requests.get(self.url, timeout=15)
            if response.status_code == 200:
                with open(full_path, "wb") as f:
                    f.write(response.content)
                self.finished.emit(True, full_path)
            else:
                self.finished.emit(False, "")
        except Exception as e:
            print(f"Image download error: {e}")
            self.finished.emit(False, "")