import os
from PyQt6.QtWidgets import (QWidget, QHBoxLayout, QSplitter, QMessageBox, 
                             QTabWidget)
from PyQt6.QtCore import Qt, QEvent
from PyQt6.QtGui import QKeySequence, QShortcut

from ui.widgets.npc_sheet import NpcSheet
from ui.workers import ApiSearchWorker
from core.locales import tr

# Sidebar'daki sınıfları artık oradan import etmiyoruz çünkü burada kullanılmıyorlar.
# Ancak EntityTabWidget bu dosyanın sorumluluğunda.

class EntityTabWidget(QTabWidget):
    """
    Sağ taraftaki sekmeli kart yönetim widget'ı.
    Sürükle-bırak ile kart açmayı ve kapatmayı destekler.
    """
    def __init__(self, data_manager, parent_db_tab, panel_id):
        super().__init__()
        self.dm = data_manager
        self.parent_db_tab = parent_db_tab
        self.panel_id = panel_id
        
        self.setTabsClosable(True)
        self.setMovable(True)
        self.setAcceptDrops(True) # Sürükle bırak kabul et
        
        self.tabCloseRequested.connect(self.close_tab)
        
        # --- SHORTCUT: Ctrl + W ---
        self.close_shortcut = QShortcut(QKeySequence("Ctrl+W"), self)
        self.close_shortcut.activated.connect(self.close_current_tab)

        # --- MOUSE MIDDLE CLICK TRACKING ---
        self.tabBar().installEventFilter(self)

        self.setStyleSheet("""
            QTabWidget::pane { border: 1px solid #444; background-color: #1e1e1e; }
            QTabBar::tab { background: #2d2d2d; color: #aaa; padding: 8px 15px; margin-right: 2px; }
            QTabBar::tab:selected { background: #1e1e1e; color: white; border-top: 2px solid #007acc; font-weight: bold; }
            QTabBar::tab:hover { background: #3e3e3e; }
        """)

    def close_current_tab(self):
        """Closes the active tab."""
        idx = self.currentIndex()
        if idx != -1:
            self.close_tab(idx)

    def eventFilter(self, obj, event):
        """Closes the tab when middle-clicked on the tab bar."""
        if obj is self.tabBar() and event.type() == QEvent.Type.MouseButtonRelease:
            if event.button() == Qt.MouseButton.MiddleButton:
                idx = self.tabBar().tabAt(event.pos())
                if idx != -1:
                    self.close_tab(idx)
                    return True
        return super().eventFilter(obj, event)

    def dragEnterEvent(self, event):
        if event.mimeData().hasText(): 
            event.acceptProposedAction()
        else:
            event.ignore()
        
    def dropEvent(self, event):
        # Sidebar'dan sürüklenen ID'yi al
        eid = event.mimeData().text()
        self.parent_db_tab.open_entity_tab(eid, target_panel=self.panel_id)
        event.acceptProposedAction()
        
    def close_tab(self, index):
        widget = self.widget(index)
        if widget: 
            widget.deleteLater()
        self.removeTab(index)


