from PyQt6.QtWidgets import (QDialog, QVBoxLayout, QHBoxLayout, QTableWidget, 
                             QTableWidgetItem, QHeaderView, QPushButton, QLineEdit, 
                             QComboBox, QLabel, QSpinBox, QAbstractItemView, QFrame)
from PyQt6.QtCore import Qt
from PyQt6.QtGui import QColor, QBrush
from core.locales import tr

class EncounterSelectionDialog(QDialog):
    def __init__(self, data_manager, parent=None):
        super().__init__(parent)
        self.dm = data_manager
        self.selected_entities = [] 
        
        self.setWindowTitle(tr("TITLE_ADD_COMBAT"))
        self.resize(800, 600)
        # Stil QSS'den gelecek, buraya yazmıyoruz.
        
        self.init_ui()
        self.load_data()

    def init_ui(self):
        layout = QVBoxLayout(self)
        
        # --- ÜST FİLTRE ALANI ---
        filter_layout = QHBoxLayout()
        
        self.inp_search = QLineEdit()
        self.inp_search.setPlaceholderText(tr("PH_SEARCH_NAME_TAG"))
        self.inp_search.textChanged.connect(self.filter_table)
        
        self.combo_type = QComboBox()
        self.combo_type.addItem(tr("LBL_TYPE_ALL"), "Tümü")
        self.combo_type.addItem(tr("CAT_NPC"), "NPC")
        self.combo_type.addItem(tr("CAT_MONSTER"), "Monster") # Data 'Monster' olduğu için value 'Monster' kalmalı
        self.combo_type.addItem(tr("CAT_PLAYER"), "Player")
        
        self.combo_type.currentTextChanged.connect(self.filter_table)
        
        filter_layout.addWidget(QLabel("🔍"))
        filter_layout.addWidget(self.inp_search, 3)
        filter_layout.addWidget(QLabel(f"{tr('LBL_TYPE')}:"))
        filter_layout.addWidget(self.combo_type, 1)
        
        layout.addLayout(filter_layout)
        
        # --- ORTA TABLO ALANI ---
        self.table = QTableWidget()
        self.table.setColumnCount(6)
        # Başlıklar
        headers = [tr("HEADER_NAME"), tr("LBL_TYPE"), tr("LBL_HP"), tr("LBL_AC"), tr("HEADER_INIT_BONUS"), "ID"]
        self.table.setHorizontalHeaderLabels(headers)
        self.table.hideColumn(5) # ID sütunu gizli
        
        # Tablo Ayarları
        self.table.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeMode.Stretch)
        self.table.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        self.table.setSelectionMode(QAbstractItemView.SelectionMode.ExtendedSelection)
        self.table.setSortingEnabled(True)
        self.table.setEditTriggers(QAbstractItemView.EditTrigger.NoEditTriggers)
        self.table.doubleClicked.connect(self.add_and_close)
        
        layout.addWidget(self.table)
        
        # --- ALT AKSİYON ALANI ---
        action_layout = QHBoxLayout()
        self.lbl_count = QLabel(tr("LBL_ADD_COUNT"))
        self.spin_count = QSpinBox()
        self.spin_count.setRange(1, 20)
        self.spin_count.setValue(1)
        self.spin_count.setFixedWidth(60)
        
        self.btn_add = QPushButton(tr("BTN_ADD_SELECTED"))
        self.btn_add.setObjectName("successBtn")
        self.btn_add.clicked.connect(self.accept_selection)
        
        action_layout.addStretch()
        action_layout.addWidget(self.lbl_count)
        action_layout.addWidget(self.spin_count)
        action_layout.addWidget(self.btn_add)
        
        layout.addLayout(action_layout)

    def _parse_int(self, value):
        """Metin içindeki ilk sayıyı alır (Örn: '45 (5d10)' -> 45)"""
        if not value: return 0
        try:
            # Boşluktan böl ve ilk kısmı al
            first_part = str(value).split(' ')[0]
            # Sadece rakamları filtrele (Örn: '14,' -> '14')
            clean_num = ''.join(filter(str.isdigit, first_part))
            return int(clean_num) if clean_num else 0
        except:
            return 0

    def load_data(self):
        self.table.setRowCount(0)
        entities = self.dm.data["entities"]
        
        # Verileri sıralama kolaylığı için önce listeye alalım (Opsiyonel ama temiz olur)
        # Ancak direkt döngü de olur.
        
        for eid, data in entities.items():
            etype = data.get("type", "NPC")
            
            # Sadece savaşçı tipleri listele
            if etype not in ["NPC", "Monster", "Canavar", "Player", "Oyuncu"]:
                continue
                
            name = data.get("name", tr("NAME_UNNAMED"))
            tags = " ".join(data.get("tags", [])).lower()
            
            # Statları Çek ve Temizle
            c_stats = data.get("combat_stats", {})
            
            raw_hp = c_stats.get("hp", "10")
            raw_ac = c_stats.get("ac", "10")
            
            # Temizlenmiş (Sayısal) Değerler (Sıralama için kullanılabilir)
            hp_val = self._parse_int(raw_hp)
            ac_val = self._parse_int(raw_ac)
            
            # İnisiyatif Bonusu Hesapla
            stats = data.get("stats", {})
            dex = int(stats.get("DEX", 10))
            dex_mod = (dex - 10) // 2
            
            extra_init = self._parse_int(c_stats.get("initiative") or c_stats.get("init_bonus") or 0)
            total_init_bonus = dex_mod + extra_init
            
            sign = "+" if total_init_bonus >= 0 else ""
            init_str = f"{sign}{total_init_bonus}"
            
            # Tabloya Ekle
            row = self.table.rowCount()
            self.table.insertRow(row)
            
            # 0: İsim
            item_name = QTableWidgetItem(name)
            # Arama için gizli veri (İsim + Tag + Tip)
            search_data = f"{name.lower()} {tags} {etype.lower()}"
            item_name.setData(Qt.ItemDataRole.UserRole, search_data)
            self.table.setItem(row, 0, item_name)
            
            # 1: Tip
            self.table.setItem(row, 1, QTableWidgetItem(etype))
            
            # 2: HP (Sayısal sıralama için setData kullanıyoruz)
            item_hp = QTableWidgetItem(str(hp_val))
            item_hp.setData(Qt.ItemDataRole.DisplayRole, hp_val) # Sayısal sıralama
            item_hp.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
            self.table.setItem(row, 2, item_hp)
            
            # 3: AC
            item_ac = QTableWidgetItem(str(ac_val))
            item_ac.setData(Qt.ItemDataRole.DisplayRole, ac_val)
            item_ac.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
            self.table.setItem(row, 3, item_ac)
            
            # 4: Init Bonus
            item_init = QTableWidgetItem(init_str)
            item_init.setData(Qt.ItemDataRole.DisplayRole, total_init_bonus)
            item_init.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
            if total_init_bonus > 0:
                item_init.setForeground(QBrush(QColor("#4caf50"))) # Yeşil
            elif total_init_bonus < 0:
                item_init.setForeground(QBrush(QColor("#ef5350"))) # Kırmızı
            self.table.setItem(row, 4, item_init)
            
            # 5: ID (Gizli)
            self.table.setItem(row, 5, QTableWidgetItem(eid))

    def filter_table(self):
        search_text = self.inp_search.text().lower()
        # Combo data (Tümü, NPC, Monster, Player)
        filter_type = self.combo_type.currentData() 
        
        # Tip eşleştirme haritası (Data'daki tip ile filtre arasındaki ilişki)
        mapping = {
            "NPC": ["NPC"], 
            "Monster": ["Monster", "Canavar"], 
            "Player": ["Player", "Oyuncu"]
        }
        allowed_types = mapping.get(filter_type, [])
        
        for row in range(self.table.rowCount()):
            # Gizli arama verisi (isim + tagler)
            row_search_data = self.table.item(row, 0).data(Qt.ItemDataRole.UserRole)
            row_type_text = self.table.item(row, 1).text()
            
            match_text = search_text in row_search_data
            match_type = (filter_type == "Tümü") or (row_type_text in allowed_types)
            
            self.table.setRowHidden(row, not (match_text and match_type))

    def accept_selection(self):
        selected_rows = self.table.selectionModel().selectedRows()
        if not selected_rows: return
            
        count = self.spin_count.value()
        for index in selected_rows:
            row = index.row()
            eid = self.table.item(row, 5).text()
            for _ in range(count):
                self.selected_entities.append(eid)
        self.accept()

    def add_and_close(self):
        row = self.table.currentRow()
        if row >= 0:
            eid = self.table.item(row, 5).text()
            self.selected_entities.append(eid)
            self.accept()