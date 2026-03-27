import importlib
import logging
import os
import sys
from typing import Any, Dict, Optional

from PyQt6.QtCore import Qt
from PyQt6.QtGui import QKeySequence, QShortcut
from PyQt6.QtWidgets import (
    QApplication,
    QFileDialog,
    QMainWindow,
    QMessageBox,
)

from config import CACHE_DIR, DATA_ROOT, DATA_ROOT_MODE, load_theme
from core.data_manager import DataManager
from core.locales import tr
from core.log_config import setup_logging
from core.theme_manager import ThemeManager
from ui.campaign_selector import CampaignSelector
from ui.player_window import PlayerWindow

logger = logging.getLogger(__name__)

_DATA_ROOT_FALLBACK_NOTICE_SHOWN = False


class MainWindow(QMainWindow):
    def __init__(self, data_manager, dev_mode=False):
        super().__init__()
        self.data_manager = data_manager
        self.dev_mode = dev_mode
        self.player_window = PlayerWindow(dev_mode=self.dev_mode)

        self.theme_list = [
            ("dark", "THEME_DARK"),
            ("light", "THEME_LIGHT"),
            ("baldur", "Baldur's Gate"),
            ("discord", "Discord"),
            ("grim", "Grim (Dark)"),
            ("midnight", "THEME_MIDNIGHT"),
            ("emerald", "THEME_EMERALD"),
            ("parchment", "THEME_PARCHMENT"),
            ("ocean", "THEME_OCEAN"),
            ("frost", "THEME_FROST"),
            ("amethyst", "THEME_AMETHYST"),
        ]

        base_title = f"DM Tool - {self.data_manager.data.get('world_name', 'Bilinmiyor')}"
        if self.dev_mode:
            base_title = f"[DEV] {base_title}"
        self.setWindowTitle(base_title)
        self.setGeometry(100, 100, 1400, 900)

        self.current_stylesheet = load_theme(self.data_manager.current_theme)
        self.setStyleSheet(self.current_stylesheet)

        self.active_shortcuts = []

        self.init_ui()
        self._show_data_root_notice_once()

    def _load_root_factory_module(self, reload_module: bool = False):
        module = importlib.import_module("ui.main_root")
        if reload_module:
            module = importlib.reload(module)
        return module

    def _apply_root_bundle(self, bundle: Dict[str, Any]):
        old_central = self.centralWidget()
        self.setCentralWidget(bundle["central_widget"])

        for name, value in bundle.items():
            if name == "central_widget":
                continue
            setattr(self, name, value)

        if old_central is not None and old_central is not self.centralWidget():
            old_central.deleteLater()

    def _capture_reload_state(self) -> Dict[str, Any]:
        state = {
            "geometry": self.saveGeometry(),
            "tab_index": None,
            "splitter_sizes": None,
            "soundpad_visible": False,
            "soundpad_checked": False,
        }

        if hasattr(self, "tabs"):
            state["tab_index"] = self.tabs.currentIndex()
        if hasattr(self, "content_splitter"):
            state["splitter_sizes"] = self.content_splitter.sizes()
        if hasattr(self, "soundpad_panel"):
            state["soundpad_visible"] = self.soundpad_panel.isVisible()
        if hasattr(self, "btn_toggle_sound"):
            state["soundpad_checked"] = self.btn_toggle_sound.isChecked()

        return state

    def _restore_reload_state(self, state: Dict[str, Any]):
        if state.get("geometry") is not None:
            self.restoreGeometry(state["geometry"])

        if state.get("splitter_sizes") and hasattr(self, "content_splitter"):
            current_sizes = self.content_splitter.sizes()
            if len(current_sizes) == len(state["splitter_sizes"]):
                self.content_splitter.setSizes(state["splitter_sizes"])

        if hasattr(self, "soundpad_panel"):
            visible = bool(state.get("soundpad_visible", False))
            self.soundpad_panel.setVisible(visible)
            if hasattr(self, "btn_toggle_sound"):
                self.btn_toggle_sound.setChecked(
                    bool(state.get("soundpad_checked", visible))
                )

        if state.get("tab_index") is not None and hasattr(self, "tabs"):
            tab_index = int(state["tab_index"])
            if 0 <= tab_index < self.tabs.count():
                self.tabs.setCurrentIndex(tab_index)

    def rebuild_root_widget(self, reload_main_root_module: bool = True):
        state = self._capture_reload_state()

        root_factory_module = self._load_root_factory_module(
            reload_module=reload_main_root_module
        )
        bundle = root_factory_module.create_root_widget(self)
        self._apply_root_bundle(bundle)

        self._restore_reload_state(state)

        # Re-apply theme and translated labels after rebuilding widgets.
        self.current_stylesheet = load_theme(self.data_manager.current_theme)
        self.setStyleSheet(self.current_stylesheet)
        if hasattr(self.player_window, "update_theme"):
            self.player_window.update_theme(self.current_stylesheet)

    def init_ui(self):
        root_factory_module = self._load_root_factory_module(reload_module=False)
        bundle = root_factory_module.create_root_widget(self)
        self._apply_root_bundle(bundle)
        self.retranslate_ui()

        self._shortcut_edit_mode = QShortcut(QKeySequence("Ctrl+E"), self)
        self._shortcut_edit_mode.activated.connect(self.toggle_active_edit_mode)

    def toggle_active_edit_mode(self):
        """Toggle edit mode on the currently active entity card."""
        if hasattr(self, "db_tab"):
            sheet = self.db_tab.get_active_sheet()
            if sheet:
                sheet._toggle_edit_mode()

    def _show_data_root_notice_once(self):
        global _DATA_ROOT_FALLBACK_NOTICE_SHOWN
        if DATA_ROOT_MODE != "fallback":
            return
        if _DATA_ROOT_FALLBACK_NOTICE_SHOWN:
            return

        _DATA_ROOT_FALLBACK_NOTICE_SHOWN = True
        QMessageBox.information(
            self,
            tr("MSG_INFO"),
            tr("MSG_DATA_ROOT_FALLBACK", path=DATA_ROOT),
        )

    def setup_soundpad_shortcuts(self, shortcuts_map):
        for shortcut in self.active_shortcuts:
            shortcut.setEnabled(False)
            shortcut.deleteLater()
        self.active_shortcuts.clear()

        if stop_all_key := shortcuts_map.get("stop_all"):
            sc = QShortcut(QKeySequence(stop_all_key), self)
            sc.activated.connect(self.soundpad_panel.stop_all)
            self.active_shortcuts.append(sc)

        if stop_ambience_key := shortcuts_map.get("stop_ambience"):
            sc = QShortcut(QKeySequence(stop_ambience_key), self)
            sc.activated.connect(self.soundpad_panel.stop_ambience)
            self.active_shortcuts.append(sc)

        if sfx_shortcuts := shortcuts_map.get("play_sfx", {}):
            for sfx_id, key_sequence in sfx_shortcuts.items():
                if key_sequence and sfx_id in self.soundpad_panel.sfx_buttons:
                    sc = QShortcut(QKeySequence(key_sequence), self)
                    sc.activated.connect(
                        lambda s_id=sfx_id: self.soundpad_panel.play_sfx(s_id)
                    )
                    self.active_shortcuts.append(sc)

    def retranslate_ui(self):
        self.btn_toggle_player.setText(tr("BTN_PLAYER_SCREEN"))
        self.btn_export_txt.setText(tr("BTN_EXPORT"))
        self.btn_toggle_sound.setToolTip(tr("BTN_TOGGLE_SOUNDPAD"))
        self.lbl_campaign.setText(
            f"{tr('LBL_CAMPAIGN')} {self.data_manager.data.get('world_name')}"
        )
        self.lbl_campaign.setToolTip(tr("TT_DATA_ROOT_ACTIVE", path=DATA_ROOT))
        self.tabs.setTabText(0, tr("TAB_DB"))
        self.tabs.setTabText(1, tr("TAB_MIND_MAP"))
        self.tabs.setTabText(2, tr("TAB_MAP"))
        self.tabs.setTabText(3, tr("TAB_SESSION"))

        if hasattr(self.db_tab, "retranslate_ui"):
            self.db_tab.retranslate_ui()
        if hasattr(self.map_tab, "retranslate_ui"):
            self.map_tab.retranslate_ui()
        if hasattr(self.session_tab, "retranslate_ui"):
            self.session_tab.retranslate_ui()
        if hasattr(self.soundpad_panel, "retranslate_ui"):
            self.soundpad_panel.retranslate_ui()
        if hasattr(self.entity_sidebar, "retranslate_ui"):
            self.entity_sidebar.retranslate_ui()

        self.lbl_theme.setText(tr("LBL_THEME"))
        for i, (_, display_name) in enumerate(self.theme_list):
            text = tr(display_name) if display_name.startswith("THEME_") else display_name
            self.combo_theme.setItemText(i, text)

    def change_language(self, index):
        codes = ["EN", "TR", "DE", "FR"]
        code = codes[index] if index < len(codes) else "EN"
        self.data_manager.save_settings({"language": code})
        self.retranslate_ui()

    def toggle_soundpad(self):
        is_visible = self.soundpad_panel.isVisible()
        self.soundpad_panel.setVisible(not is_visible)
        self.btn_toggle_sound.setChecked(not is_visible)
        if not is_visible:
            sizes = self.content_splitter.sizes()
            if sizes[-1] == 0:
                new_size = 300
                sizes[1] -= new_size
                sizes[-1] = new_size
                self.content_splitter.setSizes(sizes)

    def change_theme(self, index):
        if 0 <= index < len(self.theme_list):
            theme_name = self.theme_list[index][0]
            self.data_manager.save_settings({"theme": theme_name})

            self.current_stylesheet = load_theme(theme_name)
            self.setStyleSheet(self.current_stylesheet)
            if hasattr(self.player_window, "update_theme"):
                self.player_window.update_theme(self.current_stylesheet)

            if hasattr(self.mind_map_tab, "apply_theme"):
                self.mind_map_tab.apply_theme(theme_name)

            self.refresh_database_tab_themes(theme_name)

    def refresh_database_tab_themes(self, theme_name):
        palette = ThemeManager.get_palette(theme_name)

        # Refresh the EntityTabWidget tab bars themselves
        self.db_tab.tab_manager_left.refresh_theme(palette)
        self.db_tab.tab_manager_right.refresh_theme(palette)

        # Refresh each open NpcSheet card
        for i in range(self.db_tab.tab_manager_left.count()):
            sheet = self.db_tab.tab_manager_left.widget(i)
            if hasattr(sheet, "refresh_theme"):
                sheet.refresh_theme(palette)

        for i in range(self.db_tab.tab_manager_right.count()):
            sheet = self.db_tab.tab_manager_right.widget(i)
            if hasattr(sheet, "refresh_theme"):
                sheet.refresh_theme(palette)

        # Refresh the entity sidebar
        if hasattr(self, "entity_sidebar"):
            self.entity_sidebar.refresh_theme(palette)

    def toggle_player_window(self):
        if self.player_window.isVisible():
            self.player_window.hide()
            self.btn_toggle_player.setChecked(False)
            self.projection_manager.setVisible(False)
        else:
            self.player_window.show()
            self.btn_toggle_player.setChecked(True)
            self.player_window.update_theme(self.current_stylesheet)
            self.projection_manager.setVisible(True)

    def export_entities_to_txt(self):
        path, _ = QFileDialog.getSaveFileName(
            self, tr("TITLE_EXPORT"), "export.txt", tr("FILE_FILTER_TXT")
        )
        if not path:
            return
        try:
            with open(path, "w", encoding="utf-8") as f:
                f.write(f"{tr('TXT_EXPORT_HEADER')}\n")
                f.write(
                    f"{tr('TXT_EXPORT_WORLD')}{self.data_manager.data.get('world_name')}\n"
                )
                f.write("=" * 50 + "\n\n")
                entities = self.data_manager.data.get("entities", {})
                if not entities:
                    f.write(f"{tr('TXT_EXPORT_NO_DATA')}\n")
                sorted_keys = sorted(entities.keys(), key=lambda k: entities[k].get("name", ""))
                for i, eid in enumerate(sorted_keys, 1):
                    ent = entities[eid]
                    name = ent.get("name", tr("NAME_UNNAMED"))
                    type_ = ent.get("type", tr("NAME_UNKNOWN"))
                    tags = ", ".join(ent.get("tags", []))
                    desc = ent.get("description", "").replace("\n", " ")
                    if len(desc) > 100:
                        desc = desc[:97] + "..."
                    f.write(f"{i}. {name} ({type_})\n")
                    if tags:
                        f.write(f"{tr('TXT_EXPORT_TAGS')}{tags}\n")
                    f.write(f"{tr('TXT_EXPORT_DESC')}{desc}\n")
                    c = ent.get("combat_stats", {})
                    if type_ in ["NPC", "Monster", "Player"] and c:
                        hp = c.get("hp", "-")
                        ac = c.get("ac", "-")
                        cr = c.get("cr", "-")
                        f.write(f"   HP: {hp} | AC: {ac} | CR: {cr}\n")
                    f.write("-" * 30 + "\n")
            QMessageBox.information(self, tr("MSG_SUCCESS"), tr("MSG_EXPORT_SUCCESS"))
        except Exception as e:
            QMessageBox.critical(
                self, tr("MSG_ERROR"), tr("MSG_FILE_WRITE_ERROR", error=str(e))
            )

    def switch_world(self):
        self.switch_world_requested = True
        self.close()

    def on_entity_selected(self, eid):
        current_idx = self.tabs.currentIndex()
        current_widget = self.tabs.widget(current_idx)
        if current_widget == self.db_tab:
            self.db_tab.open_entity_tab(eid)
        else:
            self.tabs.setCurrentWidget(self.db_tab)
            self.db_tab.open_entity_tab(eid)


