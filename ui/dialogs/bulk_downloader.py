import json
import logging
import os
import time

import requests
from PyQt6.QtCore import Qt, QThread, pyqtSignal
from PyQt6.QtWidgets import (
    QDialog,
    QLabel,
    QMessageBox,
    QProgressBar,
    QPushButton,
    QTextEdit,
    QVBoxLayout,
)

from config import API_BASE_URL, CACHE_DIR, probe_write_access
from core.locales import tr
from core.theme_manager import ThemeManager

logger = logging.getLogger(__name__)

# Library repository
LIBRARY_DIR = os.path.join(CACHE_DIR, "library")
LIBRARY_SOURCE_DIR = os.path.join(LIBRARY_DIR, "dnd5e")

class DownloadWorker(QThread):
    progress_signal = pyqtSignal(int)
    log_signal = pyqtSignal(str)
    finished_signal = pyqtSignal()

    def __init__(self):
        super().__init__()
        self.is_running = True
        
        # Categories to download and API endpoints
        # Note: 'equipment' endpoint covers Weapons, Armor, Adventuring Gear, Tools and Mounts.
        # 'magic-items' covers all magic items. These two provide 100% item coverage.
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
        
        # 1. Prepare Folders
        lib_img_dir = os.path.join(LIBRARY_DIR, "images")
        for endpoint in self.categories.keys():
            path = os.path.join(LIBRARY_SOURCE_DIR, endpoint)
            if not os.path.exists(path): os.makedirs(path)
        if not os.path.exists(lib_img_dir): os.makedirs(lib_img_dir)

        # 1.5 CHECK PERMISSIONS (real write probe)
        if not probe_write_access(LIBRARY_SOURCE_DIR):
            self.log_signal.emit(tr("MSG_ERR_NO_WRITE_PERMISSION"))
            self.finished_signal.emit()
            return

        session = requests.Session()
        
        # Step 1: Fetch All Lists (Index)
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
                    self._save_index(endpoint, items) # Save indexes to cache
                else:
                    self.log_signal.emit(tr("LOG_ERROR_LIST_FAILED", endpoint=endpoint))
            except Exception as e:
                self.log_signal.emit(tr("LOG_CONN_ERROR_DETAIL", error=str(e)))

        # Step 2: Download Details (JSON ONLY - IMAGES ON DEMAND)
        current_count = 0
        for endpoint, items in lists_to_process.items():
            folder_path = os.path.join(LIBRARY_SOURCE_DIR, endpoint)
            label = self.categories[endpoint]
            self.log_signal.emit(tr("LOG_DOWNLOADING", label=label, count=len(items)))
            
            for item in items:
                if not self.is_running: break
                index = item["index"]
                file_path = os.path.join(folder_path, f"{index}.json")
                
                # Skip if file already exists
                if os.path.exists(file_path):
                    current_count += 1
                    if current_count % 10 == 0: self._update_progress(current_count, total_items_to_download)
                    continue

                try:
                    url = f"{API_BASE_URL}/{endpoint}/{index}"
                    resp = session.get(url, timeout=5)
                    if resp.status_code == 200:
                        detail_data = resp.json()
                        
                        # Save JSON
                        with open(file_path, "w", encoding="utf-8") as f:
                            json.dump(detail_data, f, indent=4)
                    
                    time.sleep(0.02) # To avoid hitting API limits (No images, can go fast)
                except Exception as e:
                    self.log_signal.emit(tr("LOG_ERROR_ITEM_DETAIL", index=index, error=str(e)))

                current_count += 1
                if current_count % 5 == 0: self._update_progress(current_count, total_items_to_download)

        self.finished_signal.emit()

    def _update_progress(self, current, total):
        if total > 0:
            percent = int((current / total) * 100)
            self.progress_signal.emit(percent)

    def _save_index(self, endpoint, new_items):
        """
        Saves the list from API to 'reference_indexes.json'.
        IMPORTANT: Merges 'equipment' and 'magic-items' categories under the same Equipment key
        so they appear in a single list in offline search.
        """
        index_file = os.path.join(CACHE_DIR, "reference_indexes.json")
        full_index = {}

        # Read the existing index file
        if os.path.exists(index_file):
            try:
                with open(index_file, "r", encoding="utf-8") as f:
                    full_index = json.load(f)
            except (json.JSONDecodeError, OSError):
                full_index = {}

        # Category keys used by our application
        key_map = {
            "monsters": tr("CAT_MONSTER"),
            "spells": tr("CAT_SPELL"),
            "equipment": tr("CAT_EQUIPMENT"),
            "magic-items": tr("CAT_EQUIPMENT"), # NOTE: Saving both to the same place
            "classes": tr("CAT_CLASS"),
            "races": tr("CAT_RACE")
        }
        
        app_key = key_map.get(endpoint)
        if app_key:
            # If this category exists, overwrite logic
            if app_key == tr("CAT_EQUIPMENT"):
                # Logic to merge Equipment and Magic Items
                existing_list = full_index.get(app_key, [])
                
                # Put existing indexes (ID) into a set to avoid duplicates
                existing_ids = {i["index"] for i in existing_list}
                
                # Add new ones
                for item in new_items:
                    if item["index"] not in existing_ids:
                        existing_list.append(item)
                        existing_ids.add(item["index"])
                
                full_index[app_key] = existing_list
            else:
                # Direct overwrite for other categories (current list)
                full_index[app_key] = new_items

        # Save file
        try:
            with open(index_file, "w", encoding="utf-8") as f:
                json.dump(full_index, f, indent=4)
        except Exception as e:
            logger.error(tr("MSG_INDEX_SAVE_ERROR", error=str(e)))

        # Invalidate msgpack cache so DataManager reloads from JSON
        dat_file = os.path.join(CACHE_DIR, "reference_indexes.dat")
        if os.path.exists(dat_file):
            try:
                os.remove(dat_file)
            except Exception as ex:
                logger.error(tr("MSG_CACHE_INVALIDATION_ERROR", error=str(ex)))

    def stop(self):
        self.is_running = False

