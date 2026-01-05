from PyQt6.QtWidgets import (QWidget, QVBoxLayout, QTableWidget, QTableWidgetItem, 
                             QHBoxLayout, QPushButton, QHeaderView, QInputDialog, 
                             QMenu, QMessageBox, QFrame, QLineEdit, QFileDialog, 
                             QDialog, QListWidget, QListWidgetItem, QLabel, QAbstractItemView)
from PyQt6.QtGui import QAction, QColor, QBrush, QCursor, QIcon, QPixmap
from PyQt6.QtCore import Qt, pyqtSignal, QSize
from core.locales import tr
from ui.windows.battle_map_window import BattleMapWindow
import random
import os

# D&D 5e Standart Durumlar
CONDITIONS = [
    "Blinded", "Charmed", "Deafened", "Frightened", "Grappled", "Incapacitated", 
    "Invisible", "Paralyzed", "Petrified", "Poisoned", "Prone", "Restrained", 
    "Stunned", "Unconscious", "Exhaustion"
]

class NumericTableWidgetItem(QTableWidgetItem):
    def __lt__(self, other):
        try:
            # Hem DisplayRole hem EditRole üzerinden sayısal veri çekmeye çalış
            d1 = self.data(Qt.ItemDataRole.DisplayRole)
            d2 = other.data(Qt.ItemDataRole.DisplayRole)
            return float(d1) < float(d2)
        except (ValueError, TypeError, AttributeError):
            return super().__lt__(other)

# --- YENİ: HARİTA SEÇİM DİYALOĞU ---
class MapSelectorDialog(QDialog):
    def __init__(self, assets_path, parent=None):
        super().__init__(parent)
        self.assets_path = assets_path
        self.selected_file = None # Seçilen dosya adı (ör: map.png)
        self.is_new_import = False # Yeni yükle butonuna basıldı mı?
        
        self.setWindowTitle(tr("TITLE_MAP_SELECTOR"))
        self.setFixedSize(600, 500)
        self.setStyleSheet("background-color: #1e1e1e; color: white;")
        
        self.init_ui()
        self.load_maps()

    def init_ui(self):
        layout = QVBoxLayout(self)
        
        lbl = QLabel(tr("LBL_SAVED_MAPS"))
        lbl.setStyleSheet("font-weight: bold; font-size: 14px; color: #ffb74d;")
        layout.addWidget(lbl)
        
        # Resim Listesi (Icon Mode)
        self.list_widget = QListWidget()
        self.list_widget.setViewMode(QListWidget.ViewMode.IconMode)
        self.list_widget.setIconSize(QSize(150, 150))
        self.list_widget.setResizeMode(QListWidget.ResizeMode.Adjust)
        self.list_widget.setSpacing(10)
        self.list_widget.setStyleSheet("""
            QListWidget { background-color: #252526; border: 1px solid #444; }
            QListWidget::item { border: 1px solid transparent; padding: 5px; }
            QListWidget::item:selected { background-color: #333; border: 2px solid #007acc; border-radius: 5px; }
        """)
        self.list_widget.itemDoubleClicked.connect(self.select_existing)
        layout.addWidget(self.list_widget)
        
        # Butonlar
        btn_layout = QHBoxLayout()
        
        self.btn_import = QPushButton(tr("BTN_IMPORT_NEW_MAP"))
        self.btn_import.setStyleSheet("background-color: #2e7d32; color: white; padding: 8px; font-weight: bold;")
        self.btn_import.clicked.connect(self.select_new)
        
        self.btn_select = QPushButton(tr("BTN_OPEN_SELECTED_MAP"))
        self.btn_select.setStyleSheet("background-color: #007acc; color: white; padding: 8px; font-weight: bold;")
        self.btn_select.clicked.connect(self.select_existing)
        
        btn_layout.addWidget(self.btn_import)
        btn_layout.addStretch()
        btn_layout.addWidget(self.btn_select)
        
        layout.addLayout(btn_layout)

    def retranslate_ui(self):
        self.setWindowTitle(tr("TITLE_MAP_SELECTOR"))
        self.btn_import.setText(tr("BTN_IMPORT_NEW_MAP"))
        self.btn_select.setText(tr("BTN_OPEN_SELECTED_MAP"))

    def load_maps(self):
        if not os.path.exists(self.assets_path):
            return
            
        valid_extensions = {".png", ".jpg", ".jpeg", ".bmp"}
        
        files = [f for f in os.listdir(self.assets_path) 
                 if os.path.splitext(f)[1].lower() in valid_extensions]
        
        for f in files:
            full_path = os.path.join(self.assets_path, f)
            
            # Thumbnail oluştur
            icon = QIcon(full_path)
            item = QListWidgetItem(icon, f)
            item.setData(Qt.ItemDataRole.UserRole, f) # Dosya adını sakla
            
            self.list_widget.addItem(item)

    def select_existing(self):
        current_item = self.list_widget.currentItem()
        if current_item:
            self.selected_file = current_item.data(Qt.ItemDataRole.UserRole)
            self.accept()
        else:
            QMessageBox.warning(self, tr("MSG_WARNING"), tr("MSG_SELECT_MAP_FROM_LIST"))

    def select_new(self):
        self.is_new_import = True
        self.accept()


