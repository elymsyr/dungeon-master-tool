ENTITY_SCHEMAS = {
    "NPC": [
        ("LBL_RACE", "text", None),
        ("LBL_CLASS", "text", None),
        ("LBL_LEVEL", "text", None), 
        ("LBL_ATTITUDE", "combo", ["LBL_ATTR_FRIENDLY", "LBL_ATTR_NEUTRAL", "LBL_ATTR_HOSTILE"]),
        ("LBL_ATTR_LOCATION", "text", None)
    ],
    "Monster": [
        ("LBL_CR", "text", None),
        ("LBL_ATTACK_TYPE", "text", None)
    ],
    "Spell": [
        ("LBL_LEVEL", "combo", ["Cantrip", "1", "2", "3", "4", "5", "6", "7", "8", "9"]),
        ("LBL_SCHOOL", "text", None),
        ("LBL_CASTING_TIME", "text", None),
        ("LBL_RANGE", "text", None),
        ("LBL_DURATION", "text", None),
        ("LBL_COMPONENTS", "text", None)
    ],
    "Equipment": [
        ("LBL_CATEGORY", "text", None),
        ("LBL_RARITY", "text", None),
        ("LBL_ATTUNEMENT", "text", None),
        ("LBL_COST", "text", None),
        ("LBL_WEIGHT", "text", None),
        ("LBL_DAMAGE_DICE", "text", None),
        ("LBL_DAMAGE_TYPE", "text", None),
        ("LBL_RANGE", "text", None),
        ("LBL_AC", "text", None),
        ("LBL_REQUIREMENTS", "text", None),
        ("LBL_PROPERTIES", "text", None)
    ],
    "Class": [
        ("LBL_HIT_DIE", "text", None), 
        ("LBL_MAIN_STATS", "text", None), 
        ("LBL_PROFICIENCIES", "text", None)
    ],
    "Race": [
        ("LBL_SPEED", "text", None), 
        ("LBL_SIZE", "combo", ["Small", "Medium", "Large"]), 
        ("LBL_ALIGNMENT", "text", None), 
        ("LBL_LANGUAGE", "text", None)
    ],
    "Location": [
        ("LBL_DANGER_LEVEL", "combo", ["LBL_DANGER_SAFE", "LBL_DANGER_LOW", "LBL_DANGER_MEDIUM", "LBL_DANGER_HIGH"]), 
        ("LBL_ENVIRONMENT", "text", None)
    ],
    "Player": [
        ("LBL_CLASS", "text", None), 
        ("LBL_RACE", "text", None), 
        ("LBL_LEVEL", "text", None)
    ],
    "Quest": [
        ("LBL_STATUS", "combo", ["LBL_STATUS_NOT_STARTED", "LBL_STATUS_ACTIVE", "LBL_STATUS_COMPLETED"]), 
        ("LBL_GIVER", "text", None), 
        ("LBL_REWARD", "text", None)
    ],
    "Lore": [
        ("LBL_CATEGORY", "combo", ["LBL_LORE_HISTORY", "LBL_LORE_GEOGRAPHY", "LBL_LORE_RELIGION", "LBL_LORE_CULTURE", "LBL_LORE_OTHER"]), 
        ("LBL_SECRET_INFO", "text", None)
    ]
}

# Mapping for legacy data compatibility (TR -> EN)
SCHEMA_MAP = {
    "Canavar": "Monster",
    "Büyü (Spell)": "Spell",
    "Eşya (Equipment)": "Equipment",
    "Sınıf (Class)": "Class",
    "Irk (Race)": "Race",
    "Mekan": "Location",
    "Oyuncu": "Player",
    "Görev": "Quest",
    "Lore": "Lore"
}

# Mapping for legacy property labels compatibility
PROPERTY_MAP = {
    "Irk": "LBL_RACE",
    "Sınıf": "LBL_CLASS",
    "Seviye": "LBL_LEVEL",
    "Tavır": "LBL_ATTITUDE",
    "Konum": "LBL_ATTR_LOCATION",
    "Challenge Rating (CR)": "LBL_CR",
    "Saldırı Tipi": "LBL_ATTACK_TYPE",
    "Okul (School)": "LBL_SCHOOL",
    "Süre (Casting Time)": "LBL_CASTING_TIME",
    "Menzil (Range)": "LBL_RANGE",
    "Menzil": "LBL_RANGE",
    "Süreklilik (Duration)": "LBL_DURATION",
    "Bileşenler (Components)": "LBL_COMPONENTS",
    "Kategori": "LBL_CATEGORY",
    "Nadirik (Rarity)": "LBL_RARITY",
    "Uyumlanma (Attunement)": "LBL_ATTUNEMENT",
    "Maliyet": "LBL_COST",
    "Ağırlık": "LBL_WEIGHT",
    "Hasar Zarı": "LBL_DAMAGE_DICE",
    "Hasar Tipi": "LBL_DAMAGE_TYPE",
    "Zırh Sınıfı (AC)": "LBL_AC",
    "Gereksinimler": "LBL_REQUIREMENTS",
    "Özellikler": "LBL_PROPERTIES",
    "Hit Die": "LBL_HIT_DIE",
    "Ana Statlar": "LBL_MAIN_STATS",
    "Zırh/Silah Yetkinlikleri": "LBL_PROFICIENCIES",
    "Hız": "LBL_SPEED",
    "Boyut": "LBL_SIZE",
    "Hizalanma Eğilimi": "LBL_ALIGNMENT",
    "Dil": "LBL_LANGUAGE",
    "Tehlike Seviyesi": "LBL_DANGER_LEVEL",
    "Ortam": "LBL_ENVIRONMENT",
    "Durum": "LBL_STATUS",
    "Görevi Veren": "LBL_GIVER",
    "Ödül": "LBL_REWARD",
    "Gizli Bilgi": "LBL_SECRET_INFO"
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
        "combat_stats": {"hp": "", "max_hp": "", "ac": "", "speed": "", "cr": "", "xp": "", "initiative": ""},
        
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
        
        "pdfs": [],               # PDF Dosyaları
        "location_id": None,

        # --- Gelişmiş Statlar (NPC/Canavar için) ---
        "saving_throws": "",
        "damage_vulnerabilities": "",
        "damage_resistances": "",
        "damage_immunities": "",
        "condition_immunities": "",
        "proficiency_bonus": "",
        "passive_perception": "",
        "skills": ""
    }