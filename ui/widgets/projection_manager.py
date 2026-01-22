import os
from PyQt6.QtWidgets import (QWidget, QHBoxLayout, QLabel, QFrame, QVBoxLayout)
from PyQt6.QtGui import QPixmap
from PyQt6.QtCore import Qt, pyqtSignal
from core.locales import tr
from core.theme_manager import ThemeManager

class ProjectionThumbnail(QFrame):
    """Small thumbnail for the header toolbar."""
    remove_requested = pyqtSignal(str)

    def __init__(self, image_path, pixmap=None, parent=None):
        super().__init__(parent)
        self.image_path = image_path
        self._is_map = False # Durum takibi için
        self.current_palette = ThemeManager.get_palette("dark") # Varsayılan

        # Small size to fit in header
        self.setFixedSize(50, 36)
        
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)
        
        self.lbl_img = QLabel()
        self.lbl_img.setAlignment(Qt.AlignmentFlag.AlignCenter)
        
        # İçeriği güncelle
        self.update_thumbnail(image_path, pixmap)
            
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setToolTip(tr("TIP_REMOVE_PROJECTION"))
        layout.addWidget(self.lbl_img)
        
        # İlk stil ataması (Daha sonra ebeveyn tarafından update_theme ile güncellenebilir)
        self.apply_style()

    def update_theme(self, palette):
        """Dışarıdan tema değişikliği geldiğinde çağrılır."""
        self.current_palette = palette
        self.apply_style()
        # Yazı rengini tekrar uygula (çünkü o da temaya bağlı)
        self._apply_text_color()

    def apply_style(self):
        p = self.current_palette
        bg = p.get("ui_thumbnail_bg", "#333")
        border = p.get("ui_thumbnail_border", "#555")
        
        # Theme compatible hover border
        hover_border = p.get("ui_thumbnail_hover_border_remove", "#ff5555")

        self.setStyleSheet(f"""
            QFrame {{ 
                background-color: {bg}; 
                border: 1px solid {border}; 
                border-radius: 4px; 
            }}
            QFrame:hover {{
                border-color: {hover_border};
            }}
        """)

    def update_thumbnail(self, image_path, pixmap):
        filename = os.path.basename(image_path)
        
        # Harita kontrolü (İster dosya olsun ister hafıza objesi)
        if "map_snapshot" in filename or "Live_Map" in filename:
            self._is_map = True
            self.lbl_img.setText(tr("LBL_MAP_THUMB"))
            self.lbl_img.setPixmap(QPixmap()) # Pixmap varsa temizle
        
        elif pixmap:
            self._is_map = False
            # Hafızadan gelen resim varsa direkt kullan
            scaled = pixmap.scaled(48, 34, Qt.AspectRatioMode.KeepAspectRatio, Qt.TransformationMode.SmoothTransformation)
            self.lbl_img.setPixmap(scaled)
            
        elif os.path.exists(image_path):
            self._is_map = False
            # Dosyadan oku
            pix = QPixmap(image_path).scaled(48, 34, Qt.AspectRatioMode.KeepAspectRatio, Qt.TransformationMode.SmoothTransformation)
            self.lbl_img.setPixmap(pix)
        else:
            self._is_map = False
            self.lbl_img.setText("?")
            self.lbl_img.setPixmap(QPixmap())

        self._apply_text_color()

    def _apply_text_color(self):
        """Duruma göre (Map/Bilinmeyen) yazı rengini temadan uygular."""
        if self._is_map:
            color = self.current_palette.get("ui_thumbnail_text_map", "#ffb74d")
            self.lbl_img.setStyleSheet(f"font-weight: bold; color: {color}; font-size: 11px; background: transparent;")
        elif not self.lbl_img.pixmap() or self.lbl_img.pixmap().isNull():
            # "?" durumu
            color = self.current_palette.get("ui_thumbnail_text_unknown", "#aaa")
            self.lbl_img.setStyleSheet(f"font-size: 10px; color: {color}; background: transparent;")

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            self.remove_requested.emit(self.image_path)

