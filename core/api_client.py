import requests
from config import API_BASE_URL

class DndApiClient:
    def __init__(self):
        self.session = requests.Session()
        self.ENDPOINT_MAP = {
            "Canavar": "monsters",
            "Büyü (Spell)": "spells",
            "Eşya (Equipment)": "equipment",
            "Sınıf (Class)": "classes",
            "Irk (Race)": "races",
            "Magic Item": "magic-items"
        }

    # ... (get_list, search, _fetch_all aynı kalıyor) ...
    def get_list(self, category):
        endpoint = self.ENDPOINT_MAP.get(category)
        if not endpoint:
            if category == "Eşya (Equipment)":
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
                return response.json().get("results", [])
            return []
        except Exception:
            return []

    def search(self, category, query):
        endpoint = self.ENDPOINT_MAP.get(category)
        if not endpoint: return None, "Kategori desteklenmiyor."

        formatted_query = query.lower().strip().replace(" ", "-")
        url = f"{API_BASE_URL}/{endpoint}/{formatted_query}"
        
        try:
            response = self.session.get(url, timeout=10)
            if response.status_code == 200:
                return self.parse_dispatcher(category, response.json()), "Başarılı"
            
            if category == "Eşya (Equipment)":
                url2 = f"{API_BASE_URL}/magic-items/{formatted_query}"
                resp2 = self.session.get(url2, timeout=10)
                if resp2.status_code == 200:
                    return self.parse_equipment(resp2.json()), "Magic Item bulundu."

            return None, "Bulunamadı."
        except Exception as e:
            return None, str(e)

    def parse_dispatcher(self, category, data):
        if category == "Canavar": return self.parse_monster(data)
        elif category == "Büyü (Spell)": return self.parse_spell(data)
        elif category == "Eşya (Equipment)": return self.parse_equipment(data)
        elif category == "Sınıf (Class)": return self.parse_class(data)
        elif category == "Irk (Race)": return self.parse_race(data)
        return {}

    def parse_monster(self, data):
        """
        API'den gelen ham canavar verisini uygulamanın veri yapısına çevirir.
        Ayrıca 'spellcasting' özelliği varsa büyülerin indexlerini yakalar.
        """
        # 1. AC Parse (Zırh Sınıfı)
        ac_val = "10"
        raw_ac = data.get("armor_class", [])
        if isinstance(raw_ac, list) and len(raw_ac) > 0:
            ac_entry = raw_ac[0]
            ac_val = f"{ac_entry.get('value', 10)}"
            if ac_entry.get('type'): 
                ac_val += f" ({ac_entry.get('type')})"
        else:
            ac_val = str(data.get("armor_class", 10))

        # 2. Hız Parse
        speed_dict = data.get("speed", {})
        speed_str = ", ".join([f"{k.capitalize()} {v}" for k, v in speed_dict.items()])

        # 3. Saves & Skills Parse (Proficiencies listesinden ayıklama)
        saves = []
        skills = []
        for prof in data.get("proficiencies", []):
            name = prof.get("proficiency", {}).get("name", "")
            val = prof.get("value", 0)
            sign = "+" if val >= 0 else ""
            
            if "Saving Throw:" in name:
                # Örn: "Saving Throw: DEX" -> "DEX +5"
                stat = name.replace("Saving Throw:", "").strip()
                saves.append(f"{stat} {sign}{val}")
            elif "Skill:" in name:
                # Örn: "Skill: Perception" -> "Perception +6"
                skill_name = name.replace("Skill:", "").strip()
                skills.append(f"{skill_name} {sign}{val}")

        # 4. Action/Trait Formatlama Yardımcısı
        def format_actions(action_list):
            formatted = []
            for action in action_list:
                name = action.get("name", "Action")
                desc = action.get("desc", "")
                # API bazen 'attack_bonus' veya 'damage' verir ama bunlar genellikle 'desc' metninde yazılıdır.
                # Biz sadece temiz name/desc ikilisini alıyoruz.
                formatted.append({"name": name, "desc": desc})
            return formatted

        # 5. BÜYÜ TESPİTİ (Spellcasting Detection)
        detected_spells = []
        # special_abilities içinde 'spellcasting' anahtarı olan bir yetenek arıyoruz
        for ability in data.get("special_abilities", []):
            if "spellcasting" in ability:
                # ability["spellcasting"]["spells"] -> [{"name": "Fireball", "url": ".../fireball"}]
                spells_list = ability["spellcasting"].get("spells", [])
                for spell_ref in spells_list:
                    url = spell_ref.get("url")
                    if url:
                        # URL sonundaki index'i al (örn: "fireball")
                        index = url.rstrip("/").split("/")[-1]
                        detected_spells.append(index)

        # 6. Veri Sözlüğünü Oluştur
        return {
            "name": data.get("name"),
            "type": "Canavar",
            "description": f"Size: {data.get('size')}, Type: {data.get('type')}, Alignment: {data.get('alignment')}",
            "tags": [data.get("type", ""), data.get("size", "")],
            "image_path": "", # API resimleri online URL'dir, lokalde yoksa boş bırakıyoruz

            # Temel Statlar
            "stats": {
                "STR": data.get("strength", 10),
                "DEX": data.get("dexterity", 10),
                "CON": data.get("constitution", 10),
                "INT": data.get("intelligence", 10),
                "WIS": data.get("wisdom", 10),
                "CHA": data.get("charisma", 10)
            },
            
            # Savaş Statları
            "combat_stats": {
                "hp": str(data.get("hit_points", 10)),
                "max_hp": f"{data.get('hit_points', 10)} ({data.get('hit_dice', '')})",
                "ac": str(ac_val),
                "speed": speed_str,
                "cr": str(data.get("challenge_rating", 0)),
                "xp": str(data.get("xp", 0)),
                "initiative": "" # Genelde DEX'ten hesaplanır, boş bırakıyoruz
            },

            # Gelişmiş Statlar
            "saving_throws": ", ".join(saves),
            "skills": ", ".join(skills),
            "damage_vulnerabilities": ", ".join(data.get("damage_vulnerabilities", [])),
            "damage_resistances": ", ".join(data.get("damage_resistances", [])),
            "damage_immunities": ", ".join(data.get("damage_immunities", [])),
            "condition_immunities": ", ".join([c["name"] if isinstance(c, dict) else c for c in data.get("condition_immunities", [])]),
            "proficiency_bonus": str(data.get("proficiency_bonus", "")),
            "passive_perception": str(data.get("senses", {}).get("passive_perception", "")),

            # Listeler
            "traits": format_actions(data.get("special_abilities", [])),
            "actions": format_actions(data.get("actions", [])),
            "reactions": format_actions(data.get("reactions", [])),
            "legendary_actions": format_actions(data.get("legendary_actions", [])),
            
            # Ek Özellikler
            "attributes": {
                "Duyular (Senses)": ", ".join([f"{k}: {v}" for k, v in data.get("senses", {}).items() if k != "passive_perception"]),
                "Diller": data.get("languages", "-")
            },

            # GEÇİCİ ALAN (DataManager bunu okuyup silecek)
            "_detected_spell_indices": detected_spells
        }

    def parse_spell(self, data):
        desc = "\n".join(data.get("desc", []))
        if data.get("higher_level"):
            desc += "\n\n**Higher Levels:** " + "\n".join(data.get("higher_level", []))
        
        # Components
        comps = data.get("components", [])
        comp_str = ", ".join(comps)
        if "M" in comps and data.get("material"):
            comp_str += f" ({data.get('material')})"

        # Damage
        dmg_str = ""
        dmg = data.get("damage", {})
        if dmg.get("damage_type"):
            dmg_str = f"Type: {dmg['damage_type'].get('name')}"
        
        if dmg.get("damage_at_slot_level"):
            levels = [f"Lvl {k}: {v}" for k,v in dmg["damage_at_slot_level"].items()]
            # Çok uzun olmasın diye ilk ve sonu alalım veya yan yana yazalım
            dmg_str += " | " + ", ".join(levels[:3]) + ("..." if len(levels)>3 else "")

        classes = [c["name"] for c in data.get("classes", [])]
        
        return {
            "name": data.get("name"),
            "type": "Büyü (Spell)",
            "description": desc,
            "tags": classes + [f"Level {data.get('level')}", data.get("school", {}).get("name", "")],
            "attributes": {
                "Seviye": str(data.get("level")),
                "Okul": data.get("school", {}).get("name", ""),
                "Süre (Casting Time)": data.get("casting_time", ""),
                "Menzil (Range)": data.get("range", ""),
                "Bileşenler": comp_str,
                "Süreklilik (Duration)": ("Concentration, " if data.get("concentration") else "") + data.get("duration", ""),
                "Ritüel": "Evet" if data.get("ritual") else "Hayır",
                "Hasar": dmg_str
            }
        }

    def parse_equipment(self, data):
        desc = "\n".join(data.get("desc", []))
        
        # Maliyet parse
        cost = data.get("cost", {})
        cost_str = f"{cost.get('quantity', 0)} {cost.get('unit', '')}"
        
        # Hasar parse (Silahsa)
        dmg_str = ""
        if data.get("damage"):
            dmg_str = f"{data['damage']['damage_dice']} {data['damage']['damage_type']['name']}"
            
        # Zırh parse
        ac_str = ""
        if data.get("armor_class"):
            ac = data["armor_class"]
            ac_str = str(ac.get("base", 10))
            if ac.get("dex_bonus"): ac_str += " + Dex"
            
        return {
            "name": data.get("name"),
            "type": "Eşya (Equipment)",
            "description": desc,
            "tags": [data.get("equipment_category", {}).get("name", "")],
            "attributes": {
                "Maliyet": cost_str,
                "Ağırlık": str(data.get("weight", 0)) + " lb",
                "Hasar": dmg_str,
                "Zırh Sınıfı (AC)": ac_str,
                "Özellikler": ", ".join([p["name"] for p in data.get("properties", [])])
            }
        }

    # Sınıf ve Irk parserları aynı kalabilir veya detaylandırılabilir
    def parse_class(self, data):
        return {"name": data.get("name"), "type": "Sınıf (Class)", "description": f"Hit Die: d{data.get('hit_die')}", "attributes": {"Hit Die": f"d{data.get('hit_die')}"}}

    def parse_race(self, data):
        return {"name": data.get("name"), "type": "Irk (Race)", "description": f"Speed: {data.get('speed')}", "attributes": {"Hız": str(data.get("speed"))}}