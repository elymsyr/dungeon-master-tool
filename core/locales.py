# Localization Dictionary

# Current Language Global Variable
CURRENT_LANGUAGE = "EN"

def set_language(lang_code):
    global CURRENT_LANGUAGE
    if lang_code in ["EN", "TR"]:
        CURRENT_LANGUAGE = lang_code

def tr(key):
    """Returns the translated string for the given key."""
    return TRANSLATIONS.get(CURRENT_LANGUAGE, {}).get(key, key)

TRANSLATIONS = {
    "EN": {
        # General
        "BTN_SAVE": "Save",
        "BTN_DELETE": "Delete",
        "BTN_CANCEL": "Cancel",
        "BTN_ADD": "Add",
        "BTN_REMOVE": "Remove",
        "BTN_IMPORT": "Import",
        "BTN_CLOSE": "Close",
        "MSG_SUCCESS": "Success",
        "MSG_ERROR": "Error",
        "MSG_WARNING": "Warning",
        "LBL_NAME": "Name:",
        "LBL_TYPE": "Type:",
        "LBL_DESC": "Description:",
        
        # Main Window
        "WIN_TITLE": "Dungeon Master Tool",
        "BTN_PLAYER_SCREEN": "📺 Toggle Player Screen",
        "BTN_EXPORT": "📄 Export (TXT)",
        "LBL_CAMPAIGN": "World: ",
        "TAB_DB": "Database & Characters",
        "TAB_MAP": "Maps",
        "TAB_SESSION": "Session",
        
        # Map Tab
        "BTN_LOAD_MAP": "🖼️ Load Map",
        "BTN_PROJECT_MAP": "🌍 Project Map",
        "MSG_SELECT_MAP": "Select Map Image",
        "MSG_NO_PLAYER_SCREEN": "First open the Player Screen.",
        "MSG_ADD_PIN": "Add Pin",
        "MSG_SELECT_ENTITY": "Select Entity:",
        "MSG_NO_ENTITY_FOR_PIN": "No suitable entity found to pin.",
        "MSG_DELETE_PIN": "Remove this pin?",
        "MENU_INSPECT": "Inspect",
        "MENU_MOVE": "Move",
        "MENU_DELETE": "Delete",
        
        # Bulk Downloader
        "TITLE_DOWNLOADER": "Bulk Downloader",
        "LBL_SELECT_CATS": "Select Categories:",
        "BTN_START_DOWNLOAD": "Start Download",
        "MSG_DOWNLOAD_COMPLETE": "Download Complete!",
        
        # Campaign Selector
        "TITLE_SELECT_WORLD": "Select or Create World",
        "BTN_CREATE_WORLD": "Create New World",
        "LBL_SELECT_WORLD": "Select World:",
        "MSG_ENTER_WORLD_NAME": "Enter World Name:",
        "LBL_LANGUAGE": "Language / Dil:",
        
        # Database Tab
        "BTN_NEW_ENTITY": "➕ New Entity",
        "BTN_API_BROWSER": "🌐 API Browser",
        "LBL_SEARCH": "Search...",
        "LBL_FILTER": "Filter",
        "BTN_NEW_ENTITY": "➕ New Entity",
        "BTN_API_BROWSER": "🌐 API Browser",
        "BTN_DOWNLOAD_ALL": "⬇️ Download All (Offline)",
        "LBL_CHECK_LIBRARY": "Include Library Results",
        "LBL_SEARCH": "Search...",
        "LBL_FILTER": "Filter",
        "CAT_ALL": "All",
        
        # API Browser
        "TITLE_API": "D&D 5e API Browser",
        "LBL_CATEGORY": "Category:",
        "LBL_SEARCH_API": "Search (Eng)...",
        "MSG_LOADING": "Loading...",
        "MSG_IMPORTED": "Imported successfully.",
        "MSG_EXISTS": "Already exists.",
        
        # NPC Sheet
        "BTN_SELECT_IMG": "Select Image",
        "BTN_SHOW_PLAYER": "👁️ Show to Player",
        "BTN_SHOW_STATS": "📄 Project Card",
        "LBL_TAGS": "Tags:",
        "LBL_LOCATION": "Location:",
        "LBL_RESIDENTS": "Residents:",
        "GRP_STATS": "Stats",
        "GRP_SPELLS": "Spells",
        "GRP_ACTIONS": "Actions",
        "GRP_INVENTORY": "Inventory",
        "TAB_STATS": "📊 Stats",
        "TAB_SPELLS": "✨ Spells",
        "TAB_ACTIONS": "⚔️ Actions",
        "TAB_INV": "🎒 Inventory",
        "TAB_DOCS": "📂 Docs & PDFs",
        "Lore": "Lore",
        
        # Dialogs
        "GRP_PDF": "Attached PDF Files",
        "BTN_OPEN_PDF": "Open PDF",
        "BTN_PROJECT_PDF": "👁️ Project PDF",
        "MSG_SELECT_PDF": "Select PDF File",
        "MSG_CONFIRM_DELETE_PDF": "Remove this PDF file?",
        
        # Session & Combat
        "TITLE_COMBAT": "⚔️ Combat & Initiative",
        "GRP_DICE": "Roll Dice",
        "BTN_NEW_SESSION": "📝 New Session",
        "BTN_LOAD_SESSION": "Load",
        "LBL_LOG": "📜 Event Log",
        "LBL_NOTES": "🕵️ DM Notes",
        "BTN_ADD_LOG": "Add Log",
        "HEADER_NAME": "Name",
        "HEADER_INIT": "Init",
        "HEADER_AC": "AC",
        "HEADER_HP": "HP",
        "HEADER_COND": "Condition",
        "BTN_ROLL_INIT": "🎲 Roll Init",
        "BTN_CLEAR": "🗑️ Clear",
        "MENU_ADD_COND": "🩸 Add/Remove Condition",
        "MENU_REMOVE_COMBAT": "❌ Remove from Combat",
    },
    
    "TR": {
        # General
        "BTN_SAVE": "Kaydet",
        "BTN_DELETE": "Sil",
        "BTN_CANCEL": "İptal",
        "BTN_ADD": "Ekle",
        "BTN_REMOVE": "Kaldır",
        "BTN_IMPORT": "İçe Aktar",
        "BTN_CLOSE": "Kapat",
        "MSG_SUCCESS": "Başarılı",
        "MSG_ERROR": "Hata",
        "MSG_WARNING": "Uyarı",
        "LBL_NAME": "İsim:",
        "LBL_TYPE": "Tip:",
        "LBL_DESC": "Açıklama:",
        
        # Main Window
        "WIN_TITLE": "Zindan Efendisi Aracı",
        "BTN_PLAYER_SCREEN": "📺 Oyuncu Ekranını Aç/Kapat",
        "BTN_EXPORT": "📄 Dışa Aktar (TXT)",
        "LBL_CAMPAIGN": "Dünya: ",
        "TAB_DB": "Veritabanı & Karakterler",
        "TAB_MAP": "Haritalar",
        "TAB_SESSION": "Oturum",

        # Map Tab
        "BTN_LOAD_MAP": "🖼️ Harita Yükle",
        "BTN_PROJECT_MAP": "🌍 Haritayı Yansıt",
        "MSG_SELECT_MAP": "Harita Seç",
        "MSG_NO_PLAYER_SCREEN": "Önce Oyuncu Ekranını açın.",
        "MSG_ADD_PIN": "Pin Ekle",
        "MSG_SELECT_ENTITY": "Varlık Seç:",
        "MSG_NO_ENTITY_FOR_PIN": "Haritaya eklenebilecek uygun bir varlık bulunamadı.",
        "MSG_DELETE_PIN": "Bu pini kaldırmak istiyor musun?",
        "MENU_INSPECT": "İncele",
        "MENU_MOVE": "Taşı",
        "MENU_DELETE": "Sil",
        
        # Bulk Downloader
        "TITLE_DOWNLOADER": "Toplu İndirici",
        "LBL_SELECT_CATS": "Kategorileri Seç:",
        "BTN_START_DOWNLOAD": "İndirmeyi Başlat",
        "MSG_DOWNLOAD_COMPLETE": "İndirme Tamamlandı!",
        
        # Campaign Selector
        "TITLE_SELECT_WORLD": "Dünya Seç veya Oluştur",
        "BTN_CREATE_WORLD": "Yeni Dünya Oluştur",
        "LBL_SELECT_WORLD": "Dünya Seçiniz:",
        "MSG_ENTER_WORLD_NAME": "Dünya Adı Giriniz:",
        "LBL_LANGUAGE": "Language / Dil:",
        
        # Database Tab
        "BTN_NEW_ENTITY": "➕ Yeni Varlık",
        "BTN_API_BROWSER": "🌐 API Tarayıcı",
        "LBL_SEARCH": "Ara...",
        "LBL_FILTER": "Filtre",
        "BTN_NEW_ENTITY": "➕ Yeni Varlık",
        "BTN_API_BROWSER": "🌐 Kütüphaneyi Tara (Detaylı)",
        "BTN_DOWNLOAD_ALL": "⬇️ Tüm Veritabanını İndir (Offline)",
        "LBL_CHECK_LIBRARY": "Kütüphane sonuçlarını dahil et",
        "LBL_SEARCH": "Ara...",
        "LBL_FILTER": "Filtre",
        "CAT_ALL": "Tümü",
        
        # API Browser
        "TITLE_API": "D&D 5e API Tarayıcı",
        "LBL_CATEGORY": "Kategori:",
        "LBL_SEARCH_API": "Ara (İng)...",
        "MSG_LOADING": "Yükleniyor...",
        "MSG_IMPORTED": "Başarıyla içe aktarıldı.",
        "MSG_EXISTS": "Zaten mevcut.",
        
        # NPC Sheet
        "BTN_SELECT_IMG": "Resim Seç",
        "BTN_SHOW_PLAYER": "👁️ Oyuncuya Göster",
        "BTN_SHOW_STATS": "📄 Kartı Yansıt",
        "LBL_TAGS": "Etiketler:",
        "LBL_LOCATION": "Konum:",
        "LBL_RESIDENTS": "Sakinler:",
        "GRP_STATS": "İstatistikler",
        "GRP_SPELLS": "Büyüler",
        "GRP_ACTIONS": "Eylemler",
        "GRP_INVENTORY": "Envanter",
        "TAB_STATS": "📊 İstatistikler",
        "TAB_SPELLS": "✨ Büyüler",
        "TAB_ACTIONS": "⚔️ Eylemler",
        "TAB_ACTIONS": "⚔️ Eylemler",
        "TAB_INV": "🎒 Envanter",
        "TAB_DOCS": "📂 Belgeler & PDF",
        
        "GRP_PDF": "Ekli PDF Dosyaları",
        "BTN_OPEN_PDF": "PDF Aç",
        "BTN_PROJECT_PDF": "👁️ PDF Yansıt",
        "MSG_SELECT_PDF": "PDF Dosyası Seç",
        "MSG_CONFIRM_DELETE_PDF": "Bu PDF dosyasını silmek istiyor musun?",
        
        # Session & Combat
        "TITLE_COMBAT": "⚔️ Savaş & İnisiyatif",
        "GRP_DICE": "Zar At",
        "BTN_NEW_SESSION": "📝 Yeni Oturum",
        "BTN_LOAD_SESSION": "Yükle",
        "LBL_LOG": "📜 Olay Günlüğü",
        "LBL_NOTES": "🕵️ DM Notları",
        "BTN_ADD_LOG": "Log Ekle",
        "HEADER_NAME": "İsim",
        "HEADER_INIT": "İnisiyatif",
        "HEADER_AC": "ZS (AC)",
        "HEADER_HP": "CY (HP)",
        "HEADER_COND": "Durum",
        "BTN_ROLL_INIT": "🎲 İnisiyatif At",
        "BTN_CLEAR": "🗑️ Temizle",
        "MENU_ADD_COND": "🩸 Durum Ekle/Kaldır",
        "MENU_REMOVE_COMBAT": "❌ Savaştan Çıkar",
    }
}