def run_application(
    dev_bridge=None,
    dev_last_world: Optional[str] = None,
):
    QApplication.setAttribute(Qt.ApplicationAttribute.AA_ShareOpenGLContexts)
    app = QApplication(sys.argv)

    if dev_bridge is not None:
        dev_bridge.start()
        app.aboutToQuit.connect(dev_bridge.close)

    dm = DataManager()
    pending_dev_world = dev_last_world

    while True:
        campaign_loaded = False

        if pending_dev_world:
            success, msg = dm.load_campaign_by_name(pending_dev_world)
            if success:
                campaign_loaded = True
                logger.info("Auto-loaded world: %s", pending_dev_world)
            else:
                logger.warning(
                    "Failed to auto-load world '%s': %s. Opening campaign selector.",
                    pending_dev_world,
                    msg,
                )
            pending_dev_world = None

        if not campaign_loaded:
            selector = CampaignSelector(dm)
            if not selector.exec():
                break

        window = MainWindow(dm, dev_mode=(os.getenv("DM_DEV_CHILD") == "1"))
        if dev_bridge is not None:
            dev_bridge.attach(window)

        window.show()
        app.exec()

        if getattr(window, "switch_world_requested", False):
            continue
        break

    return 0


if __name__ == "__main__":
    setup_logging(
        level="DEBUG" if os.getenv("DM_DEV_CHILD") == "1" else "INFO",
        log_dir=str(CACHE_DIR),
    )

    dev_bridge = None
    dev_last_world = None

    if os.getenv("DM_DEV_CHILD") == "1":
        dev_last_world = os.getenv("DM_DEV_LAST_WORLD") or None
        from core.dev.ipc_bridge import DevIpcBridge

        dev_bridge = DevIpcBridge.from_env()

    exit_code = run_application(dev_bridge=dev_bridge, dev_last_world=dev_last_world)

    if dev_bridge is not None:
        dev_bridge.close()

    sys.exit(exit_code)
