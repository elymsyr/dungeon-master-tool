import requests
from config import API_BASE_URL
from core.locales import tr

class DndApiClient:
    def __init__(self):
        self.session = requests.Session()
        
        # SOLVED: Enable SSL verification for security.
        # If you get an SSLError, ensure 'pip install --upgrade certifi' is run.
        self.session.verify = True 
        
        self.ENDPOINT_MAP = {
            "NPC": "monsters",
            "Monster": "monsters",
            "Spell": "spells",
            "Equipment": "equipment",
            "Class": "classes",
            "Race": "races",
            "Magic Item": "magic-items"
        }
        # The API base is .../api, but images are at the root
        self.DOMAIN_ROOT = "https://www.dnd5eapi.co"

    def get_list(self, category):
        endpoint = self.ENDPOINT_MAP.get(category)
        if not endpoint:
            if category == "Equipment":
                l1 = self._fetch_all("equipment")
                l2 = self._fetch_all("magic-items")
                return l1 + l2
            return []
        return self._fetch_all(endpoint)

    def _fetch_all(self, endpoint):
        url = f"{API_BASE_URL}/{endpoint}"
        try:
            # Added verify=True explicit (though session handles it)
            response = self.session.get(url, timeout=10)
            if response.status_code == 200:
                return response.json().get("results", [])
            return []
        except Exception:
            return []

    def search(self, category, query):
        endpoint = self.ENDPOINT_MAP.get(category)
        if not endpoint: return None, tr("MSG_CAT_NOT_SUPPORTED")

        formatted_query = query.lower().strip().replace(" ", "-")
        url = f"{API_BASE_URL}/{endpoint}/{formatted_query}"
        
        try:
            response = self.session.get(url, timeout=10)
            if response.status_code == 200:
                return self.parse_dispatcher(category, response.json()), tr("MSG_SEARCH_SUCCESS")
            
            if category == "Equipment":
                url2 = f"{API_BASE_URL}/magic-items/{formatted_query}"
                resp2 = self.session.get(url2, timeout=10)
                if resp2.status_code == 200:
                    return self.parse_equipment(resp2.json()), tr("MSG_FOUND_MAGIC_ITEM")

            return None, tr("MSG_SEARCH_NOT_FOUND")
        except Exception as e:
            return None, str(e)

    def download_image_bytes(self, full_url):
        """Downloads image data from the full URL."""
        try:
            response = self.session.get(full_url, timeout=15)
            if response.status_code == 200:
                return response.content
            return None
        except Exception as e:
            print(f"Image download error: {e}")
            return None

    def parse_dispatcher(self, category, data):
        if category in ["Monster", "NPC"]: return self.parse_monster(data)
        elif category == "Spell": return self.parse_spell(data)
        elif category == "Equipment": return self.parse_equipment(data)
        elif category == "Class": return self.parse_class(data)
        elif category == "Race": return self.parse_race(data)
        return {}

    def parse_monster(self, data):
        """
        API'den gelen ham canavar verisini uygulamanın veri yapısına çevirir.
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

        # 3. Saves & Skills Parse
        saves = []
        skills = []
        for prof in data.get("proficiencies", []):
            name = prof.get("proficiency", {}).get("name", "")
            val = prof.get("value", 0)
            sign = "+" if val >= 0 else ""
            
            if "Saving Throw:" in name:
                stat = name.replace("Saving Throw:", "").strip()
                saves.append(f"{stat} {sign}{val}")
            elif "Skill:" in name:
                skill_name = name.replace("Skill:", "").strip()
                skills.append(f"{skill_name} {sign}{val}")

        # 4. Action/Trait Formatlama Yardımcısı
        def format_actions(action_list):
            formatted = []
            for action in action_list:
                name = action.get("name", "Action")
                desc = action.get("desc", "")
                formatted.append({"name": name, "desc": desc})
            return formatted

        # 5. BÜYÜ TESPİTİ
        detected_spells = []
        for ability in data.get("special_abilities", []):
            if "spellcasting" in ability:
                spells_list = ability["spellcasting"].get("spells", [])
                for spell_ref in spells_list:
                    url = spell_ref.get("url")
                    if url:
                        index = url.rstrip("/").split("/")[-1]
                        detected_spells.append(index)

        # 6. RESİM URL TESPİTİ
        remote_image_url = ""
        if data.get("image"):
            remote_image_url = self.DOMAIN_ROOT + data.get("image")

        # 7. Veri Sözlüğünü Oluştur
        return {
            "name": data.get("name"),
            "type": "Monster",
            "description": f"Size: {data.get('size')}, Type: {data.get('type')}, Alignment: {data.get('alignment')}",
            "tags": [data.get("type", ""), data.get("size", "")],
            "image_path": "", # Local path will be filled by DataManager
            
            # Temporary field for DataManager
            "_remote_image_url": remote_image_url,

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
                "initiative": ""
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
                "LBL_CR": str(data.get("challenge_rating", 0)),
                "LBL_ATTACK_TYPE": "Melee / Ranged", 
                "LBL_SENSES": ", ".join([f"{k}: {v}" for k, v in data.get("senses", {}).items() if k != "passive_perception"]),
                "LBL_LANGUAGE": data.get("languages", "-")
            },

            # GEÇİCİ ALAN
            "_detected_spell_indices": detected_spells
        }

    def parse_spell(self, data):
        desc = "\n".join(data.get("desc", []))
        if data.get("higher_level"):
            desc += "\n\n**Higher Levels:** " + "\n".join(data.get("higher_level", []))
        
        comps = data.get("components", [])
        comp_str = ", ".join(comps)
        if "M" in comps and data.get("material"):
            comp_str += f" ({data.get('material')})"

        dmg_str = ""
        dmg = data.get("damage", {})
        if dmg.get("damage_type"):
            dmg_str = f"Type: {dmg['damage_type'].get('name')}"
        
        if dmg.get("damage_at_slot_level"):
            levels = [f"Lvl {k}: {v}" for k,v in dmg["damage_at_slot_level"].items()]
            dmg_str += " | " + ", ".join(levels[:3]) + ("..." if len(levels)>3 else "")

        classes = [c["name"] for c in data.get("classes", [])]
        
        return {
            "name": data.get("name"),
            "type": "Spell",
            "description": desc,
            "tags": classes + [f"Level {data.get('level')}", data.get("school", {}).get("name", "")],
            "attributes": {
                "LBL_LEVEL": str(data.get("level")),
                "LBL_SCHOOL": data.get("school", {}).get("name", ""),
                "LBL_CASTING_TIME": data.get("casting_time", ""),
                "LBL_RANGE": data.get("range", ""),
                "LBL_COMPONENTS": comp_str,
                "LBL_DURATION": ("Concentration, " if data.get("concentration") else "") + data.get("duration", ""),
                "LBL_RITUAL": "LBL_YES" if data.get("ritual") else "LBL_NO",
                "LBL_DAMAGE": dmg_str
            }
        }
    
    def parse_equipment(self, data):
        desc_list = data.get("desc", [])
        description = "\n".join(desc_list) if isinstance(desc_list, list) else str(desc_list)
        cat_main = data.get("equipment_category", {}).get("name", tr("LBL_GENERAL_CAT"))
        sub_cats = []
        if data.get("weapon_category"): sub_cats.append(data["weapon_category"])
        if data.get("armor_category"): sub_cats.append(data["armor_category"])
        if data.get("vehicle_category"): sub_cats.append(data["vehicle_category"])
        if data.get("tool_category"): sub_cats.append(data["tool_category"])
        if data.get("gear_category"): 
            gc = data["gear_category"]
            sub_cats.append(gc.get("name") if isinstance(gc, dict) else str(gc))
        if data.get("category_range"): sub_cats.append(data["category_range"])
        full_sub_cat = ", ".join([s for s in sub_cats if s])
        final_category = f"{cat_main} ({full_sub_cat})" if full_sub_cat else cat_main
        tags = [cat_main] + sub_cats
        cost_str = "-"
        if data.get("cost"):
            q = data["cost"].get("quantity", 0)
            u = data["cost"].get("unit", "gp")
            cost_str = f"{q} {u}"
        damage_dice = ""
        damage_type = ""
        if data.get("damage"):
            damage_dice = data["damage"].get("damage_dice", "")
            if data["damage"].get("damage_type"):
                damage_type = data["damage"]["damage_type"].get("name", "")
        if data.get("two_handed_damage"):
            th_dice = data["two_handed_damage"].get("damage_dice")
            if th_dice:
                damage_dice += f" (2H: {th_dice})"
        range_str = ""
        if data.get("range"):
            norm = data["range"].get("normal")
            long = data["range"].get("long")
            if norm:
                range_str = f"{norm} ft."
                if long: range_str += f" / {long} ft."
        ac_str = ""
        if data.get("armor_class"):
            ac_data = data["armor_class"]
            if isinstance(ac_data, dict):
                base = ac_data.get("base", 10)
                dex = ac_data.get("dex_bonus", False)
                max_bonus = ac_data.get("max_bonus")
                ac_str = str(base)
                if dex:
                    ac_str += " + Dex"
                    if max_bonus: ac_str += f" (max {max_bonus})"
            else:
                ac_str = str(ac_data)
        reqs = []
        if data.get("str_minimum") and int(data.get("str_minimum", 0)) > 0:
            reqs.append(f"Min Str {data['str_minimum']}")
        if data.get("stealth_disadvantage"):
            reqs.append("Stealth Disadv.")
        req_str = ", ".join(reqs)
        props = [p.get("name", "") for p in data.get("properties", [])]
        if data.get("speed"):
            s = data["speed"]
            val = f"{s.get('quantity')} {s.get('unit')}" if isinstance(s, dict) else s
            props.append(f"{tr('LBL_PROP_SPEED')}: {val}")
        if data.get("capacity"):
            props.append(f"{tr('LBL_PROP_CAPACITY')}: {data['capacity']}")
        prop_str = ", ".join(props)
        rarity = ""
        if data.get("rarity"):
            rarity = data["rarity"].get("name", "")
        attunement = tr("LBL_NO_ATTUNEMENT")
        if "requires attunement" in description.lower():
            attunement = tr("LBL_REQ_ATTUNEMENT")
        return {
            "name": data.get("name"),
            "type": "Equipment",
            "description": description,
            "tags": tags,
            "attributes": {
                "LBL_CATEGORY": final_category,
                "LBL_RARITY": rarity,
                "LBL_ATTUNEMENT": attunement,
                "LBL_COST": cost_str,
                "LBL_WEIGHT": f"{data.get('weight', 0)} lb.",
                "LBL_DAMAGE_DICE": damage_dice,
                "LBL_DAMAGE_TYPE": damage_type,
                "LBL_RANGE": range_str,
                "LBL_AC": ac_str,
                "LBL_REQUIREMENTS": req_str,
                "LBL_PROPERTIES": prop_str
            }
        }

    def parse_class(self, data):
        return {"name": data.get("name"), "type": "Class", "description": f"Hit Die: d{data.get('hit_die')}", "attributes": {"LBL_HIT_DIE": f"d{data.get('hit_die')}"}}

    def parse_race(self, data):
        return {"name": data.get("name"), "type": "Irk (Race)", "description": f"Speed: {data.get('speed')}", "attributes": {"Hız": str(data.get("speed"))}}