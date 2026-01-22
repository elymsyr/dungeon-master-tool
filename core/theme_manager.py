class ThemeManager:
    """
    QSS (Qt Style Sheets) tarafından kontrol edilemeyen bileşenler için 
    (QGraphicsItem, HTML content, Canvas Background vb.) renk paletlerini yönetir.
    """
    
    # Varsayılan (Fallback) palet
    DEFAULT_PALETTE = {
        "canvas_bg": "#181818",         # MindMap Arka Planı
        "grid_color": "#2b2b2b",        # Izgara Çizgileri
        "node_bg_note": "#fff9c4",      # Not Kağıdı (Sarımsı)
        "node_bg_entity": "#2b2b2b",    # Varlık Kartı Arka Planı
        "node_text": "#212121",         # Not Kağıdı Yazı Rengi
        "line_color": "#787878",        # Bağlantı Çizgileri
        "line_selected": "#42a5f5",     # Seçili Çizgi
        "html_text": "#e0e0e0",         # Markdown Görüntüleyici Yazısı
        "html_link": "#42a5f5",         # Link Rengi
        "html_header": "#ffb74d"        # Başlıklar (H1, H2)
    }

    # Tema Bazlı Paletler
    PALETTES = {
        "dark": DEFAULT_PALETTE.copy(),
        
        "light": {
            "canvas_bg": "#f5f7fa",
            "grid_color": "#e2e8f0",
            "node_bg_note": "#ffffff",
            "node_bg_entity": "#ffffff",
            "node_text": "#2d3748",
            "line_color": "#cbd5e0",
            "line_selected": "#3182ce",
            "html_text": "#2d3748",
            "html_link": "#3182ce",
            "html_header": "#2b6cb0"
        },
        
        "parchment": {
            "canvas_bg": "#dccdb5", # Eski kağıt rengi
            "grid_color": "rgba(62, 39, 35, 0.2)",
            "node_bg_note": "#fdfbf7",
            "node_bg_entity": "#e5dace",
            "node_text": "#3e2723", # Koyu kahve
            "line_color": "#8d6e63",
            "line_selected": "#5d4037",
            "html_text": "#3e2723",
            "html_link": "#1565c0",
            "html_header": "#5d4037"
        },
        
        "ocean": {
            "canvas_bg": "#0f1b26", # Derin deniz mavisi
            "grid_color": "#1c313a",
            "node_bg_note": "#e0f7fa", # Açık camgöbeği
            "node_bg_entity": "#162533",
            "node_text": "#006064",
            "line_color": "#4dd0e1",
            "line_selected": "#00bcd4",
            "html_text": "#e0f7fa",
            "html_link": "#26c6da",
            "html_header": "#00bcd4"
        },
        
        "emerald": {
            "canvas_bg": "#051e12", 
            "grid_color": "#1b5e20",
            "node_bg_note": "#e8f5e9",
            "node_bg_entity": "#0a2718",
            "node_text": "#1b5e20",
            "line_color": "#2e7d32",
            "line_selected": "#00e676",
            "html_text": "#e8f5e9",
            "html_link": "#66bb6a",
            "html_header": "#00e676"
        },
        
        "midnight": {
            "canvas_bg": "#000000",
            "grid_color": "#1a1a1a",
            "node_bg_note": "#e1bee7", # Açık mor
            "node_bg_entity": "#121212",
            "node_text": "#4a148c",
            "line_color": "#7c4dff",
            "line_selected": "#b388ff",
            "html_text": "#b0bec5",
            "html_link": "#7c4dff",
            "html_header": "#651fff"
        }
        # Diğer temalar (grim, frost, baldur, amethyst) varsayılan dark veya light'a düşebilir 
        # veya buraya eklenebilir.
    }

    @staticmethod
    def get_palette(theme_name):
        """Verilen tema ismi için renk paletini döner."""
        # Eğer tema listemizde yoksa varsayılanı (dark) kullan
        return ThemeManager.PALETTES.get(theme_name, ThemeManager.DEFAULT_PALETTE)