class BulkDownloadDialog(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle(tr("TITLE_DOWNLOADER"))
        self.setFixedSize(600, 500)

        self.worker = None
        self.init_ui()
        self.refresh_theme(ThemeManager.get_palette("dark"))

    def init_ui(self):
        layout = QVBoxLayout(self)

        self.lbl_info = QLabel(tr("LBL_DOWNLOADER_DESC"))
        self.lbl_info.setWordWrap(True)
        layout.addWidget(self.lbl_info)

        self.progress_bar = QProgressBar()
        self.progress_bar.setValue(0)
        layout.addWidget(self.progress_bar)

        self.txt_log = QTextEdit()
        self.txt_log.setReadOnly(True)
        layout.addWidget(self.txt_log)

        self.btn_start = QPushButton(tr("BTN_START_DOWNLOAD"))
        self.btn_start.clicked.connect(self.start_download)
        layout.addWidget(self.btn_start)

    def refresh_theme(self, palette: dict) -> None:
        """Apply palette-based styling to all theme-sensitive elements."""
        ui_bg = palette.get("node_bg_entity", "#1e1e1e")
        ui_text = palette.get("html_text", "#e0e0e0")
        border = palette.get("sidebar_divider", "#444")
        bar_bg = palette.get("ui_bg_dark", "#222")
        bar_chunk = palette.get("hp_bar_high", "#2e7d32")
        log_bg = palette.get("canvas_bg", "#121212")
        log_border = palette.get("grid_color", "#333")
        log_text = palette.get("html_dim", "#bbb")
        btn_bg = palette.get("pin_default", "#0d47a1")
        btn_hover = palette.get("line_selected", "#1565c0")
        btn_dis = palette.get("sidebar_divider", "#444")
        btn_dis_text = palette.get("sidebar_label_secondary", "#888")
        self.setStyleSheet(f"background-color: {ui_bg}; color: {ui_text};")
        self.lbl_info.setStyleSheet(f"color: {ui_text}; margin-bottom: 10px;")
        self.progress_bar.setStyleSheet(
            f"QProgressBar {{ border: 2px solid {border}; border-radius: 5px;"
            f" text-align: center; background-color: {bar_bg}; color: {ui_text}; height: 25px; }}"
            f"QProgressBar::chunk {{ background-color: {bar_chunk}; width: 20px; }}"
        )
        self.txt_log.setStyleSheet(
            f"background-color: {log_bg}; border: 1px solid {log_border};"
            f" font-family: 'Consolas', monospace; font-size: 12px; color: {log_text};"
        )
        self.btn_start.setStyleSheet(
            f"QPushButton {{ background-color: {btn_bg}; color: {ui_text};"
            f" padding: 12px; font-weight: bold; font-size: 14px; border-radius: 4px; }}"
            f"QPushButton:hover {{ background-color: {btn_hover}; }}"
            f"QPushButton:disabled {{ background-color: {btn_dis}; color: {btn_dis_text}; }}"
        )

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
        # Auto scroll to bottom
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
