"""Combat table widgets — DraggableCombatTable and cell-level helpers.

These classes were extracted from combat_tracker.py to keep each file
focused on a single responsibility.

Classes:
    DraggableCombatTable    -- QTableWidget that accepts entity drops.
    ConditionIcon           -- 24×24 painted condition badge with right-click menu.
    ConditionsWidget        -- Row of ConditionIcon badges for one combatant.
    HpBarWidget             -- +/- HP bar for one combatant row.
    NumericTableWidgetItem  -- QTableWidgetItem with numeric sort order.
    MapSelectorDialog       -- Dialog for picking a battle-map image or importing one.
"""

import logging
import os

from PyQt6.QtCore import QRect, QSize, Qt, pyqtSignal
from PyQt6.QtGui import QAction, QBrush, QColor, QIcon, QPainter, QPainterPath, QPixmap
from PyQt6.QtWidgets import (
    QDialog,
    QHBoxLayout,
    QLabel,
    QListWidget,
    QListWidgetItem,
    QMenu,
    QMessageBox,
    QProgressBar,
    QPushButton,
    QStyle,
    QTableWidget,
    QTableWidgetItem,
    QVBoxLayout,
    QWidget,
)

from core.locales import tr
from core.theme_manager import ThemeManager

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# DraggableCombatTable
# ---------------------------------------------------------------------------

class DraggableCombatTable(QTableWidget):
    """QTableWidget subclass that accepts dragged entity IDs from the sidebar."""

    entity_dropped = pyqtSignal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setAcceptDrops(True)

    def dragEnterEvent(self, event):
        if event.mimeData().hasText():
            event.acceptProposedAction()
        else:
            super().dragEnterEvent(event)

    def dragMoveEvent(self, event):
        event.acceptProposedAction()

    def dropEvent(self, event):
        eid = event.mimeData().text()
        self.entity_dropped.emit(eid)
        event.acceptProposedAction()


# ---------------------------------------------------------------------------
# ConditionIcon
# ---------------------------------------------------------------------------

class ConditionIcon(QWidget):
    """24×24 round badge for a single condition on a combatant."""

    removed = pyqtSignal(str)

    def __init__(self, name, icon_path, duration=0, max_duration=0, palette=None):
        super().__init__()
        self.name = name
        self.icon_path = icon_path
        self.duration = int(duration)
        self.max_duration = int(max_duration)
        self.current_palette = palette if palette else ThemeManager.get_palette("dark")

        self.setFixedSize(24, 24)
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setToolTip(f"{name} ({self.duration}/{self.max_duration} Turns)")

    def update_theme(self, palette):
        self.current_palette = palette
        self.update()

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        path = QPainterPath()
        path.addEllipse(1, 1, 22, 22)
        painter.setClipPath(path)

        if self.icon_path and os.path.exists(self.icon_path):
            painter.drawPixmap(0, 0, 24, 24, QPixmap(self.icon_path))
        else:
            bg_color = self.current_palette.get("condition_default_bg", "#5c6bc0")
            txt_color = self.current_palette.get("condition_text", "#ffffff")
            painter.setBrush(QBrush(QColor(bg_color)))
            painter.drawRect(0, 0, 24, 24)
            painter.setPen(QColor(txt_color))
            font = painter.font()
            font.setPixelSize(10)
            font.setBold(True)
            painter.setFont(font)
            painter.drawText(
                QRect(0, 0, 24, 24),
                Qt.AlignmentFlag.AlignCenter,
                self.name[:2].upper(),
            )

        if self.max_duration > 0:
            dur_bg = self.current_palette.get(
                "condition_duration_bg", "rgba(0, 0, 0, 200)"
            )
            painter.setClipping(False)
            painter.setBrush(QBrush(QColor(dur_bg)))
            painter.setPen(Qt.PenStyle.NoPen)
            painter.drawRoundedRect(0, 14, 24, 10, 2, 2)
            painter.setPen(Qt.GlobalColor.white)
            font = painter.font()
            font.setPixelSize(8)
            font.setBold(True)
            painter.setFont(font)
            painter.drawText(
                QRect(0, 14, 24, 10),
                Qt.AlignmentFlag.AlignCenter,
                f"{self.duration}",
            )

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.RightButton:
            menu = QMenu(self)
            p = self.current_palette
            menu.setStyleSheet(
                f"QMenu {{ background-color: {p.get('ui_floating_bg', '#333')}; "
                f"color: {p.get('ui_floating_text', '#eee')}; "
                f"border: 1px solid {p.get('ui_floating_border', '#555')}; }}"
            )
            del_act = QAction("❌ " + tr("MENU_REMOVE_CONDITION"), self)
            del_act.triggered.connect(lambda: self.removed.emit(self.name))
            menu.addAction(del_act)
            menu.exec(event.globalPos())


