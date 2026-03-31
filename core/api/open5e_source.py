import logging

from core.locales import tr
from core.api.base_source import ApiSource
from core.api.entity_parser import MonsterParser

logger = logging.getLogger(__name__)

ENDPOINT_MAP = {
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
    "Plane": "v1/planes",
}


class Open5eApiSource(ApiSource):
    """Open5e API Source"""

    def __init__(self, session):
        super().__init__(session)
        self.BASE_URL = "https://api.open5e.com"
        self.ENDPOINT_MAP = ENDPOINT_MAP

    def get_supported_categories(self):
        return list(self.ENDPOINT_MAP.keys())

    def get_list(self, category, page=1, filters=None):
        endpoint = self.ENDPOINT_MAP.get(category)
        if not endpoint:
            return {"results": [], "count": 0, "next": None, "previous": None}

        url = f"{self.BASE_URL}/{endpoint}/?format=json&limit=50&page={page}"

        if filters and isinstance(filters, dict):
            for k, v in filters.items():
                if v:
                    url += f"&{k}={v}"

        try:
            response = self.session.get(url, timeout=10)
            if response.status_code == 200:
                data = response.json()
                results = data.get("results", [])
                final_list = [
                    {
                        "name": item.get("name", "Unknown"),
                        "index": item.get("slug") or item.get("key"),
                        "url": item.get("url"),
                    }
                    for item in results
                ]
                return {
                    "results": final_list,
                    "count": data.get("count", 0),
                    "next": data.get("next"),
                    "previous": data.get("previous"),
                }
            return {"results": [], "count": 0, "next": None, "previous": None}
        except Exception as e:
            logger.error("Open5e list error: %s", e)
            return {"results": [], "count": 0, "next": None, "previous": None}

    def get_documents(self):
        try:
            url = f"{self.BASE_URL}/v1/documents/?format=json&limit=100"
            response = self.session.get(url, timeout=10)
            if response.status_code == 200:
                data = response.json()
                return [(item.get("slug"), item.get("title")) for item in data.get("results", [])]
            return []
        except Exception as e:
            logger.error("Open5e docs error: %s", e)
            return []

    def get_details(self, category, index):
        endpoint = self.ENDPOINT_MAP.get(category)
        if not endpoint:
            return None

        url = f"{self.BASE_URL}/{endpoint}/{index}/?format=json"
        try:
            response = self.session.get(url, timeout=10)
            if response.status_code == 200:
                return response.json()
            return None
        except Exception as e:
            logger.error("Open5e details error: %s", e)
            return None

    def search(self, category, query):
        endpoint = self.ENDPOINT_MAP.get(category)
        if not endpoint:
            return None, tr("MSG_CAT_NOT_SUPPORTED")

        url = f"{self.BASE_URL}/{endpoint}/{query}/?format=json"
        try:
            response = self.session.get(url, timeout=10)
            if response.status_code == 200:
                return self.parse_dispatcher(category, response.json()), tr("MSG_SEARCH_SUCCESS")
            return None, tr("MSG_SEARCH_NOT_FOUND")
        except Exception as e:
            return None, str(e)

    def parse_dispatcher(self, category, data):
        if category in ["Monster", "NPC"]:
            return self.parse_monster(data)
        elif category == "Spell":
            return self.parse_spell(data)
        elif category in ["Magic Item", "Weapon", "Armor"]:
            return self.parse_item(data)
        elif category == "Feat":
            return self.parse_feat(data)
        elif category == "Background":
            return self.parse_background(data)
        elif category == "Plane":
            return self.parse_plane(data)
        elif category == "Condition":
            return self.parse_condition(data)
        return self.parse_generic(category, data)

    def _get_source_str(self, data):
        if "_meta_source" in data:
            return data["_meta_source"]
        doc = data.get("document__title") or data.get("document", {}).get("title", "")
        return f"Open5e - {doc}" if doc else "Open5e"

    def parse_monster(self, data):
        return MonsterParser.from_open5e(data, source_str=self._get_source_str(data))

    def parse_spell(self, data):
        return {
            "name": data.get("name"),
            "type": "Spell",
            "description": data.get("desc", ""),
            "source": self._get_source_str(data),
            "tags": [
                f"Level {data.get('level_int', 0)}",
                data.get("school", ""),
                data.get("dnd_class", ""),
            ],
            "attributes": {
                "LBL_LEVEL": data.get("level", ""),
                "LBL_SCHOOL": data.get("school", ""),
                "LBL_CASTING_TIME": data.get("casting_time", ""),
                "LBL_RANGE": data.get("range", ""),
                "LBL_COMPONENTS": data.get("components", ""),
                "LBL_DURATION": (
                    ("C, " if data.get("concentration") == "yes" else "") + data.get("duration", "")
                ),
                "LBL_RITUAL": "Yes" if data.get("ritual") == "yes" else "No",
            },
        }

    def parse_item(self, data):
        return {
            "name": data.get("name", "Unknown Item"),
            "type": "Equipment",
            "description": data.get("desc", data.get("description", "")),
            "source": self._get_source_str(data),
            "tags": [data.get("type", ""), data.get("rarity", "")],
            "attributes": {
                "LBL_RARITY": data.get("rarity", ""),
                "LBL_ATTUNEMENT": data.get("requires_attunement", ""),
                "Category": data.get("category", ""),
                "Cost": data.get("cost", ""),
                "Weight": data.get("weight", ""),
            },
        }

    def parse_feat(self, data):
        return {
            "name": data.get("name"),
            "type": "Feat",
            "description": data.get("desc", ""),
            "source": self._get_source_str(data),
            "attributes": {"LBL_PREREQUISITE": data.get("prerequisite", "")},
        }

    def parse_background(self, data):
        return {
            "name": data.get("name"),
            "type": "Background",
            "description": (
                f"{data.get('desc', '')}\n\nFeature: {data.get('feature', '')}\n"
                f"{data.get('feature_desc', '')}"
            ),
            "source": self._get_source_str(data),
            "attributes": {
                "LBL_SKILL_PROFICIENCIES": data.get("skill_proficiencies", ""),
                "LBL_TOOL_PROFICIENCIES": data.get("tool_proficiencies", ""),
                "LBL_LANGUAGES": data.get("languages", ""),
                "LBL_EQUIPMENT": data.get("equipment", ""),
            },
        }

    def parse_plane(self, data):
        return {
            "name": data.get("name"),
            "type": "Plane",
            "description": data.get("desc", ""),
            "source": self._get_source_str(data),
            "attributes": {},
        }

    def parse_condition(self, data):
        return {
            "name": data.get("name"),
            "type": "Condition",
            "description": data.get("desc", ""),
            "source": self._get_source_str(data),
            "attributes": {},
        }

    def parse_generic(self, category, data):
        desc = data.get("desc", data.get("description", ""))
        if isinstance(desc, list):
            desc = "\n".join(desc)
        return {
            "name": data.get("name", "Unknown"),
            "type": category,
            "description": desc,
            "source": self._get_source_str(data),
            "attributes": data.get("attributes", {}),
        }
