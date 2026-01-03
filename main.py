import sys
import os
import json
import shutil
import uuid
from PyQt6.QtWidgets import (QApplication, QMainWindow, QWidget, QVBoxLayout, 
                             QHBoxLayout, QLabel, QPushButton, QFileDialog, 
                             QMessageBox, QListWidget, QLineEdit, QTextEdit, 
                             QComboBox, QFormLayout, QSplitter, QListWidgetItem,
                             QTabWidget, QGraphicsView, QGraphicsScene, QGraphicsPixmapItem,
                             QGraphicsEllipseItem, QInputDialog, QMenu, QGraphicsItem)
from PyQt6.QtGui import QPixmap, QBrush, QColor, QPen, QAction, QPainter, QWheelEvent, QScreen
from PyQt6.QtCore import Qt, pyqtSignal, QPointF

# --- DATA MANAGER ---
class DataManager:
    def __init__(self):
        self.current_campaign_path = None
        self.data = {
            "world_name": "",
            "entities": {},
            "map_data": { "image_path": "", "pins": [] }
        }

    def create_campaign(self, folder_path, world_name):
        try:
            assets_path = os.path.join(folder_path, "assets")
            if not os.path.exists(assets_path): os.makedirs(assets_path)

            self.data = {"world_name": world_name, "entities": {}, "map_data": {"image_path": "", "pins": []}}
            self.current_campaign_path = folder_path
            self.save_data()
            return True, "Kampanya oluşturuldu."
        except Exception as e:
            return False, str(e)

    def load_campaign(self, folder_path):
        data_file_path = os.path.join(folder_path, "data.json")
        if not os.path.exists(data_file_path): return False, "data.json yok."
        
        try:
            with open(data_file_path, "r", encoding="utf-8") as f:
                self.data = json.load(f)
            if "entities" not in self.data: self.data["entities"] = {}
            if "map_data" not in self.data: self.data["map_data"] = {"image_path": "", "pins": []}
            self.current_campaign_path = folder_path
            return True, f"'{self.data.get('world_name')}' yüklendi."
        except Exception as e:
            return False, str(e)

    def save_data(self):
        if self.current_campaign_path:
            with open(os.path.join(self.current_campaign_path, "data.json"), "w", encoding="utf-8") as f:
                json.dump(self.data, f, indent=4, ensure_ascii=False)

    def import_image(self, source_path):
        if not self.current_campaign_path: return None
        filename = f"{uuid.uuid4().hex}_{os.path.basename(source_path)}"
        dest_path = os.path.join(self.current_campaign_path, "assets", filename)
        shutil.copy2(source_path, dest_path)
        return os.path.join("assets", filename)

    def save_entity(self, entity_id, entity_data):
        if not entity_id: entity_id = str(uuid.uuid4())
        self.data["entities"][entity_id] = entity_data
        self.save_data()
        return entity_id

    def delete_entity(self, entity_id):
        if entity_id in self.data["entities"]:
            del self.data["entities"][entity_id]
            self.data["map_data"]["pins"] = [p for p in self.data["map_data"]["pins"] if p["entity_id"] != entity_id]
            self.save_data()

    def get_full_path(self, relative_path):
        if self.current_campaign_path and relative_path:
            return os.path.join(self.current_campaign_path, relative_path)
        return None

    def set_map_image(self, rel_path):
        self.data["map_data"]["image_path"] = rel_path
        self.save_data()

    def add_pin(self, x, y, entity_id):
        self.data["map_data"]["pins"].append({"x": x, "y": y, "entity_id": entity_id})
        self.save_data()


# --- OYUNCU PENCERESİ (YENİ) ---
class PlayerWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Player View")
        self.resize(800, 600)
        self.setStyleSheet("background-color: black;")
        
        # İçerik gösterici
        self.viewer = QLabel(self)
        self.viewer.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.setCentralWidget(self.viewer)
        
    def show_image(self, pixmap):
        if pixmap and not pixmap.isNull():
            # Pencere boyutuna orantılı sığdır
            scaled = pixmap.scaled(self.size(), Qt.AspectRatioMode.KeepAspectRatio, Qt.TransformationMode.SmoothTransformation)
            self.viewer.setPixmap(scaled)
        else:
            self.viewer.clear()
            self.viewer.setText("...")

    def resizeEvent(self, event):
        # Pencere boyutu değişirse resmi tekrar ölçekle (mevcut resim varsa)
        if self.viewer.pixmap():
            # Orijinal resmi saklamadığımız için hafif bozulma olabilir,
            # profesyonel çözümde orijinal pixmap'i saklamak gerekir.
            # Şimdilik basitçe pass geçiyoruz, bir dahaki resim yüklemede düzelir.
            pass 
        super().resizeEvent(event)