# ---------------------------------------------------------------------------
# ConditionsWidget
# ---------------------------------------------------------------------------

class ConditionsWidget(QWidget):
    """Row of ConditionIcon badges for a single combatant table row."""

    conditionsChanged = pyqtSignal()
    conditionRemoved = pyqtSignal(str)
    clicked = pyqtSignal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self.layout = QHBoxLayout(self)
        self.layout.setContentsMargins(2, 2, 2, 2)
        self.layout.setSpacing(2)
        self.layout.addStretch()
        self.active_conditions: list[dict] = []
        self.current_palette = ThemeManager.get_palette("dark")
        self.setCursor(Qt.CursorShape.PointingHandCursor)

    def update_theme(self, palette):
        self.current_palette = palette
        for i in range(self.layout.count()):
            item = self.layout.itemAt(i)
            if item.widget() and isinstance(item.widget(), ConditionIcon):
                item.widget().update_theme(palette)

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            if not isinstance(self.childAt(event.pos()), ConditionIcon):
                self.clicked.emit()
        super().mousePressEvent(event)

    def set_conditions(self, conditions_list: list[dict]) -> None:
        while self.layout.count() > 1:
            item = self.layout.takeAt(1)
            if item.widget():
                item.widget().deleteLater()
        self.active_conditions = conditions_list
        for cond in conditions_list:
            icon_widget = ConditionIcon(
                cond["name"],
                cond.get("icon"),
                cond.get("duration"),
                cond.get("max_duration"),
                self.current_palette,
            )
            icon_widget.removed.connect(self.remove_condition)
            self.layout.addWidget(icon_widget)

    def add_condition(self, name: str, icon_path: str | None, max_turns: int) -> None:
        for c in self.active_conditions:
            if c["name"] == name:
                c["duration"] = max_turns
                c["max_duration"] = max_turns
                self.set_conditions(self.active_conditions)
                self.conditionsChanged.emit()
                return
        self.active_conditions.append(
            {
                "name": name,
                "icon": icon_path,
                "duration": max_turns,
                "max_duration": max_turns,
            }
        )
        self.set_conditions(self.active_conditions)
        self.conditionsChanged.emit()

    def remove_condition(self, name: str) -> None:
        self.active_conditions = [
            c for c in self.active_conditions if c["name"] != name
        ]
        self.set_conditions(self.active_conditions)
        self.conditionsChanged.emit()
        self.conditionRemoved.emit(name)

    def tick_conditions(self) -> None:
        remaining = []
        for c in self.active_conditions:
            if c["max_duration"] > 0:
                c["duration"] -= 1
                if c["duration"] > 0:
                    remaining.append(c)
            else:
                remaining.append(c)
        self.active_conditions = remaining
        self.set_conditions(self.active_conditions)
        self.conditionsChanged.emit()


# ---------------------------------------------------------------------------
# HpBarWidget
# ---------------------------------------------------------------------------

