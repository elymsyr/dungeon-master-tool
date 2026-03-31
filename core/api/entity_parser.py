"""Shared entity parsers used by multiple API sources.

MonsterParser centralises the two previously duplicated parse_monster()
implementations (Dnd5eApiSource and Open5eApiSource) behind two class
methods that handle the format differences before building the shared
output schema.
"""

from core.api.field_mappers import format_actions, json_dict_to_str


class MonsterParser:
    """Builds the canonical monster entity dict from raw source data."""

    @classmethod
    def from_dnd5e(cls, data, domain_root="https://www.dnd5eapi.co"):
        # 1. AC
        ac_val = "10"
        raw_ac = data.get("armor_class", [])
        if isinstance(raw_ac, list) and raw_ac:
            ac_entry = raw_ac[0]
            ac_val = f"{ac_entry.get('value', 10)}"
            if ac_entry.get("type"):
                ac_val += f" ({ac_entry.get('type')})"
        else:
            ac_val = str(data.get("armor_class", 10))

        # 2. Speed
        speed_dict = data.get("speed", {})
        speed_str = ", ".join([f"{k.capitalize()} {v}" for k, v in speed_dict.items()])

        # 3. Saves & Skills from proficiencies list
        saves, skills = [], []
        for prof in data.get("proficiencies", []):
            name = prof.get("proficiency", {}).get("name", "")
            val = prof.get("value", 0)
            sign = "+" if val >= 0 else ""
            if "Saving Throw:" in name:
                saves.append(f"{name.replace('Saving Throw:', '').strip()} {sign}{val}")
            elif "Skill:" in name:
                skills.append(f"{name.replace('Skill:', '').strip()} {sign}{val}")

        # 4. Dependency detection
        detected_spells = []
        for ability in data.get("special_abilities", []):
            if "spellcasting" in ability:
                for spell_ref in ability["spellcasting"].get("spells", []):
                    url = spell_ref.get("url")
                    if url:
                        detected_spells.append(url.rstrip("/").split("/")[-1])

        detected_equipment = []
        if "equipment" in data:
            for item in data["equipment"]:
                url = item.get("equipment", {}).get("url") if isinstance(item, dict) else None
                if url:
                    detected_equipment.append(url.rstrip("/").split("/")[-1])

        # 5. Image
        local_img = data.get("local_image_path", "")
        remote_image_url = ""
        if not local_img and data.get("image"):
            remote_image_url = domain_root + data.get("image")

        return {
            "name": data.get("name"),
            "type": "Monster",
            "description": (
                f"Size: {data.get('size')}, Type: {data.get('type')}, "
                f"Align: {data.get('alignment')}"
            ),
            "source": "SRD 5e (2014)",
            "tags": [data.get("type", ""), data.get("size", "")],
            "image_path": local_img,
            "_remote_image_url": remote_image_url,
            "stats": {
                "STR": data.get("strength", 10),
                "DEX": data.get("dexterity", 10),
                "CON": data.get("constitution", 10),
                "INT": data.get("intelligence", 10),
                "WIS": data.get("wisdom", 10),
                "CHA": data.get("charisma", 10),
            },
            "combat_stats": {
                "hp": str(data.get("hit_points", 10)),
                "max_hp": f"{data.get('hit_points', 10)} ({data.get('hit_dice', '')})",
                "ac": str(ac_val),
                "speed": speed_str,
                "cr": str(data.get("challenge_rating", 0)),
                "xp": str(data.get("xp", 0)),
                "initiative": "",
            },
            "saving_throws": ", ".join(saves),
            "skills": ", ".join(skills),
            "damage_vulnerabilities": ", ".join(data.get("damage_vulnerabilities", [])),
            "damage_resistances": ", ".join(data.get("damage_resistances", [])),
            "damage_immunities": ", ".join(data.get("damage_immunities", [])),
            "condition_immunities": ", ".join(
                [c["name"] if isinstance(c, dict) else c for c in data.get("condition_immunities", [])]
            ),
            "proficiency_bonus": str(data.get("proficiency_bonus", "")),
            "passive_perception": str(data.get("senses", {}).get("passive_perception", "")),
            "traits": format_actions(data.get("special_abilities", [])),
            "actions": format_actions(data.get("actions", [])),
            "reactions": format_actions(data.get("reactions", [])),
            "legendary_actions": format_actions(data.get("legendary_actions", [])),
            "attributes": {
                "LBL_CR": str(data.get("challenge_rating", 0)),
                "LBL_ATTACK_TYPE": "Melee / Ranged",
                "LBL_SENSES": ", ".join(
                    [f"{k}: {v}" for k, v in data.get("senses", {}).items() if k != "passive_perception"]
                ),
                "LBL_LANGUAGE": data.get("languages", "-"),
            },
            "_detected_spell_indices": detected_spells,
            "_detected_equipment_indices": detected_equipment,
        }

    @classmethod
    def from_open5e(cls, data, source_str="Open5e"):
        ac_val = str(data.get("armor_class", 10))
        speed_dict = data.get("speed", {})
        speed_str = (
            ", ".join([f"{k} {v}" for k, v in speed_dict.items()])
            if isinstance(speed_dict, dict)
            else str(speed_dict)
        )

        desc = data.get("desc", "")
        if not desc:
            desc = data.get("description", "")
        if isinstance(desc, list):
            desc = "\n".join(desc)

        return {
            "name": data.get("name"),
            "type": "Monster",
            "description": desc + f"\n\n{data.get('legendary_desc', '')}",
            "source": source_str,
            "tags": [data.get("type", ""), data.get("size", ""), data.get("subtype", "")],
            "image_path": "",
            "_remote_image_url": data.get("img_main", ""),
            "stats": {
                "STR": data.get("strength", 10),
                "DEX": data.get("dexterity", 10),
                "CON": data.get("constitution", 10),
                "INT": data.get("intelligence", 10),
                "WIS": data.get("wisdom", 10),
                "CHA": data.get("charisma", 10),
            },
            "combat_stats": {
                "hp": str(data.get("hit_points", 10)),
                "max_hp": f"{data.get('hit_points', 10)} ({data.get('hit_dice', '')})",
                "ac": str(ac_val),
                "speed": speed_str,
                "cr": str(data.get("challenge_rating", 0)),
                "xp": "",
                "initiative": "",
            },
            "saving_throws": (
                f"STR {data.get('strength_save')}" if data.get("strength_save") else ""
            ),
            "skills": json_dict_to_str(data.get("skills", {})),
            "damage_vulnerabilities": data.get("damage_vulnerabilities", ""),
            "damage_resistances": data.get("damage_resistances", ""),
            "damage_immunities": data.get("damage_immunities", ""),
            "condition_immunities": data.get("condition_immunities", ""),
            "proficiency_bonus": "",
            "passive_perception": str(data.get("perception", "")),
            "traits": format_actions(data.get("special_abilities", [])),
            "actions": format_actions(data.get("actions", [])),
            "reactions": format_actions(data.get("reactions", [])),
            "legendary_actions": format_actions(data.get("legendary_actions", [])),
            "attributes": {
                "LBL_CR": str(data.get("challenge_rating", 0)),
                "LBL_SENSES": data.get("senses", ""),
                "LBL_LANGUAGE": data.get("languages", "-"),
            },
        }
