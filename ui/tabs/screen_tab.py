import os

from PyQt6.QtWidgets import (
    QFileDialog,
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QListWidget,
    QPushButton,
    QVBoxLayout,
    QWidget,
)
from PyQt6.QtCore import Qt

from core.locales import tr


class ScreenTab(QWidget):
    """DM control panel for the unified PlayerWindow.

    Lets the DM:
    - Switch the player window between Image Screen and Battle Map views
    - Choose the image layout (Single / Side-by-Side / 2×2 Grid)
    - Manage the projection list (add, reorder, remove images)
    - Toggle a black screen overlay
    - Clear all projections
    """

    def __init__(self, player_window, data_manager):
        super().__init__()
        self._pw = player_window
        self._dm = data_manager

        # Sync projection list whenever images change on the player window
        player_window.projection_changed.connect(self.refresh_projection_list)

        self.init_ui()

    # ------------------------------------------------------------------
    # UI construction
    # ------------------------------------------------------------------

    def init_ui(self):
        main_layout = QVBoxLayout(self)
        main_layout.setContentsMargins(10, 10, 10, 10)
        main_layout.setSpacing(10)

        # --- View switcher ---
        view_group = QGroupBox(tr("BTN_PLAYER_SCREEN"))
        view_layout = QHBoxLayout(view_group)
        view_layout.setSpacing(6)

        self.btn_image_mode = QPushButton(tr("BTN_IMAGE_MODE"))
        self.btn_image_mode.setObjectName("primaryBtn")
        self.btn_image_mode.setCheckable(True)
        self.btn_image_mode.setChecked(True)
        self.btn_image_mode.clicked.connect(self._on_image_mode)

        self.btn_battle_mode = QPushButton(tr("BTN_BATTLE_MAP_MODE"))
        self.btn_battle_mode.setObjectName("primaryBtn")
        self.btn_battle_mode.setCheckable(True)
        self.btn_battle_mode.clicked.connect(self._on_battle_mode)

        view_layout.addWidget(self.btn_image_mode)
        view_layout.addWidget(self.btn_battle_mode)
        view_layout.addStretch()

        self.btn_black = QPushButton(tr("BTN_BLACK_SCREEN"))
        self.btn_black.setObjectName("dangerBtn")
        self.btn_black.setCheckable(True)
        self.btn_black.toggled.connect(self._pw.set_black_screen)
        view_layout.addWidget(self.btn_black)

        main_layout.addWidget(view_group)

        # --- Image layout selector ---
        layout_group = QGroupBox(tr("LBL_PROJECTIONS"))
        layout_outer = QVBoxLayout(layout_group)

        layout_row = QHBoxLayout()
        layout_row.setSpacing(4)

        lbl_layout = QLabel("Layout:")
        lbl_layout.setFixedWidth(50)
        layout_row.addWidget(lbl_layout)

        self.btn_single = QPushButton(tr("LBL_LAYOUT_SINGLE"))
        self.btn_single.setCheckable(True)
        self.btn_single.clicked.connect(lambda: self._set_layout("single"))

        self.btn_side = QPushButton(tr("LBL_LAYOUT_SIDE"))
        self.btn_side.setCheckable(True)
        self.btn_side.setChecked(True)
        self.btn_side.clicked.connect(lambda: self._set_layout("side_by_side"))

        self.btn_grid = QPushButton(tr("LBL_LAYOUT_GRID"))
        self.btn_grid.setCheckable(True)
        self.btn_grid.clicked.connect(lambda: self._set_layout("grid"))

        self._layout_btns = [self.btn_single, self.btn_side, self.btn_grid]
        for b in self._layout_btns:
            layout_row.addWidget(b)
        layout_row.addStretch()
        layout_outer.addLayout(layout_row)

        # Projection list
        self.list_projections = QListWidget()
        self.list_projections.setMaximumHeight(160)
        layout_outer.addWidget(self.list_projections)

        # Projection action buttons
        proj_btns = QHBoxLayout()

        self.btn_add = QPushButton(tr("BTN_ADD_IMAGE"))
        self.btn_add.setObjectName("successBtn")
        self.btn_add.clicked.connect(self._on_add_image)

        self.btn_move_up = QPushButton("↑")
        self.btn_move_up.setFixedWidth(32)
        self.btn_move_up.clicked.connect(self._on_move_up)

        self.btn_move_down = QPushButton("↓")
        self.btn_move_down.setFixedWidth(32)
        self.btn_move_down.clicked.connect(self._on_move_down)

        self.btn_remove = QPushButton(tr("BTN_REMOVE"))
        self.btn_remove.setObjectName("dangerBtn")
        self.btn_remove.clicked.connect(self._on_remove)

        self.btn_clear = QPushButton(tr("BTN_CLEAR_ALL"))
        self.btn_clear.setObjectName("dangerBtn")
        self.btn_clear.clicked.connect(self._on_clear_all)

        proj_btns.addWidget(self.btn_add)
        proj_btns.addWidget(self.btn_move_up)
        proj_btns.addWidget(self.btn_move_down)
        proj_btns.addWidget(self.btn_remove)
        proj_btns.addStretch()
        proj_btns.addWidget(self.btn_clear)
        layout_outer.addLayout(proj_btns)

        main_layout.addWidget(layout_group)

        # --- Battle Map note ---
        battle_group = QGroupBox(tr("BTN_BATTLE_MAP_MODE"))
        battle_layout = QVBoxLayout(battle_group)
        battle_note = QLabel(
            "Battle Map is controlled from the Session tab.\n"
            'Use the "Show Battle Map" button there to switch view.'
        )
        battle_note.setWordWrap(True)
        battle_note.setStyleSheet("color: #aaa; font-style: italic;")
        battle_layout.addWidget(battle_note)
        main_layout.addWidget(battle_group)

        main_layout.addStretch()

    # ------------------------------------------------------------------
    # Projection list sync
    # ------------------------------------------------------------------

    def refresh_projection_list(self):
        """Rebuild the list widget from the player window's active image paths."""
        current_row = self.list_projections.currentRow()
        self.list_projections.clear()
        for path in self._pw.active_image_paths:
            self.list_projections.addItem(os.path.basename(path))
        if 0 <= current_row < self.list_projections.count():
            self.list_projections.setCurrentRow(current_row)

    # ------------------------------------------------------------------
    # View switcher
    # ------------------------------------------------------------------

    def _on_image_mode(self):
        self.btn_image_mode.setChecked(True)
        self.btn_battle_mode.setChecked(False)
        self._pw.set_active_view("images")

    def _on_battle_mode(self):
        self.btn_battle_mode.setChecked(True)
        self.btn_image_mode.setChecked(False)
        self._pw.set_active_view("battlemap")

    # ------------------------------------------------------------------
    # Layout selector
    # ------------------------------------------------------------------

    def _set_layout(self, mode: str):
        mode_map = {"single": 0, "side_by_side": 1, "grid": 2}
        for i, btn in enumerate(self._layout_btns):
            btn.setChecked(list(mode_map.keys())[i] == mode)
        self._pw.set_image_layout(mode)

    # ------------------------------------------------------------------
    # Projection actions
    # ------------------------------------------------------------------

    def _on_add_image(self):
        paths, _ = QFileDialog.getOpenFileNames(
            self,
            tr("BTN_ADD_IMAGE"),
            "",
            "Images (*.png *.jpg *.jpeg *.bmp *.webp)",
        )
        for path in paths:
            self._pw.add_image_to_view(path)

    def _on_remove(self):
        row = self.list_projections.currentRow()
        if 0 <= row < len(self._pw.active_image_paths):
            path = self._pw.active_image_paths[row]
            self._pw.remove_image_from_view(path)

    def _on_move_up(self):
        row = self.list_projections.currentRow()
        if row <= 0:
            return
        self._swap_images(row, row - 1)
        self.list_projections.setCurrentRow(row - 1)

    def _on_move_down(self):
        row = self.list_projections.currentRow()
        if row < 0 or row >= len(self._pw.active_image_paths) - 1:
            return
        self._swap_images(row, row + 1)
        self.list_projections.setCurrentRow(row + 1)

    def _swap_images(self, i: int, j: int):
        """Swap two images in the player window's lists and rebuild."""
        pw = self._pw
        pw.active_image_paths[i], pw.active_image_paths[j] = (
            pw.active_image_paths[j],
            pw.active_image_paths[i],
        )
        pw.active_viewers[i], pw.active_viewers[j] = (
            pw.active_viewers[j],
            pw.active_viewers[i],
        )
        pw._rebuild_image_page()
        self.refresh_projection_list()

    def _on_clear_all(self):
        self._pw.clear_images()

    # ------------------------------------------------------------------
    # Retranslation
    # ------------------------------------------------------------------

    def retranslate_ui(self):
        self.btn_image_mode.setText(tr("BTN_IMAGE_MODE"))
        self.btn_battle_mode.setText(tr("BTN_BATTLE_MAP_MODE"))
        self.btn_black.setText(tr("BTN_BLACK_SCREEN"))
        self.btn_single.setText(tr("LBL_LAYOUT_SINGLE"))
        self.btn_side.setText(tr("LBL_LAYOUT_SIDE"))
        self.btn_grid.setText(tr("LBL_LAYOUT_GRID"))
        self.btn_add.setText(tr("BTN_ADD_IMAGE"))
        self.btn_remove.setText(tr("BTN_REMOVE"))
        self.btn_clear.setText(tr("BTN_CLEAR_ALL"))
