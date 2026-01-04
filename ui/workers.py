from PyQt6.QtCore import QThread, pyqtSignal

class ApiSearchWorker(QThread):
    finished = pyqtSignal(bool, object, str) # success, data, message

    def __init__(self, data_manager, category, query):
        super().__init__()
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
    finished = pyqtSignal(list)

    def __init__(self, api_client, category):
        super().__init__()
        self.api_client = api_client
        self.category = category

    def run(self):
        data = self.api_client.get_list(self.category)
        self.finished.emit(data)
