class ThemeManager:
    """
    QSS (Qt Style Sheets) tarafından kontrol edilemeyen bileşenler için 
    (QGraphicsItem, HTML content, Canvas Background, özel çizimler vb.) 
    renk paletlerini yönetir.
    """
    
    # --- VARSAYILAN (DARK) PALET ---
    DEFAULT_PALETTE = {
        # --- Mind Map & Canvas ---
        "canvas_bg": "#181818",         # Sonsuz arka plan
        "grid_color": "#2b2b2b",        # Izgara çizgileri
        "node_bg_note": "#fff9c4",      # Not kağıdı (Sarımsı)
        "node_bg_entity": "#2b2b2b",    # Varlık kartı arka planı
        "node_text": "#212121",         # Not kağıdı üzerindeki yazı
        "line_color": "#787878",        # Bağlantı çizgileri
        "line_selected": "#42a5f5",     # Seçili bağlantı çizgisi
        "ui_resize_handle": "rgba(66, 165, 245, 180)", # Boyutlandırma tutamacı (Aktif)
        "ui_resize_handle_inactive": "rgba(128, 128, 128, 100)", # Boyutlandırma tutamacı (Pasif)

        # --- Markdown Editor (HTML Styles) ---
        "html_text": "#e0e0e0",         # Normal metin
        "html_link": "#42a5f5",         # Linkler
        "html_header": "#ffb74d",       # Başlıklar (H1-H3)
        "html_code_bg": "rgba(128,128,128,0.3)", # Kod blokları

        # --- Floating Controls (Zoom Buttons) ---
        "ui_floating_bg": "rgba(40, 40, 40, 230)",
        "ui_floating_border": "#555",
        "ui_floating_text": "#eee",
        "ui_floating_hover_bg": "#42a5f5",
        "ui_floating_hover_text": "#ffffff",

        # --- Autosave Indicator ---
        "ui_autosave_bg": "rgba(0, 0, 0, 100)",
        "ui_autosave_text_saved": "#81c784",   # Yeşil
        "ui_autosave_text_editing": "#ffb74d", # Turuncu

        # --- Projection Manager (Header) ---
        "ui_projection_bg": "rgba(0, 0, 0, 0.2)",
        "ui_projection_border": "rgba(255, 255, 255, 0.3)",
        "ui_projection_hover_bg": "rgba(50, 150, 250, 0.2)",
        "ui_projection_hover_border": "#42a5f5",
        "ui_thumbnail_bg": "#333",
        "ui_thumbnail_border": "#555",
        "ui_thumbnail_text_map": "#ffb74d",
        "ui_thumbnail_text_unknown": "#aaa",
        "ui_thumbnail_hover_border_remove": "#ff5555", # Silme uyarısı (Kırmızı)

        # --- Combat Tracker & Token Borders ---
        "token_border_player": "#4caf50",   # Oyuncu (Yeşil)
        "token_border_hostile": "#ef5350",  # Düşman (Kırmızı)
        "token_border_friendly": "#42a5f5", # Dost (Mavi)
        "token_border_neutral": "#bdbdbd",  # Nötr (Gri)
        "token_border_active": "#ffb74d",   # Sırası Gelen (Turuncu)
        
        # --- HP Bar Widget ---
        "hp_bar_high": "#2e7d32",           # Yüksek Can
        "hp_bar_med": "#fbc02d",            # Orta Can
        "hp_bar_low": "#c62828",            # Düşük Can
        "hp_widget_bg": "rgba(0,0,0,0.3)",  # Arka plan
        "hp_btn_decrease_bg": "#c62828",    # Azalt butonu
        "hp_btn_decrease_hover": "#d32f2f",
        "hp_btn_increase_bg": "#2e7d32",    # Artır butonu
        "hp_btn_increase_hover": "#388e3c",
        
        # --- Condition Icons ---
        "condition_default_bg": "#5c6bc0",
        "condition_duration_bg": "rgba(0, 0, 0, 200)",
        "condition_text": "#ffffff",

        # --- Battle Map Editor (Fog & Tools) ---
        "fog_pen_add": "#000000",           # Siyah (Görünür alan) - Maskeleme mantığına göre değişebilir
        "fog_pen_remove": "#ffffff",        # Beyaz/Silgi
        "fog_temp_path": "#ffff00",         # Çizim sırasındaki rehber çizgi (Sarı)
        
        # --- Map Pins ---
        "pin_npc": "#ff9800",
        "pin_monster": "#d32f2f",
        "pin_location": "#2e7d32",
        "pin_player": "#4caf50",
        "pin_default": "#007acc",
        "timeline_pin_bg": "#42a5f5",
        "timeline_session_bg": "#ffb300",

        # --- DM Notes (Secret) ---
        "dm_note_border": "#d32f2f",
        "dm_note_title": "#e57373"
    }

    # --- TEMA TANIMLARI ---
    PALETTES = {
        "dark": DEFAULT_PALETTE.copy(),
        
        "light": {
            "canvas_bg": "#f5f7fa",
            "grid_color": "#cbd5e0",
            "node_bg_note": "#ffffff",
            "node_bg_entity": "#ffffff",
            "node_text": "#2d3748",
            "line_color": "#a0aec0",
            "line_selected": "#3182ce",
            "html_text": "#2d3748",
            "html_link": "#3182ce",
            "html_header": "#2b6cb0",
            
            "ui_floating_bg": "rgba(255, 255, 255, 230)",
            "ui_floating_border": "#cbd5e0",
            "ui_floating_text": "#2d3748",
            
            "ui_projection_bg": "rgba(0, 0, 0, 0.05)",
            "ui_projection_border": "rgba(0, 0, 0, 0.2)",
            "ui_thumbnail_bg": "#edf2f7",
            "ui_thumbnail_border": "#cbd5e0",
            
            "hp_widget_bg": "rgba(0,0,0,0.1)",
        },
        
        "parchment": {
            "canvas_bg": "#dccdb5",
            "grid_color": "rgba(62, 39, 35, 0.15)",
            "node_bg_note": "#fdfbf7",
            "node_bg_entity": "#e5dace",
            "node_text": "#3e2723",
            "line_color": "#8d6e63",
            "line_selected": "#5d4037",
            "html_text": "#3e2723",
            "html_link": "#1565c0",
            "html_header": "#5d4037",
            
            "ui_floating_bg": "rgba(229, 218, 206, 0.9)",
            "ui_floating_border": "#8d6e63",
            "ui_floating_text": "#3e2723",
            "ui_floating_hover_bg": "#8d6e63",
            
            "dm_note_border": "#8d6e63",
            "dm_note_title": "#5d4037"
        },
        
        "ocean": {
            "canvas_bg": "#0f1b26",
            "grid_color": "#1c313a",
            "node_bg_note": "#e0f7fa",
            "node_bg_entity": "#162533",
            "node_text": "#006064",
            "line_color": "#4dd0e1",
            "line_selected": "#00bcd4",
            "html_text": "#e0f7fa",
            "html_link": "#26c6da",
            "html_header": "#00bcd4",
            "ui_resize_handle": "rgba(38, 198, 218, 180)",
            
            "ui_floating_bg": "rgba(22, 37, 51, 0.9)",
            "ui_floating_border": "#37474f",
            "ui_floating_text": "#e0f7fa",
            "ui_floating_hover_bg": "#00bcd4"
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
            "html_header": "#00e676",
            
            "ui_floating_bg": "rgba(10, 39, 24, 0.9)",
            "ui_floating_hover_bg": "#00e676"
        },
        
        "midnight": {
            "canvas_bg": "#000000",
            "grid_color": "#1a1a1a",
            "node_bg_note": "#e1bee7",
            "node_bg_entity": "#121212",
            "node_text": "#4a148c",
            "line_color": "#7c4dff",
            "line_selected": "#b388ff",
            "html_text": "#b0bec5",
            "html_link": "#7c4dff",
            "html_header": "#651fff",
            
            "ui_floating_bg": "rgba(20, 20, 20, 0.9)",
            "ui_floating_hover_bg": "#651fff"
        },
        
        "discord": {
            "canvas_bg": "#202225",
            "grid_color": "#2f3136",
            "node_bg_note": "#36393f",
            "node_bg_entity": "#2f3136",
            "node_text": "#dcddde",
            "line_color": "#40444b",
            "line_selected": "#5865f2",
            "html_text": "#dcddde",
            "html_link": "#00b0f4",
            "html_header": "#ffffff",
            
            "ui_floating_bg": "#2f3136",
            "ui_floating_hover_bg": "#5865f2"
        },
        
        "baldur": {
            "canvas_bg": "#110b09",
            "grid_color": "#3e2723",
            "node_bg_note": "#e0d8c8",
            "node_bg_entity": "#1a120b",
            "node_text": "#3e2723",
            "line_color": "#8d6e63",
            "line_selected": "#ffd700",
            "html_text": "#c8b696",
            "html_link": "#ffd700",
            "html_header": "#b88e4a",
            
            "ui_floating_bg": "rgba(26, 18, 11, 0.9)",
            "ui_floating_hover_bg": "#b88e4a",
            "ui_floating_hover_text": "#000000"
        },
        
        "grim": {
            "canvas_bg": "#1c1c1c",
            "grid_color": "#333",
            "node_bg_note": "#d7ccc8",
            "node_bg_entity": "#262626",
            "node_text": "#3e2723",
            "line_color": "#555",
            "line_selected": "#a63a28",
            "html_text": "#d7d7d7",
            "html_link": "#a63a28",
            "html_header": "#8c2323",
            
            "ui_floating_bg": "#333",
            "ui_floating_hover_bg": "#a63a28"
        },
        
        "frost": {
            "canvas_bg": "#e6fffa",
            "grid_color": "#b2f5ea",
            "node_bg_note": "#ffffff",
            "node_bg_entity": "#f0fff4",
            "node_text": "#234e52",
            "line_color": "#81e6d9",
            "line_selected": "#319795",
            "html_text": "#2c7a7b",
            "html_link": "#319795",
            "html_header": "#285e61",
            
            "ui_floating_bg": "rgba(230, 255, 250, 0.9)",
            "ui_floating_border": "#81e6d9",
            "ui_floating_text": "#234e52",
            "ui_floating_hover_bg": "#319795"
        },
        
        "amethyst": {
            "canvas_bg": "#211a26",
            "grid_color": "#4a148c",
            "node_bg_note": "#f3e5f5",
            "node_bg_entity": "#2d2436",
            "node_text": "#4a148c",
            "line_color": "#7b1fa2",
            "line_selected": "#ea80fc",
            "html_text": "#f3e5f5",
            "html_link": "#ab47bc",
            "html_header": "#ea80fc",
            
            "ui_floating_bg": "rgba(45, 36, 54, 0.9)",
            "ui_floating_hover_bg": "#ab47bc"
        }
    }

    @staticmethod
    def get_palette(theme_name):
        """Verilen tema ismi için renk paletini döner. Bulamazsa Dark döner."""
        base = ThemeManager.DEFAULT_PALETTE.copy()
        
        if theme_name in ThemeManager.PALETTES:
            # Sadece değişen anahtarları güncelle (Merge)
            specific = ThemeManager.PALETTES[theme_name]
            base.update(specific)
            
        return base