from PyQt6.QtWidgets import QGraphicsView, QGraphicsScene, QGraphicsPixmapItem
from PyQt6.QtGui import QPainter, QWheelEvent
from PyQt6.QtCore import Qt, pyqtSignal

class ImageViewer(QGraphicsView):
    # Emitted after any zoom or pan; carries (transform, h_scroll, v_scroll)
    view_changed = pyqtSignal(object, int, int)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.scene = QGraphicsScene(self)
        self.setScene(self.scene)

        # High-quality render settings
        self.setRenderHint(QPainter.RenderHint.Antialiasing)
        self.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform)

        # Pan / Scroll
        self.setDragMode(QGraphicsView.DragMode.ScrollHandDrag)
        self.setTransformationAnchor(QGraphicsView.ViewportAnchor.AnchorUnderMouse)
        self.setResizeAnchor(QGraphicsView.ViewportAnchor.AnchorUnderMouse)

        # Background (black / dark)
        self.setStyleSheet("background-color: #000; border: none;")
        self.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)

        self.pixmap_item = None
        self._syncing = False

        self.horizontalScrollBar().valueChanged.connect(self._emit_view_changed)
        self.verticalScrollBar().valueChanged.connect(self._emit_view_changed)

    def set_image(self, pixmap):
        """Initial setup: Loads image and fits to view."""
        self.scene.clear()
        if pixmap and not pixmap.isNull():
            self.pixmap_item = QGraphicsPixmapItem(pixmap)
            self.pixmap_item.setTransformationMode(Qt.TransformationMode.SmoothTransformation)
            self.scene.addItem(self.pixmap_item)
            self.setSceneRect(self.pixmap_item.boundingRect())
            self.fitInView(self.pixmap_item, Qt.AspectRatioMode.KeepAspectRatio)
        else:
            self.pixmap_item = None

    def update_pixmap(self, pixmap):
        """Updates the image content WITHOUT resetting zoom/pan."""
        if self.pixmap_item and pixmap and not pixmap.isNull():
            self.pixmap_item.setPixmap(pixmap)
        else:
            self.set_image(pixmap)

    def wheelEvent(self, event: QWheelEvent):
        zoom_in_factor = 1.15
        zoom_out_factor = 1 / zoom_in_factor
        if event.angleDelta().y() > 0:
            self.scale(zoom_in_factor, zoom_in_factor)
        else:
            self.scale(zoom_out_factor, zoom_out_factor)
        self._emit_view_changed()

    def _emit_view_changed(self):
        if not self._syncing:
            self.view_changed.emit(
                self.transform(),
                self.horizontalScrollBar().value(),
                self.verticalScrollBar().value(),
            )

    def apply_view_state(self, transform, h_scroll, v_scroll):
        """Apply an external view state (transform + scroll) without re-emitting."""
        self._syncing = True
        self.setTransform(transform)
        self.horizontalScrollBar().setValue(h_scroll)
        self.verticalScrollBar().setValue(v_scroll)
        self._syncing = False
