import json
from typing import Any

from PyQt6.QtCore import Qt, QThread, QTimer, pyqtSignal
from PyQt6.QtWidgets import (
    QComboBox,
    QDialog,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QListWidget,
    QListWidgetItem,
    QMessageBox,
    QPushButton,
    QSplitter,
    QStyle,
    QTabWidget,
    QTextEdit,
    QTreeWidget,
    QTreeWidgetItem,
    QVBoxLayout,
    QWidget,
    QAbstractItemView,
)

from core.locales import tr
from ui.dialogs.bulk_downloader import BulkDownloadDialog
from ui.workers import ApiListWorker


LOCAL_CATEGORY_TO_TYPE = {
    "monsters": "Monster",
    "spells": "Spell",
    "equipment": "Equipment",
    "magic-items": "Equipment",
    "weapons": "Equipment",
    "armor": "Equipment",
    "classes": "Class",
    "races": "Race",
    "feats": "Feat",
    "conditions": "Condition",
    "npc": "NPC",
}


def resolve_entity_type(category_or_type: str | None) -> str:
    if not category_or_type:
        return ""
    key = str(category_or_type)
    if key in LOCAL_CATEGORY_TO_TYPE:
        return LOCAL_CATEGORY_TO_TYPE[key]

    api_map = {
        "Magic Item": "Equipment",
    }
    if key in api_map:
        return api_map[key]
    return key


class LibraryScanWorker(QThread):
    """Scans the on-disk cache/library folder and builds a tree structure."""

    finished = pyqtSignal(dict)

    def __init__(self, data_manager, parent=None):
        super().__init__(parent)
        self.dm = data_manager

    def run(self):
        self.dm.refresh_library_catalog()
        self.finished.emit(self.dm.library_tree)