class HpBarWidget(QWidget):
    """Interactive HP progress bar with +/- buttons."""

    hpChanged = pyqtSignal(int)

    def __init__(self, current_hp, max_hp, palette=None):
        super().__init__()
        self.current_palette = palette if palette else ThemeManager.get_palette("dark")
        self.current = int(current_hp)
        self.max_val = int(max_hp) if int(max_hp) > 0 else 1

        l = QHBoxLayout(self)
        l.setContentsMargins(0, 2, 0, 2)
        l.setSpacing(2)

        b_m = QPushButton("-")
        b_m.setFixedSize(20, 20)
        b_m.setCursor(Qt.CursorShape.PointingHandCursor)
        dec_bg = self.current_palette.get("hp_btn_decrease_bg", "#c62828")
        dec_hov = self.current_palette.get("hp_btn_decrease_hover", "#d32f2f")
        b_m.setStyleSheet(
            f"QPushButton {{ background-color: {dec_bg}; color: white; border: none;"
            f" border-radius: 3px; font-weight: bold; }}"
            f"QPushButton:hover {{ background-color: {dec_hov}; }}"
        )
        b_m.clicked.connect(self.decrease_hp)

        self.bar = QProgressBar()
        self.bar.setRange(0, self.max_val)
        self.bar.setValue(self.current)
        self.bar.setTextVisible(True)
        self.bar.setFormat(f"%v / {self.max_val}")
        self.bar.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.update_color()

        b_p = QPushButton("+")
        b_p.setFixedSize(20, 20)
        b_p.setCursor(Qt.CursorShape.PointingHandCursor)
        inc_bg = self.current_palette.get("hp_btn_increase_bg", "#2e7d32")
        inc_hov = self.current_palette.get("hp_btn_increase_hover", "#388e3c")
        b_p.setStyleSheet(
            f"QPushButton {{ background-color: {inc_bg}; color: white; border: none;"
            f" border-radius: 3px; font-weight: bold; }}"
            f"QPushButton:hover {{ background-color: {inc_hov}; }}"
        )
        b_p.clicked.connect(self.increase_hp)

        l.addWidget(b_m)
        l.addWidget(self.bar, 1)
        l.addWidget(b_p)

    def update_theme(self, palette):
        self.current_palette = palette
        self.update_color()

    def update_color(self) -> None:
        r = self.current / self.max_val if self.max_val > 0 else 0
        p = self.current_palette
        if r > 0.5:
            c = p.get("hp_bar_high", "#2e7d32")
        elif r > 0.2:
            c = p.get("hp_bar_med", "#fbc02d")
        else:
            c = p.get("hp_bar_low", "#c62828")
        bg = p.get("hp_widget_bg", "rgba(0,0,0,0.3)")
        border = p.get("ui_floating_border", "#555")
        self.bar.setStyleSheet(
            f"QProgressBar::chunk {{ background-color: {c}; }} "
            f"QProgressBar {{ color: white; border: 1px solid {border}; "
            f"border-radius: 3px; background: {bg}; }}"
        )

    def update_hp(self, new_hp: int) -> None:
        self.current = int(new_hp)
        self.bar.setValue(self.current)
        self.bar.setFormat(f"{self.current} / {self.max_val}")
        self.update_color()
        self.hpChanged.emit(self.current)

    def decrease_hp(self) -> None:
        self.update_hp(self.current - 1)

    def increase_hp(self) -> None:
        self.update_hp(self.current + 1)


# ---------------------------------------------------------------------------
# NumericTableWidgetItem
# ---------------------------------------------------------------------------

class NumericTableWidgetItem(QTableWidgetItem):
    """QTableWidgetItem that sorts numerically instead of lexicographically."""

    def __lt__(self, other):
        try:
            return float(self.data(Qt.ItemDataRole.DisplayRole)) < float(
                other.data(Qt.ItemDataRole.DisplayRole)
            )
        except (ValueError, TypeError):
            return super().__lt__(other)


