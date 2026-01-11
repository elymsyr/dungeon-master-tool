from PyQt6.QtWidgets import (QDialog, QVBoxLayout, QFormLayout, QSpinBox, 
                             QDialogButtonBox, QListWidget, QListWidgetItem, 
                             QLabel, QGroupBox, QHBoxLayout, QPushButton, QComboBox)
from PyQt6.QtCore import Qt
from core.locales import tr
from ui.widgets.markdown_editor import MarkdownEditor  # Markdown Editör

class TimelineEntryDialog(QDialog):
    def __init__(self, data_manager, default_day=1, default_note="", selected_ids=None, selected_session_id=None, parent=None):
        super().__init__(parent)
        self.dm = data_manager
        self.selected_session_id = selected_session_id
        
        self.setWindowTitle("Timeline Olayı Ekle/Düzenle")
        self.resize(500, 700) # İçerik arttığı için biraz büyüttük
        
        # Yeni kayıt mı düzenleme mi? (Varsayılan seçimler için)
        self.is_new_entry = (selected_ids is None or len(selected_ids) == 0)
        
        # ID listesini normalize et
        if selected_ids is None:
            self.selected_ids = []
        elif isinstance(selected_ids, (str, int)):
            self.selected_ids = [str(selected_ids)]
        else:
            self.selected_ids = [str(i) for i in selected_ids]
        
        self.init_ui(default_day, default_note)

    def init_ui(self, day, note):
        layout = QVBoxLayout(self)
        
        # --- ÜST FORM (GÜN VE OTURUM) ---
        form = QFormLayout()
        
        # 1. Gün Seçimi
        self.spin_day = QSpinBox()
        self.spin_day.setRange(1, 99999)
        self.spin_day.setValue(day)
        form.addRow("Gün (Day):", self.spin_day)
        
        # 2. Oturum Bağlantısı
        self.combo_session = QComboBox()
        self.combo_session.addItem("- İlişkili Oturum Yok -", None)
        
        sessions = self.dm.data.get("sessions", [])
        for sess in sessions:
            self.combo_session.addItem(f"📜 {sess['name']}", sess['id'])
            
        if self.selected_session_id:
            idx = self.combo_session.findData(self.selected_session_id)
            if idx >= 0: self.combo_session.setCurrentIndex(idx)
            
        form.addRow("Oturum (Link):", self.combo_session)
        layout.addLayout(form)
        
        # --- OYUNCULAR LİSTESİ ---
        grp_players = QGroupBox("Oyuncular")
        layout_players = QVBoxLayout(grp_players)
        layout_players.setContentsMargins(5, 5, 5, 5)
        
        # Başlık ve Tümünü Seç Butonu
        h_player_header = QHBoxLayout()
        h_player_header.addWidget(QLabel("Parti Üyeleri:"))
        h_player_header.addStretch()
        
        btn_all_players = QPushButton("Tümünü Seç")
        btn_all_players.setFixedSize(80, 22)
        btn_all_players.setStyleSheet("font-size: 11px; padding: 2px;")
        btn_all_players.clicked.connect(lambda: self.select_all_in_list(self.list_players, True))
        
        h_player_header.addWidget(btn_all_players)
        layout_players.addLayout(h_player_header)

        self.list_players = QListWidget()
        self.list_players.setMaximumHeight(120)
        layout_players.addWidget(self.list_players)
        layout.addWidget(grp_players)

        # --- DİĞER VARLIKLAR (NPC/MONSTER) ---
        grp_others = QGroupBox("Diğer Varlıklar")
        layout_others = QVBoxLayout(grp_others)
        layout_others.setContentsMargins(5, 5, 5, 5)

        # Başlık ve Tümünü Seç Butonu
        h_other_header = QHBoxLayout()
        h_other_header.addWidget(QLabel("NPC ve Canavarlar:"))
        h_other_header.addStretch()
        
        btn_all_others = QPushButton("Tümünü Seç")
        btn_all_others.setFixedSize(80, 22)
        btn_all_others.setStyleSheet("font-size: 11px; padding: 2px;")
        btn_all_others.clicked.connect(lambda: self.select_all_in_list(self.list_others, True))
        
        h_other_header.addWidget(btn_all_others)
        layout_others.addLayout(h_other_header)

        self.list_others = QListWidget()
        self.list_others.setMaximumHeight(150)
        layout_others.addWidget(self.list_others)
        layout.addWidget(grp_others)

        # Listeleri Doldur
        self.populate_lists()

        # 3. Not Alanı (Markdown)
        layout.addWidget(QLabel("Notlar (Markdown):"))
        self.txt_note = MarkdownEditor(text=note)
        self.txt_note.setPlaceholderText("Hikaye detayları, ipuçları, olaylar...")
        layout.addWidget(self.txt_note)
        
        # Butonlar
        buttons = QDialogButtonBox(QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel)
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)
        layout.addWidget(buttons)

    def populate_lists(self):
        """Veritabanındaki varlıkları ilgili listelere dağıtır."""
        for eid, ent in self.dm.data["entities"].items():
            etype = ent.get("type")
            
            # Sadece ilgili tipleri al
            if etype not in ["Player", "NPC", "Monster"]:
                continue

            # Öğe oluştur
            icon = "👤" if etype == "Player" else "💀" if etype == "Monster" else "😐"
            item = QListWidgetItem(f"{icon} {ent['name']}")
            item.setData(Qt.ItemDataRole.UserRole, eid)
            item.setFlags(item.flags() | Qt.ItemFlag.ItemIsUserCheckable)
            
            # Listeyi belirle ve ekle
            target_list = self.list_players if etype == "Player" else self.list_others
            target_list.addItem(item)

            # --- SEÇİM MANTIĞI ---
            should_check = False
            
            if self.is_new_entry:
                # Yeni kayıtsa: Sadece Oyuncuları varsayılan olarak seç
                if etype == "Player":
                    should_check = True
            else:
                # Düzenlemeyse: Daha önce kaydedilmiş ID'leri seç
                if eid in self.selected_ids:
                    should_check = True
            
            item.setCheckState(Qt.CheckState.Checked if should_check else Qt.CheckState.Unchecked)

    def select_all_in_list(self, list_widget, state):
        """Bir listedeki tüm öğeleri seçer."""
        check_state = Qt.CheckState.Checked if state else Qt.CheckState.Unchecked
        for i in range(list_widget.count()):
            item = list_widget.item(i)
            item.setCheckState(check_state)

    def get_data(self):
        # Her iki listeden seçili ID'leri topla
        ids = []
        
        # Oyuncular
        for i in range(self.list_players.count()):
            item = self.list_players.item(i)
            if item.checkState() == Qt.CheckState.Checked:
                ids.append(item.data(Qt.ItemDataRole.UserRole))
        
        # Diğerleri
        for i in range(self.list_others.count()):
            item = self.list_others.item(i)
            if item.checkState() == Qt.CheckState.Checked:
                ids.append(item.data(Qt.ItemDataRole.UserRole))
        
        return {
            "day": self.spin_day.value(),
            "entity_ids": ids,
            "session_id": self.combo_session.currentData(),
            "note": self.txt_note.toPlainText() # MarkdownEditor'den metni al
        }