class LocalLibraryTab(QWidget):
    def __init__(self, data_manager, parent_window):
        super().__init__()
        self.dm = data_manager
        self.parent_window = parent_window
        self.selected_file_path = None

        self.init_ui()
        self.refresh_library()

    def init_ui(self):
        layout = QHBoxLayout(self)

        left_layout = QVBoxLayout()
        self.inp_search = QLineEdit()
        self.inp_search.setPlaceholderText(tr("LBL_SEARCH"))
        self.inp_search.textChanged.connect(self.filter_tree)

        self.tree = QTreeWidget()
        self.tree.setHeaderHidden(True)
        self.tree.setSelectionMode(QAbstractItemView.SelectionMode.ExtendedSelection)
        self.tree.itemClicked.connect(self.on_item_clicked)
        self.tree.itemSelectionChanged.connect(self.on_selection_changed)

        btn_refresh = QPushButton(tr("BTN_REFRESH") if hasattr(tr, "BTN_REFRESH") else "Refresh")
        btn_refresh.clicked.connect(self.refresh_library)

        left_layout.addWidget(self.inp_search)
        left_layout.addWidget(self.tree)
        left_layout.addWidget(btn_refresh)

        right_layout = QVBoxLayout()
        self.lbl_name = QLabel(tr("MSG_NO_SELECTION"))
        self.lbl_name.setObjectName("importTitle")

        self.txt_preview = QTextEdit()
        self.txt_preview.setReadOnly(True)

        self.btn_import = QPushButton(tr("BTN_IMPORT"))
        self.btn_import.setObjectName("successBtn")
        self.btn_import.setEnabled(False)
        self.btn_import.clicked.connect(self.import_selected)

        right_layout.addWidget(self.lbl_name)
        right_layout.addWidget(self.txt_preview)
        right_layout.addWidget(self.btn_import)

        splitter = QSplitter(Qt.Orientation.Horizontal)
        w_left = QWidget()
        w_left.setLayout(left_layout)
        w_right = QWidget()
        w_right.setLayout(right_layout)
        splitter.addWidget(w_left)
        splitter.addWidget(w_right)
        splitter.setSizes([300, 500])

        layout.addWidget(splitter)

    def refresh_library(self):
        self.tree.clear()
        self.tree.setEnabled(False)
        self.worker = LibraryScanWorker(self.dm, self)
        self.worker.finished.connect(self.on_scan_finished)
        self.worker.start()

    def on_scan_finished(self, data):
        self.tree.setEnabled(True)
        self.tree.clear()

        for source, categories in sorted(data.items()):
            source_item = QTreeWidgetItem(self.tree)
            source_item.setText(0, source.upper())
            source_item.setFlags(source_item.flags() & ~Qt.ItemFlag.ItemIsSelectable)

            for cat, files in sorted(categories.items()):
                cat_item = QTreeWidgetItem(source_item)
                cat_map_tr = {
                    "monsters": tr("CAT_MONSTERS_PL"),
                    "spells": tr("CAT_SPELLS_PL"),
                    "equipment": tr("CAT_EQUIPMENT_ALL"),
                    "classes": tr("CAT_CLASSES_PL"),
                    "races": tr("CAT_RACES_PL"),
                    "magic-items": tr("CAT_MAGIC_ITEMS_ALL"),
                }
                cat_text = cat_map_tr.get(cat, cat.title())

                cat_item.setText(0, f"{cat_text} ({len(files)})")
                cat_item.setFlags(cat_item.flags() & ~Qt.ItemFlag.ItemIsSelectable)

                for entry in files:
                    f_path = entry.get("path")
                    f_name = entry.get("display_name") or entry.get("index", "")
                    f_slug = entry.get("index", "")
                    file_item = QTreeWidgetItem(cat_item)
                    file_item.setText(0, f_name)
                    file_item.setData(
                        0,
                        Qt.ItemDataRole.UserRole,
                        {"path": f_path, "slug": f_slug, "cat": cat},
                    )

        self.tree.expandAll()
        self.on_selection_changed()

    def filter_tree(self, text):
        search = text.lower()
        root = self.tree.invisibleRootItem()
        for i in range(root.childCount()):
            source_item = root.child(i)
            source_visible = False
            for j in range(source_item.childCount()):
                cat_item = source_item.child(j)
                cat_visible = False
                for k in range(cat_item.childCount()):
                    file_item = cat_item.child(k)
                    if search in file_item.text(0).lower():
                        file_item.setHidden(False)
                        cat_visible = True
                        source_visible = True
                    else:
                        file_item.setHidden(True)
                cat_item.setHidden(not cat_visible)
            source_item.setHidden(not source_visible)

    def _read_json_payload(self, path: str) -> dict[str, Any] | None:
        with open(path, "r", encoding="utf-8") as f:
            raw_content = f.read().strip()
            if not raw_content:
                raise ValueError("File is empty")

            content: Any = json.loads(raw_content)
            for _ in range(3):
                if isinstance(content, str):
                    try:
                        content = json.loads(content)
                    except json.JSONDecodeError:
                        break
                else:
                    break

            if not isinstance(content, dict):
                raise ValueError(f"Invalid data format: {type(content)}")
            return content

    def _parse_payload(self, payload_meta: dict[str, Any]) -> tuple[dict[str, Any] | None, str, str | None]:
        cat = payload_meta.get("cat", "")
        api_cat = LOCAL_CATEGORY_TO_TYPE.get(cat, "Monster")
        path = payload_meta.get("path")
        if not path:
            return None, api_cat, "Missing file path"

        try:
            content = self._read_json_payload(path)
            parsed = self.dm.api_client.parse_dispatcher(api_cat, content)
            if not isinstance(parsed, dict) or not parsed:
                return None, api_cat, "Failed to parse file"
            return parsed, api_cat, None
        except Exception as e:
            return None, api_cat, str(e)

    def on_item_clicked(self, item, _col):
        payload = item.data(0, Qt.ItemDataRole.UserRole)
        if not payload:
            self.selected_file_path = None
            self.lbl_name.setText(tr("MSG_NO_SELECTION"))
            self.txt_preview.clear()
            return

        self.selected_file_path = payload.get("path")
        parsed, api_cat, err = self._parse_payload(payload)
        if err or not parsed:
            self.lbl_name.setText(tr("LBL_ERROR_READING_FILE"))
            self.txt_preview.setText(f"Error: {err}")
            return

        src = parsed.get("source") or tr("NAME_UNKNOWN")
        type_ = parsed.get("type") or api_cat
        desc = parsed.get("description") or tr("LBL_FAILED_LOAD_DATA")

        self.lbl_name.setText(parsed.get("name", item.text(0)))
        self.txt_preview.setHtml(
            f"<b>{tr('LBL_SOURCE')}</b> {src}<br><b>{tr('LBL_TYPE')}</b> {type_}<br><hr>{desc}"
        )

    def _selected_leaf_payloads(self) -> list[dict[str, Any]]:
        selected_payloads = []
        for item in self.tree.selectedItems():
            payload = item.data(0, Qt.ItemDataRole.UserRole)
            if payload:
                selected_payloads.append(payload)
        return selected_payloads

    def on_selection_changed(self):
        selected_payloads = self._selected_leaf_payloads()
        if not selected_payloads:
            self.btn_import.setEnabled(False)
            self.btn_import.setToolTip("")
            return

        allowed = all(
            self.parent_window.is_type_allowed(payload.get("cat"))
            for payload in selected_payloads
        )
        self.btn_import.setEnabled(allowed)
        if not allowed:
            self.btn_import.setToolTip(
                tr("MSG_IMPORT_TYPE_MISMATCH", type=self.parent_window.expected_type)
            )
        else:
            self.btn_import.setToolTip("")

    def import_selected(self):
        selected_payloads = self._selected_leaf_payloads()
        if not selected_payloads:
            QMessageBox.warning(self, tr("MSG_WARNING"), tr("MSG_IMPORT_SELECT_FIRST"))
            return

        disallowed = [p for p in selected_payloads if not self.parent_window.is_type_allowed(p.get("cat"))]
        if disallowed:
            QMessageBox.warning(
                self,
                tr("MSG_WARNING"),
                tr("MSG_IMPORT_TYPE_MISMATCH", type=self.parent_window.expected_type),
            )
            return

        imported_ids: list[str] = []
        errors: list[str] = []

        for payload in selected_payloads:
            parsed, _api_cat, err = self._parse_payload(payload)
            if err or not parsed:
                errors.append(f"{payload.get('slug') or payload.get('path')}: {err or 'parse failed'}")
                continue
            try:
                new_id = self.dm.import_entity_with_dependencies(parsed)
                imported_ids.append(new_id)
            except Exception as e:
                errors.append(f"{parsed.get('name', payload.get('slug', 'entry'))}: {e}")

        if imported_ids:
            self.parent_window.register_imported_ids(imported_ids)
            self.parent_window.entity_imported.emit()
            QMessageBox.information(
                self,
                tr("MSG_SUCCESS"),
                tr("MSG_IMPORT_BATCH_DONE", count=len(imported_ids)),
            )

        if errors:
            details = "\n".join(errors[:10])
            QMessageBox.warning(
                self,
                tr("MSG_WARNING"),
                tr("MSG_IMPORT_PARTIAL_ERRORS", details=details),
            )