# ---------------------------------------------------------------------------
# MapSelectorDialog
# ---------------------------------------------------------------------------

class MapSelectorDialog(QDialog):
    """Dialog for choosing an existing battle-map or importing a new one."""

    def __init__(self, data_manager, parent=None):
        super().__init__(parent)
        self.dm = data_manager
        self.selected_file: str | None = None
        self.is_new_import: bool = False

        self.setWindowTitle(tr("TITLE_MAP_SELECTOR"))
        self.setFixedSize(650, 550)
        self._init_ui()
        self._load_locations()

    def _init_ui(self):
        l = QVBoxLayout(self)
        lbl = QLabel(tr("LBL_SAVED_MAPS"))
        lbl.setObjectName("toolbarLabel")
        l.addWidget(lbl)

        self.lw = QListWidget()
        self.lw.setViewMode(QListWidget.ViewMode.IconMode)
        self.lw.setIconSize(QSize(160, 160))
        self.lw.setResizeMode(QListWidget.ResizeMode.Adjust)
        self.lw.setSpacing(10)
        self.lw.setProperty("class", "iconList")
        self.lw.itemDoubleClicked.connect(self._select_existing)
        l.addWidget(self.lw)

        h = QHBoxLayout()
        b1 = QPushButton(tr("BTN_IMPORT_NEW_MAP"))
        b1.setObjectName("successBtn")
        b1.clicked.connect(self._select_new)

        b2 = QPushButton(tr("BTN_OPEN_SELECTED_MAP"))
        b2.setObjectName("primaryBtn")
        b2.clicked.connect(self._select_existing)

        h.addWidget(b1)
        h.addStretch()
        h.addWidget(b2)
        l.addLayout(h)

    def _load_locations(self):
        self.lw.clear()
        for eid, ent in self.dm.data["entities"].items():
            if ent.get("type") != "Location":
                continue
            loc_name = ent.get("name", "Unknown Location")
            battlemaps = ent.get("battlemaps", [])
            if not battlemaps and ent.get("image_path"):
                battlemaps = [ent["image_path"]]
            elif not battlemaps and ent.get("images"):
                battlemaps = [ent["images"][0]]
            if not battlemaps:
                continue
            for i, img_path in enumerate(battlemaps):
                if not img_path:
                    continue
                if img_path.startswith("http") or img_path.endswith(
                    (".mp4", ".webm", ".mkv", ".avi")
                ):
                    icon = self.style().standardIcon(
                        QStyle.StandardPixmap.SP_MediaPlay
                    )
                    display_name = f"{loc_name} (VIDEO {i + 1})"
                    item = QListWidgetItem(icon, display_name)
                    item.setData(Qt.ItemDataRole.UserRole, img_path)
                    item.setToolTip(img_path)
                    self.lw.addItem(item)
                else:
                    full_path = self.dm.get_full_path(img_path)
                    if not full_path or not os.path.exists(full_path):
                        continue
                    display_name = (
                        f"{loc_name} ({i + 1})" if len(battlemaps) > 1 else loc_name
                    )
                    pix = QPixmap(full_path).scaled(
                        160, 160,
                        Qt.AspectRatioMode.KeepAspectRatio,
                        Qt.TransformationMode.SmoothTransformation,
                    )
                    icon = QIcon(pix)
                    item = QListWidgetItem(icon, display_name)
                    item.setData(Qt.ItemDataRole.UserRole, img_path)
                    item.setToolTip(f"{loc_name} - Map {i + 1}")
                    self.lw.addItem(item)

    def _select_existing(self):
        current = self.lw.currentItem()
        if not current:
            QMessageBox.warning(self, tr("MSG_WARNING"), tr("MSG_SELECT_MAP_FROM_LIST"))
            return
        self.selected_file = current.data(Qt.ItemDataRole.UserRole)
        self.accept()

    def _select_new(self):
        self.is_new_import = True
        self.accept()
