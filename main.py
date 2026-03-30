import base64
import importlib
import logging
import os
import sys
from typing import Any, Dict, Optional

from PyQt6.QtCore import QByteArray, Qt
from PyQt6.QtGui import QImageReader, QKeySequence, QShortcut
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
from ui.soundpad_panel import SoundpadPanel

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
        self._map_tab_rendered_once = False

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
        if hasattr(self, "session_tab"):
            st = self.session_tab
            state["session_main_splitter"]  = st.main_splitter.sizes()
            state["session_right_splitter"] = st.right_splitter.sizes()
            state["session_bottom_tab"]     = st.bottom_tabs.currentIndex()
        if hasattr(self, "db_tab"):
            state["db_workspace_splitter"] = self.db_tab.workspace_splitter.sizes()

        return state

    def _restore_reload_state(self, state: Dict[str, Any]):
        def _apply_sizes(splitter, sizes):
            if sizes and len(splitter.sizes()) == len(sizes):
                splitter.setSizes(sizes)

        if state.get("geometry") is not None:
            self.restoreGeometry(state["geometry"])

        if hasattr(self, "content_splitter"):
            _apply_sizes(self.content_splitter, state.get("splitter_sizes"))

        if hasattr(self, "soundpad_panel"):
            visible = bool(state.get("soundpad_visible", False))
            if visible:
                self._ensure_soundpad_panel()
            self.soundpad_panel.setVisible(visible)
            if hasattr(self, "btn_toggle_sound"):
                self.btn_toggle_sound.setChecked(
                    bool(state.get("soundpad_checked", visible))
                )

        if state.get("tab_index") is not None and hasattr(self, "tabs"):
            tab_index = int(state["tab_index"])
            if 0 <= tab_index < self.tabs.count():
                self.tabs.setCurrentIndex(tab_index)

        if hasattr(self, "session_tab"):
            st = self.session_tab
            _apply_sizes(st.main_splitter,  state.get("session_main_splitter"))
            _apply_sizes(st.right_splitter, state.get("session_right_splitter"))
            idx = state.get("session_bottom_tab")
            if idx is not None and 0 <= idx < st.bottom_tabs.count():
                st.bottom_tabs.setCurrentIndex(idx)

        if hasattr(self, "db_tab"):
            _apply_sizes(self.db_tab.workspace_splitter, state.get("db_workspace_splitter"))

    def rebuild_root_widget(self, reload_main_root_module: bool = True):
        state = self._capture_reload_state()

        root_factory_module = self._load_root_factory_module(
            reload_module=reload_main_root_module
        )
        bundle = root_factory_module.create_root_widget(self)
        self._apply_root_bundle(bundle)

        self._restore_reload_state(state)
        self._post_root_setup()

        # Re-apply theme and translated labels after rebuilding widgets.
        self.current_stylesheet = load_theme(self.data_manager.current_theme)
        self.setStyleSheet(self.current_stylesheet)
        if hasattr(self.player_window, "update_theme"):
            self.player_window.update_theme(self.current_stylesheet)

    def closeEvent(self, event):
        state = {}
        state["geometry"] = base64.b64encode(self.saveGeometry().data()).decode()
        if hasattr(self, "content_splitter"):
            state["splitter_sizes"] = self.content_splitter.sizes()
        if hasattr(self, "tabs"):
            state["tab_index"] = self.tabs.currentIndex()
        if hasattr(self, "soundpad_panel"):
            state["soundpad_visible"] = self.soundpad_panel.isVisible()

        # Session tab layout
        if hasattr(self, "session_tab"):
            st = self.session_tab
            state["session_main_splitter"]  = st.main_splitter.sizes()
            state["session_right_splitter"] = st.right_splitter.sizes()
            state["session_bottom_tab"]     = st.bottom_tabs.currentIndex()

        # Database tab layout + open cards
        if hasattr(self, "db_tab"):
            state["db_workspace_splitter"] = self.db_tab.workspace_splitter.sizes()

            def _panel_eids(manager):
                return [
                    manager.widget(i).property("entity_id")
                    for i in range(manager.count())
                    if manager.widget(i) and manager.widget(i).property("entity_id")
                ]

            state["db_open_left"]   = _panel_eids(self.db_tab.tab_manager_left)
            state["db_open_right"]  = _panel_eids(self.db_tab.tab_manager_right)
            state["db_active_left"] = self.db_tab.tab_manager_left.currentIndex()
            state["db_active_right"]= self.db_tab.tab_manager_right.currentIndex()

        self.data_manager.save_settings({"ui_state": state})
        super().closeEvent(event)

    def _restore_ui_state_from_settings(self):
        ui = self.data_manager.settings.get("ui_state", {})

        def _apply_sizes(splitter, sizes):
            if sizes and len(splitter.sizes()) == len(sizes):
                splitter.setSizes(sizes)

        if geom := ui.get("geometry"):
            try:
                self.restoreGeometry(QByteArray(base64.b64decode(geom)))
            except Exception:
                pass

        if hasattr(self, "content_splitter"):
            _apply_sizes(self.content_splitter, ui.get("splitter_sizes"))

        visible = ui.get("soundpad_visible", False)
        if hasattr(self, "soundpad_panel"):
            if visible:
                self._ensure_soundpad_panel()
            self.soundpad_panel.setVisible(visible)
            if hasattr(self, "btn_toggle_sound"):
                self.btn_toggle_sound.setChecked(visible)

        if (idx := ui.get("tab_index")) is not None and hasattr(self, "tabs"):
            if 0 <= idx < self.tabs.count():
                self.tabs.setCurrentIndex(idx)

        # Session tab
        if hasattr(self, "session_tab"):
            st = self.session_tab
            _apply_sizes(st.main_splitter,  ui.get("session_main_splitter"))
            _apply_sizes(st.right_splitter, ui.get("session_right_splitter"))
            idx = ui.get("session_bottom_tab")
            if idx is not None and 0 <= idx < st.bottom_tabs.count():
                st.bottom_tabs.setCurrentIndex(idx)

        # Database tab
        if hasattr(self, "db_tab"):
            _apply_sizes(self.db_tab.workspace_splitter, ui.get("db_workspace_splitter"))
            for eid in ui.get("db_open_left", []):
                try:
                    self.db_tab.open_entity_tab(eid, target_panel="left")
                except Exception:
                    pass
            for eid in ui.get("db_open_right", []):
                try:
                    self.db_tab.open_entity_tab(eid, target_panel="right")
                except Exception:
                    pass
            li = ui.get("db_active_left", -1)
            if li >= 0:
                self.db_tab.tab_manager_left.setCurrentIndex(li)
            ri = ui.get("db_active_right", -1)
            if ri >= 0:
                self.db_tab.tab_manager_right.setCurrentIndex(ri)

    def init_ui(self):
        root_factory_module = self._load_root_factory_module(reload_module=False)
        bundle = root_factory_module.create_root_widget(self)
        self._apply_root_bundle(bundle)
        self.retranslate_ui()
        self._restore_ui_state_from_settings()
        self._post_root_setup()

        self._shortcut_edit_mode = QShortcut(QKeySequence("Ctrl+E"), self)
        self._shortcut_edit_mode.activated.connect(self.toggle_active_edit_mode)

    def _post_root_setup(self):
        self._map_tab_rendered_once = False
        if hasattr(self, "tabs"):
            self.tabs.currentChanged.connect(self._on_main_tab_changed)
            self._on_main_tab_changed(self.tabs.currentIndex())

    def _on_main_tab_changed(self, index: int):
        if not hasattr(self, "tabs") or not hasattr(self, "map_tab"):
            return
        if not (0 <= index < self.tabs.count()):
            return
        if self.tabs.widget(index) is self.map_tab and not self._map_tab_rendered_once:
            self.map_tab.render_map()
            self._map_tab_rendered_once = True

    def _ensure_soundpad_panel(self):
        panel = getattr(self, "soundpad_panel", None)
        if isinstance(panel, SoundpadPanel):
            return panel
        if panel is None or not hasattr(self, "content_splitter"):
            return panel

        visible = panel.isVisible()
        index = self.content_splitter.indexOf(panel)
        if index < 0:
            index = self.content_splitter.count() - 1

        real_panel = SoundpadPanel()
        real_panel.setVisible(visible)
        real_panel.theme_loaded_with_shortcuts.connect(self.setup_soundpad_shortcuts)
        self.setup_soundpad_shortcuts(real_panel.global_library.get("shortcuts", {}))

        old_panel = self.content_splitter.replaceWidget(index, real_panel)
        if old_panel is not None and old_panel is not real_panel:
            old_panel.deleteLater()

        self.soundpad_panel = real_panel
        return real_panel

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
            sc.activated.connect(self._soundpad_stop_all)
            self.active_shortcuts.append(sc)

        if stop_ambience_key := shortcuts_map.get("stop_ambience"):
            sc = QShortcut(QKeySequence(stop_ambience_key), self)
            sc.activated.connect(self._soundpad_stop_ambience)
            self.active_shortcuts.append(sc)

        if sfx_shortcuts := shortcuts_map.get("play_sfx", {}):
            for sfx_id, key_sequence in sfx_shortcuts.items():
                if key_sequence:
                    sc = QShortcut(QKeySequence(key_sequence), self)
                    sc.activated.connect(
                        lambda s_id=sfx_id: self._soundpad_play_sfx(s_id)
                    )
                    self.active_shortcuts.append(sc)

    def _soundpad_stop_all(self):
        panel = self._ensure_soundpad_panel()
        if panel:
            panel.stop_all()

    def _soundpad_stop_ambience(self):
        panel = self._ensure_soundpad_panel()
        if panel:
            panel.stop_ambience()

    def _soundpad_play_sfx(self, sfx_id):
        panel = self._ensure_soundpad_panel()
        if panel:
            panel.play_sfx(sfx_id)

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
        panel = self._ensure_soundpad_panel()
        if panel is None:
            return

        is_visible = panel.isVisible()
        panel.setVisible(not is_visible)
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
    # Force VA-API software decode to avoid hardware-accelerated decode
    # failures (invalid VAEntryPoint) on systems with incomplete VA-API support.
    os.environ.setdefault("LIBVA_DRIVER_NAME", "null")
    QApplication.setAttribute(Qt.ApplicationAttribute.AA_ShareOpenGLContexts)
    app = QApplication(sys.argv)
    QImageReader.setAllocationLimit(1024)  # allow large battle map images up to 2 GB decoded

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