class OnlineApiTab(QWidget):
    def __init__(self, data_manager, parent_window, default_category: str | None = None):
        super().__init__()
        self.dm = data_manager
        self.parent_window = parent_window
        self.default_category = default_category

        self.current_category = default_category or "Monster"
        self.current_page = 1
        self.next_page_url = None
        self.prev_page_url = None
        self.search_timer = QTimer()
        self.search_timer.setInterval(600)
        self.search_timer.setSingleShot(True)
        self.search_timer.timeout.connect(self.load_list)

        self.init_ui()
        self.refresh_categories()

    def init_ui(self):
        main_layout = QVBoxLayout(self)

        top = QHBoxLayout()
        self.combo_source = QComboBox()
        self.combo_source.setFixedWidth(150)
        for key, name in self.dm.api_client.get_available_sources():
            self.combo_source.addItem(name, key)
        curr = self.dm.api_client.current_source_key
        idx = self.combo_source.findData(curr)
        if idx >= 0:
            self.combo_source.setCurrentIndex(idx)
        self.combo_source.currentIndexChanged.connect(self.on_source_changed)

        self.combo_cat = QComboBox()
        self.combo_cat.setFixedWidth(150)
        self.combo_cat.currentIndexChanged.connect(self.on_category_changed)

        self.inp_search = QLineEdit()
        self.inp_search.setPlaceholderText(tr("LBL_SEARCH_API"))
        self.inp_search.textChanged.connect(lambda: self.search_timer.start())

        self.btn_bulk = QPushButton()
        self.btn_bulk.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_ArrowDown))
        self.btn_bulk.setToolTip(tr("BTN_DOWNLOAD_ALL"))
        self.btn_bulk.clicked.connect(lambda: BulkDownloadDialog(self).exec())

        top.addWidget(self.combo_source)
        top.addWidget(self.combo_cat)
        top.addWidget(self.inp_search, 1)
        top.addWidget(self.btn_bulk)
        main_layout.addLayout(top)

        splitter = QSplitter(Qt.Orientation.Horizontal)

        left_w = QWidget()
        left_l = QVBoxLayout(left_w)
        left_l.setContentsMargins(0, 0, 0, 0)

        self.list_widget = QListWidget()
        self.list_widget.setAlternatingRowColors(True)
        self.list_widget.setSelectionMode(QAbstractItemView.SelectionMode.ExtendedSelection)
        self.list_widget.itemClicked.connect(self.on_item_clicked)
        self.list_widget.itemSelectionChanged.connect(self._update_import_button)

        pag_l = QHBoxLayout()
        self.btn_prev = QPushButton()
        self.btn_prev.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_ArrowBack))
        self.btn_prev.setObjectName("compactBtn")
        self.btn_prev.setFixedSize(28, 28)
        self.btn_prev.clicked.connect(self.prev_page)
        self.lbl_page = QLabel("1")
        self.lbl_page.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.btn_next = QPushButton()
        self.btn_next.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_ArrowForward))
        self.btn_next.setObjectName("compactBtn")
        self.btn_next.setFixedSize(28, 28)
        self.btn_next.clicked.connect(self.next_page)
        pag_l.addWidget(self.btn_prev)
        pag_l.addWidget(self.lbl_page)
        pag_l.addWidget(self.btn_next)

        left_l.addWidget(self.list_widget)
        left_l.addLayout(pag_l)
        splitter.addWidget(left_w)

        right_w = QWidget()
        right_l = QVBoxLayout(right_w)
        right_l.setContentsMargins(5, 0, 0, 0)
        self.lbl_name = QLabel(tr("MSG_NO_SELECTION"))
        self.lbl_name.setObjectName("importTitle")
        self.txt_desc = QTextEdit()
        self.txt_desc.setReadOnly(True)

        self.btn_import = QPushButton(tr("BTN_IMPORT"))
        self.btn_import.setObjectName("successBtn")
        self.btn_import.setEnabled(False)
        self.btn_import.clicked.connect(self.import_selected)

        right_l.addWidget(self.lbl_name)
        right_l.addWidget(self.txt_desc)
        right_l.addWidget(self.btn_import)
        splitter.addWidget(right_w)
        splitter.setSizes([300, 500])
        main_layout.addWidget(splitter)

    def refresh_categories(self):
        self.combo_cat.blockSignals(True)
        self.combo_cat.clear()
        cats = self.dm.api_client.get_supported_categories()
        for cat in cats:
            t_key = f"CAT_{cat.upper().replace(' ', '_')}"
            translated = tr(t_key)
            self.combo_cat.addItem(translated if translated != t_key else cat, cat)

        selected_idx = -1
        if self.default_category:
            selected_idx = self.combo_cat.findData(self.default_category)
        if selected_idx < 0:
            selected_idx = self.combo_cat.findData(self.current_category)
        if selected_idx < 0:
            selected_idx = 0

        if selected_idx >= 0:
            self.combo_cat.setCurrentIndex(selected_idx)
            self.current_category = self.combo_cat.currentData()

        self.combo_cat.blockSignals(False)
        self.load_list()

    def on_source_changed(self):
        self.dm.api_client.set_source(self.combo_source.currentData())
        self.current_page = 1
        self.refresh_categories()

    def on_category_changed(self):
        self.current_category = self.combo_cat.currentData()
        self.current_page = 1
        self.load_list()

    def _update_import_button(self):
        selected_items = [
            item for item in self.list_widget.selectedItems()
            if item.data(Qt.ItemDataRole.UserRole)
        ]
        has_selection = bool(selected_items)
        allowed = self.parent_window.is_type_allowed(self.current_category)
        self.btn_import.setEnabled(has_selection and allowed)
        if has_selection and not allowed:
            self.btn_import.setToolTip(
                tr("MSG_IMPORT_TYPE_MISMATCH", type=self.parent_window.expected_type)
            )
        else:
            self.btn_import.setToolTip("")

    def load_list(self):
        self.list_widget.clear()
        self.lbl_name.setText(tr("MSG_LOADING"))
        self.txt_desc.clear()
        self.btn_import.setEnabled(False)
        self.setEnabled(False)

        filters = {"search": self.inp_search.text()} if self.inp_search.text() else None
        self.worker = ApiListWorker(self.dm, self.current_category, self.current_page, filters)
        self.worker.finished.connect(self.on_list_loaded)
        self.worker.start()

    def on_list_loaded(self, data):
        self.setEnabled(True)
        self.lbl_name.setText(tr("MSG_NO_SELECTION"))
        items = data.get("results", []) if isinstance(data, dict) else data
        self.next_page_url = data.get("next") if isinstance(data, dict) else None
        self.prev_page_url = data.get("previous") if isinstance(data, dict) else None

        self.btn_prev.setEnabled(bool(self.prev_page_url))
        self.btn_next.setEnabled(bool(self.next_page_url))
        self.lbl_page.setText(str(self.current_page))

        if not items:
            self.list_widget.addItem(tr("LBL_NO_RESULTS"))
            self._update_import_button()
            return

        for item_data in items:
            list_item = QListWidgetItem(item_data["name"])
            list_item.setData(Qt.ItemDataRole.UserRole, item_data["index"])
            self.list_widget.addItem(list_item)

        self._update_import_button()

    def prev_page(self):
        self.current_page -= 1
        self.load_list()

    def next_page(self):
        self.current_page += 1
        self.load_list()

    def on_item_clicked(self, item):
        idx = item.data(Qt.ItemDataRole.UserRole)
        if not idx:
            return

        self.lbl_name.setText(item.text() + "...")
        self.txt_desc.clear()

        success, msg, data_or_id = self.dm.fetch_from_api(self.current_category, idx)
        if not success:
            self.lbl_name.setText(tr("MSG_ERROR"))
            self.txt_desc.setText(msg or tr("LBL_FAILED_LOAD_DATA"))
            self._update_import_button()
            return

        data = self.dm.data["entities"].get(data_or_id) if isinstance(data_or_id, str) else data_or_id
        if not isinstance(data, dict):
            self.lbl_name.setText(tr("MSG_ERROR"))
            self.txt_desc.setText(tr("LBL_FAILED_LOAD_DATA"))
            self._update_import_button()
            return

        self.lbl_name.setText(data.get("name", tr("NAME_UNKNOWN")))
        src = data.get("source") or data.get("_meta_source", tr("NAME_UNKNOWN"))
        desc = data.get("description", tr("LBL_FAILED_LOAD_DATA"))
        self.txt_desc.setHtml(f"<b>{tr('LBL_SOURCE')}</b> {src}<br><hr>{desc}")
        self._update_import_button()

    def import_selected(self):
        if not self.parent_window.is_type_allowed(self.current_category):
            QMessageBox.warning(
                self,
                tr("MSG_WARNING"),
                tr("MSG_IMPORT_TYPE_MISMATCH", type=self.parent_window.expected_type),
            )
            return

        selected_items = [
            item for item in self.list_widget.selectedItems()
            if item.data(Qt.ItemDataRole.UserRole)
        ]
        if not selected_items:
            QMessageBox.warning(self, tr("MSG_WARNING"), tr("MSG_IMPORT_SELECT_FIRST"))
            return

        self.btn_import.setEnabled(False)
        self.btn_import.setText(tr("MSG_IMPORTING"))

        imported_ids: list[str] = []
        errors: list[str] = []

        for item in selected_items:
            idx = item.data(Qt.ItemDataRole.UserRole)
            success, msg, result = self.dm.fetch_from_api(self.current_category, idx)
            if not success:
                errors.append(f"{item.text()}: {msg}")
                continue

            try:
                if isinstance(result, str):
                    imported_ids.append(result)
                elif isinstance(result, dict):
                    new_id = self.dm.import_entity_with_dependencies(result)
                    imported_ids.append(new_id)
                else:
                    errors.append(f"{item.text()}: invalid payload")
            except Exception as e:
                errors.append(f"{item.text()}: {e}")

        if imported_ids:
            self.parent_window.register_imported_ids(imported_ids)
            self.parent_window.entity_imported.emit()
            QMessageBox.information(
                self,
                tr("MSG_SUCCESS"),
                tr("MSG_IMPORT_BATCH_DONE", count=len(imported_ids)),
            )

        if errors:
            details = "\n".join(errors[:10])
            QMessageBox.warning(
                self,
                tr("MSG_WARNING"),
                tr("MSG_IMPORT_PARTIAL_ERRORS", details=details),
            )

        self.btn_import.setText(tr("BTN_IMPORT"))
        self._update_import_button()


