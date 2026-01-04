import requests
from config import API_BASE_URL

class DndApiClient:
    def __init__(self):
        self.session = requests.Session()
        
        # Kategori -> Endpoint Haritası
        self.ENDPOINT_MAP = {
            "Canavar": "monsters",
            "Büyü (Spell)": "spells",
            "Eşya (Equipment)": "equipment",
            "Sınıf (Class)": "classes",
            "Irk (Race)": "races",
            "Magic Item": "magic-items" # Ekstra
        }

    def get_list(self, category):
        """
        Seçilen kategorideki TÜM varlıkların listesini (index) çeker.
        Dönüş: [{"index": "acid-arrow", "name": "Acid Arrow", "url": "..."}, ...]
        """
        endpoint = self.ENDPOINT_MAP.get(category)
        if not endpoint:
            # Eşya kategorisi için özel durum: Hem Equipment hem Magic Item çekelim
            if category == "Eşya (Equipment)":
                # İkisini birleştir
                l1 = self._fetch_all("equipment")
                l2 = self._fetch_all("magic-items")
                return l1 + l2
            return []

        return self._fetch_all(endpoint)

    def _fetch_all(self, endpoint):
        url = f"{API_BASE_URL}/{endpoint}"
        try:
            response = self.session.get(url, timeout=10)
            if response.status_code == 200:
                data = response.json()
                return data.get("results", [])
            return []
        except Exception as e:
            print(f"API List Error: {e}")
            return []

    def search(self, category, query):
        """Tekil arama (Eski fonksiyon aynen kalıyor, sadece magic item için küçük fix)"""
        endpoint = self.ENDPOINT_MAP.get(category)
        if not endpoint: return None, "Kategori desteklenmiyor."

        formatted_query = query.lower().strip().replace(" ", "-")
        url = f"{API_BASE_URL}/{endpoint}/{formatted_query}"
        
        try:
            response = self.session.get(url, timeout=10)
            if response.status_code == 200:
                return self.parse_dispatcher(category, response.json()), "Başarılı"
            
            # Eşya ise Magic Item da dene
            if category == "Eşya (Equipment)":
                url2 = f"{API_BASE_URL}/magic-items/{formatted_query}"
                resp2 = self.session.get(url2, timeout=10)
                if resp2.status_code == 200:
                    return self.parse_equipment(resp2.json()), "Magic Item bulundu."

            return None, "Bulunamadı."
        except Exception as e:
            return None, str(e)

    # --- PARSERLAR (Önceki kodların aynısı - Kısaltıldı) ---
    def parse_dispatcher(self, category, data):
        if category == "Canavar": return self.parse_monster(data)
        elif category == "Büyü (Spell)": return self.parse_spell(data)
        elif category == "Eşya (Equipment)": return self.parse_equipment(data)
        elif category == "Sınıf (Class)": return self.parse_class(data)
        elif category == "Irk (Race)": return self.parse_race(data)
        return {}

    # (Buraya önceki cevaptaki parse_monster, parse_spell vb. metodlarını aynen koymalısın)
    # Kod tekrarı olmaması için burayı kısaltıyorum, sen önceki api_client.py'daki parserları silme.
    def parse_monster(self, data):
        # ... (Eski kod) ...
        ac_val = data.get("armor_class", [{"value": 10}])[0].get("value", 10) if isinstance(data.get("armor_class"), list) else data.get("armor_class", 10)
        return {
            "name": data.get("name"), "type": "Canavar",
            "description": f"Size: {data.get('size')}, Type: {data.get('type')}",
            "stats": {k.upper()[:3]: data.get(k) for k in ["strength", "dexterity", "constitution", "intelligence", "wisdom", "charisma"]},
            "combat_stats": {"hp": f"{data.get('hit_points')}", "ac": str(ac_val), "cr": str(data.get("challenge_rating")), "speed": "30 ft"},
            "attributes": {"Challenge Rating (CR)": str(data.get("challenge_rating"))},
            "traits": [{"name": t["name"], "desc": t["desc"]} for t in data.get("special_abilities", [])],
            "actions": [{"name": a["name"], "desc": a["desc"]} for a in data.get("actions", [])]
        }
    
    def parse_spell(self, data):
        desc = "\n".join(data.get("desc", []))
        return {
            "name": data.get("name"), "type": "Büyü (Spell)",
            "description": desc,
            "tags": [data.get("school", {}).get("name", ""), f"Level {data.get('level')}"],
            "attributes": {
                "Seviye": str(data.get("level")), "Okul (School)": data.get("school", {}).get("name", ""),
                "Süre (Casting Time)": data.get("casting_time", ""), "Menzil (Range)": data.get("range", "")
            }
        }

    def parse_equipment(self, data):
        desc = "\n".join(data.get("desc", []))
        return {
            "name": data.get("name"), "type": "Eşya (Equipment)", "description": desc,
            "attributes": {"Maliyet": str(data.get("cost", {}).get("quantity", 0)), "Eşya Tipi": data.get("equipment_category", {}).get("name", "")}
        }

    def parse_class(self, data):
        return {"name": data.get("name"), "type": "Sınıf (Class)", "description": f"Hit Die: d{data.get('hit_die')}", "attributes": {"Hit Die": f"d{data.get('hit_die')}"}}

    def parse_race(self, data):
        return {"name": data.get("name"), "type": "Irk (Race)", "description": f"Speed: {data.get('speed')}", "attributes": {"Hız": str(data.get("speed"))}}