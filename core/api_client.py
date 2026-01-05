import requests
from config import API_BASE_URL

class DndApiClient:
    def __init__(self):
        self.session = requests.Session()
        self.session.verify = False # Bypass SSL verification for reliability
        self.ENDPOINT_MAP = {
            "NPC": "monsters",
            "Monster": "monsters",
            "Spell": "spells",
            "Equipment": "equipment",
            "Class": "classes",
            "Race": "races",
            "Magic Item": "magic-items"
        }

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
            
            if category == "Equipment":
                url2 = f"{API_BASE_URL}/magic-items/{formatted_query}"
                resp2 = self.session.get(url2, timeout=10)
                if resp2.status_code == 200:
                    return self.parse_equipment(resp2.json()), "Magic Item bulundu."

            return None, "Bulunamadı."
        except Exception as e:
            return None, str(e)

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
            "type": "Monster",
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
                "LBL_CR": str(data.get("challenge_rating", 0)),
                "LBL_ATTACK_TYPE": "Melee / Ranged", # API doesn't have a simple field for this
                "LBL_SENSES": ", ".join([f"{k}: {v}" for k, v in data.get("senses", {}).items() if k != "passive_perception"]),
                "LBL_LANGUAGE": data.get("languages", "-")
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
        """
        API verisini ENTITY_SCHEMAS["Eşya (Equipment)"] formatına tam uyumlu hale getirir.
        """
        # 1. AÇIKLAMA (DESC)
        desc_list = data.get("desc", [])
        description = "\n".join(desc_list) if isinstance(desc_list, list) else str(desc_list)
        
        # 2. KATEGORİ (Detaylı)
        # Ana: Weapon, Armor...
        cat_main = data.get("equipment_category", {}).get("name", "Genel")
        
        # Alt: Martial, Heavy, Shield...
        sub_cats = []
        if data.get("weapon_category"): sub_cats.append(data["weapon_category"])
        if data.get("armor_category"): sub_cats.append(data["armor_category"])
        if data.get("vehicle_category"): sub_cats.append(data["vehicle_category"])
        if data.get("tool_category"): sub_cats.append(data["tool_category"])
        if data.get("gear_category"): 
            gc = data["gear_category"]
            sub_cats.append(gc.get("name") if isinstance(gc, dict) else str(gc))
        if data.get("category_range"): sub_cats.append(data["category_range"])
        
        # Boşlukları temizle ve birleştir
        full_sub_cat = ", ".join([s for s in sub_cats if s])
        final_category = f"{cat_main} ({full_sub_cat})" if full_sub_cat else cat_main
        
        # Etiketler (Arama için)
        tags = [cat_main] + sub_cats

        # 3. FİYAT
        cost_str = "-"
        if data.get("cost"):
            q = data["cost"].get("quantity", 0)
            u = data["cost"].get("unit", "gp")
            cost_str = f"{q} {u}"

        # 4. HASAR (Ayrı Ayrı Parse Ediyoruz)
        damage_dice = ""
        damage_type = ""
        
        # Silah hasarı
        if data.get("damage"):
            damage_dice = data["damage"].get("damage_dice", "")
            if data["damage"].get("damage_type"):
                damage_type = data["damage"]["damage_type"].get("name", "")
        
        # Çift el hasarı varsa parantez içinde ekle
        if data.get("two_handed_damage"):
            th_dice = data["two_handed_damage"].get("damage_dice")
            if th_dice:
                damage_dice += f" (2H: {th_dice})"

        # 5. MENZİL
        range_str = ""
        if data.get("range"):
            norm = data["range"].get("normal")
            long = data["range"].get("long")
            if norm:
                range_str = f"{norm} ft."
                if long: range_str += f" / {long} ft."

        # 6. ZIRH SINIFI (AC)
        ac_str = ""
        if data.get("armor_class"):
            ac_data = data["armor_class"]
            # Bazen direkt sayı, bazen dict döner
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

        # 7. GEREKSİNİMLER
        reqs = []
        if data.get("str_minimum") and int(data.get("str_minimum", 0)) > 0:
            reqs.append(f"Min Str {data['str_minimum']}")
        if data.get("stealth_disadvantage"):
            reqs.append("Stealth Disadv.")
        req_str = ", ".join(reqs)

        # 8. ÖZELLİKLER (Properties)
        props = [p.get("name", "") for p in data.get("properties", [])]
        
        # Araç Hızı / Kapasite
        if data.get("speed"):
            s = data["speed"]
            val = f"{s.get('quantity')} {s.get('unit')}" if isinstance(s, dict) else s
            props.append(f"Hız: {val}")
        if data.get("capacity"):
            props.append(f"Kapasite: {data['capacity']}")
            
        prop_str = ", ".join(props)

        # 9. MAGIC ITEM ÖZEL (Rarity / Attunement)
        rarity = ""
        if data.get("rarity"):
            rarity = data["rarity"].get("name", "")
            
        attunement = "Gerekli Değil"
        # Açıklamada 'requires attunement' geçiyor mu?
        if "requires attunement" in description.lower():
            attunement = "Gerekli"

        # 10. ÇIKTI SÖZLÜĞÜ (Models.py ile birebir aynı anahtarlar)
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

    # Sınıf ve Irk parserları aynı kalabilir veya detaylandırılabilir
    def parse_class(self, data):
        return {"name": data.get("name"), "type": "Class", "description": f"Hit Die: d{data.get('hit_die')}", "attributes": {"LBL_HIT_DIE": f"d{data.get('hit_die')}"}}

    def parse_race(self, data):
        return {"name": data.get("name"), "type": "Irk (Race)", "description": f"Speed: {data.get('speed')}", "attributes": {"Hız": str(data.get("speed"))}}