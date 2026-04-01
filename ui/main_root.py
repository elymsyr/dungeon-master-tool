from PyQt6.QtCore import Qt
from PyQt6.QtWidgets import (
    QApplication,
    QComboBox,
    QHBoxLayout,
    QLabel,
    QPushButton,
    QSplitter,
    QStyle,
    QTabWidget,
    QVBoxLayout,
    QWidget,
)

from config import DATA_ROOT
from core.locales import tr
from ui.tabs.database_tab import DatabaseTab
from ui.tabs.map_tab import MapTab
from ui.tabs.mind_map_tab import MindMapTab
from ui.tabs.session_tab import SessionTab
from ui.pdf_panel import PdfPanel
from ui.widgets.entity_sidebar import EntitySidebar
from ui.widgets.projection_manager import ProjectionManager


class SoundpadPlaceholder(QWidget):
    """Lightweight stand-in until the real SoundpadPanel is requested."""

    def __init__(self):
        super().__init__()
        self.sfx_buttons = {}
        self.setMinimumWidth(240)
        self.setMaximumWidth(400)
        self.setObjectName("soundpadContainer")

    def stop_all(self):
        return None

    def stop_ambience(self):
        return None

    def play_sfx(self, _sfx_id):
        return None

    def retranslate_ui(self):
        return None