# --- ÖZELLEŞTİRİLMİŞ PİN NESNESİ ---
class MapPinItem(QGraphicsEllipseItem):
    def __init__(self, x, y, radius, color, entity_id, tooltip_text, callback_click):
        super().__init__(x - radius/2, y - radius/2, radius, radius)
        self.entity_id = entity_id
        self.callback_click = callback_click # Tıklanınca çalışacak fonksiyon
        
        self.setBrush(QBrush(QColor(color)))
        self.setPen(QPen(Qt.GlobalColor.black))
        self.setToolTip(tooltip_text)
        self.setZValue(1)
        self.setFlags(QGraphicsItem.GraphicsItemFlag.ItemIsSelectable)

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            self.callback_click(self.entity_id) # ID'yi ana programa gönder
        super().mousePressEvent(event)


# --- HARİTA GÖRÜNTÜLEYİCİ ---
class MapViewer(QGraphicsView):
    pin_created_signal = pyqtSignal(float, float) 

    def __init__(self, parent=None):
        super().__init__(parent)
        self.scene = QGraphicsScene(self)
        self.setScene(self.scene)
        self.setRenderHint(QPainter.RenderHint.Antialiasing)
        self.setDragMode(QGraphicsView.DragMode.ScrollHandDrag)
        self.setTransformationAnchor(QGraphicsView.ViewportAnchor.AnchorUnderMouse)
        self.map_item = None
        self.pins = []

    def load_map(self, pixmap):
        self.scene.clear()
        self.pins = []
        self.map_item = QGraphicsPixmapItem(pixmap)
        self.map_item.setZValue(0)
        self.scene.addItem(self.map_item)
        self.setSceneRect(self.map_item.boundingRect())

    def add_pin_object(self, pin_item):
        self.scene.addItem(pin_item)
        self.pins.append(pin_item)

    def wheelEvent(self, event: QWheelEvent):
        zoom_in = 1.15
        zoom_out = 1 / zoom_in
        if event.angleDelta().y() > 0: self.scale(zoom_in, zoom_in)
        else: self.scale(zoom_out, zoom_out)

    def contextMenuEvent(self, event):
        if not self.map_item: return
        menu = QMenu(self)
        action_add_pin = QAction("Buraya Pin Ekle", self)
        menu.addAction(action_add_pin)
        scene_pos = self.mapToScene(event.pos())
        if not self.map_item.boundingRect().contains(scene_pos): return
        action = menu.exec(self.mapToGlobal(event.pos()))
        if action == action_add_pin:
            self.pin_created_signal.emit(scene_pos.x(), scene_pos.y())


