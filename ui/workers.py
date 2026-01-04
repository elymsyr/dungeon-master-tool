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
            # DataManager'ın existing fetch metodunu kullanacağız ama artık thread içinde
            success, msg, eid = self.data_manager.fetch_from_api(self.category, self.query)
            # fetch_from_api -> (Success, Msg, ID) döner
            # Bizim sinyalimiz: (Success, Data/ID, Msg)
            self.finished.emit(success, eid, msg)
        except Exception as e:
            self.finished.emit(False, None, str(e))

class ApiListWorker(QThread):
    finished = pyqtSignal(list)

    def __init__(self, api_client, category):
        super().__init__()
        self.api_client = api_client
        self.category = category

    def run(self):
        data = self.api_client.get_list(self.category)
        self.finished.emit(data)
