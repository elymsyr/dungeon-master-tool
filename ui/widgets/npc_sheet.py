import logging
import os

from PyQt6.QtCore import QSize, Qt, QUrl, pyqtSignal
from PyQt6.QtGui import QDesktopServices, QIcon, QKeySequence, QPixmap, QShortcut
from PyQt6.QtWidgets import (
    QApplication,
    QComboBox,
    QFormLayout,
    QFrame,
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QListWidget,
    QListWidgetItem,
    QMessageBox,
    QPushButton,
    QScrollArea,
    QStyle,
    QTabWidget,
    QTextEdit,
    QVBoxLayout,
    QWidget,
)

from core.locales import tr
from core.models import ENTITY_SCHEMAS
from core.theme_manager import ThemeManager
from ui.widgets.image_gallery import ImageGalleryWidget
from ui.widgets.linked_entity_widget import LinkedEntityWidget
from ui.widgets.markdown_editor import MarkdownEditor
from ui.widgets.pdf_manager import PdfManagerWidget

logger = logging.getLogger(__name__)


class NpcSheet(QWidget):
    """Entity detail sheet — slim orchestrator delegating to sub-widgets.

    Signals:
        request_open_entity(str): Emitted when the user wants to navigate to a
            linked entity. Carries the entity ID.
        data_changed(): Emitted once the first time the sheet is modified
            (dirty flag transition False → True).
        save_requested(): Emitted when the user presses Ctrl+S or the Save
            button.
    """

    # --- SIGNALS ---
    request_open_entity = pyqtSignal(str)
    data_changed = pyqtSignal()
    save_requested = pyqtSignal()

    def __init__(self, data_manager):
        super().__init__()
        self.dm = data_manager
        self.dynamic_inputs = {}

        # Sub-widget data lists (battlemap stays on NpcSheet; others delegate)
        self.battlemap_list: list[str] = []

        self.is_dirty = False
        self.is_embedded = False
        self.current_palette = ThemeManager.get_palette(self.dm.current_theme)

        # Create sub-widgets before init_ui so they can be embedded
        self.image_gallery = ImageGalleryWidget(self.dm)
        self.pdf_manager = PdfManagerWidget(self.dm)
        self.spell_widget = LinkedEntityWidget(
            data_manager=self.dm,
            entity_type="Spell",
            group_title=tr("GRP_SPELLS"),
            search_placeholder=tr("PH_SEARCH_SPELL"),
            open_entity_callback=self.request_open_entity.emit,
        )
        self.item_widget = LinkedEntityWidget(
            data_manager=self.dm,
            entity_type="Equipment",
            group_title=tr("LBL_DB_ITEMS"),
            search_placeholder=tr("PH_SEARCH_ITEM"),
            open_entity_callback=self.request_open_entity.emit,
        )

        self.init_ui()

        # Backward-compat aliases (set after init_ui creates the sub-widget UIs)
        self.list_pdfs = self.pdf_manager.list_pdfs
        self.list_assigned_spells = self.spell_widget.list_assigned
        self.list_assigned_items = self.item_widget.list_assigned
        self.combo_all_spells = self.spell_widget.combo_all
        self.combo_all_items = self.item_widget.combo_all
        self.lbl_image = self.image_gallery.lbl_image
        self.lbl_img_counter = self.image_gallery.lbl_counter

        # Ctrl+S shortcut
        self.shortcut_save = QShortcut(QKeySequence("Ctrl+S"), self)
        self.shortcut_save.activated.connect(self.emit_save_request)

    # ------------------------------------------------------------------
    # Backward-compat properties — image gallery
    # ------------------------------------------------------------------

    @property
    def image_list(self) -> list[str]:
        return self.image_gallery.image_list

    @image_list.setter
    def image_list(self, value: list[str]) -> None:
        self.image_gallery.image_list = value

    @property
    def current_img_index(self) -> int:
        return self.image_gallery.current_img_index

    @current_img_index.setter
    def current_img_index(self, value: int) -> None:
        self.image_gallery.current_img_index = value

    # ------------------------------------------------------------------
    # Backward-compat properties — linked entities
    # ------------------------------------------------------------------

    @property
    def linked_spell_ids(self) -> list[str]:
        return self.spell_widget._linked_ids

    @linked_spell_ids.setter
    def linked_spell_ids(self, value: list[str]) -> None:
        self.spell_widget._linked_ids = list(value)

    @property
    def linked_item_ids(self) -> list[str]:
        return self.item_widget._linked_ids

    @linked_item_ids.setter
    def linked_item_ids(self, value: list[str]) -> None:
        self.item_widget._linked_ids = list(value)

    # ------------------------------------------------------------------
    # Embedded-mode & theming
    # ------------------------------------------------------------------

    def set_embedded_mode(self, enabled: bool) -> None:
        self.is_embedded = enabled
        self.btn_save.setVisible(not enabled)
        self.btn_delete.setVisible(not enabled)
        if enabled:
            self.inp_desc.set_transparent_mode(True)
            self.inp_dm_notes.set_transparent_mode(True)

    def refresh_theme(self, palette) -> None:
        """Update the theme for all sub-components (including Markdown editors)."""
        self.current_palette = palette
        self.inp_desc.refresh_theme(palette)
        self.inp_dm_notes.refresh_theme(palette)

        for container in [
            self.trait_container,
            self.action_container,
            self.reaction_container,
            self.legendary_container,
            self.inventory_container,
            self.custom_spell_container,
        ]:
            for i in range(container.dynamic_area.count()):
                widget = container.dynamic_area.itemAt(i).widget()
                if widget and hasattr(widget, "inp_desc"):
                    widget.inp_desc.refresh_theme(palette)

        border_col = palette.get("dm_note_border", "#d32f2f")
        title_col = palette.get("dm_note_title", "#e57373")
        self.grp_dm_notes.setStyleSheet(
            f"QGroupBox {{ border: 1px solid {border_col}; "
            f"color: {title_col}; font-weight: bold; }}"
        )

    # ------------------------------------------------------------------
    # UI construction
    # ------------------------------------------------------------------

    def init_ui(self) -> None:
        main_layout = QVBoxLayout(self)
        main_layout.setContentsMargins(0, 0, 0, 0)

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame)
        scroll.setObjectName("mainScroll")

        self.content_widget = QWidget()
        self.content_widget.setObjectName("sheetContainer")
        self.content_widget.setAttribute(Qt.WidgetAttribute.WA_StyledBackground, True)
        self.content_widget.setStyleSheet(
            "QLineEdit, QPlainTextEdit { background-color: transparent; }"
        )

        self.content_layout = QVBoxLayout(self.content_widget)

        # --- TOP SECTION (Image Gallery + Metadata) ---
        top_layout = QHBoxLayout()
        top_layout.addWidget(self.image_gallery)

        info_layout = QFormLayout()
        self.inp_name = QLineEdit()
        self.inp_type = QComboBox()
        for cat in ENTITY_SCHEMAS.keys():
            self.inp_type.addItem(
                tr(
                    f"CAT_{cat.upper().replace(' ', '_').replace('(', '').replace(')', '')}"
                ),
                cat,
            )
        self.inp_type.currentIndexChanged.connect(self._on_type_index_changed)

        self.inp_source = QLineEdit()
        self.inp_source.setPlaceholderText(tr("LBL_SOURCE_PH"))
        self.inp_source.setReadOnly(True)

        self.inp_tags = QLineEdit()
        self.inp_tags.setPlaceholderText(tr("LBL_TAGS_PH"))

        self.combo_location = QComboBox()
        self.combo_location.setEditable(True)
        self.combo_location.setPlaceholderText(tr("PH_LOCATION_SELECT"))
        self.lbl_location = QLabel(tr("LBL_LOCATION"))
        self.list_residents = QListWidget()
        self.list_residents.setMaximumHeight(80)
        self.list_residents.itemDoubleClicked.connect(self._on_linked_item_dbl_click)
        self.lbl_residents = QLabel(tr("LBL_RESIDENTS"))

        info_layout.addRow(tr("LBL_NAME"), self.inp_name)
        info_layout.addRow(tr("LBL_TYPE"), self.inp_type)
        info_layout.addRow(tr("LBL_SOURCE"), self.inp_source)
        info_layout.addRow(tr("LBL_TAGS"), self.inp_tags)
        info_layout.addRow(self.lbl_location, self.combo_location)
        info_layout.addRow(self.lbl_residents, self.list_residents)

        top_layout.addLayout(info_layout, 1)
        self.content_layout.addLayout(top_layout)

        # --- DESCRIPTION ---
        self.content_layout.addWidget(QLabel(f"<b>{tr('LBL_DESC')}</b>"))
        self.inp_desc = MarkdownEditor()
        self.inp_desc.set_data_manager(self.dm)
        self.inp_desc.entity_link_clicked.connect(self.request_open_entity.emit)
        self.inp_desc.setMinimumHeight(180)
        self.inp_desc.setPlaceholderText(tr("LBL_DESC"))
        self.content_layout.addWidget(self.inp_desc)

        # Dynamic attributes
        self.grp_dynamic = QGroupBox(tr("LBL_PROPERTIES"))
        self.layout_dynamic = QFormLayout(self.grp_dynamic)
        self.content_layout.addWidget(self.grp_dynamic)

        # Tabs
        self.tabs = QTabWidget()
        self.tab_stats = QWidget()
        self.setup_stats_tab()
        self.tabs.addTab(self.tab_stats, tr("TAB_STATS"))

        self.tab_spells = QWidget()
        self.setup_spells_tab()
        self.tabs.addTab(self.tab_spells, tr("TAB_SPELLS"))

        self.tab_features = QWidget()
        self.setup_features_tab()
        self.tabs.addTab(self.tab_features, tr("TAB_ACTIONS"))

        self.tab_inventory = QWidget()
        self.setup_inventory_tab()
        self.tabs.addTab(self.tab_inventory, tr("TAB_INV"))

        self.tab_docs = QWidget()
        self.setup_docs_tab()
        self.tabs.addTab(self.tab_docs, tr("TAB_DOCS"))

        self.tab_battlemaps = QWidget()
        self.setup_battlemap_tab()
        self.tabs.addTab(self.tab_battlemaps, tr("TAB_BATTLEMAPS"))

        self.content_layout.addWidget(self.tabs)

        # DM Notes
        self.grp_dm_notes = QGroupBox(
            f"{tr('LBL_ICON_EDIT')} {tr('LBL_NOTES')} {tr('LBL_PRIVATE')}"
        )
        self.grp_dm_notes.setStyleSheet(
            f"QGroupBox {{ border: 1px solid "
            f"{self.current_palette.get('dm_note_border', '#d32f2f')}; "
            f"color: {self.current_palette.get('dm_note_title', '#e57373')}; "
            f"font-weight: bold; }}"
        )
        dm_notes_layout = QVBoxLayout(self.grp_dm_notes)
        self.inp_dm_notes = MarkdownEditor()
        self.inp_dm_notes.set_data_manager(self.dm)
        self.inp_dm_notes.entity_link_clicked.connect(self.request_open_entity.emit)
        self.inp_dm_notes.setPlaceholderText(tr("PH_DM_NOTES"))
        self.inp_dm_notes.setMinimumHeight(120)
        dm_notes_layout.addWidget(self.inp_dm_notes)
        self.content_layout.addWidget(self.grp_dm_notes)

        scroll.setWidget(self.content_widget)
        main_layout.addWidget(scroll)

        # Footer buttons
        btn_layout = QHBoxLayout()
        btn_layout.setContentsMargins(10, 10, 10, 10)
        self.btn_delete = QPushButton(tr("BTN_DELETE"))
        self.btn_delete.setObjectName("dangerBtn")
        self.btn_save = QPushButton(tr("BTN_SAVE"))
        self.btn_save.setObjectName("primaryBtn")
        self.btn_save.clicked.connect(self.emit_save_request)

        btn_layout.addStretch()
        btn_layout.addWidget(self.btn_delete)
        btn_layout.addWidget(self.btn_save)
        main_layout.addLayout(btn_layout)

        self.update_ui_by_type(self.inp_type.currentData())
        self._connect_change_signals()

    # ------------------------------------------------------------------
    # Feature card helper
    # ------------------------------------------------------------------

    def add_feature_card(self, group, name="", desc="", ph_title=None, ph_desc=None):
        self.mark_as_dirty()
        if ph_title is None:
            ph_title = tr("LBL_TITLE_PH")
        if ph_desc is None:
            ph_desc = tr("LBL_DETAILS_PH")

        card = QFrame()
        card.setProperty("class", "featureCard")
        l = QVBoxLayout(card)

        h_header = QHBoxLayout()
        t = QLineEdit(name)
        t.setPlaceholderText(ph_title)
        t.setStyleSheet("font-weight: bold; border:none; font-size: 14px;")
        t.textChanged.connect(self.mark_as_dirty)

        btn_del = QPushButton()
        btn_del.setFixedSize(24, 24)
        btn_del.setIcon(
            self.style().standardIcon(QStyle.StandardPixmap.SP_TitleBarCloseButton)
        )
        btn_del.setStyleSheet("background: transparent; border: none;")
        btn_del.clicked.connect(
            lambda: [
                group.dynamic_area.removeWidget(card),
                card.deleteLater(),
                self.mark_as_dirty(),
            ]
        )

        h_header.addWidget(t)
        h_header.addWidget(btn_del)
        l.addLayout(h_header)

        d = MarkdownEditor(text=desc)
        d.set_data_manager(self.dm)
        d.entity_link_clicked.connect(self.request_open_entity.emit)
        d.setPlaceholderText(ph_desc)
        d.setMinimumHeight(120)
        d.textChanged.connect(self.mark_as_dirty)

        if self.is_embedded:
            d.set_transparent_mode(True)

        l.addWidget(d)
        group.dynamic_area.addWidget(card)
        card.inp_title = t
        card.inp_desc = d

    # ------------------------------------------------------------------
    # Data binding
    # ------------------------------------------------------------------

    def populate_sheet(self, data: dict) -> None:
        def safe_str(val):
            if val is None:
                return ""
            if isinstance(val, dict):
                return ", ".join(f"{k}: {v}" for k, v in val.items())
            if isinstance(val, list):
                return ", ".join(str(x) for x in val)
            return str(val)

        self.refresh_reference_combos()
        self.inp_name.setText(safe_str(data.get("name", "")))
        self.inp_source.setText(safe_str(data.get("source", "")))
        curr_type = data.get("type", "NPC")
        idx = self.inp_type.findData(curr_type)
        self.inp_type.setCurrentIndex(idx if idx >= 0 else 0)
        tags = data.get("tags", [])
        self.inp_tags.setText(
            ", ".join(tags) if isinstance(tags, list) else safe_str(tags)
        )
        self.inp_desc.setText(safe_str(data.get("description", "")))
        self.inp_dm_notes.setText(safe_str(data.get("dm_notes", "")))

        loc_val = data.get("location_id") or data.get("attributes", {}).get(
            "LBL_ATTR_LOCATION"
        )
        if loc_val:
            idx = self.combo_location.findData(loc_val)
            if idx >= 0:
                self.combo_location.setCurrentIndex(idx)
            else:
                self.combo_location.setCurrentText(str(loc_val))
        else:
            self.combo_location.setCurrentIndex(0)

        stats = data.get("stats", {})
        for k, v in self.stats_inputs.items():
            v.setText(str(stats.get(k, 10)))
            self._update_modifier(k, v.text())

        c = data.get("combat_stats", {})
        self.inp_hp.setText(safe_str(c.get("hp", "")))
        self.inp_max_hp.setText(safe_str(c.get("max_hp", "")))
        self.inp_ac.setText(safe_str(c.get("ac", "")))
        self.inp_speed.setText(safe_str(c.get("speed", "")))
        self.inp_init.setText(safe_str(c.get("initiative", "")))

        self.inp_saves.setText(safe_str(data.get("saving_throws", "")))
        self.inp_skills.setText(safe_str(data.get("skills", "")))
        self.inp_vuln.setText(safe_str(data.get("damage_vulnerabilities", "")))
        self.inp_resist.setText(safe_str(data.get("damage_resistances", "")))
        self.inp_dmg_immune.setText(safe_str(data.get("damage_immunities", "")))
        self.inp_cond_immune.setText(safe_str(data.get("condition_immunities", "")))
        self.inp_prof.setText(safe_str(data.get("proficiency_bonus", "")))
        self.inp_pp.setText(safe_str(data.get("passive_perception", "")))

        self.update_ui_by_type(curr_type)
        attrs = data.get("attributes", {})
        for label_key, widget in self.dynamic_inputs.items():
            val = attrs.get(label_key, "")
            if isinstance(widget, QComboBox):
                ix = widget.findData(val)
                if ix >= 0:
                    widget.setCurrentIndex(ix)
                else:
                    widget.setCurrentText(safe_str(val))
            else:
                widget.setText(safe_str(val))

        self.clear_all_cards()
        for k, container in [
            ("traits", self.trait_container),
            ("actions", self.action_container),
            ("reactions", self.reaction_container),
            ("legendary_actions", self.legendary_container),
            ("custom_spells", self.custom_spell_container),
            ("inventory", self.inventory_container),
        ]:
            for item in data.get(k) or []:
                self.add_feature_card(
                    container,
                    safe_str(item.get("name")),
                    safe_str(item.get("desc")),
                )

        # Delegate to sub-widgets
        self.spell_widget.set_linked_ids(data.get("spells", []))
        self.item_widget.set_linked_ids(data.get("equipment_ids", []))

        images = data.get("images", [])
        if not images and data.get("image_path"):
            images = [data.get("image_path")]
        self.image_gallery.set_images(images)

        self.battlemap_list = data.get("battlemaps", [])
        self._render_battlemap_list()

        remote_url = data.get("_remote_image_url")
        if not images and remote_url:
            self.image_gallery.start_lazy_download(
                remote_url, data.get("name", "entity")
            )

        self.pdf_manager.set_pdfs(data.get("pdfs", []))
        self.is_dirty = False

    def collect_data_from_sheet(self) -> dict | None:
        if not self.inp_name.text():
            return None

        def get_cards(container):
            res = []
            for i in range(container.dynamic_area.count()):
                w = container.dynamic_area.itemAt(i).widget()
                if w:
                    res.append({"name": w.inp_title.text(), "desc": w.inp_desc.toPlainText()})
            return res

        loc_id = self.combo_location.currentData()
        loc_text = self.combo_location.currentText()
        final_loc = (
            loc_id if (loc_id and self.combo_location.currentIndex() > 0) else loc_text.strip()
        )

        return {
            "name": self.inp_name.text(),
            "type": self.inp_type.currentText(),
            "source": self.inp_source.text(),
            "tags": [t.strip() for t in self.inp_tags.text().split(",") if t.strip()],
            "description": self.inp_desc.toPlainText(),
            "dm_notes": self.inp_dm_notes.toPlainText(),
            "images": self.image_gallery.get_images(),
            "battlemaps": self.battlemap_list,
            "location_id": final_loc,
            "stats": {k: int(v.text() or 10) for k, v in self.stats_inputs.items()},
            "combat_stats": {
                "hp": self.inp_hp.text(),
                "max_hp": self.inp_max_hp.text(),
                "ac": self.inp_ac.text(),
                "speed": self.inp_speed.text(),
                "initiative": self.inp_init.text(),
            },
            "saving_throws": self.inp_saves.text(),
            "skills": self.inp_skills.text(),
            "damage_vulnerabilities": self.inp_vuln.text(),
            "damage_resistances": self.inp_resist.text(),
            "damage_immunities": self.inp_dmg_immune.text(),
            "condition_immunities": self.inp_cond_immune.text(),
            "proficiency_bonus": self.inp_prof.text(),
            "passive_perception": self.inp_pp.text(),
            "attributes": {
                l: (w.currentText() if isinstance(w, QComboBox) else w.text())
                for l, w in self.dynamic_inputs.items()
            },
            "traits": get_cards(self.trait_container),
            "actions": get_cards(self.action_container),
            "reactions": get_cards(self.reaction_container),
            "legendary_actions": get_cards(self.legendary_container),
            "inventory": get_cards(self.inventory_container),
            "custom_spells": get_cards(self.custom_spell_container),
            "spells": self.spell_widget.get_linked_ids(),
            "equipment_ids": self.item_widget.get_linked_ids(),
            "pdfs": self.pdf_manager.get_pdfs(),
        }

    def _connect_change_signals(self) -> None:
        inputs = [
            self.inp_name, self.inp_tags, self.inp_hp, self.inp_max_hp,
            self.inp_ac, self.inp_speed, self.inp_prof, self.inp_pp, self.inp_init,
            self.inp_saves, self.inp_skills, self.inp_vuln, self.inp_resist,
            self.inp_dmg_immune, self.inp_cond_immune,
        ]
        inputs.extend(self.stats_inputs.values())
        for w in inputs:
            if isinstance(w, QLineEdit):
                w.textChanged.connect(self.mark_as_dirty)
            elif isinstance(w, QTextEdit):
                w.textChanged.connect(self.mark_as_dirty)

        self.inp_desc.textChanged.connect(self.mark_as_dirty)
        self.inp_dm_notes.textChanged.connect(self.mark_as_dirty)
        self.inp_type.currentIndexChanged.connect(self.mark_as_dirty)
        self.combo_location.editTextChanged.connect(self.mark_as_dirty)
        self.combo_location.currentIndexChanged.connect(self.mark_as_dirty)

        # Mark dirty when sub-widgets are modified
        self.image_gallery.btn_add.clicked.connect(self.mark_as_dirty)
        self.image_gallery.btn_remove.clicked.connect(self.mark_as_dirty)
        self.spell_widget.btn_add.clicked.connect(self.mark_as_dirty)
        self.spell_widget.btn_remove.clicked.connect(self.mark_as_dirty)
        self.item_widget.btn_add.clicked.connect(self.mark_as_dirty)
        self.item_widget.btn_remove.clicked.connect(self.mark_as_dirty)

    def mark_as_dirty(self) -> None:
        if not self.is_dirty:
            self.is_dirty = True
            self.data_changed.emit()

    def emit_save_request(self) -> None:
        self.save_requested.emit()

    # ------------------------------------------------------------------
    # Reference combo population
    # ------------------------------------------------------------------

    def refresh_reference_combos(self) -> None:
        self.combo_location.clear()
        for eid, ent in self.dm.data["entities"].items():
            etype = ent.get("type")
            name = ent.get("name", tr("NAME_UNNAMED"))
            if etype == "Location":
                self.combo_location.addItem(f"{tr('LBL_ICON_PIN')} {name}", eid)

        self.spell_widget.populate_available()
        self.item_widget.populate_available()

    # ------------------------------------------------------------------
    # Stats tab
    # ------------------------------------------------------------------

    def setup_stats_tab(self) -> None:
        layout = QVBoxLayout(self.tab_stats)
        self.grp_base_stats = QGroupBox(tr("GRP_STATS"))
        l = QHBoxLayout(self.grp_base_stats)
        self.stats_inputs = {}
        self.stats_modifiers = {}
        for s in ["STR", "DEX", "CON", "INT", "WIS", "CHA"]:
            v = QVBoxLayout()
            lbl_title = QLabel(s)
            lbl_title.setAlignment(Qt.AlignmentFlag.AlignCenter)
            lbl_title.setStyleSheet("font-weight: bold;")
            inp = QLineEdit("10")
            inp.setAlignment(Qt.AlignmentFlag.AlignCenter)
            inp.setMaximumWidth(50)
            inp.textChanged.connect(lambda text, key=s: self._update_modifier(key, text))
            lbl_mod = QLabel("+0")
            lbl_mod.setAlignment(Qt.AlignmentFlag.AlignCenter)
            lbl_mod.setProperty("class", "statModifier")
            self.stats_inputs[s] = inp
            self.stats_modifiers[s] = lbl_mod
            v.addWidget(lbl_title)
            v.addWidget(inp)
            v.addWidget(lbl_mod)
            l.addLayout(v)
        layout.addWidget(self.grp_base_stats)

        self.grp_combat_stats = QGroupBox(tr("GRP_COMBAT"))
        v_comb = QVBoxLayout(self.grp_combat_stats)
        self.inp_hp = QLineEdit()
        self.inp_hp.setPlaceholderText(tr("LBL_HP"))
        self.inp_max_hp = QLineEdit()
        self.inp_max_hp.setPlaceholderText(tr("LBL_MAX_HP"))
        self.inp_ac = QLineEdit()
        self.inp_ac.setPlaceholderText(tr("HEADER_AC"))
        self.inp_speed = QLineEdit()
        self.inp_prof = QLineEdit()
        self.inp_pp = QLineEdit()
        self.inp_init = QLineEdit()
        self.inp_init.setPlaceholderText(tr("LBL_INIT"))
        r1 = QHBoxLayout()
        for t, w in [
            (tr("LBL_MAX_HP"), self.inp_max_hp),
            (tr("LBL_HP"), self.inp_hp),
            (tr("HEADER_AC"), self.inp_ac),
            (tr("LBL_SPEED"), self.inp_speed),
        ]:
            v = QVBoxLayout()
            v.addWidget(QLabel(t))
            v.addWidget(w)
            r1.addLayout(v)
        r2 = QHBoxLayout()
        for t, w in [
            (tr("LBL_PROF_BONUS"), self.inp_prof),
            (tr("LBL_PASSIVE_PERC"), self.inp_pp),
            (tr("LBL_INIT_BONUS"), self.inp_init),
        ]:
            v = QVBoxLayout()
            v.addWidget(QLabel(t))
            v.addWidget(w)
            r2.addLayout(v)
        v_comb.addLayout(r1)
        v_comb.addLayout(r2)
        layout.addWidget(self.grp_combat_stats)

        self.grp_defense = QGroupBox(tr("GRP_DEFENSE"))
        form3 = QFormLayout(self.grp_defense)
        self.inp_saves = QLineEdit()
        self.inp_skills = QLineEdit()
        self.inp_vuln = QLineEdit()
        self.inp_resist = QLineEdit()
        self.inp_dmg_immune = QLineEdit()
        self.inp_cond_immune = QLineEdit()
        form3.addRow(tr("LBL_SAVES"), self.inp_saves)
        form3.addRow(tr("LBL_SKILLS"), self.inp_skills)
        form3.addRow(tr("LBL_VULN"), self.inp_vuln)
        form3.addRow(tr("LBL_RESIST"), self.inp_resist)
        form3.addRow(tr("LBL_DMG_IMMUNE"), self.inp_dmg_immune)
        form3.addRow(tr("LBL_COND_IMMUNE"), self.inp_cond_immune)
        layout.addWidget(self.grp_defense)
        layout.addStretch()

    def _update_modifier(self, stat_key: str, text_value: str) -> None:
        try:
            val = int(text_value)
            mod = (val - 10) // 2
            sign = "+" if mod >= 0 else ""
            self.stats_modifiers[stat_key].setText(f"{sign}{mod}")
            if mod > 0:
                self.stats_modifiers[stat_key].setStyleSheet(
                    f"color: {self.current_palette.get('hp_bar_full', '#4caf50')}; font-weight: bold;"
                )
            else:
                self.stats_modifiers[stat_key].setStyleSheet(
                    f"color: {self.current_palette.get('html_dim', '#aaa')}; font-weight: normal;"
                )
        except ValueError:
            self.stats_modifiers[stat_key].setText("-")

    # ------------------------------------------------------------------
    # Spells tab — delegates to spell_widget
    # ------------------------------------------------------------------

    def setup_spells_tab(self) -> None:
        layout = QVBoxLayout(self.tab_spells)
        layout.addWidget(self.spell_widget)
        self.custom_spell_container = self._create_section(tr("LBL_MANUAL_SPELLS"))
        self.add_btn_to_section(self.custom_spell_container, tr("BTN_ADD"))
        layout.addWidget(self.custom_spell_container)
        layout.addStretch()

    # ------------------------------------------------------------------
    # Inventory tab — delegates to item_widget
    # ------------------------------------------------------------------

    def setup_inventory_tab(self) -> None:
        layout = QVBoxLayout(self.tab_inventory)
        layout.addWidget(self.item_widget)
        self.inventory_container = self._create_section(tr("GRP_INVENTORY"))
        self.add_btn_to_section(self.inventory_container, tr("BTN_ADD"))
        layout.addWidget(self.inventory_container)
        layout.addStretch()

    # ------------------------------------------------------------------
    # Features tab
    # ------------------------------------------------------------------

    def setup_features_tab(self) -> None:
        layout = QVBoxLayout(self.tab_features)
        self.trait_container = self._create_section(tr("LBL_TRAITS"))
        self.add_btn_to_section(self.trait_container, tr("BTN_ADD"))
        self.action_container = self._create_section(tr("LBL_ACTIONS"))
        self.add_btn_to_section(self.action_container, tr("BTN_ADD"))
        self.reaction_container = self._create_section(tr("LBL_REACTIONS"))
        self.add_btn_to_section(self.reaction_container, tr("BTN_ADD"))
        self.legendary_container = self._create_section(tr("LBL_LEGENDARY_ACTIONS"))
        self.add_btn_to_section(self.legendary_container, tr("BTN_ADD"))
        layout.addWidget(self.trait_container)
        layout.addWidget(self.action_container)
        layout.addWidget(self.reaction_container)
        layout.addWidget(self.legendary_container)
        layout.addStretch()

    # ------------------------------------------------------------------
    # Docs tab — delegates to pdf_manager
    # ------------------------------------------------------------------

    def setup_docs_tab(self) -> None:
        layout = QVBoxLayout(self.tab_docs)
        layout.addWidget(self.pdf_manager)
        layout.addStretch()

    # ------------------------------------------------------------------
    # Battlemaps tab (stays on NpcSheet — specific to entity detail)
    # ------------------------------------------------------------------

    def setup_battlemap_tab(self) -> None:
        layout = QVBoxLayout(self.tab_battlemaps)

        lbl_info = QLabel(tr("LBL_BATTLEMAP_HELP"))
        lbl_info.setStyleSheet(
            f"color: {self.current_palette.get('html_dim', '#888')}; font-style: italic;"
        )
        layout.addWidget(lbl_info)

        h_btn = QHBoxLayout()
        self.btn_add_map = QPushButton(tr("BTN_ADD_MEDIA"))
        self.btn_add_map.clicked.connect(self.add_battlemap_dialog)

        self.btn_remove_map = QPushButton(tr("BTN_REMOVE"))
        self.btn_remove_map.clicked.connect(self.remove_selected_battlemap)

        h_btn.addWidget(self.btn_add_map)
        h_btn.addWidget(self.btn_remove_map)
        h_btn.addStretch()
        layout.addLayout(h_btn)

        self.list_battlemaps = QListWidget()
        self.list_battlemaps.setViewMode(QListWidget.ViewMode.IconMode)
        self.list_battlemaps.setIconSize(QSize(120, 120))
        self.list_battlemaps.setResizeMode(QListWidget.ResizeMode.Adjust)
        self.list_battlemaps.setSpacing(10)
        layout.addWidget(self.list_battlemaps)

    def add_battlemap_dialog(self) -> None:
        from PyQt6.QtWidgets import QFileDialog

        files, _ = QFileDialog.getOpenFileNames(
            self,
            tr("TITLE_SELECT_MEDIA"),
            "",
            "Media (*.png *.jpg *.jpeg *.bmp *.mp4 *.webm *.mkv *.m4v *.avi)",
        )
        if files:
            for f in files:
                rel_path = self.dm.import_image(f)
                if rel_path:
                    self.battlemap_list.append(rel_path)
            self._render_battlemap_list()
            self.mark_as_dirty()

    def remove_selected_battlemap(self) -> None:
        row = self.list_battlemaps.currentRow()
        if row >= 0:
            del self.battlemap_list[row]
            self._render_battlemap_list()
            self.mark_as_dirty()

    def _render_battlemap_list(self) -> None:
        self.list_battlemaps.clear()
        video_exts = {".mp4", ".webm", ".mkv", ".m4v", ".avi", ".mov"}
        for path in self.battlemap_list:
            if path.startswith("http"):
                continue
            display_name = os.path.basename(path)
            icon = None
            full_path = self.dm.get_full_path(path)
            if not full_path or not os.path.exists(full_path):
                continue
            ext = os.path.splitext(full_path)[1].lower()
            if ext in video_exts:
                icon = self.style().standardIcon(QStyle.StandardPixmap.SP_MediaPlay)
                display_name = f"{display_name} {tr('SUFFIX_VIDEO')}"
            else:
                pix = QPixmap(full_path).scaled(
                    120, 120,
                    Qt.AspectRatioMode.KeepAspectRatio,
                    Qt.TransformationMode.SmoothTransformation,
                )
                icon = QIcon(pix)
            if icon:
                item = QListWidgetItem(icon, display_name)
                item.setData(Qt.ItemDataRole.UserRole, path)
                item.setToolTip(path)
                self.list_battlemaps.addItem(item)

    # ------------------------------------------------------------------
    # Linked-entity helpers (thin delegates, keep public API)
    # ------------------------------------------------------------------

    def _on_linked_item_dbl_click(self, item: QListWidgetItem) -> None:
        eid = item.data(Qt.ItemDataRole.UserRole)
        if eid:
            self.request_open_entity.emit(eid)

    def add_linked_spell(self) -> None:
        self.spell_widget._on_add()
        self.mark_as_dirty()

    def remove_linked_spell(self) -> None:
        self.spell_widget._on_remove()
        self.mark_as_dirty()

    def add_linked_item(self) -> None:
        self.item_widget._on_add()
        self.mark_as_dirty()

    def remove_linked_item(self) -> None:
        self.item_widget._on_remove()
        self.mark_as_dirty()

    # ------------------------------------------------------------------
    # Image gallery helpers (thin delegates, keep public API)
    # ------------------------------------------------------------------

    def add_image_dialog(self) -> None:
        rel = self.image_gallery.add_image_dialog()
        if rel:
            self.mark_as_dirty()

    def remove_current_image(self) -> None:
        self.image_gallery.remove_current()
        self.mark_as_dirty()

    def show_prev_image(self) -> None:
        self.image_gallery.show_prev()

    def show_next_image(self) -> None:
        self.image_gallery.show_next()

    def update_image_display(self) -> None:
        self.image_gallery.refresh_display()

    # ------------------------------------------------------------------
    # PDF helpers (thin delegates, keep public API)
    # ------------------------------------------------------------------

    def add_pdf_dialog(self) -> None:
        self.pdf_manager.set_entity_id(self.property("entity_id"))
        self.pdf_manager.add_pdf_dialog()
        self.mark_as_dirty()

    def open_current_pdf(self) -> None:
        self.pdf_manager.open_current_pdf()

    def remove_current_pdf(self) -> None:
        self.pdf_manager.set_entity_id(self.property("entity_id"))
        self.pdf_manager.remove_current_pdf()
        self.mark_as_dirty()

    def open_pdf_folder(self) -> None:
        self.pdf_manager.open_pdf_folder()

    # ------------------------------------------------------------------
    # Dynamic form (type-driven properties)
    # ------------------------------------------------------------------

    def _create_section(self, title: str):
        group = QGroupBox(title)
        v = QVBoxLayout(group)
        group.dynamic_area = QVBoxLayout()
        v.addLayout(group.dynamic_area)
        return group

    def add_btn_to_section(self, container, label: str) -> None:
        btn = QPushButton(label)
        btn.clicked.connect(lambda: self.add_feature_card(container))
        btn.setObjectName("successBtn")
        container.layout().insertWidget(0, btn)

    def clear_all_cards(self) -> None:
        for g in [
            self.trait_container,
            self.action_container,
            self.reaction_container,
            self.legendary_container,
            self.inventory_container,
            self.custom_spell_container,
        ]:
            while g.dynamic_area.count():
                item = g.dynamic_area.takeAt(0)
                if item.widget():
                    item.widget().deleteLater()

    def _on_type_index_changed(self, index: int) -> None:
        cat_key = self.inp_type.itemData(index)
        if cat_key:
            self.update_ui_by_type(cat_key)

    def build_dynamic_form(self, category_name: str) -> None:
        while self.layout_dynamic.rowCount() > 0:
            self.layout_dynamic.removeRow(0)
        self.dynamic_inputs = {}
        schema = ENTITY_SCHEMAS.get(category_name, [])
        cat_trans = (
            tr(f"CAT_{category_name.upper()}")
            if category_name in ENTITY_SCHEMAS
            else category_name
        )
        self.grp_dynamic.setTitle(f"{cat_trans} {tr('LBL_PROPERTIES')}")

        for label_key, dtype, options in schema:
            if dtype == "combo":
                widget = QComboBox()
                widget.setEditable(True)
                if options:
                    for opt in options:
                        widget.addItem(tr(opt) if str(opt).startswith("LBL_") else opt, opt)
                widget.editTextChanged.connect(self.mark_as_dirty)
                widget.currentIndexChanged.connect(self.mark_as_dirty)

            elif dtype == "entity_select":
                widget = QComboBox()
                widget.setEditable(True)
                widget.addItem("-", "")
                widget.setProperty("target_type", options)
                self._populate_unified_combo(options, widget)
                widget.activated.connect(
                    lambda idx, w=widget: self._on_unified_selection(idx, w)
                )
                widget.editTextChanged.connect(self.mark_as_dirty)
                self.layout_dynamic.addRow(f"{tr(label_key)}:", widget)
                self.dynamic_inputs[label_key] = widget
                continue  # skip the generic addRow below

            else:
                widget = QLineEdit()
                widget.textChanged.connect(self.mark_as_dirty)

            self.layout_dynamic.addRow(f"{tr(label_key)}:", widget)
            self.dynamic_inputs[label_key] = widget

    def _populate_unified_combo(self, category: str, widget: QComboBox) -> None:
        widget.clear()
        widget.addItem("-", "")
        candidates = []
        for eid, ent in self.dm.data["entities"].items():
            if ent.get("type") == category:
                candidates.append(
                    {
                        "name": ent.get("name", tr("NAME_UNNAMED")),
                        "id": eid,
                        "is_local": True,
                        "source": tr("LBL_LOCAL"),
                    }
                )
        remote_cat = category if category != "Location" else None
        if remote_cat:
            try:
                page = 1
                max_pages = 10
                while page <= max_pages:
                    cache_data = self.dm.get_api_index(remote_cat, page=page)
                    results = (
                        cache_data.get("results", []) if isinstance(cache_data, dict) else []
                    )
                    if not results:
                        break
                    source_label = self.dm.api_client.current_source_key.upper()
                    if source_label == "DND5E":
                        source_label = "SRD 5e"
                    for item in results:
                        candidates.append(
                            {
                                "name": item.get("name", tr("NAME_UNKNOWN")),
                                "id": item.get("index") or item.get("slug"),
                                "is_local": False,
                                "source": source_label,
                                "raw_data": item,
                            }
                        )
                    if isinstance(cache_data, dict) and not cache_data.get("next"):
                        break
                    page += 1
                    QApplication.processEvents()
            except Exception as e:
                logger.error("Unified pop error: %s", e)
        candidates.sort(key=lambda x: x["name"])
        for cand in candidates:
            display = cand["name"]
            if not cand["is_local"]:
                display = f"☁️ {cand['name']} [{cand['source']}]"
            widget.addItem(display, cand["name"])
            idx = widget.count() - 1
            widget.setItemData(idx, cand, Qt.ItemDataRole.UserRole)

    def _on_unified_selection(self, index: int, widget: QComboBox) -> None:
        data = widget.itemData(index, Qt.ItemDataRole.UserRole)
        if not data:
            return
        if not data["is_local"]:
            original_text = widget.itemText(index)
            widget.setItemText(index, f"⏳ {tr('MSG_LOADING')}...")
            QApplication.processEvents()
            target_type = widget.property("target_type")
            try:
                success, parsed_or_msg = self.dm.fetch_details_from_api(
                    target_type, data["id"]
                )
                if success:
                    widget.setItemText(index, data["name"])
                    self.mark_as_dirty()
                else:
                    widget.setItemText(index, original_text)
                    QMessageBox.warning(self, tr("MSG_ERROR"), parsed_or_msg)
            except Exception as e:
                widget.setItemText(index, original_text)
                QMessageBox.critical(self, tr("MSG_ERROR"), f"Error: {e}")
        else:
            self.mark_as_dirty()

    def update_ui_by_type(self, category_name: str) -> None:
        self.build_dynamic_form(category_name)
        is_npc_like = category_name in ["NPC", "Monster"]
        is_player = category_name == "Player"
        is_lore = category_name == "Lore"
        is_status = category_name == "Status Effect"
        is_location = category_name == "Location"

        if category_name == "Location":
            self.list_residents.clear()
            my_id = self.property("entity_id")
            if my_id:
                for eid, ent in self.dm.data["entities"].items():
                    loc_ref = ent.get("location_id") or ent.get(
                        "attributes", {}
                    ).get("LBL_ATTR_LOCATION")
                    if loc_ref == my_id:
                        item = QListWidgetItem(f"{ent['name']} ({ent['type']})")
                        item.setData(Qt.ItemDataRole.UserRole, eid)
                        self.list_residents.addItem(item)

        self.lbl_location.setVisible(is_npc_like or is_player)
        self.combo_location.setVisible(is_npc_like or is_player)
        self.lbl_residents.setVisible(category_name == "Location")
        self.list_residents.setVisible(category_name == "Location")

        self.tabs.setTabVisible(0, is_npc_like)   # Stats
        self.tabs.setTabVisible(1, is_npc_like)   # Spells
        self.tabs.setTabVisible(2, is_npc_like)   # Actions
        self.tabs.setTabVisible(3, is_npc_like)   # Inventory
        self.tabs.setTabVisible(4, is_lore or is_player or is_status or is_location)  # Docs

        idx_battlemap = self.tabs.indexOf(self.tab_battlemaps)
        if idx_battlemap != -1:
            self.tabs.setTabVisible(idx_battlemap, is_location)

        if is_player:
            if self.grp_combat_stats.parent() == self.tab_stats:
                self.tab_stats.layout().removeWidget(self.grp_combat_stats)
                self.content_layout.insertWidget(
                    self.content_layout.indexOf(self.tabs), self.grp_combat_stats
                )
            self.grp_combat_stats.setVisible(True)
        elif is_status:
            self.grp_combat_stats.setVisible(False)
        else:
            if self.grp_combat_stats.parent() != self.tab_stats:
                self.content_layout.removeWidget(self.grp_combat_stats)
                self.tab_stats.layout().insertWidget(1, self.grp_combat_stats)
            self.grp_combat_stats.setVisible(is_npc_like)
