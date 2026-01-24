import requests
import json
from config import API_BASE_URL
from core.locales import tr

class ApiSource:
    """Abstract base class for API sources."""
    def __init__(self, session):
        self.session = session

    def get_list(self, category, page=1, filters=None):
        raise NotImplementedError

    def get_supported_categories(self):
        raise NotImplementedError

    def get_documents(self):
        """Returns list of (slug, title) for available source books."""
        return []

    def get_details(self, category, index):
        """Returns RAW JSON dictionary for the given entry."""
        raise NotImplementedError

    def search(self, category, query):
        raise NotImplementedError

    def download_image_bytes(self, full_url):
        try:
            response = self.session.get(full_url, timeout=15)
            if response.status_code == 200:
                return response.content
            return None
        except Exception as e:
            print(f"Image download error: {e}")
            return None

class Dnd5eApiSource(ApiSource):
    """Legacy API Source (dnd5eapi.co)"""
    def __init__(self, session):
        super().__init__(session)
        self.ENDPOINT_MAP = {
            "NPC": "monsters",
            "Monster": "monsters",
            "Spell": "spells",
            "Equipment": "equipment",
            "Class": "classes",
            "Race": "races",
            "Magic Item": "magic-items"
        }
        self.DOMAIN_ROOT = "https://www.dnd5eapi.co"

    def get_supported_categories(self):
        return list(self.ENDPOINT_MAP.keys())

    def get_list(self, category, page=1, filters=None):
        # D&D 5e API does not support pagination/filtering in list endpoint naturally in this implementation
        endpoint = self.ENDPOINT_MAP.get(category)
        if not endpoint:
            if category == "Equipment":
                l1 = self._fetch_all("equipment")
                l2 = self._fetch_all("magic-items")
                return {"results": l1 + l2, "count": len(l1)+len(l2), "next": None, "previous": None}
            return {"results": [], "count": 0, "next": None, "previous": None}
        
        if filters and filters.get("search"):
            search_query = filters["search"].lower()
            results = [x for x in self._fetch_all(endpoint) if search_query in x.get("name", "").lower()]
        else:
            results = self._fetch_all(endpoint)
            
        return {"results": results, "count": len(results), "next": None, "previous": None}

    def _fetch_all(self, endpoint):
        url = f"{API_BASE_URL}/{endpoint}"
        try:
            response = self.session.get(url, timeout=10)
            if response.status_code == 200:
                return response.json().get("results", [])
            return []
        except Exception:
            return []

    def get_details(self, category, index):
        endpoint = self.ENDPOINT_MAP.get(category)
        if not endpoint: return None

        # Dnd5e lookup by index
        url = f"{API_BASE_URL}/{endpoint}/{index}"
        try:
            response = self.session.get(url, timeout=10)
            if response.status_code == 200:
                return response.json()
             
            # Fallback for Equipment/Magic Item ambiguity
            if category == "Equipment":
                 url2 = f"{API_BASE_URL}/magic-items/{index}"
                 resp2 = self.session.get(url2, timeout=10)
                 if resp2.status_code == 200: return resp2.json()
            
            return None
        except Exception as e:
            print(f"Dnd5e Details Error: {e}")
            return None

    def search(self, category, query):
        # Existing search logic actually fetches details because Dnd5e "search" is just by index (slug)
        # But for compatibility we keep it. However, now DataManager will prefer get_details logic.
        raw_data = self.get_details(category, query)
        if raw_data:
             if category == "Equipment" and "equipment_category" not in raw_data and "desc" in raw_data and "rarity" in raw_data:
                 return self.parse_equipment(raw_data), tr("MSG_FOUND_MAGIC_ITEM")
             return self.parse_dispatcher(category, raw_data), tr("MSG_SEARCH_SUCCESS")
        return None, tr("MSG_SEARCH_NOT_FOUND")

    def parse_dispatcher(self, category, data):
        if category in ["Monster", "NPC"]:
            return self.parse_monster(data)
        elif category == "Spell":
            return self.parse_spell(data)
        elif category == "Equipment":
            return self.parse_equipment(data)
        elif category == "Class":
            return self.parse_class(data)
        elif category == "Race":
            return self.parse_race(data)
        return {}

    def parse_monster(self, data):
        # 1. AC Parse
        ac_val = "10"
        raw_ac = data.get("armor_class", [])
        if isinstance(raw_ac, list) and len(raw_ac) > 0:
            ac_entry = raw_ac[0]
            ac_val = f"{ac_entry.get('value', 10)}"
            if ac_entry.get('type'): ac_val += f" ({ac_entry.get('type')})"
        else:
            ac_val = str(data.get("armor_class", 10))

        # 2. Hız Parse
        speed_dict = data.get("speed", {})
        speed_str = ", ".join([f"{k.capitalize()} {v}" for k, v in speed_dict.items()])

        # 3. Saves & Skills Parse
        saves, skills = [], []
        for prof in data.get("proficiencies", []):
            name = prof.get("proficiency", {}).get("name", "")
            val = prof.get("value", 0)
            sign = "+" if val >= 0 else ""
            
            if "Saving Throw:" in name:
                stat = name.replace("Saving Throw:", "").strip()
                saves.append(f"{stat} {sign}{val}")
            elif "Skill:" in name:
                skill_label = name.replace("Skill:", "").strip()
                skills.append(f"{skill_label} {sign}{val}")

        # 4. Action/Trait Formatlama Yardımcısı
        def format_actions(action_list):
            return [{"name": a.get("name", "Action"), "desc": a.get("desc", "")} for a in action_list]

        # 5. BAĞIMLILIK TESPİTİ (Büyü ve Ekipman)
        detected_spells = []
        for ability in data.get("special_abilities", []):
            if "spellcasting" in ability:
                for spell_ref in ability["spellcasting"].get("spells", []):
                    url = spell_ref.get("url")
                    if url: detected_spells.append(url.rstrip("/").split("/")[-1])

        detected_equipment = []
        if "equipment" in data:
            for item in data["equipment"]:
                url = item.get("equipment", {}).get("url") if isinstance(item, dict) else None
                if url: detected_equipment.append(url.rstrip("/").split("/")[-1])

        # 6. RESİM URL TESPİTİ
        local_img = data.get("local_image_path", "")
        remote_image_url = ""
        if not local_img and data.get("image"):
            remote_image_url = self.DOMAIN_ROOT + data.get("image")

        return {
            "name": data.get("name"),
            "type": "Monster",
            "description": f"Size: {data.get('size')}, Type: {data.get('type')}, Align: {data.get('alignment')}",
            "source": "SRD 5e (2014)",
            "tags": [data.get("type", ""), data.get("size", "")],
            "image_path": local_img,
            "_remote_image_url": remote_image_url,
            "stats": {
                "STR": data.get("strength", 10), "DEX": data.get("dexterity", 10),
                "CON": data.get("constitution", 10), "INT": data.get("intelligence", 10),
                "WIS": data.get("wisdom", 10), "CHA": data.get("charisma", 10)
            },
            "combat_stats": {
                "hp": str(data.get("hit_points", 10)),
                "max_hp": f"{data.get('hit_points', 10)} ({data.get('hit_dice', '')})",
                "ac": str(ac_val), "speed": speed_str,
                "cr": str(data.get("challenge_rating", 0)), "xp": str(data.get("xp", 0)),
                "initiative": ""
            },
            "saving_throws": ", ".join(saves),
            "skills": ", ".join(skills),
            "damage_vulnerabilities": ", ".join(data.get("damage_vulnerabilities", [])),
            "damage_resistances": ", ".join(data.get("damage_resistances", [])),
            "damage_immunities": ", ".join(data.get("damage_immunities", [])),
            "condition_immunities": ", ".join([c["name"] if isinstance(c, dict) else c for c in data.get("condition_immunities", [])]),
            "proficiency_bonus": str(data.get("proficiency_bonus", "")),
            "passive_perception": str(data.get("senses", {}).get("passive_perception", "")),
            "traits": format_actions(data.get("special_abilities", [])),
            "actions": format_actions(data.get("actions", [])),
            "reactions": format_actions(data.get("reactions", [])),
            "legendary_actions": format_actions(data.get("legendary_actions", [])),
            "attributes": {
                "LBL_CR": str(data.get("challenge_rating", 0)),
                "LBL_ATTACK_TYPE": "Melee / Ranged", 
                "LBL_SENSES": ", ".join([f"{k}: {v}" for k, v in data.get("senses", {}).items() if k != "passive_perception"]),
                "LBL_LANGUAGE": data.get("languages", "-")
            },
            "_detected_spell_indices": detected_spells,
            "_detected_equipment_indices": detected_equipment
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
            "source": "SRD 5e (2014)",
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
            "source": "SRD 5e (2014)",
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
        return {"name": data.get("name"), "type": "Class", "description": f"Hit Die: d{data.get('hit_die')}", "source": "SRD 5e (2014)", "attributes": {"LBL_HIT_DIE": f"d{data.get('hit_die')}"}}

    def parse_race(self, data):
        return {"name": data.get("name"), "type": "Race", "description": f"Speed: {data.get('speed')}", "source": "SRD 5e (2014)", "attributes": {"Hız": str(data.get("speed"))}}


class Open5eApiSource(ApiSource):
    """Open5e API Source"""
    def __init__(self, session):
        super().__init__(session)
        self.BASE_URL = "https://api.open5e.com"
        # Map our Categories to Open5e endpoints
        self.ENDPOINT_MAP = {
            "Monster": "v1/monsters",
            "NPC": "v1/monsters",
            "Spell": "v1/spells",
            "Magic Item": "v1/magicitems",
            "Weapon": "v1/weapons",
            "Armor": "v1/armor",
            "Class": "v1/classes",
            "Race": "v1/races",
            "Background": "v1/backgrounds",
            "Feat": "v1/feats",
            "Condition": "v1/conditions",
            "Plane": "v1/planes"
        }

    def get_supported_categories(self):
        return list(self.ENDPOINT_MAP.keys())

    def get_list(self, category, page=1, filters=None):
        endpoint = self.ENDPOINT_MAP.get(category)
        if not endpoint: return {"results": [], "count": 0, "next": None, "previous": None}
        
        # Base URL
        url = f"{self.BASE_URL}/{endpoint}/?format=json&limit=50&page={page}"
        
        # Apply Filters (specifically 'document__slug' and 'search')
        if filters and isinstance(filters, dict):
            for k, v in filters.items():
                if v: url += f"&{k}={v}"

        try:
            response = self.session.get(url, timeout=10)
            if response.status_code == 200:
                data = response.json()
                results = data.get("results", [])
                
                # Transform list for UI (Name, Index/Slug)
                final_list = []
                for item in results:
                    final_list.append({
                        "name": item.get("name", "Unknown"),
                        "index": item.get("slug") or item.get("key"), # Open5e uses 'slug'
                        "url": item.get("url")
                    })
                return {
                    "results": final_list, 
                    "count": data.get("count", 0), 
                    "next": data.get("next"), 
                    "previous": data.get("previous")
                }
            return {"results": [], "count": 0, "next": None, "previous": None}
        except Exception as e:
            print(f"Open5e List Error: {e}")
            return {"results": [], "count": 0, "next": None, "previous": None}

    def get_documents(self):
        try:
            url = f"{self.BASE_URL}/v1/documents/?format=json&limit=100"
            response = self.session.get(url, timeout=10)
            if response.status_code == 200:
                data = response.json()
                results = data.get("results", [])
                # Return list of (slug, title)
                return [(item.get("slug"), item.get("title")) for item in results]
            return []
        except Exception as e:
            print(f"Open5e Docs Error: {e}")
            return []

    def get_details(self, category, index):
        endpoint = self.ENDPOINT_MAP.get(category)
        if not endpoint: return None

        # Open5e uses 'slug' for lookup usually
        url = f"{self.BASE_URL}/{endpoint}/{index}/?format=json"
        
        try:
            response = self.session.get(url, timeout=10)
            if response.status_code == 200:
                return response.json()
            return None
        except Exception as e:
            print(f"Open5e Details Error: {e}")
            return None

    def search(self, category, query):
        endpoint = self.ENDPOINT_MAP.get(category)
        if not endpoint: return None, tr("MSG_CAT_NOT_SUPPORTED")

        # Open5e doesn't support path-based search like /monsters/{name} directly efficiently without knowing slug.
        # But 'query' here from the UI is actually the 'index/slug' when clicked from list.
        # If it's a raw text search, we should use ?search= param.
        # However, ApiClient.search logic conventionally usually fetches DETAILS by ID.
        # Let's assume 'query' IS the slug if it's coming from on_item_clicked.
        
        url = f"{self.BASE_URL}/{endpoint}/{query}/?format=json"
        
        try:
            response = self.session.get(url, timeout=10)
            if response.status_code == 200:
                return self.parse_dispatcher(category, response.json()), tr("MSG_SEARCH_SUCCESS")
            return None, tr("MSG_SEARCH_NOT_FOUND")
        except Exception as e:
            return None, str(e)

    def parse_dispatcher(self, category, data):
        if category in ["Monster", "NPC"]: return self.parse_monster(data)
        elif category == "Spell": return self.parse_spell(data)
        elif category in ["Magic Item", "Weapon", "Armor"]: return self.parse_item(data)
        elif category == "Feat": return self.parse_feat(data)
        elif category == "Background": return self.parse_background(data)
        elif category == "Plane": return self.parse_plane(data)
        elif category == "Condition": return self.parse_condition(data)
        # Fallback generic parse
        return self.parse_generic(category, data)

    def parse_generic(self, category, data):
        # Open5e'de açıklama 'desc' içindedir. Eğer liste ise birleştir.
        desc = data.get("desc", data.get("description", ""))
        if isinstance(desc, list): desc = "\n".join(desc)
        
        return {
            "name": data.get("name", "Unknown"),
            "type": category,
            "description": desc,
            "source": self._get_source_str(data),
            "attributes": data.get("attributes", {}) # Varsa öznitelikleri al
        }

    def _get_source_str(self, data):
        # Eğer DataManager tarafından meta veri enjekte edildiyse onu kullan
        if "_meta_source" in data:
            return data["_meta_source"]
            
        doc = data.get("document__title") or data.get("document", {}).get("title", "")
        return f"Open5e - {doc}" if doc else "Open5e"

    def parse_monster(self, data):
        # Open5e format is slightly different but similar keys
        ac_val = str(data.get("armor_class", 10))
        speed_dict = data.get("speed", {})
        speed_str = ", ".join([f"{k} {v}" for k, v in speed_dict.items()]) if isinstance(speed_dict, dict) else str(speed_dict)

        # Actions
        def format_actions(action_list):
            if not action_list: return []
            return [{"name": a.get("name", "Action"), "desc": a.get("desc", "")} for a in action_list]

        desc = data.get("desc", "")
        if not desc: desc = data.get("description", "")
        if isinstance(desc, list): desc = "\n".join(desc)

        return {
            "name": data.get("name"),
            "type": "Monster",
            "description": desc + f"\n\n{data.get('legendary_desc', '')}",
            "source": self._get_source_str(data),
            "tags": [data.get("type", ""), data.get("size", ""), data.get("subtype", "")],
            "image_path": "", # Open5e rarely has images directly or uses img_main
            "_remote_image_url": data.get("img_main", ""),
            "stats": {
                "STR": data.get("strength", 10), "DEX": data.get("dexterity", 10),
                "CON": data.get("constitution", 10), "INT": data.get("intelligence", 10),
                "WIS": data.get("wisdom", 10), "CHA": data.get("charisma", 10)
            },
            "combat_stats": {
                "hp": str(data.get("hit_points", 10)),
                "max_hp": f"{data.get('hit_points', 10)} ({data.get('hit_dice', '')})",
                "ac": str(ac_val), "speed": speed_str,
                "cr": str(data.get("challenge_rating", 0)), "xp": "",
                "initiative": ""
            },
            "saving_throws": f"STR {data.get('strength_save')}" if data.get('strength_save') else "", # Simplified, Open5e provides precise save values sometimes
            "skills": json_dict_to_str(data.get("skills", {})),
            "damage_vulnerabilities": data.get("damage_vulnerabilities", ""),
            "damage_resistances": data.get("damage_resistances", ""),
            "damage_immunities": data.get("damage_immunities", ""),
            "condition_immunities": data.get("condition_immunities", ""),
            "proficiency_bonus": "",
            "passive_perception": str(data.get("perception", "")), # Open5e keys differ
            "traits": format_actions(data.get("special_abilities", [])),
            "actions": format_actions(data.get("actions", [])),
            "reactions": format_actions(data.get("reactions", [])),
            "legendary_actions": format_actions(data.get("legendary_actions", [])),
            "attributes": {
                "LBL_CR": str(data.get("challenge_rating", 0)),
                "LBL_SENSES": data.get("senses", ""),
                "LBL_LANGUAGE": data.get("languages", "-")
            }
        }

    def parse_spell(self, data):
        return {
            "name": data.get("name"),
            "type": "Spell",
            "description": data.get("desc", ""),
            "source": self._get_source_str(data),
            "tags": [f"Level {data.get('level_int', 0)}", data.get("school", ""), data.get("dnd_class", "")],
            "attributes": {
                "LBL_LEVEL": data.get("level", ""),
                "LBL_SCHOOL": data.get("school", ""),
                "LBL_CASTING_TIME": data.get("casting_time", ""),
                "LBL_RANGE": data.get("range", ""),
                "LBL_COMPONENTS": data.get("components", ""),
                "LBL_DURATION": ("C, " if data.get("concentration") == "yes" else "") + data.get("duration", ""),
                "LBL_RITUAL": "Yes" if data.get("ritual") == "yes" else "No"
            }
        }
    
    def parse_item(self, data):
        # Open5e'den gelen Armor, Weapon veya Magic Item verilerini 
        # her zaman 'Equipment' tipine zorluyoruz.
        return {
            "name": data.get("name", "Unknown Item"),
            "type": "Equipment", # Burası 'Armor' veya 'Weapon' kalırsa sistem NPC sanabilir
            "description": data.get("desc", data.get("description", "")),
            "source": self._get_source_str(data),
            "tags": [data.get("type", ""), data.get("rarity", "")],
            "attributes": {
                "LBL_RARITY": data.get("rarity", ""),
                "LBL_ATTUNEMENT": data.get("requires_attunement", ""),
                "Category": data.get("category", ""),
                "Cost": data.get("cost", ""),
                "Weight": data.get("weight", "")
            }
        }

    def parse_feat(self, data):
        return {
            "name": data.get("name"),
            "type": "Feat",
            "description": data.get("desc", ""),
            "source": self._get_source_str(data),
            "attributes": {
                "LBL_PREREQUISITE": data.get("prerequisite", "")
            }
        }

    def parse_background(self, data):
        # Open5e Backgrounds
        return {
            "name": data.get("name"),
            "type": "Background",
            "description": f"{data.get('desc', '')}\n\nFeature: {data.get('feature', '')}\n{data.get('feature_desc', '')}",
            "source": self._get_source_str(data),
            "attributes": {
                "LBL_SKILL_PROFICIENCIES": data.get("skill_proficiencies", ""),
                "LBL_TOOL_PROFICIENCIES": data.get("tool_proficiencies", ""),
                "LBL_LANGUAGES": data.get("languages", ""),
                "LBL_EQUIPMENT": data.get("equipment", "")
            }
        }

    def parse_plane(self, data):
        return {
            "name": data.get("name"),
            "type": "Plane",
            "description": data.get("desc", ""),
            "source": self._get_source_str(data),
            "attributes": {} 
        }

    def parse_condition(self, data):
        return {
            "name": data.get("name"),
            "type": "Condition",
            "description": data.get("desc", ""),
            "source": self._get_source_str(data),
            "attributes": {}
        }


def json_dict_to_str(d):
    if not d: return ""
    return ", ".join([f"{k}: {v}" for k, v in d.items()])

class DndApiClient:
    def __init__(self):
        self.session = requests.Session()
        self.session.verify = True 
        
        self.sources = {
            "dnd5e": Dnd5eApiSource(self.session),
            "open5e": Open5eApiSource(self.session)
        }
        self.current_source_key = "dnd5e"

    @property
    def current_source(self):
        return self.sources[self.current_source_key]

    def set_source(self, key):
        if key in self.sources:
            self.current_source_key = key

    def get_available_sources(self):
        return [("dnd5e", "D&D 5e API (Official SRD)"), ("open5e", "Open5e API (Community)")]

    def get_supported_categories(self):
        return self.current_source.get_supported_categories()

    def get_list(self, category, page=1, filters=None):
        return self.current_source.get_list(category, page=page, filters=filters)

    def get_documents(self):
        return self.current_source.get_documents()

    def get_details(self, category, index):
        return self.current_source.get_details(category, index)

    def search(self, category, query):
        return self.current_source.search(category, query)

    def download_image_bytes(self, full_url):
        return self.current_source.download_image_bytes(full_url)

    def parse_dispatcher(self, category, data):
        # --- GÜVENLİK DUVARI: Verinin sözlük olduğundan emin ol ---
        if isinstance(data, str):
            try:
                data = json.loads(data)
            except:
                return {"name": "Parse Error", "type": category, "description": str(data)}

        # İlgili kaynağın (dnd5e/open5e) parse işlemini yap
        result = self.current_source.parse_dispatcher(category, data)
        
        # Eğer sonuç sözlük değilse (hata payı)
        if not isinstance(result, dict):
            result = {"name": "Data Error", "type": category, "description": str(result)}

        # Kaynak bilgilerini işle
        result["api_source"] = getattr(self, "current_source_key", "unknown")
        
        # Eğer Ham veride DataManager tarafından zorlanmış bir kaynak ismi varsa, onu kullan
        if isinstance(data, dict) and "_meta_source" in data:
            result["source"] = data["_meta_source"]
            
        return result