def create_root_widget(main_window):
    """Builds the main window root UI tree and returns all key widget refs."""
    data_manager = main_window.data_manager
    player_window = main_window.player_window
    event_bus = getattr(main_window, "event_bus", None)

    central = QWidget()
    main_layout = QVBoxLayout(central)

    toolbar = QHBoxLayout()
    toolbar.setContentsMargins(5, 5, 5, 5)

    btn_toggle_player = QPushButton(tr("BTN_PLAYER_SCREEN"))
    btn_toggle_player.setCheckable(True)
    btn_toggle_player.setObjectName("primaryBtn")
    btn_toggle_player.clicked.connect(main_window.toggle_player_window)

    btn_export_txt = QPushButton(tr("BTN_EXPORT"))
    btn_export_txt.setObjectName("successBtn")
    btn_export_txt.clicked.connect(main_window.export_entities_to_txt)

    style = QApplication.style()
    btn_toggle_sound = QPushButton()
    btn_toggle_sound.setIcon(style.standardIcon(QStyle.StandardPixmap.SP_MediaVolume))
    btn_toggle_sound.setFixedSize(28, 28)
    btn_toggle_sound.setCheckable(True)
    btn_toggle_sound.setToolTip(tr("BTN_TOGGLE_SOUNDPAD"))
    btn_toggle_sound.clicked.connect(main_window.toggle_soundpad)

    btn_toggle_pdf = QPushButton()
    btn_toggle_pdf.setIcon(style.standardIcon(QStyle.StandardPixmap.SP_FileIcon))
    btn_toggle_pdf.setFixedSize(28, 28)
    btn_toggle_pdf.setCheckable(True)
    btn_toggle_pdf.setToolTip(tr("BTN_TOGGLE_PDF_PANEL"))
    btn_toggle_pdf.clicked.connect(main_window.toggle_pdf_panel)

    btn_edit_mode = QPushButton(f"✏️ {tr('BTN_EDIT')}")
    btn_edit_mode.setCheckable(True)
    btn_edit_mode.setObjectName("editModeBtn")
    btn_edit_mode.setToolTip(tr("BTN_EDIT"))
    btn_edit_mode.clicked.connect(main_window.toggle_active_edit_mode)

    lbl_campaign = QLabel(f"{tr('LBL_CAMPAIGN')} {data_manager.data.get('world_name')}")
    lbl_campaign.setObjectName("toolbarLabel")
    lbl_campaign.setStyleSheet("font-weight: bold; margin-right: 10px;")
    lbl_campaign.setToolTip(tr("TT_DATA_ROOT_ACTIVE", path=DATA_ROOT))

    btn_switch_world = QPushButton(tr("BTN_SWITCH_WORLD"))
    btn_switch_world.setToolTip(tr("BTN_SWITCH_WORLD"))
    btn_switch_world.clicked.connect(main_window.switch_world)

    projection_manager = ProjectionManager()
    projection_manager.setVisible(False)
    projection_manager.image_added.connect(player_window.add_image_to_view)
    projection_manager.image_removed.connect(player_window.remove_image_from_view)

    combo_lang = QComboBox()
    combo_lang.addItems(["English", "Türkçe", "Deutsch", "Français"])
    current_lang = data_manager.settings.get("language", "EN")
    lang_map = {"EN": 0, "TR": 1, "DE": 2, "FR": 3}
    combo_lang.setCurrentIndex(lang_map.get(current_lang.upper(), 0))
    combo_lang.currentIndexChanged.connect(main_window.change_language)

    lbl_theme = QLabel(tr("LBL_THEME"))
    lbl_theme.setObjectName("toolbarLabel")

    combo_theme = QComboBox()
    for _, display_name in main_window.theme_list:
        text = tr(display_name) if display_name.startswith("THEME_") else display_name
        combo_theme.addItem(text)

    current_theme_code = data_manager.current_theme
    index_to_select = next(
        (i for i, (code, _) in enumerate(main_window.theme_list) if code == current_theme_code),
        0,
    )
    combo_theme.setCurrentIndex(index_to_select)
    combo_theme.currentIndexChanged.connect(main_window.change_theme)

    toolbar.addWidget(btn_toggle_player)
    toolbar.addWidget(btn_export_txt)
    toolbar.addWidget(btn_toggle_sound)
    toolbar.addWidget(btn_toggle_pdf)
    toolbar.addWidget(btn_edit_mode)
    toolbar.addSpacing(10)
    toolbar.addWidget(lbl_campaign)
    toolbar.addWidget(projection_manager)
    toolbar.addStretch()
    toolbar.addWidget(combo_lang)
    toolbar.addWidget(lbl_theme)
    toolbar.addWidget(combo_theme)
    toolbar.addWidget(btn_switch_world)

    main_layout.addLayout(toolbar)

    content_splitter = QSplitter(Qt.Orientation.Horizontal)
    content_splitter.setHandleWidth(4)

    entity_sidebar = EntitySidebar(data_manager, event_bus=event_bus)
    entity_sidebar.item_double_clicked.connect(main_window.on_entity_selected)
    content_splitter.addWidget(entity_sidebar)

    tabs = QTabWidget()

    db_tab = DatabaseTab(data_manager, player_window, event_bus=event_bus)
    tabs.addTab(db_tab, tr("TAB_DB"))

    mind_map_tab = MindMapTab(data_manager, main_window_ref=main_window, event_bus=event_bus)
    tabs.addTab(mind_map_tab, tr("TAB_MIND_MAP"))

    map_tab = MapTab(data_manager, player_window, main_window)
    tabs.addTab(map_tab, tr("TAB_MAP"))

    session_tab = SessionTab(data_manager, player_window, event_bus=event_bus)
    tabs.addTab(session_tab, tr("TAB_SESSION"))

    content_splitter.addWidget(tabs)

    soundpad_panel = SoundpadPlaceholder()
    soundpad_panel.setVisible(False)
    content_splitter.addWidget(soundpad_panel)

    pdf_panel = PdfPanel()
    pdf_panel.setVisible(False)
    content_splitter.addWidget(pdf_panel)

    content_splitter.setStretchFactor(0, 0)
    content_splitter.setStretchFactor(1, 1)
    content_splitter.setStretchFactor(2, 0)
    content_splitter.setStretchFactor(3, 0)
    content_splitter.setCollapsible(0, True)
    content_splitter.setCollapsible(2, True)
    content_splitter.setCollapsible(3, True)
    content_splitter.setSizes([300, 1000, 0, 0])

    main_layout.addWidget(content_splitter)

    # entity.deleted → entity_sidebar.refresh_list is now handled via EventBus
    session_tab.txt_log.entity_link_clicked.connect(db_tab.open_entity_tab)
    session_tab.txt_notes.entity_link_clicked.connect(db_tab.open_entity_tab)

    return {
        "central_widget": central,
        "btn_toggle_player": btn_toggle_player,
        "btn_export_txt": btn_export_txt,
        "btn_toggle_sound": btn_toggle_sound,
        "lbl_campaign": lbl_campaign,
        "btn_switch_world": btn_switch_world,
        "projection_manager": projection_manager,
        "combo_lang": combo_lang,
        "lbl_theme": lbl_theme,
        "combo_theme": combo_theme,
        "content_splitter": content_splitter,
        "entity_sidebar": entity_sidebar,
        "tabs": tabs,
        "db_tab": db_tab,
        "mind_map_tab": mind_map_tab,
        "map_tab": map_tab,
        "session_tab": session_tab,
        "soundpad_panel": soundpad_panel,
        "pdf_panel": pdf_panel,
        "btn_toggle_pdf": btn_toggle_pdf,
        "btn_edit_mode": btn_edit_mode,
    }
