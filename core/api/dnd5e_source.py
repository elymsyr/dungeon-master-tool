import logging

from config import API_BASE_URL
from core.locales import tr
from core.api.base_source import ApiSource
from core.api.entity_parser import MonsterParser

logger = logging.getLogger(__name__)

DOMAIN_ROOT = "https://www.dnd5eapi.co"

ENDPOINT_MAP = {
    "NPC": "monsters",
    "Monster": "monsters",
    "Spell": "spells",
    "Equipment": "equipment",
    "Class": "classes",
    "Race": "races",
    "Magic Item": "magic-items",
}


class Dnd5eApiSource(ApiSource):
    """Legacy API Source (dnd5eapi.co)"""

    def __init__(self, session):
        super().__init__(session)
        self.ENDPOINT_MAP = ENDPOINT_MAP
        self.DOMAIN_ROOT = DOMAIN_ROOT

    def get_supported_categories(self):
        return list(self.ENDPOINT_MAP.keys())

    def get_list(self, category, page=1, filters=None):
        endpoint = self.ENDPOINT_MAP.get(category)
        if not endpoint:
            if category == "Equipment":
                l1 = self._fetch_all("equipment")
                l2 = self._fetch_all("magic-items")
                return {"results": l1 + l2, "count": len(l1) + len(l2), "next": None, "previous": None}
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
        if not endpoint:
            return None

        url = f"{API_BASE_URL}/{endpoint}/{index}"
        try:
            response = self.session.get(url, timeout=10)
            if response.status_code == 200:
                return response.json()

            if category == "Equipment":
                url2 = f"{API_BASE_URL}/magic-items/{index}"
                resp2 = self.session.get(url2, timeout=10)
                if resp2.status_code == 200:
                    return resp2.json()

            return None
        except Exception as e:
            logger.error("Dnd5e details error: %s", e)
            return None

    def search(self, category, query):
        raw_data = self.get_details(category, query)
        if raw_data:
            if (
                category == "Equipment"
                and "equipment_category" not in raw_data
                and "desc" in raw_data
                and "rarity" in raw_data
            ):
                return self.parse_equipment(raw_data), tr("MSG_FOUND_MAGIC_ITEM")
            return self.parse_dispatcher(category, raw_data), tr("MSG_SEARCH_SUCCESS")
        return None, tr("MSG_SEARCH_NOT_FOUND")

    def parse_dispatcher(self, category, data):
        if category in ["Monster", "NPC"]:
            return self.parse_monster(data)
        elif category == "Spell":
            return self.parse_spell(data)
        elif category in ["Equipment", "Magic Item"]:
            return self.parse_equipment(data)
        elif category == "Class":
            return self.parse_class(data)
        elif category == "Race":
            return self.parse_race(data)
        return {}

    def parse_monster(self, data):
        return MonsterParser.from_dnd5e(data, domain_root=self.DOMAIN_ROOT)

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
            levels = [f"Lvl {k}: {v}" for k, v in dmg["damage_at_slot_level"].items()]
            dmg_str += " | " + ", ".join(levels[:3]) + ("..." if len(levels) > 3 else "")

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
                "LBL_DURATION": (
                    ("Concentration, " if data.get("concentration") else "") + data.get("duration", "")
                ),
                "LBL_RITUAL": "LBL_YES" if data.get("ritual") else "LBL_NO",
                "LBL_DAMAGE": dmg_str,
            },
        }

    def parse_equipment(self, data):
        desc_list = data.get("desc", [])
        description = "\n".join(desc_list) if isinstance(desc_list, list) else str(desc_list)
        cat_main = data.get("equipment_category", {}).get("name", tr("LBL_GENERAL_CAT"))
        sub_cats = []
        if data.get("weapon_category"):
            sub_cats.append(data["weapon_category"])
        if data.get("armor_category"):
            sub_cats.append(data["armor_category"])
        if data.get("vehicle_category"):
            sub_cats.append(data["vehicle_category"])
        if data.get("tool_category"):
            sub_cats.append(data["tool_category"])
        if data.get("gear_category"):
            gc = data["gear_category"]
            sub_cats.append(gc.get("name") if isinstance(gc, dict) else str(gc))
        if data.get("category_range"):
            sub_cats.append(data["category_range"])
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
            long_ = data["range"].get("long")
            if norm:
                range_str = f"{norm} ft."
                if long_:
                    range_str += f" / {long_} ft."

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
                    if max_bonus:
                        ac_str += f" (max {max_bonus})"
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
                "LBL_PROPERTIES": prop_str,
            },
        }

    def parse_class(self, data):
        return {
            "name": data.get("name"),
            "type": "Class",
            "description": f"Hit Die: d{data.get('hit_die')}",
            "source": "SRD 5e (2014)",
            "attributes": {"LBL_HIT_DIE": f"d{data.get('hit_die')}"},
        }

    def parse_race(self, data):
        return {
            "name": data.get("name"),
            "type": "Race",
            "description": f"Speed: {data.get('speed')}",
            "source": "SRD 5e (2014)",
            "attributes": {"LBL_SPEED": str(data.get("speed"))},
        }
