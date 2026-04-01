"""Shared helpers for NpcSheet tab widgets.

Provides module-level functions used by multiple tab widgets so they
don't need to duplicate them or depend on the parent NpcSheet.
"""

from PyQt6.QtWidgets import (
    QFrame,
    QGroupBox,
    QHBoxLayout,
    QLineEdit,
    QPushButton,
    QSizePolicy,
    QVBoxLayout,
    QStyle,
    QApplication,
)

from core.locales import tr
from ui.widgets.markdown_editor import MarkdownEditor


def make_section(title: str) -> QGroupBox:
    """Create a QGroupBox with a dynamic_area QVBoxLayout inside it."""
    group = QGroupBox(title)
    group.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Maximum)
    v = QVBoxLayout(group)
    group.dynamic_area = QVBoxLayout()
    v.addLayout(group.dynamic_area)
    return group


def add_section_button(section: QGroupBox, label: str, callback, btn_list: list) -> QPushButton:
    """Prepend an 'Add' button to *section* and append it to *btn_list*."""
    btn = QPushButton(label)
    btn.clicked.connect(callback)
    btn.setObjectName("successBtn")
    section.layout().insertWidget(0, btn)
    btn_list.append(btn)
    return btn


def create_feature_card(
    group: QGroupBox,
    dm,
    dirty_cb,
    open_entity_cb,
    is_embedded: bool = False,
    name: str = "",
    desc: str = "",
    ph_title: str | None = None,
    ph_desc: str | None = None,
):
    """Build and insert a feature card (title + description) into *group*.

    Returns the card QFrame with attributes:
      card.inp_title  — QLineEdit
      card.inp_desc   — MarkdownEditor
      card.btn_del    — QPushButton
    """
    dirty_cb()

    if ph_title is None:
        ph_title = tr("LBL_TITLE_PH")
    if ph_desc is None:
        ph_desc = tr("LBL_DETAILS_PH")

    desc_min_height = 88

    card = QFrame()
    card.setProperty("class", "featureCard")
    layout = QVBoxLayout(card)

    h_header = QHBoxLayout()
    t = QLineEdit(name)
    t.setPlaceholderText(ph_title)
    t.setObjectName("featureCardTitle")
    t.textChanged.connect(dirty_cb)

    _style = QApplication.style()
    btn_del = QPushButton()
    btn_del.setFixedSize(24, 24)
    btn_del.setIcon(_style.standardIcon(QStyle.StandardPixmap.SP_TitleBarCloseButton))
    btn_del.setStyleSheet("background: transparent; border: none;")
    btn_del.clicked.connect(
        lambda: [
            group.dynamic_area.removeWidget(card),
            card.deleteLater(),
            dirty_cb(),
        ]
    )

    h_header.addWidget(t)
    h_header.addWidget(btn_del)
    layout.addLayout(h_header)

    d = MarkdownEditor(text=desc)
    d.set_data_manager(dm)
    d.set_toggle_button_visible(False)
    d.entity_link_clicked.connect(open_entity_cb)
    d.setPlaceholderText(ph_desc)
    d.setMinimumHeight(desc_min_height)
    d.textChanged.connect(dirty_cb)

    if is_embedded:
        d.set_transparent_mode(True)

    layout.addWidget(d)
    group.dynamic_area.addWidget(card)
    card.inp_title = t
    card.inp_desc = d
    card.btn_del = btn_del
    return card


def clear_section(section: QGroupBox) -> None:
    """Remove and delete all widgets from section.dynamic_area."""
    while section.dynamic_area.count():
        item = section.dynamic_area.takeAt(0)
        if item.widget():
            item.widget().deleteLater()