class ImportWindow(QDialog):
    entity_imported = pyqtSignal()
    entities_imported = pyqtSignal(list)

    def __init__(
        self,
        data_manager,
        parent=None,
        selection_mode: bool = False,
        default_category: str | None = None,
        expected_type: str | None = None,
    ):
        super().__init__(parent)
        self.setWindowTitle(tr("TITLE_IMPORT_CENTER"))
        self.resize(1000, 700)

        self.selection_mode = selection_mode
        self.selected_id = None
        self.default_category = default_category
        self.expected_type = expected_type
        self.imported_entity_ids: list[str] = []

        layout = QVBoxLayout(self)
        self.tabs = QTabWidget()

        self.tab_online = OnlineApiTab(data_manager, self, default_category=default_category)
        self.tab_local = LocalLibraryTab(data_manager, self)
        self.tab_file = QWidget()

        self.tabs.addTab(self.tab_online, tr("TAB_API_SEARCH"))
        self.tabs.addTab(self.tab_local, tr("TAB_LOCAL_LIB"))
        self.tabs.addTab(self.tab_file, tr("TAB_FILE_IMPORT"))

        layout.addWidget(self.tabs)

        if self.selection_mode:
            actions = QHBoxLayout()
            actions.addStretch()
            self.btn_done = QPushButton(tr("BTN_DONE"))
            self.btn_done.setEnabled(False)
            self.btn_done.clicked.connect(self.accept)
            self.btn_close = QPushButton(tr("BTN_CLOSE"))
            self.btn_close.clicked.connect(self.reject)
            actions.addWidget(self.btn_done)
            actions.addWidget(self.btn_close)
            layout.addLayout(actions)

    def is_type_allowed(self, category_or_type: str | None) -> bool:
        if not self.expected_type:
            return True
        resolved = resolve_entity_type(category_or_type)
        return resolved == self.expected_type

    def register_imported_ids(self, ids: list[str]) -> None:
        new_ids = []
        for eid in ids:
            if eid and eid not in self.imported_entity_ids:
                self.imported_entity_ids.append(eid)
                new_ids.append(eid)

        if new_ids:
            self.entities_imported.emit(new_ids)

        if self.selection_mode and hasattr(self, "btn_done"):
            if self.imported_entity_ids:
                self.btn_done.setEnabled(True)
                self.btn_done.setText(f"{tr('BTN_DONE')} ({len(self.imported_entity_ids)})")
            else:
                self.btn_done.setEnabled(False)
                self.btn_done.setText(tr("BTN_DONE"))
