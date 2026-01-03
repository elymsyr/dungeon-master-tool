# core/models.py

# Arayüzde dinamik form oluşturmak için kullanılan şemalar
# Format: "Kategori": [("Etiket", "Widget Tipi", [Seçenekler])]
ENTITY_SCHEMAS = {
    "NPC": [
        ("Irk", "text", None),
        ("Sınıf", "text", None), # İleride burayı Class entity'sine bağlayacağız
        ("Tavır", "combo", ["Dost", "Nötr", "Düşman"]),
        ("Konum", "text", None)
    ],
    "Canavar": [
        ("Challenge Rating (CR)", "text", None),
        ("HP", "text", None),
        ("AC", "text", None),
        ("Hız", "text", None),
        ("Saldırı Tipi", "text", None)
    ],
    "Büyü (Spell)": [
        ("Seviye", "combo", ["Cantrip", "1", "2", "3", "4", "5", "6", "7", "8", "9"]),
        ("Okul (School)", "text", None),
        ("Süre (Casting Time)", "text", None),
        ("Menzil (Range)", "text", None),
        ("Süreklilik (Duration)", "text", None),
        ("Bileşenler (Components)", "text", None)
    ],
    "Eşya (Equipment)": [
        ("Eşya Tipi", "text", None), # Weapon, Armor, Potion...
        ("Maliyet", "text", None),
        ("Ağırlık", "text", None),
        ("Hasar/Zırh", "text", None),
        ("Özellikler", "text", None)
    ],
    "Sınıf (Class)": [
        ("Hit Die", "text", None),
        ("Ana Statlar", "text", None), # Saving Throws
        ("Zırh/Silah Yetkinlikleri", "text", None)
    ],
    "Irk (Race)": [
        ("Hız", "text", None),
        ("Boyut", "combo", ["Small", "Medium", "Large"]),
        ("Hizalanma Eğilimi", "text", None),
        ("Dil", "text", None)
    ],
    "Mekan": [
        ("Tehlike Seviyesi", "combo", ["Güvenli", "Düşük", "Orta", "Yüksek"]),
        ("Ortam", "text", None)
    ]
}

def get_default_entity_structure(entity_type="NPC"):
    """Varsayılan boş veri yapısı"""
    return {
        "name": "Yeni Kayıt",
        "type": entity_type,
        "description": "",
        "image_path": "",
        "tags": [],
        "attributes": {}, # Dinamik alanlar buraya
        "stats": {"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10},
        "combat_stats": {"hp": "", "ac": "", "speed": "", "cr": ""},
        "traits": [],
        "actions": []
    }