class DatabaseTab(QWidget):
    """
    Sadece sağ taraftaki çalışma alanını (İki bölmeli kart sistemi) yönetir.
    Sol taraftaki liste artık Global Sidebar'da.
    """
    def __init__(self, data_manager, player_window):
        super().__init__()
        self.dm = data_manager
        self.player_window = player_window
        
        self.init_ui()

    def init_ui(self):
        main_layout = QHBoxLayout(self)
        main_layout.setContentsMargins(0, 0, 0, 0)
        
        # Sadece çalışma alanı (İkili Kart Sistemi)
        self.workspace_splitter = QSplitter(Qt.Orientation.Horizontal)
        
        self.tab_manager_left = EntityTabWidget(self.dm, self, "left")
        self.tab_manager_right = EntityTabWidget(self.dm, self, "right")
        
        # Boşken tamamen kaybolmamaları için min width
        self.tab_manager_left.setMinimumWidth(50)
        self.tab_manager_right.setMinimumWidth(50)
        
        self.workspace_splitter.addWidget(self.tab_manager_left)
        self.workspace_splitter.addWidget(self.tab_manager_right)
        
        # Başlangıçta eşit böl
        self.workspace_splitter.setSizes([500, 500])
        self.workspace_splitter.setCollapsible(0, False)
        
        main_layout.addWidget(self.workspace_splitter)

    def open_entity_tab(self, eid, target_panel="left", data=None):
        """
        Belirtilen ID veya Veri ile yeni bir NpcSheet sekmesi açar.
        API'den veri çekme mantığı da buradadır.
        """
        # 1. API ID Kontrolü (lib_...)
        if eid and str(eid).startswith("lib_"):
            parts = eid.split("_")
            raw_cat = parts[1]
            # Basit mapping
            category_map = {"monsters": "Monster", "spells": "Spell", "equipment": "Equipment", "magic-items": "Equipment", "classes": "Class", "races": "Race", "npc": "NPC"}
            target_cat = category_map.get(raw_cat, raw_cat.capitalize())
            
            # Asenkron Worker ile çek
            self._fetch_and_open_api_entity(target_cat, parts[2], target_panel)
            return

        # 2. Hedef Tab Manager'ı belirle
        target_manager = self.tab_manager_left if target_panel == "left" else self.tab_manager_right
        
        # 3. Zaten açıksa o sekmeye odaklan
        if eid:
            for i in range(target_manager.count()):
                sheet = target_manager.widget(i)
                if sheet.property("entity_id") == eid: 
                    target_manager.setCurrentIndex(i)
                    return
            
            # Veritabanından veriyi al
            if not data:
                data = self.dm.data["entities"].get(eid)
        
        if not data: 
            return # Veri yoksa açma

        # 4. Yeni Sheet Oluştur
        new_sheet = NpcSheet(self.dm)
        new_sheet.setProperty("entity_id", eid)
        
        # Sinyal bağlantıları
        # İçindeki linklere tıklandığında yine bu fonksiyonu çağır (recursive navigation)
        new_sheet.request_open_entity.connect(lambda id: self.open_entity_tab(id, target_panel))
        new_sheet.save_requested.connect(lambda: self.save_sheet_data(new_sheet))
        new_sheet.data_changed.connect(lambda: self.mark_tab_unsaved(new_sheet, target_manager))
        
        # Veriyi doldur
        self.populate_sheet(new_sheet, data)
        
        # Silme ve Projeksiyon butonları
        new_sheet.btn_delete.clicked.connect(lambda: self.delete_entity_from_tab(new_sheet))
        new_sheet.btn_project_pdf.clicked.connect(lambda: self.project_entity_pdf(new_sheet))
        
        # PDF butonları
        new_sheet.btn_add_pdf.clicked.connect(new_sheet.add_pdf_dialog)
        new_sheet.btn_open_pdf.clicked.connect(new_sheet.open_current_pdf)
        new_sheet.btn_remove_pdf.clicked.connect(new_sheet.remove_current_pdf)
        new_sheet.btn_open_pdf_folder.clicked.connect(new_sheet.open_pdf_folder)
        
        # Tab Başlığı
        icon_char = "👤" if data.get("type") == "NPC" else "🐉" if data.get("type") == "Monster" else "📜"
        tab_title = f"{icon_char} {data.get('name')}"
        if not eid: tab_title = f"⚠️ {tab_title}" # Kaydedilmemiş
        
        tab_index = target_manager.addTab(new_sheet, tab_title)
        target_manager.setCurrentIndex(tab_index)

    def _fetch_and_open_api_entity(self, cat, idx, target_panel):
        """API Worker başlatır."""
        self.api_worker = ApiSearchWorker(self.dm, cat, idx)
        self.api_worker.finished.connect(lambda s, d, m: self._on_api_fetched(s, d, m, target_panel))
        # Garbage collection'ı önlemek için referansı tutuyoruz, iş bitince sileriz
        self.api_worker.finished.connect(lambda: setattr(self, 'api_worker', None))
        self.api_worker.start()

    def _on_api_fetched(self, success, data_or_id, msg, target_panel):
        if success:
            if isinstance(data_or_id, dict):
                # Yeni veri geldi, import formatına hazırla
                processed_data = self.dm.prepare_entity_from_external(data_or_id)
                self.open_entity_tab(eid=None, target_panel=target_panel, data=processed_data)
            elif isinstance(data_or_id, str):
                # Zaten varmış, ID döndü
                self.open_entity_tab(data_or_id, target_panel)
        else: 
            QMessageBox.warning(self, tr("MSG_ERROR"), msg)

    def save_sheet_data(self, sheet):
        eid = sheet.property("entity_id")
        data = self.collect_data_from_sheet(sheet)
        if not data: return
        
        # Kaydet
        new_eid = self.dm.save_entity(eid, data)
        sheet.setProperty("entity_id", new_eid)
        sheet.is_dirty = False
        
        # Başlığı güncelle
        updated_data = self.dm.data["entities"][new_eid]
        sheet.inp_source.setText(updated_data.get("source", "")) # Kaynak bilgisini güncelle
        
        # Tab başlığını bul ve güncelle
        for manager in [self.tab_manager_left, self.tab_manager_right]:
            idx = manager.indexOf(sheet)
            if idx != -1:
                icon_char = "👤" if data.get("type") == "NPC" else "🐉"
                manager.setTabText(idx, f"{icon_char} {data.get('name')}")
        
        # Global Listeyi yenilemek için sinyal gönderilebilir ama Sidebar zaten yenilenebilir
        # Burada sidebar referansımız yok, ama veri değiştiği için sorun yok.

    def delete_entity_from_tab(self, sheet):
        eid = sheet.property("entity_id")
        if not eid:
            # Henüz kaydedilmemiş, sadece kapat
            self._close_sheet_tab(sheet)
            return

        if QMessageBox.question(self, tr("BTN_DELETE"), tr("MSG_CONFIRM_DELETE")) == QMessageBox.StandardButton.Yes:
            self.dm.delete_entity(eid)
            self._close_sheet_tab(sheet)
            # Sidebar yenilemesi main window üzerinden olur veya otomatik olur.

    def _close_sheet_tab(self, sheet):
        for manager in [self.tab_manager_left, self.tab_manager_right]:
            idx = manager.indexOf(sheet) 
            if idx != -1: 
                manager.removeTab(idx)

    def mark_tab_unsaved(self, sheet, manager):
        idx = manager.indexOf(sheet)
        if idx != -1:
            current_title = manager.tabText(idx)
            if not current_title.startswith("*") and not current_title.startswith("⚠️"):
                manager.setTabText(idx, f"* {current_title}")

    # --- PROJECTION HELPERS ---
    def project_entity_pdf(self, sheet):
        current_item = sheet.list_pdfs.currentItem()
        if not current_item:
            QMessageBox.warning(self, tr("MSG_WARNING"), tr("MSG_SELECT_PDF_FIRST"))
            return
            
        rel_path = current_item.text()
        full_path = self.dm.get_full_path(rel_path)
        
        if full_path and os.path.exists(full_path):
            self.player_window.show_pdf(full_path)
            if not self.player_window.isVisible():
                self.player_window.show()
        else:
            QMessageBox.warning(self, tr("MSG_ERROR"), tr("MSG_FILE_NOT_FOUND_DISK"))

    # --- WRAPPERS ---
    def populate_sheet(self, s, data): 
        s.populate_sheet(data) 
    
    def collect_data_from_sheet(self, s): 
        return s.collect_data_from_sheet()

    def retranslate_ui(self):
        for manager in [self.tab_manager_left, self.tab_manager_right]:
            for i in range(manager.count()):
                widget = manager.widget(i)
                if hasattr(widget, "retranslate_ui"): widget.retranslate_ui()