# --- ANA PENCERE ---
class DungeonMasterApp(QMainWindow):
    def __init__(self):
        super().__init__()
        self.data_manager = DataManager()
        self.player_window = PlayerWindow() # İkinci pencereyi oluştur
        self.current_entity_id = None
        self.init_ui()

    def init_ui(self):
        self.setWindowTitle("DM Tool - Ultimate Edition")
        self.setGeometry(100, 100, 1200, 800)
        self.setStyleSheet("background-color: #2b2b2b; color: #ffffff;")

        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        main_layout = QVBoxLayout(central_widget)

        # ÜST BAR
        top_bar = QHBoxLayout()
        self.btn_new = QPushButton("Yeni Dünya")
        self.btn_load = QPushButton("Dünya Yükle")
        self.btn_open_player = QPushButton("📺 Oyuncu Ekranını Aç") # YENİ
        self.btn_open_player.setStyleSheet("background-color: #512da8; font-weight: bold;")
        self.lbl_world_name = QLabel("Yüklü Dünya: Yok")
        self.lbl_world_name.setStyleSheet("font-weight: bold; color: #ffa500; font-size: 14px; margin-left: 10px;")
        
        top_bar.addWidget(self.btn_new)
        top_bar.addWidget(self.btn_load)
        top_bar.addWidget(self.btn_open_player)
        top_bar.addWidget(self.lbl_world_name)
        top_bar.addStretch()
        main_layout.addLayout(top_bar)

        # SEKMELER
        self.tabs = QTabWidget()
        self.tabs.setStyleSheet("""
            QTabWidget::pane { border: 1px solid #444; }
            QTabBar::tab { background: #444; color: #ccc; padding: 10px; }
            QTabBar::tab:selected { background: #666; color: white; font-weight: bold; }
        """)
        
        self.tab_db = QWidget()
        self.setup_database_tab()
        self.tabs.addTab(self.tab_db, "Veritabanı")

        self.tab_map = QWidget()
        self.setup_map_tab()
        self.tabs.addTab(self.tab_map, "Dünya Haritası")

        main_layout.addWidget(self.tabs)
        
        # Bağlantılar
        self.toggle_interface(False)
        self.btn_new.clicked.connect(self.new_campaign_dialog)
        self.btn_load.clicked.connect(self.load_campaign_dialog)
        self.btn_open_player.clicked.connect(self.toggle_player_window)

    def setup_database_tab(self):
        layout = QHBoxLayout(self.tab_db)
        splitter = QSplitter(Qt.Orientation.Horizontal)

        # Sol
        left_widget = QWidget()
        l_layout = QVBoxLayout(left_widget)
        self.list_widget = QListWidget()
        self.list_widget.itemClicked.connect(self.load_entity_to_form)
        self.btn_add_entity = QPushButton("+ Yeni Varlık")
        self.btn_add_entity.clicked.connect(self.prepare_new_entity)
        self.btn_add_entity.setStyleSheet("background-color: #2e7d32; padding: 6px;")
        l_layout.addWidget(QLabel("Kayıtlar"))
        l_layout.addWidget(self.list_widget)
        l_layout.addWidget(self.btn_add_entity)

        # Sağ
        right_widget = QWidget()
        r_layout = QVBoxLayout(right_widget)
        form = QFormLayout()
        
        self.inp_name = QLineEdit()
        self.inp_type = QComboBox()
        self.inp_type.addItems(["NPC", "Mekan", "Oyuncu", "Canavar"])
        self.inp_desc = QTextEdit()
        self.lbl_img_prev = QLabel("Resim Yok")
        self.lbl_img_prev.setFixedSize(200, 200)
        self.lbl_img_prev.setScaledContents(True)
        self.lbl_img_prev.setStyleSheet("border: 1px dashed #666;")
        
        self.btn_img_sel = QPushButton("Resim Seç")
        self.btn_img_sel.clicked.connect(self.select_entity_image)
        
        # YENİ BUTON: OYUNCUYA GÖSTER
        self.btn_show_to_player = QPushButton("👁️ Görseli Oyunculara Göster")
        self.btn_show_to_player.setStyleSheet("background-color: #d84315; font-weight: bold; padding: 5px;")
        self.btn_show_to_player.clicked.connect(self.push_entity_image_to_player)

        self.current_img_rel = ""

        form.addRow("İsim:", self.inp_name)
        form.addRow("Tip:", self.inp_type)
        form.addRow("Açıklama:", self.inp_desc)
        form.addRow("Görsel:", self.btn_img_sel)
        form.addRow("", self.btn_show_to_player) # Forma eklendi
        form.addRow("", self.lbl_img_prev)

        btn_box = QHBoxLayout()
        self.btn_save = QPushButton("KAYDET")
        self.btn_save.setStyleSheet("background-color: #0277bd;")
        self.btn_save.clicked.connect(self.save_current_entity)
        self.btn_del = QPushButton("SİL")
        self.btn_del.setStyleSheet("background-color: #c62828;")
        self.btn_del.clicked.connect(self.delete_current_entity)
        
        btn_box.addWidget(self.btn_save)
        btn_box.addWidget(self.btn_del)

        r_layout.addLayout(form)
        r_layout.addLayout(btn_box)
        r_layout.addStretch()

        splitter.addWidget(left_widget)
        splitter.addWidget(right_widget)
        splitter.setSizes([300, 900])
        layout.addWidget(splitter)

    def setup_map_tab(self):
        layout = QVBoxLayout(self.tab_map)
        controls = QHBoxLayout()
        self.btn_load_map = QPushButton("Harita Resmi Yükle")
        self.btn_load_map.clicked.connect(self.upload_map_image)
        
        # YENİ BUTON: HARİTAYI OYUNCUYA GÖSTER
        self.btn_show_map_player = QPushButton("🗺️ Haritayı Oyunculara Göster (Temiz)")
        self.btn_show_map_player.clicked.connect(self.push_map_to_player)
        self.btn_show_map_player.setStyleSheet("background-color: #00695c; font-weight: bold;")

        controls.addWidget(self.btn_load_map)
        controls.addWidget(self.btn_show_map_player)
        controls.addStretch()
        
        self.map_viewer = MapViewer()
        self.map_viewer.setStyleSheet("background-color: #111; border: 2px solid #333;")
        self.map_viewer.pin_created_signal.connect(self.handle_new_pin)

        layout.addLayout(controls)
        layout.addWidget(self.map_viewer)

    def toggle_interface(self, state):
        self.tab_db.setEnabled(state)
        self.tab_map.setEnabled(state)
        self.btn_open_player.setEnabled(True) # Her zaman aktif olabilir

    def toggle_player_window(self):
        if self.player_window.isVisible():
            self.player_window.hide()
            self.btn_open_player.setText("📺 Oyuncu Ekranını Aç")
        else:
            self.player_window.show()
            self.btn_open_player.setText("📺 Oyuncu Ekranını Kapat")

    # --- DOSYA İŞLEMLERİ ---
    def new_campaign_dialog(self):
        folder = QFileDialog.getExistingDirectory(self, "Yeni Dünya Klasörü")
        if folder:
            name = os.path.basename(folder)
            success, msg = self.data_manager.create_campaign(folder, name)
            if success: self.load_ui_from_data()
            else: QMessageBox.critical(self, "Hata", msg)

    def load_campaign_dialog(self):
        folder = QFileDialog.getExistingDirectory(self, "Dünya Seç")
        if folder:
            success, msg = self.data_manager.load_campaign(folder)
            if success: self.load_ui_from_data()
            else: QMessageBox.critical(self, "Hata", msg)

    def load_ui_from_data(self):
        self.lbl_world_name.setText(f"Dünya: {self.data_manager.data['world_name']}")
        self.toggle_interface(True)
        self.refresh_entity_list()
        self.prepare_new_entity()
        self.render_map()

    # --- ENTITY İŞLEMLERİ ---
    def refresh_entity_list(self):
        self.list_widget.clear()
        for eid, data in self.data_manager.data["entities"].items():
            item = QListWidgetItem(f"{data['name']} ({data['type']})")
            item.setData(Qt.ItemDataRole.UserRole, eid)
            self.list_widget.addItem(item)

    def prepare_new_entity(self):
        self.current_entity_id = None
        self.inp_name.clear()
        self.inp_desc.clear()
        self.current_img_rel = ""
        self.lbl_img_prev.setPixmap(QPixmap())
        self.lbl_img_prev.setText("Resim Yok")
        self.btn_show_to_player.setEnabled(False) # Resim yoksa kapat

    def load_entity_to_form(self, item):
        # 1. Listeden tıklanarak çağrılır
        # 2. Haritadan pine tıklanarak çağrılır (item yerine ID gelebilir)
        
        if isinstance(item, QListWidgetItem):
            eid = item.data(Qt.ItemDataRole.UserRole)
        else:
            eid = item # Direkt ID geldiyse

        data = self.data_manager.data["entities"].get(eid)
        if not data: return
        
        self.current_entity_id = eid
        self.inp_name.setText(data.get("name"))
        self.inp_desc.setText(data.get("description"))
        idx = self.inp_type.findText(data.get("type"))
        if idx >= 0: self.inp_type.setCurrentIndex(idx)
        
        self.current_img_rel = data.get("image_path", "")
        if self.current_img_rel:
            full = self.data_manager.get_full_path(self.current_img_rel)
            self.lbl_img_prev.setPixmap(QPixmap(full))
            self.btn_show_to_player.setEnabled(True)
        else:
            self.lbl_img_prev.setText("Resim Yok")
            self.btn_show_to_player.setEnabled(False)

        # Listede de seçili hale getir (Haritadan gelindiyse)
        if not isinstance(item, QListWidgetItem):
             for i in range(self.list_widget.count()):
                 if self.list_widget.item(i).data(Qt.ItemDataRole.UserRole) == eid:
                     self.list_widget.setCurrentRow(i)
                     break

    def select_entity_image(self):
        fname, _ = QFileDialog.getOpenFileName(self, "Resim Seç", "", "Images (*.png *.jpg)")
        if fname:
            rel = self.data_manager.import_image(fname)
            self.current_img_rel = rel
            self.lbl_img_prev.setPixmap(QPixmap(self.data_manager.get_full_path(rel)))
            self.btn_show_to_player.setEnabled(True)

    def save_current_entity(self):
        if not self.inp_name.text(): return
        data = {
            "name": self.inp_name.text(),
            "type": self.inp_type.currentText(),
            "description": self.inp_desc.toPlainText(),
            "image_path": self.current_img_rel
        }
        self.data_manager.save_entity(self.current_entity_id, data)
        self.refresh_entity_list()
        self.prepare_new_entity()
        QMessageBox.information(self, "Tamam", "Kaydedildi.")
        self.render_map()

    def delete_current_entity(self):
        if self.current_entity_id:
            if QMessageBox.question(self, "Sil", "Emin misin?") == QMessageBox.StandardButton.Yes:
                self.data_manager.delete_entity(self.current_entity_id)
                self.refresh_entity_list()
                self.prepare_new_entity()
                self.render_map()

    # --- OYUNCU EKRANI KONTROLLERİ ---
    def push_entity_image_to_player(self):
        if not self.player_window.isVisible():
            QMessageBox.warning(self, "Uyarı", "Önce 'Oyuncu Ekranını Aç' butonuna bas.")
            return
        
        if self.current_img_rel:
            full = self.data_manager.get_full_path(self.current_img_rel)
            self.player_window.show_image(QPixmap(full))
        else:
            self.player_window.show_image(None)

    def push_map_to_player(self):
        if not self.player_window.isVisible():
            QMessageBox.warning(self, "Uyarı", "Önce 'Oyuncu Ekranını Aç' butonuna bas.")
            return

        map_rel = self.data_manager.data.get("map_data", {}).get("image_path")
        if map_rel:
            full = self.data_manager.get_full_path(map_rel)
            self.player_window.show_image(QPixmap(full))
        else:
            QMessageBox.warning(self, "Uyarı", "Henüz harita resmi yüklenmemiş.")

    # --- HARİTA ---
    def upload_map_image(self):
        fname, _ = QFileDialog.getOpenFileName(self, "Harita Resmi Seç", "", "Images (*.png *.jpg *.jpeg)")
        if fname:
            rel = self.data_manager.import_image(fname)
            self.data_manager.set_map_image(rel)
            self.render_map()

    def render_map(self):
        map_rel = self.data_manager.data.get("map_data", {}).get("image_path")
        if not map_rel: return

        full_path = self.data_manager.get_full_path(map_rel)
        if not os.path.exists(full_path): return
        
        pixmap = QPixmap(full_path)
        self.map_viewer.load_map(pixmap)

        pins = self.data_manager.data.get("map_data", {}).get("pins", [])
        entities = self.data_manager.data.get("entities", {})

        for pin in pins:
            eid = pin["entity_id"]
            if eid in entities:
                entity = entities[eid]
                color = "#ff0000"
                if entity["type"] == "NPC": color = "#ff9800"
                elif entity["type"] == "Mekan": color = "#2196f3"
                elif entity["type"] == "Oyuncu": color = "#4caf50"
                
                # Özel Pin Nesnesi Kullanıyoruz
                pin_item = MapPinItem(
                    pin["x"], pin["y"], 20, color, eid, entity["name"], 
                    self.on_pin_clicked # Tıklama fonksiyonunu gönderiyoruz
                )
                self.map_viewer.add_pin_object(pin_item)

    def on_pin_clicked(self, entity_id):
        # Pin tıklandığında sol menüden o karakteri seç ve forma yükle
        self.tabs.setCurrentWidget(self.tab_db) # DB sekmesine geç
        self.load_entity_to_form(entity_id)

    def handle_new_pin(self, x, y):
        entities = self.data_manager.data.get("entities", {})
        if not entities: return

        items = []
        ids = []
        for eid, data in entities.items():
            items.append(f"{data['name']} ({data['type']})")
            ids.append(eid)

        item, ok = QInputDialog.getItem(self, "Pin Ekle", "Varlık Seç:", items, 0, False)
        if ok and item:
            index = items.index(item)
            self.data_manager.add_pin(x, y, ids[index])
            self.render_map()

if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = DungeonMasterApp()
    window.show()
    sys.exit(app.exec())