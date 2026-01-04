ENTITY_SCHEMAS = {
    "NPC": [
        ("Irk", "text", None),
        ("Sınıf", "text", None),
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
    # ... Diğer şemalar aynı kalsın ...
    "Büyü (Spell)": [
        ("Seviye", "combo", ["Cantrip", "1", "2", "3", "4", "5", "6", "7", "8", "9"]),
        ("Okul (School)", "text", None),
        ("Süre (Casting Time)", "text", None),
        ("Menzil (Range)", "text", None),
        ("Süreklilik (Duration)", "text", None),
        ("Bileşenler (Components)", "text", None)
    ],
    "Eşya (Equipment)": [
        ("Eşya Tipi", "text", None),
        ("Maliyet", "text", None),
        ("Ağırlık", "text", None),
        ("Hasar/Zırh", "text", None),
        ("Özellikler", "text", None)
    ],
    "Sınıf (Class)": [("Hit Die", "text", None), ("Ana Statlar", "text", None), ("Zırh/Silah Yetkinlikleri", "text", None)],
    "Irk (Race)": [("Hız", "text", None), ("Boyut", "combo", ["Small", "Medium", "Large"]), ("Hizalanma Eğilimi", "text", None), ("Dil", "text", None)],
    "Mekan": [("Tehlike Seviyesi", "combo", ["Güvenli", "Düşük", "Orta", "Yüksek"]), ("Ortam", "text", None)],
    "Oyuncu": [("Sınıf", "text", None), ("Irk", "text", None), ("Seviye", "text", None)],
    "Görev": [("Durum", "combo", ["Başlamadı", "Aktif", "Tamamlandı"]), ("Görevi Veren", "text", None), ("Ödül", "text", None)]
}

def get_default_entity_structure(entity_type="NPC"):
    return {
        "name": "Yeni Kayıt",
        "type": entity_type,
        "description": "",
        "images": [], # YENİ: Çoklu resim desteği
        "image_path": "", # Geriye dönük uyumluluk için (varsa ilk resim buraya da yazılır)
        "tags": [],
        "attributes": {},
        "stats": {"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10},
        "combat_stats": {"hp": "", "ac": "", "speed": "", "cr": ""},
        
        # --- LİSTELER ---
        "traits": [],
        "actions": [],
        "reactions": [],
        "legendary_actions": [],
        
        # Büyüler
        "spells": [],             # ID Listesi (Linked)
        "custom_spells": [],      # Manuel Kartlar
        
        # Envanter (YENİLENEN KISIM)
        "equipment_ids": [],      # YENİ: ID Listesi (Linked Items)
        "inventory": [],          # Manuel Kartlar (Mevcut yapı)
        
        "location_id": None
    }