# --- COMBAT TRACKER ANA SINIF ---
class CombatTracker(QWidget):
    data_changed_signal = pyqtSignal()

    def __init__(self, data_manager):
        super().__init__()
        self.dm = data_manager
        self.current_turn_index = -1
        self.battle_map_window = None 
        
        # Session State Verileri
        self.current_map_path = None # Relative path (assets/...)
        self.current_token_size = 50
        self.token_positions = {} 
        self.loading = False # Yükleme sırasında sinyal göndermeyi engellemek için
        
        self.init_ui()

    def init_ui(self):
        layout = QVBoxLayout(self)
        
        # TABLO
        self.table = QTableWidget()
        self.table.setColumnCount(5)
        self.table.setHorizontalHeaderLabels([tr("HEADER_NAME"), tr("HEADER_INIT"), tr("HEADER_AC"), tr("HEADER_HP"), tr("HEADER_COND")])
        self.table.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeMode.Stretch)
        self.table.horizontalHeader().setSectionResizeMode(4, QHeaderView.ResizeMode.Stretch)
        self.table.setSelectionBehavior(QTableWidget.SelectionBehavior.SelectRows)
        self.table.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
        
        self.table.customContextMenuRequested.connect(self.open_context_menu)
        self.table.itemChanged.connect(self.on_data_changed)
        
        # Sütun başlıklarına tıklandığında sıralama özelliğini aç
        self.table.setSortingEnabled(False) # Otomatik sıralama çakışmasın diye kapalı
        layout.addWidget(self.table)

        # KONTROLLER
        quick_layout = QHBoxLayout()
        self.inp_quick_name = QLineEdit(); self.inp_quick_name.setPlaceholderText(tr("HEADER_NAME"))
        self.inp_quick_init = QLineEdit(); self.inp_quick_init.setPlaceholderText(tr("LBL_INIT")); self.inp_quick_init.setMaximumWidth(50)
        self.inp_quick_hp = QLineEdit(); self.inp_quick_hp.setPlaceholderText(tr("LBL_HP")); self.inp_quick_hp.setMaximumWidth(50)
        self.btn_quick_add = QPushButton(tr("BTN_QUICK_ADD")); self.btn_quick_add.clicked.connect(self.quick_add)
        
        quick_layout.addWidget(self.inp_quick_name, 3)
        quick_layout.addWidget(self.inp_quick_init, 1)
        quick_layout.addWidget(self.inp_quick_hp, 1)
        quick_layout.addWidget(self.btn_quick_add, 1)
        layout.addLayout(quick_layout)

        # Butonlar 1
        btn_layout = QHBoxLayout()
        self.btn_next_turn = QPushButton(tr("BTN_NEXT_TURN"))
        self.btn_next_turn.setStyleSheet("background-color: #fbc02d; color: black; font-weight: bold;")
        self.btn_next_turn.clicked.connect(self.next_turn)
        
        self.btn_battle_map = QPushButton("🗺️ Battle Map")
        self.btn_battle_map.setStyleSheet("background-color: #0277bd; color: white; font-weight: bold;")
        self.btn_battle_map.clicked.connect(self.open_battle_map)

        btn_layout.addWidget(self.btn_next_turn)
        btn_layout.addWidget(self.btn_battle_map)
        layout.addLayout(btn_layout)
        
        # Butonlar 2
        btn_layout2 = QHBoxLayout()
        self.btn_add = QPushButton(tr("BTN_ADD")); self.btn_add.clicked.connect(self.add_combatant_dialog)
        self.btn_add_players = QPushButton(tr("BTN_ADD_PLAYERS")); self.btn_add_players.clicked.connect(self.add_all_players)
        self.btn_roll = QPushButton(tr("BTN_ROLL_INIT")); self.btn_roll.clicked.connect(self.roll_initiatives)
        self.btn_clear_all = QPushButton(tr("BTN_CLEAR_ALL"))
        self.btn_clear_all.clicked.connect(self.clear_tracker)
        self.btn_clear_all.setStyleSheet("color: #ff5252;")
        
        btn_layout2.addWidget(self.btn_add)
        btn_layout2.addWidget(self.btn_add_players)
        btn_layout2.addWidget(self.btn_roll)
        btn_layout2.addWidget(self.btn_clear_all)
        layout.addLayout(btn_layout2)

    def retranslate_ui(self):
        self.table.setHorizontalHeaderLabels([tr("HEADER_NAME"), tr("HEADER_INIT"), tr("HEADER_AC"), tr("HEADER_HP"), tr("HEADER_COND")])
        self.inp_quick_name.setPlaceholderText(tr("HEADER_NAME"))
        self.inp_quick_init.setPlaceholderText(tr("LBL_INIT"))
        self.inp_quick_hp.setPlaceholderText(tr("LBL_HP"))
        self.btn_quick_add.setText(tr("BTN_QUICK_ADD"))
        self.btn_next_turn.setText(tr("BTN_NEXT_TURN"))
        self.btn_add.setText(tr("BTN_ADD"))
        self.btn_add_players.setText(tr("BTN_ADD_PLAYERS"))
        self.btn_roll.setText(tr("BTN_ROLL_INIT"))
        self.btn_clear_all.setText(tr("BTN_CLEAR_ALL"))
        
        if self.battle_map_window and self.battle_map_window.isVisible():
            self.battle_map_window.retranslate_ui()
            self.refresh_battle_map()

    # --- BATTLE MAP ENTEGRASYONU (GÜNCELLENDİ) ---
    def open_battle_map(self):
        # 1. Eğer pencere zaten açıksa öne getir
        if self.battle_map_window and self.battle_map_window.isVisible():
            self.battle_map_window.raise_()
            self.battle_map_window.activateWindow()
            return

        force_reload = False
        
        # 2. Eğer harita yolu yoksa SEÇİM EKRANINI AÇ
        if not self.current_map_path:
            # Assets klasörünü bul
            assets_path = os.path.join(self.dm.current_campaign_path, "assets")
            if not os.path.exists(assets_path):
                os.makedirs(assets_path)
            
            # Seçim diyaloğunu aç
            selector = MapSelectorDialog(assets_path, self)
            
            if selector.exec():
                if selector.is_new_import:
                    # Yeni Yükle
                    fname, _ = QFileDialog.getOpenFileName(self, tr("MSG_SELECT_MAP"), "", "Images (*.png *.jpg *.jpeg)")
                    if fname:
                        rel_path = self.dm.import_image(fname)
                        if rel_path:
                            self.current_map_path = rel_path
                            force_reload = True
                            self.data_changed_signal.emit()
                    else:
                        return # İptal ettiyse açma
                elif selector.selected_file:
                    # Mevcut Olanı Seç
                    self.current_map_path = os.path.join("assets", selector.selected_file)
                    force_reload = True
                    self.data_changed_signal.emit()
            else:
                return # Diyalog kapatıldıysa harita açma

        # 3. Pencereyi Oluştur ve Göster
        self.battle_map_window = BattleMapWindow(self.dm)
        self.battle_map_window.token_moved_signal.connect(self.on_token_moved_in_map)
        self.battle_map_window.slider_size.valueChanged.connect(self.on_token_size_changed)
        
        self.battle_map_window.show()
        
        self.refresh_battle_map(force_map_reload=force_reload)

    def on_token_moved_in_map(self, eid, x, y):
        self.token_positions[eid] = (x, y)
        self.data_changed_signal.emit() # Pozisyon değişince kaydet

    def on_token_size_changed(self, val):
        self.current_token_size = val
        self.data_changed_signal.emit() # Boyut değişince kaydet

    def refresh_battle_map(self, force_map_reload=False):
        if not self.battle_map_window: return
        
        # Pencere görünür olmasa da veriyi güncelleyelim (arkada hazır dursun)
        data = self.get_combat_data_for_map()
        
        # Harita yolu (relative -> full)
        map_full_path = None
        # Eğer force_map_reload istenmişse VEYA pencerede harita hiç yoksa gönder
        if (force_map_reload or self.battle_map_window.map_item is None) and self.current_map_path:
            map_full_path = self.dm.get_full_path(self.current_map_path)
        
        self.battle_map_window.update_combat_data(data, self.current_turn_index, map_full_path, self.current_token_size)

    def get_combat_data_for_map(self):
        data = []
        for row in range(self.table.rowCount()):
            item_name = self.table.item(row, 0)
            item_init = self.table.item(row, 1)
            item_ac = self.table.item(row, 2)
            item_hp = self.table.item(row, 3)
            
            # Tam güvenlik: Hücrelerden biri bile oluşmamışsa atla
            if not all([item_name, item_init, item_ac, item_hp]):
                continue
            
            eid = item_init.data(Qt.ItemDataRole.UserRole)
            x, y = None, None
            if eid and eid in self.token_positions:
                x, y = self.token_positions[eid]
            
            data.append({
                "name": item_name.text(),
                "hp": item_hp.text(),
                "eid": eid,
                "x": x, "y": y
            })
        return data

    def on_data_changed(self, item): 
        if self.loading: return
        if item.column() == 1: # Initiative sütunu değiştiyse
            self._sort_and_refresh()
        else:
            self.refresh_battle_map()
            self.data_changed_signal.emit()

    # --- SAVAŞ AKIŞI ---
    def next_turn(self):
        count = self.table.rowCount()
        if count == 0: return
        self.loading = True
        self.current_turn_index = (self.current_turn_index + 1) % count
        self.update_highlights()
        self.refresh_battle_map()
        self.loading = False
        self.data_changed_signal.emit()

    def update_highlights(self):
        self.table.blockSignals(True)
        for r in range(self.table.rowCount()):
            for c in range(self.table.columnCount()):
                item = self.table.item(r, c)
                if item: item.setBackground(QBrush(QColor(0,0,0,0)))
        if 0 <= self.current_turn_index < self.table.rowCount():
            for c in range(self.table.columnCount()):
                item = self.table.item(self.current_turn_index, c)
                if item: item.setBackground(QBrush(QColor(40, 80, 40)))
        self.table.blockSignals(False)

    def _sort_and_refresh(self):
        # Şu anki sıradaki kişinin EID veya ismini sakla
        current_eid = None
        if 0 <= self.current_turn_index < self.table.rowCount():
            item_init = self.table.item(self.current_turn_index, 1)
            if item_init: current_eid = item_init.data(Qt.ItemDataRole.UserRole)
            if not current_eid:
                item_name = self.table.item(self.current_turn_index, 0)
                if item_name: current_eid = item_name.text()

        self.table.blockSignals(True)
        # Sütun 1'e göre (Initiative) büyükten küçüğe sırala
        self.table.sortItems(1, Qt.SortOrder.DescendingOrder)
        self.table.blockSignals(False)

        # Sıradaki kişiyi yeni yerinde bul
        if current_eid is not None:
            for row in range(self.table.rowCount()):
                item_init = self.table.item(row, 1)
                item_name = self.table.item(row, 0)
                # Hem EID hem isim kontrolü (Hangisi eşleşirse)
                if (item_init and item_init.data(Qt.ItemDataRole.UserRole) == current_eid) or \
                   (item_name and item_name.text() == current_eid):
                    self.current_turn_index = row
                    break
        
        self.update_highlights()
        self.refresh_battle_map()
        if not self.loading:
            self.data_changed_signal.emit()

    def clear_tracker(self):
        self.table.setRowCount(0)
        self.current_turn_index = -1
        self.token_positions.clear()
        self.current_map_path = None
        self.refresh_battle_map()
        if self.battle_map_window: self.battle_map_window.set_map_image(None)
        if not self.loading:
            self.data_changed_signal.emit()

    # --- SAVE / LOAD SİSTEMİ ---
    def get_session_state(self):
        """Oturum kaydedilirken çağrılır. Tüm durumu paketler."""
        combatants = []
        for row in range(self.table.rowCount()):
            # HÜCRE GÜVENLİĞİ
            item_name = self.table.item(row, 0)
            item_init = self.table.item(row, 1)
            item_ac = self.table.item(row, 2)
            item_hp = self.table.item(row, 3)
            item_cond = self.table.item(row, 4)

            if item_name is None or item_init is None: continue

            eid = item_init.data(Qt.ItemDataRole.UserRole)
            x, y = None, None
            if eid and eid in self.token_positions: x, y = self.token_positions[eid]

            # JSON serileştirme hatası (RecursionError) olmaması için verileri ilkel tiplere (int, str) zorla
            combatants.append({
                "name": str(item_name.text()),
                "init": str(item_init.text()),
                "ac": str(item_ac.text() if item_ac else ""),
                "hp": str(item_hp.text() if item_hp else ""),
                "cond": str(item_cond.text() if item_cond else ""),
                "eid": str(eid) if eid else None,
                "bonus": int(item_name.data(Qt.ItemDataRole.UserRole) or 0),
                "x": float(x) if x is not None else None,
                "y": float(y) if y is not None else None
            })
            
        return {
            "combatants": combatants,
            "map_path": str(self.current_map_path) if self.current_map_path else None, 
            "token_size": int(self.current_token_size),
            "turn_index": int(self.current_turn_index)
        }

    def load_combat_data(self, combatants_list):
        """Eski format (sadece liste) için destek"""
        self.load_session_state({"combatants": combatants_list})

    def load_session_state(self, state_data):
        if not state_data: return
        self.loading = True
        self.table.blockSignals(True)
        self.table.setRowCount(0)
        self.token_positions.clear()
        
        combatants = state_data.get("combatants", [])
        self.current_map_path = state_data.get("map_path")
        self.current_token_size = int(state_data.get("token_size", 50))
        self.current_turn_index = int(state_data.get("turn_index", -1))
        
        for c in combatants:
            eid = c.get("eid")
            if eid and c.get("x") is not None:
                self.token_positions[eid] = (float(c["x"]), float(c["y"]))
            self.add_direct_row(
                str(c["name"]), 
                str(c["init"]), 
                str(c["ac"]), 
                str(c["hp"]), 
                str(c["cond"]), 
                str(eid) if eid else None, 
                int(c.get("bonus", 0))
            )
            
        self.table.blockSignals(False)
        self._sort_and_refresh()
        
        if self.current_map_path:
             self.open_battle_map()
             
        self.loading = False

    # --- HELPER METHODS ---
    def add_direct_row(self, name, init, ac, hp, condition, eid, init_bonus=0):
        row = self.table.rowCount()
        self.table.insertRow(row)
        
        # İsim ve Bonus verisi (UserRole 0. kolonda)
        item_name = QTableWidgetItem(name)
        item_name.setData(Qt.ItemDataRole.UserRole, init_bonus)
        self.table.setItem(row, 0, item_name)
        
        item_init = NumericTableWidgetItem(str(init))
        item_init.setData(Qt.ItemDataRole.UserRole, eid)
        self.table.setItem(row, 1, item_init)
        
        # AC ve HP (Sayısal Sıralama)
        self.table.setItem(row, 2, NumericTableWidgetItem(str(ac)))
        self.table.setItem(row, 3, NumericTableWidgetItem(str(hp)))
        
        # Durumlar
        cond_item = QTableWidgetItem(condition)
        if condition:
            cond_item.setForeground(QBrush(QColor("#ff5252")))
        self.table.setItem(row, 4, cond_item)

    def quick_add(self):
        name = self.inp_quick_name.text().strip(); 
        if not name: return
        self.add_direct_row(name, self.inp_quick_init.text() or str(random.randint(1,20)), "10", self.inp_quick_hp.text() or "10", "", None)
        self.inp_quick_name.clear(); self.inp_quick_init.clear(); self.inp_quick_hp.clear()
        self._sort_and_refresh()

    def add_combatant_dialog(self):
        entities = self.dm.data["entities"]
        items = []; ids = []
        for eid, data in entities.items():
            if data.get("type") in ["NPC", "Monster", "Player"]:
                items.append(f"{data['name']} ({data['type']})"); ids.append(eid)
        item, ok = QInputDialog.getItem(self, tr("BTN_ADD"), tr("LBL_NAME"), items, 0, False)
        if ok and item: self.add_row_from_entity(ids[items.index(item)]); self._sort_and_refresh()

    def add_row_from_entity(self, entity_id):
        data = self.dm.data["entities"].get(entity_id)
        if not data: return
        name = data.get("name", "Bilinmeyen")
        hp = data.get("combat_stats", {}).get("hp", "10")
        ac = data.get("combat_stats", {}).get("ac", "10")
        
        # Inisiyatif Bonusu Hesapla: DEX Modifier + Ek Inisiyatif Bonusu
        bonus_data = self.calculate_entity_initiative_bonus(data)
        total_bonus = bonus_data["total"]
        
        # Zar At
        die_roll = random.randint(1, 20)
        total_init = die_roll + total_bonus
        
        # Detaylı log (Hata ayıklama için terminalde kalacak)
        print(f"🎲 {name} savaşa eklendi - Log: {die_roll} (zar) + {bonus_data['dex_mod']} (DEX) + {bonus_data['extra']} (ek) = {total_init}")
        
        self.add_direct_row(name, total_init, ac, hp, "", entity_id, total_bonus)
    
    def calculate_entity_initiative_bonus(self, data):
        """Varlık verisinden toplam inisiyatif bonusunu hesaplar"""
        try:
            dex = int(data.get("stats", {}).get("DEX", 10))
            dex_mod = (dex - 10) // 2
        except:
            dex_mod = 0
            
        try:
            # Hem 'initiative' hem 'init_bonus' gibi farklı key olasılıklarına karşı esnek
            c_stats = data.get("combat_stats", {})
            extra_init = c_stats.get("initiative") or c_stats.get("init_bonus") or 0
            extra_init = int(extra_init)
        except:
            extra_init = 0
            
        return {
            "dex_mod": dex_mod,
            "extra": extra_init,
            "total": dex_mod + extra_init
        }

    def add_all_players(self):
        entities = self.dm.data["entities"]
        existing_eids = [self.table.item(row, 1).data(Qt.ItemDataRole.UserRole) for row in range(self.table.rowCount())]
        for eid, data in entities.items():
            if data.get("type") == "Player" and eid not in existing_eids: self.add_row_from_entity(eid)
        self._sort_and_refresh()

    def roll_initiatives(self):
        self.table.blockSignals(True)
        rolls = []
        for row in range(self.table.rowCount()):
            item_name = self.table.item(row, 0)
            item_init = self.table.item(row, 1)
            if not item_name or not item_init: continue
            
            name = item_name.text()
            eid = item_init.data(Qt.ItemDataRole.UserRole)
            
            # Veritabanından güncel bonusu çek (Eğer varsa)
            bonus = item_name.data(Qt.ItemDataRole.UserRole) or 0
            if eid and eid in self.dm.data["entities"]:
                ent_data = self.dm.data["entities"][eid]
                bonus_data = self.calculate_entity_initiative_bonus(ent_data)
                bonus = bonus_data["total"]
                # Tablodaki bonusu da güncelle ki bir sonraki seferde güncel kalsın
                item_name.setData(Qt.ItemDataRole.UserRole, bonus)
                log_detail = f"{bonus_data['dex_mod']} (DEX) + {bonus_data['extra']} (ek)"
            else:
                log_detail = f"{bonus} (sabit)"
            
            die_roll = random.randint(1, 20)
            total = die_roll + bonus
            
            item_init.setText(str(total))
            rolls.append(f"{name}: {die_roll} (zar) + {log_detail} = {total}")
            
        self.table.blockSignals(False)
        print("\n--- Inisiyatif Zar Atışları ---")
        for r in rolls: print(r)
        
        self._sort_and_refresh()

    def open_context_menu(self, position):
        row = self.table.rowAt(position.y()); 
        if row == -1: return
        menu = QMenu()
        cond_menu = menu.addMenu(tr("MENU_ADD_COND"))
        current_cond_text = self.table.item(row, 4).text()
        current_conditions = [c.strip() for c in current_cond_text.split(",") if c.strip()]
        for cond in CONDITIONS:
            action = QAction(cond, self); action.setCheckable(True)
            if any(cond.split(" ")[0] in c for c in current_conditions): action.setChecked(True)
            action.triggered.connect(lambda checked, c=cond, r=row: self.toggle_condition(r, c))
            cond_menu.addAction(action)
        menu.addSeparator()
        del_action = QAction(tr("MENU_REMOVE_COMBAT"), self)
        del_action.triggered.connect(lambda: self.delete_row(row))
        menu.addAction(del_action)
        menu.exec(self.table.viewport().mapToGlobal(position))
        self.refresh_battle_map()

    def toggle_condition(self, row, condition):
        item = self.table.item(row, 4)
        current_list = [c.strip() for c in item.text().split(",") if c.strip()]
        if condition in current_list: current_list.remove(condition)
        else: current_list.append(condition)
        new_text = ", ".join(current_list)
        item.setText(new_text)
        item.setForeground(QBrush(QColor("#ff5252"))) if new_text else item.setForeground(QBrush(QColor("#e0e0e0")))
        self.refresh_battle_map()
        self.data_changed_signal.emit()

    def delete_row(self, row):
        self.table.removeRow(row)
        if self.table.rowCount() > 0:
            if self.current_turn_index >= row:
                self.current_turn_index = max(0, self.current_turn_index - 1)
        else:
            self.current_turn_index = -1
        self.update_highlights()
        self.refresh_battle_map()
        self.data_changed_signal.emit()