class ProjectionManager(QWidget):
    """Drop zone that sits inside the main toolbar."""
    # Sinyal artık (Path, PixmapObject) taşıyor. Pixmap yoksa None gider.
    image_added = pyqtSignal(str, object)
    image_removed = pyqtSignal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setAcceptDrops(True)
        self.setFixedHeight(40)
        self.setMinimumWidth(120) 
        self.setObjectName("projectionBar")
        
        # Başlangıç paleti
        self.current_palette = ThemeManager.get_palette("dark")
        
        self.layout = QHBoxLayout(self)
        self.layout.setContentsMargins(5, 2, 5, 2)
        self.layout.setSpacing(5)
        self.layout.setAlignment(Qt.AlignmentFlag.AlignLeft)
        
        self.lbl_info = QLabel(tr("LBL_DROP_HINT"))
        self.lbl_info.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.layout.addWidget(self.lbl_info)
        
        self.thumbnails = {} 
        
        # İlk stili uygula
        self.apply_styles(is_hover=False)

    def update_theme(self, palette):
        """MainWindow tarafından çağrılır. Kendini ve çocuklarını günceller."""
        self.current_palette = palette
        self.apply_styles(is_hover=False)
        
        # Dil değişmiş olabilir, metni güncelle
        self.lbl_info.setText(tr("LBL_DROP_HINT"))
        
        # Çocuk thumbnail'leri güncelle
        for thumb in self.thumbnails.values():
            thumb.update_theme(palette)

    def apply_styles(self, is_hover=False):
        p = self.current_palette
        
        if is_hover:
            bg = p.get("ui_projection_hover_bg", "rgba(50, 150, 250, 0.2)")
            border = p.get("ui_projection_hover_border", "#42a5f5")
            border_style = "1px solid"
        else:
            bg = p.get("ui_projection_bg", "rgba(0, 0, 0, 0.2)")
            border = p.get("ui_projection_border", "rgba(255, 255, 255, 0.3)")
            border_style = "1px dashed"

        self.setStyleSheet(f"""
            QWidget#projectionBar {{
                background-color: {bg};
                border: {border_style} {border};
                border-radius: 4px; 
            }}
        """)
        
        # Hint text rengi genellikle border rengiyle uyumlu olur
        self.lbl_info.setStyleSheet(f"color: {border}; font-size: 11px; font-style: italic; border: none; background: transparent;")

    def dragEnterEvent(self, event):
        if event.mimeData().hasUrls() or event.mimeData().hasText():
            event.acceptProposedAction()
            self.apply_styles(is_hover=True)

    def dragLeaveEvent(self, event):
        self.apply_styles(is_hover=False)

    def dropEvent(self, event):
        self.apply_styles(is_hover=False)
        image_path = None
        
        if event.mimeData().hasUrls():
            urls = event.mimeData().urls()
            if urls:
                image_path = urls[0].toLocalFile()
        elif event.mimeData().hasText():
            image_path = event.mimeData().text()
            
        if image_path and os.path.exists(image_path) and image_path.lower().endswith(('.png', '.jpg', '.jpeg', '.bmp', '.webp')):
            self.add_image(image_path)
            event.acceptProposedAction()

    def add_image(self, path, pixmap=None):
        """
        path: Dosya yolu (ID olarak kullanılır).
        pixmap: (Opsiyonel) Eğer varsa diskten okumak yerine bu kullanılır.
        """
        if path in self.thumbnails: 
            # UPDATE EXISTING
            thumb = self.thumbnails[path]
            thumb.update_thumbnail(path, pixmap)
            # Re-emit signal so PlayerWindow knows to update its view
            self.image_added.emit(path, pixmap)
            return
            
        self.lbl_info.hide()
        
        thumb = ProjectionThumbnail(path, pixmap=pixmap)
        # Yeni eklenen thumbnail'e mevcut temayı uygula
        thumb.update_theme(self.current_palette)
        
        thumb.remove_requested.connect(self.remove_image)
        self.layout.addWidget(thumb)
        
        self.thumbnails[path] = thumb
        
        # Sinyali tetikle: PlayerWindow'a gönder
        self.image_added.emit(path, pixmap)
        
        self.setMinimumWidth(self.minimumWidth() + 55)

    def remove_image(self, path):
        if path in self.thumbnails:
            widget = self.thumbnails.pop(path)
            self.layout.removeWidget(widget)
            widget.deleteLater()
            
            self.image_removed.emit(path)
            self.setMinimumWidth(max(120, self.minimumWidth() - 55))
            
            if not self.thumbnails:
                self.lbl_info.show()