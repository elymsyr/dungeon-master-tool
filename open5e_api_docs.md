Open5E Api
Welcome to the Open5e API.
You can review the basic DRF Browseable API here.
You can review swagger-ui at /schema/swagger-ui/
You can review redoc at /schema/redoc/

GET /
HTTP 200 OK
Allow: GET, HEAD, OPTIONS
Content-Type: application/json
Vary: Accept

{
    "manifest": "https://api.open5e.com/v1/manifest/",
    "spells": "https://api.open5e.com/v2/spells/",
    "spelllist": "https://api.open5e.com/v1/spelllist/",
    "monsters": "https://api.open5e.com/v1/monsters/",
    "documents": "https://api.open5e.com/v2/documents/",
    "backgrounds": "https://api.open5e.com/v2/backgrounds/",
    "planes": "https://api.open5e.com/v1/planes/",
    "sections": "https://api.open5e.com/v1/sections/",
    "feats": "https://api.open5e.com/v2/feats/",
    "conditions": "https://api.open5e.com/v2/conditions/",
    "races": "https://api.open5e.com/v1/races/",
    "classes": "https://api.open5e.com/v1/classes/",
    "magicitems": "https://api.open5e.com/v1/magicitems/",
    "weapons": "https://api.open5e.com/v2/weapons/",
    "armor": "https://api.open5e.com/v2/armor/"
}

Manifest List
list: API endpoint for returning a list of of manifests.

For each data source file, there is a corresponding manifest containing an
MD5 hash of the data inside that file. When we update our data files, the
corresponding manifest's hash changes. If you host a service that
automatically downloads data from Open5e, you can periodically check
the manifests to determine whether your data is out of date.

retrieve: API endpoint for returning a particular manifest.

For each data source file, there is a corresponding manifest containing an
MD5 hash of the data inside that file. When we update our data files, the
corresponding manifest's hash changes. If you host a service that
automatically downloads data from Open5e, you can periodically check
the manifests to determine whether your data is out of date.

GET /v1/manifest/
HTTP 200 OK
Allow: GET, HEAD, OPTIONS
Content-Type: application/json
Vary: Accept

{
    "count": 0,
    "next": null,
    "previous": null,
    "results": []
}



Spell List
list: API endpoint for returning a list of spells.
retrieve: API endpoint for returning a particular spell.

«123…40»
GET /v2/spells/
HTTP 200 OK
Allow: GET, HEAD, OPTIONS
Content-Type: application/json
Vary: Accept

{
    "count": 1954,
    "next": "https://api.open5e.com/v2/spells/?page=2",
    "previous": null,
    "results": [
        {
            "url": "https://api.open5e.com/v2/spells/a5e-ag_accelerando/",
            "document": {
                "name": "Adventurer's Guide",
                "key": "a5e-ag",
                "type": "SOURCE",
                "display_name": "Adventurer's Guide",
                "publisher": {
                    "name": "EN Publishing",
                    "key": "en-publishing",
                    "url": "https://api.open5e.com/v2/publishers/en-publishing/"
                },
                "gamesystem": {
                    "name": "Advanced 5th Edition",
                    "key": "a5e",
                    "url": "https://api.open5e.com/v2/gamesystems/a5e/"
                },
                "permalink": "https://a5esrd.com/a5esrd"
            },
            "key": "a5e-ag_accelerando",
            "casting_options": [
                {
                    "type": "default",
                    "damage_roll": null,
                    "target_count": null,
                    "duration": null,
                    "range": null,
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                }
            ],
            "school": {
                "name": "Transmutation",
                "key": "transmutation",
                "url": "https://api.open5e.com/v2/spellschools/transmutation/"
            },
            "classes": [],
            "range_unit": "feet",
            "shape_size_unit": "feet",
            "name": "Accelerando",
            "desc": "You play a complex and quick up-tempo piece that gradually gets faster and more complex, instilling the targets with its speed. You cannot cast another spell through your spellcasting focus while concentrating on this spell.\n\nUntil the spell ends, targets gain cumulative benefits the longer you maintain concentration on this spell (including the turn you cast it).\n\n* **1 Round:** Double Speed.\n* **2 Rounds:** +2 bonus to AC.\n* **3 Rounds:** Advantage on Dexterity saving throws.\n* **4 Rounds:** An additional action each turn. This action can be used only to take the Attack (one weapon attack only), Dash, Disengage, Hide, or Use an Object action.\n\nWhen the spell ends, a target can't move or take actions until after its next turn as the impact of their frenetic speed catches up to it.",
            "level": 4,
            "higher_level": "You may maintain concentration on this spell for an additional 2 rounds for each slot level above 4th.",
            "target_type": "object",
            "range_text": "30 feet",
            "range": 30.0,
            "ritual": false,
            "casting_time": "action",
            "reaction_condition": null,
            "verbal": true,
            "somatic": true,
            "material": true,
            "material_specified": "",
            "material_cost": null,
            "material_consumed": false,
            "target_count": 1,
            "saving_throw_ability": "dexterity",
            "attack_roll": false,
            "damage_roll": "",
            "damage_types": [],
            "duration": "6 rounds",
            "shape_type": null,
            "shape_size": null,
            "concentration": true
        },
        {
            "url": "https://api.open5e.com/v2/spells/a5e-ag_acid-arrow/",
            "document": {
                "name": "Adventurer's Guide",
                "key": "a5e-ag",
                "type": "SOURCE",
                "display_name": "Adventurer's Guide",
                "publisher": {
                    "name": "EN Publishing",
                    "key": "en-publishing",
                    "url": "https://api.open5e.com/v2/publishers/en-publishing/"
                },
                "gamesystem": {
                    "name": "Advanced 5th Edition",
                    "key": "a5e",
                    "url": "https://api.open5e.com/v2/gamesystems/a5e/"
                },
                "permalink": "https://a5esrd.com/a5esrd"
            },
            "key": "a5e-ag_acid-arrow",
            "casting_options": [
                {
                    "type": "default",
                    "damage_roll": null,
                    "target_count": null,
                    "duration": null,
                    "range": null,
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                }
            ],
            "school": {
                "name": "Evocation",
                "key": "evocation",
                "url": "https://api.open5e.com/v2/spellschools/evocation/"
            },
            "classes": [],
            "range_unit": "feet",
            "shape_size_unit": "feet",
            "name": "Acid Arrow",
            "desc": "A jet of acid streaks towards the target like a hissing, green arrow. Make a ranged spell attack.\n\nOn a hit the target takes 4d4 acid damage and 2d4 ongoing acid damage for 1 round. On a miss the target takes half damage.",
            "level": 2,
            "higher_level": "Increase this spell's initial and ongoing damage by 1d4 per slot level above 2nd.",
            "target_type": "creature",
            "range_text": "120 feet",
            "range": 120.0,
            "ritual": false,
            "casting_time": "action",
            "reaction_condition": null,
            "verbal": true,
            "somatic": true,
            "material": true,
            "material_specified": "",
            "material_cost": null,
            "material_consumed": false,
            "target_count": 1,
            "saving_throw_ability": "",
            "attack_roll": true,
            "damage_roll": "4d4",
            "damage_types": [
                "acid"
            ],
            "duration": "instantaneous",
            "shape_type": null,
            "shape_size": null,
            "concentration": false
        },
        {
            "url": "https://api.open5e.com/v2/spells/a5e-ag_acid-splash/",
            "document": {
                "name": "Adventurer's Guide",
                "key": "a5e-ag",
                "type": "SOURCE",
                "display_name": "Adventurer's Guide",
                "publisher": {
                    "name": "EN Publishing",
                    "key": "en-publishing",
                    "url": "https://api.open5e.com/v2/publishers/en-publishing/"
                },
                "gamesystem": {
                    "name": "Advanced 5th Edition",
                    "key": "a5e",
                    "url": "https://api.open5e.com/v2/gamesystems/a5e/"
                },
                "permalink": "https://a5esrd.com/a5esrd"
            },
            "key": "a5e-ag_acid-splash",
            "casting_options": [
                {
                    "type": "default",
                    "damage_roll": null,
                    "target_count": null,
                    "duration": null,
                    "range": null,
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                },
                {
                    "type": "player_level_1",
                    "damage_roll": "",
                    "target_count": null,
                    "duration": null,
                    "range": null,
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                },
                {
                    "type": "player_level_2",
                    "damage_roll": "",
                    "target_count": null,
                    "duration": null,
                    "range": null,
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                },
                {
                    "type": "player_level_3",
                    "damage_roll": "",
                    "target_count": null,
                    "duration": null,
                    "range": null,
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                },
                {
                    "type": "player_level_4",
                    "damage_roll": "",
                    "target_count": null,
                    "duration": null,
                    "range": null,
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                },
                {
                    "type": "player_level_5",
                    "damage_roll": "2d6",
                    "target_count": null,
                    "duration": null,
                    "range": null,
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                },
                {
                    "type": "player_level_6",
                    "damage_roll": "2d6",
                    "target_count": null,
                    "duration": null,
                    "range": null,
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                },
                {
                    "type": "player_level_7",
                    "damage_roll": "2d6",
                    "target_count": null,
                    "duration": null,
                    "range": null,
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                },
                {
                    "type": "player_level_8",
                    "damage_roll": "2d6",
                    "target_count": null,
                    "duration": null,
                    "range": null,
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                },
                {
                    "type": "player_level_9",
                    "damage_roll": "2d6",
                    "target_count": null,
                    "duration": null,
                    "range": null,
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                },
                {
                    "type": "player_level_10",
                    "damage_roll": "2d6",
                    "target_count": null,
                    "duration": null,
                    "range": null,
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                },
                {
                    "type": "player_level_11",
                    "damage_roll": "3d6",
                    "target_count": null,
                    "duration": null,
                    "range": null,
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                },
                {
                    "type": "player_level_12",
                    "damage_roll": "3d6",
                    "target_count": null,
                    "duration": null,
                    "range": null,
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                },
                {
                    "type": "player_level_13",
                    "damage_roll": "3d6",
                    "target_count": null,
                    "duration": null,
                    "range": null,
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                },
                {
                    "type": "player_level_14",
                    "damage_roll": "3d6",
                    "target_count": null,
                    "duration": null,
                    "range": null,
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                },
                {
                    "type": "player_level_15",
                    "damage_roll": "3d6",
                    "target_count": null,
                    "duration": null,
                    "range": null,
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                },
                {
                    "type": "player_level_16",
                    "damage_roll": "3d6",
                    "target_count": null,
                    "duration": null,
                    "range": null,
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                },
                {
                    "type": "player_level_17",
                    "damage_roll": "4d6",
                    "target_count": null,
                    "duration": null,
                    "range": null,
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                },
                {
                    "type": "player_level_18",
                    "damage_roll": "4d6",
                    "target_count": null,
                    "duration": null,
                    "range": null,
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                },
                {
                    "type": "player_level_19",
                    "damage_roll": "4d6",
                    "target_count": null,
                    "duration": null,
                    "range": null,
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                },
                {
                    "type": "player_level_20",
                    "damage_roll": "4d6",
                    "target_count": null,
                    "duration": null,
                    "range": null,
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                }
            ],
            "school": {
                "name": "Conjuration",
                "key": "conjuration",
                "url": "https://api.open5e.com/v2/spellschools/conjuration/"
            },
            "classes": [],
            "range_unit": "feet",
            "shape_size_unit": "feet",
            "name": "Acid Splash",
            "desc": "A stinking bubble of acid is conjured out of thin air to fly at the targets, dealing 1d6 acid damage.",
            "level": 0,
            "higher_level": "This spell's damage increases by 1d6 when you reach 5th level (2d6), 11th level (3d6), and 17th level (4d6).",
            "target_type": "creature",
            "range_text": "60 feet",
            "range": 60.0,
            "ritual": false,
            "casting_time": "action",
            "reaction_condition": null,
            "verbal": true,
            "somatic": true,
            "material": false,
            "material_specified": "",
            "material_cost": null,
            "material_consumed": false,
            "target_count": 2,
            "saving_throw_ability": "",
            "attack_roll": false,
            "damage_roll": "",
            "damage_types": [],
            "duration": "instantaneous",
            "shape_type": null,
            "shape_size": null,
            "concentration": false
        },
        {
            "url": "https://api.open5e.com/v2/spells/a5e-ag_aid/",
            "document": {
                "name": "Adventurer's Guide",
                "key": "a5e-ag",
                "type": "SOURCE",
                "display_name": "Adventurer's Guide",
                "publisher": {
                    "name": "EN Publishing",
                    "key": "en-publishing",
                    "url": "https://api.open5e.com/v2/publishers/en-publishing/"
                },
                "gamesystem": {
                    "name": "Advanced 5th Edition",
                    "key": "a5e",
                    "url": "https://api.open5e.com/v2/gamesystems/a5e/"
                },
                "permalink": "https://a5esrd.com/a5esrd"
            },
            "key": "a5e-ag_aid",
            "casting_options": [
                {
                    "type": "default",
                    "damage_roll": null,
                    "target_count": null,
                    "duration": null,
                    "range": null,
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                }
            ],
            "school": {
                "name": "Abjuration",
                "key": "abjuration",
                "url": "https://api.open5e.com/v2/spellschools/abjuration/"
            },
            "classes": [
                {
                    "name": "Cleric",
                    "key": "srd_cleric",
                    "url": "https://api.open5e.com/v2/classes/srd_cleric/"
                }
            ],
            "range_unit": "feet",
            "shape_size_unit": "feet",
            "name": "Aid",
            "desc": "You draw upon divine power, imbuing the targets with fortitude. Until the spell ends, each target increases its hit point maximum and current hit points by 5.",
            "level": 2,
            "higher_level": "The granted hit points increase by an additional 5 for each slot level above 2nd.",
            "target_type": "point",
            "range_text": "60 feet",
            "range": 60.0,
            "ritual": false,
            "casting_time": "action",
            "reaction_condition": null,
            "verbal": true,
            "somatic": true,
            "material": true,
            "material_specified": "",
            "material_cost": null,
            "material_consumed": false,
            "target_count": 1,
            "saving_throw_ability": "",
            "attack_roll": false,
            "damage_roll": "",
            "damage_types": [],
            "duration": "8 hours",
            "shape_type": null,
            "shape_size": null,
            "concentration": false
        },
        {
            "url": "https://api.open5e.com/v2/spells/a5e-ag_air-wave/",
            "document": {
                "name": "Adventurer's Guide",
                "key": "a5e-ag",
                "type": "SOURCE",
                "display_name": "Adventurer's Guide",
                "publisher": {
                    "name": "EN Publishing",
                    "key": "en-publishing",
                    "url": "https://api.open5e.com/v2/publishers/en-publishing/"
                },
                "gamesystem": {
                    "name": "Advanced 5th Edition",
                    "key": "a5e",
                    "url": "https://api.open5e.com/v2/gamesystems/a5e/"
                },
                "permalink": "https://a5esrd.com/a5esrd"
            },
            "key": "a5e-ag_air-wave",
            "casting_options": [
                {
                    "type": "default",
                    "damage_roll": null,
                    "target_count": null,
                    "duration": null,
                    "range": null,
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                },
                {
                    "type": "slot_level_2",
                    "damage_roll": null,
                    "target_count": null,
                    "duration": null,
                    "range": "60 feet",
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                },
                {
                    "type": "slot_level_3",
                    "damage_roll": null,
                    "target_count": null,
                    "duration": null,
                    "range": "90 feet",
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                },
                {
                    "type": "slot_level_4",
                    "damage_roll": null,
                    "target_count": null,
                    "duration": null,
                    "range": "120 feet",
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                },
                {
                    "type": "slot_level_5",
                    "damage_roll": null,
                    "target_count": null,
                    "duration": null,
                    "range": "150 feet",
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                },
                {
                    "type": "slot_level_6",
                    "damage_roll": null,
                    "target_count": null,
                    "duration": null,
                    "range": "180 feet",
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                },
                {
                    "type": "slot_level_7",
                    "damage_roll": null,
                    "target_count": null,
                    "duration": null,
                    "range": "210 feet",
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                },
                {
                    "type": "slot_level_8",
                    "damage_roll": null,
                    "target_count": null,
                    "duration": null,
                    "range": "240 feet",
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                },
                {
                    "type": "slot_level_9",
                    "damage_roll": null,
                    "target_count": null,
                    "duration": null,
                    "range": "270 feet",
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                }
            ],
            "school": {
                "name": "Conjuration",
                "key": "conjuration",
                "url": "https://api.open5e.com/v2/spellschools/conjuration/"
            },
            "classes": [],
            "range_unit": "feet",
            "shape_size_unit": "feet",
            "name": "Air Wave",
            "desc": "Your deft weapon swing sends a wave of cutting air to assault a creature within range. Make a melee weapon attack against the target. If you are wielding one weapon in each hand, your attack deals an additional 1d6 damage. Regardless of the weapon you are wielding, your attack deals slashing damage.",
            "level": 1,
            "higher_level": "The spell's range increases by 30 feet for each slot level above 1st.",
            "target_type": "creature",
            "range_text": "30 feet",
            "range": 30.0,
            "ritual": false,
            "casting_time": "action",
            "reaction_condition": null,
            "verbal": true,
            "somatic": false,
            "material": false,
            "material_specified": "",
            "material_cost": null,
            "material_consumed": false,
            "target_count": 1,
            "saving_throw_ability": "",
            "attack_roll": false,
            "damage_roll": "",
            "damage_types": [],
            "duration": "instantaneous",
            "shape_type": null,
            "shape_size": null,
            "concentration": false
        },
        {
            "url": "https://api.open5e.com/v2/spells/a5e-ag_alarm/",
            "document": {
                "name": "Adventurer's Guide",
                "key": "a5e-ag",
                "type": "SOURCE",
                "display_name": "Adventurer's Guide",
                "publisher": {
                    "name": "EN Publishing",
                    "key": "en-publishing",
                    "url": "https://api.open5e.com/v2/publishers/en-publishing/"
                },
                "gamesystem": {
                    "name": "Advanced 5th Edition",
                    "key": "a5e",
                    "url": "https://api.open5e.com/v2/gamesystems/a5e/"
                },
                "permalink": "https://a5esrd.com/a5esrd"
            },
            "key": "a5e-ag_alarm",
            "casting_options": [
                {
                    "type": "default",
                    "damage_roll": null,
                    "target_count": null,
                    "duration": null,
                    "range": null,
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                },
                {
                    "type": "ritual",
                    "damage_roll": null,
                    "target_count": null,
                    "duration": null,
                    "range": null,
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                },
                {
                    "type": "slot_level_2",
                    "damage_roll": null,
                    "target_count": 2,
                    "duration": null,
                    "range": "600 feet",
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                },
                {
                    "type": "slot_level_3",
                    "damage_roll": null,
                    "target_count": 3,
                    "duration": null,
                    "range": "600 feet",
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                },
                {
                    "type": "slot_level_4",
                    "damage_roll": null,
                    "target_count": 4,
                    "duration": null,
                    "range": "600 feet",
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                },
                {
                    "type": "slot_level_5",
                    "damage_roll": null,
                    "target_count": 5,
                    "duration": null,
                    "range": "600 feet",
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                },
                {
                    "type": "slot_level_6",
                    "damage_roll": null,
                    "target_count": 6,
                    "duration": null,
                    "range": "600 feet",
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                },
                {
                    "type": "slot_level_7",
                    "damage_roll": null,
                    "target_count": 7,
                    "duration": null,
                    "range": "600 feet",
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                },
                {
                    "type": "slot_level_8",
                    "damage_roll": null,
                    "target_count": 8,
                    "duration": null,
                    "range": "600 feet",
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                },
                {
                    "type": "slot_level_9",
                    "damage_roll": null,
                    "target_count": 9,
                    "duration": null,
                    "range": "600 feet",
                    "concentration": null,
                    "shape_size": null,
                    "desc": null
                }
            ],
            "school": {
                "name": "Abjuration",
                "key": "abjuration",
                "url": "https://api.open5e.com/v2/spellschools/abjuration/"
            },
            "classes": [],
            "range_unit": "feet",
            "shape_size_unit": "feet",
            "name": "Alarm",
            "desc": "You set an alarm against unwanted intrusion that alerts you whenever a creature of size Tiny or larger touches or enters the warded area. When you cast the spell, choose any number of creatures. These creatures don't set off the alarm.\n\nChoose whether the alarm is silent or audible. The silent alarm is heard in your mind if you are within 1 mile of the warded area and it awakens you if you are sleeping. An audible alarm produces a loud noise of your choosing for 10 seconds within 60 feet.",
            "level": 1,
            "higher_level": "You may create an additional alarm for each slot level above 1st. The spell's range increases to 600 feet, but you must be familiar with the locations you ward, and all alarms must be set within the same physical structure. Setting off one alarm does not activate the other alarms.\n\nYou may choose one of the following effects in place of creating an additional alarm. The effects apply to all alarms created during the spell's casting.\n\nIncreased Duration. The spell's duration increases to 24 hours.\n\nImproved Audible Alarm. The audible alarm produces any sound you choose and can be heard up to 300 feet away.\n\nImproved Mental Alarm. The mental alarm alerts you regardless of your location, even if you and the alarm are on different planes of existence.",
            "target_type": "creature",
            "range_text": "60 feet",
            "range": 60.0,
            "ritual": true,
            "casting_time": "1minute",
            "reaction_condition": null,
            "verbal": true,
            "somatic": true,
            "material": true,
            "material_specified": "",
            "material_cost": null,
            "material_consumed": false,
            "target_count": 1,
            "saving_throw_ability": "",
            "attack_roll": false,
            "damage_roll": "",
            "damage_types": [],
            "duration": "8 hours",
            "shape_type": null,
            "shape_size": null,
            "concentration": false
        },
        {
            "url": "https://api.open5e.com/v2/spells/a5e-ag_alter-self/",
            "document": {
                "name": "Adventurer's Guide",
                "key": "a5e-ag",
                "type": "SOURCE",
                "display_name": "Adventurer's Guide",
                "publisher": {
                    "name": "EN Publishing",
                    "key": "en-publishing",
                    "url": "https://api.open5e.com/v2/publishers/en-publishing/"
                },
                "gamesystem": {
                    "name": "Advanced 5th Edition",
                    "key": "a5e",
                    "url": "https://api.open5e.com/v2/gamesystems/a5e/"
                },
                "permalink": "https://a5esrd.com/a5esrd"
            },
            "key": "a5e-ag_alter-self",
            "casting_options": [
......


Spell List List
list: API endpoint for returning a list of spell lists.
retrieve: API endpoint for returning a particular spell list.

GET /v1/spelllist/
HTTP 200 OK
Allow: GET, HEAD, OPTIONS
Content-Type: application/json
Vary: Accept

{
    "count": 7,
    "next": null,
    "previous": null,
    "results": [
        {
            "slug": "bard",
            "name": "bard",
            "desc": "",
            "spells": [
                "abhorrent-apparition",
                "accelerate",
                "adjust-position",
                "agonizing-mark",
                "ale-dritch-blast",
                "ally-aegis",
                "alter-arrows-fortune",
                "analyze-device",
                "anchoring-rope",
                "animal-friendship",
                "animal-messenger",
                "animate-objects",
                "anticipate-attack",
                "anticipate-weakness",
                "arcane-sword",
                "armored-heart",
                "ashen-memories",
                "auspicious-warning",
                "avoid-grievous-injury",
                "awaken",
                "bad-timing",
                "bane",
                "batsense",
                "beguiling-gift",
                "bestow-curse",
                "binding-oath",
                "black-goats-blessing",
                "bleating-call",
                "blindnessdeafness",
                "calm-emotions",
                "charm-person",
                "clairvoyance",
                "comprehend-languages",
                "compulsion",
                "confusion",
                "cure-wounds",
                "dancing-lights",
                "detect-magic",
                "detect-thoughts",
                "dimension-door",
                "disguise-self",
                "dispel-magic",
                "dominate-monster",
                "dominate-person",
                "door-of-the-far-traveler",
                "dream",
                "enhance-ability",
                "enthrall",
                "ethereal-stairs",
                "etherealness",
                "exchanged-knowledge",
                "extract-foyson",
                "eye-bite",
                "eyebite",
                "faerie-fire",
                "fear",
                "feather-fall",
                "feeblemind",
                "find-the-flaw",
                "find-the-path",
                "forcecage",
                "foresight",
                "freedom-of-movement",
                "geas",
                "gift-of-azathoth",
                "glibness",
                "glyph-of-warding",
                "greater-invisibility",
                "greater-restoration",
                "guards-and-wards",
                "hallucinatory-terrain",
                "healing-word",
                "heat-metal",
                "heroism",
                "hideous-laughter",
                "hold-monster",
                "hold-person",
                "hypnagogia",
......



Spell Instance
list: API endpoint for returning a list of spells.
retrieve: API endpoint for returning a particular spell.

GET /v2/spells/a5e-ag_acid-arrow/
HTTP 200 OK
Allow: GET, HEAD, OPTIONS
Content-Type: application/json
Vary: Accept

{
    "url": "https://api.open5e.com/v2/spells/a5e-ag_acid-arrow/",
    "document": {
        "name": "Adventurer's Guide",
        "key": "a5e-ag",
        "type": "SOURCE",
        "display_name": "Adventurer's Guide",
        "publisher": {
            "name": "EN Publishing",
            "key": "en-publishing",
            "url": "https://api.open5e.com/v2/publishers/en-publishing/"
        },
        "gamesystem": {
            "name": "Advanced 5th Edition",
            "key": "a5e",
            "url": "https://api.open5e.com/v2/gamesystems/a5e/"
        },
        "permalink": "https://a5esrd.com/a5esrd"
    },
    "key": "a5e-ag_acid-arrow",
    "casting_options": [
        {
            "type": "default",
            "damage_roll": null,
            "target_count": null,
            "duration": null,
            "range": null,
            "concentration": null,
            "shape_size": null,
            "desc": null
        }
    ],
    "school": {
        "name": "Evocation",
        "key": "evocation",
        "url": "https://api.open5e.com/v2/spellschools/evocation/"
    },
    "classes": [],
    "range_unit": "feet",
    "shape_size_unit": "feet",
    "name": "Acid Arrow",
    "desc": "A jet of acid streaks towards the target like a hissing, green arrow. Make a ranged spell attack.\n\nOn a hit the target takes 4d4 acid damage and 2d4 ongoing acid damage for 1 round. On a miss the target takes half damage.",
    "level": 2,
    "higher_level": "Increase this spell's initial and ongoing damage by 1d4 per slot level above 2nd.",
    "target_type": "creature",
    "range_text": "120 feet",
    "range": 120.0,
    "ritual": false,
    "casting_time": "action",
    "reaction_condition": null,
    "verbal": true,
    "somatic": true,
    "material": true,
    "material_specified": "",
    "material_cost": null,
    "material_consumed": false,
    "target_count": 1,
    "saving_throw_ability": "",
    "attack_roll": true,
    "damage_roll": "4d4",
    "damage_types": [
        "acid"
    ],
    "duration": "instantaneous",
    "shape_type": null,
    "shape_size": null,
    "concentration": false
}


Document List
list: API endpoint for returning a list of documents.
retrieve: API endpoint for returning a particular document.

GET /v2/documents/
HTTP 200 OK
Allow: GET, HEAD, OPTIONS
Content-Type: application/json
Vary: Accept

{
    "count": 24,
    "next": null,
    "previous": null,
    "results": [
        {
            "url": "https://api.open5e.com/v2/documents/a5e-ag/",
            "key": "a5e-ag",
            "licenses": [
                {
                    "name": "Creative Commons Attribution 4.0",
                    "key": "cc-by-40",
                    "url": "https://api.open5e.com/v2/licenses/cc-by-40/"
                },
                {
                    "name": "OPEN GAME LICENSE Version 1.0a",
                    "key": "ogl-10a",
                    "url": "https://api.open5e.com/v2/licenses/ogl-10a/"
                }
            ],
            "publisher": {
                "name": "EN Publishing",
                "key": "en-publishing",
                "url": "https://api.open5e.com/v2/publishers/en-publishing/"
            },
            "gamesystem": {
                "name": "Advanced 5th Edition",
                "key": "a5e",
                "url": "https://api.open5e.com/v2/gamesystems/a5e/"
            },
            "display_name": "Adventurer's Guide",
            "name": "Adventurer's Guide",
            "desc": "In this guide to Level Up, the advanced roleplaying game, you will find everything you need to play. Create diverse and unique heroes, engage in epic combat with villainous foes, cast powerful spells, and build mighty strongholds!",
            "type": "SOURCE",
            "author": "EN Publishing",
            "publication_date": "2021-11-01T00:00:00",
            "permalink": "https://a5esrd.com/a5esrd",
            "distance_unit": "feet",
            "weight_unit": "lb"
        },
        {
            "url": "https://api.open5e.com/v2/documents/a5e-ddg/",
            "key": "a5e-ddg",
            "licenses": [
                {
                    "name": "Creative Commons Attribution 4.0",
                    "key": "cc-by-40",
                    "url": "https://api.open5e.com/v2/licenses/cc-by-40/"
                },
                {
                    "name": "OPEN GAME LICENSE Version 1.0a",
                    "key": "ogl-10a",
                    "url": "https://api.open5e.com/v2/licenses/ogl-10a/"
                }
            ],
            "publisher": {
                "name": "EN Publishing",
                "key": "en-publishing",
                "url": "https://api.open5e.com/v2/publishers/en-publishing/"
            },
            "gamesystem": {
                "name": "Advanced 5th Edition",
                "key": "a5e",
                "url": "https://api.open5e.com/v2/gamesystems/a5e/"
            },
            "display_name": "Dungeon Delver’s Guide",
            "name": "Dungeon Delver’s Guide",
            "desc": "The Dungeon Delver's Guide is a resource for Narrators that want to create compelling and deadly mazes and lairs, and adventurers who want to venture below and return to the surface alive.",
            "type": "SOURCE",
            "author": "EN Publishing",
            "publication_date": "2023-10-03T00:00:00",
            "permalink": "https://a5esrd.com/a5esrd",
            "distance_unit": "feet",
            "weight_unit": "lb"
        },
        {
            "url": "https://api.open5e.com/v2/documents/a5e-gpg/",
            "key": "a5e-gpg",
            "licenses": [
                {
                    "name": "Creative Commons Attribution 4.0",
                    "key": "cc-by-40",
                    "url": "https://api.open5e.com/v2/licenses/cc-by-40/"
                },
                {
                    "name": "OPEN GAME LICENSE Version 1.0a",
                    "key": "ogl-10a",
                    "url": "https://api.open5e.com/v2/licenses/ogl-10a/"
                }
            ],
            "publisher": {
                "name": "EN Publishing",
                "key": "en-publishing",
                "url": "https://api.open5e.com/v2/publishers/en-publishing/"
            },
            "gamesystem": {
                "name": "Advanced 5th Edition",
                "key": "a5e",
                "url": "https://api.open5e.com/v2/gamesystems/a5e/"
            },
            "display_name": "Gate Pass Gazette",
            "name": "Gate Pass Gazette",
            "desc": "The Gate Pass Gazette is the official monthly magazine for Level Up: Advanced 5th Edition. You can subscribe to it on Patreon. The content below includes mechanical elements of the magazine, but not the full text or context of the articles.\r\n\r\nThe first issue (which we called Issue #0) of the Gate Pass Gazette included the artificer class, lycanthropy rules, the construct heritage, and the jabberwock monster. We release an issue every month, including new heritages, archetypes, monsters, magic items, and much much more.",
            "type": "SOURCE",
            "author": "EN Publishing",
            "publication_date": "2022-01-01T00:00:00",
            "permalink": "https://a5esrd.com/a5esrd",
            "distance_unit": "feet",
            "weight_unit": "lb"
        },
        {
            "url": "https://api.open5e.com/v2/documents/a5e-mm/",
            "key": "a5e-mm",
            "licenses": [
                {
                    "name": "OPEN GAME LICENSE Version 1.0a",
                    "key": "ogl-10a",
                    "url": "https://api.open5e.com/v2/licenses/ogl-10a/"
                }
            ],
            "publisher": {
                "name": "EN Publishing",
                "key": "en-publishing",
                "url": "https://api.open5e.com/v2/publishers/en-publishing/"
            },
            "gamesystem": {
                "name": "Advanced 5th Edition",
                "key": "a5e",
                "url": "https://api.open5e.com/v2/gamesystems/a5e/"
            },
            "display_name": "Monstrous Menagerie",
            "name": "Monstrous Menagerie",
            "desc": "The Monstrous Menagerie provides nearly 600 monsters, variants, monster templates, and hordes for your Level Up: Advanced 5th Edition game. Populate your game world with classic monsters ranging from the lowly stirge to the terrifying tarrasque, along with new horrors like the khalkos and the phase monster. Challenge even the mightiest adventurers with elite monsters like great wyrm dragons and the Medusa Queen. Use simple templates to create new monsters like zombie sea serpents and merfolk alchemists. Overwhelm opposition with stat blocks representing hordes of guards, skeletons, or demons.",
            "type": "SOURCE",
            "author": "Paul Hughes",
            "publication_date": "2021-12-12T00:00:00",
            "permalink": "https://enpublishingrpg.com/collections/level-up-advanced-5th-edition-a5e/products/level-up-monstrous-menagerie-a5e",
            "distance_unit": "feet",
            "weight_unit": "lb"
        },
        {
            "url": "https://api.open5e.com/v2/documents/bfrd/",
            "key": "bfrd",
            "licenses": [
                {
                    "name": "Creative Commons Attribution 4.0",
                    "key": "cc-by-40",
                    "url": "https://api.open5e.com/v2/licenses/cc-by-40/"
                }
            ],
            "publisher": {
                "name": "Kobold Press",
                "key": "kobold-press",
                "url": "https://api.open5e.com/v2/publishers/kobold-press/"
            },
            "gamesystem": {
                "name": "5th Edition 2014",
                "key": "5e-2014",
                "url": "https://api.open5e.com/v2/gamesystems/5e-2014/"
            },
            "display_name": "Black Flag SRD",
            "name": "Black Flag SRD",
            "desc": "Black Flag Roleplaying Reference Document v0.2",
            "type": "SOURCE",
            "author": "Open Design LLC d/b/a Kobold Press",
            "publication_date": "2023-10-16T00:00:00",
            "permalink": "https://koboldpress.com/black-flag-reference-document/",
            "distance_unit": "feet",
            "weight_unit": "lb"
        },
        {
            "url": "https://api.open5e.com/v2/documents/ccdx/",
            "key": "ccdx",
            "licenses": [
                {
                    "name": "OPEN GAME LICENSE Version 1.0a",
                    "key": "ogl-10a",
                    "url": "https://api.open5e.com/v2/licenses/ogl-10a/"
                }
            ],
            "publisher": {
                "name": "Kobold Press",
                "key": "kobold-press",
                "url": "https://api.open5e.com/v2/publishers/kobold-press/"
            },
            "gamesystem": {
                "name": "5th Edition 2014",
                "key": "5e-2014",
                "url": "https://api.open5e.com/v2/gamesystems/5e-2014/"
            },
            "display_name": "Creature Codex",
            "name": "Creature Codex",
            "desc": "Whether you need scuttling dungeon denizens, alien horrors, or sentient avatars of the World Tree, the Creature Codex has you covered! Nearly 400 new foes for your 5th Edition game—everything from acid ants and grave behemoths to void giants and zombie lords.\r\n\r\nThe 424 PAGES OF THE CREATURE CODEX INCLUDE:\r\n\r\n    A dozen new demons and five new angels\r\n    Wasteland dragons and dinosaurs\r\n    All-new golems, including the altar flame golem, doom golem, and keg golem\r\n    Elemental lords and animal lords to challenge powerful parties\r\n    Chieftains and other leaders for ratfolk, centaurs, goblins, trollkin, and more\r\n    New undead, including a heirophant lich to menace lower-level characters\r\n\r\n…and much more! Use them in your favorite published setting, or populate the dungeons in a world of your own creation. Pick up Creature Codex and surprise your players with monsters they won’t be expecting!\r\n\r\nCOMPATIBLE WITH THE 5TH EDITION OF THE WORLD’S FIRST ROLEPLAYING GAME!",
            "type": "SOURCE",
            "author": "Wolfgang Baur, Dan Dillon, Richard Green, James Haeck, Chris Harris, Jeremy Hochhalter, James Introcaso, Chris Lockey, Shawn Merwin, and Jon Sawatsky",
            "publication_date": "2018-06-01T00:00:00",
            "permalink": "https://koboldpress.com/kpstore/product/creature-codex-for-5th-edition-dnd/",
            "distance_unit": "feet",
            "weight_unit": "lb"
        },
        {
            "url": "https://api.open5e.com/v2/documents/core/",
            "key": "core",
            "licenses": [
                {
                    "name": "Creative Commons Attribution 4.0",
                    "key": "cc-by-40",
                    "url": "https://api.open5e.com/v2/licenses/cc-by-40/"
                },
                {
                    "name": "OPEN GAME LICENSE Version 1.0a",
                    "key": "ogl-10a",
                    "url": "https://api.open5e.com/v2/licenses/ogl-10a/"
                }
            ],
            "publisher": {
                "name": "Open5e",
                "key": "open5e",
                "url": "https://api.open5e.com/v2/publishers/open5e/"
            },
            "gamesystem": {
                "name": "5th Edition 2014",
                "key": "5e-2014",
                "url": "https://api.open5e.com/v2/gamesystems/5e-2014/"
            },
            "display_name": "5e Core",
            "name": "5e Core Concepts",
            "desc": "This document is related to the core concepts of 5e for all gamesystems and documents. For example, Charisma as a concept is shared across all implementations of 5e. It was initially defined by Wizards of the Coast (in SRD 2014), and then adopted in all other subsequent add-ons and documents.",
            "type": "MISC",
            "author": "Mike Mearls, Jeremy Crawford, Chris Perkins, Rodney Thompson, Peter Lee, James Wyatt, Robert J. Schwalb, Bruce R. Cordell, Chris Sims, and Steve Townshend, based on original material by E. Gary Gygax and Dave Arneson.",
            "publication_date": "2014-01-01T00:00:00",
            "permalink": "https://dnd.wizards.com/resources/systems-reference-document",
            "distance_unit": "feet",
            "weight_unit": null
        },
        {
            "url": "https://api.open5e.com/v2/documents/deepm/",
            "key": "deepm",
            "licenses": [
                {
                    "name": "OPEN GAME LICENSE Version 1.0a",
                    "key": "ogl-10a",
                    "url": "https://api.open5e.com/v2/licenses/ogl-10a/"
                }
            ],
            "publisher": {
                "name": "Kobold Press",
                "key": "kobold-press",
                "url": "https://api.open5e.com/v2/publishers/kobold-press/"
            },
            "gamesystem": {
                "name": "5th Edition 2014",
                "key": "5e-2014",
                "url": "https://api.open5e.com/v2/gamesystems/5e-2014/"
            },
            "display_name": "Deep Magic for 5th Edition",
            "name": "Deep Magic for 5th Edition",
            "desc": "*Command 700 New Spells for 5th Edition!*\r\n\r\nNo matter how you slice it, magic is at the heart of fantasy—and nothing says magic like a massive tome of spells.\r\n\r\nThis tome collects, updates, tweaks, and expands spells from years of the Deep Magic for Fifth Edition series—more than 700 new and revised spells. And it adds a lot more:\r\n\r\n* 19 divine domains from Beer to Mountain and Speed to Winter;\r\n* 13 new wizard specialties, such as the elementalist and the timekeeper;\r\n* 6 new sorcerous origins, including the Aristocrat and the Farseer;\r\n* 3 otherworldly patrons for warlocks, including the Sibyl;\r\n* expanded treatments of familiars and other wizardly servants;\r\n* and much more!\r\n\r\nThis 356-page tome is not just for wizards, warlocks, and sorcerers. Deep Magic also expands the horizons of what’s possible for bards, clerics, druids, and even rangers and paladins. It offers something new for every spellcasting class!\r\n\r\nWith these new spells and options, your characters (or your villains) can become masters of winter magic, chaos magic, or shadow magic. Seek out hidden colleges and academies of lost lore. Learn new runes, hieroglyphs, and cantrips to break down the walls of reality, or just bend them a bit.\r\n\r\nDeep Magic contains nothing but magic from start to finish!",
            "type": "SOURCE",
            "author": "Dan Dillon, Chris Harris, and Jeff Lee",
            "publication_date": "2020-02-13T00:00:00",
            "permalink": "https://koboldpress.com/kpstore/product/deep-magic-for-5th-edition-hardcover/",
            "distance_unit": "feet",
            "weight_unit": "lb"
        },
        {
            "url": "https://api.open5e.com/v2/documents/deepmx/",
            "key": "deepmx",
            "licenses": [
                {
                    "name": "OPEN GAME LICENSE Version 1.0a",
                    "key": "ogl-10a",
                    "url": "https://api.open5e.com/v2/licenses/ogl-10a/"
                }
            ],
            "publisher": {
                "name": "Kobold Press",
                "key": "kobold-press",
                "url": "https://api.open5e.com/v2/publishers/kobold-press/"
            },
            "gamesystem": {
                "name": "5th Edition 2014",
                "key": "5e-2014",
                "url": "https://api.open5e.com/v2/gamesystems/5e-2014/"
            },
            "display_name": "Deep Magic Extended",
            "name": "Deep Magic Extended",
            "desc": "?",
            "type": "SOURCE",
            "author": "Not sure.",
            "publication_date": "2024-02-14T19:02:02",
            "permalink": "https://koboldpress.com/deepmagic",
            "distance_unit": "feet",
            "weight_unit": "lb"
        },
        {
            "url": "https://api.open5e.com/v2/documents/elderberry-inn-icons/",
            "key": "elderberry-inn-icons",
            "licenses": [
                {
                    "name": "Creative Commons 0",
                    "key": "cc0",
                    "url": "https://api.open5e.com/v2/licenses/cc0/"
                }
            ],
            "publisher": {
                "name": "Open5e",
                "key": "open5e",
                "url": "https://api.open5e.com/v2/publishers/open5e/"
            },
            "gamesystem": {
                "name": "5th Edition 2014",
                "key": "5e-2014",
                "url": "https://api.open5e.com/v2/gamesystems/5e-2014/"
            },
            "display_name": "Elderberry Inn Icons",
            "name": "Elderberry Inn Icons",
            "desc": "Designed with love by Anaislalovi for Elderberry Inn.",
            "type": "MISC",
            "author": "Ana Isabel Latorre López Villalta",
            "publication_date": "2023-10-05T00:00:00",
            "permalink": "https://github.com/anaislalovi/dnd5e-icons",
            "distance_unit": null,
            "weight_unit": "lb"
        },
        {
            "url": "https://api.open5e.com/v2/documents/kp/",
            "key": "kp",
            "licenses": [
                {
                    "name": "OPEN GAME LICENSE Version 1.0a",
                    "key": "ogl-10a",
                    "url": "https://api.open5e.com/v2/licenses/ogl-10a/"
                }
            ],
            "publisher": {
                "name": "Kobold Press",
                "key": "kobold-press",
                "url": "https://api.open5e.com/v2/publishers/kobold-press/"
            },
            "gamesystem": {
                "name": "5th Edition 2014",
                "key": "5e-2014",
                "url": "https://api.open5e.com/v2/gamesystems/5e-2014/"
            },
            "display_name": "Kobold Press Compilation",
            "name": "Kobold Press Compilation",
            "desc": "Kobold Press Community Use Policy",
            "type": "SOURCE",
            "author": "Various",
            "publication_date": "2024-02-14T19:53:41",
            "permalink": "https://koboldpress.com/",
            "distance_unit": "feet",
            "weight_unit": "lb"
        },
        {
            "url": "https://api.open5e.com/v2/documents/open5e/",
            "key": "open5e",
            "licenses": [
                {
                    "name": "OPEN GAME LICENSE Version 1.0a",
                    "key": "ogl-10a",
                    "url": "https://api.open5e.com/v2/licenses/ogl-10a/"
                }
            ],
            "publisher": {
                "name": "Open5e",
                "key": "open5e",
                "url": "https://api.open5e.com/v2/publishers/open5e/"
            },
            "gamesystem": {
                "name": "5th Edition 2014",
                "key": "5e-2014",
                "url": "https://api.open5e.com/v2/gamesystems/5e-2014/"
            },
            "display_name": "Open5e Originals",
            "name": "Open5e Originals",
            "desc": "Original items from Open5e",
            "type": "SOURCE",
            "author": "Ean Moody, Various",
            "publication_date": "2024-02-15T02:15:19",
            "permalink": "https://open5e.com/",
            "distance_unit": "feet",
            "weight_unit": "lb"
        },
        {
            "url": "https://api.open5e.com/v2/documents/open5e-2024/",
            "key": "open5e-2024",
            "licenses": [
                {
                    "name": "OPEN GAME LICENSE Version 1.0a",
                    "key": "ogl-10a",
                    "url": "https://api.open5e.com/v2/licenses/ogl-10a/"
                }
            ],
            "publisher": {
                "name": "Open5e",
                "key": "open5e",
                "url": "https://api.open5e.com/v2/publishers/open5e/"
            },
            "gamesystem": {
                "name": "5th Edition 2024",
                "key": "5e-2024",
                "url": "https://api.open5e.com/v2/gamesystems/5e-2024/"
            },
            "display_name": "Open5e Originals",
            "name": "Open5e Originals",
            "desc": "Original items from Open5e",
            "type": "SOURCE",
            "author": "Ean Moody, Various",
            "publication_date": "2024-02-15T02:15:19",
            "permalink": "https://open5e.com/",
            "distance_unit": "feet",
            "weight_unit": "lb"
        },
        {
            "url": "https://api.open5e.com/v2/documents/spells-that-dont-suck/",
            "key": "spells-that-dont-suck",
            "licenses": [
                {
                    "name": "Creative Commons Attribution 4.0",
                    "key": "cc-by-40",
                    "url": "https://api.open5e.com/v2/licenses/cc-by-40/"
                }
            ],
            "publisher": {
                "name": "Somanyrobots",
                "key": "somanyrobots",
                "url": "https://api.open5e.com/v2/publishers/somanyrobots/"
            },
            "gamesystem": {
                "name": "5th Edition 2014",
                "key": "5e-2014",
                "url": "https://api.open5e.com/v2/gamesystems/5e-2014/"
            },
            "display_name": "Spells That Don't Suck",
            "name": "Spells That Don't Suck",
            "desc": "Spells That Don't Suck is a package of replacement spells for problematic ones in core 5E - typically rebalancing under- or over-powered spells. All content contained within is licensed CC-BY and free to reuse. Includes spells from Spells That Don't Suck by Omega Ankh and somanyrobots, which is licensed CC-BY and available here https://www.somanyrobots.com/s/Spells-That-Dont-Suck-compressed.pdf. Includes spells from Kibbles' Casting Compendium 2.0 by KibblesTasty Homebrewc LLC, which is licensed CC-BY and available here: https://www.kthomebrew.com/krd.",
            "type": "SOURCE",
            "author": "Ben Somers / somanyrobots, Omega Ankh",
            "publication_date": "2025-03-30T00:00:00",
            "permalink": "https://www.somanyrobots.com/s/Spells-That-Dont-Suck-compressed.pdf",
            "distance_unit": "feet",
            "weight_unit": "lb"
        },
        {
            "url": "https://api.open5e.com/v2/documents/srd-2014/",
            "key": "srd-2014",
            "licenses": [
                {
                    "name": "Creative Commons Attribution 4.0",
                    "key": "cc-by-40",
                    "url": "https://api.open5e.com/v2/licenses/cc-by-40/"
                },
                {
                    "name": "OPEN GAME LICENSE Version 1.0a",
                    "key": "ogl-10a",
                    "url": "https://api.open5e.com/v2/licenses/ogl-10a/"
                }
            ],
            "publisher": {
                "name": "Wizards of the Coast",
                "key": "wizards-of-the-coast",
                "url": "https://api.open5e.com/v2/publishers/wizards-of-the-coast/"
            },
            "gamesystem": {
                "name": "5th Edition 2014",
                "key": "5e-2014",
                "url": "https://api.open5e.com/v2/gamesystems/5e-2014/"
            },
            "display_name": "5e 2014 Rules",
            "name": "System Reference Document 5.1",
            "desc": "The System Reference Document (SRD) contains guidelines for publishing content under the Open-Gaming License (OGL) or Creative Commons. The Dungeon Masters Guild also provides self-publishing opportunities for individuals and groups.",
            "type": "SOURCE",
            "author": "Mike Mearls, Jeremy Crawford, Chris Perkins, Rodney Thompson, Peter Lee, James Wyatt, Robert J. Schwalb, Bruce R. Cordell, Chris Sims, and Steve Townshend, based on original material by E. Gary Gygax and Dave Arneson.",
            "publication_date": "2023-01-23T00:00:00",
            "permalink": "https://dnd.wizards.com/resources/systems-reference-document",
            "distance_unit": "feet",
            "weight_unit": "lb"
        },
        {
            "url": "https://api.open5e.com/v2/documents/srd-2024/",
            "key": "srd-2024",
            "licenses": [
                {
                    "name": "Creative Commons Attribution 4.0",
                    "key": "cc-by-40",
                    "url": "https://api.open5e.com/v2/licenses/cc-by-40/"
                }
            ],
            "publisher": {
                "name": "Wizards of the Coast",
                "key": "wizards-of-the-coast",
                "url": "https://api.open5e.com/v2/publishers/wizards-of-the-coast/"
            },
            "gamesystem": {
                "name": "5th Edition 2024",
                "key": "5e-2024",
                "url": "https://api.open5e.com/v2/gamesystems/5e-2024/"
            },
            "display_name": "5e 2024 Rules",
            "name": "System Reference Document 5.2",
            "desc": "The System Reference Document (SRD) contains guidelines for publishing content under Creative Commons.",
            "type": "SOURCE",
            "author": "Wizards of the Coast",
            "publication_date": "2024-01-01T00:00:00",
            "permalink": "https://dnd.wizards.com/resources/systems-reference-document",
            "distance_unit": "feet",
            "weight_unit": "lb"
        },
        {
            "url": "https://api.open5e.com/v2/documents/tdcs/",
            "key": "tdcs",
            "licenses": [
                {
                    "name": "OPEN GAME LICENSE Version 1.0a",
                    "key": "ogl-10a",
                    "url": "https://api.open5e.com/v2/licenses/ogl-10a/"
                }
            ],
            "publisher": {
                "name": "Green Ronin Publishing",
                "key": "green-ronin",
                "url": "https://api.open5e.com/v2/publishers/green-ronin/"
            },
            "gamesystem": {
                "name": "5th Edition 2014",
                "key": "5e-2014",
                "url": "https://api.open5e.com/v2/gamesystems/5e-2014/"
            },
            "display_name": "Tal'dorei Campaign Setting",
            "name": "Tal'dorei Campaign Setting",
            "desc": "Critical Role: Tal'Dorei Campaign Setting is a sourcebook that details the continent of Tal'Dorei from the Critical Role campaign setting for the 5th edition of the Dungeons & Dragons fantasy role-playing game. It was published by Green Ronin Publishing and released on August 17, 2017.",
            "type": "SOURCE",
            "author": "Matthew Mercer, James Haeck",
            "publication_date": "2017-08-17T00:00:00",
            "permalink": "https://en.wikipedia.org/wiki/Critical_Role%3A_Tal'Dorei_Campaign_Setting",
            "distance_unit": "feet",
            "weight_unit": "lb"
        },
        {
            "url": "https://api.open5e.com/v2/documents/tob/",
            "key": "tob",
            "licenses": [
                {
                    "name": "OPEN GAME LICENSE Version 1.0a",
                    "key": "ogl-10a",
                    "url": "https://api.open5e.com/v2/licenses/ogl-10a/"
                }
            ],
            "publisher": {
                "name": "Kobold Press",
                "key": "kobold-press",
                "url": "https://api.open5e.com/v2/publishers/kobold-press/"
            },
            "gamesystem": {
                "name": "5th Edition 2014",
                "key": "5e-2014",
                "url": "https://api.open5e.com/v2/gamesystems/5e-2014/"
            },
            "display_name": "Tome of Beasts",
            "name": "Tome of Beasts",
            "desc": "Tome of Beasts from Kobold Press brings more than 400 new monsters to the 5th Edition! Use them in your favorite setting for fantasy adventure! Pick up Tome of Beasts and give your players an encounter they won’t soon forget.",
            "type": "SOURCE",
            "author": "Chris Harris, Dan Dillon, Rodrigo Garcia Carmona, and Wolfgang Baur",
            "publication_date": "2016-01-01T00:00:00",
            "permalink": "https://koboldpress.com/tome-of-beasts/",
            "distance_unit": "feet",
            "weight_unit": "lb"
        },
        {
            "url": "https://api.open5e.com/v2/documents/tob-2023/",
            "key": "tob-2023",
            "licenses": [
                {
                    "name": "OPEN GAME LICENSE Version 1.0a",
                    "key": "ogl-10a",
                    "url": "https://api.open5e.com/v2/licenses/ogl-10a/"
                }
            ],
            "publisher": {
                "name": "Kobold Press",
                "key": "kobold-press",
                "url": "https://api.open5e.com/v2/publishers/kobold-press/"
            },
            "gamesystem": {
                "name": "5th Edition 2014",
                "key": "5e-2014",
                "url": "https://api.open5e.com/v2/gamesystems/5e-2014/"
            },
            "display_name": "Tome of Beasts 1 (2023 Edition)",
            "name": "Tome of Beasts 1 (2023 Edition)",
            "desc": "Whether you need dungeon vermin or world-shaking villains, the Tome of Beasts 1 (2023 Edition) has it. This book presents more than 400 foes suitable for any campaign setting—from tiny drakes and peculiar spiders to demon lords and ancient dragons.\r\n\r\nTome of Beasts 1 (2023 Edition) introduces new foes and upgrades monsters that originally appeared in Tome of Beasts, including:\r\n\r\n    Updates to include errata and streamline mechanics\r\n    11 new creatures like the ashwalker, planewatcher, and the ancient cave dragon\r\n    Expanded tables by creature type and terrain\r\n    New monster art—and much more!",
            "type": "SOURCE",
            "author": "Dan Dillon, Chris Harris, Rodrigo Garcia Carmona, Wolfgang Baur",
            "publication_date": "2024-03-22T00:00:00",
            "permalink": "https://koboldpress.com/kpstore/product/tome-of-beasts-1-2023-edition-hardcover/",
            "distance_unit": "feet",
            "weight_unit": "lb"
        },
        {
            "url": "https://api.open5e.com/v2/documents/tob2/",
            "key": "tob2",
            "licenses": [
                {
                    "name": "OPEN GAME LICENSE Version 1.0a",
                    "key": "ogl-10a",
                    "url": "https://api.open5e.com/v2/licenses/ogl-10a/"
                }
            ],
            "publisher": {
                "name": "Kobold Press",
                "key": "kobold-press",
                "url": "https://api.open5e.com/v2/publishers/kobold-press/"
            },
            "gamesystem": {
                "name": "5th Edition 2014",
                "key": "5e-2014",
                "url": "https://api.open5e.com/v2/gamesystems/5e-2014/"
            },
            "display_name": "Tome of Beasts 2",
            "name": "Tome of Beasts 2",
            "desc": "From the creators of the original Tome of Beasts! Kobold Press has wrangled a new horde of wildly original, often lethal, and highly entertaining 5E-compatible monsters to challenge new players and veterans alike.\r\n\r\nThe Tome of Beasts 2 brings 400 new monsters to 5th edition, from angelic enforcers, sasquatch, and shriekbats, to psychic vampires, zombie dragons, and so much more.\r\n\r\nIn addition to the hardcover volume and PDFs, there’s also Tome of Beasts 2: Pawns and Tome of Beasts 2: Lairs with beautiful maps and more!",
            "type": "SOURCE",
            "author": "Wolfgang Baur, Celeste Conowitch, Darrin Drader, James Introcaso, Philip Larwood, Jeff Lee, Kelly Pawlik, Brian Suskind, Mike Welham",
            "publication_date": "2020-10-20T00:00:00",
            "permalink": "https://koboldpress.com/tome-of-beasts-2/",
            "distance_unit": "feet",
            "weight_unit": "lb"
        },
        {
            "url": "https://api.open5e.com/v2/documents/tob3/",
            "key": "tob3",
            "licenses": [
                {
                    "name": "OPEN GAME LICENSE Version 1.0a",
                    "key": "ogl-10a",
                    "url": "https://api.open5e.com/v2/licenses/ogl-10a/"
                }
            ],
            "publisher": {
                "name": "Kobold Press",
                "key": "kobold-press",
                "url": "https://api.open5e.com/v2/publishers/kobold-press/"
            },
            "gamesystem": {
                "name": "5th Edition 2014",
                "key": "5e-2014",
                "url": "https://api.open5e.com/v2/gamesystems/5e-2014/"
            },
            "display_name": "Tome of Beasts 3",
            "name": "Tome of Beasts 3",
            "desc": "Coming soon to Kickstarter, with over 400 monsters at your fingertips, Tome of Beasts 3 is sure to challenge, delight, and even terrify your players:\r\n\r\n    An appendix filled with NPCs\r\n    Monsters designed by guest designers, such as B. Dave Walters, Gail Simone, and many more\r\n    Monsters designed by our very own backers\r\n    Monsters ranging from familiars to coastal environments to towering undead to forest-haunting dragons\r\n    Backers can playtest the monsters!\r\n\r\nTome of Beasts 3 Lairs contains 18 mapped adventures, plus any reached stretch-goal adventures, including:\r\n\r\n    A shipwreck filled with treasure—and danger!\r\n    A bakery-owning drake with a spooky problem\r\n    A cult hunting a fey that can allow them to travel the planes\r\n    A farmer whose prize-winning sheep are disappearing",
            "type": "SOURCE",
            "author": "Wolfgang Baur, Celeste Conowitch, Darrin Drader, James Introcaso, Philip Larwood, Jeff Lee, Kelly Pawlik, Brian Suskind, Mike Welham",
            "publication_date": "2022-01-10T00:00:00",
            "permalink": "https://koboldpress.com/tome-of-beasts-3/",
            "distance_unit": null,
            "weight_unit": "lb"
        },
        {
            "url": "https://api.open5e.com/v2/documents/toh/",
            "key": "toh",
            "licenses": [
                {
                    "name": "OPEN GAME LICENSE Version 1.0a",
                    "key": "ogl-10a",
                    "url": "https://api.open5e.com/v2/licenses/ogl-10a/"
                }
            ],
            "publisher": {
                "name": "Kobold Press",
                "key": "kobold-press",
                "url": "https://api.open5e.com/v2/publishers/kobold-press/"
            },
            "gamesystem": {
                "name": "5th Edition 2014",
                "key": "5e-2014",
                "url": "https://api.open5e.com/v2/gamesystems/5e-2014/"
            },
            "display_name": "Tome of Heroes",
            "name": "Tome of Heroes",
            "desc": "Tome of Heroes Open-Gaming License Content by Kobold Press",
            "type": "SOURCE",
            "author": "Kelly Pawlik, Ben Mcfarland, and Briand Suskind",
            "publication_date": "2022-06-01T00:00:00",
            "permalink": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/",
            "distance_unit": "feet",
            "weight_unit": "lb"
        },
        {
            "url": "https://api.open5e.com/v2/documents/vom/",
            "key": "vom",
            "licenses": [
                {
                    "name": "OPEN GAME LICENSE Version 1.0a",
                    "key": "ogl-10a",
                    "url": "https://api.open5e.com/v2/licenses/ogl-10a/"
                }
            ],
            "publisher": {
                "name": "Kobold Press",
                "key": "kobold-press",
                "url": "https://api.open5e.com/v2/publishers/kobold-press/"
            },
            "gamesystem": {
                "name": "5th Edition 2014",
                "key": "5e-2014",
                "url": "https://api.open5e.com/v2/gamesystems/5e-2014/"
            },
            "display_name": "Vault of Magic",
            "name": "Vault of Magic",
            "desc": "Inside Vault of Magic, you’ll find a vast treasure trove of enchanted items of every imaginable use—more than 900 in all! There are plenty of armors, weapons, potions, rings, and wands, but that’s just for starters. From mirrors to masks, edibles to earrings, and lanterns to lockets, it’s all here, ready for you to use in your 5th Edition game.\r\n\r\nThis 240-page volume includes:\r\n\r\n    More than 30 unique items developed by special guests, including Patrick Rothfuss, Gail Simone, Deborah Ann Woll, and Luke Gygax\r\n    Fabled items that grow in power as characters rise in levels\r\n    New item themes, such as monster-inspired, clockwork, and apprentice wizards\r\n    Hundreds of full-color illustrations\r\n    25 treasure-generation tables sorted by rarity and including magic items from the core rules\r\n\r\nAmaze and delight your players and spice up your 5th Edition campaign with fresh, new enchanted items from Vault of Magic. It’ll turn that next treasure hoard into something . . . wondrous!\r\n\r\nSKU: KOB-9245-DnD-5E",
            "type": "SOURCE",
            "author": "Phillip Larwood, Jeff Lee, and Christopher Lockey",
            "publication_date": "2021-11-20T00:00:00",
            "permalink": "https://koboldpress.com/kpstore/product/vault-of-magic-for-5th-edition/",
            "distance_unit": "feet",
            "weight_unit": "lb"
        },
        {
            "url": "https://api.open5e.com/v2/documents/wz/",
            "key": "wz",
            "licenses": [
                {
                    "name": "OPEN GAME LICENSE Version 1.0a",
                    "key": "ogl-10a",
                    "url": "https://api.open5e.com/v2/licenses/ogl-10a/"
                }
            ],
            "publisher": {
                "name": "Kobold Press",
                "key": "kobold-press",
                "url": "https://api.open5e.com/v2/publishers/kobold-press/"
            },
            "gamesystem": {
                "name": "5th Edition 2014",
                "key": "5e-2014",
                "url": "https://api.open5e.com/v2/gamesystems/5e-2014/"
            },
            "display_name": "Warlock Zine",
            "name": "Warlock Zine",
            "desc": "The Warlock zines published and available on KP's Warlock booklets.",
            "type": "SOURCE",
            "author": "Woflgang Baur, others.",
            "publication_date": "2017-08-02T00:00:00",
            "permalink": "https://koboldpress.com/kpstore/product-category/all-products/warlock-5th-edition-dnd/",
            "distance_unit": "feet",
            "weight_unit": "lb"
        }
    ]
}


Document Instance
list: API endpoint for returning a list of documents.
retrieve: API endpoint for returning a particular document.

GET /v2/documents/a5e-ag/
HTTP 200 OK
Allow: GET, HEAD, OPTIONS
Content-Type: application/json
Vary: Accept

{
    "url": "https://api.open5e.com/v2/documents/a5e-ag/",
    "key": "a5e-ag",
    "licenses": [
        {
            "name": "Creative Commons Attribution 4.0",
            "key": "cc-by-40",
            "url": "https://api.open5e.com/v2/licenses/cc-by-40/"
        },
        {
            "name": "OPEN GAME LICENSE Version 1.0a",
            "key": "ogl-10a",
            "url": "https://api.open5e.com/v2/licenses/ogl-10a/"
        }
    ],
    "publisher": {
        "name": "EN Publishing",
        "key": "en-publishing",
        "url": "https://api.open5e.com/v2/publishers/en-publishing/"
    },
    "gamesystem": {
        "name": "Advanced 5th Edition",
        "key": "a5e",
        "url": "https://api.open5e.com/v2/gamesystems/a5e/"
    },
    "display_name": "Adventurer's Guide",
    "name": "Adventurer's Guide",
    "desc": "In this guide to Level Up, the advanced roleplaying game, you will find everything you need to play. Create diverse and unique heroes, engage in epic combat with villainous foes, cast powerful spells, and build mighty strongholds!",
    "type": "SOURCE",
    "author": "EN Publishing",
    "publication_date": "2021-11-01T00:00:00",
    "permalink": "https://a5esrd.com/a5esrd",
    "distance_unit": "feet",
    "weight_unit": "lb"
}


Background List
list: API endpoint for returning a list of backgrounds.
retrieve: API endpoint for returning a particular background.

«12»
GET /v2/backgrounds/
HTTP 200 OK
Allow: GET, HEAD, OPTIONS
Content-Type: application/json
Vary: Accept

{
    "count": 58,
    "next": "https://api.open5e.com/v2/backgrounds/?page=2",
    "previous": null,
    "results": [
        {
            "url": "https://api.open5e.com/v2/backgrounds/a5e-ag_acolyte/",
            "key": "a5e-ag_acolyte",
            "benefits": [
                {
                    "name": "Ability Score Increases",
                    "desc": "+1 to Wisdom and one other ability score.",
                    "type": "ability_score"
                },
                {
                    "name": "Adventures and Advancement",
                    "desc": "In small settlements without other resources, your authority may extend to such matters as settling disputes and punishing criminals. You might also be expected to deal with local outbreaks of supernatural dangers such as fiendish possessions, cults, and the unquiet dead. \r\nIf you solve several problems brought to you by members of your faith, you may be promoted (or reinstated) within the hierarchy of your order. You gain the free service of up to 4 acolytes, and direct access to your order’s leaders.",
                    "type": "adventures_and_advancement"
                },
                {
                    "name": "Connection and Memento",
                    "desc": "Roll 1d10, choose, or make up your own.\r\n\r\n#### Acolyte Connections\r\n\r\n|d10|Connection|\r\n|---|---|\r\n|1|A beloved high priest or priestess awaiting your return to the temple once you resolve your crisis of faith.|\r\n|2|A former priest—exposed by you as a heretic—who swore revenge before fleeing.|\r\n|3|The wandering herald who rescued you as an orphan and sponsored your entry into your temple.|\r\n|4|The inquisitor who rooted out your heresy (or framed you) and had you banished from your temple.|\r\n|5|The fugitive charlatan or cult leader whom you once revered as a holy person.|\r\n|6|Your scandalous friend, a fellow acolyte who fled the temple in search of worldly pleasures.|\r\n|7|The high priest who discredited your temple and punished the others of your order.|\r\n|8|The wandering adventurer whose tales of glory enticed you from your temple.|\r\n|9|The leader of your order, a former adventurer who sends you on quests to battle your god's enemies.|\r\n|10|The former leader of your order who inexplicably retired to a life of isolation and penance.|\r\n\r\n### Acolyte Memento\r\n\r\n|d10|Memento|\r\n|---|---|\r\n|1|The timeworn holy symbol bequeathed to you by your beloved mentor on their deathbed.|\r\n|2|A precious holy relic secretly passed on to you in a moment of great danger.|\r\n|3|A prayer book which contains strange and sinister deviations from the accepted liturgy.|\r\n|4|A half-complete book of prophecies which seems to hint at danger for your faith—if only the other half could be found!|\r\n|5|A gift from a mentor: a book of complex theology which you don't yet understand.|\r\n|6|Your only possession when you entered the temple as a child: a signet ring bearing a coat of arms.|\r\n|7|A strange candle which never burns down.|\r\n|8|The true name of a devil that you glimpsed while tidying up papers for a sinister visitor.|\r\n|9|A weapon (which seems to exhibit no magical properties) given to you with great solemnity by your mentor.|\r\n|10|A much-thumbed and heavily underlined prayer book given to you by the fellow acolyte you admire most.|",
                    "type": "connection_and_memento"
                },
                {
                    "name": "Equipment",
                    "desc": "Holy symbol (amulet or reliquary), common clothes, robe, and a prayer book, prayer wheel, or prayer beads.",
                    "type": "equipment"
                },
                {
                    "name": "Languages",
                    "desc": "One of your choice.",
                    "type": "language"
                },
                {
                    "name": "Skill Proficiencies",
                    "desc": "Religion, and either Insight or Persuasion.",
                    "type": "skill_proficiency"
                }
            ],
            "document": {
                "name": "Adventurer's Guide",
                "key": "a5e-ag",
                "type": "SOURCE",
                "display_name": "Adventurer's Guide",
                "publisher": {
                    "name": "EN Publishing",
                    "key": "en-publishing",
                    "url": "https://api.open5e.com/v2/publishers/en-publishing/"
                },
                "gamesystem": {
                    "name": "Advanced 5th Edition",
                    "key": "a5e",
                    "url": "https://api.open5e.com/v2/gamesystems/a5e/"
                },
                "permalink": "https://a5esrd.com/a5esrd"
            },
            "name": "Acolyte",
            "desc": ""
        },
        {
            "url": "https://api.open5e.com/v2/backgrounds/a5e-ag_artisan/",
            "key": "a5e-ag_artisan",
            "benefits": [
                {
                    "name": "Ability Score Increases",
                    "desc": "+1 to Intelligence and one other ability score.",
                    "type": "ability_score"
                },
                {
                    "name": "Adventures And Advancement",
                    "desc": "If you participate in the creation of a magic item (a “master work”), you will gain the services of up to 8 commoner apprentices with the appropriate tool proficiency.",
                    "type": "adventures_and_advancement"
                },
                {
                    "name": "Connection and Memento",
                    "desc": "Roll 1d10, choose, or make up your own.\r\n\r\n#### Artisan Connections\r\n\r\n|d10|Connection|\r\n|---|---|\r\n|1|The cruel master who worked you nearly to death and now does the same to other apprentices.|\r\n|2|The kind master who taught you the trade.|\r\n|3|The powerful figure who refused to pay for your finest work.|\r\n|4|The jealous rival who made a fortune after stealing your secret technique.|\r\n|5|The corrupt rival who framed and imprisoned your mentor.|\r\n|6|The bandit leader who destroyed your mentor's shop and livelihood.|\r\n|7|The crime boss who bankrupted your mentor.|\r\n|8|The shady alchemist who always needs dangerous ingredients to advance the state of your art.|\r\n|9|Your apprentice who went missing.|\r\n|10|The patron who supports your work.|\r\n\r\n### Artisan Mementos\r\n\r\n|d10|Memento|\r\n|---|---|\r\n|1|*Jeweler:* A 10,000 gold commission for a ruby ring (now all you need is a ruby worth 5,000 gold).|\r\n|2|*Smith:* Your blacksmith's hammer (treat as a light hammer).|\r\n|3|*Cook:* A well-seasoned skillet (treat as a mace).|\r\n|4|*Alchemist:* A formula with exotic ingredients that will produce...something.|\r\n|5|*Leatherworker:* An exotic monster hide which could be turned into striking-looking leather armor.|\r\n|6|*Mason:* Your trusty sledgehammer (treat as a warhammer).|\r\n|7|*Potter:* Your secret technique for vivid colors which is sure to disrupt Big Pottery.|\r\n|8|*Weaver:* A set of fine clothes (your own work).|\r\n|9|*Woodcarver:* A longbow, shortbow, or crossbow (your own work).|\r\n|10|*Calligrapher:* Strange notes you copied from a rambling manifesto. Do they mean something?|",
                    "type": "connection_and_memento"
                },
                {
                    "name": "Equipment",
                    "desc": "One set of artisan's tools, traveler's clothes.",
                    "type": "equipment"
                },
                {
                    "name": "Skill Proficiencies",
                    "desc": "Persuasion, and either Insight or History.",
                    "type": "skill_proficiency"
                },
                {
                    "name": "Tool Proficiencies",
                    "desc": "One type of artisan’s tools or smith’s tools.",
                    "type": "tool_proficiency"
                },
                {
                    "name": "Trade Mark",
                    "desc": "When in a city or town, you have access to a fully-stocked workshop with everything you need to ply your trade. Furthermore, you can expect to earn full price when you sell items you have crafted (though there is no guarantee of a buyer).",
                    "type": "feature"
                }
            ],
            "document": {
                "name": "Adventurer's Guide",
                "key": "a5e-ag",
                "type": "SOURCE",
                "display_name": "Adventurer's Guide",
                "publisher": {
                    "name": "EN Publishing",
                    "key": "en-publishing",
                    "url": "https://api.open5e.com/v2/publishers/en-publishing/"
                },
                "gamesystem": {
                    "name": "Advanced 5th Edition",
                    "key": "a5e",
                    "url": "https://api.open5e.com/v2/gamesystems/a5e/"
                },
                "permalink": "https://a5esrd.com/a5esrd"
            },
            "name": "Artisan",
            "desc": ""
        },
        {
            "url": "https://api.open5e.com/v2/backgrounds/a5e-ag_charlatan/",
            "key": "a5e-ag_charlatan",
            "benefits": [
                {
                    "name": "Ability Score Increases",
                    "desc": "+1 to Charisma and one other ability score.",
                    "type": "ability_score"
                },
                {
                    "name": "Adventures and Advancement",
                    "desc": "If you pull off a long-standing impersonation or false identity with exceptional success, you may eventually legally become that person. If you’re impersonating a real person, they might be considered the impostor. You gain any property and servants associated with your identity.",
                    "type": "adventures_and_advancement"
                },
                {
                    "name": "Connection and Memento",
                    "desc": "Roll 1d10, choose, or make up your own.\r\n\r\n#### Charlatan Connections\r\n\r\n|d10|Connection|\r\n|---|---|\r\n|1|A relentless pursuer: an inspector who you once made a fool of.|\r\n|2|A relentless pursuer: a mark you once cheated.|\r\n|3|A relentless pursuer: a former partner just out of jail who blames you for everything.|\r\n|4|A former partner now gone straight who couldn't possibly be coaxed out of retirement.|\r\n|5|A respected priest or tavernkeeper who tips you off about rich potential marks.|\r\n|6|The elusive former partner who ratted you out and sent you to jail.|\r\n|7|A famous noble or politician who through sheer luck happens to bear a striking resemblance to you.|\r\n|8|The crook who taught you everything and just can't stay out of trouble.|\r\n|9|A gullible noble who knows you by one of your former aliases, and who always seems to pop up at inconvenient times.|\r\n|10|A prominent noble who knows you only under your assumed name and who trusts you as their spiritual advisor, tutor, long-lost relative, or the like.|\r\n\r\n#### Charlatan Mementos\r\n\r\n|d10|Memento|\r\n|---|---|\r\n|1|A die that always comes up 6.|\r\n|2|A dozen brightly-colored \"potions\".|\r\n|3|A magical staff that emits a harmless shower of sparks when vigorously thumped.|\r\n|4|A set of fine clothes suitable for nobility.|\r\n|5|A genuine document allowing its holder one free release from prison for a non-capital crime.|\r\n|6|A genuine deed to a valuable property that is, unfortunately, quite haunted.|\r\n|7|An ornate harlequin mask.|\r\n|8|Counterfeit gold coins or costume jewelry apparently worth 100 gold (DC 15 Investigation check to notice they're fake).|\r\n|9|A sword that appears more magical than it really is (its blade is enchanted with continual flame and it is a mundane weapon).|\r\n|10|A nonmagical crystal ball.|",
                    "type": "connection_and_memento"
                },
                {
                    "name": "Many Identities",
                    "desc": "You have a bundle of forged papers of all kinds—property deeds, identification papers, love letters, arrest warrants, and letters of recommendation—all requiring only a few signatures and flourishes to meet the current need. When you encounter a new document or letter, you can add a forged and modified copy to your bundle. If your bundle is lost, you can recreate it with a forgery kit and a day’s work.",
                    "type": "feature"
                },
                {
                    "name": "Skill Proficiencies",
                    "desc": "Deception, and either Culture, Insight, or Sleight of Hand.",
                    "type": "skill_proficiency"
                },
                {
                    "name": "Suggested Equipment",
                    "desc": "Common clothes, disguise kit, forgery kit.",
                    "type": "equipment"
                },
                {
                    "name": "Tool Proficiencies",
                    "desc": "Disguise kit, forgery kit.",
                    "type": "tool_proficiency"
                }
            ],
            "document": {
                "name": "Adventurer's Guide",
                "key": "a5e-ag",
                "type": "SOURCE",
                "display_name": "Adventurer's Guide",
                "publisher": {
                    "name": "EN Publishing",
                    "key": "en-publishing",
                    "url": "https://api.open5e.com/v2/publishers/en-publishing/"
                },
                "gamesystem": {
                    "name": "Advanced 5th Edition",
                    "key": "a5e",
                    "url": "https://api.open5e.com/v2/gamesystems/a5e/"
                },
                "permalink": "https://a5esrd.com/a5esrd"
            },
            "name": "Charlatan",
            "desc": ""
        },
        {
            "url": "https://api.open5e.com/v2/backgrounds/a5e-ag_criminal/",
            "key": "a5e-ag_criminal",
            "benefits": [
                {
                    "name": "Ability Score Increases",
                    "desc": "+1 to Dexterity and one other ability score.",
                    "type": "ability_score"
                },
                {
                    "name": "Adventures And Advancement",
                    "desc": "If you pull off several successful jobs or heists, you may be promoted (or reinstated) as a leader in your gang. You may gain the free service of up to 8 **bandits** at any time.",
                    "type": "adventures_and_advancement"
                },
                {
                    "name": "Connection and Memento",
                    "desc": "Roll 1d10, choose, or make up your own.\r\n\r\n#### Criminal Connections\r\n\r\n|d10|Connection|\r\n|---|---|\r\n|1|The master criminal who inducted you into your first gang.|\r\n|2|The cleric or herald who convinced you to use your skills for good (and who may be legally responsible for your continued good behavior).|\r\n|3|Your sibling or other relative—who also happens to be a representative of the law.|\r\n|4|The gang of rascals and pickpockets who once called you their leader.|\r\n|5|The bounty hunter who has sworn to bring you to justice.|\r\n|6|Your former partner who made off with all the loot after a big score.|\r\n|7|The masked courier who occasionally gives you jobs.|\r\n|8|The crime boss to whom you have sworn loyalty (or to whom you owe an enormous debt).|\r\n|9|The master thief who once stole something precious from you.|\r\n|10|The corrupt noble who ruined your once-wealthy family.|\r\n\r\n#### Criminal Mementos\r\n\r\n|d10|Memento|\r\n|---|---|\r\n|1|A golden key to which you haven't discovered the lock.|\r\n|2|A brand that was burned into your shoulder as punishment for a crime.|\r\n|3|A scar for which you have sworn revenge.|\r\n|4|The distinctive mask that gives you your nickname (for instance, the Black Mask or the Red Fox).|\r\n|5|A gold coin which reappears in your possession a week after you've gotten rid of it.|\r\n|6|The stolen symbol of a sinister organization; not even your fence will take it off your hands.|\r\n|7|Documents that incriminate a dangerous noble or politician.|\r\n|8|The floor plan of a palace.|\r\n|9|The calling cards you leave after (or before) you strike.|\r\n|10|A manuscript written by your mentor: *Secret Exits of the World's Most Secure Prisons*.|",
                    "type": "connection_and_memento"
                },
                {
                    "name": "Equipment",
                    "desc": "Common clothes, dark cloak, thieves' tools.",
                    "type": "equipment"
                },
                {
                    "name": "Skill Proficiencies",
                    "desc": "Stealth, and either Deception or Intimidation.",
                    "type": "skill_proficiency"
                },
                {
                    "name": "Thieves' Cant",
                    "desc": "You know thieves' cant: a set of slang, hand signals, and code terms used by professional criminals. A creature that knows thieves' cant can hide a short message within a seemingly innocent statement. A listener who knows thieves' cant understands the message.",
                    "type": "feature"
                },
                {
                    "name": "Tool Proficiencies",
                    "desc": "Gaming set, thieves' tools.",
                    "type": "tool_proficiency"
                }
            ],
            "document": {
                "name": "Adventurer's Guide",
                "key": "a5e-ag",
                "type": "SOURCE",
                "display_name": "Adventurer's Guide",
                "publisher": {
                    "name": "EN Publishing",
                    "key": "en-publishing",
                    "url": "https://api.open5e.com/v2/publishers/en-publishing/"
                },
                "gamesystem": {
                    "name": "Advanced 5th Edition",
                    "key": "a5e",
                    "url": "https://api.open5e.com/v2/gamesystems/a5e/"
                },
                "permalink": "https://a5esrd.com/a5esrd"
            },
            "name": "Criminal",
            "desc": ""
        },
        {
            "url": "https://api.open5e.com/v2/backgrounds/a5e-ag_cultist/",
            "key": "a5e-ag_cultist",
            "benefits": [
                {
                    "name": "Ability Score Increases",
                    "desc": "+1 to Intelligence and one other ability score.",
                    "type": "ability_score"
                },
                {
                    "name": "Adventures and Advancement",
                    "desc": "Members of your former order may be hunting you for reenlistment, punishment, or both.\r\nAdditionally, your cult still seeks to open a portal, effect an apotheosis, or otherwise cause catastrophe. Eventually you may have to face the leader of your cult and perhaps even the being you once worshiped.",
                    "type": "adventures_and_advancement"
                },
                {
                    "name": "Connection and Memento",
                    "desc": "Roll 1d10, choose, or make up your own.\r\n\r\n#### Cultist Connections\r\n\r\n|d10|Connection|\r\n|---|---|\r\n|1|The cult leader whom you left for dead.|\r\n|2|The cleric or herald who showed you the error of your ways.|\r\n|3|The voice which still speaks to you in dreams.|\r\n|4|The charismatic cultist whose honeyed words and promises first tempted you.|\r\n|5|The friend or loved one still in the cult.|\r\n|6|Your former best friend who now hunts you for your desertion of the cult.|\r\n|7|The relentless inquisitor who hunts you for your past heresy.|\r\n|8|The demon which you and your compatriots accidentally unleashed.|\r\n|9|The self-proclaimed deity who barely escaped from their angry disciples after their magic tricks and fakeries were revealed.|\r\n|10|The masked cult leader whose identity you never learned, but whose cruel voice you would recognize anywhere.|\r\n\r\n#### Cultist Mementos\r\n\r\n|d10|Memento|\r\n|---|---|\r\n|1|The sinister tattoo which occasionally speaks to you.|\r\n|2|The cursed holy symbol which appears in your possession each morning no matter how you try to rid yourself of it.|\r\n|3|The scar on your palm which aches with pain when you disobey the will of your former master.|\r\n|4|The curved dagger that carries a secret enchantment able only to destroy the being you once worshiped.|\r\n|5|The amulet which is said to grant command of a powerful construct.|\r\n|6|A forbidden tome which your cult would kill to retrieve.|\r\n|7|An incriminating letter to your cult leader from their master (a noted noble or politician).|\r\n|8|A compass which points to some distant location or object.|\r\n|9|A talisman which is said to open a gateway to the realm of a forgotten god.|\r\n|10|The birthmark which distinguishes you as the chosen vessel of a reborn god.|",
                    "type": "connection_and_memento"
                },
                {
                    "name": "Equipment",
                    "desc": "Holy symbol (amulet or reliquary), common clothes, robes, 5 torches.",
                    "type": "equipment"
                },
                {
                    "name": "Forbidden Lore",
                    "desc": "When you fail an Arcana or Religion check, you know what being or book holds the knowledge you seek finding the book or paying the being’s price is another matter.",
                    "type": "feature"
                },
                {
                    "name": "Languages",
                    "desc": "One of your choice.",
                    "type": "language"
                },
                {
                    "name": "Skill Proficiencies",
                    "desc": "Religion, and either Arcana or Deception.",
                    "type": "skill_proficiency"
                }
            ],
            "document": {
                "name": "Adventurer's Guide",
                "key": "a5e-ag",
                "type": "SOURCE",
                "display_name": "Adventurer's Guide",
                "publisher": {
                    "name": "EN Publishing",
                    "key": "en-publishing",
                    "url": "https://api.open5e.com/v2/publishers/en-publishing/"
                },
                "gamesystem": {
                    "name": "Advanced 5th Edition",
                    "key": "a5e",
                    "url": "https://api.open5e.com/v2/gamesystems/a5e/"
                },
                "permalink": "https://a5esrd.com/a5esrd"
            },
            "name": "Cultist",
            "desc": ""
        },
        {
            "url": "https://api.open5e.com/v2/backgrounds/a5e-ag_entertainer/",
            "key": "a5e-ag_entertainer",
            "benefits": [
                {
                    "name": "Ability Score Increases",
                    "desc": "+1 to Charisma and one other ability score.",
                    "type": "ability_score"
                },
                {
                    "name": "Adventures And Advancement",
                    "desc": "Some of your admirers will pay you to plead a cause or smear an enemy. If you succeed at several such quests, your fame will grow. You will be welcome at royal courts, which will support you at a rich lifestyle.",
                    "type": "adventures_and_advancement"
                },
                {
                    "name": "Connection and Memento",
                    "desc": "Roll 1d10, choose, or make up your own.\r\n\r\n#### Entertainer Connections\r\n\r\n|d10|Connection|\r\n|---|---|\r\n|1|Your rival, an equally talented performer.|\r\n|2|The cruel ringleader of the sinister circus where you learned your trade.|\r\n|3|A noble who wants vengeance for the song you wrote about him.|\r\n|4|The actor who says that there's always room in their troupe for you and your companions.|\r\n|5|The noble who owes you a favor for penning the love poems that won their spouse.|\r\n|6|Your former partner, a slumming noble with a good ear and bad judgment.|\r\n|7|The rival who became successful and famous by taking credit for your best work.|\r\n|8|The highly-placed courtier who is always trying to further your career.|\r\n|9|A jilted lover who wants revenge.|\r\n|10|The many tavernkeepers and tailors to whom you owe surprisingly large sums.|\r\n\r\n#### Entertainer Mementos\r\n\r\n|d10|Memento|\r\n|---|---|\r\n|1|Your unfinished masterpiece—if you can find inspiration to overcome your writer's block.|\r\n|2|Fine clothing suitable for a noble and some reasonably convincing costume jewelry.|\r\n|3|A love letter from a rich admirer.|\r\n|4|A broken instrument of masterwork quality—if repaired, what music you could make on it!|\r\n|5|A stack of slim poetry volumes you just can't sell.|\r\n|6|Jingling jester's motley.|\r\n|7|A disguise kit.|\r\n|8|Water-squirting wands, knotted scarves, trick handcuffs, and other tools of a bizarre new entertainment trend: a nonmagical magic show.|\r\n|9|A stage dagger.|\r\n|10|A letter of recommendation from your mentor to a noble or royal court.|",
                    "type": "connection_and_memento"
                },
                {
                    "name": "Equipment",
                    "desc": "Lute or other musical instrument, costume.",
                    "type": "equipment"
                },
                {
                    "name": "Pay the Piper",
                    "desc": "In any settlement in which you haven't made yourself unpopular, your performances can earn enough money to support yourself and your companions: the bigger the settlement, the higher your standard of living, up to a moderate lifestyle in a city.",
                    "type": "feature"
                },
                {
                    "name": "Skill Proficiencies",
                    "desc": "Performance, and either Acrobatics, Culture, or Persuasion.",
                    "type": "skill_proficiency"
                }
            ],
            "document": {
                "name": "Adventurer's Guide",
                "key": "a5e-ag",
                "type": "SOURCE",
                "display_name": "Adventurer's Guide",
                "publisher": {
                    "name": "EN Publishing",
                    "key": "en-publishing",
                    "url": "https://api.open5e.com/v2/publishers/en-publishing/"
                },
                "gamesystem": {
                    "name": "Advanced 5th Edition",
                    "key": "a5e",
                    "url": "https://api.open5e.com/v2/gamesystems/a5e/"
                },
                "permalink": "https://a5esrd.com/a5esrd"
            },
            "name": "Entertainer",
            "desc": ""
        },
        {
            "url": "https://api.open5e.com/v2/backgrounds/a5e-ag_exile/",
            "key": "a5e-ag_exile",
            "benefits": [
                {
                    "name": "Ability Score Increases",
                    "desc": "+1 to Wisdom and one other ability score.",
                    "type": "ability_score"
                },
                {
                    "name": "Adventures And Advancement",
                    "desc": "You may occasionally meet others from your native land. Some may be friends, and some dire enemies; few will be indifferent to you. After a few such encounters, you may become the leader of a faction of exiles. Your followers include up to three NPCs of Challenge Rating ½ or less, such as scouts.",
                    "type": "adventures_and_advancement"
                },
                {
                    "name": "Connection and Memento",
                    "desc": "Roll 1d10, choose, or make up your own.\r\n\r\n#### Exile Connections\r\n\r\n|d10|Connection|\r\n|---|---|\r\n|1|The companions who shared your exile.|\r\n|2|The kindly local who taught you Common.|\r\n|3|The shopkeeper or innkeeper who took you in and gave you work.|\r\n|4|The hunters from your native land who pursue you.|\r\n|5|The distant ruler who banished you until you redeem yourself.|\r\n|6|The community of fellow exiles who have banded together in a city neighborhood.|\r\n|7|The acting or carnival troupe which took you in.|\r\n|8|The suspicious authorities who were convinced you were a spy.|\r\n|9|Your first friend after your exile: a grizzled adventurer who traveled with you.|\r\n|10|A well-connected and unscrupulous celebrity who hails from your homeland.|\r\n\r\n#### Exile Mementos\r\n\r\n|d10|Memento|\r\n|---|---|\r\n|1|A musical instrument which was common in your homeland.|\r\n|2|A memorized collection of poems or sagas.|\r\n|3|A locket containing a picture of your betrothed from whom you are separated.|\r\n|4|Trade, state, or culinary secrets from your native land.|\r\n|5|A piece of jewelry given to you by someone you will never see again.|\r\n|6|An inaccurate, ancient map of the land you now live in.|\r\n|7|Your incomplete travel journals.|\r\n|8|A letter from a relative directing you to someone who might be able to help you.|\r\n|9|A precious cultural artifact you must protect.|\r\n|10|An arrow meant for the heart of your betrayer.|",
                    "type": "connection_and_memento"
                },
                {
                    "name": "Equipment",
                    "desc": "Traveler's clothes, 10 days rations.",
                    "type": "equipment"
                },
                {
                    "name": "Fellow Traveler",
                    "desc": "You gain an expertise die on Persuasion checks against others who are away from their land of birth.",
                    "type": "feature"
                },
                {
                    "name": "Skill Proficiencies",
                    "desc": "Survival, and either History or Performance.",
                    "type": "skill_proficiency"
                }
            ],
            "document": {
                "name": "Adventurer's Guide",
                "key": "a5e-ag",
                "type": "SOURCE",
                "display_name": "Adventurer's Guide",
                "publisher": {
                    "name": "EN Publishing",
                    "key": "en-publishing",
                    "url": "https://api.open5e.com/v2/publishers/en-publishing/"
                },
                "gamesystem": {
                    "name": "Advanced 5th Edition",
                    "key": "a5e",
                    "url": "https://api.open5e.com/v2/gamesystems/a5e/"
                },
                "permalink": "https://a5esrd.com/a5esrd"
.......



Background Instance
list: API endpoint for returning a list of backgrounds.
retrieve: API endpoint for returning a particular background.

GET /v2/backgrounds/a5e-ag_acolyte/
HTTP 200 OK
Allow: GET, HEAD, OPTIONS
Content-Type: application/json
Vary: Accept

{
    "url": "https://api.open5e.com/v2/backgrounds/a5e-ag_acolyte/",
    "key": "a5e-ag_acolyte",
    "benefits": [
        {
            "name": "Ability Score Increases",
            "desc": "+1 to Wisdom and one other ability score.",
            "type": "ability_score"
        },
        {
            "name": "Adventures and Advancement",
            "desc": "In small settlements without other resources, your authority may extend to such matters as settling disputes and punishing criminals. You might also be expected to deal with local outbreaks of supernatural dangers such as fiendish possessions, cults, and the unquiet dead. \r\nIf you solve several problems brought to you by members of your faith, you may be promoted (or reinstated) within the hierarchy of your order. You gain the free service of up to 4 acolytes, and direct access to your order’s leaders.",
            "type": "adventures_and_advancement"
        },
        {
            "name": "Connection and Memento",
            "desc": "Roll 1d10, choose, or make up your own.\r\n\r\n#### Acolyte Connections\r\n\r\n|d10|Connection|\r\n|---|---|\r\n|1|A beloved high priest or priestess awaiting your return to the temple once you resolve your crisis of faith.|\r\n|2|A former priest—exposed by you as a heretic—who swore revenge before fleeing.|\r\n|3|The wandering herald who rescued you as an orphan and sponsored your entry into your temple.|\r\n|4|The inquisitor who rooted out your heresy (or framed you) and had you banished from your temple.|\r\n|5|The fugitive charlatan or cult leader whom you once revered as a holy person.|\r\n|6|Your scandalous friend, a fellow acolyte who fled the temple in search of worldly pleasures.|\r\n|7|The high priest who discredited your temple and punished the others of your order.|\r\n|8|The wandering adventurer whose tales of glory enticed you from your temple.|\r\n|9|The leader of your order, a former adventurer who sends you on quests to battle your god's enemies.|\r\n|10|The former leader of your order who inexplicably retired to a life of isolation and penance.|\r\n\r\n### Acolyte Memento\r\n\r\n|d10|Memento|\r\n|---|---|\r\n|1|The timeworn holy symbol bequeathed to you by your beloved mentor on their deathbed.|\r\n|2|A precious holy relic secretly passed on to you in a moment of great danger.|\r\n|3|A prayer book which contains strange and sinister deviations from the accepted liturgy.|\r\n|4|A half-complete book of prophecies which seems to hint at danger for your faith—if only the other half could be found!|\r\n|5|A gift from a mentor: a book of complex theology which you don't yet understand.|\r\n|6|Your only possession when you entered the temple as a child: a signet ring bearing a coat of arms.|\r\n|7|A strange candle which never burns down.|\r\n|8|The true name of a devil that you glimpsed while tidying up papers for a sinister visitor.|\r\n|9|A weapon (which seems to exhibit no magical properties) given to you with great solemnity by your mentor.|\r\n|10|A much-thumbed and heavily underlined prayer book given to you by the fellow acolyte you admire most.|",
            "type": "connection_and_memento"
        },
        {
            "name": "Equipment",
            "desc": "Holy symbol (amulet or reliquary), common clothes, robe, and a prayer book, prayer wheel, or prayer beads.",
            "type": "equipment"
        },
        {
            "name": "Languages",
            "desc": "One of your choice.",
            "type": "language"
        },
        {
            "name": "Skill Proficiencies",
            "desc": "Religion, and either Insight or Persuasion.",
            "type": "skill_proficiency"
        }
    ],
    "document": {
        "name": "Adventurer's Guide",
        "key": "a5e-ag",
        "type": "SOURCE",
        "display_name": "Adventurer's Guide",
        "publisher": {
            "name": "EN Publishing",
            "key": "en-publishing",
            "url": "https://api.open5e.com/v2/publishers/en-publishing/"
        },
        "gamesystem": {
            "name": "Advanced 5th Edition",
            "key": "a5e",
            "url": "https://api.open5e.com/v2/gamesystems/a5e/"
        },
        "permalink": "https://a5esrd.com/a5esrd"
    },
    "name": "Acolyte",
    "desc": ""
}


Plane List
list: API endpoint for returning a list of planes.
retrieve: API endpoint for returning a particular plane.

GET /v1/planes/
HTTP 200 OK
Allow: GET, HEAD, OPTIONS
Content-Type: application/json
Vary: Accept

{
    "count": 8,
    "next": null,
    "previous": null,
    "results": [
        {
            "slug": "astral-plane",
            "name": "Astral Plane",
            "desc": "The **Astral Plane** is the realm of thought and dream, where visitors travel as disembodied souls to reach the planes of the divine and demonic. It is a great, silvery sea, the same above and below, with swirling wisps of white and gray streaking among motes of light resembling distant stars. Erratic whirlpools of color flicker in midair like spinning coins. Occasional bits of solid matter can be found here, but most of the Astral Plane is an endless, open domain.",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Transitive Planes"
        },
        {
            "slug": "beyond-the-material",
            "name": "Beyond the Material",
            "desc": "Beyond the Material Plane, the various planes of existence are realms of myth and mystery. They’re not simply other worlds, but different qualities of being, formed and governed by spiritual and elemental principles abstracted from the ordinary world.\n### Planar Travel\nWhen adventurers travel into other planes of existence, they are undertaking a legendary journey across the thresholds of existence to a mythic destination where they strive to complete their quest. Such a journey is the stuff of legend. Braving the realms of the dead, seeking out the celestial servants of a deity, or bargaining with an efreeti in its home city will be the subject of song and story for years to come.\nTravel to the planes beyond the Material Plane can be accomplished in two ways: by casting a spell or by using a planar portal.\n**_Spells._** A number of spells allow direct or indirect access to other planes of existence. _Plane shift_ and _gate_ can transport adventurers directly to any other plane of existence, with different degrees of precision. _Etherealness_ allows adventurers to enter the Ethereal Plane and travel from there to any of the planes it touches—such as the Elemental Planes. And the _astral projection_ spell lets adventurers project themselves into the Astral Plane and travel to the Outer Planes.\n**_Portals._** A portal is a general term for a stationary interplanar connection that links a specific location on one plane to a specific location on another. Some portals are like doorways, a clear window, or a fogshrouded passage, and simply stepping through it effects the interplanar travel. Others are locations— circles of standing stones, soaring towers, sailing ships, or even whole towns—that exist in multiple planes at once or flicker from one plane to another in turn. Some are vortices, typically joining an Elemental Plane with a very similar location on the Material Plane, such as the heart of a volcano (leading to the Plane of Fire) or the depths of the ocean (to the Plane of Water).",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": null
        },
        {
            "slug": "demiplanes",
            "name": "Demiplanes",
            "desc": "Demiplanes are small extradimensional spaces with their own unique rules. They are pieces of reality that don’t seem to fit anywhere else. Demiplanes come into being by a variety of means. Some are created by spells, such as _demiplane_, or generated at the desire of a powerful deity or other force. They may exist naturally, as a fold of existing reality that has been pinched off from the rest of the multiverse, or as a baby universe growing in power. A given demiplane can be entered through a single point where it touches another plane. Theoretically, a _plane shift_ spell can also carry travelers to a demiplane, but the proper frequency required for the tuning fork is extremely hard to acquire. The _gate_ spell is more reliable, assuming the caster knows of the demiplane.",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Uncategorized Planes"
        },
        {
            "slug": "ethereal-plane",
            "name": "Ethereal Plane",
            "desc": "The **Ethereal Plane** is a misty, fog-bound dimension that is sometimes described as a great ocean. Its shores, called the Border Ethereal, overlap the Material Plane and the Inner Planes, so that every location on those planes has a corresponding location on the Ethereal Plane. Certain creatures can see into the Border Ethereal, and the _see invisibility_ and _true seeing_ spell grant that ability. Some magical effects also extend from the Material Plane into the Border Ethereal, particularly effects that use force energy such as _forcecage_ and _wall of force_. The depths of the plane, the Deep Ethereal, are a region of swirling mists and colorful fogs.",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Transitive Planes"
        },
        {
            "slug": "inner-planes",
            "name": "Inner Planes",
            "desc": "The Inner Planes surround and enfold the Material Plane and its echoes, providing the raw elemental substance from which all the worlds were made. The four **Elemental Planes**—Air, Earth, Fire, and Water—form a ring around the Material Plane, suspended within the churning **Elemental Chaos**.\nAt their innermost edges, where they are closest to the Material Plane (in a conceptual if not a literal geographical sense), the four Elemental Planes resemble a world in the Material Plane. The four elements mingle together as they do in the Material Plane, forming land, sea, and sky. Farther from the Material Plane, though, the Elemental Planes are both alien and hostile. Here, the elements exist in their purest form—great expanses of solid earth, blazing fire, crystal-clear water, and unsullied air. These regions are little-known, so when discussing the Plane of Fire, for example, a speaker usually means just the border region. At the farthest extents of the Inner Planes, the pure elements dissolve and bleed together into an unending tumult of clashing energies and colliding substance, the Elemental Chaos.",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Beyond the Material"
        },
        {
            "slug": "outer-planes",
            "name": "Outer Planes",
            "desc": "If the Inner Planes are the raw matter and energy that makes up the multiverse, the Outer Planes are the direction, thought and purpose for such construction. Accordingly, many sages refer to the Outer Planes as divine planes, spiritual planes, or godly planes, for the Outer Planes are best known as the homes of deities.\nWhen discussing anything to do with deities, the language used must be highly metaphorical. Their actual homes are not literally “places” at all, but exemplify the idea that the Outer Planes are realms of thought and spirit. As with the Elemental Planes, one can imagine the perceptible part of the Outer Planes as a sort of border region, while extensive spiritual regions lie beyond ordinary sensory experience.\nEven in those perceptible regions, appearances can be deceptive. Initially, many of the Outer Planes appear hospitable and familiar to natives of the Material Plane. But the landscape can change at the whims of the powerful forces that live on the Outer Planes. The desires of the mighty forces that dwell on these planes can remake them completely, effectively erasing and rebuilding existence itself to better fulfill their own needs.\nDistance is a virtually meaningless concept on the Outer Planes. The perceptible regions of the planes often seem quite small, but they can also stretch on to what seems like infinity. It might be possible to take a guided tour of the Nine Hells, from the first layer to the ninth, in a single day—if the powers of the Hells desire it. Or it could take weeks for travelers to make a grueling trek across a single layer.\nThe most well-known Outer Planes are a group of sixteen planes that correspond to the eight alignments (excluding neutrality) and the shades of distinction between them.\nThe planes with some element of good in their nature are called the **Upper Planes**. Celestial creatures such as angels and pegasi dwell in the Upper Planes. Planes with some element of evil are the **Lower Planes**. Fiends such as demons and devils dwell in the Lower Planes. A plane’s alignment is its essence, and a character whose alignment doesn’t match the plane’s experiences a profound sense of dissonance there. When a good creature visits Elysium, for example (a neutral good Upper Plane), it feels in tune with the plane, but an evil creature feels out of tune and more than a little uncomfortable.",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Beyond the Material"
        },
        {
            "slug": "the-material-plane",
            "name": "The Material Plane",
            "desc": "The Material Plane is the nexus where the philosophical and elemental forces that define the other planes collide in the jumbled existence of mortal life and mundane matter. All fantasy gaming worlds exist within the Material Plane, making it the starting point for most campaigns and adventures. The rest of the multiverse is defined in relation to the Material Plane.\nThe worlds of the Material Plane are infinitely diverse, for they reflect the creative imagination of the GMs who set their games there, as well as the players whose heroes adventure there. They include magic-wasted desert planets and island-dotted water worlds, worlds where magic combines with advanced technology and others trapped in an endless Stone Age, worlds where the gods walk and places they have abandoned.",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": null
        },
        {
            "slug": "transitive-planes",
            "name": "Transitive Planes",
            "desc": "The Ethereal Plane and the Astral Plane are called the Transitive Planes. They are mostly featureless realms that serve primarily as ways to travel from one plane to another. Spells such as _etherealness_ and _astral projection_ allow characters to enter these planes and traverse them to reach the planes beyond.",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Beyond the Material"
        }
    ]
}


Section List
list: API endpoint for returning a list of sections.
retrieve: API endpoint for returning a particular section.

GET /v1/sections/
HTTP 200 OK
Allow: GET, HEAD, OPTIONS
Content-Type: application/json
Vary: Accept

{
    "count": 45,
    "next": null,
    "previous": null,
    "results": [
        {
            "slug": "abilities",
            "name": "Abilities",
            "desc": "Six abilities provide a quick description of every creature's physical and mental characteristics:\n\n- **Strength**, measuring physical power\n - **Dexterity**, measuring agility\n - **Constitution**, measuring endurance \n - **Intelligence**, measuring reasoning and memory \n - **Wisdom**, measuring perception and insight \n - **Charisma**, measuring force of personality\n\n\nIs a character muscle-bound and insightful? Brilliant and charming? Nimble and hardy? Ability scores define these qualities---a creature's assets as well as weaknesses.\n\nThe three main rolls of the game---the ability check, the saving throw, and the attack roll---rely on the six ability scores. The book's introduction describes the basic rule behind these rolls: roll a d20, add an ability modifier derived from one of the six ability scores, and compare the total to a target number\n\n## Ability Scores and Modifiers\n\n Each of a creature's abilities has a score, a number that defines the magnitude of that ability. An ability score is not just a measure of innate capabilities, but also encompasses a creature's training and competence in activities related to that ability.\n\nA score of 10 or 11 is the normal human average, but adventurers and many monsters are a cut above average in most abilities. A score of 18 is the highest that a person usually reaches. Adventurers can have scores as high as 20, and monsters and divine beings can have scores as high as 30.\n\nEach ability also has a modifier, derived from the score and ranging from -5 (for an ability score of 1) to +10 (for a score of 30). The Ability Scores and Modifiers table notes the ability modifiers for the range of possible ability scores, from 1 to 30.\n\n  To determine an ability modifier without consulting the table, subtract 10 from the ability score and then divide the total by 2 (round down).\n\n Because ability modifiers affect almost every attack roll, ability check, and saving throw, ability modifiers come up in play more often than their associated scores.\n\n## Advantage and Disadvantage\n\nSometimes a special ability or spell tells you that you have advantage or disadvantage on an ability check, a saving throw, or an attack roll.\nWhen that happens, you roll a second d20 when you make the roll. Use the higher of the two rolls if you have advantage, and use the lower roll if you have disadvantage. For example, if you have disadvantage and roll a 17 and a 5, you use the 5. If you instead have advantage and roll those numbers, you use the 17.\n\nIf multiple situations affect a roll and each one grants advantage or imposes disadvantage on it, you don't roll more than one additional d20.\nIf two favorable situations grant advantage, for example, you still roll only one additional d20.\n\nIf circumstances cause a roll to have both advantage and disadvantage, you are considered to have neither of them, and you roll one d20. This is true even if multiple circumstances impose disadvantage and only one grants advantage or vice versa. In such a situation, you have neither advantage nor disadvantage.\n\nWhen you have advantage or disadvantage and something in the game, such as the halfling's Lucky trait, lets you reroll the d20, you can reroll only one of the dice. You choose which one. For example, if a halfling has advantage or disadvantage on an ability check and rolls a 1 and a 13, the halfling could use the Lucky trait to reroll the 1.\n\nYou usually gain advantage or disadvantage through the use of special abilities, actions, or spells. Inspiration can also give a character advantage. The GM can also decide that circumstances influence a roll in one direction or the other and grant advantage or impose disadvantage as a result.\n\n## Proficiency Bonus  \nCharacters have a proficiency bonus determined by level. Monsters also have this bonus, which is incorporated in their stat blocks. The bonus is used in the rules on ability checks, saving throws, and attack rolls.\n\nYour proficiency bonus can't be added to a single die roll or other number more than once. For example, if two different rules say you can add your proficiency bonus to a Wisdom saving throw, you nevertheless add the bonus only once when you make the save.\n\nOccasionally, your proficiency bonus might be multiplied or divided (doubled or halved, for example) before you apply it. For example, the rogue's Expertise feature doubles the proficiency bonus for certain ability checks. If a circumstance suggests that your proficiency bonus applies more than once to the same roll, you still add it only once and multiply or divide it only once.\n\nBy the same token, if a feature or effect allows you to multiply your proficiency bonus when making an ability check that wouldn't normally benefit from your proficiency bonus, you still don't add the bonus to the check. For that check your proficiency bonus is 0, given the fact that multiplying 0 by any number is still 0. For instance, if you lack proficiency in the History skill, you gain no benefit from a feature that lets you double your proficiency bonus when you make Intelligence (History) checks.\n\nIn general, you don't multiply your proficiency bonus for attack rolls or saving throws. If a feature or effect allows you to do so, these same rules apply.\n\n## Ability Checks  \nAn ability check tests a character's or monster's innate talent and training in an effort to overcome a challenge. The GM calls for an ability check when a character or monster attempts an action (other than an attack) that has a chance of failure. When the outcome is uncertain, the dice determine the results.\n\nFor every ability check, the GM decides which of the six abilities is relevant to the task at hand and the difficulty of the task, represented by a Difficulty Class.\n\nThe more difficult a task, the higher its DC. The Typical Difficulty Classes table shows the most common DCs.\n\nTo make an ability check, roll a d20 and add the relevant ability modifier. As with other d20 rolls, apply bonuses and penalties, and compare the total to the DC. If the total equals or exceeds the DC, the ability check is a success---the creature overcomes the challenge at hand. Otherwise, it's a failure, which means the character or monster makes no progress toward the objective or makes progress combined with a setback determined by the GM.\n\n### Contests  \nSometimes one character's or monster's efforts are directly opposed to another's. This can occur when both of them are trying to do the same thing and only one can succeed, such as attempting to snatch up a magic ring that has fallen on the floor. This situation also applies when one of them is trying to prevent the other one from accomplishing a goal---for example, when a monster tries to force open a door that an adventurer is holding closed. In situations like these, the outcome is determined by a special form of ability check, called a contest.\n\nBoth participants in a contest make ability checks appropriate to their efforts. They apply all appropriate bonuses and penalties, but instead of comparing the total to a DC, they compare the totals of their two checks. The participant with the higher check total wins the contest.\nThat character or monster either succeeds at the action or prevents the other one from succeeding.\n\nIf the contest results in a tie, the situation remains the same as it was before the contest. Thus, one contestant might win the contest by default. If two characters tie in a contest to snatch a ring off the floor, neither character grabs it. In a contest between a monster trying to open a door and an adventurer trying to keep the door closed, a tie means that the door remains shut.\n\n### Skills\n\n Each ability covers a broad range of capabilities, including skills that a character or a monster can be proficient in. A skill represents a specific aspect of an ability score, and an individual's proficiency in a skill demonstrates a focus on that aspect. (A character's starting skill proficiencies are determined at character creation, and a monster's skill proficiencies appear in the monster's stat block.)  For example, a Dexterity check might reflect a character's attempt to pull off an acrobatic stunt, to palm an object, or to stay hidden. Each of these aspects of Dexterity has an associated skill: Acrobatics, Sleight of Hand, and Stealth, respectively. So a character who has proficiency in the Stealth skill is particularly good at Dexterity checks related to sneaking and hiding.\n\nThe skills related to each ability score are shown in the following list. (No skills are related to Constitution.) See an ability's description in the later sections of this section for examples of how to use a skill associated with an ability.\n\n**Strength**\n\n- Athletics\n\n**Dexterity**\n- Acrobatics\n- Sleight of Hand\n- Stealth\n\n**Intelligence**\n\n- Arcana\n- History\n- Investigation\n- Nature\n- Religion\n\n**Wisdom**\n\n- Animal Handling\n- Insight\n- Medicine\n- Perception\n- Survival\n\n**Charisma**\n\n- Deception\n- Intimidation\n- Performance\n- Persuasion\n\n\nSometimes, the GM might ask for an ability check using a specific skill---for example, Make a Wisdom (Perception) check. At other times, a player might ask the GM if proficiency in a particular skill applies to a check. In either case, proficiency in a skill means an individual can add his or her proficiency bonus to ability checks that involve that skill. Without proficiency in the skill, the individual makes a normal ability check.\n\nFor example, if a character attempts to climb up a dangerous cliff, the GM might ask for a Strength (Athletics) check. If the character is proficient in Athletics, the character's proficiency bonus is added to the Strength check. If the character lacks that proficiency, he or she just makes a Strength check.\n\n#### Variant: Skills with Different Abilities  \nNormally, your proficiency in a skill applies only to a specific kind of ability check. Proficiency in Athletics, for example, usually applies to Strength checks. In some situations, though, your proficiency might reasonably apply to a different kind of check. In such cases, the GM might ask for a check using an unusual combination of ability and skill, or you might ask your GM if you can apply a proficiency to a different check. For example, if you have to swim from an offshore island to the mainland, your GM might call for a Constitution check to see if you have the stamina to make it that far. In this case, your GM might allow you to apply your proficiency in Athletics and ask for a Constitution (Athletics) check. So if you're proficient in Athletics, you apply your proficiency bonus to the Constitution check just as you would normally do for a Strength (Athletics) check. Similarly, when your half-orc barbarian uses a display of raw strength to intimidate an enemy, your GM might ask for a Strength (Intimidation) check, even though Intimidation is normally associated with Charisma.\n\n### Passive Checks  \nA passive check is a special kind of ability check that doesn't involve any die rolls. Such a check can represent the average result for a task done repeatedly, such as searching for secret doors over and over again, or can be used when the GM wants to secretly determine whether the characters succeed at something without rolling dice, such as noticing a hidden monster.\n\nHere's how to determine a character's total for a passive check:  > 10 + all modifiers that normally apply to the check  If the character has advantage on the check, add 5. For disadvantage, subtract 5. The game refers to a passive check total as a **score**.\n\nFor example, if a 1st-level character has a Wisdom of 15 and proficiency in Perception, he or she has a passive Wisdom (Perception) score of 14.\n\nThe rules on hiding in the Dexterity section below rely on passive checks, as do the exploration rules.\n\n### Working Together  \nSometimes two or more characters team up to attempt a task. The character who's leading the effort---or the one with the highest ability modifier---can make an ability check with advantage, reflecting the help provided by the other characters. In combat, this requires the Help action.\n\nA character can only provide help if the task is one that he or she could attempt alone. For example, trying to open a lock requires proficiency with thieves' tools, so a character who lacks that proficiency can't help another character in that task. Moreover, a character can help only when two or more individuals working together would actually be productive. Some tasks, such as threading a needle, are no easier with help.\n\n#### Group Checks  \nWhen a number of individuals are trying to accomplish something as a group, the GM might ask for a group ability check. In such a situation, the characters who are skilled at a particular task help cover those who aren't.\n\nTo make a group ability check, everyone in the group makes the ability check. If at least half the group succeeds, the whole group succeeds.\nOtherwise, the group fails.\n\nGroup checks don't come up very often, and they're most useful when all the characters succeed or fail as a group. For example, when adventurers are navigating a swamp, the GM might call for a group Wisdom (Survival) check to see if the characters can avoid the quicksand, sinkholes, and other natural hazards of the environment. If at least half the group succeeds, the successful characters are able to guide their companions out of danger. Otherwise, the group stumbles into one of these hazards.\n\nEvery task that a character or monster might attempt in the game is covered by one of the six abilities. This section explains in more detail what those abilities mean and the ways they are used in the game.\n\n### Strength  \nStrength measures bodily power, athletic training, and the extent to which you can exert raw physical force.\n\n#### Strength Checks  \nA Strength check can model any attempt to lift, push, pull, or break something, to force your body through a space, or to otherwise apply brute force to a situation. The Athletics skill reflects aptitude in certain kinds of Strength checks.\n\n##### Athletics  \nYour Strength (Athletics) check covers difficult situations you encounter while climbing, jumping, or swimming. Examples include the following activities:  - You attempt to climb a sheer or slippery cliff, avoid hazards while   scaling a wall, or cling to a surface while something is trying to   knock you off.\n- You try to jump an unusually long distance or pull off a stunt   midjump.\n- You struggle to swim or stay afloat in treacherous currents,   storm-tossed waves, or areas of thick seaweed. Or another creature   tries to push or pull you underwater or otherwise interfere with   your swimming.\n\n##### Other Strength Checks  \nThe GM might also call for a Strength check when you try to accomplish tasks like the following:  - Force open a stuck, locked, or barred door - Break free of bonds - Push through a tunnel that is too small - Hang on to a wagon while being dragged behind it - Tip over a statue - Keep a boulder from rolling\n\n\n#### Attack Rolls and Damage\n\nYou add your Strength modifier to your attack roll and your damage roll when attacking with a melee weapon such as a mace, a battleaxe, or a javelin. You use melee weapons to make melee attacks in hand-to-hand combat, and some of them can be thrown to make a ranged attack.\n\n#### Lifting and Carrying  \nYour Strength score determines the amount of weight you can bear. The following terms define what you can lift or carry.\n\n**Carrying Capacity.** Your carrying capacity is your Strength score multiplied by 15. This is the weight (in pounds) that you can carry, which is high enough that most characters don't usually have to worry about it.\n\n**Push, Drag, or Lift.** You can push, drag, or lift a weight in pounds up to twice your carrying capacity (or 30 times your Strength score).\nWhile pushing or dragging weight in excess of your carrying capacity, your speed drops to 5 feet.\n\n**Size and Strength.** Larger creatures can bear more weight, whereas Tiny creatures can carry less. For each size category above Medium, double the creature's carrying capacity and the amount it can push, drag, or lift. For a Tiny creature, halve these weights.\n\n#### Variant: Encumbrance  \nThe rules for lifting and carrying are intentionally simple. Here is a variant if you are looking for more detailed rules for determining how a character is hindered by the weight of equipment. When you use this variant, ignore the Strength column of the Armor table.\n\nIf you carry weight in excess of 5 times your Strength score, you are **encumbered**, which means your speed drops by 10 feet.\n\nIf you carry weight in excess of 10 times your Strength score, up to your maximum carrying capacity, you are instead **heavily encumbered**, which means your speed drops by 20 feet and you have disadvantage on ability checks, attack rolls, and saving throws that use Strength, Dexterity, or Constitution.\n\n### Dexterity \nDexterity measures agility, reflexes, and balance.\n\n#### Dexterity Checks\n\nA Dexterity check can model any attempt to move nimbly, quickly, or quietly, or to keep from falling on tricky footing. The Acrobatics, Sleight of Hand, and Stealth skills reflect aptitude in certain kinds of Dexterity checks.\n\n##### Acrobatics  \nYour Dexterity (Acrobatics) check covers your attempt to stay on your feet in a tricky situation, such as when you're trying to run across a sheet of ice, balance on a tightrope, or stay upright on a rocking ship's deck. The GM might also call for a Dexterity (Acrobatics) check to see if you can perform acrobatic stunts, including dives, rolls, somersaults, and flips.\n\n##### Sleight of Hand  \nWhenever you attempt an act of legerdemain or manual trickery, such as planting something on someone else or concealing an object on your person, make a Dexterity (Sleight of Hand) check. The GM might also call for a Dexterity (Sleight of Hand) check to determine whether you can lift a coin purse off another person or slip something out of another person's pocket.\n\n##### Stealth  \nMake a Dexterity (Stealth) check when you attempt to conceal yourself from enemies, slink past guards, slip away without being noticed, or sneak up on someone without being seen or heard.\n\n##### Other Dexterity Checks  \nThe GM might call for a Dexterity check when you try to accomplish tasks like the following:  - Control a heavily laden cart on a steep descent - Steer a chariot around a tight turn - Pick a lock - Disable a trap - Securely tie up a prisoner - Wriggle free of bonds - Play a stringed instrument - Craft a small or detailed object  **Hiding**  The GM decides when circumstances are appropriate for hiding. When you try to hide, make a Dexterity (Stealth) check. Until you are discovered or you stop hiding, that check's total is contested by the Wisdom (Perception) check of any creature that actively searches for signs of your presence.\n\nYou can't hide from a creature that can see you clearly, and you give away your position if you make noise, such as shouting a warning or knocking over a vase.\n\nAn invisible creature can always try to hide. Signs of its passage might still be noticed, and it does have to stay quiet.\n\nIn combat, most creatures stay alert for signs of danger all around, so if you come out of hiding and approach a creature, it usually sees you.\nHowever, under certain circumstances, the GM might allow you to stay hidden as you approach a creature that is distracted, allowing you to gain advantage on an attack roll before you are seen.\n\n**Passive Perception.** When you hide, there's a chance someone will notice you even if they aren't searching. To determine whether such a creature notices you, the GM compares your Dexterity (Stealth) check with that creature's passive Wisdom (Perception) score, which equals 10  - the creature's Wisdom modifier, as well as any other bonuses or   penalties. If the creature has advantage, add 5. For disadvantage,   subtract 5. For example, if a 1st-level character (with a proficiency   bonus of +2) has a Wisdom of 15 (a +2 modifier) and proficiency in   Perception, he or she has a passive Wisdom (Perception) of 14.\n\n**What Can You See?** One of the main factors in determining whether you can find a hidden creature or object is how well you can see in an area, which might be **lightly** or **heavily obscured**, as explained in the-environment.\n\n#### Attack Rolls and Damage\n\nYou add your Dexterity modifier to your attack roll and your damage roll when attacking with a ranged weapon, such as a sling or a longbow. You can also add your Dexterity modifier to your attack roll and your damage roll when attacking with a melee weapon that has the finesse property, such as a dagger or a rapier.\n\n#### Armor Class  \nDepending on the armor you wear, you might add some or all of your Dexterity modifier to your Armor Class.\n\n#### Initiative  \nAt the beginning of every combat, you roll initiative by making a Dexterity check. Initiative determines the order of creatures' turns in combat.\n\n### Constitution  \nConstitution measures health, stamina, and vital force.\n\n#### Constitution Checks  \nConstitution checks are uncommon, and no skills apply to Constitution checks, because the endurance this ability represents is largely passive rather than involving a specific effort on the part of a character or monster. A Constitution check can model your attempt to push beyond normal limits, however.\n\nThe GM might call for a Constitution check when you try to accomplish tasks like the following:  - Hold your breath - March or labor for hours without rest - Go without sleep - Survive without food or water - Quaff an entire stein of ale in one go  #### Hit Points  \nYour Constitution modifier contributes to your hit points. Typically, you add your Constitution modifier to each Hit Die you roll for your hit points.\n\nIf your Constitution modifier changes, your hit point maximum changes as well, as though you had the new modifier from 1st level. For example, if you raise your Constitution score when you reach 4th level and your Constitution modifier increases from +1 to +2, you adjust your hit point maximum as though the modifier had always been +2. So you add 3 hit points for your first three levels, and then roll your hit points for 4th level using your new modifier. Or if you're 7th level and some effect lowers your Constitution score so as to reduce your Constitution modifier by 1, your hit point maximum is reduced by 7.\n\n### Intelligence\n\nIntelligence measures mental acuity, accuracy of recall, and the ability to reason.\n\n#### Intelligence Checks  \nAn Intelligence check comes into play when you need to draw on logic, education, memory, or deductive reasoning. The Arcana, History, Investigation, Nature, and Religion skills reflect aptitude in certain kinds of Intelligence checks.\n\n##### Arcana  \nYour Intelligence (Arcana) check measures your ability to recall lore about spells, magic items, eldritch symbols, magical traditions, the planes of existence, and the inhabitants of those planes.\n\n##### History  \nYour Intelligence (History) check measures your ability to recall lore about historical events, legendary people, ancient kingdoms, past disputes, recent wars, and lost civilizations.\n\n##### Investigation\n\nWhen you look around for clues and make deductions based on those clues, you make an Intelligence (Investigation) check. You might deduce the location of a hidden object, discern from the appearance of a wound what kind of weapon dealt it, or determine the weakest point in a tunnel that could cause it to collapse. Poring through ancient scrolls in search of a hidden fragment of knowledge might also call for an Intelligence (Investigation) check.\n\n##### Nature  \nYour Intelligence (Nature) check measures your ability to recall lore about terrain, plants and animals, the weather, and natural cycles.\n\n##### Religion\n\nYour Intelligence (Religion) check  measures your ability to recall lore about deities, rites and prayers, religious hierarchies, holy symbols, and the practices of secret cults.\n\n##### Other Intelligence Checks  \nThe GM might call for an Intelligence check when you try to accomplish tasks like the following:  - Communicate with a creature without using words - Estimate the value of a precious item - Pull together a disguise to pass as a city guard - Forge a document - Recall lore about a craft or trade - Win a game of skill\n\n#### Spellcasting Ability  \nWizards use Intelligence as their spellcasting ability, which helps determine the saving throw DCs of spells they cast.\n\n### Wisdom  \nWisdom reflects how attuned you are to the world around you and represents perceptiveness and intuition.\n\n#### Wisdom Checks  \nA Wisdom check might reflect an effort to read body language, understand someone's feelings, notice things about the environment, or care for an injured person. The Animal Handling, Insight, Medicine, Perception, and Survival skills reflect aptitude in certain kinds of Wisdom checks.\n\n##### Animal Handling  \nWhen there is any question whether you can calm down a domesticated animal, keep a mount from getting spooked, or intuit an animal's intentions, the GM might call for a Wisdom (Animal Handling) check. You also make a Wisdom (Animal Handling) check to control your mount when you attempt a risky maneuver.\n\n##### Insight  \nYour Wisdom (Insight) check decides whether you can determine the true intentions of a creature, such as when searching out a lie or predicting someone's next move. Doing so involves gleaning clues from body language, speech habits, and changes in mannerisms.\n\n##### Medicine  \nA Wisdom (Medicine) check lets you try to stabilize a dying companion or diagnose an illness.\n\n##### Perception  \nYour Wisdom (Perception) check lets you spot, hear, or otherwise detect the presence of something. It measures your general awareness of your surroundings and the keenness of your senses. For example, you might try to hear a conversation through a closed door, eavesdrop under an open window, or hear monsters moving stealthily in the forest. Or you might try to spot things that are obscured or easy to miss, whether they are orcs lying in ambush on a road, thugs hiding in the shadows of an alley, or candlelight under a closed secret door.\n\n##### Survival  \nThe GM might ask you to make a Wisdom (Survival) check to follow tracks, hunt wild game, guide your group through frozen wastelands, identify signs that owlbears live nearby, predict the weather, or avoid quicksand and other natural hazards.\n\n##### Other Wisdom Checks  \nThe GM might call for a Wisdom check when you try to accomplish tasks like the following:  - Get a gut feeling about what course of action to follow - Discern whether a seemingly dead or living creature is undead  #### Spellcasting Ability  \nClerics, druids, and rangers use Wisdom as their spellcasting ability, which helps determine the saving throw DCs of spells they cast.\n\n### Charisma\n\nCharisma measures your ability to interact effectively with others. It includes such factors as confidence and eloquence, and it can represent a charming or commanding personality.\n\n#### Charisma Checks\n\nA Charisma check might arise when you try to influence or entertain others, when you try to make an impression or tell a convincing lie, or when you are navigating a tricky social situation. The Deception, Intimidation, Performance, and Persuasion skills reflect aptitude in certain kinds of Charisma checks.\n\n##### Deception\n\nYour Charisma (Deception) check determines whether you can convincingly hide the truth, either verbally or through your actions. This deception can encompass everything from misleading others through ambiguity to telling outright lies. Typical situations include trying to fast-talk a guard, con a merchant, earn money through gambling, pass yourself off in a disguise, dull someone's suspicions with false assurances, or maintain a straight face while telling a blatant lie.\n\n##### Intimidation  \nWhen you attempt to influence someone through overt threats, hostile actions, and physical violence, the GM might ask you to make a Charisma (Intimidation) check. Examples include trying to pry information out of a prisoner, convincing street thugs to back down from a confrontation, or using the edge of a broken bottle to convince a sneering vizier to reconsider a decision.\n\n##### Performance  \nYour Charisma (Performance) check determines how well you can delight an audience with music, dance, acting, storytelling, or some other form of entertainment.\n\n##### Persuasion  \nWhen you attempt to influence someone or a group of people with tact, social graces, or good nature, the GM might ask you to make a Charisma (Persuasion) check. Typically, you use persuasion when acting in good faith, to foster friendships, make cordial requests, or exhibit proper etiquette. Examples of persuading others include convincing a chamberlain to let your party see the king, negotiating peace between warring tribes, or inspiring a crowd of townsfolk\n\n##### Other Charisma Checks\n\nThe GM might call for a Charisma check when you try to accomplish tasks like the following:\n\n- Find the best person to talk to for news, rumors, and gossip\n- Blend into a crowd to get the sense of key topics of conversation\n\n\n#### Spellcasting Ability\n\nBards, paladins, sorcerers, and warlocks use Charisma as their spellcasting ability, which helps determine the saving throw DCs of spells they cast.",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Gameplay Mechanics"
        },
        {
            "slug": "actions-in-combat",
            "name": "Actions in Combat",
            "desc": "When you take your action on your turn, you can take one of the actions presented here, an action you gained from your class or a special feature, or an action that you improvise. Many monsters have action options of their own in their stat blocks.\n\nWhen you describe an action not detailed elsewhere in the rules, the GM tells you whether that action is possible and what kind of roll you need to make, if any, to determine success or failure.\n\n## Types of Actions\n\n### Attack\n\nThe most common action to take in combat is the Attack action, whether you are swinging a sword, firing an arrow from a bow, or brawling with your fists.\n\nWith this action, you make one melee or ranged attack. See the Making an Attack section for the rules that govern attacks. Certain features, such as the Extra Attack feature of the fighter, allow you to make more than one attack with this action.\n\n### Cast a Spell\n\nSpellcasters such as wizards and clerics, as well as many monsters, have access to spells and can use them to great effect in combat. Each spell has a casting time, which specifies whether the caster must use an action, a reaction, minutes, or even hours to cast the spell. Casting a spell is, therefore, not necessarily an action. Most spells do have a casting time of 1 action, so a spellcaster often uses his or her action in combat to cast such a spell.\n\n### Dash\n\nWhen you take the Dash action, you gain extra movement for the current turn. The increase equals your speed, after applying any modifiers. With a speed of 30 feet, for example, you can move up to 60 feet on your turn if you dash.\n\nAny increase or decrease to your speed changes this additional movement by the same amount. If your speed of 30 feet is reduced to 15 feet, for instance, you can move up to 30 feet this turn if you dash.\n\n### Disengage\n\nIf you take the Disengage action, your movement doesn't provoke opportunity attacks for the rest of the turn.\n\n### Dodge\n\nWhen you take the Dodge action, you focus entirely on avoiding attacks. Until the start of your next turn, any attack roll made against you has disadvantage if you can see the attacker, and you make Dexterity saving throws with advantage. You lose this benefit if you are incapacitated or if your speed drops to 0.\n\n### Help\n\nYou can lend your aid to another creature in the completion of a task.\n\nWhen you take the Help action, the creature you aid gains advantage on the next ability check it makes to perform the task you are helping with, provided that it makes the check before the start of your next turn.\n\nAlternatively, you can aid a friendly creature in attacking a creature within 5 feet of you. You feint, distract the target, or in some other way team up to make your ally's attack more effective. If your ally attacks the target before your next turn, the first attack roll is made with advantage.\n\n### Hide\n\nWhen you take the Hide action, you make a Dexterity (Stealth) check in an attempt to hide, following the rules for hiding. If you succeed, you gain certain benefits, as described in srd:unseen-attackers-and-targets.\n\n### Ready\n\nSometimes you want to get the jump on a foe or wait for a particular circumstance before you act. To do so, you can take the Ready action on your turn, which lets you act using your reaction before the start of your next turn.\n\nFirst, you decide what perceivable circumstance will trigger your reaction. Then, you choose the action you will take in response to that trigger, or you choose to move up to your speed in response to it. Examples include 'If the cultist steps on the trapdoor, I'll pull the lever that opens it,' and 'If the goblin steps next to me, I move away.'\n\nWhen the trigger occurs, you can either take your reaction right after the trigger finishes or ignore the trigger. Remember that you can take only one reaction per round.\n\nWhen you ready a spell, you cast it as normal but hold its energy, which you release with your reaction when the trigger occurs. To be readied, a spell must have a casting time of 1 action, and holding onto the spell's magic requires concentration. If your concentration is broken, the spell dissipates without taking effect. For example, if you are concentrating on the srd:web spell and ready srd:magic-missile, your srd:web spell ends, and if you take damage before you release srd:magic-missile with your reaction, your concentration might be broken.\n\n### Search\n\nWhen you take the Search action, you devote your attention to finding something. Depending on the nature of your search, the GM might have you make a Wisdom (Perception) check or an Intelligence (Investigation) check.\n\n### Use an Object\n\nYou normally interact with an object while doing something else, such as when you draw a sword as part of an attack. When an object requires your action for its use, you take the Use an Object action. This action is also useful when you want to interact with more than one object on your turn.",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Combat"
        },
        {
            "slug": "adventuring-gear",
            "name": "Adventuring Gear",
            "desc": "This section describes items that have special rules or require further explanation.\n\n**_Acid._** As an action, you can splash the contents of this vial onto a creature within 5 feet of you or throw the vial up to 20 feet, shattering it on impact. In either case, make a ranged attack against a creature or object, treating the acid as an improvised weapon. On a hit, the target takes 2d6 acid damage.\n\n**_Alchemist's Fire._** This sticky, adhesive fluid ignites when exposed to air. As an action, you can throw this flask up to 20 feet, shattering it on impact. Make a ranged attack against a creature or object, treating the alchemist's fire as an improvised weapon. On a hit, the target takes 1d4 fire damage at the start of each of its turns. A creature can end this damage by using its action to make a DC 10 Dexterity check to extinguish the flames.\n\n**_Antitoxin._** A creature that drinks this vial of liquid gains advantage on saving throws against poison for 1 hour. It confers no benefit to undead or constructs.\n\n**_Arcane Focus._** An arcane focus is a special item-an orb, a crystal, a rod, a specially constructed staff, a wand-like length of wood, or some similar item- designed to channel the power of arcane spells. A sorcerer, warlock, or wizard can use such an item as a spellcasting focus.\n\n**_Ball Bearings._** As an action, you can spill these tiny metal balls from their pouch to cover a level, square area that is 10 feet on a side. A creature moving across the covered area must succeed on a DC 10 Dexterity saving throw or fall prone. A creature moving through the area at half speed doesn't need to make the save.\n\n**_Block and Tackle._** A set of pulleys with a cable threaded through them and a hook to attach to objects, a block and tackle allows you to hoist up to four times the weight you can normally lift.\n\n**_Book._** A book might contain poetry, historical accounts, information pertaining to a particular field of lore, diagrams and notes on gnomish contraptions, or just about anything else that can be represented using text or pictures. A book of spells is a spellbook (described later in this section).\n\n**_Caltrops._** As an action, you can spread a bag of caltrops to cover a square area that is 5 feet on a side. Any creature that enters the area must succeed on a DC 15 Dexterity saving throw or stop moving this turn and take 1 piercing damage. Taking this damage reduces the creature's walking speed by 10 feet until the creature regains at least 1 hit point. A creature moving through the area at half speed doesn't need to make the save.\n\n**_Candle._** For 1 hour, a candle sheds bright light in a 5-foot radius and dim light for an additional 5 feet.\n\n**_Case, Crossbow Bolt._** This wooden case can hold up to twenty crossbow bolts.\n\n**_Case, Map or Scroll._** This cylindrical leather case can hold up to ten rolled-up sheets of paper or five rolled-up sheets of parchment.\n\n**_Chain._** A chain has 10 hit points. It can be burst with a successful DC 20 Strength check.\n\n**_Climber's Kit._** A climber's kit includes special pitons, boot tips, gloves, and a harness. You can use the climber's kit as an action to anchor yourself; when you do, you can't fall more than 25 feet from the point where you anchored yourself, and you can't climb more than 25 feet away from that point without undoing the anchor.\n\n**_Component Pouch._** A component pouch is a small, watertight leather belt pouch that has compartments to hold all the material components and other special items you need to cast your spells, except for those components that have a specific cost (as indicated in a spell's description).\n\n**_Crowbar._** Using a crowbar grants advantage to Strength checks where the crowbar's leverage can be applied.\n\n**_Druidic Focus._** A druidic focus might be a sprig of mistletoe or holly, a wand or scepter made of yew or another special wood, a staff drawn whole out of a living tree, or a totem object incorporating feathers, fur, bones, and teeth from sacred animals. A druid can use such an object as a spellcasting focus.\n\n**_Fishing Tackle._** This kit includes a wooden rod, silken line, corkwood bobbers, steel hooks, lead sinkers, velvet lures, and narrow netting.\n\n**_Healer's Kit._** This kit is a leather pouch containing bandages, salves, and splints. The kit has ten uses. As an action, you can expend one use of the kit to stabilize a creature that has 0 hit points, without needing to make a Wisdom (Medicine) check.\n\n**_Holy Symbol._** A holy symbol is a representation of a god or pantheon. It might be an amulet depicting a symbol representing a deity, the same symbol carefully engraved or inlaid as an emblem on a shield, or a tiny box holding a fragment of a sacred relic. Appendix PH-B **Fantasy-Historical Pantheons** lists the symbols commonly associated with many gods in the multiverse. A cleric or paladin can use a holy symbol as a spellcasting focus. To use the symbol in this way, the caster must hold it in hand, wear it visibly, or bear it on a shield.\n\n**_Holy Water._** As an action, you can splash the contents of this flask onto a creature within 5 feet of you or throw it up to 20 feet, shattering it on impact. In either case, make a ranged attack against a target creature, treating the holy water as an improvised weapon. If the target is a fiend or undead, it takes 2d6 radiant damage. A cleric or paladin may create holy water by performing a special ritual. The ritual takes 1 hour to perform, uses 25 gp worth of powdered silver, and requires the caster to expend a 1st-level spell slot.\n\n**_Hunting Trap._** When you use your action to set it, this trap forms a saw-toothed steel ring that snaps shut when a creature steps on a pressure plate in the center. The trap is affixed by a heavy chain to an immobile object, such as a tree or a spike driven into the ground. A creature that steps on the plate must succeed on a DC 13 Dexterity saving throw or take 1d4 piercing damage and stop moving. Thereafter, until the creature breaks free of the trap, its movement is limited by the length of the chain (typically 3 feet long). A creature can use its action to make a DC 13 Strength check, freeing itself or another creature within its reach on a success. Each failed check deals 1 piercing damage to the trapped creature.\n\n**_Lamp._** A lamp casts bright light in a 15-foot radius and dim light for an additional 30 feet. Once lit, it burns for 6 hours on a flask (1 pint) of oil.\n\n**_Lantern, Bullseye._** A bullseye lantern casts bright light in a 60-foot cone and dim light for an additional 60 feet. Once lit, it burns for 6 hours on a flask (1 pint) of oil.\n\n**_Lantern, Hooded._** A hooded lantern casts bright light in a 30-foot radius and dim light for an additional 30 feet. Once lit, it burns for 6 hours on a flask (1 pint) of oil. As an action, you can lower the hood, reducing the light to dim light in a 5-foot radius.\n\n**_Lock._** A key is provided with the lock. Without the key, a creature proficient with thieves' tools can pick this lock with a successful DC 15 Dexterity check. Your GM may decide that better locks are available for higher prices.\n\n**_Magnifying Glass._** This lens allows a closer look at small objects. It is also useful as a substitute for flint and steel when starting fires. Lighting a fire with a magnifying glass requires light as bright as sunlight to focus, tinder to ignite, and about 5 minutes for the fire to ignite. A magnifying glass grants advantage on any ability check made to appraise or inspect an item that is small or highly detailed.\n\n**_Manacles._** These metal restraints can bind a Small or Medium creature. Escaping the manacles requires a successful DC 20 Dexterity check. Breaking them requires a successful DC 20 Strength check. Each set of manacles comes with one key. Without the key, a creature proficient with thieves' tools can pick the manacles' lock with a successful DC 15 Dexterity check. Manacles have 15 hit points.\n\n**_Mess Kit._** This tin box contains a cup and simple cutlery. The box clamps together, and one side can be used as a cooking pan and the other as a plate or shallow bowl.\n\n**_Oil._** Oil usually comes in a clay flask that holds 1 pint. As an action, you can splash the oil in this flask onto a creature within 5 feet of you or throw it up to 20 feet, shattering it on impact. Make a ranged attack against a target creature or object, treating the oil as an improvised weapon. On a hit, the target is covered in oil. If the target takes any fire damage before the oil dries (after 1 minute), the target takes an additional 5 fire damage from the burning oil. You can also pour a flask of oil on the ground to cover a 5-foot-square area, provided that the surface is level. If lit, the oil burns for 2 rounds and deals 5 fire damage to any creature that enters the area or ends its turn in the area. A creature can take this damage only once per turn.\n\n**_Poison, Basic._** You can use the poison in this vial to coat one slashing or piercing weapon or up to three pieces of ammunition. Applying the poison takes an action. A creature hit by the poisoned weapon or ammunition must make a DC 10 Constitution saving throw or take 1d4 poison damage. Once applied, the poison retains potency for 1 minute before drying.\n\n**_Potion of Healing._** A character who drinks the magical red fluid in this vial regains 2d4 + 2 hit points. Drinking or administering a potion takes an action.\n\n**_Pouch._** A cloth or leather pouch can hold up to 20 sling bullets or 50 blowgun needles, among other things. A compartmentalized pouch for holding spell components is called a component pouch (described earlier in this section).\n\n**_Quiver._** A quiver can hold up to 20 arrows.\n\n**_Ram, Portable._** You can use a portable ram to break down doors. When doing so, you gain a +4 bonus on the Strength check. One other character can help you use the ram, giving you advantage on this check.\n\n**_Rations._** Rations consist of dry foods suitable for extended travel, including jerky, dried fruit, hardtack, and nuts.\n\n**_Rope._** Rope, whether made of hemp or silk, has 2 hit points and can be burst with a DC 17 Strength check.\n\n**_Scale, Merchant's._** A scale includes a small balance, pans, and a suitable assortment of weights up to 2 pounds. With it, you can measure the exact weight of small objects, such as raw precious metals or trade goods, to help determine their worth.\n\n**_Spellbook._** Essential for wizards, a spellbook is a leather-bound tome with 100 blank vellum pages suitable for recording spells.\n\n**_Spyglass._** Objects viewed through a spyglass are magnified to twice their size.\n\n**_Tent._** A simple and portable canvas shelter, a tent sleeps two.\n\n**_Tinderbox._** This small container holds flint, fire steel, and tinder (usually dry cloth soaked in light oil) used to kindle a fire. Using it to light a torch—or anything else with abundant, exposed fuel—takes an action. Lighting any other fire takes 1 minute.\n\n**_Torch._** A torch burns for 1 hour, providing bright light in a 20-foot radius and dim light for an additional 20 feet. If you make a melee attack with a burning torch and hit, it deals 1 fire damage.\n\n### Adventuring Gear\n\n|**Item**| **Cost**| **Weight**|\n|---|---|---|\n|Abacus|2 gp|2 lb.|\n|Acid (vial)|25 gp|1 lb.|\n|Alchemist's fire (flask)|50 gp|1 lb.|\n|**Ammunition**| | |\n|&emsp;&emsp;Arrows (20) |1 gp|1 lb.|\n|&emsp;&emsp;Blowgun needles (50)|1 gp|1 lb.|\n|&emsp;&emsp;Crossbow bolts (20)|1 gp|1 1/2 lb.|\n|&emsp;&emsp;Sling bullets (20)|4 cp|1 1/2 lb.|\n|Antitoxin (vial)|50 gp|-|\n| **Arcane focus** | | |\n|&emsp;&emsp;Crystal|10 gp|1 lb.|\n|&emsp;&emsp;Orb|20 gp|3 lb.|\n|&emsp;&emsp;Rod|10 gp|2 lb.|\n|&emsp;&emsp;Staff|5 gp|4 lb.|\n|&emsp;&emsp;Wand|10 gp|1 lb.|\n|Backpack|2 gp|5 lb.|\n|Ball bearings (bag of 1,000)|1 gp|2 lb.|\n|Barrel|2 gp|70 lb.|\n|Bedroll|1 gp|7 lb.|\n|Bell|1 gp|-|\n|Blanket|5 sp|3 lb.|\n|Block and tackle|1 gp|5 lb.|\n|Book|25 gp| 5 lb. |\n|Bottle, glass|2 gp|2 lb.|\n|Bucket|5 cp| 2 lb. |\n| Caltrops (bag of 20) | 1 gp | 2 lb. |\n|Candle|1 cp|-|\n| Case, crossbow bolt|1 gp|1 lb.|\n|Case, map or scroll|1 gp|1 lb.|\n|Chain (10 feet)|5 gp|10 lb.|\n|Chalk (1 piece)| 1 cp | - |\n| Chest|5 gp|25 lb.|\n|Climber's kit|25 gp|12 lb.|\n|Clothes, common|5 sp|3 lb.|\n|Clothes, costume|5 gp|4 lb.|\n|Clothes, fine | 15 gp | 6 lb. |\n| Clothes, traveler's | 2 gp|4 lb. |\n| Components pouch|25 gp|2 lb.|\n|Crowbar|2 gp|5 lb.|\n|**Druidic Focus**| | |\n|&emsp;&emsp;Sprig of mistletoe|1 gp|-|\n|&emsp;&emsp;Totem|1 gp|-|\n|&emsp;&emsp;Wooden staff|5 gp|4 lb.|\n|&emsp;&emsp;Yew wand|10 gp|1 lb.|\n|Fishing table|1 gp|4 lb.|\n|Flask or tankard|2 cp|1 lb.|\n|Grappling hook|2 gp|4 lb.|\n|Hammer|1 gp|3 lb.|\n|Hammer, sledge|2 gp|10 lb.|\n|Healer's kit|5 gp|3 lb.|\n|**Holy Symbol**| | |\n|&emsp;&emsp;Amulet| 5 gp|1 lb.|\n|&emsp;&emsp;Emblem|5 gp|-|\n|&emsp;&emsp;Reliquary|5 gp|-|\n|Holy water (flask)|25 gp|1 lb.|\n|Hourglass|25 gp|1 lb.|\n|Hunting trap|5 gp|25 lb.|\n|Ink  (1 ounce bottle)|10 gp|-|\n|Ink pen|2 cp|-|\n|Jug or pitcher|2 cp|4 lb.|\n|Ladder (10-foot)|1 sp|25 lb.|\n|Lamp|5 sp|1 lb.|\n|Lantern, bullseye|10 gp|1 lb.|\n|Lantern, hooded|5 gp|2 lb.|\n|Lock|10 gp|1 lb.|\n|Magnifying glass|100 gp|-|\n|Manacles|2 gp|6 lb.|\n|Mess kit|2 sp|1 lb.|\n|Mirror, steel|5 gp|1/2 lb.|\n|Oil (flask)|1 sp|1 lb.|\n|Paper (one sheet)|2 sp|-|\n|Parchment (one sheet)|1 sp|-|\n|Perfume (vial)|5 gp|-|\n|Pick, miner's|2 gp| 10 lb.|\n|Piton|5 cp|1/4 lb.|\n|Poison, basic (vial)|100 gp|-|\n|Pole (10-foot)|5 cp|7 lb.|\n|Quiver|1 gp|1 lb.|\n|Ram, portable|4 gp|35 lb.|\n|Rations (1 day)|5 sp|2 lb.|\n|Robes|1 gp|4 lb.|\n|Rope, hempen (50 feet)|1 gp|10 lb.|\n|Rope, silk (50 feet)|10 gp|5 lb.|\n|Sack|1 cp|1/2 lb.|\n|Scales, merchant's|5 gp|3 lb.|\n|Sealing wax|5 sp|-|\n|Shovel|2 gp|5 lb.|\n|Signal whistle|5 cp|-|\n|Signet ring|5 gp|-|\n|Soap|2 cp|-|\n|Spellbook|50 gp|3 lb.|\n|Spikes, iron (10)|1 gp|5 lb.|\n|Spyglass|1000 gp|1 lb.|\n|Tent, two-person|2 gp|20 lb.|\n|Tinderbox|5 sp|1 lb.|\n|Torch|1 cp|1 lb.|\n|Vial|1 gp|-|\n|Waterskin|2 sp|5 lb. (full)|\n|Whetstone|1 cp|1 lb.|\n\n### Container Capacity\n\n|**Container**|**Capacity**|\n|---|---|\n|Backpack&ast;|1 cubic foot/30 pounds of gear|\n|Barrel|40 gallons liquid, 4 cubic feet solid|\n|Basket|2 cubic feet/40 pounds of gear|\n|Bottle|1 1/2 pints liquid|\n|Bucket|3 gallons liquid, 1/2 cubic foot solid|\n|Chest|12 cubic feet/300 pounds of gear|\n|Flask or tankard|1 pint liquid|\n|Jug or pitcher|1 gallon liquid|\n|Pot, iron|1 gallon liquid|\n|Pouch|1/5 cubic foot/6 pounds of gear|\n|Sack|1 cubic foot/30 pounds of gear|\n|Vial|4 ounces liquid|\n|Waterskin|4 pints liquid|\n\n&ast;You can also strap items, such as a bedroll or a coil of rope, to the outside of a backpack.",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Equipment"
        },
        {
            "slug": "alignment",
            "name": "Alignment",
            "desc": "A typical creature in the game world has an alignment, which broadly describes its moral and personal attitudes. Alignment is a combination of two factors: one identifies morality (good, evil, or neutral), and the other describes attitudes toward society and order (lawful, chaotic, or neutral). Thus, nine distinct alignments define the possible combinations.\n\nThese brief summaries of the nine alignments describe the typical behavior of a creature with that alignment. Individuals might vary significantly from that typical behavior, and few people are perfectly and consistently faithful to the precepts of their alignment.\n\n**Lawful good** (LG) creatures can be counted on to do the right thing as expected by society. Gold dragons, paladins, and most dwarves are lawful good.\n\n**Neutral good** (NG) folk do the best they can to help others according to their needs. Many celestials, some cloud giants, and most gnomes are neutral good.\n\n**Chaotic good** (CG) creatures act as their conscience directs, with little regard for what others expect. Copper dragons, many elves, and unicorns are chaotic good.\n\n**Lawful neutral** (LN) individuals act in accordance with law, tradition, or personal codes. Many monks and some wizards are lawful neutral.\n\n**Neutral** (N) is the alignment of those who prefer to steer clear of moral questions and don't take sides, doing what seems best at the time. Lizardfolk, most druids, and many humans are neutral.\n\n**Chaotic neutral** (CN) creatures follow their whims, holding their personal freedom above all else. Many barbarians and rogues, and some bards, are chaotic neutral.\n\n**Lawful evil** (LE) creatures methodically take what they want, within the limits of a code of tradition, loyalty, or order. Devils, blue dragons, and hobgoblins are lawful evil.\n\n**Neutral evil** (NE) is the alignment of those who do whatever they can get away with, without compassion or qualms. Many drow, some cloud giants, and goblins are neutral evil.\n\n**Chaotic evil** (CE) creatures act with arbitrary violence, spurred by their greed, hatred, or bloodlust. Demons, red dragons, and orcs are chaotic evil.\n\n## Alignment in the Multiverse\n\nFor many thinking creatures, alignment is a moral choice. Humans, dwarves, elves, and other humanoid races can choose whether to follow the paths of good or evil, law or chaos. According to myth, the good- aligned gods who created these races gave them free will to choose their moral paths, knowing that good without free will is slavery.\n\nThe evil deities who created other races, though, made those races to serve them. Those races have strong inborn tendencies that match the nature of their gods. Most orcs share the violent, savage nature of the orc gods, and are thus inclined toward evil. Even if an orc chooses a good alignment, it struggles against its innate tendencies for its entire life. (Even half-orcs feel the lingering pull of the orc god's influence.)\n\nAlignment is an essential part of the nature of celestials and fiends. A devil does not choose to be lawful evil, and it doesn't tend toward lawful evil, but rather it is lawful evil in its essence. If it somehow ceased to be lawful evil, it would cease to be a devil.\n\nMost creatures that lack the capacity for rational thought do not have alignments-they are **unaligned**. Such a creature is incapable of making a moral or ethical choice and acts according to its bestial nature. Sharks are savage predators, for example, but they are not evil; they have no alignment.",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Characters"
        },
        {
            "slug": "armor",
            "name": "Armor",
            "desc": "Fantasy gaming worlds are a vast tapestry made up of many different cultures, each with its own technology level. For this reason, adventurers have access to a variety of armor types, ranging from leather armor to chain mail to costly plate armor, with several other kinds of armor in between. The Armor table collects the most commonly available types of armor found in the game and separates them into three categories: light armor, medium armor, and heavy armor. Many warriors supplement their armor with a shield.\n\nThe Armor table shows the cost, weight, and other properties of the common types of armor worn in fantasy gaming worlds.\n\n**_Armor Proficiency._** Anyone can put on a suit of armor or strap a shield to an arm. Only those proficient in the armor's use know how to wear it effectively, however. Your class gives you proficiency with certain types of armor. If you wear armor that you lack proficiency with, you have disadvantage on any ability check, saving throw, or attack roll that involves Strength or Dexterity, and you can't cast spells.\n\n**_Armor Class (AC)._** Armor protects its wearer from attacks. The armor (and shield) you wear determines your base Armor Class.\n\n**_Heavy Armor._** Heavier armor interferes with the wearer's ability to move quickly, stealthily, and freely. If the Armor table shows “Str 13” or “Str 15” in the Strength column for an armor type, the armor reduces the wearer's speed by 10 feet unless the wearer has a Strength score equal to or higher than the listed score.\n\n**_Stealth._** If the Armor table shows “Disadvantage” in the Stealth column, the wearer has disadvantage on Dexterity (Stealth) checks.\n\n**_Shields._** A shield is made from wood or metal and is carried in one hand. Wielding a shield increases your Armor Class by 2. You can benefit from only one shield at a time.\n\n## Light Armor\n\nMade from supple and thin materials, light armor favors agile adventurers since it offers some protection without sacrificing mobility. If you wear light armor, you add your Dexterity modifier to the base number from your armor type to determine your Armor Class.\n\n**_Padded._** Padded armor consists of quilted layers of cloth and batting.\n\n**_Leather._** The breastplate and shoulder protectors of this armor are made of leather that has been stiffened by being boiled in oil. The rest of the armor is made of softer and more flexible materials.\n\n**_Studded Leather._** Made from tough but flexible leather, studded leather is reinforced with close-set rivets or spikes.\n\n## Medium Armor\n\nMedium armor offers more protection than light armor, but it also impairs movement more. If you wear medium armor, you add your Dexterity modifier, to a maximum of +2, to the base number from your armor type to determine your Armor Class.\n\n**_Hide._** This crude armor consists of thick furs and pelts. It is commonly worn by barbarian tribes, evil humanoids, and other folk who lack access to the tools and materials needed to create better armor.\n\n**_Chain Shirt._** Made of interlocking metal rings, a chain shirt is worn between layers of clothing or leather. This armor offers modest protection to the wearer's upper body and allows the sound of the rings rubbing against one another to be muffled by outer layers.\n\n**_Scale Mail._** This armor consists of a coat and leggings (and perhaps a separate skirt) of leather covered with overlapping pieces of metal, much like the scales of a fish. The suit includes gauntlets.\n\n**_Breastplate._** This armor consists of a fitted metal chest piece worn with supple leather. Although it leaves the legs and arms relatively unprotected, this armor provides good protection for the wearer's vital organs while leaving the wearer relatively unencumbered.\n\n**_Half Plate._** Half plate consists of shaped metal plates that cover most of the wearer's body. It does not include leg protection beyond simple greaves that are attached with leather straps.\n\n## Heavy Armor\n\nOf all the armor categories, heavy armor offers the best protection. These suits of armor cover the entire body and are designed to stop a wide range of attacks. Only proficient warriors can manage their weight and bulk.\n\nHeavy armor doesn't let you add your Dexterity modifier to your Armor Class, but it also doesn't penalize you if your Dexterity modifier is negative.\n\n**_Ring Mail._** This armor is leather armor with heavy rings sewn into it. The rings help reinforce the armor against blows from swords and axes. Ring mail is inferior to chain mail, and it's usually worn only by those who can't afford better armor.\n\n**_Chain Mail._** Made of interlocking metal rings, chain mail includes a layer of quilted fabric worn underneath the mail to prevent chafing and to cushion the impact of blows. The suit includes gauntlets.\n\n**_Splint._** This armor is made of narrow vertical strips of metal riveted to a backing of leather that is worn over cloth padding. Flexible chain mail protects the joints.\n\n**_Plate._** Plate consists of shaped, interlocking metal plates to cover the entire body. A suit of plate includes gauntlets, heavy leather boots, a visored helmet, and thick layers of padding underneath the armor. Buckles and straps distribute the weight over the body.\n\n**Armor (table)**\n\n| Armor              | Cost     | Armor Class (AC)          | Strength | Stealth      | Weight |\n|--------------------|----------|---------------------------|----------|--------------|--------|\n| **_Light Armor_**  |          |                           |          |              |        |\n| Padded             | 5 gp     | 11 + Dex modifier         | -        | Disadvantage | 8 lb.  |\n| Leather            | 10 gp    | 11 + Dex modifier         | -        | -            | 10 lb. |\n| Studded leather    | 45 gp    | 12 + Dex modifier         | -        | -            | 13 lb. |\n| **_Medium Armor_** |          |                           |          |              |        |\n| Hide               | 10 gp    | 12 + Dex modifier (max 2) | -        | -            | 12 lb. |\n| Chain shirt        | 50 gp    | 13 + Dex modifier (max 2) | -        | -            | 20 lb. |\n| Scale mail         | 50 gp    | 14 + Dex modifier (max 2) | -        | Disadvantage | 45 lb. |\n| Breastplate        | 400 gp   | 14 + Dex modifier (max 2) | -        | -            | 20 lb. |\n| Half plate         | 750 gp   | 15 + Dex modifier (max 2) | -        | Disadvantage | 40 lb. |\n| **_Heavy Armor_**  |          |                           |          |              |        |\n| Ring mail          | 30 gp    | 14                        | -        | Disadvantage | 40 lb. |\n| Chain mail         | 75 gp    | 16                        | Str 13   | Disadvantage | 55 lb. |\n| Splint             | 200 gp   | 17                        | Str 15   | Disadvantage | 60 lb. |\n| Plate              | 1,500 gp | 18                        | Str 15   | Disadvantage | 65 lb. |\n| **_Shield_**       |          |                           |          |              |        |\n| Shield             | 10 gp    | +2                        | -        | -            | 6 lb.  |\n\n## Getting Into and Out of Armor\n\nThe time it takes to don or doff armor depends on the armor's category.\n\n**_Don._** This is the time it takes to put on armor. You benefit from the armor's AC only if you take the full time to don the suit of armor.\n\n**_Doff._** This is the time it takes to take off armor. If you have help, reduce this time by half.\n\n**Donning and Doffing Armor (table)**\n\n| Category     | Don        | Doff      |\n|--------------|------------|-----------|\n| Light Armor  | 1 minute   | 1 minute  |\n| Medium Armor | 5 minutes  | 1 minute  |\n| Heavy Armor  | 10 minutes | 5 minutes |\n| Shield       | 1 action   | 1 action  |",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Equipment"
        },
        {
            "slug": "attacking",
            "name": "Attacking",
            "desc": "Whether you're striking with a melee weapon, firing a weapon at range, or making an attack roll as part of a spell, an attack has a simple structure.\n\n1. **Choose a target.** Pick a target within your attack's range: a creature, an object, or a location.\n2. **Determine modifiers.** The GM determines whether the target has cover and whether you have advantage or disadvantage against the target. In addition, spells, special abilities, and other effects can apply penalties or bonuses to your attack roll.\n3. **Resolve the attack.** You make the attack roll. On a hit, you roll damage, unless the particular attack has rules that specify otherwise. Some attacks cause special effects in addition to or instead of damage.\n\n\nIf there's ever any question whether something you're doing counts as an attack, the rule is simple: if you're making an attack roll, you're making an attack.\n\n## Attack Rolls\n\nWhen you make an attack, your attack roll determines whether the attack hits or misses. To make an attack roll, roll a d20 and add the appropriate modifiers. If the total of the roll plus modifiers equals or exceeds the target's Armor Class (AC), the attack hits. The AC of a character is determined at character creation, whereas the AC of a monster is in its stat block.\n\n### Modifiers to the Roll\n\nWhen a character makes an attack roll, the two most common modifiers to the roll are an ability modifier and the character's proficiency bonus. When a monster makes an attack roll, it uses whatever modifier is provided in its stat block.\n\n**Ability Modifier.** The ability modifier used for a melee weapon attack is Strength, and the ability modifier used for a ranged weapon attack is Dexterity. Weapons that have the finesse or thrown property break this rule.\n\nSome spells also require an attack roll. The ability modifier used for a spell attack depends on the spellcasting ability of the spellcaster.\n\n**Proficiency Bonus.** You add your proficiency bonus to your attack roll when you attack using a weapon with which you have proficiency, as well as when you attack with a spell.\n\n### Rolling 1 or 20\n\nSometimes fate blesses or curses a combatant, causing the novice to hit and the veteran to miss.\n\n> **Sage Advice**\n\n> Spell attacks can score critical hits, just like any other attack.\n\n> \n\n> Source: [Sage Advice > Compendium](http://media.wizards.com/2015/downloads/dnd/SA_Compendium_1.01.pdf)\n\nIf the d20 roll for an attack is a 20, the attack hits regardless of any modifiers or the target's AC. This is called a critical hit.\n\nIf the d20 roll for an attack is a 1, the attack misses regardless of any modifiers or the target's AC.\n\n## Unseen Attackers and Targets\n\nCombatants often try to escape their foes' notice by hiding, casting the invisibility spell, or lurking in darkness.\n\nWhen you attack a target that you can't see, you have disadvantage on the attack roll. This is true whether you're guessing the target's location or you're targeting a creature you can hear but not see. If the target isn't in the location you targeted, you automatically miss, but the GM typically just says that the attack missed, not whether you guessed the target's location correctly.\n\nWhen a creature can't see you, you have advantage on attack rolls against it. If you are hidden---both unseen and unheard---when you make an attack, you give away your location when the attack hits or misses.\n\n## Ranged Attacks\n\n When you make a ranged attack, you fire a bow or a crossbow, hurl a handaxe, or otherwise send projectiles to strike a foe at a distance. A monster might shoot spines from its tail. Many spells also involve making a ranged attack.\n\n### Range\n\nYou can make ranged attacks only against targets within a specified range. If a ranged attack, such as one made with a spell, has a single range, you can't attack a target beyond this range.\n\nSome ranged attacks, such as those made with a longbow or a shortbow, have two ranges. The smaller number is the normal range, and the larger number is the long range. Your attack roll has disadvantage when your target is beyond normal range, and you can't attack a target beyond the long range.\n\n### Ranged Attacks in Close Combat\n\n Aiming a ranged attack is more difficult when a foe is next to you. When you make a ranged attack with a weapon, a spell, or some other means, you have disadvantage on the attack roll if you are within 5 feet of a hostile creature who can see you and who isn't incapacitated.\n\n## Melee Attacks\n\nUsed in hand-to-hand combat, a melee attack allows you to attack a foe within your reach. A melee attack typically uses a handheld weapon such as a sword, a warhammer, or an axe. A typical monster makes a melee attack when it strikes with its claws, horns, teeth, tentacles, or other body part. A few spells also involve making a melee attack.\n\nMost creatures have a 5-foot **reach** and can thus attack targets within 5 feet of them when making a melee attack. Certain creatures (typically those larger than Medium) have melee attacks with a greater reach than 5 feet, as noted in their descriptions.\n\nInstead of using a weapon to make a melee weapon attack, you can use an **unarmed strike**: a punch, kick, head-butt, or similar forceful blow (none of which count as weapons). On a hit, an unarmed strike deals bludgeoning damage equal to 1 + your Strength modifier. You are proficient with your unarmed strikes.\n\n### Opportunity Attacks\n\nIn a fight, everyone is constantly watching for a chance to strike an enemy who is fleeing or passing by. Such a strike is called an opportunity attack.\n\nYou can make an opportunity attack when a hostile creature that you can see moves out of your reach. To make the opportunity attack, you use your reaction to make one melee attack against the provoking creature. The attack occurs right before the creature leaves your reach.\n\nYou can avoid provoking an opportunity attack by taking the Disengage action. You also don't provoke an opportunity attack when you teleport or when someone or something moves you without using your movement, action, or reaction. For example, you don't provoke an opportunity attack if an explosion hurls you out of a foe's reach or if gravity causes you to fall past an enemy.\n\n### Two-Weapon Fighting\n\nWhen you take the Attack action and attack with a light melee weapon that you're holding in one hand, you can use a bonus action to attack with a different light melee weapon that you're holding in the other hand. You don't add your ability modifier to the damage of the bonus attack, unless that modifier is negative.\n\nIf either weapon has the thrown property, you can throw the weapon, instead of making a melee attack with it.\n\n### Grappling\n\nWhen you want to grab a creature or wrestle with it, you can use the Attack action to make a special melee attack, a grapple. If you're able to make multiple attacks with the Attack action, this attack replaces one of them.\n\nThe target of your grapple must be no more than one size larger than you and must be within your reach. Using at least one free hand, you try to seize the target by making a grapple check instead of an attack roll: a Strength (Athletics) check contested by the target's Strength (Athletics) or Dexterity (Acrobatics) check (the target chooses the ability to use). If you succeed, you subject the target to the srd:grappled condition. The condition specifies the things that end it, and you can release the target whenever you like (no action required).\n\n**Escaping a Grapple.** A grappled creature can use its action to escape. To do so, it must succeed on a Strength (Athletics) or Dexterity (Acrobatics) check contested by your Strength (Athletics) check.\n\n **Moving a Grappled Creature.** When you move, you can drag or carry the grappled creature with you, but your speed is halved, unless the creature is two or more sizes smaller than you.\n\n > **Contests in Combat**\n\n > Battle often involves pitting your prowess against that of your foe. Such a challenge is represented by a contest. This section includes the most common contests that require an action in combat: grappling and shoving a creature. The GM can use these contests as models for improvising others.\n\n\n### Shoving a Creature\n\nUsing the Attack action, you can make a special melee attack to shove a creature, either to knock it srd:prone or push it away from you. If you're able to make multiple attacks with the Attack action, this attack replaces one of them.\n\nThe target must be no more than one size larger than you and must be within your reach. Instead of making an attack roll, you make a Strength (Athletics) check contested by the target's Strength (Athletics) or Dexterity (Acrobatics) check (the target chooses the ability to use). If you win the contest, you either knock the target srd:prone or push it 5 feet away from you.",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Combat"
        },
        {
            "slug": "backgrounds",
            "name": "Backgrounds",
            "desc": "Every story has a beginning. Your character's background reveals where you came from, how you became an adventurer, and your place in the world. Your fighter might have been a courageous knight or a grizzled soldier. Your wizard could have been a sage or an artisan. Your rogue might have gotten by as a guild thief or commanded audiences as a jester.\n\nChoosing a background provides you with important story cues about your character's identity. The most important question to ask about your background is *what changed*? Why did you stop doing whatever your background describes and start adventuring? Where did you get the money to purchase your starting gear, or, if you come from a wealthy background, why don't you have *more* money? How did you learn the skills of your class? What sets you apart from ordinary people who share your background?\n\nThe sample backgrounds in this chapter provide both concrete benefits (features, proficiencies, and languages) and roleplaying suggestions.\n\n## Proficiencies\n\nEach background gives a character proficiency in two skills (described in “Using Ability Scores”).\n\nIn addition, most backgrounds give a character proficiency with one or more tools (detailed in “Equipment”).\n\nIf a character would gain the same proficiency from two different sources, he or she can choose a different proficiency of the same kind (skill or tool) instead.\n\n## Languages\n\nSome backgrounds also allow characters to learn additional languages beyond those given by race. See “Languages.”\n\n## Equipment\n\nEach background provides a package of starting equipment. If you use the optional rule to spend coin on gear, you do not receive the starting equipment from your background.\n\n## Suggested Characteristics\n\nA background contains suggested personal characteristics based on your background. You can pick characteristics, roll dice to determine them randomly, or use the suggestions as inspiration for characteristics of your own creation.\n\n## Customizing a Background\n\nYou might want to tweak some of the features of a background so it better fits your character or the campaign setting. To customize a background, you can replace one feature with any other one, choose any two skills, and choose a total of two tool proficiencies or languages from the sample backgrounds. You can either use the equipment package from your background or spend coin on gear as described in the equipment section. (If you spend coin, you can't also take the equipment package suggested for your class.) Finally, choose two personality traits, one ideal, one bond, and one flaw. If you can't find a feature that matches your desired background, work with your GM to create one.",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Characters"
        },
        {
            "slug": "between-adventures",
            "name": "Between Adventures",
            "desc": "Between trips to dungeons and battles against ancient evils, adventurers need time to rest, recuperate, and prepare for their next adventure.\n\n Many adventurers also use this time to perform other tasks, such as crafting arms and armor, performing research, or spending their hard-earned gold.\n\n In some cases, the passage of time is something that occurs with little fanfare or description. When starting a new adventure, the GM might simply declare that a certain amount of time has passed and allow you to describe in general terms what your character has been doing. At other times, the GM might want to keep track of just how much time is passing as events beyond your perception stay in motion.\n\n## Lifestyle Expenses\n\nBetween adventures, you choose a particular quality of life and pay the cost of maintaining that lifestyle.\n\nLiving a particular lifestyle doesn't have a huge effect on your character, but your lifestyle can affect the way other individuals and groups react to you. For example, when you lead an aristocratic lifestyle, it might be easier for you to influence the nobles of the city than if you live in poverty.\n\n## Downtime Activities \n\nBetween adventures, the GM might ask you what your character is doing during his or her downtime. Periods of downtime can vary in duration, but each downtime activity requires a certain number of days to complete before you gain any benefit, and at least 8 hours of each day must be spent on the downtime activity for the day to count. The days do not need to be consecutive. If you have more than the minimum amount of days to spend, you can keep doing the same thing for a longer period of time, or switch to a new downtime activity.\n\n Downtime activities other than the ones presented below are possible. If you want your character to spend his or her downtime performing an activity not covered here, discuss it with your GM.\n\n### Crafting \n\nYou can craft nonmagical objects, including adventuring equipment and works of art. You must be proficient with tools related to the object you are trying to create (typically artisan's tools). You might also need access to special materials or locations necessary to create it.\n\nFor example, someone proficient with smith's tools needs a forge in order to craft a sword or suit of armor.\n\nFor every day of downtime you spend crafting, you can craft one or more items with a total market value not exceeding 5 gp, and you must expend raw materials worth half the total market value. If something you want to craft has a market value greater than 5 gp, you make progress every day in 5- gp increments until you reach the market value of the item.\n\nFor example, a suit of plate armor (market value 1,500 gp) takes 300 days to craft by yourself.\n\n Multiple characters can combine their efforts toward the crafting of a single item, provided that the characters all have proficiency with the requisite tools and are working together in the same place. Each character contributes 5 gp worth of effort for every day spent helping to craft the item. For example, three characters with the requisite tool proficiency and the proper facilities can craft a suit of plate armor in 100 days, at a total cost of 750 gp.\n\n While crafting, you can maintain a modest lifestyle without having to pay 1 gp per day, or a comfortable lifestyle at half the normal cost.\n\n### Practicing a Profession\n\nYou can work between adventures, allowing you to maintain a modest lifestyle without having to pay 1 gp per day. This benefit lasts as long you continue to practice your profession.\n\nIf you are a member of an organization that can provide gainful employment, such as a temple or a thieves' guild, you earn enough to support a comfortable lifestyle instead.\n\nIf you have proficiency in the Performance skill and put your performance skill to use during your downtime, you earn enough to support a wealthy lifestyle instead.\n\n### Recuperating  \nYou can use downtime between adventures to recover from a debilitating injury, disease, or poison.\n\nAfter three days of downtime spent recuperating, you can make a DC 15 Constitution saving throw. On a successful save, you can choose one of the following results:\n\n- End one effect on you that prevents you from regaining hit points.\n- For the next 24 hours, gain advantage on saving throws against one disease or poison currently affecting you.\n\n\n### Researching\n\nThe time between adventures is a great chance to perform research, gaining insight into mysteries that have unfurled over the course of the campaign. Research can include poring over dusty tomes and crumbling scrolls in a library or buying drinks for the locals to pry rumors and gossip from their lips.\n\nWhen you begin your research, the GM determines whether the information is available, how many days of downtime it will take to find it, and whether there are any restrictions on your research (such as needing to seek out a specific individual, tome, or location). The GM might also require you to make one or more ability checks, such as an Intelligence (Investigation) check to find clues pointing toward the information you seek, or a Charisma (Persuasion) check to secure someone's aid. Once those conditions are met, you learn the information if it is available.\n\nFor each day of research, you must spend 1 gp to cover your expenses.\n\nThis cost is in addition to your normal lifestyle expenses.\n\n### Training\n\nYou can spend time between adventures learning a new language or training with a set of tools. Your GM might allow additional training options.\n\nFirst, you must find an instructor willing to teach you. The GM determines how long it takes, and whether one or more ability checks are required.\n\nThe training lasts for 250 days and costs 1 gp per day. After you spend the requisite amount of time and money, you learn the new language or gain proficiency with the new tool.",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Gameplay Mechanics"
        },
        {
            "slug": "coins",
            "name": "Coins",
            "desc": "Common coins come in several different denominations based on the relative worth of the metal from which they are made. The three most common coins are the gold piece (gp), the silver piece (sp), and the copper piece (cp).\n\nWith one gold piece, a character can buy a bedroll, 50 feet of good rope, or a goat. A skilled (but not exceptional) artisan can earn one gold piece a day. The old piece is the standard unit of measure for wealth, even if the coin itself is not commonly used. When merchants discuss deals that involve goods or services worth hundreds or thousands of gold pieces, the transactions don't usually involve the exchange of individual coins. Rather, the gold piece is a standard measure of value, and the actual exchange is in gold bars, letters of credit, or valuable goods.\n\nOne gold piece is worth ten silver pieces, the most prevalent coin among commoners. A silver piece buys a laborer's work for half a day, a flask of lamp oil, or a night's rest in a poor inn.\n\nOne silver piece is worth ten copper pieces, which are common among laborers and beggars. A single copper piece buys a candle, a torch, or a piece of chalk.\n\nIn addition, unusual coins made of other precious metals sometimes appear in treasure hoards. The electrum piece (ep) and the platinum piece (pp) originate from fallen empires and lost kingdoms, and they sometimes arouse suspicion and skepticism when used in transactions. An electrum piece is worth five silver pieces, and a platinum piece is worth ten gold pieces.\n\nA standard coin weighs about a third of an ounce, so fifty coins weigh a pound.\n\n**Standard Exchange Rates (table)**\n\n| Coin          | CP    | SP   | EP   | GP    | PP      |\n|---------------|-------|------|------|-------|---------|\n| Copper (cp)   | 1     | 1/10 | 1/50 | 1/100 | 1/1,000 |\n| Silver (sp)   | 10    | 1    | 1/5  | 1/10  | 1/100   |\n| Electrum (ep) | 50    | 5    | 1    | 1/2   | 1/20    |\n| Gold (gp)     | 100   | 10   | 2    | 1     | 1/10    |\n| Platinum (pp) | 1,000 | 100  | 20   | 10    | 1       |",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Equipment"
        },
        {
            "slug": "combat-sequence",
            "name": "Combat Sequence",
            "desc": "A typical combat encounter is a clash between two sides, a flurry of weapon swings, feints, parries, footwork, and spellcasting. The game organizes the chaos of combat into a cycle of rounds and turns. A **round** represents about 6 seconds in the game world. During a round, each participant in a battle takes a **turn**. The order of turns is determined at the beginning of a combat encounter, when everyone rolls initiative. Once everyone has taken a turn, the fight continues to the next round if neither side has defeated the other.\n\n> **Combat Step by Step** > > 1. **Determine surprise.** The GM determines whether anyone involved > in the combat encounter is surprised. > 2. **Establish positions.** The GM decides where all the characters > and monsters are located. Given the adventurers' marching order or > their stated positions in the room or other location, the GM > figures out where the adversaries are̶ how far away and in what > direction. > 3. **Roll initiative.** Everyone involved in the combat encounter > rolls initiative, determining the order of combatants' turns. > 4. **Take turns.** Each participant in the battle takes a turn in > initiative order. > 5. **Begin the next round.** When everyone involved in the combat has > had a turn, the round ends. Repeat step 4 until the fighting > stops.\n\n**Surprise**\n\nA band of adventurers sneaks up on a bandit camp springing from the trees to attack them. A gelatinous cube glides down a dungeon passage, unnoticed by the adventurers until the cube engulfs one of them. In these situations, one side of the battle gains surprise over the other.\n\nThe GM determines who might be surprised. If neither side tries to be stealthy, they automatically notice each other. Otherwise, the GM compares the Dexterity (Stealth) checks of anyone hiding with the passive Wisdom (Perception) score of each creature on the opposing side. Any character or monster that doesn't notice a threat is surprised at the start of the encounter.\n\nIf you're surprised, you can't move or take an action on your first turn of the combat, and you can't take a reaction until that turn ends. A member of a group can be surprised even if the other members aren't.\n\n## Initiative\n\nInitiative determines the order of turns during combat. When combat starts, every participant makes a Dexterity check to determine their place in the initiative order. The GM makes one roll for an entire group of identical creatures, so each member of the group acts at the same time.\n\nThe GM ranks the combatants in order from the one with the highest Dexterity check total to the one with the lowest. This is the order (called the initiative order) in which they act during each round. The initiative order remains the same from round to round.\n\nIf a tie occurs, the GM decides the order among tied GM-controlled creatures, and the players decide the order among their tied characters. The GM can decide the order if the tie is between a monster and a player character. Optionally, the GM can have the tied characters and monsters each roll a d20 to determine the order, highest roll going first.\n\n## Your Turn\n\nOn your turn, you can **move** a distance up to your speed and **take one action**. You decide whether to move first or take your action first. Your speed---sometimes called your walking speed---is noted on your character sheet.\n\nThe most common actions you can take are described in srd:actions-in-combat. Many class features and other abilities provide additional options for your action.\n\nsrd:movement-and-position gives the rules for your move.\n\nYou can forgo moving, taking an action, or doing anything at all on your turn. If you can't decide what to do on your turn, consider taking the Dodge or Ready action, as described in srd:actions-in-combat.\n\n### Bonus Actions\n\nVarious class features, spells, and other abilities let you take an additional action on your turn called a bonus action. The Cunning Action feature, for example, allows a rogue to take a bonus action. You can take a bonus action only when a special ability, spell, or other feature of the game states that you can do something as a bonus action. You otherwise don't have a bonus action to take.\n\n> **Sage Advice**\n\n> Actions and bonus actions can't be exchanged. If you have two abilities that require bonus actions to activate you can only use one, even if you take no other actions.\n\n> Source: [Sage Advice > Compendium](http://media.wizards.com/2015/downloads/dnd/SA_Compendium_1.01.pdf)\n\nYou can take only one bonus action on your turn, so you must choose which bonus action to use when you have more than one available.\n\nYou choose when to take a bonus action during your turn, unless the bonus action's timing is specified, and anything that deprives you of your ability to take actions also prevents you from taking a bonus action.\n\n### Other Activity on Your Turn\n\nYour turn can include a variety of flourishes that require neither your action nor your move.\n\nYou can communicate however you are able, through brief utterances and gestures, as you take your turn.\n\nYou can also interact with one object or feature of the environment for free, during either your move or your action. For example, you could open a door during your move as you stride toward a foe, or you could draw your weapon as part of the same action you use to attack.\n\nIf you want to interact with a second object, you need to use your action. Some magic items and other special objects always require an action to use, as stated in their descriptions.\n\nThe GM might require you to use an action for any of these activities when it needs special care or when it presents an unusual obstacle. For instance, the GM could reasonably expect you to use an action to open a stuck door or turn a crank to lower a drawbridge.\n\n## Reactions\n\nCertain special abilities, spells, and situations allow you to take a special action called a reaction. A reaction is an instant response to a trigger of some kind, which can occur on your turn or on someone else's. The opportunity attack <srd:opportunity-attacks> is the most common type of reaction.\n\nWhen you take a reaction, you can't take another one until the start of your next turn. If the reaction interrupts another creature's turn, that creature can continue its turn right after the reaction.",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Combat"
        },
        {
            "slug": "conditions",
            "name": "Conditions",
            "desc": "Conditions alter a creature's capabilities in a variety of ways and can arise as a result of a spell, a class feature, a monster's attack, or other effect. Most conditions, such as blinded, are impairments, but a few, such as invisible, can be advantageous.\n\nA condition lasts either until it is countered (the prone condition is countered by standing up, for example) or for a duration specified by the effect that imposed the condition.\n\nIf multiple effects impose the same condition on a creature, each instance of the condition has its own duration, but the condition's effects don't get worse. A creature either has a condition or doesn't.\n\nThe following definitions specify what happens to a creature while it is subjected to a condition.\n\n## Blinded\n\n* A blinded creature can't see and automatically fails any ability check that requires sight.\n* Attack rolls against the creature have advantage, and the creature's attack rolls have disadvantage.\n\n## Charmed\n\n* A charmed creature can't attack the charmer or target the charmer with harmful abilities or magical effects.\n* The charmer has advantage on any ability check to interact socially with the creature.\n\n## Deafened\n\n* A deafened creature can't hear and automatically fails any ability check that requires hearing.\n\n## Exhaustion\n\n* Some special abilities and environmental hazards, such as starvation and the long-term effects of freezing or scorching temperatures, can lead to a special condition called exhaustion. Exhaustion is measured in six levels. An effect can give a creature one or more levels of exhaustion, as specified in the effect's description.\n\n| Level | Effect                                         |\n|-------|------------------------------------------------|\n| 1     | Disadvantage on ability checks                 |\n| 2     | Speed halved                                   |\n| 3     | Disadvantage on attack rolls and saving throws |\n| 4     | Hit point maximum halved                       |\n| 5     | Speed reduced to 0                             |\n| 6     | Death                                          |\n\nIf an already exhausted creature suffers another effect that causes exhaustion, its current level of exhaustion increases by the amount specified in the effect's description.\n\nA creature suffers the effect of its current level of exhaustion as well as all lower levels. For example, a creature suffering level 2 exhaustion has its speed halved and has disadvantage on ability checks.\n\nAn effect that removes exhaustion reduces its level as specified in the effect's description, with all exhaustion effects ending if a creature's exhaustion level is reduced below 1.\n\nFinishing a long rest reduces a creature's exhaustion level by 1, provided that the creature has also ingested some food and drink.\n\n## Frightened\n\n* A frightened creature has disadvantage on ability checks and attack rolls while the source of its fear is within line of sight.\n* The creature can't willingly move closer to the source of its fear.\n\n## Grappled\n\n* A grappled creature's speed becomes 0, and it can't benefit from any bonus to its speed.\n* The condition ends if the grappler is incapacitated (see the condition).\n* The condition also ends if an effect removes the grappled creature from the reach of the grappler or grappling effect, such as when a creature is hurled away by the *thunder-wave* spell.\n\n## Incapacitated\n\n* An incapacitated creature can't take actions or reactions.\n\n## Invisible\n\n* An invisible creature is impossible to see without the aid of magic or a special sense. For the purpose of hiding, the creature is heavily obscured. The creature's location can be detected by any noise it makes or any tracks it leaves.\n* Attack rolls against the creature have disadvantage, and the creature's attack rolls have advantage.\n\n## Paralyzed\n\n* A paralyzed creature is incapacitated (see the condition) and can't move or speak.\n* The creature automatically fails Strength and Dexterity saving throws.\n* Attack rolls against the creature have advantage.\n* Any attack that hits the creature is a critical hit if the attacker is within 5 feet of the creature.\n\n## Petrified\n\n* A petrified creature is transformed, along with any nonmagical object it is wearing or carrying, into a solid inanimate substance (usually stone). Its weight increases by a factor of ten, and it ceases aging.\n* The creature is incapacitated (see the condition), can't move or speak, and is unaware of its surroundings.\n* Attack rolls against the creature have advantage.\n* The creature automatically fails Strength and Dexterity saving throws.\n* The creature has resistance to all damage.\n* The creature is immune to poison and disease, although a poison or disease already in its system is suspended, not neutralized.\n\n## Poisoned\n\n* A poisoned creature has disadvantage on attack rolls and ability checks.\n\n## Prone\n\n* A prone creature's only movement option is to crawl, unless it stands up and thereby ends the condition.\n* The creature has disadvantage on attack rolls.\n* An attack roll against the creature has advantage if the attacker is within 5 feet of the creature. Otherwise, the attack roll has disadvantage.\n\n## Restrained\n\n* A restrained creature's speed becomes 0, and it can't benefit from any bonus to its speed.\n* Attack rolls against the creature have advantage, and the creature's attack rolls have disadvantage.\n* The creature has disadvantage on Dexterity saving throws.\n\n## Stunned\n\n* A stunned creature is incapacitated (see the condition), can't move, and can speak only falteringly.\n* The creature automatically fails Strength and Dexterity saving throws.\n* Attack rolls against the creature have advantage.\n\n## Unconscious\n\n* An unconscious creature is incapacitated (see the condition), can't move or speak, and is unaware of its surroundings\n* The creature drops whatever it's holding and falls prone.\n* The creature automatically fails Strength and Dexterity saving throws.\n* Attack rolls against the creature have advantage.\n* Any attack that hits the creature is a critical hit if the attacker is within 5 feet of the creature.",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Rules"
        },
        {
            "slug": "cover",
            "name": "Cover",
            "desc": "Walls, trees, creatures, and other obstacles can provide cover during combat, making a target more difficult to harm. A target can benefit from cover only when an attack or other effect originates on the opposite side of the cover.\n\n There are three degrees of cover. If a target is behind multiple sources of cover, only the most protective degree of cover applies; the degrees aren't added together. For example, if a target is behind a creature that gives half cover and a tree trunk that gives three-quarters cover, the target has three-quarters cover.\n\nA target with **half cover** has a +2 bonus to AC and Dexterity saving throws. A target has half cover if an obstacle blocks at least half of its body. The obstacle might be a low wall, a large piece of furniture, a narrow tree trunk, or a creature, whether that creature is an enemy or a friend.\n\nA target with **three-quarters cover** has a +5 bonus to AC and Dexterity saving throws. A target has three-quarters cover if about three-quarters of it is covered by an obstacle. The obstacle might be a portcullis, an arrow slit, or a thick tree trunk.\n\n A target with **total cover** can't be targeted directly by an attack or a spell, although some spells can reach such a target by including it in an area of effect. A target has total cover if it is completely concealed by an obstacle. ",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Combat"
        },
        {
            "slug": "damage-and-healing",
            "name": "Damage and Healing",
            "desc": "Injury and the risk of death are constant companions of those who explore fantasy gaming worlds. The thrust of a sword, a well-placed arrow, or a blast of flame from a srd:fireball spell all have the potential to damage, or even kill, the hardiest of creatures.\n\n## Hit Points\n\nHit points represent a combination of physical and mental durability, the will to live, and luck. Creatures with more hit points are more difficult to kill. Those with fewer hit points are more fragile.\n\nA creature's current hit points (usually just called hit points) can be any number from the creature's hit point maximum down to 0. This number changes frequently as a creature takes damage or receives healing.\n\nWhenever a creature takes damage, that damage is subtracted from its hit points. The loss of hit points has no effect on a creature's capabilities until the creature drops to 0 hit points.\n\n## Damage Rolls\n\nEach weapon, spell, and harmful monster ability specifies the damage it deals. You roll the damage die or dice, add any modifiers, and apply the damage to your target. Magic weapons, special abilities, and other factors can grant a bonus to damage. With a penalty, it is possible to deal 0 damage, but never negative damage. When attacking with a **weapon**, you add your ability modifier---the same modifier used for the attack roll---to the damage. A **spell** tells you which dice to roll for damage and whether to add any modifiers.\n\nIf a spell or other effect deals damage to **more** **than one target** at the same time, roll the damage once for all of them. For example, when a wizard casts srd:fireball or a cleric casts srd:flame-strike, the spell's damage is rolled once for all creatures caught in the blast.\n\n### Critical Hits\n\nWhen you score a critical hit, you get to roll extra dice for the attack's damage against the target. Roll all of the attack's damage dice twice and add them together. Then add any relevant modifiers as normal. To speed up play, you can roll all the damage dice at once.\n\nFor example, if you score a critical hit with a dagger, roll 2d4 for the damage, rather than 1d4, and then add your relevant ability modifier. If the attack involves other damage dice, such as from the rogue's Sneak Attack feature, you roll those dice twice as well.\n\n### Damage Types\n\nDifferent attacks, damaging spells, and other harmful effects deal different types of damage. Damage types have no rules of their own, but other rules, such as damage resistance, rely on the types.\n\nThe damage types follow, with examples to help a GM assign a damage type to a new effect.\n\n**Acid.** The corrosive spray of a black dragon's breath and the dissolving enzymes secreted by a black pudding deal acid damage.\n\n**Bludgeoning.** Blunt force attacks---hammers, falling, constriction, and the like---deal bludgeoning damage.\n\n**Cold.** The infernal chill radiating from an ice devil's spear and the frigid blast of a white dragon's breath deal cold damage.\n\n**Fire.** Red dragons breathe fire, and many spells conjure flames to deal fire damage.\n\n**Force.** Force is pure magical energy focused into a damaging form. Most effects that deal force damage are spells, including _magic missile_ and _spiritual weapon_.\n\n**Lightning.** A _lightning bolt_ spell and a blue dragon's breath deal lightning damage.\n\n**Necrotic.** Necrotic damage, dealt by certain undead and a spell such as _chill touch_, withers matter and even the soul.\n\n**Piercing.** Puncturing and impaling attacks, including spears and monsters' bites, deal piercing damage.\n\n**Poison.** Venomous stings and the toxic gas of a green dragon's breath deal poison damage.\n\n**Psychic.** Mental abilities such as a mind flayer's psionic blast deal psychic damage.\n\n**Radiant.** Radiant damage, dealt by a cleric's _flame strike_ spell or an angel's smiting weapon, sears the flesh like fire and overloads the spirit with power.\n\n**Slashing.** Swords, axes, and monsters' claws deal slashing damage.\n\n**Thunder.** A concussive burst of sound, such as the effect of the srd:thunderwave spell, deals thunder damage.\n\n## Damage Resistance and Vulnerability\n\nSome creatures and objects are exceedingly difficult or unusually easy to hurt with certain types of damage.\n\nIf a creature or an object has **resistance** to a damage type, damage of that type is halved against it. If a creature or an object has **vulnerability** to a damage type, damage of that type is doubled against it.\n\nResistance and then vulnerability are applied after all other modifiers to damage. For example, a creature has resistance to bludgeoning damage and is hit by an attack that deals 25 bludgeoning damage. The creature is also within a magical aura that reduces all damage by 5. The 25 damage is first reduced by 5 and then halved, so the creature takes 10 damage.\n\nMultiple instances of resistance or vulnerability that affect the same damage type count as only one instance. For example, if a creature has resistance to fire damage as well as resistance to all nonmagical damage, the damage of a nonmagical fire is reduced by half against the creature, not reduced by three--- quarters.\n\n## Healing\n\nUnless it results in death, damage isn't permanent. Even death is reversible through powerful magic. Rest can restore a creature's hit points, and magical methods such as a _cure wounds_ spell or a _potion of healing_ can remove damage in an instant.\n\nWhen a creature receives healing of any kind, hit points regained are added to its current hit points. A creature's hit points can't exceed its hit point maximum, so any hit points regained in excess of this number are lost. For example, a druid grants a ranger 8 hit points of healing. If the ranger has 14 current hit points and has a hit point maximum of 20, the ranger regains 6 hit points from the druid, not 8.\n\nA creature that has died can't regain hit points until magic such as the srd:revivify spell has restored it to life.\n\n## Dropping to 0 Hit Points\n\nWhen you drop to 0 hit points, you either die outright or fall srd:unconscious, as explained in the following sections.\n\n### Instant Death\n\nMassive damage can kill you instantly. When damage reduces you to 0 hit points and there is damage remaining, you die if the remaining damage equals or exceeds your hit point maximum.\n\nFor example, a cleric with a maximum of 12 hit points currently has 6 hit points. If she takes 18 damage from an attack, she is reduced to 0 hit points, but 12 damage remains. Because the remaining damage equals her hit point maximum, the cleric dies.\n\n### Falling Unconscious\n\nIf damage reduces you to 0 hit points and fails to kill you, you fall srd:unconscious. This unconsciousness ends if you regain any hit points.\n\n### Death Saving Throws\n\nWhenever you start your turn with 0 hit points, you must make a special saving throw, called a death saving throw, to determine whether you creep closer to death or hang onto life. Unlike other saving throws, this one isn't tied to any ability score. You are in the hands of fate now, aided only by spells and features that improve your chances of succeeding on a saving throw.\n\nRoll a d20. If the roll is 10 or higher, you succeed. Otherwise, you fail. A success or failure has no effect by itself. On your third success, you become stable (see below). On your third failure, you die. The successes and failures don't need to be consecutive; keep track of both until you collect three of a kind. The number of both is reset to zero when you regain any hit points or become stable.\n\n**Rolling 1 or 20.** When you make a death saving throw and roll a 1 on the d20, it counts as two failures. If you roll a 20 on the d20, you regain 1 hit point.\n\n**Damage at 0 Hit Points.** If you take any damage while you have 0 hit points, you suffer a death saving throw failure. If the damage is from a critical hit, you suffer two failures instead. If the damage equals or exceeds your hit point maximum, you suffer instant death.\n\n### Stabilizing a Creature\n\nThe best way to save a creature with 0 hit points is to heal it. If healing is unavailable, the creature can at least be stabilized so that it isn't killed by a failed death saving throw.\n\nYou can use your action to administer first aid to an srd:unconscious creature and attempt to stabilize it, which requires a successful DC 10 Wisdom (Medicine) check. A **stable** creature doesn't make death saving throws, even though it has 0 hit points, but it does remain srd:unconscious. The creature stops being stable, and must start making death saving throws again, if it takes any damage. A stable creature that isn't healed regains 1 hit point after 1d4 hours.\n\n### Monsters and Death\n\nMost GMs have a monster die the instant it drops to 0 hit points, rather than having it fall srd:unconscious and make death saving throws. Mighty villains and special nonplayer characters are common exceptions; the GM might have them fall srd:unconscious and follow the same rules as player characters.\n\n## Knocking a Creature Out\n\nSometimes an attacker wants to incapacitate a foe, rather than deal a killing blow. When an attacker reduces a creature to 0 hit points with a melee attack, the attacker can knock the creature out. The attacker can make this choice the instant the damage is dealt. The creature falls srd:unconscious and is stable.\n\n## Temporary Hit Points\n\nSome spells and special abilities confer temporary hit points to a creature. Temporary hit points aren't actual hit points; they are a buffer against damage, a pool of hit points that protect you from injury. When you have temporary hit points and take damage, the temporary hit points are lost first, and any leftover damage carries over to your normal hit points. _For example, if you have 5 temporary hit points and take 7 damage, you lose the temporary hit points and then take 2 damage._ Because temporary hit points are separate from your actual hit points, they can exceed your hit point maximum. A character can, therefore, be at full hit points and receive temporary hit points.\n\nHealing can't restore temporary hit points, and they can't be added together. If you have temporary hit points and receive more of them, you decide whether to keep the ones you have or to gain the new ones. For example, if a spell grants you 12 temporary hit points when you already have 10, you can have 12 or 10, not 22.\n\nIf you have 0 hit points, receiving temporary hit points doesn't restore you to consciousness or stabilize you. They can still absorb damage directed at you while you're in that state, but only true healing can save you.\n\nUnless a feature that grants you temporary hit points has a duration, they last until they're depleted or you finish a long rest.",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Combat"
        },
        {
            "slug": "diseases",
            "name": "Diseases",
            "desc": "A plague ravages the kingdom, setting the adventurers on a quest to find a cure. An adventurer emerges from an ancient tomb, unopened for centuries, and soon finds herself suffering from a wasting illness. A warlock offends some dark power and contracts a strange affliction that spreads whenever he casts spells.\n\nA simple outbreak might amount to little more than a small drain on party resources, curable by a casting of _lesser restoration_. A more complicated outbreak can form the basis of one or more adventures as characters search for a cure, stop the spread of the disease, and deal with the consequences.\n\nA disease that does more than infect a few party members is primarily a plot device. The rules help describe the effects of the disease and how it can be cured, but the specifics of how a disease works aren't bound by a common set of rules. Diseases can affect any creature, and a given illness might or might not pass from one race or kind of creature to another. A plague might affect only constructs or undead, or sweep through a halfling neighborhood but leave other races untouched. What matters is the story you want to tell.\n\n## Sample Diseases\n\nThe diseases here illustrate the variety of ways disease can work in the game. Feel free to alter the saving throw DCs, incubation times, symptoms, and other characteristics of these diseases to suit your campaign.\n\n### Cackle Fever\n\nThis disease targets humanoids, although gnomes are strangely immune. While in the grips of this disease, victims frequently succumb to fits of mad laughter, giving the disease its common name and its morbid nickname: “the shrieks.”\n\nSymptoms manifest 1d4 hours after infection and include fever and disorientation. The infected creature gains one level of exhaustion that can't be removed until the disease is cured.\n\nAny event that causes the infected creature great stress-including entering combat, taking damage, experiencing fear, or having a nightmare-forces the creature to make a DC 13 Constitution saving throw. On a failed save, the creature takes 5 (1d10) psychic damage and becomes incapacitated with mad laughter for 1 minute. The creature can repeat the saving throw at the end of each of its turns, ending the mad laughter and the incapacitated condition on a success.\n\nAny humanoid creature that starts its turn within 10 feet of an infected creature in the throes of mad laughter must succeed on a DC 10 Constitution saving throw or also become infected with the disease. Once a creature succeeds on this save, it is immune to the mad laughter of that particular infected creature for 24 hours.\n\nAt the end of each long rest, an infected creature can make a DC 13 Constitution saving throw. On a successful save, the DC for this save and for the save to avoid an attack of mad laughter drops by 1d6. When the saving throw DC drops to 0, the creature recovers from the disease. A creature that fails three of these saving throws gains a randomly determined form of indefinite madness, as described later in this chapter.\n\n### Sewer Plague\n\nSewer plague is a generic term for a broad category of illnesses that incubate in sewers, refuse heaps, and stagnant swamps, and which are sometimes transmitted by creatures that dwell in those areas, such as rats and otyughs.\n\nWhen a humanoid creature is bitten by a creature that carries the disease, or when it comes into contact with filth or offal contaminated by the disease, the creature must succeed on a DC 11 Constitution saving throw or become infected.\n\nIt takes 1d4 days for sewer plague's symptoms to manifest in an infected creature. Symptoms include fatigue and cramps. The infected creature suffers one level of exhaustion, and it regains only half the normal number of hit points from spending Hit Dice and no hit points from finishing a long rest.\n\nAt the end of each long rest, an infected creature must make a DC 11 Constitution saving throw. On a failed save, the character gains one level of exhaustion. On a successful save, the character's exhaustion level decreases by one level. If a successful saving throw reduces the infected creature's level of exhaustion below 1, the creature recovers from the disease.\n\n### Sight Rot\n\nThis painful infection causes bleeding from the eyes and eventually blinds the victim.\n\nA beast or humanoid that drinks water tainted by sight rot must succeed on a DC 15 Constitution saving throw or become infected. One day after infection, the creature's vision starts to become blurry. The creature takes a -1 penalty to attack rolls and ability checks that rely on sight. At the end of each long rest after the symptoms appear, the penalty worsens by 1. When it reaches -5, the victim is blinded until its sight is restored by magic such as _lesser restoration_ or _heal_.\n\nSight rot can be cured using a rare flower called Eyebright, which grows in some swamps. Given an hour, a character who has proficiency with an herbalism kit can turn the flower into one dose of ointment. Applied to the eyes before a long rest, one dose of it prevents the disease from worsening after that rest. After three doses, the ointment cures the disease entirely.",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Rules"
        },
        {
            "slug": "environment",
            "name": "Environment",
            "desc": "By its nature, adventuring involves delving into places that are dark, dangerous, and full of mysteries to be explored. The rules in thissection cover some of the most important ways in which adventurersinteract with the environment in such places.\n## Falling \nA fall from a great height is one of the most common hazards facing anadventurer. At the end of a fall, a creature takes 1d6 bludgeoningdamage for every 10 feet it fell, to a maximum of 20d6. The creaturelands prone, unless it avoids taking damage from the fall.\n## Suffocating\nA creature can hold its breath for a number of minutes equal to 1 + itsConstitution modifier (minimum of 30 seconds).\nWhen a creature runs out of breath or is choking, it can survive for anumber of rounds equal to its Constitution modifier (minimum of 1round). At the start of its next turn, it drops to 0 hit points and isdying, and it can't regain hit points or be stabilized until it canbreathe again.\nFor example, a creature with a Constitution of 14 can hold its breathfor 3 minutes. If it starts suffocating, it has 2 rounds to reach airbefore it drops to 0 hit points.\n## Vision and Light\nThe most fundamental tasks of adventuring---noticing danger, findinghidden objects, hitting an enemy in combat, and targeting a spell, toname just a few---rely heavily on a character's ability to see. Darknessand other effects that obscure vision can prove a significant hindrance.\nA given area might be lightly or heavily obscured. In a **lightly obscured** area, such as dim light, patchy fog, or moderate foliage,creatures have disadvantage on Wisdom (Perception) checks that rely onsight.\nA **heavily obscured** area---such as darkness, opaque fog, or densefoliage---blocks vision entirely. A creature effectively suffers fromthe blinded condition when trying to see something in that area.\nThe presence or absence of light in an environment creates threecategories of illumination: bright light, dim light, and darkness.\n**Bright light** lets most creatures see normally. Even gloomy daysprovide bright light, as do torches, lanterns, fires, and other sourcesof illumination within a specific radius.\n**Dim light**, also called shadows, creates a lightly obscured area. Anarea of dim light is usually a boundary between a source of brightlight, such as a torch, and surrounding darkness. The soft light oftwilight and dawn also counts as dim light. A particularly brilliantfull moon might bathe the land in dim light.\n**Darkness** creates a heavily obscured area. Characters face darknessoutdoors at night (even most moonlit nights), within the confines of anunlit dungeon or a subterranean vault, or in an area of magicaldarkness.\n### Blindsight\nA creature with blindsight can perceive its surroundings without relyingon sight, within a specific radius. Creatures without eyes, such asoozes, and creatures with echolocation or heightened senses, such asbats and true dragons, have this sense.\n\n### Darkvision\n\nMany creatures in fantasy gaming worlds, especially those that dwellunderground, have darkvision. Within a specified range, a creature withdarkvision can see in darkness as if the darkness were dim light, soareas of darkness are only lightly obscured as far as that creature isconcerned. However, the creature can't discern color in darkness, onlyshades of gray.\n### Truesight\nA creature with truesight can, out to a specific range, see in normaland magical darkness, see invisible creatures and objects,automatically detect visual illusions and succeed on saving throwsagainst them, and perceives the original form of a shapechanger or acreature that is transformed by magic. Furthermore, the creature can seeinto the Ethereal Plane.\n\n## Food and Water\n\nCharacters who don't eat or drink suffer the effects of exhaustion. Exhaustion caused by lack of food or water can't beremoved until the character eats and drinks the full required amount.\n### Food\nA character needs one pound of food per day and can make food lastlonger by subsisting on half rations. Eating half a pound of food in aday counts as half a day without food.\nA character can go without food for a number of days equal to 3 + his orher Constitution modifier (minimum 1). At the end of each day beyondthat limit, a character automatically suffers one level of exhaustion.\nA normal day of eating resets the count of days without food to zero.\n### Water\nA character needs one gallon of water per day, or two gallons per day ifthe weather is hot. A character who drinks only half that much watermust succeed on a DC 15 Constitution saving throw or suffer one level of exhaustion at the end of the day. A character with access to evenless water automatically suffers one level of exhaustion at the end of the day.\nIf the character already has one or more levels of exhaustion, the character takes two levels in either case.\n## Interacting with Objects\nA character's interaction with objects in an environment is often simpleto resolve in the game. The player tells the GM that his or hercharacter is doing something, such as moving a lever, and the GM describes what, if anything, happens.\nFor example, a character might decide to pull a lever, which might, inturn, raise a portcullis, cause a room to flood with water, or open asecret door in a nearby wall. If the lever is rusted in position,though, a character might need to force it. In such a situation, the GM might call for a Strength check to see whether the character can wrenchthe lever into place. The GM sets the DC for any such check based on thedifficulty of the task.\nCharacters can also damage objects with their weapons and spells.\nObjects are immune to poison and psychic damage, but otherwise they canbe affected by physical and magical attacks much like creatures can. TheGM determines an object's Armor Class and hit points, and might decidethat certain objects have resistance or immunity to certain kinds ofattacks. (It's hard to cut a rope with a club, for example.) Objectsalways fail Strength and Dexterity saving throws, and they are immune toeffects that require other saves. When an object drops to 0 hit points,it breaks.\nA character can also attempt a Strength check to break an object. The GM sets the DC for any such check.",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Gameplay Mechanics"
        },
        {
            "slug": "equipment-packs",
            "name": "Equipment Packs",
            "desc": "The starting equipment you get from your class includes a collection of useful adventuring gear, put together in a pack. The contents of these packs are listed here.\n\nIf you are buying your starting equipment, you can purchase a pack for the price shown, which might be cheaper than buying the items individually.\n\n**Burglar's Pack (16 gp).** Includes a backpack, a bag of 1,000 ball bearings, 10 feet of string, a bell, 5 candles, a crowbar, a hammer, 10 pitons, a hooded lantern, 2 flasks of oil, 5 days rations, a tinderbox, and a waterskin. The pack also has 50 feet of hempen rope strapped to the side of it.\n\n**Diplomat's Pack (39 gp).** Includes a chest, 2 cases for maps and scrolls, a set of fine clothes, a bottle of ink, an ink pen, a lamp, 2 flasks of oil, 5 sheets of paper, a vial of perfume, sealing wax, and soap.\n\n**Dungeoneer's Pack (12 gp).** Includes a backpack, a crowbar, a hammer, 10 pitons, 10 torches, a tinderbox, 10 days of rations, and a waterskin. The pack also has 50 feet of hempen rope strapped to the side of it.\n\n**Entertainer's Pack (40 gp).** Includes a backpack, a bedroll, 2 costumes, 5 candles, 5 days of rations, a waterskin, and a disguise kit.\n\n**Explorer's Pack (10 gp).** Includes a backpack, a bedroll, a mess kit, a tinderbox, 10 torches, 10 days of rations, and a waterskin. The pack also has 50 feet of hempen rope strapped to the side of it.\n\n**Priest's Pack (19 gp).** Includes a backpack, a blanket, 10 candles, a tinderbox, an alms box, 2 blocks of incense, a censer, vestments, 2 days of rations, and a waterskin.\n\n**Scholar's Pack (40 gp).** Includes a backpack, a book of lore, a bottle of ink, an ink pen, 10 sheet of parchment, a little bag of sand, and a small knife.",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Equipment"
        },
        {
            "slug": "expenses",
            "name": "Expenses",
            "desc": "When not descending into the depths of the earth, exploring ruins for lost treasures, or waging war against the encroaching darkness, adventurers face more mundane realities. Even in a fantastical world, people require basic necessities such as shelter, sustenance, and clothing. These things cost money, although some lifestyles cost more than others.\n\n## Lifestyle Expenses\n\nLifestyle expenses provide you with a simple way to account for the cost of living in a fantasy world. They cover your accommodations, food and drink, and all your other necessities. Furthermore, expenses cover the cost of maintaining your equipment so you can be ready when adventure next calls.\n\nAt the start of each week or month (your choice), choose a lifestyle from the Expenses table and pay the price to sustain that lifestyle. The prices listed are per day, so if you wish to calculate the cost of your chosen lifestyle over a thirty-day period, multiply the listed price by 30. Your lifestyle might change from one period to the next, based on the funds you have at your disposal, or you might maintain the same lifestyle throughout your character's career.\n\nYour lifestyle choice can have consequences. Maintaining a wealthy lifestyle might help you make contacts with the rich and powerful, though you run the risk of attracting thieves. Likewise, living frugally might help you avoid criminals, but you are unlikely to make powerful connections.\n\n**Lifestyle Expenses (table)**\n\n| Lifestyle    | Price/Day     |\n|--------------|---------------|\n| Wretched     | -             |\n| Squalid      | 1 sp          |\n| Poor         | 2 sp          |\n| Modest       | 1 gp          |\n| Comfortable  | 2 gp          |\n| Wealthy      | 4 gp          |\n| Aristocratic | 10 gp minimum |\n\n**_Wretched._** You live in inhumane conditions. With no place to call home, you shelter wherever you can, sneaking into barns, huddling in old crates, and relying on the good graces of people better off than you. A wretched lifestyle presents abundant dangers. Violence, disease, and hunger follow you wherever you go. Other wretched people covet your armor, weapons, and adventuring gear, which represent a fortune by their standards. You are beneath the notice of most people.\n\n**_Squalid._** You live in a leaky stable, a mud-floored hut just outside town, or a vermin-infested boarding house in the worst part of town. You have shelter from the elements, but you live in a desperate and often violent environment, in places rife with disease, hunger, and misfortune. You are beneath the notice of most people, and you have few legal protections. Most people at this lifestyle level have suffered some terrible setback. They might be disturbed, marked as exiles, or suffer from disease.\n\n**_Poor._** A poor lifestyle means going without the comforts available in a stable community. Simple food and lodgings, threadbare clothing, and unpredictable conditions result in a sufficient, though probably unpleasant, experience. Your accommodations might be a room in a flophouse or in the common room above a tavern. You benefit from some legal protections, but you still have to contend with violence, crime, and disease. People at this lifestyle level tend to be unskilled laborers, costermongers, peddlers, thieves, mercenaries, and other disreputable types.\n\n**_Modest._** A modest lifestyle keeps you out of the slums and ensures that you can maintain your equipment. You live in an older part of town, renting a room in a boarding house, inn, or temple. You don't go hungry or thirsty, and your living conditions are clean, if simple. Ordinary people living modest lifestyles include soldiers with families, laborers, students, priests, hedge wizards, and the like.\n\n**_Comfortable._** Choosing a comfortable lifestyle means that you can afford nicer clothing and can easily maintain your equipment. You live in a small cottage in a middle-class neighborhood or in a private room at a fine inn. You associate with merchants, skilled tradespeople, and military officers.\n\n**_Wealthy._** Choosing a wealthy lifestyle means living a life of luxury, though you might not have achieved the social status associated with the old money of nobility or royalty. You live a lifestyle comparable to that of a highly successful merchant, a favored servant of the royalty, or the owner of a few small businesses. You have respectable lodgings, usually a spacious home in a good part of town or a comfortable suite at a fine inn. You likely have a small staff of servants.\n\n**_Aristocratic._** You live a life of plenty and comfort. You move in circles populated by the most powerful people in the community. You have excellent lodgings, perhaps a townhouse in the nicest part of town or rooms in the finest inn. You dine at the best restaurants, retain the most skilled and fashionable tailor, and have servants attending to your every need. You receive invitations to the social gatherings of the rich and powerful, and spend evenings in the company of politicians, guild leaders, high priests, and nobility. You must also contend with the highest levels of deceit and treachery. The wealthier you are, the greater the chance you will be drawn into political intrigue as a pawn or participant.\n\n> ### Self-Sufficiency\n>\n> The expenses and lifestyles described here assume that you are spending your time between adventures in town, availing yourself of whatever services you can afford-paying for food and shelter, paying townspeople to sharpen your sword and repair your armor, and so on. Some characters, though, might prefer to spend their time away from civilization, sustaining themselves in the wild by hunting, foraging, and repairing their own gear.\n>\n> Maintaining this kind of lifestyle doesn't require you to spend any coin, but it is time-consuming. If you spend your time between adventures practicing a profession, you can eke out the equivalent of a poor lifestyle. Proficiency in the Survival skill lets you live at the equivalent of a comfortable lifestyle.\n\n## Food, Drink, and Lodging\n\nThe Food, Drink, and Lodging table gives prices for individual food items and a single night's lodging. These prices are included in your total lifestyle expenses.\n\n**Food, Drink, and Lodging (table)**\n\n| Item                     | Cost  |\n|--------------------------|-------|\n| **_Ale_**                |       |\n| - Gallon                 | 2 sp  |\n| - Mug                    | 4 cp  |\n| Banquet (per person)     | 10 gp |\n| Bread, loaf              | 2 cp  |\n| Cheese, hunk             | 1 sp  |\n| **_Inn stay (per day)_** |       |\n| - Squalid                | 7 cp  |\n| - Poor                   | 1 sp  |\n| - Modest                 | 5 sp  |\n| - Comfortable            | 8 sp  |\n| - Wealthy                | 2 gp  |\n| - Aristocratic           | 4 gp  |\n| **_Meals (per day)_**    |       |\n| - Squalid                | 3 cp  |\n| - Poor                   | 6 cp  |\n| - Modest                 | 3 sp  |\n| - Comfortable            | 5 sp  |\n| - Wealthy                | 8 sp  |\n| - Aristocratic           | 2 gp  |\n| Meat, chunk              | 3 sp  |\n| **_Wine_**               |       |\n| - Common (pitcher)       | 2 sp  |\n| - Fine (bottle)          | 10 gp |\n\n## Services\n\nAdventurers can pay nonplayer characters to assist them or act on their behalf in a variety of circumstances. Most such hirelings have fairly ordinary skills, while others are masters of a craft or art, and a few are experts with specialized adventuring skills.\n\nSome of the most basic types of hirelings appear on the Services table. Other common hirelings include any of the wide variety of people who inhabit a typical town or city, when the adventurers pay them to perform a specific task. For example, a wizard might pay a carpenter to construct an elaborate chest (and its miniature replica) for use in the *secret chest* spell. A fighter might commission a blacksmith to forge a special sword. A bard might pay a tailor to make exquisite clothing for an upcoming performance in front of the duke.\n\nOther hirelings provide more expert or dangerous services. Mercenary soldiers paid to help the adventurers take on a hobgoblin army are hirelings, as are sages hired to research ancient or esoteric lore. If a high-level adventurer establishes a stronghold of some kind, he or she might hire a whole staff of servants and agents to run the place, from a castellan or steward to menial laborers to keep the stables clean. These hirelings often enjoy a long-term contract that includes a place to live within the stronghold as part of the offered compensation.\n\nSkilled hirelings include anyone hired to perform a service that involves a proficiency (including weapon, tool, or skill): a mercenary, artisan, scribe, and so on. The pay shown is a minimum; some expert hirelings require more pay. Untrained hirelings are hired for menial work that requires no particular skill and can include laborers, porters, maids, and similar workers.\n\n**Services (table)**\n\n| Service Pay       | Pay           |\n|-------------------|---------------|\n| **_Coach cab_**   |               |\n| - Between towns   | 3 cp per mile |\n| - Within a city   | 1 cp          |\n| **_Hireling_**    |               |\n| - Skilled         | 2 gp per day  |\n| - Untrained       | 2 sp per day  |\n| Messenger         | 2 cp per mile |\n| Road or gate toll | 1 cp          |\n| Ship's passage    | 1 sp per mile |\n\n## Spellcasting Services\n\nPeople who are able to cast spells don't fall into the category of ordinary hirelings. It might be possible to find someone willing to cast a spell in exchange for coin or favors, but it is rarely easy and no established pay rates exist. As a rule, the higher the level of the desired spell, the harder it is to find someone who can cast it and the more it costs.\n\nHiring someone to cast a relatively common spell of 1st or 2nd level, such as *cure wounds* or *identify*, is easy enough in a city or town, and might cost 10 to 50 gold pieces (plus the cost of any expensive material components). Finding someone able and willing to cast a higher-level spell might involve traveling to a large city, perhaps one with a university or prominent temple. Once found, the spellcaster might ask for a service instead of payment-the kind of service that only adventurers can provide, such as retrieving a rare item from a dangerous locale or traversing a monster-infested wilderness to deliver something important to a distant settlement.",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Equipment"
        },
        {
            "slug": "feats",
            "name": "Feats",
            "desc": "A feat represents a talent or an area of expertise that gives a character special capabilities. It embodies training, experience, and abilities beyond what a class provides.\n\nAt certain levels, your class gives you the Ability Score Improvement feature. Using the optional feats rule, you can forgo taking that feature to take a feat of your choice instead. You can take each feat only once, unless the feat’s description says otherwise.\n\nYou must meet any prerequisite specified in a feat to take that feat. If you ever lose a feat’s prerequisite, you can’t use that feat until you regain the prerequisite. For example, the Grappler feat requires you to have a Strength of 13 or higher. If your Strength is reduced below 13 somehow—perhaps by a withering curse—you can’t benefit from the Grappler feat until your Strength is restored.",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Characters"
        },
        {
            "slug": "inspiration",
            "name": "Inspiration",
            "desc": "Inspiration is a rule the game master can use to reward you for playing your character in a way that's true to his or her personality traits, ideal, bond, and flaw. By using inspiration, you can draw on your personality trait of compassion for the downtrodden to give you an edge in negotiating with the Beggar Prince. Or inspiration can let you call on your bond to the defense of your home village to push past the effect of a spell that has been laid on you.\n\n## Gaining Inspiration\n\nYour GM can choose to give you inspiration for a variety of reasons. Typically, GMs award it when you play out your personality traits, give in to the drawbacks presented by a flaw or bond, and otherwise portray your character in a compelling way. Your GM will tell you how you can earn inspiration in the game.\n\nYou either have inspiration or you don't - you can't stockpile multiple “inspirations” for later use.\n\n## Using Inspiration\n\nIf you have inspiration, you can expend it when you make an attack roll, saving throw, or ability check. Spending your inspiration gives you advantage on that roll.\n\nAdditionally, if you have inspiration, you can reward another player for good roleplaying, clever thinking, or simply doing something exciting in the game. When another player character does something that really contributes to the story in a fun and interesting way, you can give up your inspiration to give that character inspiration.",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Characters"
        },
        {
            "slug": "languages",
            "name": "Languages",
            "desc": "Your race indicates the languages your character can speak by default, and your background might give you access to one or more additional languages of your choice. Note these languages on your character sheet.\n\nChoose your languages from the Standard Languages table, or choose one that is common in your campaign. With your GM's permission, you can instead choose a language from the Exotic Languages table or a secret language, such as thieves' cant or the tongue of druids.\n\nSome of these languages are actually families of languages with many dialects. For example, the Primordial language includes the Auran, Aquan, Ignan, and Terran dialects, one for each of the four elemental planes. Creatures that speak different dialects of the same language can communicate with one another.\n\n**Standard Languages (table)**\n\n| Language | Typical Speakers | Script   |\n|----------|------------------|----------|\n| Common   | Humans           | Common   |\n| Dwarvish | Dwarves          | Dwarvish |\n| Elvish   | Elves            | Elvish   |\n| Giant    | Ogres, giants    | Dwarvish |\n| Gnomish  | Gnomes           | Dwarvish |\n| Goblin   | Goblinoids       | Dwarvish |\n| Halfling | Halflings        | Common   |\n| Orc      | Orcs             | Dwarvish |\n\n**Exotic Languages (table)**\n\n| Language    | Typical Speakers    | Script    |\n|-------------|---------------------|-----------|\n| Abyssal     | Demons              | Infernal  |\n| Celestial   | Celestials          | Celestial |\n| Draconic    | Dragons, dragonborn | Draconic  |\n| Deep Speech | Aboleths, cloakers  | -         |\n| Infernal    | Devils              | Infernal  |\n| Primordial  | Elementals          | Dwarvish  |\n| Sylvan      | Fey creatures       | Elvish    |\n| Undercommon | Underworld traders  | Elvish    |",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Characters"
        },
        {
            "slug": "legal-information",
            "name": "Legal Information",
            "desc": "Permission to copy, modify and distribute the files collectively known as the System Reference Document 5.1 (“SRD5”) is granted solely through the use of the Open Gaming License, Version 1.0a.\n\nThis material is being released using the Open Gaming License Version 1.0a and you should read and understand the terms of that license before using this material.\n\nThe text of the Open Gaming License itself is not Open Game Content. Instructions on using the License are provided within the License itself.\n\nThe following items are designated Product Identity, as defined in Section 1(e) of the Open Game License Version 1.0a, and are subject to the conditions set forth in Section 7 of the OGL, and are not Open Content: Dungeons & Dragons, D&D, Player's Handbook, Dungeon Master, Monster Manual, d20 System, Wizards of the Coast, d20 (when used as a trademark), Forgotten Realms, Faerûn, proper names (including those used in the names of spells or items), places, Underdark, Red Wizard of Thay, the City of Union, Heroic Domains of Ysgard, Ever- Changing Chaos of Limbo, Windswept Depths of Pandemonium, Infinite Layers of the Abyss, Tarterian Depths of Carceri, Gray Waste of Hades, Bleak Eternity of Gehenna, Nine Hells of Baator, Infernal Battlefield of Acheron, Clockwork Nirvana of Mechanus, Peaceable Kingdoms of Arcadia, Seven Mounting Heavens of Celestia, Twin Paradises of Bytopia, Blessed Fields of Elysium, Wilderness of the Beastlands, Olympian Glades of Arborea, Concordant Domain of the Outlands, Sigil, Lady of Pain, Book of Exalted Deeds, Book of Vile Darkness, beholder, gauth, carrion crawler, tanar'ri, baatezu, displacer beast, githyanki, githzerai, mind flayer, illithid, umber hulk, yuan-ti.\n\nAll of the rest of the SRD5 is Open Game Content as described in Section 1(d) of the License.\n\nThe terms of the Open Gaming License Version 1.0a are as follows:\n\nOPEN GAME LICENSE Version 1.0a\n\nThe following text is the property of Wizards of the Coast, Inc. and is Copyright 2000 Wizards of the Coast, Inc (\"Wizards\"). All Rights Reserved.\n\n1. Definitions: (a)\"Contributors\" means the copyright and/or trademark owners who have contributed Open Game Content; (b)\"Derivative Material\" means copyrighted material including derivative works and translations (including into other computer languages), potation, modification, correction, addition, extension, upgrade, improvement, compilation, abridgment or other form in which an existing work may be recast, transformed or adapted; (c) \"Distribute\" means to reproduce, license, rent, lease, sell, broadcast, publicly display, transmit or otherwise distribute; (d)\"Open Game Content\" means the game mechanic and includes the methods, procedures, processes and routines to the extent such content does not embody the Product Identity and is an enhancement over the prior art and any additional content clearly identified as Open Game Content by the Contributor, and means any work covered by this License, including translations and derivative works under copyright law, but specifically excludes Product Identity. (e) \"Product Identity\" means product and product line names, logos and identifying marks including trade dress; artifacts; creatures characters; stories, storylines, plots, thematic elements, dialogue, incidents, language, artwork, symbols, designs, depictions, likenesses, formats, poses, concepts, themes and graphic, photographic and other visual or audio representations; names and descriptions of characters, spells, enchantments, personalities, teams, personas, likenesses and special abilities; places, locations, environments, creatures, equipment, magical or supernatural abilities or effects, logos, symbols, or graphic designs; and any other trademark or registered trademark clearly identified as Product identity by the owner of the Product Identity, and which specifically excludes the Open Game Content; (f) \"Trademark\" means the logos, names, mark, sign, motto, designs that are used by a Contributor to identify itself or its products or the associated products contributed to the Open Game License by the Contributor (g) \"Use\", \"Used\" or \"Using\" means to use, Distribute, copy, edit, format, modify, translate and otherwise create Derivative Material of Open Game Content. (h) \"You\" or \"Your\" means the licensee in terms of this agreement.\n\n2. The License: This License applies to any Open Game Content that contains a notice indicating that the Open Game Content may only be Used under and in terms of this License. You must affix such a notice to any Open Game Content that you Use. No terms may be added to or subtracted from this License except as described by the License itself. No other terms or conditions may be applied to any Open Game Content distributed using this License.\n\n3. Offer and Acceptance: By Using the Open Game Content You indicate Your acceptance of the terms of this License.\n\n4. Grant and Consideration: In consideration for agreeing to use this License, the Contributors grant You a perpetual, worldwide, royalty-free, non- exclusive license with the exact terms of this License to Use, the Open Game Content.\n\n5. Representation of Authority to Contribute: If You are contributing original material as Open Game Content, You represent that Your Contributions are Your original creation and/or You have sufficient rights to grant the rights conveyed by this License.\n\n6. Notice of License Copyright: You must update the COPYRIGHT NOTICE portion of this License to include the exact text of the COPYRIGHT NOTICE of any Open Game Content You are copying, modifying or distributing, and You must add the title, the copyright date, and the copyright holder's name to the COPYRIGHT NOTICE of any original Open Game Content you Distribute.\n\n7. Use of Product Identity: You agree not to Use any Product Identity, including as an indication as to compatibility, except as expressly licensed in another, independent Agreement with the owner of each element of that Product Identity. You agree not to indicate compatibility or co-adaptability with any Trademark or Registered Trademark in conjunction with a work containing Open Game Content except as expressly licensed in another, independent Agreement with the owner of such Trademark or Registered Trademark. The use of any Product Identity in Open Game Content does not constitute a challenge to the ownership of that Product Identity. The owner of any Product Identity used in Open Game Content shall retain all rights, title and interest in and to that Product Identity.\n\n8. Identification: If you distribute Open Game Content You must clearly indicate which portions of the work that you are distributing are Open Game Content.\n\n9. Updating the License: Wizards or its designated Agents may publish updated versions of this License. You may use any authorized version of this License to copy, modify and distribute any Open Game Content originally distributed under any version of this License.\n\n10. Copy of this License: You MUST include a copy of this License with every copy of the Open Game Content You Distribute.\n\n11. Use of Contributor Credits: You may not market or advertise the Open Game Content using the name of any Contributor unless You have written permission from the Contributor to do so.\n\n12. Inability to Comply: If it is impossible for You to comply with any of the terms of this License with respect to some or all of the Open Game Content due to statute, judicial order, or governmental regulation then You may not Use any Open Game Material so affected.\n\n13. Termination: This License will terminate automatically if You fail to comply with all terms herein and fail to cure such breach within 30 days of becoming aware of the breach. All sublicenses shall survive the termination of this License.\n\n14. Reformation: If any provision of this License is held to be unenforceable, such provision shall be reformed only to the extent necessary to make it enforceable.\n\n15. COPYRIGHT NOTICE.\n\nOpen Game License v 1.0a Copyright 2000, Wizards of the Coast, Inc.\n\nSystem Reference Document 5.0 Copyright 2016, Wizards of the Coast, Inc.; Authors Mike Mearls, Jeremy Crawford, Chris Perkins, Rodney Thompson, Peter Lee, James Wyatt, Robert J. Schwalb, Bruce R. Cordell, Chris Sims, and Steve Townshend, based on original material by E. Gary Gygax and Dave Arneson.\n\nEND OF LICENSE\n",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Legal Information"
        },
        {
            "slug": "leveling-up",
            "name": "Leveling Up",
            "desc": "As your character goes on adventures and overcomes challenges, he or she gains experience, represented by experience points. A character who reaches a specified experience point total advances in capability. This advancement is called **gaining a level**.\n\nWhen your character gains a level, his or her class often grants additional features, as detailed in the class description. Some of these features allow you to increase your ability scores, either increasing two scores by 1 each or increasing one score by 2. You can't increase an ability score above 20. In addition, every character's proficiency bonus increases at certain levels.\n\nEach time you gain a level, you gain 1 additional Hit Die. Roll that Hit Die, add your Constitution modifier to the roll, and add the total to your hit point maximum. Alternatively, you can use the fixed value shown in your class entry, which is the average result of the die roll (rounded up).\n\nWhen your Constitution modifier increases by 1, your hit point maximum increases by 1 for each level you have attained. For example, if your 7th-level fighter has a Constitution score of 18, when he reaches 8th level, he increases his Constitution score from 17 to 18, thus increasing his Constitution modifier from +3 to +4. His hit point maximum then increases by 8.\n\nThe Character Advancement table summarizes the XP you need to advance in levels from level 1 through level 20, and the proficiency bonus for a character of that level. Consult the information in your character's class description to see what other improvements you gain at each level.\n\n**Character Advancement (table)**\n\n| Experience Points | Level | Proficiency Bonus |\n|-------------------|-------|-------------------|\n| 0                 | 1     | +2                |\n| 300               | 2     | +2                |\n| 900               | 3     | +2                |\n| 2,700             | 4     | +2                |\n| 6,500             | 5     | +3                |\n| 14,000            | 6     | +3                |\n| 23,000            | 7     | +3                |\n| 34,000            | 8     | +3                |\n| 48,000            | 9     | +4                |\n| 64,000            | 10    | +4                |\n| 85,000            | 11    | +4                |\n| 100,000           | 12    | +4                |\n| 120,000           | 13    | +5                |\n| 140,000           | 14    | +5                |\n| 165,000           | 15    | +5                |\n| 195,000           | 16    | +5                |\n| 225,000           | 17    | +6                |\n| 265,000           | 18    | +6                |\n| 305,000           | 19    | +6                |\n| 355,000           | 20    | +6                |",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Character Advancement"
        },
        {
            "slug": "madness",
            "name": "Madness",
            "desc": "In a typical campaign, characters aren't driven mad by the horrors they face and the carnage they inflict day after day, but sometimes the stress of being an adventurer can be too much to bear. If your campaign has a strong horror theme, you might want to use madness as a way to reinforce that theme, emphasizing the extraordinarily horrific nature of the threats the adventurers face.\n\n## Going Mad\n\nVarious magical effects can inflict madness on an otherwise stable mind. Certain spells, such as _contact other plane_ and _symbol_, can cause insanity, and you can use the madness rules here instead of the spell effects of those spells*.* Diseases, poisons, and planar effects such as psychic wind or the howling winds of Pandemonium can all inflict madness. Some artifacts can also break the psyche of a character who uses or becomes attuned to them.\n\nResisting a madness-inducing effect usually requires a Wisdom or Charisma saving throw.\n\n## Madness Effects\n\nMadness can be short-term, long-term, or indefinite. Most relatively mundane effects impose short-term madness, which lasts for just a few minutes. More horrific effects or cumulative effects can result in long-term or indefinite madness.\n\nA character afflicted with **short-term madness** is subjected to an effect from the Short-Term Madness table for 1d10 minutes.\n\nA character afflicted with **long-term madness** is subjected to an effect from the Long-Term Madness table for 1d10 × 10 hours.\n\nA character afflicted with **indefinite madness** gains a new character flaw from the Indefinite Madness table that lasts until cured.\n\n**Short-Term Madness (table)**\n| d100   | Effect (lasts 1d10 minutes)                                                                                                  |\n|--------|------------------------------------------------------------------------------------------------------------------------------|\n| 01-20  | The character retreats into his or her mind and becomes paralyzed. The effect ends if the character takes any damage.        |\n| 21-30  | The character becomes incapacitated and spends the duration screaming, laughing, or weeping.                                 |\n| 31-40  | The character becomes frightened and must use his or her action and movement each round to flee from the source of the fear. |\n| 41-50  | The character begins babbling and is incapable of normal speech or spellcasting.                                             |\n| 51-60  | The character must use his or her action each round to attack the nearest creature.                                          |\n| 61-70  | The character experiences vivid hallucinations and has disadvantage on ability checks.                                       |\n| 71-75  | The character does whatever anyone tells him or her to do that isn't obviously self- destructive.                            |\n| 76-80  | The character experiences an overpowering urge to eat something strange such as dirt, slime, or offal.                       |\n| 81-90  | The character is stunned.                                                                                                    |\n| 91-100 | The character falls unconscious.                                                                                             |\n\n**Long-Term Madness (table)**\n| d100   | Effect (lasts 1d10 × 10 hours)                                                                                                                                                                                                       |\n|--------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|\n| 01-10  | The character feels compelled to repeat a specific activity over and over, such as washing hands, touching things, praying, or counting coins.                                                                                       |\n| 11-20  | The character experiences vivid hallucinations and has disadvantage on ability checks.                                                                                                                                               |\n| 21-30  | The character suffers extreme paranoia. The character has disadvantage on Wisdom and Charisma checks.                                                                                                                                |\n| 31-40  | The character regards something (usually the source of madness) with intense revulsion, as if affected by the antipathy effect of the antipathy/sympathy spell.                                                                      |\n| 41-45  | The character experiences a powerful delusion. Choose a potion. The character imagines that he or she is under its effects.                                                                                                          |\n| 46-55  | The character becomes attached to a “lucky charm,” such as a person or an object, and has disadvantage on attack rolls, ability checks, and saving throws while more than 30 feet from it.                                           |\n| 56-65  | The character is blinded (25%) or deafened (75%).                                                                                                                                                                                    |\n| 66-75  | The character experiences uncontrollable tremors or tics, which impose disadvantage on attack rolls, ability checks, and saving throws that involve Strength or Dexterity.                                                           |\n| 76-85  | The character suffers from partial amnesia. The character knows who he or she is and retains racial traits and class features, but doesn't recognize other people or remember anything that happened before the madness took effect. |\n| 86-90  | Whenever the character takes damage, he or she must succeed on a DC 15 Wisdom saving throw or be affected as though he or she failed a saving throw against the confusion spell. The confusion effect lasts for 1 minute.            |\n| 91-95  | The character loses the ability to speak.                                                                                                                                                                                            |\n| 96-100 | The character falls unconscious. No amount of jostling or damage can wake the character.                                                                                                                                             |\n\n**Indefinite Madness (table)**\n| d100   | Flaw (lasts until cured)                                                                                                                 |\n|--------|------------------------------------------------------------------------------------------------------------------------------------------|\n| 01-15  | “Being drunk keeps me sane.”                                                                                                             |\n| 16-25  | “I keep whatever I find.”                                                                                                                |\n| 26-30  | “I try to become more like someone else I know-adopting his or her style of dress, mannerisms, and name.”                                |\n| 31-35  | “I must bend the truth, exaggerate, or outright lie to be interesting to other people.”                                                  |\n| 36-45  | “Achieving my goal is the only thing of interest to me, and I'll ignore everything else to pursue it.”                                   |\n| 46-50  | “I find it hard to care about anything that goes on around me.”                                                                          |\n| 51-55  | “I don't like the way people judge me all the time.”                                                                                     |\n| 56-70  | “I am the smartest, wisest, strongest, fastest, and most beautiful person I know.”                                                       |\n| 71-80  | “I am convinced that powerful enemies are hunting me, and their agents are everywhere I go. I am sure they're watching me all the time.” |\n| 81-85  | “There's only one person I can trust. And only I can see this special friend.”                                                           |\n| 86-95  | “I can't take anything seriously. The more serious the situation, the funnier I find it.”                                                |\n| 96-100 | “I've discovered that I really like killing people.”                                                                                     |\n## Curing Madness\n\nA _calm emotions_ spell can suppress the effects of madness, while a _lesser restoration_ spell can rid a character of a short-term or long-term madness. Depending on the source of the madness, _remove curse_ or _dispel evil_ might also prove effective. A _greater restoration_ spell or more powerful magic is required to rid a character of indefinite madness.\n\n",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Rules"
        },
        {
            "slug": "magic-items",
            "name": "Magic Items",
            "desc": "Magic items are gleaned from the hoards of conquered monsters or discovered in long-lost vaults. Such items grant capabilities a character could rarely have otherwise, or they complement their owner’s capabilities in wondrous ways.\n\n# Attunement\n\nSome magic items require a creature to form a bond with them before their magical properties can be used. This bond is called attunement, and certain items have a prerequisite for it. If the prerequisite is a class, a creature must be a member of that class to attune to the item. (If the class is a spellcasting class, a monster qualifies if it has spell slots and uses that class’s spell list.) If the prerequisite is to be a spellcaster, a creature qualifies if it can cast at least one spell using its traits or features, not using a magic item or the like.\n\nWithout becoming attuned to an item that requires attunement, a creature gains only its nonmagical benefits, unless its description states otherwise. For example, a magic shield that requires attunement provides the benefits of a normal shield to a creature not attuned to it, but none of its magical properties.\n\nAttuning to an item requires a creature to spend a short rest focused on only that item while being in physical contact with it (this can’t be the same short rest used to learn the item’s properties). This focus can take the form of weapon practice (for a weapon), meditation (for a wondrous item), or some other appropriate activity. If the short rest is interrupted, the attunement attempt fails. Otherwise, at the end of the short rest, the creature gains an intuitive understanding of how to activate any magical properties of the item, including any necessary command words.\n\nAn item can be attuned to only one creature at a time, and a creature can be attuned to no more than three magic items at a time. Any attempt to attune to a fourth item fails; the creature must end its attunement to an item first. Additionally, a creature can’t attune to more than one copy of an item. For example, a creature can’t attune to more than one *ring of protection* at a time.\n\nA creature’s attunement to an item ends if the creature no longer satisfies the prerequisites for attunement, if the item has been more than 100 feet away for at least 24 hours, if the creature dies, or if another creature attunes to the item. A creature can also voluntarily end attunement by spending another short rest focused on the item, unless the item is cursed.\n\n# Wearing and Wielding Items\n\nUsing a magic item’s properties might mean wearing or wielding it. A magic item meant to be worn must be donned in the intended fashion: boots go on the feet, gloves on the hands, hats and helmets on the head, and rings on the finger. Magic armor must be donned, a shield strapped to the arm, a cloak fastened about the shoulders. A weapon must be held.\n\nIn most cases, a magic item that’s meant to be worn can fit a creature regardless of size or build. Many magic garments are made to be easily adjustable, or they magically adjust themselves to the wearer. Rare exceptions exist. If the story suggests a good reason for an item to fit only creatures of a certain size or shape, you can rule that it doesn’t adjust. For example, drow-made armor might fit elves only. Dwarves might make items usable only by dwarf-sized and dwarf-shaped folk.\n\nWhen a nonhumanoid tries to wear an item, use your discretion as to whether the item functions as intended. A ring placed on a tentacle might work, but a yuan-ti with a snakelike tail instead of legs can’t wear boots.\n\n## Multiple Items of the Same Kind\n\nUse common sense to determine whether more than one of a given kind of magic item can be worn. A character can’t normally wear more than one pair of footwear, one pair of gloves or gauntlets, one pair of bracers, one suit of armor, one item of headwear, and one cloak. You can make exceptions; a character might be able to wear a circlet under a helmet, for example, or to layer two cloaks.\n\n## Paired Items\n\nItems that come in pairs—such as boots, bracers, gauntlets, and gloves—impart their benefits only if both items of the pair are worn. For example, a character wearing a boot of striding and springing on one foot and a boot of elvenkind on the other foot gains no benefit from either.\n\n# Activating an Item\n\nActivating some magic items requires a user to do something special, such as holding the item and uttering a command word. The description of each item category or individual item details how an item is activated. Certain items use the following rules for their activation.\n\nIf an item requires an action to activate, that action isn’t a function of the Use an Item action, so a feature such as the rogue’s Fast Hands can’t be used to activate the item.\n\n## Command Word\n\nA command word is a word or phrase that must be spoken for an item to work. A magic item that requires a command word can’t be activated in an area where sound is prevented, as in the area of the silence spell.\n\n## Consumables\n\nSome items are used up when they are activated. A potion or an elixir must be swallowed, or an oil applied to the body. The writing vanishes from a scroll when it is read. Once used, a consumable item loses its magic.\n\n## Spells\n\nSome magic items allow the user to cast a spell from the item. The spell is cast at the lowest possible spell level, doesn’t expend any of the user’s spell slots, and requires no components, unless the item’s description says otherwise. The spell uses its normal casting time, range, and duration, and the user of the item must concentrate if the spell requires concentration. Many items, such as potions, bypass the casting of a spell and confer the spell’s effects, with their usual duration. Certain items make exceptions to these rules, changing the casting time, duration, or other parts of a spell.\n\nA magic item, such as certain staffs, may require you to use your own spellcasting ability when you cast a spell from the item. If you have more than one spellcasting ability, you choose which one to use with the item. If you don’t have a spellcasting ability—perhaps you’re a rogue with the Use Magic Device feature—your spellcasting ability modifier is +0 for the item, and your proficiency bonus does apply.\n\n## Charges\n\nSome magic items have charges that must be expended to activate their properties. The number of charges an item has remaining is revealed when an identify spell is cast on it, as well as when a creature attunes to it. Additionally, when an item regains charges, the creature attuned to it learns how many charges it regained.\n\n# Sentient Magic Items\n\nSome magic items possess sentience and personality. Such an item might be possessed, haunted by the spirit of a previous owner, or self-aware thanks to the magic used to create it. In any case, the item behaves like a character, complete with personality quirks, ideals, bonds, and sometimes flaws. A sentient item might be a cherished ally to its wielder or a continual thorn in the side.\n\nMost sentient items are weapons. Other kinds of items can manifest sentience, but consumable items such as potions and scrolls are never sentient.\n\nSentient magic items function as NPCs under the GM’s control. Any activated property of the item is under the item’s control, not its wielder’s. As long as the wielder maintains a good relationship with the item, the wielder can access those properties normally. If the relationship is strained, the item can suppress its activated properties or even turn them against the wielder.\n\n## Creating Sentient Magic Items\n\nWhen you decide to make a magic item sentient, you create the item’s persona in the same way you would create an NPC, with a few exceptions described here.\n\n### Abilities\n\nA sentient magic item has Intelligence, Wisdom, and Charisma scores. You can choose the item’s abilities or determine them randomly. To determine them randomly, roll 4d6 for each one, dropping the lowest roll and totaling the rest.\n\n### Communication\n\nA sentient item has some ability to communicate, either by sharing its emotions, broadcasting its thoughts telepathically, or speaking aloud. You can choose how it communicates or roll on the following table.\n\n| d100 | Communication |\n|--------|-----------------------|\n| 01–60 | The item communicates by transmitting emotion to the creature carrying or wielding it. |\n| 61–90 | The item can speak, read, and understand one or more languages. |\n|  91–00 | The item can speak, read, and understand one or more languages. In addition, the item can communicate telepathically with any character that carries or wields it. |\n\n### Senses\n\nWith sentience comes awareness. A sentient item can perceive its surroundings out to a limited range. You can choose its senses or roll on the following table.\n\n| d4 | Senses |\n|-----|------------|\n| 1 | Hearing and normal vision out to 30 feet. |\n| 2  | Hearing and normal vision out to 60 feet |\n| 3 | Hearing and normal vision out to 120 feet. |\n| 4 | Hearing and darkvision out to 120 feet. |\n\n### Alignment\n\nA sentient magic item has an alignment. Its creator or nature might suggest an alignment. If not, you can pick an alignment or roll on the following table.\n\n| d100 | Alignment |\n|--------|---------------|\n| 01–15 | Lawful good |\n| 16–35 | Neutral good |\n| 36–50 | Chaotic good |\n| 51–63 | Lawful neutral |\n| 64–73 | Neutral |\n| 74–85 | Chaotic neutral |\n| 86–89 | Lawful evil |\n| 90–96 | Neutral evil |\n| 97–00 | Chaotic evil |\n\n### Special Purpose\n\nYou can give a sentient item an objective it pursues, perhaps to the exclusion of all else. As long as the wielder’s use of the item aligns with that special purpose, the item remains cooperative. Deviating from this course might cause conflict between the wielder and the item, and could even cause the item to prevent the use of its activated properties. You can pick a special purpose or roll on the following table.\n\n| d10 | Purpose |\n|-------|-------------|\n| 1 | *Aligned:* The item seeks to defeat or destroy those of a diametrically opposed alignment. (Such an item is never neutral.) |\n| 2 | *Bane:* The item seeks to defeat or destroy creatures of a particular kind, such as fiends, shapechangers, trolls, or wizards. |\n| 3 | *Protector:* The item seeks to defend a particular race or kind of creature, such as elves or druids. |\n| 4 | *Crusader:* The item seeks to defeat, weaken, or destroy the servants of a particular deity. |\n| 5 | *Templar:* The item seeks to defend the servants and interests of a particular deity. |\n| 6 | *Destroyer:* The item craves destruction and goads its user to fight arbitrarily. |\n| 7 | *Glory Seeker:* The item seeks renown as the greatest magic item in the world, by establishing its user as a famous or notorious figure. |\n| 8 | *Lore Seeker:* The item craves knowledge or is determined to solve a mystery, learn a secret, or unravel a cryptic prophecy. |\n| 9 | *Destiny Seeker:* The item is convinced that it and its wielder have key roles to play in future events. |\n| 10 | *Creator Seeker:* The item seeks its creator and wants to understand why it was created. |\n\n## Conflict\n\nA sentient item has a will of its own, shaped by its personality and alignment. If its wielder acts in a manner opposed to the item’s alignment or purpose, conflict can arise. When such a conflict occurs, the item makes a Charisma check contested by the wielder’s Charisma check. If the item wins the contest, it makes one or more of the following demands:\n\n* The item insists on being carried or worn at all times.\n* The item demands that its wielder dispose of anything the item finds repugnant.\n* The item demands that its wielder pursue the item’s goals to the exclusion of all other goals.\n* The item demands to be given to someone else.\n\nIf its wielder refuses to comply with the item’s wishes, the item can do any or all of the following:\n\n* Make it impossible for its wielder to attune to it.\n* Suppress one or more of its activated properties.\n* Attempt to take control of its wielder.\n\nIf a sentient item attempts to take control of its wielder, the wielder must make a Charisma saving throw, with a DC equal to 12 + the item’s Charisma modifier. On a failed save, the wielder is charmed by the item for 1d12 hours. While charmed, the wielder must try to follow the item’s commands. If the wielder takes damage, it can repeat the saving throw, ending the effect on a success. Whether the attempt to control its user succeeds or fails, the item can’t use this power again until the next dawn.",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Rules"
        },
        {
            "slug": "monsters",
            "name": "Monsters",
            "desc": "A monster’s statistics, sometimes referred to as its **stat block**, provide the essential information that you need to run the monster.\n\n## Size\n\nA monster can be Tiny, Small, Medium, Large, Huge, or Gargantuan. The Size Categories table shows how much space a creature of a particular size controls in combat. See the *Player’s Handbook* for more information on creature size and space.\n\n### Size Categories\n\n| Size | Space | Examples |\n|--------|----------|---------------|\n| Tiny | 2½ by 2½ ft. | Imp, sprite |\n| Small | 5 b 5 ft. | Giant rat, goblin |\n| Medium | 5 b 5 ft. | Orc, werewolf |\n| Large | 10 b 10 ft. | Hippogriff, ogre |\n| Huge | 15 b 15 ft. | Fire giant, treant |\n| Gargantuan | 20 b 20 ft. or larger | Kraken, purple worm |\n\n#### Modifying Creatures\n\nDespite the versatile collection of monsters in this book, you might be at a loss when it comes to finding the perfect creature for part of an adventure. Feel free to tweak an existing creature to make it into something more useful for you, perhaps by borrowing a trait or two from a different monster or by using a variant or template, such as the ones in this book. Keep in mind that modifying a monster, including when you apply a template to it, might change its challenge rating.\n\n## Type\n\nA monster’s type speaks to its fundamental nature. Certain spells, magic items, class features, and other effects in the game interact in special ways with creatures of a particular type. For example, an *arrow of dragon slaying* deals extra damage not only to dragons but also other creatures of the dragon type, such as dragon turtles and wyverns.\n\nThe game includes the following monster types, which have no rules of their own.\n\n**Aberrations** are utterly alien beings. Many of them have innate magical abilities drawn from the creature’s alien mind rather than the mystical forces of the world. The quintessential aberrations are aboleths, beholders, mind flayers, and slaadi.\n\n**Beasts** are nonhumanoid creatures that are a natural part of the fantasy ecology. Some of them have magical powers, but most are unintelligent and lack any society or language. Beasts include all varieties of ordinary animals, dinosaurs, and giant versions of animals.\n\n**Celestials** are creatures native to the Upper Planes. Many of them are the servants of deities, employed as messengers or agents in the mortal realm and throughout the planes. Celestials are good by nature, so the exceptional celestial who strays from a good alignment is a horrifying rarity. Celestials include angels, couatls, and pegasi.\n\n**Constructs** are made, not born. Some are programmed by their creators to follow a simple set of instructions, while others are imbued with sentience and capable of independent thought. Golems are the iconic constructs. Many creatures native to the outer plane of Mechanus, such as modrons, are constructs shaped from the raw material of the plane by the will of more powerful creatures.\n\n**Dragons** are large reptilian creatures of ancient origin and tremendous power. True dragons, including the good metallic dragons and the evil chromatic dragons, are highly intelligent and have innate magic. Also in this category are creatures distantly related to true dragons, but less powerful, less intelligent, and less magical, such as wyverns and pseudodragons.\n\n**Elementals** are creatures native to the elemental planes. Some creatures of this type are little more than animate masses of their respective elements, including the creatures simply called elementals. Others have biological forms infused with elemental energy. The races of genies, including djinn and efreet, form the most important civilizations on the elemental planes. Other elemental creatures include azers and invisible stalkers.\n\n**Fey** are magical creatures closely tied to the forces of nature. They dwell in twilight groves and misty forests. In some worlds, they are closely tied to the Feywild, also called the Plane of Faerie. Some are also found in the Outer Planes, particularly the planes of Arborea and the Beastlands. Fey include dryads, pixies, and satyrs.\n\n**Fiends** are creatures of wickedness that are native to the Lower Planes. A few are the servants of deities, but many more labor under the leadership of archdevils and demon princes. Evil priests and mages sometimes summon fiends to the material world to do their bidding. If an evil celestial is a rarity, a good fiend is almost inconceivable. Fiends include demons, devils, hell hounds, rakshasas, and yugoloths.\n\n**Giants** tower over humans and their kind. They are humanlike in shape, though some have multiple heads (ettins) or deformities (fomorians). The six varieties of true giant are hill giants, stone giants, frost giants, fire giants, cloud giants, and storm giants. Besides these, creatures such as ogres and trolls are giants.\n\n**Humanoids** are the main peoples of a fantasy gaming world, both civilized and savage, including humans and a tremendous variety of other species. They have language and culture, few if any innate magical abilities (though most humanoids can learn spellcasting), and a bipedal form. The most common humanoid races are the ones most suitable as player characters: humans, dwarves, elves, and halflings. Almost as numerous but far more savage and brutal, and almost uniformly evil, are the races of goblinoids (goblins, hobgoblins, and bugbears), orcs, gnolls, lizardfolk, and kobolds.\n\n**Monstrosities** are monsters in the strictest sense—frightening creatures that are not ordinary, not truly natural, and almost never benign. Some are the results of magical experimentation gone awry (such as owlbears), and others are the product of terrible curses (including minotaurs and yuan-ti). They defy categorization, and in some sense serve as a catch-all category for creatures that don’t fit into any other type.\n\n**Oozes** are gelatinous creatures that rarely have a fixed shape. They are mostly subterranean, dwelling in caves and dungeons and feeding on refuse, carrion, or creatures unlucky enough to get in their way. Black puddings and gelatinous cubes are among the most recognizable oozes.\n\n**Plants** in this context are vegetable creatures, not ordinary flora. Most of them are ambulatory, and some are carnivorous. The quintessential plants are the shambling mound and the treant. Fungal creatures such as the gas spore and the myconid also fall into this category.\n\n**Undead** are once-living creatures brought to a horrifying state of undeath through the practice of necromantic magic or some unholy curse. Undead include walking corpses, such as vampires and zombies, as well as bodiless spirits, such as ghosts and specters.\n\n### Tags\nA monster might have one or more tags appended to its type, in parentheses. For example, an orc has the *humanoid (orc)* type. The parenthetical tags provide additional categorization for certain creatures. The tags have no rules of their own, but something in the game, such as a magic item, might refer to them. For instance, a spear that is especially effective at fighting demons would work against any monster that has the demon tag.\n\n## Alignment\n\nA monster’s alignment provides a clue to its disposition and how it behaves in a roleplaying or combat situation. For example, a chaotic evil monster might be difficult to reason with and might attack characters on sight, whereas a neutral monster might be willing to negotiate. See the *Player’s Handbook* for descriptions of the different alignments.\n\nThe alignment specified in a monster’s stat block is the default. Feel free to depart from it and change a monster’s alignment to suit the needs of your campaign. If you want a good-aligned green dragon or an evil storm giant, there’s nothing stopping you.\n\nSome creatures can have **any alignment**. In other words, you choose the monster’s alignment. Some monster’s alignment entry indicates a tendency or aversion toward law, chaos, good, or evil. For example, a berserker can be any chaotic alignment (chaotic good, chaotic neutral, or chaotic evil), as befits its wild nature.\n\nMany creatures of low intelligence have no comprehension of law or chaos, good or evil. They don’t make moral or ethical choices, but rather act on instinct. These creatures are **unaligned**, which means they don’t have an alignment.\n\n## Armor Class\n\nA monster that wears armor or carries a shield has an Armor Class (AC) that takes its armor, shield, and Dexterity into account. Otherwise, a monster’s AC is based on its Dexterity modifier and natural armor, if any. If a monster has natural armor, wears armor, or carries a shield, this is noted in parentheses after its AC value.\n\n## Hit Points\n\nA monster usually dies or is destroyed when it drops to 0 hit points. For more on hit points, see the *Player’s Handbook*.\n\nA monster’s hit points are presented both as a die expression and as an average number. For example, a monster with 2d8 hit points has 9 hit points on average (2 × 4½).\n\nA monster’s size determines the die used to calculate its hit points, as shown in the Hit Dice by Size table.\n\n### Hit Dice by Size\n\n| Monster Size | Hit Die | Average HP per Die |\n|-------------------|-----------|----------------------------|\n| Tiny | d4 | 2½ |\n| Small | d6 | 3½ |\n| Medium | d8 | 4½ |\n| Large | d10 | 5½ |\n| Huge | d12 | 6½ |\n| Gargantuan | d20 | 10½ |\n\nA monster’s Constitution modifier also affects the number of hit points it has. Its Constitution modifier is multiplied by the number of Hit Dice it possesses, and the result is added to its hit points. For example, if a monster has a Constitution of 12 (+1 modifier) and 2d8 Hit Dice, it has 2d8 + 2 hit points (average 11).\n\n## Speed\n\nA monster’s speed tells you how far it can move on its turn. For more information on speed, see the *Player’s Handbook*.\n\nAll creatures have a walking speed, simply called the monster’s speed. Creatures that have no form of ground-based locomotion have a walking speed of 0 feet.\n\nSome creatures have one or more of the following additional movement modes.\n\n### Burrow\n\nA monster that has a burrowing speed can use that speed to move through sand, earth, mud, or ice. A monster can’t burrow through solid rock unless it has a special trait that allows it to do so.\n\n### Climb\n\nA monster that has a climbing speed can use all or part of its movement to move on vertical surfaces. The monster doesn’t need to spend extra movement to climb.\n\n### Fly\n\nA monster that has a flying speed can use all or part of its movement to fly. Some monsters have the ability to hover, which makes them hard to knock out of the air (as explained in the rules on flying in the *Player’s Handbook*). Such a monster stops hovering when it dies.\n\n### Swim\n\nA monster that has a swimming speed doesn’t need to spend extra movement to swim.\n\n## Ability Scores\n\nEvery monster has six ability scores (Strength, Dexterity, Constitution, Intelligence, Wisdom, and Charisma) and corresponding modifiers. For more information on ability scores and how they’re used in play, see the *Player’s Handbook*.\n\n## Saving Throws\n\nThe Saving Throws entry is reserved for creatures that are adept at resisting certain kinds of effects. For example, a creature that isn’t easily charmed or frightened might gain a bonus on its Wisdom saving throws. Most creatures don’t have special saving throw bonuses, in which case this section is absent.\n\nA saving throw bonus is the sum of a monster’s relevant ability modifier and its proficiency bonus, which is determined by the monster’s challenge rating (as shown in the Proficiency Bonus by Challenge Rating table).\n\n### Proficiency Bonus by Challenge Rating\n\n| Challenge | Proficiency Bonus |\n|---------------|--------------------------|\n| 0 | +2 |\n| ⅛ | +2 |\n| ¼ | +2 |\n| ½ |+2 |\n| 1 | +2 |\n| 2 | +2 |\n| 3 | +2 |\n| 4 | +2 |\n| 5 | +3 |\n| 6 | +3 |\n| 7 | +3 |\n| 8 | +3 |\n| 9 | +4 |\n| 10 | +4 |\n| 11 | +4 |\n| 12 | +4 |\n| 13 | +5 |\n| 14 | +5 |\n| 15 | +5 |\n| 16 | +5 |\n| 17 | +6 |\n| 18 | +6 |\n| 19 | +6 |\n| 20 | +6 |\n| 21 | +7 |\n| 22 | +7 |\n| 23 | +7 |\n| 24 | +7 |\n| 25 | +8 |\n| 26 | +8 |\n| 27 | +8 |\n| 28 | +8 |\n| 29 | +9 |\n| 30 | +9 |\n\n## Skills\n\nThe Skills entry is reserved for monsters that are proficient in one or more skills. For example, a monster that is very perceptive and stealthy might have bonuses to Wisdom (Perception) and Dexterity (Stealth) checks.\n\nA skill bonus is the sum of a monster’s relevant ability modifier and its proficiency bonus, which is determined by the monster’s challenge rating (as shown in the Proficiency Bonus by Challenge Rating table). Other modifiers might apply. For instance, a monster might have a larger-than-expected bonus (usually double its proficiency bonus) to account for its heightened expertise.\n\n### Armor, Weapon, and Tool Proficiencies\n\nAssume that a creature is proficient with its armor, weapons, and tools. If you swap them out, you decide whether the creature is proficient with its new equipment.\n\nFor example, a hill giant typically wears hide armor and wields a greatclub. You could equip a hill giant with chain mail and a greataxe instead, and assume the giant is proficient with both, one or the other, or neither.\n\nSee the *Player’s Handbook* for rules on using armor or weapons without proficiency.\n\n## Vulnerabilities, Resistances, and Immunities\n\nSome creatures have vulnerability, resistance, or immunity to certain types of damage. Particular creatures are even resistant or immune to damage from nonmagical attacks (a magical attack is an attack delivered by a spell, a magic item, or another magical source). In addition, some creatures are immune to certain conditions.\n\n## Senses\n\nThe Senses entry notes a monster’s passive Wisdom (Perception) score, as well as any special senses the monster might have. Special senses are described below.\n\n### Blindsight\n\nA monster with blindsight can perceive its surroundings without relying on sight, within a specific radius.\n\nCreatures without eyes, such as grimlocks and gray oozes, typically have this special sense, as do creatures with echolocation or heightened senses, such as bats and true dragons.\n\nIf a monster is naturally blind, it has a parenthetical note to this effect, indicating that the radius of its blindsight defines the maximum range of its perception.\n\n### Darkvision\n\nA monster with darkvision can see in the dark within a specific radius. The monster can see in dim light within the radius as if it were bright light, and in darkness as if it were dim light. The monster can’t discern color in darkness, only shades of gray. Many creatures that live underground have this special sense.\n\n### Tremorsense\n\nA monster with tremorsense can detect and pinpoint the origin of vibrations within a specific radius, provided that the monster and the source of the vibrations are in contact with the same ground or substance. Tremorsense can’t be used to detect flying or incorporeal creatures. Many burrowing creatures, such as ankhegs and umber hulks, have this special sense.\n\n### Truesight\n\nA monster with truesight can, out to a specific range, see in normal and magical darkness, see invisible creatures and objects, automatically detect visual illusions and succeed on saving throws against them, and perceive the original form of a shapechanger or a creature that is transformed by magic. Furthermore, the monster can see into the Ethereal Plane within the same range.\n\n## Languages\n\nThe languages that a monster can speak are listed in alphabetical order. Sometimes a monster can understand a language but can’t speak it, and this is noted in its entry. A \"—\" indicates that a creature neither speaks nor understands any language.\n\n### Telepathy\n\nTelepathy is a magical ability that allows a monster to communicate mentally with another creature within a specified range. The contacted creature doesn’t need to share a language with the monster to communicate in this way with it, but it must be able to understand at least one language. A creature without telepathy can receive and respond to telepathic messages but can’t initiate or terminate a telepathic conversation.\n\nA telepathic monster doesn’t need to see a contacted creature and can end the telepathic contact at any time. The contact is broken as soon as the two creatures are no longer within range of each other or if the telepathic monster contacts a different creature within range. A telepathic monster can initiate or terminate a telepathic conversation without using an action, but while the monster is incapacitated, it can’t initiate telepathic contact, and any current contact is terminated.\n\nA creature within the area of an *antimagic field* or in any other location where magic doesn’t function can’t send or receive telepathic messages.\n\n## Challenge\n\nA monster’s **challenge rating** tells you how great a threat the monster is. An appropriately equipped and well-rested party of four adventurers should be able to defeat a monster that has a challenge rating equal to its level without suffering any deaths. For example, a party of four 3rd-level characters should find a monster with a challenge rating of 3 to be a worthy challenge, but not a deadly one.\n\nMonsters that are significantly weaker than 1st-level characters have a challenge rating lower than 1. Monsters with a challenge rating of 0 are insignificant except in large numbers; those with no effective attacks are worth no experience points, while those that have attacks are worth 10 XP each.\n\nSome monsters present a greater challenge than even a typical 20th-level party can handle. These monsters have a challenge rating of 21 or higher and are specifically designed to test player skill.\n\n### Experience Points\n\nThe number of experience points (XP) a monster is worth is based on its challenge rating. Typically, XP is awarded for defeating the monster, although the GM may also award XP for neutralizing the threat posed by the monster in some other manner.\n\nUnless something tells you otherwise, a monster summoned by a spell or other magical ability is worth the XP noted in its stat block.\n\n#### Experience Points by Challenge Rating\n\n| Challenge | XP |\n|---------------|------|\n| 0 | 0 or 10 |\n| ⅛ | 25 |\n| ¼ | 50 |\n| ½ |100 |\n| 1 | 200 |\n| 2 | 450 |\n| 3 | 700 |\n| 4 | 1,100 |\n| 5 | 1,800 |\n| 6 | 2,300 |\n| 7 | 2,900 |\n| 8 | 3,900 |\n| 9 | 5,000 |\n| 10 | 5,900 |\n| 11 | 7,200 |\n| 12 | 8,400 |\n| 13 | 10,000 |\n| 14 | 11,500 |\n| 15 | 13,000 |\n| 16 | 15,000 |\n| 17 | 18,000 |\n| 18 | 20,000 |\n| 19 | 22,000 |\n| 20 | 25,000 |\n| 21 | 33,000 |\n| 22 | 41,000 |\n| 23 | 50,000 |\n| 24 | 62,000 |\n| 25 | 75,000 |\n| 26 | 90,000 |\n| 27 | 105,000 |\n| 28 | 120,000 |\n| 29 | 135,000 |\n| 30 | 155,000 |\n\n## Special Traits\nSpecial traits (which appear after a monster’s challenge rating but before any actions or reactions) are characteristics that are likely to be relevant in a combat encounter and that require some explanation.\n\n### Innate Spellcasting\n\nA monster with the innate ability to cast spells has the Innate Spellcasting special trait. Unless noted otherwise, an innate spell of 1st level or higher is always cast at its lowest possible level and can’t be cast at a higher level. If a monster has a cantrip where its level matters and no level is given, use the monster’s challenge rating.\n\nAn innate spell can have special rules or restrictions. For example, a drow mage can innately cast the *levitate* spell, but the spell has a “self only” restriction, which means that the spell affects only the drow mage.\n\nA monster’s innate spells can’t be swapped out with other spells. If a monster’s innate spells don’t require attack rolls, no attack bonus is given for them.\n\n### Spellcasting\n\nA monster with the Spellcasting special trait has a spellcaster level and spell slots, which it uses to cast its spells of 1st level and higher (as explained in the *Player’s Handbook*). The spellcaster level is also used for any cantrips included in the feature.\n\nThe monster has a list of spells known or prepared from a specific class. The list might also include spells from a feature in that class, such as the Divine Domain feature of the cleric or the Druid Circle feature of the druid. The monster is considered a member of that class when attuning to or using a magic item that requires membership in the class or access to its spell list.\n\nA monster can cast a spell from its list at a higher level if it has the spell slot to do so. For example, a drow mage with the 3rd-level *lightning bolt* spell can cast it as a 5th-level spell by using one of its 5th-level spell slots.\n\nYou can change the spells that a monster knows or has prepared, replacing any spell on its spell list with a spell of the same level and from the same class list. If you do so, you might cause the monster to be a greater or lesser threat than suggested by its challenge rating.\n\n### Psionics\n\nA monster that casts spells using only the power of its mind has the psionics tag added to its Spellcasting or Innate Spellcasting special trait. This tag carries no special rules of its own, but other parts of the game might refer to it. A monster that has this tag typically doesn’t require any components to cast its spells.\n\n## Actions\n\nWhen a monster takes its action, it can choose from the options in the Actions section of its stat block or use one of the actions available to all creatures, such as the Dash or Hide action, as described in the *Player’s Handbook*.\n\n### Melee and Ranged Attacks\n\nThe most common actions that a monster will take in combat are melee and ranged attacks. These can be spell attacks or weapon attacks, where the “weapon” might be a manufactured item or a natural weapon, such as a claw or tail spike. For more information on different kinds of attacks, see the *Player’s Handbook*.\n\n***Creature vs. Target.*** The target of a melee or ranged attack is usually either one creature or one target, the difference being that a “target” can be a creature or an object.\n\n***Hit.*** Any damage dealt or other effects that occur as a result of an attack hitting a target are described after the \"*Hit*\" notation. You have the option of taking average damage or rolling the damage; for this reason, both the average damage and the die expression are presented.\n\n***Miss.*** If an attack has an effect that occurs on a miss, that information is presented after the \"*Miss:*\" notation.\n\n### Multiattack\n\nA creature that can make multiple attacks on its turn has the Multiattack action. A creature can’t use Multiattack when making an opportunity attack, which must be a single melee attack.\n\n### Ammunition\nA monster carries enough ammunition to make its ranged attacks. You can assume that a monster has 2d4 pieces of ammunition for a thrown weapon attack, and 2d10 pieces of ammunition for a projectile weapon such as a bow or crossbow.\n\n## Reactions\n\nIf a monster can do something special with its reaction, that information is contained here. If a creature has no special reaction, this section is absent.\n\n## Limited Usage\n\nSome special abilities have restrictions on the number of times they can be used.\n\n***X/Day.*** The notation \"X/Day\" means a special ability can be used X number of times and that a monster must finish a long rest to regain expended uses. For example, \"1/Day\" means a special ability can be used once and that the monster must finish a long rest to use it again.\n\n***Recharge X–Y.*** The notation \"Recharge X–Y\" means a monster can use a special ability once and that the ability then has a random chance of recharging during each subsequent round of combat. At the start of each of the monster’s turns, roll a d6. If the roll is one of the numbers in the recharge notation, the monster regains the use of the special ability. The ability also recharges when the monster finishes a short or long rest.\n\nFor example, \"Recharge 5–6\" means a monster can use the special ability once. Then, at the start of the monster’s turn, it regains the use of that ability if it rolls a 5 or 6 on a d6.\n\n***Recharge after a Short or Long Rest.*** This notation means that a monster can use a special ability once and then must finish a short or long rest to use it again.\n   \n#### Grapple Rules for Monsters\n\nMany monsters have special attacks that allow them to quickly grapple prey. When a monster hits with such an attack, it doesn’t need to make an additional ability check to determine whether the grapple succeeds, unless the attack says otherwise.\n\nA creature grappled by the monster can use its action to try to escape. To do so, it must succeed on a Strength (Athletics) or Dexterity (Acrobatics) check against the escape DC in the monster’s stat block. If no escape DC is given, assume the DC is 10 + the monster’s Strength (Athletics) modifier.\n\n## Equipment\n\nA stat block rarely refers to equipment, other than armor or weapons used by a monster. A creature that customarily wears clothes, such as a humanoid, is assumed to be dressed appropriately.\n\nYou can equip monsters with additional gear and trinkets however you like, and you decide how much of a monster’s equipment is recoverable after the creature is slain and whether any of that equipment is still usable. A battered suit of armor made for a monster is rarely usable by someone else, for instance.\n\nIf a spellcasting monster needs material components to cast its spells, assume that it has the material components it needs to cast the spells in its stat block.\n\n# Legendary Creatures\n\nA legendary creature can do things that ordinary creatures can’t. It can take special actions outside its turn, and it might exert magical influence for miles around.\n\nIf a creature assumes the form of a legendary creature, such as through a spell, it doesn’t gain that form’s legendary actions, lair actions, or regional effects.\n\n## Legendary Actions\n\nA legendary creature can take a certain number of special actions—called legendary actions—outside its turn. Only one legendary action option can be used at a time and only at the end of another creature’s turn. A creature regains its spent legendary actions at the start of its turn. It can forgo using them, and it can’t use them while incapacitated or otherwise unable to take actions. If surprised, it can’t use them until after its first turn in the combat.\n\n## A Legendary Creature’s Lair\n\nA legendary creature might have a section describing its lair and the special effects it can create while there, either by act of will or simply by being present. Such a section applies only to a legendary creature that spends a great deal of time in its lair.\n\n### Lair Actions\n\nIf a legendary creature has lair actions, it can use them to harness the ambient magic in its lair. On initiative count 20 (losing all initiative ties), it can use one of its lair action options. It can’t do so while incapacitated or otherwise unable to take actions. If surprised, it can’t use one until after its first turn in the combat.\n\n### Regional Effects\n\nThe mere presence of a legendary creature can have strange and wondrous effects on its environment, as noted in this section. Regional effects end abruptly or dissipate over time when the legendary creature dies.",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Rules"
        },
        {
            "slug": "mounted-combat",
            "name": "Mounted Combat",
            "desc": "A knight charging into battle on a warhorse, a wizard casting spells from the back of a griffon, or a cleric soaring through the sky on a pegasus all enjoy the benefits of speed and mobility that a mount can provide.\n\nA willing creature that is at least one size larger than you and that has an appropriate anatomy can serve as a mount, using the following rules.\n\n## Mounting and Dismounting\n\nOnce during your move, you can mount a creature that is within 5 feet of you or dismount. Doing so costs an amount of movement equal to half your speed. For example, if your speed is 30 feet, you must spend 15 feet of movement to mount a horse. Therefore, you can't mount it if you don't have 15 feet of movement left or if your speed is 0.\n\nIf an effect moves your mount against its will while you're on it, you must succeed on a DC 10 Dexterity saving throw or fall off the mount, landing srd:prone in a space within 5 feet of it. If you're knocked srd:prone while mounted, you must make the same saving throw.\n\nIf your mount is knocked srd:prone, you can use your reaction to dismount it as it falls and land on your feet. Otherwise, you are dismounted and fall srd:prone in a space within 5 feet it.\n\n## Controlling a Mount\n\nWhile you're mounted, you have two options. You can either control the mount or allow it to act independently. Intelligent creatures, such as dragons, act independently.\n\nYou can control a mount only if it has been trained to accept a rider. Domesticated horses, donkeys, and similar creatures are assumed to have such training. The initiative of a controlled mount changes to match yours when you mount it. It moves as you direct it, and it has only three action options: Dash, Disengage, and Dodge. A controlled mount can move and act even on the turn that you mount it.\n\nAn independent mount retains its place in the initiative order. Bearing a rider puts no restrictions on the actions the mount can take, and it moves and acts as it wishes. It might flee from combat, rush to attack and devour a badly injured foe, or otherwise act against your wishes.\n\nIn either case, if the mount provokes an opportunity attack while you're on it, the attacker can target you or the mount.",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Combat"
        },
        {
            "slug": "mounts-and-vehicles",
            "name": "Mounts and Vehicles",
            "desc": "A good mount can help you move more quickly through the wilderness, but its primary purpose is to carry the gear that would otherwise slow you down. The Mounts and Other Animals table shows each animal's speed and base carrying capacity.\n\nAn animal pulling a carriage, cart, chariot, sled, or wagon can move weight up to five times its base carrying capacity, including the weight of the vehicle. If multiple animals pull the same vehicle, they can add their carrying capacity together.\n\nMounts other than those listed here are available in fantasy gaming worlds, but they are rare and not normally available for purchase. These include flying mounts (pegasi, griffons, hippogriffs, and similar animals) and even aquatic mounts (giant sea horses, for example). Acquiring such a mount often means securing an egg and raising the creature yourself, making a bargain with a powerful entity, or negotiating with the mount itself.\n\n**_Barding._** Barding is armor designed to protect an animal's head, neck, chest, and body. Any type of armor shown on the Armor table can be purchased as barding. The cost is four times the equivalent armor made for humanoids, and it weighs twice as much.\n\n**_Saddles._** A military saddle braces the rider, helping you keep your seat on an active mount in battle. It gives you advantage on any check you make to remain mounted. An exotic saddle is required for riding any aquatic or flying mount.\n\n**_Vehicle Proficiency._** If you have proficiency with a certain kind of vehicle (land or water), you can add your proficiency bonus to any check you make to control that kind of vehicle in difficult circumstances.\n\n**_Rowed Vessels._** Keelboats and rowboats are used on lakes and rivers. If going downstream, add the speed of the current (typically 3 miles per hour) to the speed of the vehicle. These vehicles can't be rowed against any significant current, but they can be pulled upstream by draft animals on the shores. A rowboat weighs 100 pounds, in case adventurers carry it over land.\n\n**Mounts and Other Animals (table)**\n\n| Item           | Cost   | Speed  | Carrying Capacity |\n|----------------|--------|--------|-------------------|\n| Camel          | 50 gp  | 50 ft. | 480 lb.           |\n| Donkey or mule | 8 gp   | 40 ft. | 420 lb.           |\n| Elephant       | 200 gp | 40 ft. | 1,320 lb.         |\n| Horse, draft   | 50 gp  | 40 ft. | 540 lb.           |\n| Horse, riding  | 75 gp  | 60 ft. | 480 lb.           |\n| Mastiff        | 25 gp  | 40 ft. | 195 lb.           |\n| Pony           | 30 gp  | 40 ft. | 225 lb.           |\n| Warhorse       | 400 gp | 60 ft. | 540 lb.           |\n\n**Tack, Harness, and Drawn Vehicles (table)**\n\n| Item               | Cost   | Weight  |\n|--------------------|--------|---------|\n| Barding            | ×4     | ×2      |\n| Bit and bridle     | 2 gp   | 1 lb.   |\n| Carriage           | 100 gp | 600 lb. |\n| Cart               | 15 gp  | 200 lb. |\n| Chariot            | 250 gp | 100 lb. |\n| Feed (per day)     | 5 cp   | 10 lb.  |\n| **_Saddle_**       |        |         |\n| - Exotic           | 60 gp  | 40 lb.  |\n| - Military         | 20 gp  | 30 lb.  |\n| - Pack             | 5 gp   | 15 lb.  |\n| - Riding           | 10 gp  | 25 lb.  |\n| Saddlebags         | 4 gp   | 8 lb.   |\n| Sled               | 20 gp  | 300 lb. |\n| Stabling (per day) | 5 sp   | -       |\n| Wagon              | 35 gp  | 400 lb. |\n\n**Waterborne Vehicles (table)**\n\n| Item         | Cost      | Speed  |\n|--------------|-----------|--------|\n| Galley       | 30,000 gp | 4 mph  |\n| Keelboat     | 3,000 gp  | 1 mph  |\n| Longship     | 10,000 gp | 3 mph  |\n| Rowboat      | 50 gp     | 1½ mph |\n| Sailing ship | 10,000 gp | 2 mph  |\n| Warship      | 25,000 gp | 2½ mph |\n",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Equipment"
        },
        {
            "slug": "movement",
            "name": "Movement",
            "desc": "Swimming across a rushing river, sneaking down a dungeon corridor, scaling a treacherous mountain slope---all sorts of movement play a keyrole in fantasy gaming adventures.\n\nThe GM can summarize the adventurers' movement without calculating exactdistances or travel times: You travel through the forest and find thedungeon entrance late in the evening of the third day. Even in adungeon, particularly a large dungeon or a cave network, the GM cansummarize movement between encounters: After killing the guardian at the entrance to the ancient dwarven stronghold, you consult your map,which leads you through miles of echoing corridors to a chasm bridged bya narrow stone arch. Sometimes it's important, though, to know how long it takes to get fromone spot to another, whether the answer is in days, hours, or minutes.\n\nThe rules for determining travel time depend on two factors: the speedand travel pace of the creatures moving and the terrain they're movingover.\n\n## Speed\n\nEvery character and monster has a speed, which is the distance in feetthat the character or monster can walk in 1 round. This number assumesshort bursts of energetic movement in the midst of a life-threateningsituation.\n\nThe following rules determine how far a character or monster can move ina minute, an hour, or a day.\n\n### Travel Pace\n\nWhile traveling, a group of adventurers can move at a normal, fast, orslow pace, as shown on the Travel Pace table. The table states how farthe party can move in a period of time and whether the pace has anyeffect. A fast pace makes characters less perceptive, while a slow pacemakes it possible to sneak around and to search an area more carefully.\n\n**Forced March.** The Travel Pace table assumes that characters travelfor 8 hours in day. They can push on beyond that limit, at the risk of exhaustion.\n\nFor each additional hour of travel beyond 8 hours, the characters coverthe distance shown in the Hour column for their pace, and each charactermust make a Constitution saving throw at the end of the hour. The DC is 10 + 1 for each hour past 8 hours. On a failed saving throw, a charactersuffers one level of exhaustion.\n\n**Mounts and Vehicles.** For short spans of time (up to an hour), many animals move much faster than humanoids. A mounted character can ride at a gallop for about an hour, covering twice the usual distance for a fastpace. If fresh mounts are available every 8 to 10 miles, characters cancover larger distances at this pace, but this is very rare except indensely populated areas.\nCharacters in wagons, carriages, or other land vehicles choose a pace asnormal. Characters in a waterborne vessel are limited to the speed ofthe vessel, and they don't suffer penalties for a fast pace or gainbenefits from a slow pace. Depending on the vessel and the size of thecrew, ships might be able to travel for up to 24 hours per day.\nCertain special mounts, such as a pegasus or griffon, or specialvehicles, such as a carpet of flying, allow you to travel more swiftly.\n\n### Difficult Terrain\n\nThe travel speeds given in the Travel Pace table assume relativelysimple terrain: roads, open plains, or clear dungeon corridors. But adventurers often face dense forests, deep swamps, rubble-filled ruins, steep mountains, and ice-covered ground---all considered difficult terrain.\n\nYou move at half speed in difficult terrain---moving 1 foot in difficult terrain costs 2 feet of speed---so you can cover only half the normal distance in a minute, an hour, or a day.\n\n## Special Types of Movement\n\nMovement through dangerous dungeons or wilderness areas often involves more than simply walking. Adventurers might have to climb, crawl, swim,or jump to get where they need to go.\n\n### Climbing, Swimming, and Crawling\n\nWhile climbing or swimming, each foot of movement costs 1 extra foot (2extra feet in difficult terrain), unless a creature has a climbing orswimming speed. At the GM's option, climbing a slippery vertical surfaceor one with few handholds requires a successful Strength (Athletics) check. Similarly, gaining any distance in rough water might require asuccessful Strength (Athletics) check.\n\n### Jumping\n\nYour Strength determines how far you can jump.\n\n**Long Jump.** When you make a long jump, you cover a number of feet upto your Strength score if you move at least 10 feet on foot immediatelybefore the jump. When you make a standing long jump, you can leap onlyhalf that distance. Either way, each foot you clear on the jump costs afoot of movement.\nThis rule assumes that the height of your jump doesn't matter, such as ajump across a stream or chasm. At your GM's option, you must succeed ona DC 10 Strength (Athletics) check to clear a low obstacle (no tallerthan a quarter of the jump's distance), such as a hedge or low wall.\nOtherwise, you hit it.\nWhen you land in difficult terrain, you must succeed on a DC 10Dexterity (Acrobatics) check to land on your feet. Otherwise, you landprone.\n\n**High Jump.** When you make a high jump, you leap into the air a numberof feet equal to 3 + your Strength modifier if you move at least 10 feeton foot immediately before the jump. When you make a standing high jump,you can jump only half that distance. Either way, each foot you clear onthe jump costs a foot of movement. In some circumstances, your GM mightallow you to make a Strength (Athletics) check to jump higher than younormally can.\nYou can extend your arms half your height above yourself during thejump. Thus, you can reach above you a distance equal to the height ofthe jump plus 1½ times your height.",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Gameplay Mechanics"
        },
        {
            "slug": "multiclassing",
            "name": "Multiclassing",
            "desc": "Multiclassing allows you to gain levels in multiple classes. Doing so lets you mix the abilities of those classes to realize a character concept that might not be reflected in one of the standard class options.\n\nWith this rule, you have the option of gaining a level in a new class whenever you advance in level, instead of gaining a level in your current class. Your levels in all your classes are added together to determine your character level. For example, if you have three levels in wizard and two in fighter, you're a 5th-level character.\n\nAs you advance in levels, you might primarily remain a member of your original class with just a few levels in another class, or you might change course entirely, never looking back at the class you left behind. You might even start progressing in a third or fourth class. Compared to a single-class character of the same level, you'll sacrifice some focus in exchange for versatility.\n\n## Prerequisites\n\nTo qualify for a new class, you must meet the ability score prerequisites for both your current class and your new one, as shown in the Multiclassing Prerequisites table. For example, a barbarian who decides to multiclass into the druid class must have both Strength and Wisdom scores of 13 or higher. Without the full training that a beginning character receives, you must be a quick study in your new class, having a natural aptitude that is reflected by higher- than-average ability scores.\n\n**Multiclassing Prerequisites (table)**\n\n| Class     | Ability Score Minimum       |\n|-----------|-----------------------------|\n| Barbarian | Strength 13                 |\n| Bard      | Charisma 13                 |\n| Cleric    | Wisdom 13                   |\n| Druid     | Wisdom 13                   |\n| Fighter   | Strength 13 or Dexterity 13 |\n| Monk      | Dexterity 13 and Wisdom 13  |\n| Paladin   | Strength 13 and Charisma 13 |\n| Ranger    | Dexterity 13 and Wisdom 13  |\n| Rogue     | Dexterity 13                |\n| Sorcerer  | Charisma 13                 |\n| Warlock   | Charisma 13                 |\n| Wizard    | Intelligence 13             |\n\n## Experience Points\n\nThe experience point cost to gain a level is always based on your total character level, as shown in the Character Advancement table, not your level in a particular class. So, if you are a cleric 6/fighter 1, you must gain enough XP to reach 8th level before you can take your second level as a fighter or your seventh level as a cleric.\n\n## Hit Points and Hit Dice\n\nYou gain the hit points from your new class as described for levels after 1st. You gain the 1st-level hit points for a class only when you are a 1st-level character.\n\nYou add together the Hit Dice granted by all your classes to form your pool of Hit Dice. If the Hit Dice are the same die type, you can simply pool them together. For example, both the fighter and the paladin have a d10, so if you are a paladin 5/fighter 5, you have ten d10 Hit Dice. If your classes give you Hit Dice of different types, keep track of them separately. If you are a paladin 5/cleric 5, for example, you have five d10 Hit Dice and five d8 Hit Dice.\n\n# Proficiency Bonus\n\nYour proficiency bonus is always based on your total character level, as shown in the Character Advancement table in chapter 1, not your level in a particular class. For example, if you are a fighter 3/rogue 2, you have the proficiency bonus of a 5th- level character, which is +3.\n\n# Proficiencies\n\nWhen you gain your first level in a class other than your initial class, you gain only some of new class's starting proficiencies, as shown in the Multiclassing Proficiencies table.\n\n**Multiclassing Proficiencies (table)**\n\n| Class     | Proficiencies Gained                                                                                       |\n|-----------|------------------------------------------------------------------------------------------------------------|\n| Barbarian | Shields, simple weapons, martial weapons                                                                   |\n| Bard      | Light armor, one skill of your choice, one musical instrument of your choice                               |\n| Cleric    | Light armor, medium armor, shields                                                                         |\n| Druid     | Light armor, medium armor, shields (druids will not wear armor or use shields made of metal)               |\n| Fighter   | Light armor, medium armor, shields, simple weapons, martial weapons                                        |\n| Monk      | Simple weapons, shortswords                                                                                |\n| Paladin   | Light armor, medium armor, shields, simple weapons, martial weapons                                        |\n| Ranger    | Light armor, medium armor, shields, simple weapons, martial weapons, one skill from the class's skill list |\n| Rogue     | Light armor, one skill from the class's skill list, thieves' tools                                         |\n| Sorcerer  | -                                                                                                          |\n| Warlock   | Light armor, simple weapons                                                                                |\n| Wizard    | -                                                                                                          |\n\n## Class Features\n\nWhen you gain a new level in a class, you get its features for that level. You don't, however, receive the class's starting equipment, and a few features have additional rules when you're multiclassing: Channel Divinity, Extra Attack, Unarmored Defense, and Spellcasting.\n\n## Channel Divinity\n\nIf you already have the Channel Divinity feature and gain a level in a class that also grants the feature, you gain the Channel Divinity effects granted by that class, but getting the feature again doesn't give you an additional use of it. You gain additional uses only when you reach a class level that explicitly grants them to you. For example, if you are a cleric 6/paladin 4, you can use Channel Divinity twice between rests because you are high enough level in the cleric class to have more uses. Whenever you use the feature, you can choose any of the Channel Divinity effects available to you from your two classes.\n\n## Extra Attack\n\nIf you gain the Extra Attack class feature from more than one class, the features don't add together. You can't make more than two attacks with this feature unless it says you do (as the fighter's version of Extra Attack does). Similarly, the warlock's eldritch invocation Thirsting Blade doesn't give you additional attacks if you also have Extra Attack.\n\n## Unarmored Defense\n\nIf you already have the Unarmored Defense feature, you can't gain it again from another class.\n\n## Spellcasting\n\nYour capacity for spellcasting depends partly on your combined levels in all your spellcasting classes and partly on your individual levels in those classes. Once you have the Spellcasting feature from more than one class, use the rules below. If you multiclass but have the Spellcasting feature from only one class, you follow the rules as described in that class.\n\n**_Spells Known and Prepared._** You determine what spells you know and can prepare for each class individually, as if you were a single-classed member of that class. If you are a ranger 4/wizard 3, for example, you know three 1st-level ranger spells based on your levels in the ranger class. As 3rd-level wizard, you know three wizard cantrips, and your spellbook contains ten wizard spells, two of which (the two you gained when you reached 3rd level as a wizard) can be 2nd-level spells. If your Intelligence is 16, you can prepare six wizard spells from your spellbook.\n\nEach spell you know and prepare is associated with one of your classes, and you use the spellcasting ability of that class when you cast the spell. Similarly, a spellcasting focus, such as a holy symbol, can be used only for the spells from the class associated with that focus.\n\n**_Spell Slots._** You determine your available spell slots by adding together all your levels in the bard, cleric, druid, sorcerer, and wizard classes, and half your levels (rounded down) in the paladin and ranger classes. Use this total to determine your spell slots by consulting the Multiclass Spellcaster table.\n\nIf you have more than one spellcasting class, this table might give you spell slots of a level that is higher than the spells you know or can prepare. You can use those slots, but only to cast your lower-level spells. If a lower-level spell that you cast, like _burning hands_, has an enhanced effect when cast using a higher-level slot, you can use the enhanced effect, even though you don't have any spells of that higher level.\n\nFor example, if you are the aforementioned ranger 4/wizard 3, you count as a 5th-level character when determining your spell slots: you have four 1st-level slots, three 2nd-level slots, and two 3rd-level slots. However, you don't know any 3rd-level spells, nor do you know any 2nd-level ranger spells. You can use the spell slots of those levels to cast the spells you do know-and potentially enhance their effects.\n\n**_Pact Magic._** If you have both the Spellcasting class feature and the Pact Magic class feature from the warlock class, you can use the spell slots you gain from the Pact Magic feature to cast spells you know or have prepared from classes with the Spellcasting class feature, and you can use the spell slots you gain from the Spellcasting class feature to cast warlock spells you know.\n\n**Multiclass Spellcaster: Spell Slots per Spell Level (table)**\n\n| Level | 1st | 2nd | 3rd | 4th | 5th | 6th | 7th | 8th | 9th |\n|-------|-----|-----|-----|-----|-----|-----|-----|-----|-----|\n| 1st   | 2   | -   | -   | -   | -   | -   | -   | -   | -   |\n| 2nd   | 3   | -   | -   | -   | -   | -   | -   | -   | -   |\n| 3rd   | 4   | 2   | -   | -   | -   | -   | -   | -   | -   |\n| 4th   | 4   | 3   | -   | -   | -   | -   | -   | -   | -   |\n| 5th   | 4   | 3   | 2   | -   | -   | -   | -   | -   | -   |\n| 6th   | 4   | 3   | 3   | -   | -   | -   | -   | -   | -   |\n| 7th   | 4   | 3   | 3   | 1   | -   | -   | -   | -   | -   |\n| 8th   | 4   | 3   | 3   | 2   | -   | -   | -   | -   | -   |\n| 9th   | 4   | 3   | 3   | 3   | 1   | -   | -   | -   | -   |\n| 10th  | 4   | 3   | 3   | 3   | 2   | -   | -   | -   | -   |\n| 11th  | 4   | 3   | 3   | 3   | 2   | 1   | -   | -   | -   |\n| 12th  | 4   | 3   | 3   | 3   | 2   | 1   | -   | -   | -   |\n| 13th  | 4   | 3   | 3   | 3   | 2   | 1   | 1   | -   | -   |\n| 14th  | 4   | 3   | 3   | 3   | 2   | 1   | 1   | -   | -   |\n| 15th  | 4   | 3   | 3   | 3   | 2   | 1   | 1   | 1   | -   |\n| 16th  | 4   | 3   | 3   | 3   | 2   | 1   | 1   | 1   | -   |\n| 17th  | 4   | 3   | 3   | 3   | 2   | 1   | 1   | 1   | 1   |\n| 18th  | 4   | 3   | 3   | 3   | 3   | 1   | 1   | 1   | 1   |\n| 19th  | 4   | 3   | 3   | 3   | 3   | 2   | 1   | 1   | 1   |\n| 20th  | 4   | 3   | 3   | 3   | 3   | 2   | 2   | 1   | 1   |",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Character Advancement"
        },
        {
            "slug": "nonplayer-characters",
            "name": "Nonplayer Characters",
            "desc": "This appendix contains statistics for various humanoid nonplayer characters (NPCs) that adventurers might encounter during a campaign, including lowly commoners and mighty archmages. These stat blocks can be used to represent both human and nonhuman NPCs.\n\n## Customizing NPCs\n\nThere are many easy ways to customize the NPCs in this appendix for your home campaign.\n\n***Racial Traits.*** You can add racial traits to an NPC. For example, a halfling druid might have a speed of 25 feet and the Lucky trait. Adding racial traits to an NPC doesn’t alter its challenge rating. For more on racial traits, see the *Player’s Handbook*.\n\n***Spell Swaps.*** One way to customize an NPC spellcaster is to replace one or more of its spells. You can substitute any spell on the NPC’s spell list with a different spell of the same level from the same spell list. Swapping spells in this manner doesn’t alter an NPC’s challenge rating.\n\n***Armor and Weapon Swaps.*** You can upgrade or downgrade an NPC’s armor, or add or switch weapons. Adjustments to Armor Class and damage can change an NPC’s challenge rating.\n\n***Magic Items.*** The more powerful an NPC, the more likely it has one or more magic items in its possession. An archmage, for example, might have a magic staff or wand, as well as one or more potions and scrolls. Giving an NPC a potent damage-dealing magic item could alter its challenge rating.",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Rules"
        },
        {
            "slug": "objects",
            "name": "Objects",
            "desc": "When characters need to saw through ropes, shatter a window, or smash a vampire's coffin, the only hard and fast rule is this: given enough time and the right tools, characters can destroy any destructible object. Use common sense when determining a character's success at damaging an object. Can a fighter cut through a section of a stone wall with a sword? No, the sword is likely to break before the wall does.\n\nFor the purpose of these rules, an object is a discrete, inanimate item like a window, door, sword, book, table, chair, or stone, not a building or a vehicle that is composed of many other objects.\n\n## Statistics for Objects\n\nWhen time is a factor, you can assign an Armor Class and hit points to a destructible object. You can also give it immunities, resistances, and vulnerabilities to specific types of damage.\n\n**_Armor Class_**. An object's Armor Class is a measure of how difficult it is to deal damage to the object when striking it (because the object has no chance of dodging out of the way). The Object Armor Class table provides suggested AC values for various substances.\n\n**Object Armor Class (table)**\n| Substance           | AC |\n|---------------------|----|\n| Cloth, paper, rope  | 11 |\n| Crystal, glass, ice | 13 |\n| Wood, bone          | 15 |\n| Stone               | 17 |\n| Iron, steel         | 19 |\n| Mithral             | 21 |\n| Adamantine          | 23 |\n\n**_Hit Points_**. An object's hit points measure how much damage it can take before losing its structural integrity. Resilient objects have more hit points than fragile ones. Large objects also tend to have more hit points than small ones, unless breaking a small part of the object is just as effective as breaking the whole thing. The Object Hit Points table provides suggested hit points for fragile and resilient objects that are Large or smaller.\n\n**Object Hit Points (table)**\n\n| Size                                  | Fragile  | Resilient |\n|---------------------------------------|----------|-----------|\n| Tiny (bottle, lock)                   | 2 (1d4)  | 5 (2d4)   |\n| Small (chest, lute)                   | 3 (1d6)  | 10 (3d6)  |\n| Medium (barrel, chandelier)           | 4 (1d8)  | 18 (4d8)  |\n| Large (cart, 10-ft.-by-10-ft. window) | 5 (1d10) | 27 (5d10) |\n\n**_Huge and Gargantuan Objects_**. Normal weapons are of little use against many Huge and Gargantuan objects, such as a colossal statue, towering column of stone, or massive boulder. That said, one torch can burn a Huge tapestry, and an _earthquake_ spell can reduce a colossus to rubble. You can track a Huge or Gargantuan object's hit points if you like, or you can simply decide how long the object can withstand whatever weapon or force is acting against it. If you track hit points for the object, divide it into Large or smaller sections, and track each section's hit points separately. Destroying one of those sections could ruin the entire object. For example, a Gargantuan statue of a human might topple over when one of its Large legs is reduced to 0 hit points.\n\n**_Objects and Damage Types_**. Objects are immune to poison and psychic damage. You might decide that some damage types are more effective against a particular object or substance than others. For example, bludgeoning damage works well for smashing things but not for cutting through rope or leather. Paper or cloth objects might be vulnerable to fire and lightning damage. A pick can chip away stone but can't effectively cut down a tree. As always, use your best judgment.\n\n**_Damage Threshold_**. Big objects such as castle walls often have extra resilience represented by a damage threshold. An object with a damage threshold has immunity to all damage unless it takes an amount of damage from a single attack or effect equal to or greater than its damage threshold, in which case it takes damage as normal. Any damage that fails to meet or exceed the object's damage threshold is considered superficial and doesn't reduce the object's hit points.",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Rules"
        },
        {
            "slug": "pantheons",
            "name": "Pantheons",
            "desc": "The Celtic, Egyptian, Greek, and Norse pantheons are fantasy interpretations of historical religions from our world's ancient times. They include deities that are most appropriate for use in a game, divorced from their historical context in the real world and united into pantheons that serve the needs of the game.\n\n## The Celtic Pantheon\n\nIt's said that something wild lurks in the heart of every soul, a space that thrills to the sound of geese calling at night, to the whispering wind through the pines, to the unexpected red of mistletoe on an oak-and it is in this space that the Celtic gods dwell. They sprang from the brook and stream, their might heightened by the strength of the oak and the beauty of the woodlands and open moor. When the first forester dared put a name to the face seen in the bole of a tree or the voice babbling in a brook, these gods forced themselves into being.\n\nThe Celtic gods are as often served by druids as by clerics, for they are closely aligned with the forces of nature that druids revere.\n\n## Celtic Deities\n| Deity                                             | Alignment | Suggested Domains | Symbol                             |\n|---------------------------------------------------|-----------|-------------------|------------------------------------|\n| The Daghdha, god of weather and crops             | CG        | Nature, Trickery  | Bubbling cauldron or shield        |\n| Arawn, god of life and death                      | NE        | Life, Death       | Black star on gray background      |\n| Belenus, god of sun, light, and warmth            | NG        | Light             | Solar disk and standing stones     |\n| Brigantia, goddess of rivers and livestock        | NG        | Life              | Footbridge                         |\n| Diancecht, god of medicine and healing            | LG        | Life              | Crossed oak and mistletoe branches |\n| Dunatis, god of mountains and peaks               | N         | Nature            | Red sun-capped mountain peak       |\n| Goibhniu, god of smiths and healing               | NG        | Knowledge, Life   | Giant mallet over sword            |\n| Lugh, god of arts, travel, and commerce           | CN        | Knowledge, Life   | Pair of long hands                 |\n| Manannan mac Lir, god of oceans and sea creatures | LN        | Nature, Tempest   | Wave of white water on green       |\n| Math Mathonwy, god of magic                       | NE        | Knowledge         | Staff                              |\n| Morrigan, goddess of battle                       | CE        | War               | Two crossed spears                 |\n| Nuada, god of war and warriors                    | N         | War               | Silver hand on black background    |\n| Oghma, god of speech and writing                  | NG        | Knowledge         | Unfurled scroll                    |\n| Silvanus, god of nature and forests               | N         | Nature            | Summer oak tree                    |\n## The Greek Pantheon\nThe gods of Olympus make themselves known with the gentle lap of waves against the shores and the crash of the thunder among the cloud-enshrouded peaks. The thick boar-infested woods and the sere, olive-covered hillsides hold evidence of their passing. Every aspect of nature echoes with their presence, and they've made a place for themselves inside the human heart, too.\n## Greek Deities\n| Deity                                      | Alignment | Suggested Domains      | Symbol                                |\n|--------------------------------------------|-----------|------------------------|---------------------------------------|\n| Zeus, god of the sky, ruler of the gods    | N         | Tempest                | Fist full of lightning bolts          |\n| Aphrodite, goddess of love and beauty      | CG        | Light                  | Sea shell                             |\n| Apollo, god of light, music, and healing   | CG        | Knowledge, Life, Light | Lyre                                  |\n| Ares, god of war and strife                | CE        | War                    | Spear                                 |\n| Artemis, goddess of hunting and childbirth | NG        | Life, Nature           | Bow and arrow on lunar disk           |\n| Athena, goddess of wisdom and civilization | LG        | Knowledge, War         | Owl                                   |\n| Demeter, goddess of agriculture            | NG        | Life                   | Mare's head                           |\n| Dionysus, god of mirth and wine            | CN        | Life                   | Thyrsus (staff tipped with pine cone) |\n| Hades, god of the underworld               | LE        | Death                  | Black ram                             |\n| Hecate, goddess of magic and the moon      | CE        | Knowledge, Trickery    | Setting moon                          |\n| Hephaestus, god of smithing and craft      | NG        | Knowledge              | Hammer and anvil                      |\n| Hera, goddess of marriage and intrigue     | CN        | Trickery               | Fan of peacock feathers               |\n| Hercules, god of strength and adventure    | CG        | Tempest, War           | Lion's head                           |\n| Hermes, god of travel and commerce         | CG        | Trickery               | Caduceus (winged staff and serpents)  |\n| Hestia, goddess of home and family         | NG        | Life                   | Hearth                                |\n| Nike, goddess of victory                   | LN        | War                    | Winged woman                          |\n| Pan, god of nature                         | CN        | Nature                 | Syrinx (pan pipes)                    |\n| Poseidon, god of the sea and earthquakes   | CN        | Tempest                | Trident                               |\n| Tyche, goddess of good fortune             | N         | Trickery               | Red pentagram                         |\n\n## The Egyptian Pantheon\n\nThese gods are a young dynasty of an ancient divine family, heirs to the rulership of the cosmos and the maintenance of the divine principle of Ma'at-the fundamental order of truth, justice, law, and order that puts gods, mortal pharaohs, and ordinary men and women in their logical and rightful place in the universe.\n\nThe Egyptian pantheon is unusual in having three gods responsible for death, each with different alignments. Anubis is the lawful neutral god of the afterlife, who judges the souls of the dead. Set is a chaotic evil god of murder, perhaps best known for killing his brother Osiris. And Nephthys is a chaotic good goddess of mourning.\n\n## Egyptian Deities\n| Deity                                           | Alignment | Suggested Domains        | Symbol                               |\n|-------------------------------------------------|-----------|--------------------------|--------------------------------------|\n| Re-Horakhty, god of the sun, ruler of the gods  | LG        | Life, Light              | Solar disk encircled by serpent      |\n| Anubis, god of judgment and death               | LN        | Death                    | Black jackal                         |\n| Apep, god of evil, fire, and serpents           | NE        | Trickery                 | Flaming snake                        |\n| Bast, goddess of cats and vengeance             | CG        | War                      | Cat                                  |\n| Bes, god of luck and music                      | CN        | Trickery                 | Image of the misshapen deity         |\n| Hathor, goddess of love, music, and motherhood  | NG        | Life, Light              | Horned cowʼs head with lunar disk    |\n| Imhotep, god of crafts and medicine             | NG        | Knowledge                | Step pyramid                         |\n| Isis, goddess of fertility and magic            | NG        | Knowledge, Life          | Ankh and star                        |\n| Nephthys, goddess of death and grief            | CG        | Death                    | Horns around a lunar disk            |\n| Osiris, god of nature and the underworld        | LG        | Life, Nature             | Crook and flail                      |\n| Ptah, god of crafts, knowledge, and secrets     | LN        | Knowledge                | Bull                                 |\n| Set, god of darkness and desert storms          | CE        | Death, Tempest, Trickery | Coiled cobra                         |\n| Sobek, god of water and crocodiles              | LE        | Nature, Tempest          | Crocodile head with horns and plumes |\n| Thoth, god of knowledge and wisdom              | N         | Knowledge                | Ibis                                 |\n\n## The Norse Pantheon\n\nWhere the land plummets from the snowy hills into the icy fjords below, where the longboats draw up on to the beach, where the glaciers flow forward and retreat with every fall and spring-this is the land of the Vikings, the home of the Norse pantheon. It's a brutal clime, and one that calls for brutal living. The warriors of the land have had to adapt to the harsh conditions in order to survive, but they haven't been too twisted by the needs of their environment. Given the necessity of raiding for food and wealth, it's surprising the mortals turned out as well as they did. Their powers reflect the need these warriors had for strong leadership and decisive action. Thus, they see their deities in every bend of a river, hear them in the crash of the thunder and the booming of the glaciers, and smell them in the smoke of a burning longhouse.\n\nThe Norse pantheon includes two main families, the Aesir (deities of war and destiny) and the Vanir (gods of fertility and prosperity). Once enemies, these two families are now closely allied against their common enemies, the giants (including the gods Surtur and Thrym).\n\n## Norse Deities\n\n| Deity                                     | Alignment | Suggested Domains | Symbol                            |\n|-------------------------------------------|-----------|-------------------|-----------------------------------|\n| Odin, god of knowledge and war            | NG        | Knowledge, War    | Watching blue eye                 |\n| Aegir, god of the sea and storms          | NE        | Tempest           | Rough ocean waves                 |\n| Balder, god of beauty and poetry          | NG        | Life, Light       | Gem-encrusted silver chalice      |\n| Forseti, god of justice and law           | N         | Light             | Head of a bearded man             |\n| Frey, god of fertility and the sun        | NG        | Life, Light       | Ice-blue greatsword               |\n| Freya, goddess of fertility and love      | NG        | Life              | Falcon                            |\n| Frigga, goddess of birth and fertility    | N         | Life, Light       | Cat                               |\n| Heimdall, god of watchfulness and loyalty | LG        | Light, War        | Curling musical horn              |\n| Hel, goddess of the underworld            | NE        | Death             | Woman's face, rotting on one side |\n| Hermod, god of luck                       | CN        | Trickery          | Winged scroll                     |\n| Loki, god of thieves and trickery         | CE        | Trickery          | Flame                             |\n| Njord, god of sea and wind                | NG        | Nature, Tempest   | Gold coin                         |\n| Odur, god of light and the sun            | CG        | Light             | Solar disk                        |\n| Sif, goddess of war                       | CG        | War               | Upraised sword                    |\n| Skadi, god of earth and mountains         | N         | Nature            | Mountain peak                     |\n| Surtur, god of fire giants and war        | LE        | War               | Flaming sword                     |\n| Thor, god of storms and thunder           | CG        | Tempest, War      | Hammer                            |\n| Thrym, god of frost giants and cold       | CE        | War               | White double-bladed axe           |\n| Tyr, god of courage and strategy          | LN        | Knowledge, War    | Sword                             |\n| Uller, god of hunting and winter          | CN        | Nature            | Longbow                           |\n",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Rules"
        },
        {
            "slug": "planes",
            "name": "Planes",
            "desc": "The cosmos teems with a multitude of worlds as well as myriad alternate dimensions of reality, called the **planes of existence**. It encompasses every world where GMs run their adventures, all within the relatively mundane realm of the Material Plane. Beyond that plane are domains of raw elemental matter and energy, realms of pure thought and ethos, the homes of demons and angels, and the dominions of the gods.\n\nMany spells and magic items can draw energy from these planes, summon the creatures that dwell there, communicate with their denizens, and allow adventurers to travel there. As your character achieves greater power and higher levels, you might walk on streets made of solid fire or test your mettle on a battlefield where the fallen are resurrected with each dawn.\n\n## The Material Plane\n\nThe Material Plane is the nexus where the philosophical and elemental forces that define the other planes collide in the jumbled existence of mortal life and mundane matter. All fantasy gaming worlds exist within the Material Plane, making it the starting point for most campaigns and adventures. The rest of the multiverse is defined in relation to the Material Plane.\n\nThe worlds of the Material Plane are infinitely diverse, for they reflect the creative imagination of the GMs who set their games there, as well as the players whose heroes adventure there. They include magic-wasted desert planets and island-dotted water worlds, worlds where magic combines with advanced technology and others trapped in an endless Stone Age, worlds where the gods walk and places they have abandoned.\n\n## Beyond the Material\n\nBeyond the Material Plane, the various planes of existence are realms of myth and mystery. They're not simply other worlds, but different qualities of being, formed and governed by spiritual and elemental principles abstracted from the ordinary world.\n\n## Planar Travel\n\nWhen adventurers travel into other planes of existence, they are undertaking a legendary journey across the thresholds of existence to a mythic destination where they strive to complete their quest. Such a journey is the stuff of legend. Braving the realms of the dead, seeking out the celestial servants of a deity, or bargaining with an efreeti in its home city will be the subject of song and story for years to come.\n\nTravel to the planes beyond the Material Plane can be accomplished in two ways: by casting a spell or by using a planar portal.\n\n**_Spells._** A number of spells allow direct or indirect access to other planes of existence. _Plane shift_ and _gate_ can transport adventurers directly to any other plane of existence, with different degrees of precision. _Etherealness_ allows adventurers to enter the Ethereal Plane and travel from there to any of the planes it touches-such as the Elemental Planes. And the _astral projection_ spell lets adventurers project themselves into the Astral Plane and travel to the Outer Planes.\n\n**_Portals._** A portal is a general term for a stationary interplanar connection that links a specific location on one plane to a specific location on another. Some portals are like doorways, a clear window, or a fog- shrouded passage, and simply stepping through it effects the interplanar travel. Others are locations- circles of standing stones, soaring towers, sailing ships, or even whole towns-that exist in multiple planes at once or flicker from one plane to another in turn. Some are vortices, typically joining an Elemental Plane with a very similar location on the Material Plane, such as the heart of a volcano (leading to the Plane of Fire) or the depths of the ocean (to the Plane of Water).\n\n## Transitive Planes\n\nThe Ethereal Plane and the Astral Plane are called the Transitive Planes. They are mostly featureless realms that serve primarily as ways to travel from one plane to another. Spells such as _etherealness_ and _astral projection_ allow characters to enter these planes and traverse them to reach the planes beyond.\n\nThe **Ethereal Plane** is a misty, fog-bound dimension that is sometimes described as a great ocean. Its shores, called the Border Ethereal, overlap the Material Plane and the Inner Planes, so that every location on those planes has a corresponding location on the Ethereal Plane. Certain creatures can see into the Border Ethereal, and the _see invisibility_ and _true seeing_ spell grant that ability. Some magical effects also extend from the Material Plane into the Border Ethereal, particularly effects that use force energy such as _forcecage_ and _wall of force_. The depths of the plane, the Deep Ethereal, are a region of swirling mists and colorful fogs.\n\nThe **Astral Plane** is the realm of thought and dream, where visitors travel as disembodied souls to reach the planes of the divine and demonic. It is a great, silvery sea, the same above and below, with swirling wisps of white and gray streaking among motes of light resembling distant stars. Erratic whirlpools of color flicker in midair like spinning coins. Occasional bits of solid matter can be found here, but most of the Astral Plane is an endless, open domain.\n\n## Inner Planes\n\nThe Inner Planes surround and enfold the Material Plane and its echoes, providing the raw elemental substance from which all the worlds were made. The four **Elemental Planes**-Air, Earth, Fire, and Water-form a ring around the Material Plane, suspended within the churning **Elemental Chaos**.\n\nAt their innermost edges, where they are closest to the Material Plane (in a conceptual if not a literal geographical sense), the four Elemental Planes resemble a world in the Material Plane. The four elements mingle together as they do in the Material Plane, forming land, sea, and sky. Farther from the Material Plane, though, the Elemental Planes are both alien and hostile. Here, the elements exist in their purest form-great expanses of solid earth, blazing fire, crystal-clear water, and unsullied air. These regions are little-known, so when discussing the Plane of Fire, for example, a speaker usually means just the border region. At the farthest extents of the Inner Planes, the pure elements dissolve and bleed together into an unending tumult of clashing energies and colliding substance, the Elemental Chaos.\n\n## Outer Planes\n\nIf the Inner Planes are the raw matter and energy that makes up the multiverse, the Outer Planes are the direction, thought and purpose for such construction. Accordingly, many sages refer to the Outer Planes as divine planes, spiritual planes, or godly planes, for the Outer Planes are best known as the homes of deities.\n\nWhen discussing anything to do with deities, the language used must be highly metaphorical. Their actual homes are not literally “places” at all, but exemplify the idea that the Outer Planes are realms of thought and spirit. As with the Elemental Planes, one can imagine the perceptible part of the Outer Planes as a sort of border region, while extensive spiritual regions lie beyond ordinary sensory experience.\n\nEven in those perceptible regions, appearances can be deceptive. Initially, many of the Outer Planes appear hospitable and familiar to natives of the Material Plane. But the landscape can change at the whims of the powerful forces that live on the Outer Planes. The desires of the mighty forces that dwell on these planes can remake them completely, effectively erasing and rebuilding existence itself to better fulfill their own needs.\n\nDistance is a virtually meaningless concept on the Outer Planes. The perceptible regions of the planes often seem quite small, but they can also stretch on to what seems like infinity. It might be possible to take a guided tour of the Nine Hells, from the first layer to the ninth, in a single day-if the powers of the Hells desire it. Or it could take weeks for travelers to make a grueling trek across a single layer.\n\nThe most well-known Outer Planes are a group of sixteen planes that correspond to the eight alignments (excluding neutrality) and the shades of distinction between them.\n\n### Outer Planes\n\nThe planes with some element of good in their nature are called the **Upper Planes**. Celestial creatures such as angels and pegasi dwell in the Upper Planes. Planes with some element of evil are the **Lower Planes**. Fiends such as demons and devils dwell in the Lower Planes. A plane's alignment is its essence, and a character whose alignment doesn't match the plane's experiences a profound sense of dissonance there. When a good creature visits Elysium, for example (a neutral good Upper Plane), it feels in tune with the plane, but an evil creature feels out of tune and more than a little uncomfortable.\n\n### Demiplanes\n\nDemiplanes are small extradimensional spaces with their own unique rules. They are pieces of reality that don't seem to fit anywhere else. Demiplanes come into being by a variety of means. Some are created by spells, such as _demiplane_, or generated at the desire of a powerful deity or other force. They may exist naturally, as a fold of existing reality that has been pinched off from the rest of the multiverse, or as a baby universe growing in power. A given demiplane can be entered through a single point where it touches another plane. Theoretically, a _plane shift_ spell can also carry travelers to a demiplane, but the proper frequency required for the tuning fork is extremely hard to acquire. The _gate_ spell is more reliable, assuming the caster knows of the demiplane.",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Rules"
        },
        {
            "slug": "poisons",
            "name": "Poisons",
            "desc": "Given their insidious and deadly nature, poisons are illegal in most societies but are a favorite tool among assassins, drow, and other evil creatures.\n\nPoisons come in the following four types.\n\n**_Contact_**. Contact poison can be smeared on an object and remains potent until it is touched or washed off. A creature that touches contact poison with exposed skin suffers its effects.\n\n**_Ingested_**. A creature must swallow an entire dose of ingested poison to suffer its effects. The dose can be delivered in food or a liquid. You may decide that a partial dose has a reduced effect, such as allowing advantage on the saving throw or dealing only half damage on a failed save.\n\n**_Inhaled_**. These poisons are powders or gases that take effect when inhaled. Blowing the powder or releasing the gas subjects creatures in a 5-foot cube to its effect. The resulting cloud dissipates immediately afterward. Holding one's breath is ineffective against inhaled poisons, as they affect nasal membranes, tear ducts, and other parts of the body.\n\n**_Injury_**. Injury poison can be applied to weapons, ammunition, trap components, and other objects that deal piercing or slashing damage and remains potent until delivered through a wound or washed off. A creature that takes piercing or slashing damage from an object coated with the poison is exposed to its effects.\n\n**Poisons (table)**\n| Item               | Type     | Price per Dose |\n|--------------------|----------|----------------|\n| Assassin's blood   | Ingested | 150 gp         |\n| Burnt othur fumes  | Inhaled  | 500 gp         |\n| Crawler mucus      | Contact  | 200 gp         |\n| Drow poison        | Injury   | 200 gp         |\n| Essence of ether   | Inhaled  | 300 gp         |\n| Malice             | Inhaled  | 250 gp         |\n| Midnight tears     | Ingested | 1,500 gp       |\n| Oil of taggit      | Contact  | 400 gp         |\n| Pale tincture      | Ingested | 250 gp         |\n| Purple worm poison | Injury   | 2,000 gp       |\n| Serpent venom      | Injury   | 200 gp         |\n| Torpor             | Ingested | 600 gp         |\n| Truth serum        | Ingested | 150 gp         |\n| Wyvern poison      | Injury   | 1,200 gp       |\n\n## Sample Poisons\n\nEach type of poison has its own debilitating effects.\n\n **_Assassin's Blood (Ingested)_**. A creature subjected to this poison must make a DC 10 Constitution saving throw. On a failed save, it takes 6 (1d12) poison damage and is poisoned for 24 hours. On a successful save, the creature takes half damage and isn't poisoned.\n\n **_Burnt Othur Fumes (Inhaled)_**. A creature subjected to this poison must succeed on a DC 13 Constitution saving throw or take 10 (3d6) poison damage, and must repeat the saving throw at the start of each of its turns. On each successive failed save, the character takes 3 (1d6) poison damage. After three successful saves, the poison ends.\n\n **_Crawler Mucus (Contact)_**. This poison must be harvested from a dead or incapacitated crawler. A creature subjected to this poison must succeed on a DC 13 Constitution saving throw or be poisoned for 1 minute. The poisoned creature is paralyzed. The creature can repeat the saving throw at the end of each of its turns, ending the effect on itself on a success.\n\n **_Drow Poison (Injury)_**. This poison is typically made only by the drow, and only in a place far removed from sunlight. A creature subjected to this poison must succeed on a DC 13 Constitution saving throw or be poisoned for 1 hour. If the saving throw fails by 5 or more, the creature is also unconscious while poisoned in this way. The creature wakes up if it takes damage or if another creature takes an action to shake it awake.\n\n **_Essence of Ether (Inhaled)_**. A creature subjected to this poison must succeed on a DC 15 Constitution saving throw or become poisoned for 8 hours. The poisoned creature is unconscious. The creature wakes up if it takes damage or if another creature takes an action to shake it awake.\n\n **_Malice (Inhaled)_**. A creature subjected to this poison must succeed on a DC 15 Constitution saving throw or become poisoned for 1 hour. The poisoned creature is blinded.\n\n **_Midnight Tears (Ingested)_**. A creature that ingests this poison suffers no effect until the stroke of midnight. If the poison has not been neutralized before then, the creature must succeed on a DC 17 Constitution saving throw, taking 31 (9d6) poison damage on a failed save, or half as much damage on a successful one.\n\n **_Oil of Taggit (Contact)_**. A creature subjected to this poison must succeed on a DC 13 Constitution saving throw or become poisoned for 24 hours. The poisoned creature is unconscious. The creature wakes up if it takes damage.\n\n **_Pale Tincture (Ingested)_**. A creature subjected to this poison must succeed on a DC 16 Constitution saving throw or take 3 (1d6) poison damage and become poisoned. The poisoned creature must repeat the saving throw every 24 hours, taking 3 (1d6) poison damage on a failed save. Until this poison ends, the damage the poison deals can't be healed by any means. After seven successful saving throws, the effect ends and the creature can heal normally.\n\n **_Purple Worm Poison (Injury)_**. This poison must be harvested from a dead or incapacitated purple worm. A creature subjected to this poison must make a DC 19 Constitution saving throw, taking 42 (12d6) poison damage on a failed save, or half as much damage on a successful one.\n\n **_Serpent Venom (Injury)_**. This poison must be harvested from a dead or incapacitated giant poisonous snake. A creature subjected to this poison must succeed on a DC 11 Constitution saving throw, taking 10 (3d6) poison damage on a failed save, or half as much damage on a successful one.\n\n **_Torpor (Ingested)_**. A creature subjected to this poison must succeed on a DC 15 Constitution saving throw or become poisoned for 4d6 hours. The poisoned creature is incapacitated.\n\n **_Truth Serum (Ingested)_**. A creature subjected to this poison must succeed on a DC 11 Constitution saving throw or become poisoned for 1 hour. The poisoned creature can't knowingly speak a lie, as if under the effect of a _zone of truth_ spell.\n\n **_Wyvern Poison (Injury)_**. This poison must be harvested from a dead or incapacitated wyvern. A creature subjected to this poison must make a DC 15 Constitution saving throw, taking 24 (7d6) poison damage on a failed save, or half as much damage on a successful one.",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Rules"
        },
        {
            "slug": "races",
            "name": "Races",
            "desc": "## Racial Traits\n\nThe description of each race includes racial traits that are common to members of that race. The following entries appear among the traits of most races.\n\n### Ability Score Increase\n\nEvery race increases one or more of a character’s ability scores.\n\n### Age\n\nThe age entry notes the age when a member of the race is considered an adult, as well as the race’s expected lifespan. This information can help you decide how old your character is at the start of the game. You can choose any age for your character, which could provide an explanation for some of your ability scores. For example, if you play a young or very old character, your age could explain a particularly low Strength or Constitution score, while advanced age could account for a high Intelligence or Wisdom.\n\n### Alignment\n\nMost races have tendencies toward certain alignments, described in this entry. These are not binding for player characters, but considering why your dwarf is chaotic, for example, in defiance of lawful dwarf society can help you better define your character.\n\n### Size\n\nCharacters of most races are Medium, a size category including creatures that are roughly 4 to 8 feet tall. Members of a few races are Small (between 2 and 4 feet tall), which means that certain rules of the game affect them differently. The most important of these rules is that Small characters have trouble wielding heavy weapons, as explained in \"Equipment.\"\n\n### Speed\n\nYour speed determines how far you can move when traveling ( \"Adventuring\") and fighting (\"Combat\").\n\n### Languages\n\nBy virtue of your race, your character can speak, read, and write certain languages.\n\n### Subraces\n\nSome races have subraces. Members of a subrace have the traits of the parent race in addition to the traits specified for their subrace. Relationships among subraces vary significantly from race to race and world to world.",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Characters"
        },
        {
            "slug": "rest",
            "name": "Rest",
            "desc": "Heroic though they might be, adventurers can't spend every hour of theday in the thick of exploration, social interaction, and combat. They need rest---time to sleep and eat, tend their wounds, refresh theirminds and spirits for spellcasting, and brace themselves for furtheradventure.\n\nAdventurers can take short rests in the midst of an adventuring day anda long rest to end the day.\n\n## Short Rest\n\nA short rest is a period of downtime, at least 1 hour long, during whicha character does nothing more strenuous than eating, drinking, reading, and tending to wounds.\n\nA character can spend one or more Hit Dice at the end of a short rest, up to the character's maximum number of Hit Dice, which is equal to the character's level. For each Hit Die spent in this way, the player rollsthe die and adds the character's Constitution modifier to it. the character regains hit points equal to the total. The player can decideto spend an additional Hit Die after each roll. A character regains somespent Hit Dice upon finishing a long rest, as explained below.\n\n## Long Rest\n\nA long rest is a period of extended downtime, at least 8 hours long, during which a character sleeps or performs light activity: reading,talking, eating, or standing watch for no more than 2 hours. If the rest is interrupted by a period of strenuous activity---at least 1 hour ofwalking, fighting, casting spells, or similar adventuring activity---the characters must begin the rest again to gain any benefit from it.\n\nAt the end of a long rest, a character regains all lost hit points. The character also regains spent Hit Dice, up to a number of dice equal to half of the character's total number of them (minimum of one die). For example, if a character has eight Hit Dice, he or she can regain four spent Hit Dice upon finishing a long rest.\n\nA character can't benefit from more than one long rest in a 24-hour period, and a character must have at least 1 hit point at the start of the rest to gain its benefits.",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Gameplay Mechanics"
        },
        {
            "slug": "saving-throws",
            "name": "Saving Throws",
            "desc": "A saving throw---also called a save---represents an attempt to resist a spell, a trap, a poison, a disease, or a similar threat. You don't normally decide to make a saving throw; you are forced to make one because your character or monster is at risk of harm.\n\nTo make a saving throw, roll a d20 and add the appropriate ability modifier. For example, you use your Dexterity modifier for a Dexterity saving throw.\n\nA saving throw can be modified by a situational bonus or penalty and can be affected by advantage and disadvantage, as determined by the GM.\n\nEach class gives proficiency in at least two saving throws. The wizard, for example, is proficient in Intelligence saves. As with skill proficiencies, proficiency in a saving throw lets a character add his or her proficiency bonus to saving throws made using a particular ability score. Some monsters have saving throw proficiencies as well. The Difficulty Class for a saving throw is determined by the effect that causes it. For example, the DC for a saving throw allowed by a spell is determined by the caster's spellcasting ability and proficiency bonus.\n\nThe result of a successful or failed saving throw is also detailed in the effect that allows the save. Usually, a successful save means that a creature suffers no harm, or reduced harm, from an effect.",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Gameplay Mechanics"
        },
        {
            "slug": "selling-treasure",
            "name": "Selling Treasure",
            "desc": "Opportunities abound to find treasure, equipment, weapons, armor, and more in the dungeons you explore. Normally, you can sell your treasures and trinkets when you return to a town or other settlement, provided that you can find buyers and merchants interested in your loot.\n\n**_Arms, Armor, and Other Equipment._** As a general rule, undamaged weapons, armor, and other equipment fetch half their cost when sold in a market. Weapons and armor used by monsters are rarely in good enough condition to sell.\n\n**_Magic Items._** Selling magic items is problematic. Finding someone to buy a potion or a scroll isn't too hard, but other items are out of the realm of most but the wealthiest nobles. Likewise, aside from a few common magic items, you won't normally come across magic items or spells to purchase. The value of magic is far beyond simple gold and should always be treated as such.\n\n**_Gems, Jewelry, and Art Objects._** These items retain their full value in the marketplace, and you can either trade them in for coin or use them as currency for other transactions. For exceptionally valuable treasures, the GM might require you to find a buyer in a large town or larger community first.\n\n**_Trade Goods._** On the borderlands, many people conduct transactions through barter. Like gems and art objects, trade goods-bars of iron, bags of salt, livestock, and so on-retain their full value in the market and can be used as currency.",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Equipment"
        },
        {
            "slug": "spellcasting",
            "name": "Spellcasting",
            "desc": "Magic permeates fantasy gaming worlds and often appears in the form of a spell.\n\nThis chapter provides the rules for casting spells. Different character classes have distinctive ways of learning and preparing their spells, and monsters use spells in unique ways. Regardless of its source, a spell follows the rules here.\n\n## What Is a Spell?\n\nA spell is a discrete magical effect, a single shaping of the magical energies that suffuse the multiverse into a specific, limited expression. In casting a spell, a character carefully plucks at the invisible strands of raw magic suffusing the world, pins them in place in a particular pattern, sets them vibrating in a specific way, and then releases them to unleash the desired effect-in most cases, all in the span of seconds.\n\nSpells can be versatile tools, weapons, or protective wards. They can deal damage or undo it, impose or remove conditions (see appendix A), drain life energy away, and restore life to the dead.\n\nUncounted thousands of spells have been created over the course of the multiverse's history, and many of them are long forgotten. Some might yet lie recorded in crumbling spellbooks hidden in ancient ruins or trapped in the minds of dead gods. Or they might someday be reinvented by a character who has amassed enough power and wisdom to do so.\n\n## Spell Level\n\nEvery spell has a level from 0 to 9. A spell's level is a general indicator of how powerful it is, with the lowly (but still impressive) _magic missile_ at 1st level and the earth-shaking _wish_ at 9th. Cantrips-simple but powerful spells that characters can cast almost by rote-are level 0. The higher a spell's level, the higher level a spellcaster must be to use that spell.\n\nSpell level and character level don't correspond directly. Typically, a character has to be at least 17th level, not 9th level, to cast a 9th-level spell.\n\n## Known and Prepared Spells\n\nBefore a spellcaster can use a spell, he or she must have the spell firmly fixed in mind, or must have access to the spell in a magic item. Members of a few classes, including bards and sorcerers, have a limited list of spells they know that are always fixed in mind. The same thing is true of many magic-using monsters. Other spellcasters, such as clerics and wizards, undergo a process of preparing spells. This process varies for different classes, as detailed in their descriptions.\n\nIn every case, the number of spells a caster can have fixed in mind at any given time depends on the character's level.\n\n## Spell Slots\n\nRegardless of how many spells a caster knows or prepares, he or she can cast only a limited number of spells before resting. Manipulating the fabric of magic and channeling its energy into even a simple spell is physically and mentally taxing, and higher level spells are even more so. Thus, each spellcasting class's description (except that of the warlock) includes a table showing how many spell slots of each spell level a character can use at each character level. For example, the 3rd-level wizard Umara has four 1st-level spell slots and two 2nd-level slots.\n\nWhen a character casts a spell, he or she expends a slot of that spell's level or higher, effectively “filling” a slot with the spell. You can think of a spell slot as a groove of a certain size-small for a 1st-level slot, larger for a spell of higher level. A 1st-level spell fits into a slot of any size, but a 9th-level spell fits only in a 9th-level slot. So when Umara casts _magic missile_, a 1st-level spell, she spends one of her four 1st-level slots and has three remaining.\n\nFinishing a long rest restores any expended spell slots.\n\nSome characters and monsters have special abilities that let them cast spells without using spell slots. For example, a monk who follows the Way of the Four Elements, a warlock who chooses certain eldritch invocations, and a pit fiend from the Nine Hells can all cast spells in such a way.\n\n### Casting a Spell at a Higher Level\n\nWhen a spellcaster casts a spell using a slot that is of a higher level than the spell, the spell assumes the higher level for that casting. For instance, if Umara casts _magic missile_ using one of her 2nd-level slots, that _magic missile_ is 2nd level. Effectively, the spell expands to fill the slot it is put into.\n\nSome spells, such as _magic missile_ and _cure wounds_, have more powerful effects when cast at a higher level, as detailed in a spell's description.\n\n> ## Casting in Armor\n>\n>Because of the mental focus and precise gestures required for spellcasting, you must be proficient with the armor you are wearing to cast a spell. You are otherwise too distracted and physically hampered by your armor for spellcasting.\n\n## Cantrips\n\nA cantrip is a spell that can be cast at will, without using a spell slot and without being prepared in advance. Repeated practice has fixed the spell in the caster's mind and infused the caster with the magic needed to produce the effect over and over. A cantrip's spell level is 0.\n\n## Rituals\n\nCertain spells have a special tag: ritual. Such a spell can be cast following the normal rules for spellcasting, or the spell can be cast as a ritual. The ritual version of a spell takes 10 minutes longer to cast than normal. It also doesn't expend a spell slot, which means the ritual version of a spell can't be cast at a higher level.\n\nTo cast a spell as a ritual, a spellcaster must have a feature that grants the ability to do so. The cleric and the druid, for example, have such a feature. The caster must also have the spell prepared or on his or her list of spells known, unless the character's ritual feature specifies otherwise, as the wizard's does.\n\n## Casting a Spell\n\nWhen a character casts any spell, the same basic rules are followed, regardless of the character's class or the spell's effects.\n\nEach spell description begins with a block of information, including the spell's name, level, school of magic, casting time, range, components, and duration. The rest of a spell entry describes the spell's effect.\n\n## Casting Time\n\nMost spells require a single action to cast, but some spells require a bonus action, a reaction, or much more time to cast.\n\n### Bonus Action\n\nA spell cast with a bonus action is especially swift. You must use a bonus action on your turn to cast the spell, provided that you haven't already taken a bonus action this turn. You can't cast another spell during the same turn, except for a cantrip with a casting time of 1 action.\n\n### Reactions\n\nSome spells can be cast as reactions. These spells take a fraction of a second to bring about and are cast in response to some event. If a spell can be cast as a reaction, the spell description tells you exactly when you can do so.\n\n### Longer Casting Times\n\nCertain spells (including spells cast as rituals) require more time to cast: minutes or even hours. When you cast a spell with a casting time longer than a single action or reaction, you must spend your action each turn casting the spell, and you must maintain your concentration while you do so (see “Concentration” below). If your concentration is broken, the spell fails, but you don't expend a spell slot. If you want to try casting the spell again, you must start over.\n\n## Spell Range\n\nThe target of a spell must be within the spell's range. For a spell like _magic missile_, the target is a creature. For a spell like _fireball_, the target is the point in space where the ball of fire erupts.\n\nMost spells have ranges expressed in feet. Some spells can target only a creature (including you) that you touch. Other spells, such as the _shield_ spell, affect only you. These spells have a range of self.\n\nSpells that create cones or lines of effect that originate from you also have a range of self, indicating that the origin point of the spell's effect must be you (see “Areas of Effect” later in the this chapter).\n\nOnce a spell is cast, its effects aren't limited by its range, unless the spell's description says otherwise.\n\n## Components\n\nA spell's components are the physical requirements you must meet in order to cast it. Each spell's description indicates whether it requires verbal (V), somatic (S), or material (M) components. If you can't provide one or more of a spell's components, you are unable to cast the spell.\n\n### Verbal (V)\n\nMost spells require the chanting of mystic words. The words themselves aren't the source of the spell's power; rather, the particular combination of sounds, with specific pitch and resonance, sets the threads of magic in motion. Thus, a character who is gagged or in an area of silence, such as one created by the _silence_ spell, can't cast a spell with a verbal component.\n\n### Somatic (S)\n\nSpellcasting gestures might include a forceful gesticulation or an intricate set of gestures. If a spell requires a somatic component, the caster must have free use of at least one hand to perform these gestures.\n\n### Material (M)\n\nCasting some spells requires particular objects, specified in parentheses in the component entry. A character can use a **component pouch** or a **spellcasting focus** (found in “Equipment”) in place of the components specified for a spell. But if a cost is indicated for a component, a character must have that specific component before he or she can cast the spell.\n\nIf a spell states that a material component is consumed by the spell, the caster must provide this component for each casting of the spell.\n\nA spellcaster must have a hand free to access a spell's material components-or to hold a spellcasting focus-but it can be the same hand that he or she uses to perform somatic components.\n\n## Duration\n\nA spell's duration is the length of time the spell persists. A duration can be expressed in rounds, minutes, hours, or even years. Some spells specify that their effects last until the spells are dispelled or destroyed.\n\n### Instantaneous\n\nMany spells are instantaneous. The spell harms, heals, creates, or alters a creature or an object in a way that can't be dispelled, because its magic exists only for an instant.\n\n### Concentration\n\nSome spells require you to maintain concentration in order to keep their magic active. If you lose concentration, such a spell ends.\n\nIf a spell must be maintained with concentration, that fact appears in its Duration entry, and the spell specifies how long you can concentrate on it. You can end concentration at any time (no action required).\n\nNormal activity, such as moving and attacking, doesn't interfere with concentration. The following factors can break concentration:\n\n* **Casting another spell that requires concentration.** You lose concentration on a spell if you cast another spell that requires concentration. You can't concentrate on two spells at once.\n* **Taking damage.** Whenever you take damage while you are concentrating on a spell, you must make a Constitution saving throw to maintain your concentration. The DC equals 10 or half the damage you take, whichever number is higher. If you take damage from multiple sources, such as an arrow and a dragon's breath, you make a separate saving throw for each source of damage.\n* **Being incapacitated or killed.** You lose concentration on a spell if you are incapacitated or if you die.\n\nThe GM might also decide that certain environmental phenomena, such as a wave crashing over you while you're on a storm-tossed ship, require you to succeed on a DC 10 Constitution saving throw to maintain concentration on a spell.\n\n## Targets\n\nA typical spell requires you to pick one or more targets to be affected by the spell's magic. A spell's description tells you whether the spell targets creatures, objects, or a point of origin for an area of effect (described below).\n\nUnless a spell has a perceptible effect, a creature might not know it was targeted by a spell at all. An effect like crackling lightning is obvious, but a more subtle effect, such as an attempt to read a creature's thoughts, typically goes unnoticed, unless a spell says otherwise.\n\n### A Clear Path to the Target\n\nTo target something, you must have a clear path to it, so it can't be behind total cover.\n\nIf you place an area of effect at a point that you can't see and an obstruction, such as a wall, is between you and that point, the point of origin comes into being on the near side of that obstruction.\n\n### Targeting Yourself\n\nIf a spell targets a creature of your choice, you can choose yourself, unless the creature must be hostile or specifically a creature other than you. If you are in the area of effect of a spell you cast, you can target yourself.\n\n## Areas of Effect\n\nSpells such as _burning hands_ and _cone of cold_ cover an area, allowing them to affect multiple creatures at once.\n\nA spell's description specifies its area of effect, which typically has one of five different shapes: cone, cube, cylinder, line, or sphere. Every area of effect has a **point of origin**, a location from which the spell's energy erupts. The rules for each shape specify how you position its point of origin. Typically, a point of origin is a point in space, but some spells have an area whose origin is a creature or an object.\n\nA spell's effect expands in straight lines from the point of origin. If no unblocked straight line extends from the point of origin to a location within the area of effect, that location isn't included in the spell's area. To block one of these imaginary lines, an obstruction must provide total cover.\n\n### Cone\n\nA cone extends in a direction you choose from its point of origin. A cone's width at a given point along its length is equal to that point's distance from the point of origin. A cone's area of effect specifies its maximum length.\n\nA cone's point of origin is not included in the cone's area of effect, unless you decide otherwise.\n\n### Cube\n\nYou select a cube's point of origin, which lies anywhere on a face of the cubic effect. The cube's size is expressed as the length of each side.\n\nA cube's point of origin is not included in the cube's area of effect, unless you decide otherwise.\n\n### Cylinder\n\nA cylinder's point of origin is the center of a circle of a particular radius, as given in the spell description. The circle must either be on the ground or at the height of the spell effect. The energy in a cylinder expands in straight lines from the point of origin to the perimeter of the circle, forming the base of the cylinder. The spell's effect then shoots up from the base or down from the top, to a distance equal to the height of the cylinder.\n\nA cylinder's point of origin is included in the cylinder's area of effect.\n\n### Line\n\nA line extends from its point of origin in a straight path up to its length and covers an area defined by its width.\n\nA line's point of origin is not included in the line's area of effect, unless you decide otherwise.\n\n### Sphere\n\nYou select a sphere's point of origin, and the sphere extends outward from that point. The sphere's size is expressed as a radius in feet that extends from the point.\n\nA sphere's point of origin is included in the sphere's area of effect.\n\n## Spell Saving Throws\n\nMany spells specify that a target can make a saving throw to avoid some or all of a spell's effects. The spell specifies the ability that the target uses for the save and what happens on a success or failure.\n\nThe DC to resist one of your spells equals 8 + your spellcasting ability modifier + your proficiency bonus + any special modifiers.\n\n## Spell Attack Rolls\n\nSome spells require the caster to make an attack roll to determine whether the spell effect hits the intended target. Your attack bonus with a spell attack equals your spellcasting ability modifier + your proficiency bonus.\n\nMost spells that require attack rolls involve ranged attacks. Remember that you have disadvantage on a ranged attack roll if you are within 5 feet of a hostile creature that can see you and that isn't incapacitated.\n\n> ## The Schools of Magic\n>\n> Academies of magic group spells into eight categories called schools of magic. Scholars, particularly wizards, apply these categories to all spells, believing that all magic functions in essentially the same way, whether it derives from rigorous study or is bestowed by a deity.\n>\n> The schools of magic help describe spells; they have no rules of their own, although some rules refer to the schools.\n>\n> **Abjuration** spells are protective in nature, though some of them have aggressive uses. They create magical barriers, negate harmful effects, harm trespassers, or banish creatures to other planes of existence.\n>\n> **Conjuration** spells involve the transportation of objects and creatures from one location to another. Some spells summon creatures or objects to the caster's side, whereas others allow the caster to teleport to another location. Some conjurations create objects or effects out of nothing.\n>\n> **Divination** spells reveal information, whether in the form of secrets long forgotten, glimpses of the future, the locations of hidden things, the truth behind illusions, or visions of distant people or places.\n>\n> **Enchantment** spells affect the minds of others, influencing or controlling their behavior. Such spells can make enemies see the caster as a friend, force creatures to take a course of action, or even control another creature like a puppet.\n>\n> **Evocation** spells manipulate magical energy to produce a desired effect. Some call up blasts of fire or lightning. Others channel positive energy to heal wounds.\n>\n> **Illusion** spells deceive the senses or minds of others. They cause people to see things that are not there, to miss things that are there, to hear phantom noises, or to remember things that never happened. Some illusions create phantom images that any creature can see, but the most insidious illusions plant an image directly in the mind of a creature.\n>\n> **Necromancy** spells manipulate the energies of life and death. Such spells can grant an extra reserve of life force, drain the life energy from another creature, create the undead, or even bring the dead back to life.\n>\n> Creating the undead through the use of necromancy spells such as _animate dead_ is not a good act, and only evil casters use such spells frequently.\n>\n> **Transmutation** spells change the properties of a creature, object, or environment. They might turn an enemy into a harmless creature, bolster the strength of an ally, make an object move at the caster's command, or enhance a creature's innate healing abilities to rapidly recover from injury.\n\n## Combining Magical Effects\n\nThe effects of different spells add together while the durations of those spells overlap. The effects of the same spell cast multiple times don't combine, however. Instead, the most potent effect-such as the highest bonus-from those castings applies while their durations overlap.\n\nFor example, if two clerics cast _bless_ on the same target, that character gains the spell's benefit only once; he or she doesn't get to roll two bonus dice.",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Gameplay Mechanics"
        },
        {
            "slug": "time",
            "name": "Time",
            "desc": "In situations where keeping track of the passage of time is important, the GM determines the time a task requires. The GM might use a different time scale depending on the context of the situation at hand. In a dungeon environment, the adventurers' movement happens on a scale of **minutes**. It takes them about a minute to creep down a long hallway, another minute to check for traps on the door at the end of the hall, and a good ten minutes to search the chamber beyond for anything interesting or valuable. In a city or wilderness, a scale of **hours** is often more appropriate. Adventurers eager to reach the lonely tower at the heart of the forest hurry across those fifteen miles in just under four hours' time.\n\nFor long journeys, a scale of **days** works best. Following the road from Baldur's Gate to Waterdeep, the adventurers spend four uneventful days before a goblin ambush interrupts their journey.\n\nIn combat and other fast-paced situations, the game relies on **rounds**, a 6-second span of time.",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Gameplay Mechanics"
        },
        {
            "slug": "tools",
            "name": "Tools",
            "desc": "A tool helps you to do something you couldn't otherwise do, such as craft or repair an item, forge a document, or pick a lock. Your race, class, background, or feats give you proficiency with certain tools. Proficiency with a tool allows you to add your proficiency bonus to any ability check you make using that tool. Tool use is not tied to a single ability, since proficiency with a tool represents broader knowledge of its use. For example, the GM might ask you to make a Dexterity check to carve a fine detail with your woodcarver's tools, or a Strength check to make something out of particularly hard wood.\n\n**Tools (table)**\n\n| Item                      | Cost  | Weight |\n|---------------------------|-------|--------|\n| **_Artisan's tools_**     |       |        |\n| - Alchemist's supplies    | 50 gp | 8 lb.  |\n| - Brewer's supplies       | 20 gp | 9 lb.  |\n| - Calligrapher's supplies | 10 gp | 5 lb.  |\n| - Carpenter's tools       | 8 gp  | 6 lb.  |\n| - Cartographer's tools    | 15 gp | 6 lb.  |\n| - Cobbler's tools         | 5 gp  | 5 lb.  |\n| - Cook's utensils         | 1 gp  | 8 lb.  |\n| - Glassblower's tools     | 30 gp | 5 lb.  |\n| - Jeweler's tools         | 25 gp | 2 lb.  |\n| - Leatherworker's tools   | 5 gp  | 5 lb.  |\n| - Mason's tools           | 10 gp | 8 lb.  |\n| - Painter's supplies      | 10 gp | 5 lb.  |\n| - Potter's tools          | 10 gp | 3 lb.  |\n| - Smith's tools           | 20 gp | 8 lb.  |\n| - Tinker's tools          | 50 gp | 10 lb. |\n| - Weaver's tools          | 1 gp  | 5 lb.  |\n| - Woodcarver's tools      | 1 gp  | 5 lb.  |\n| Disguise kit              | 25 gp | 3 lb.  |\n| Forgery kit               | 15 gp | 5 lb.  |\n| **_Gaming set_**          |       |        |\n| - Dice set                | 1 sp  | -      |\n| - Playing card set        | 5 sp  | -      |\n| Herbalism kit             | 5 gp  | 3 lb.  |\n| **_Musical instrument_**  |       |        |\n| - Bagpipes                | 30 gp | 6 lb.  |\n| - Drum                    | 6 gp  | 3 lb.  |\n| - Dulcimer                | 25 gp | 10 lb. |\n| - Flute                   | 2 gp  | 1 lb.  |\n| - Lute                    | 35 gp | 2 lb.  |\n| - Lyre                    | 30 gp | 2 lb.  |\n| - Horn                    | 3 gp  | 2 lb.  |\n| - Pan flute               | 12 gp | 2 lb.  |\n| - Shawm                   | 2 gp  | 1 lb.  |\n| - Viol                    | 30 gp | 1 lb.  |\n| Navigator's tools         | 25 gp | 2 lb.  |\n| Poisoner's kit            | 50 gp | 2 lb.  |\n| Thieves' tools            | 25 gp | 1 lb.  |\n| Vehicles (land or water)  | \\*    | \\*     |\n\n\\* See the “Mounts and Vehicles” section.\n\n**_Artisan's Tools._** These special tools include the items needed to pursue a craft or trade. The table shows examples of the most common types of tools, each providing items related to a single craft. Proficiency with a set of artisan's tools lets you add your proficiency bonus to any ability checks you make using the tools in your craft. Each type of artisan's tools requires a separate proficiency.\n\n**_Disguise Kit._** This pouch of cosmetics, hair dye, and small props lets you create disguises that change your physical appearance. Proficiency with this kit lets you add your proficiency bonus to any ability checks you make to create a visual disguise.\n\n**_Forgery Kit._** This small box contains a variety of papers and parchments, pens and inks, seals and sealing wax, gold and silver leaf, and other supplies necessary to create convincing forgeries of physical documents. Proficiency with this kit lets you add your proficiency bonus to any ability checks you make to create a physical forgery of a document.\n\n**_Gaming Set._** This item encompasses a wide range of game pieces, including dice and decks of cards (for games such as Three-Dragon Ante). A few common examples appear on the Tools table, but other kinds of gaming sets exist. If you are proficient with a gaming set, you can add your proficiency bonus to ability checks you make to play a game with that set. Each type of gaming set requires a separate proficiency.\n\n**_Herbalism Kit._** This kit contains a variety of instruments such as clippers, mortar and pestle, and pouches and vials used by herbalists to create remedies and potions. Proficiency with this kit lets you add your proficiency bonus to any ability checks you make to identify or apply herbs. Also, proficiency with this kit is required to create antitoxin and potions of healing.\n\n**_Musical Instrument._** Several of the most common types of musical instruments are shown on the table as examples. If you have proficiency with a given musical instrument, you can add your proficiency bonus to any ability checks you make to play music with the instrument. A bard can use a musical instrument as a spellcasting focus. Each type of musical instrument requires a separate proficiency.\n\n**_Navigator's Tools._** This set of instruments is used for navigation at sea. Proficiency with navigator's tools lets you chart a ship's course and follow navigation charts. In addition, these tools allow you to add your proficiency bonus to any ability check you make to avoid getting lost at sea.\n\n**_Poisoner's Kit._** A poisoner's kit includes the vials, chemicals, and other equipment necessary for the creation of poisons. Proficiency with this kit lets you add your proficiency bonus to any ability checks you make to craft or use poisons.\n\n**_Thieves' Tools._** This set of tools includes a small file, a set of lock picks, a small mirror mounted on a metal handle, a set of narrow-bladed scissors, and a pair of pliers. Proficiency with these tools lets you add your proficiency bonus to any ability checks you make to disarm traps or open locks.",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Equipment"
        },
        {
            "slug": "trade-goods",
            "name": "Trade Goods",
            "desc": "Most wealth is not in coins. It is measured in livestock, grain, land, rights to collect taxes, or rights to resources (such as a mine or a forest).\n\nGuilds, nobles, and royalty regulate trade. Chartered companies are granted rights to conduct trade along certain routes, to send merchant ships to various ports, or to buy or sell specific goods. Guilds set prices for the goods or services that they control, and determine who may or may not offer those goods and services. Merchants commonly exchange trade goods without using currency. The Trade Goods table shows the value of commonly exchanged goods.\n\n**Trade Goods (table)**\n\n| Cost   | Goods                                        |\n|--------|----------------------------------------------|\n| 1 cp   | 1 lb. of wheat                               |\n| 2 cp   | 1 lb. of flour or one chicken                |\n| 5 cp   | 1 lb. of salt                                |\n| 1 sp   | 1 lb. of iron or 1 sq. yd. of canvas         |\n| 5 sp   | 1 lb. of copper or 1 sq. yd. of cotton cloth |\n| 1 gp   | 1 lb. of ginger or one goat                  |\n| 2 gp   | 1 lb. of cinnamon or pepper, or one sheep    |\n| 3 gp   | 1 lb. of cloves or one pig                   |\n| 5 gp   | 1 lb. of silver or 1 sq. yd. of linen        |\n| 10 gp  | 1 sq. yd. of silk or one cow                 |\n| 15 gp  | 1 lb. of saffron or one ox                   |\n| 50 gp  | 1 lb. of gold                                |\n| 500 gp | 1 lb. of platinum                            |",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Equipment"
        },
        {
            "slug": "traps",
            "name": "Traps",
            "desc": "Traps can be found almost anywhere. One wrong step in an ancient tomb might trigger a series of scything blades, which cleave through armor and bone. The seemingly innocuous vines that hang over a cave entrance might grasp and choke anyone who pushes through them. A net hidden among the trees might drop on travelers who pass underneath. In a fantasy game, unwary adventurers can fall to their deaths, be burned alive, or fall under a fusillade of poisoned darts.\n\nA trap can be either mechanical or magical in nature. **Mechanical traps** include pits, arrow traps, falling blocks, water-filled rooms, whirling blades, and anything else that depends on a mechanism to operate. **Magic traps** are either magical device traps or spell traps. Magical device traps initiate spell effects when activated. Spell traps are spells such as _glyph of warding_ and _symbol_ that function as traps.\n\n## Traps in Play\n\nWhen adventurers come across a trap, you need to know how the trap is triggered and what it does, as well as the possibility for the characters to detect the trap and to disable or avoid it.\n\n### Triggering a Trap\n\nMost traps are triggered when a creature goes somewhere or touches something that the trap's creator wanted to protect. Common triggers include stepping on a pressure plate or a false section of floor, pulling a trip wire, turning a doorknob, and using the wrong key in a lock. Magic traps are often set to go off when a creature enters an area or touches an object. Some magic traps (such as the _glyph of warding_ spell) have more complicated trigger conditions, including a password that prevents the trap from activating.\n\n### Detecting and Disabling a Trap\n\nUsually, some element of a trap is visible to careful inspection. Characters might notice an uneven flagstone that conceals a pressure plate, spot the gleam of light off a trip wire, notice small holes in the walls from which jets of flame will erupt, or otherwise detect something that points to a trap's presence.\n\nA trap's description specifies the checks and DCs needed to detect it, disable it, or both. A character actively looking for a trap can attempt a Wisdom (Perception) check against the trap's DC. You can also compare the DC to detect the trap with each character's passive Wisdom (Perception) score to determine whether anyone in the party notices the trap in passing. If the adventurers detect a trap before triggering it, they might be able to disarm it, either permanently or long enough to move past it. You might call for an Intelligence (Investigation) check for a character to deduce what needs to be done, followed by a Dexterity check using thieves' tools to perform the necessary sabotage.\n\nAny character can attempt an Intelligence (Arcana) check to detect or disarm a magic trap, in addition to any other checks noted in the trap's description. The DCs are the same regardless of the check used. In addition, _dispel magic_ has a chance of disabling most magic traps. A magic trap's description provides the DC for the ability check made when you use _dispel magic_.\n\nIn most cases, a trap's description is clear enough that you can adjudicate whether a character's actions locate or foil the trap. As with many situations, you shouldn't allow die rolling to override clever play and good planning. Use your common sense, drawing on the trap's description to determine what happens. No trap's design can anticipate every possible action that the characters might attempt.\n\nYou should allow a character to discover a trap without making an ability check if an action would clearly reveal the trap's presence. For example, if a character lifts a rug that conceals a pressure plate, the character has found the trigger and no check is required.\n\nFoiling traps can be a little more complicated. Consider a trapped treasure chest. If the chest is opened without first pulling on the two handles set in its sides, a mechanism inside fires a hail of poison needles toward anyone in front of it. After inspecting the chest and making a few checks, the characters are still unsure if it's trapped. Rather than simply open the chest, they prop a shield in front of it and push the chest open at a distance with an iron rod. In this case, the trap still triggers, but the hail of needles fires harmlessly into the shield.\n\nTraps are often designed with mechanisms that allow them to be disarmed or bypassed. Intelligent monsters that place traps in or around their lairs need ways to get past those traps without harming themselves. Such traps might have hidden levers that disable their triggers, or a secret door might conceal a passage that goes around the trap.\n\n### Trap Effects\n\nThe effects of traps can range from inconvenient to deadly, making use of elements such as arrows, spikes, blades, poison, toxic gas, blasts of fire, and deep pits. The deadliest traps combine multiple elements to kill, injure, contain, or drive off any creature unfortunate enough to trigger them. A trap's description specifies what happens when it is triggered.\n\nThe attack bonus of a trap, the save DC to resist its effects, and the damage it deals can vary depending on the trap's severity. Use the Trap Save DCs and Attack Bonuses table and the Damage Severity by Level table for suggestions based on three levels of trap severity.\n\nA trap intended to be a **setback** is unlikely to kill or seriously harm characters of the indicated levels, whereas a **dangerous** trap is likely to seriously injure (and potentially kill) characters of the indicated levels. A **deadly** trap is likely to kill characters of the indicated levels.\n\n**Trap Save DCs and Attack Bonuses (table)**\n| Trap Danger | Save DC | Attack Bonus |\n|-------------|---------|--------------|\n| Setback     | 10-11   | +3 to +5     |\n| Dangerous   | 12-15   | +6 to +8     |\n| Deadly      | 16-20   | +9 to +12    |\n\n**Damage Severity by Level (table)**\n| Character Level | Setback | Dangerous | Deadly |\n|-----------------|---------|-----------|--------|\n| 1st-4th         | 1d10    | 2d10      | 4d10   |\n| 5th-10th        | 2d10    | 4d10      | 10d10  |\n| 11th-16th       | 4d10    | 10d10     | 18d10  |\n| 17th-20th       | 10d10   | 18d10     | 24d10  |\n\n### Complex Traps\n\nComplex traps work like standard traps, except once activated they execute a series of actions each round. A complex trap turns the process of dealing with a trap into something more like a combat encounter.\n\nWhen a complex trap activates, it rolls initiative. The trap's description includes an initiative bonus. On its turn, the trap activates again, often taking an action. It might make successive attacks against intruders, create an effect that changes over time, or otherwise produce a dynamic challenge. Otherwise, the complex trap can be detected and disabled or bypassed in the usual ways.\n\nFor example, a trap that causes a room to slowly flood works best as a complex trap. On the trap's turn, the water level rises. After several rounds, the room is completely flooded.\n\n## Sample Traps\n\nThe magical and mechanical traps presented here vary in deadliness and are presented in alphabetical order.\n\n### Collapsing Roof\n\n_Mechanical trap_\n\nThis trap uses a trip wire to collapse the supports keeping an unstable section of a ceiling in place.\n\nThe trip wire is 3 inches off the ground and stretches between two support beams. The DC to spot the trip wire is 10. A successful DC 15 Dexterity check using thieves' tools disables the trip wire harmlessly. A character without thieves' tools can attempt this check with disadvantage using any edged weapon or edged tool. On a failed check, the trap triggers.\n\nAnyone who inspects the beams can easily determine that they are merely wedged in place. As an action, a character can knock over a beam, causing the trap to trigger.\n\nThe ceiling above the trip wire is in bad repair, and anyone who can see it can tell that it's in danger of collapse.\n\nWhen the trap is triggered, the unstable ceiling collapses. Any creature in the area beneath the unstable section must succeed on a DC 15 Dexterity saving throw, taking 22 (4d10) bludgeoning damage on a failed save, or half as much damage on a successful one. Once the trap is triggered, the floor of the area is filled with rubble and becomes difficult terrain.\n\n### Falling Net\n\n_Mechanical trap_\n\nThis trap uses a trip wire to release a net suspended from the ceiling.\n\nThe trip wire is 3 inches off the ground and stretches between two columns or trees. The net is hidden by cobwebs or foliage. The DC to spot the trip wire and net is 10. A successful DC 15 Dexterity check using thieves' tools breaks the trip wire harmlessly. A character without thieves' tools can attempt this check with disadvantage using any edged weapon or edged tool. On a failed check, the trap triggers.\n\nWhen the trap is triggered, the net is released, covering a 10-foot-square area. Those in the area are trapped under the net and restrained, and those that fail a DC 10 Strength saving throw are also knocked prone. A creature can use its action to make a DC 10\n\nStrength check, freeing itself or another creature within its reach on a success. The net has AC 10 and 20 hit points. Dealing 5 slashing damage to the net (AC 10) destroys a 5-foot-square section of it, freeing any creature trapped in that section.\n\n### Fire-Breathing Statue\n\n_Magic trap_\n\nThis trap is activated when an intruder steps on a hidden pressure plate, releasing a magical gout of flame from a nearby statue. The statue can be of anything, including a dragon or a wizard casting a spell.\n\nThe DC is 15 to spot the pressure plate, as well as faint scorch marks on the floor and walls. A spell or other effect that can sense the presence of magic, such as _detect magic_, reveals an aura of evocation magic around the statue.\n\nThe trap activates when more than 20 pounds of weight is placed on the pressure plate, causing the statue to release a 30-foot cone of fire. Each creature in the fire must make a DC 13 Dexterity saving throw, taking 22 (4d10) fire damage on a failed save, or half as much damage on a successful one.\n\nWedging an iron spike or other object under the pressure plate prevents the trap from activating. A successful _dispel magic_ (DC 13) cast on the statue destroys the trap.\n\n### Pits\n\n_Mechanical trap_\n\nFour basic pit traps are presented here.\n\n**_Simple Pit_**. A simple pit trap is a hole dug in the ground. The hole is covered by a large cloth anchored on the pit's edge and camouflaged with dirt and debris.\n\nThe DC to spot the pit is 10. Anyone stepping on the cloth falls through and pulls the cloth down into the pit, taking damage based on the pit's depth (usually 10 feet, but some pits are deeper).\n\n**_Hidden Pit_**. This pit has a cover constructed from material identical to the floor around it.\n\nA successful DC 15 Wisdom (Perception) check discerns an absence of foot traffic over the section of floor that forms the pit's cover. A successful DC 15 Intelligence (Investigation) check is necessary to confirm that the trapped section of floor is actually the cover of a pit.\n\nWhen a creature steps on the cover, it swings open like a trapdoor, causing the intruder to spill into the pit below. The pit is usually 10 or 20 feet deep but can be deeper.\n\nOnce the pit trap is detected, an iron spike or similar object can be wedged between the pit's cover and the surrounding floor in such a way as to prevent the cover from opening, thereby making it safe to cross. The cover can also be magically held shut using the _arcane lock_ spell or similar magic.\n\n**_Locking Pit_**. This pit trap is identical to a hidden pit trap, with one key exception: the trap door that covers the pit is spring-loaded. After a creature falls into the pit, the cover snaps shut to trap its victim inside.\n\nA successful DC 20 Strength check is necessary to pry the cover open. The cover can also be smashed open. A character in the pit can also attempt to disable the spring mechanism from the inside with a DC 15 Dexterity check using thieves' tools, provided that the mechanism can be reached and the character can see. In some cases, a mechanism (usually hidden behind a secret door nearby) opens the pit.\n\n**_Spiked Pit_**. This pit trap is a simple, hidden, or locking pit trap with sharpened wooden or iron spikes at the bottom. A creature falling into the pit takes 11 (2d10) piercing damage from the spikes, in addition to any falling damage. Even nastier versions have poison smeared on the spikes. In that case, anyone taking piercing damage from the spikes must also make a DC 13 Constitution saving throw, taking an 22 (4d10) poison damage on a failed save, or half as much damage on a successful one.\n\n### Poison Darts\n\n_Mechanical trap_\n\nWhen a creature steps on a hidden pressure plate, poison-tipped darts shoot from spring-loaded or pressurized tubes cleverly embedded in the surrounding walls. An area might include multiple pressure plates, each one rigged to its own set of darts.\n\nThe tiny holes in the walls are obscured by dust and cobwebs, or cleverly hidden amid bas-reliefs, murals, or frescoes that adorn the walls. The DC to spot them is 15. With a successful DC 15 Intelligence (Investigation) check, a character can deduce the presence of the pressure plate from variations in the mortar and stone used to create it, compared to the surrounding floor. Wedging an iron spike or other object under the pressure plate prevents the trap from activating. Stuffing the holes with cloth or wax prevents the darts contained within from launching.\n\nThe trap activates when more than 20 pounds of weight is placed on the pressure plate, releasing four darts. Each dart makes a ranged attack with a +8\n\nbonus against a random target within 10 feet of the pressure plate (vision is irrelevant to this attack roll). (If there are no targets in the area, the darts don't hit anything.) A target that is hit takes 2 (1d4) piercing damage and must succeed on a DC 15 Constitution saving throw, taking 11 (2d10) poison damage on a failed save, or half as much damage on a successful one.\n\n### Poison Needle\n\n_Mechanical trap_\n\nA poisoned needle is hidden within a treasure chest's lock, or in something else that a creature might open. Opening the chest without the proper key causes the needle to spring out, delivering a dose of poison.\n\nWhen the trap is triggered, the needle extends 3 inches straight out from the lock. A creature within range takes 1 piercing damage and 11\n\n(2d10) poison damage, and must succeed on a DC 15 Constitution saving throw or be poisoned for 1 hour.\n\nA successful DC 20 Intelligence (Investigation) check allows a character to deduce the trap's presence from alterations made to the lock to accommodate the needle. A successful DC 15 Dexterity check using thieves' tools disarms the trap, removing the needle from the lock. Unsuccessfully attempting to pick the lock triggers the trap.\n\n### Rolling Sphere\n\n_Mechanical trap_\n\nWhen 20 or more pounds of pressure are placed on this trap's pressure plate, a hidden trapdoor in the ceiling opens, releasing a 10-foot-diameter rolling sphere of solid stone.\n\nWith a successful DC 15 Wisdom (Perception) check, a character can spot the trapdoor and pressure plate. A search of the floor accompanied by a successful DC 15 Intelligence (Investigation) check reveals variations in the mortar and stone that betray the pressure plate's presence. The same check made while inspecting the ceiling notes variations in the stonework that reveal the trapdoor. Wedging an iron spike or other object under the pressure plate prevents the trap from activating.\n\nActivation of the sphere requires all creatures present to roll initiative. The sphere rolls initiative with a +8 bonus. On its turn, it moves 60 feet in a straight line. The sphere can move through creatures' spaces, and creatures can move through its space, treating it as difficult terrain. Whenever the sphere enters a creature's space or a creature enters its space while it's rolling, that creature must succeed on a DC 15 Dexterity saving throw or take 55 (10d10) bludgeoning damage and be knocked prone.\n\nThe sphere stops when it hits a wall or similar barrier. It can't go around corners, but smart dungeon builders incorporate gentle, curving turns into nearby passages that allow the sphere to keep moving.\n\nAs an action, a creature within 5 feet of the sphere can attempt to slow it down with a DC 20 Strength check. On a successful check, the sphere's speed is reduced by 15 feet. If the sphere's speed drops to 0, it stops moving and is no longer a threat.\n\n### Sphere of Annihilation\n\n_Magic trap_\n\nMagical, impenetrable darkness fills the gaping mouth of a stone face carved into a wall. The mouth is 2 feet in diameter and roughly circular. No sound issues from it, no light can illuminate the inside of it, and any matter that enters it is instantly obliterated.\n\nA successful DC 20 Intelligence (Arcana) check reveals that the mouth contains a _sphere of annihilation_ that can't be controlled or moved. It is otherwise identical to a normal _sphere of annihilation_.\n\nSome versions of the trap include an enchantment placed on the stone face, such that specified creatures feel an overwhelming urge to approach it and crawl inside its mouth. This effect is otherwise like the _sympathy_ aspect of the _antipathy/sympathy_ spell. A successful _dispel magic_ (DC 18) removes this enchantment.",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Rules"
        },
        {
            "slug": "underwater-combat",
            "name": "Underwater Combat",
            "desc": "When adventurers pursue sahuagin back to their undersea homes, fight off sharks in an ancient shipwreck, or find themselves in a flooded dungeon room, they must fight in a challenging environment. Underwater the following rules apply.\n\nWhen making a **melee weapon attack**, a creature that doesn't have a swimming speed (either natural or granted by magic) has disadvantage on the attack roll unless the weapon is a dagger, javelin, shortsword, spear, or trident.\n\nA **ranged weapon attack** automatically misses a target beyond the weapon's normal range. Even against a target within normal range, the attack roll has disadvantage unless the weapon is a crossbow, a net, or a weapon that is thrown like a javelin (including a spear, trident, or dart).\n\nCreatures and objects that are fully immersed in water have resistance to fire damage. ",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Combat"
        },
        {
            "slug": "weapons",
            "name": "Weapons",
            "desc": "Your class grants proficiency in certain weapons, reflecting both the class's focus and the tools you are most likely to use. Whether you favor a longsword or a longbow, your weapon and your ability to wield it effectively can mean the difference between life and death while adventuring.\n\nThe Weapons table shows the most common weapons used in the fantasy gaming worlds, their price and weight, the damage they deal when they hit, and any special properties they possess. Every weapon is classified as either melee or ranged. A **melee weapon** is used to attack a target within 5 feet of you, whereas a **ranged weapon** is used to attack a target at a distance.\n\n## Weapon Proficiency\n\nYour race, class, and feats can grant you proficiency with certain weapons or categories of weapons. The two categories are **simple** and **martial**. Most people can use simple weapons with proficiency. These weapons include clubs, maces, and other weapons often found in the hands of commoners. Martial weapons, including swords, axes, and polearms, require more specialized training to use effectively. Most warriors use martial weapons because these weapons put their fighting style and training to best use.\n\nProficiency with a weapon allows you to add your proficiency bonus to the attack roll for any attack you make with that weapon. If you make an attack roll using a weapon with which you lack proficiency, you do not add your proficiency bonus to the attack roll.\n\n## Weapon Properties\n\nMany weapons have special properties related to their use, as shown in the Weapons table.\n\n**_Ammunition._** You can use a weapon that has the ammunition property to make a ranged attack only if you have ammunition to fire from the weapon. Each time you attack with the weapon, you expend one piece of ammunition. Drawing the ammunition from a quiver, case, or other container is part of the attack (you need a free hand to load a one-handed weapon). At the end of the battle, you can recover half your expended ammunition by taking a minute to search the battlefield.\n\nIf you use a weapon that has the ammunition property to make a melee attack, you treat the weapon as an improvised weapon (see “Improvised Weapons” later in the section). A sling must be loaded to deal any damage when used in this way.\n\n**_Finesse._** When making an attack with a finesse weapon, you use your choice of your Strength or Dexterity modifier for the attack and damage rolls. You must use the same modifier for both rolls.\n\n**_Heavy._** Small creatures have disadvantage on attack rolls with heavy weapons. A heavy weapon's size and bulk make it too large for a Small creature to use effectively. \n\n**_Light_**. A light weapon is small and easy to handle, making it ideal for use when fighting with two weapons.\n\n**_Loading._** Because of the time required to load this weapon, you can fire only one piece of ammunition from it when you use an action, bonus action, or reaction to fire it, regardless of the number of attacks you can normally make.\n\n**_Range._** A weapon that can be used to make a ranged attack has a range in parentheses after the ammunition or thrown property. The range lists two numbers. The first is the weapon's normal range in feet, and the second indicates the weapon's long range. When attacking a target beyond normal range, you have disadvantage on the attack roll. You can't attack a target beyond the weapon's long range.\n\n**_Reach._** This weapon adds 5 feet to your reach when you attack with it, as well as when determining your reach for opportunity attacks with it.\n\n**_Special._** A weapon with the special property has unusual rules governing its use, explained in the weapon's description (see “Special Weapons” later in this section).\n\n**_Thrown._** If a weapon has the thrown property, you can throw the weapon to make a ranged attack. If the weapon is a melee weapon, you use the same ability modifier for that attack roll and damage roll that you would use for a melee attack with the weapon. For example, if you throw a handaxe, you use your Strength, but if you throw a dagger, you can use either your Strength or your Dexterity, since the dagger has the finesse property.\n\n**_Two-Handed._** This weapon requires two hands when you attack with it.\n\n**_Versatile._** This weapon can be used with one or two hands. A damage value in parentheses appears with the property-the damage when the weapon is used with two hands to make a melee attack.\n\n### Improvised Weapons\n\nSometimes characters don't have their weapons and have to attack with whatever is at hand. An improvised weapon includes any object you can wield in one or two hands, such as broken glass, a table leg, a frying pan, a wagon wheel, or a dead goblin.\n\nOften, an improvised weapon is similar to an actual weapon and can be treated as such. For example, a table leg is akin to a club. At the GM's option, a character proficient with a weapon can use a similar object as if it were that weapon and use his or her proficiency bonus.\n\nAn object that bears no resemblance to a weapon deals 1d4 damage (the GM assigns a damage type appropriate to the object). If a character uses a ranged weapon to make a melee attack, or throws a melee weapon that does not have the thrown property, it also deals 1d4 damage. An improvised thrown weapon has a normal range of 20 feet and a long range of 60 feet.\n\n### Silvered Weapons\n\nSome monsters that have immunity or resistance to nonmagical weapons are susceptible to silver weapons, so cautious adventurers invest extra coin to plate their weapons with silver. You can silver a single weapon or ten pieces of ammunition for 100 gp. This cost represents not only the price of the silver, but the time and expertise needed to add silver to the weapon without making it less effective.\n\n### Special Weapons\n\nWeapons with special rules are described here.\n\n**_Lance._** You have disadvantage when you use a lance to attack a target within 5 feet of you. Also, a lance requires two hands to wield when you aren't mounted.\n\n**_Net._** A Large or smaller creature hit by a net is restrained until it is freed. A net has no effect on creatures that are formless, or creatures that are Huge or larger. A creature can use its action to make a DC 10 Strength check, freeing itself or another creature within its reach on a success. Dealing 5 slashing damage to the net (AC 10) also frees the creature without harming it, ending the effect and destroying the net.\n\nWhen you use an action, bonus action, or reaction to attack with a net, you can make only one attack regardless of the number of attacks you can normally make.\n\n**Weapons (table)**\n\n| Name                         | Cost  | Damage          | Weight  | Properties                                             |\n|------------------------------|-------|-----------------|---------|--------------------------------------------------------|\n| **_Simple Melee Weapons_**   |       |                 |         |                                                        |\n| Club                         | 1 sp  | 1d4 bludgeoning | 2 lb.   | Light                                                  |\n| Dagger                       | 2 gp  | 1d4 piercing    | 1 lb.   | Finesse, light, thrown (range 20/60)                   |\n| Greatclub                    | 2 sp  | 1d8 bludgeoning | 10 lb.  | Two-handed                                             |\n| Handaxe                      | 5 gp  | 1d6 slashing    | 2 lb.   | Light, thrown (range 20/60)                            |\n| Javelin                      | 5 sp  | 1d6 piercing    | 2 lb.   | Thrown (range 30/120)                                  |\n| Light hammer                 | 2 gp  | 1d4 bludgeoning | 2 lb.   | Light, thrown (range 20/60)                            |\n| Mace                         | 5 gp  | 1d6 bludgeoning | 4 lb.   | -                                                      |\n| Quarterstaff                 | 2 sp  | 1d6 bludgeoning | 4 lb.   | Versatile (1d8)                                        |\n| Sickle                       | 1 gp  | 1d4 slashing    | 2 lb.   | Light                                                  |\n| Spear                        | 1 gp  | 1d6 piercing    | 3 lb.   | Thrown (range 20/60), versatile (1d8)                  |\n| **_Simple Ranged Weapons_**  |       |                 |         |                                                        |\n| Crossbow, light              | 25 gp | 1d8 piercing    | 5 lb.   | Ammunition (range 80/320), loading, two-handed         |\n| Dart                         | 5 cp  | 1d4 piercing    | 1/4 lb. | Finesse, thrown (range 20/60)                          |\n| Shortbow                     | 25 gp | 1d6 piercing    | 2 lb.   | Ammunition (range 80/320), two-handed                  |\n| Sling                        | 1 sp  | 1d4 bludgeoning | -       | Ammunition (range 30/120)                              |\n| **_Martial Melee Weapons_**  |       |                 |         |                                                        |\n| Battleaxe                    | 10 gp | 1d8 slashing    | 4 lb.   | Versatile (1d10)                                       |\n| Flail                        | 10 gp | 1d8 bludgeoning | 2 lb.   | -                                                      |\n| Glaive                       | 20 gp | 1d10 slashing   | 6 lb.   | Heavy, reach, two-handed                               |\n| Greataxe                     | 30 gp | 1d12 slashing   | 7 lb.   | Heavy, two-handed                                      |\n| Greatsword                   | 50 gp | 2d6 slashing    | 6 lb.   | Heavy, two-handed                                      |\n| Halberd                      | 20 gp | 1d10 slashing   | 6 lb.   | Heavy, reach, two-handed                               |\n| Lance                        | 10 gp | 1d12 piercing   | 6 lb.   | Reach, special                                         |\n| Longsword                    | 15 gp | 1d8 slashing    | 3 lb.   | Versatile (1d10)                                       |\n| Maul                         | 10 gp | 2d6 bludgeoning | 10 lb.  | Heavy, two-handed                                      |\n| Morningstar                  | 15 gp | 1d8 piercing    | 4 lb.   | -                                                      |\n| Pike                         | 5 gp  | 1d10 piercing   | 18 lb.  | Heavy, reach, two-handed                               |\n| Rapier                       | 25 gp | 1d8 piercing    | 2 lb.   | Finesse                                                |\n| Scimitar                     | 25 gp | 1d6 slashing    | 3 lb.   | Finesse, light                                         |\n| Shortsword                   | 10 gp | 1d6 piercing    | 2 lb.   | Finesse, light                                         |\n| Trident                      | 5 gp  | 1d6 piercing    | 4 lb.   | Thrown (range 20/60), versatile (1d8)                  |\n| War pick                     | 5 gp  | 1d8 piercing    | 2 lb.   | -                                                      |\n| Warhammer                    | 15 gp | 1d8 bludgeoning | 2 lb.   | Versatile (1d10)                                       |\n| Whip                         | 2 gp  | 1d4 slashing    | 3 lb.   | Finesse, reach                                         |\n| **_Martial Ranged Weapons_** |       |                 |         |                                                        |\n| Blowgun                      | 10 gp | 1 piercing      | 1 lb.   | Ammunition (range 25/100), loading                     |\n| Crossbow, hand               | 75 gp | 1d6 piercing    | 3 lb.   | Ammunition (range 30/120), light, loading              |\n| Crossbow, heavy              | 50 gp | 1d10 piercing   | 18 lb.  | Ammunition (range 100/400), heavy, loading, two-handed |\n| Longbow                      | 50 gp | 1d8 piercing    | 2 lb.   | Ammunition (range 150/600), heavy, two-handed          |\n| Net                          | 1 gp  | -               | 3 lb.   | Special, thrown (range 5/15)                           |\n",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Equipment"
        }
    ]
}

Feat List
list: API endpoint for returning a list of feats.
retrieve: API endpoint for returning a particular feat.

«12»
GET /v2/feats/
HTTP 200 OK
Allow: GET, HEAD, OPTIONS
Content-Type: application/json
Vary: Accept

{
    "count": 91,
    "next": "https://api.open5e.com/v2/feats/?page=2",
    "previous": null,
    "results": [
        {
            "url": "https://api.open5e.com/v2/feats/a5e-ag_ace-driver/",
            "key": "a5e-ag_ace-driver",
            "has_prerequisite": true,
            "benefits": [
                {
                    "desc": "You gain an expertise die on ability checks made to drive or pilot a vehicle."
                },
                {
                    "desc": "While piloting a vehicle, you can use your reaction to take the Brake or Maneuver vehicle actions."
                },
                {
                    "desc": "A vehicle you load can carry 25% more cargo than normal."
                },
                {
                    "desc": "Vehicles you are piloting only suffer a malfunction when reduced to 25% of their hit points, not 50%. In addition, when the vehicle does suffer a malfunction, you roll twice on the maneuver table and choose which die to use for the result."
                },
                {
                    "desc": "Vehicles you are piloting gain a bonus to their Armor Class equal to half your proficiency bonus."
                },
                {
                    "desc": "When you Brake, you can choose to immediately stop the vehicle without traveling half of its movement speed directly forward."
                }
            ],
            "document": {
                "name": "Adventurer's Guide",
                "key": "a5e-ag",
                "type": "SOURCE",
                "display_name": "Adventurer's Guide",
                "publisher": {
                    "name": "EN Publishing",
                    "key": "en-publishing",
                    "url": "https://api.open5e.com/v2/publishers/en-publishing/"
                },
                "gamesystem": {
                    "name": "Advanced 5th Edition",
                    "key": "a5e",
                    "url": "https://api.open5e.com/v2/gamesystems/a5e/"
                },
                "permalink": "https://a5esrd.com/a5esrd"
            },
            "name": "Ace Driver",
            "desc": "You are a virtuoso of driving and piloting vehicles, able to push them beyond their normal limits and maneuver them with fluid grace through hazardous situations. You gain the following benefits:",
            "prerequisite": "Proficiency with a type of vehicle",
            "type": "GENERAL"
        },
        {
            "url": "https://api.open5e.com/v2/feats/a5e-ag_athletic/",
            "key": "a5e-ag_athletic",
            "has_prerequisite": false,
            "benefits": [
                {
                    "desc": "Your Strength or Dexterity score increases by 1, to a maximum of 20."
                },
                {
                    "desc": "When you are prone, standing up uses only 5 feet of your movement (instead of half)."
                },
                {
                    "desc": "Your speed is not halved from climbing."
                },
                {
                    "desc": "You can make a running long jump or a running high jump after moving 5 feet on foot (instead of 10 feet)."
                }
            ],
            "document": {
                "name": "Adventurer's Guide",
                "key": "a5e-ag",
                "type": "SOURCE",
                "display_name": "Adventurer's Guide",
                "publisher": {
                    "name": "EN Publishing",
                    "key": "en-publishing",
                    "url": "https://api.open5e.com/v2/publishers/en-publishing/"
                },
                "gamesystem": {
                    "name": "Advanced 5th Edition",
                    "key": "a5e",
                    "url": "https://api.open5e.com/v2/gamesystems/a5e/"
                },
                "permalink": "https://a5esrd.com/a5esrd"
            },
            "name": "Athletic",
            "desc": "Your enhanced physical training grants you the following benefits:",
            "prerequisite": "",
            "type": "GENERAL"
        },
        {
            "url": "https://api.open5e.com/v2/feats/a5e-ag_attentive/",
            "key": "a5e-ag_attentive",
            "has_prerequisite": false,
            "benefits": [
                {
                    "desc": "When rolling initiative you gain a +5 bonus."
                },
                {
                    "desc": "You can only be surprised if you are unconscious. A creature attacking you does not gain advantage from being hidden from you or unseen by you."
                }
            ],
            "document": {
                "name": "Adventurer's Guide",
                "key": "a5e-ag",
                "type": "SOURCE",
                "display_name": "Adventurer's Guide",
                "publisher": {
                    "name": "EN Publishing",
                    "key": "en-publishing",
                    "url": "https://api.open5e.com/v2/publishers/en-publishing/"
                },
                "gamesystem": {
                    "name": "Advanced 5th Edition",
                    "key": "a5e",
                    "url": "https://api.open5e.com/v2/gamesystems/a5e/"
                },
                "permalink": "https://a5esrd.com/a5esrd"
            },
            "name": "Attentive",
            "desc": "Always aware of your surroundings, you gain the following benefits:",
            "prerequisite": "",
            "type": "GENERAL"
        },
        {
            "url": "https://api.open5e.com/v2/feats/a5e-ag_battle-caster/",
            "key": "a5e-ag_battle-caster",
            "has_prerequisite": true,
            "benefits": [
                {
                    "desc": "You gain a 1d6 expertise die on concentration checks to maintain spells you have cast."
                },
                {
                    "desc": "While wielding weapons and shields, you may cast spells with a seen component."
                },
                {
                    "desc": "Instead of making an opportunity attack with a weapon, you may use your reaction to cast a spell with a casting time of 1 action. The spell must be one that only targets that creature."
                }
            ],
            "document": {
                "name": "Adventurer's Guide",
                "key": "a5e-ag",
                "type": "SOURCE",
                "display_name": "Adventurer's Guide",
                "publisher": {
                    "name": "EN Publishing",
                    "key": "en-publishing",
                    "url": "https://api.open5e.com/v2/publishers/en-publishing/"
                },
                "gamesystem": {
                    "name": "Advanced 5th Edition",
                    "key": "a5e",
                    "url": "https://api.open5e.com/v2/gamesystems/a5e/"
                },
                "permalink": "https://a5esrd.com/a5esrd"
            },
            "name": "Battle Caster",
            "desc": "You're comfortable casting, even in the chaos of battle.",
            "prerequisite": "Requires the ability to cast at least one spell of 1st-level or higher",
            "type": "GENERAL"
        },
.......

Feat Instance
list: API endpoint for returning a list of feats.
retrieve: API endpoint for returning a particular feat.

GET /v2/feats/a5e-ag_battle-caster/
HTTP 200 OK
Allow: GET, HEAD, OPTIONS
Content-Type: application/json
Vary: Accept

{
    "url": "https://api.open5e.com/v2/feats/a5e-ag_battle-caster/",
    "key": "a5e-ag_battle-caster",
    "has_prerequisite": true,
    "benefits": [
        {
            "desc": "You gain a 1d6 expertise die on concentration checks to maintain spells you have cast."
        },
        {
            "desc": "While wielding weapons and shields, you may cast spells with a seen component."
        },
        {
            "desc": "Instead of making an opportunity attack with a weapon, you may use your reaction to cast a spell with a casting time of 1 action. The spell must be one that only targets that creature."
        }
    ],
    "document": {
        "name": "Adventurer's Guide",
        "key": "a5e-ag",
        "type": "SOURCE",
        "display_name": "Adventurer's Guide",
        "publisher": {
            "name": "EN Publishing",
            "key": "en-publishing",
            "url": "https://api.open5e.com/v2/publishers/en-publishing/"
        },
        "gamesystem": {
            "name": "Advanced 5th Edition",
            "key": "a5e",
            "url": "https://api.open5e.com/v2/gamesystems/a5e/"
        },
        "permalink": "https://a5esrd.com/a5esrd"
    },
    "name": "Battle Caster",
    "desc": "You're comfortable casting, even in the chaos of battle.",
    "prerequisite": "Requires the ability to cast at least one spell of 1st-level or higher",
    "type": "GENERAL"
}

Condition List
list: API endpoint for returning a list of conditions.
retrieve: API endpoint for returning a particular condition.

GET /v2/conditions/
HTTP 200 OK
Allow: GET, HEAD, OPTIONS
Content-Type: application/json
Vary: Accept

{
    "count": 21,
    "next": null,
    "previous": null,
    "results": [
        {
            "url": "https://api.open5e.com/v2/conditions/a5e-ag_bloodied/",
            "key": "a5e-ag_bloodied",
            "document": {
                "name": "Adventurer's Guide",
                "key": "a5e-ag",
                "type": "SOURCE",
                "display_name": "Adventurer's Guide",
                "publisher": {
                    "name": "EN Publishing",
                    "key": "en-publishing",
                    "url": "https://api.open5e.com/v2/publishers/en-publishing/"
                },
                "gamesystem": {
                    "name": "Advanced 5th Edition",
                    "key": "a5e",
                    "url": "https://api.open5e.com/v2/gamesystems/a5e/"
                },
                "permalink": "https://a5esrd.com/a5esrd"
            },
            "icon": null,
            "descriptions": [
                {
                    "desc": "* A creature is bloodied when reduced to half its hit points or less.",
                    "document": "a5e-ag",
                    "gamesystem": "a5e"
                }
            ],
            "name": "Bloodied"
        },
        {
            "url": "https://api.open5e.com/v2/conditions/a5e-ag_confused/",
            "key": "a5e-ag_confused",
            "document": {
                "name": "Adventurer's Guide",
                "key": "a5e-ag",
                "type": "SOURCE",
                "display_name": "Adventurer's Guide",
                "publisher": {
                    "name": "EN Publishing",
                    "key": "en-publishing",
                    "url": "https://api.open5e.com/v2/publishers/en-publishing/"
                },
                "gamesystem": {
                    "name": "Advanced 5th Edition",
                    "key": "a5e",
                    "url": "https://api.open5e.com/v2/gamesystems/a5e/"
                },
                "permalink": "https://a5esrd.com/a5esrd"
            },
            "icon": null,
            "descriptions": [
                {
                    "desc": "* A confused creature can't take reactions. \n\n* On its turn a confused creature rolls a d8 to determine what it does.\n\n* On a 1 to 4, a confused creature does nothing. \n\n* On a 5 or 6, a confused creature takes no action or bonus action and uses all its movement to move in a randomly determined direction.\n\n* On a 7 or 8, a confused creature makes a melee attack against a randomly determined creature within its reach or does nothing if it can't make such an attack.",
                    "document": "a5e-ag",
                    "gamesystem": "a5e"
                }
            ],
            "name": "Confused"
        },
        {
            "url": "https://api.open5e.com/v2/conditions/a5e-ag_doomed/",
            "key": "a5e-ag_doomed",
            "document": {
                "name": "Adventurer's Guide",
                "key": "a5e-ag",
                "type": "SOURCE",
                "display_name": "Adventurer's Guide",
                "publisher": {
                    "name": "EN Publishing",
                    "key": "en-publishing",
                    "url": "https://api.open5e.com/v2/publishers/en-publishing/"
                },
                "gamesystem": {
                    "name": "Advanced 5th Edition",
                    "key": "a5e",
                    "url": "https://api.open5e.com/v2/gamesystems/a5e/"
                },
                "permalink": "https://a5esrd.com/a5esrd"
            },
            "icon": null,
            "descriptions": [
                {
                    "desc": "* A doomed creature dies at a time determined by the Narrator, or within 13 (2d12) hours.\n\n* A doomed creature continues to be doomed even after it dies. Magic equivalent to a 7th-level or higher spell can remove the doomed condition (such as regenerate cast on a living creature, resurrection, true resurrection, or wish).",
                    "document": "a5e-ag",
                    "gamesystem": "a5e"
                }
            ],
            "name": "Doomed"
        },
        {
            "url": "https://api.open5e.com/v2/conditions/a5e-ag_encumbered/",
            "key": "a5e-ag_encumbered",
            "document": {
                "name": "Adventurer's Guide",
                "key": "a5e-ag",
                "type": "SOURCE",
                "display_name": "Adventurer's Guide",
                "publisher": {
                    "name": "EN Publishing",
                    "key": "en-publishing",
                    "url": "https://api.open5e.com/v2/publishers/en-publishing/"
                },
                "gamesystem": {
                    "name": "Advanced 5th Edition",
                    "key": "a5e",
                    "url": "https://api.open5e.com/v2/gamesystems/a5e/"
                },
                "permalink": "https://a5esrd.com/a5esrd"
            },
            "icon": null,
            "descriptions": [
                {
                    "desc": "* An encumbered creature’s Speed is reduced to 5 feet.",
                    "document": "a5e-ag",
                    "gamesystem": "a5e"
                }
            ],
            "name": "Encumbered"
        },
        {
            "url": "https://api.open5e.com/v2/conditions/a5e-ag_rattled/",
            "key": "a5e-ag_rattled",
            "document": {
                "name": "Adventurer's Guide",
                "key": "a5e-ag",
                "type": "SOURCE",
                "display_name": "Adventurer's Guide",
                "publisher": {
                    "name": "EN Publishing",
                    "key": "en-publishing",
                    "url": "https://api.open5e.com/v2/publishers/en-publishing/"
                },
                "gamesystem": {
                    "name": "Advanced 5th Edition",
                    "key": "a5e",
                    "url": "https://api.open5e.com/v2/gamesystems/a5e/"
                },
                "permalink": "https://a5esrd.com/a5esrd"
            },
            "icon": null,
            "descriptions": [
                {
                    "desc": "*A rattled creature cannot benefit from expertise dice.\n\n* A rattled creature cannot take reactions.\n\n* A creature that is immune to being stunned is immune to being rattled.",
                    "document": "a5e-ag",
                    "gamesystem": "a5e"
                }
            ],
            "name": "Rattled"
        },
        {
            "url": "https://api.open5e.com/v2/conditions/a5e-ag_slowed/",
            "key": "a5e-ag_slowed",
            "document": {
                "name": "Adventurer's Guide",
                "key": "a5e-ag",
                "type": "SOURCE",
                "display_name": "Adventurer's Guide",
                "publisher": {
                    "name": "EN Publishing",
                    "key": "en-publishing",
                    "url": "https://api.open5e.com/v2/publishers/en-publishing/"
                },
                "gamesystem": {
                    "name": "Advanced 5th Edition",
                    "key": "a5e",
                    "url": "https://api.open5e.com/v2/gamesystems/a5e/"
                },
                "permalink": "https://a5esrd.com/a5esrd"
            },
            "icon": null,
            "descriptions": [
                {
                    "desc": "* A slowed creature's Speed is halved. \n\n* A slowed creature takes a −2 penalty to AC and Dexterity saving throws. \n\n* A slowed creature cannot take reactions. \n\n* On its turn, a slowed creature can take either an action or a bonus action, not both. In addition, it can't make more than one melee or ranged attack during its turn.",
                    "document": "a5e-ag",
                    "gamesystem": "a5e"
                }
            ],
            "name": "Slowed"
        },
        {
            "url": "https://api.open5e.com/v2/conditions/blinded/",
            "key": "blinded",
            "document": {
                "name": "5e Core Concepts",
                "key": "core",
                "type": "MISC",
                "display_name": "5e Core",
                "publisher": {
                    "name": "Open5e",
                    "key": "open5e",
                    "url": "https://api.open5e.com/v2/publishers/open5e/"
                },
                "gamesystem": {
                    "name": "5th Edition 2014",
                    "key": "5e-2014",
                    "url": "https://api.open5e.com/v2/gamesystems/5e-2014/"
                },
                "permalink": "https://dnd.wizards.com/resources/systems-reference-document"
            },
            "icon": {
                "name": "Blinded",
                "key": "elderberry_blinded",
                "url": "https://api.open5e.com/v2/images/elderberry_blinded/",
                "file_url": "/static/img/object_icons/elderberry-inn-icons/conditions/blinded.svg",
                "alt_text": "An icon representing the blinded condition in an RPG. A simple, abstract black-and-white icon of an eye with a line crossed through it.",
                "attribution": "Designed with love by Anaislalovi (@anaislalovi) for Elderberry Inn."
            },
            "descriptions": [
                {
                    "desc": "* A blinded creature
.......


Condition Instance
list: API endpoint for returning a list of conditions.
retrieve: API endpoint for returning a particular condition.

GET /v2/conditions/a5e-ag_slowed/
HTTP 200 OK
Allow: GET, HEAD, OPTIONS
Content-Type: application/json
Vary: Accept

{
    "url": "https://api.open5e.com/v2/conditions/a5e-ag_slowed/",
    "key": "a5e-ag_slowed",
    "document": {
        "name": "Adventurer's Guide",
        "key": "a5e-ag",
        "type": "SOURCE",
        "display_name": "Adventurer's Guide",
        "publisher": {
            "name": "EN Publishing",
            "key": "en-publishing",
            "url": "https://api.open5e.com/v2/publishers/en-publishing/"
        },
        "gamesystem": {
            "name": "Advanced 5th Edition",
            "key": "a5e",
            "url": "https://api.open5e.com/v2/gamesystems/a5e/"
        },
        "permalink": "https://a5esrd.com/a5esrd"
    },
    "icon": null,
    "descriptions": [
        {
            "desc": "* A slowed creature's Speed is halved. \n\n* A slowed creature takes a −2 penalty to AC and Dexterity saving throws. \n\n* A slowed creature cannot take reactions. \n\n* On its turn, a slowed creature can take either an action or a bonus action, not both. In addition, it can't make more than one melee or ranged attack during its turn.",
            "document": "a5e-ag",
            "gamesystem": "a5e"
        }
    ],
    "name": "Slowed"
}


Race List
list: API endpoint for returning a list of races.
retrieve: API endpoint for returning a particular race.

GET /v1/races/
HTTP 200 OK
Allow: GET, HEAD, OPTIONS
Content-Type: application/json
Vary: Accept

{
    "count": 20,
    "next": null,
    "previous": null,
    "results": [
        {
            "name": "Alseid",
            "slug": "alseid",
            "desc": "## Alseid Traits\nYour alseid character has certain characteristics in common with all other alseid.",
            "asi_desc": "***Ability Score Increase.*** Your Dexterity score increases by 2, and your Wisdom score increases by 1.",
            "asi": [
                {
                    "attributes": [
                        "Dexterity"
                    ],
                    "value": 2
                },
                {
                    "attributes": [
                        "Wisdom"
                    ],
                    "value": 1
                }
            ],
            "age": "***Age.*** Alseid reach maturity by the age of 20. They can live well beyond 100 years, but it is unknown just how old they can become.",
            "alignment": "***Alignment.*** Alseid are generally chaotic, flowing with the unpredictable whims of nature, though variations are common, particularly among those rare few who leave their people.",
            "size": "***Size.*** Alseid stand over 6 feet tall and weigh around 300 pounds. Your size is Medium.",
            "size_raw": "Medium",
            "speed": {
                "walk": 40
            },
            "speed_desc": "***Speed.*** Alseid are fast for their size, with a base walking speed of 40 feet.",
            "languages": "***Languages.*** You can speak, read, and write Common and Elvish.",
            "vision": "***Darkvision.*** Accustomed to the limited light beneath the forest canopy, you have superior vision in dark and dim conditions. You can see in dim light within 60 feet of you as if it were bright light, and in darkness as if it were dim light. You can't discern color in darkness, only shades of gray.",
            "traits": "***Alseid Weapon Training.*** You have proficiency with spears and shortbows.\n\n***Light Hooves.*** You have proficiency in the Stealth skill.\n\n***Quadruped.*** The mundane details of the structures of humanoids can present considerable obstacles for you. You have to squeeze when moving through trapdoors, manholes, and similar structures even when a Medium humanoid wouldn't have to squeeze. In addition, ladders, stairs, and similar structures are difficult terrain for you.\n\n***Woodfriend.*** When in a forest, you leave no tracks and can automatically discern true north.",
            "subraces": [],
            "document__slug": "toh",
            "document__title": "Tome of Heroes",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
        },
        {
            "name": "Catfolk",
            "slug": "catfolk",
            "desc": "## Catfolk Traits\nYour catfolk character has the following traits.",
            "asi_desc": "***Ability Score Increase.*** Your Dexterity score increases by 2.",
            "asi": [
                {
                    "attributes": [
                        "Dexterity"
                    ],
                    "value": 2
                }
            ],
            "age": "***Age.*** Catfolk mature at the same rate as humans and can live just past a century.",
            "alignment": "***Alignment.*** Catfolk tend toward two extremes. Some are free-spirited and chaotic, letting impulse and fancy guide their decisions. Others are devoted to duty and personal honor. Typically, catfolk deem concepts such as good and evil as less important than freedom or their oaths.",
            "size": "***Size.*** Catfolk have a similar stature to humans but are generally leaner and more muscular. Your size is Medium.",
            "size_raw": "Medium",
            "speed": {
                "walk": 30
            },
            "speed_desc": "***Speed.*** Your base walking speed is 30 feet.",
            "languages": "***Languages.*** You can speak, read, and write Common.",
            "vision": "***Darkvision.*** You have a cat's keen senses, especially in the dark. You can see in dim light within 60 feet of you as if it were bright light, and in darkness as if it were dim light. You can't discern color in darkness, only shades of gray.",
            "traits": "***Cat's Claws.*** Your sharp claws can cut with ease. Your claws are natural melee weapons, which you can use to make unarmed strikes. When you hit with a claw, your claw deals slashing damage equal to 1d4 + your Strength modifier, instead of the bludgeoning damage normal for an unarmed strike.\n\n***Hunter's Senses.*** You have proficiency in the Perception and Stealth skills.",
            "subraces": [
                {
                    "name": "Malkin",
                    "slug": "malkin",
                    "desc": "It's often said curiosity killed the cat, and this applies with equal frequency to catfolk. As a malkin catfolk you are adept at finding clever solutions to escape difficult situations, even (or perhaps especially) situations of your own making. Your diminutive size also gives you an uncanny nimbleness that helps you avoid the worst consequences of your intense inquisitiveness. Most often found in densely populated regions, these catfolk are as curious about the comings and goings of other humanoids as they are about natural or magical phenomena and artifacts. While malkins are sometimes referred to as \"housecats\" by other humanoids and even by other catfolk, doing so in a malkin's hearing is a surefire way to get a face full of claws...",
                    "asi": [
                        {
                            "attributes": [
                                "Intelligence"
                            ],
                            "value": 1
                        }
                    ],
                    "traits": "***Curiously Clever.*** You have proficiency in the Investigation skill.\n\n***Charmed Curiosity.*** When you roll a 1 on the d20 for a Dexterity check or saving throw, you can reroll the die and must use the new roll.",
                    "asi_desc": "***Ability Score Increase.*** Your Intelligence score increases by 1.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "Pantheran",
                    "slug": "pantheran",
                    "desc": "Pantheran catfolk are a wise, observant, and patient people who pride themselves on being resourceful and self-sufficient. Less social than many others of their kind, these catfolk typically dwell in small, close-knit family groups in the forests, jungles, and grasslands of the world, away from larger population centers or cities. Their family clans teach the importance of living off of and protecting the natural world, and pantherans act swiftly and mercilessly when their forest homes are threatened by outside forces. Conversely, pantherans can be the most fierce and loyal of neighbors to villages who respect nature and who take from the land and forest no more than they need. As a pantheran, you value nature and kinship, and your allies know they can count on your wisdom and, when necessary, your claws.",
                    "asi": [
                        {
                            "attributes": [
                                "Wisdom"
                            ],
                            "value": 1
                        }
                    ],
                    "traits": "***Hunter's Charge.*** Once per turn, if you move at least 10 feet toward a target and hit it with a melee weapon attack in the same turn, you can use a bonus action to attack that creature with your Cat's Claws. You can use this trait a number of times per day equal to your proficiency bonus, and you regain all expended uses when you finish a long rest.\n\n***One With the Wilds.*** You have proficiency in one of the following skills of your choice: Insight, Medicine, Nature, or Survival.",
                    "asi_desc": "***Ability Score Increase.*** Your Wisdom score increases by 1.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                }
            ],
            "document__slug": "toh",
            "document__title": "Tome of Heroes",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
        },
        {
            "name": "Darakhul",
            "slug": "darakhul",
            "desc": "## Darakhul Traits\nYour darakhul character has certain characteristics in common with all other darakhul.",
            "asi_desc": "***Ability Score Increase.*** Your Constitution score increases by 1.",
            "asi": [
                {
                    "attributes": [
                        "Constitution"
                    ],
                    "value": 1
                }
            ],
            "age": "***Age.*** An upper limit of darakhul age has never been discovered; most darakhul die violently.",
            "alignment": "***Alignment.*** Your alignment does not change when you become a darakhul, but most darakhul have a strong draw toward evil.",
            "size": "***Size.*** Your size is determined by your Heritage Subrace.",
            "size_raw": "Medium",
            "speed": {
                "walk": 30
            },
            "speed_desc": "***Speed.*** Your base walking speed is determined by your Heritage Subrace.",
            "languages": "***Languages.*** You can speak, read, and write Common, Darakhul, and a language associated with your Heritage Subrace.",
            "vision": "***Darkvision.*** You can see in dim light within 60 feet as though it were bright light and in darkness as if it were dim light. You can't discern color in darkness, only shades of gray.",
            "traits": "***Hunger for Flesh.*** You must consume 1 pound of raw meat each day or suffer the effects of starvation. If you go 24 hours without such a meal, you gain one level of exhaustion. While you have any levels of exhaustion from this trait, you can't regain hit points or remove levels of exhaustion until you spend at least 1 hour consuming 10 pounds of raw meat.\n\n***Imperfect Undeath.*** You transitioned into undeath, but your transition was imperfect. Though you are a humanoid, you are susceptible to effects that target undead. You can regain hit points from spells like cure wounds, but you can also be affected by game effects that specifically target undead, such as a cleric's Turn Undead feature. Game effects that raise a creature from the dead work on you as normal, but they return you to life as a darakhul. A true resurrection or wish spell can restore you to life as a fully living member of your original race.\n\n***Powerful Jaw.*** Your heavy jaw is powerful enough to crush bones to powder. Your bite is a natural melee weapon, which you can use to make unarmed strikes. When you hit with it, your bite deals piercing damage equal to 1d4 + your Strength modifier, instead of the bludgeoning damage normal for an unarmed strike.\n\n***Sunlight Sensitivity.*** You have disadvantage on attack rolls and on Wisdom (Perception) checks that rely on sight when you, the target of your attack, or whatever you are trying to perceive is in direct sunlight.\n\n***Undead Resilience.*** You are infused with the dark energy of undeath, which frees you from some frailties that plague most creatures. You have resistance to necrotic damage and poison damage, you are immune to disease, and you have advantage on saving throws against being charmed or poisoned. When you finish a short rest, you can reduce your exhaustion level by 1, provided you have ingested at least 1 pound of raw meat in the last 24 hours (see Hunger for Flesh).\n\n***Undead Vitality.*** You don't need to breathe, and you don't sleep the way most creatures do. Instead, you enter a dormant state that resembles death, remaining semiconscious, for 6 hours a day. While dormant, you have disadvantage on Wisdom (Perception) checks. After resting in this way, you gain the same benefit that a human does from 8 hours of sleep.\n\n***Heritage Subrace.*** You were something else before you became a darakhul. This heritage determines some of your traits. Choose one Heritage Subrace below and apply the listed traits.",
            "subraces": [
                {
                    "name": "Derro Heritage",
                    "slug": "derro-heritage",
                    "desc": "Your darakhul character was a derro before transforming into a darakhul. For you, the quieting of the otherworldly voices did not bring peace and tranquility. The impulses simply became more focused, and the desire to feast on flesh overwhelmed other urges. The darkness is still there; it just has a new, clearer form.",
                    "asi": [
                        {
                            "attributes": [
                                "Charisma"
                            ],
                            "value": 2
                        }
                    ],
                    "traits": "***Calculating Insanity.*** The insanity of your race was compressed into a cold, hard brilliance when you took on your darakhul form. These flashes of brilliance come to you at unexpected moments. You know the true strike cantrip. Charisma is your spellcasting ability for it. You can cast true strike as a bonus action a number of times equal to your Charisma modifier (a minimum of once). You regain any expended uses when you finish a long rest.",
                    "asi_desc": "***Ability Score Increase.*** Your Charisma score increases by 2.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "Dragonborn Heritage",
                    "slug": "dragonborn-heritage",
                    "desc": "Your darakhul character was a dragonborn before transforming into a darakhul. The dark power of undeath overwhelmed your elemental nature, replacing it with the foul energy and strength of the undead. Occasionally, your draconic heritage echoes a peal of raw power through your form, but it is quickly converted into necrotic waves.",
                    "asi": [
                        {
                            "attributes": [
                                "Strength"
                            ],
                            "value": 2
                        }
                    ],
                    "traits": "***Corrupted Bite.*** The inherent breath weapon of your draconic heritage is corrupted by the necrotic energy of your new darakhul form. Instead of forming a line or cone, your breath weapon now oozes out of your ghoulish maw. As a bonus action, you breathe necrotic energy onto your fangs and make one bite attack. If the attack hits, it deals extra necrotic damage equal to your level. You can't use this trait again until you finish a long rest.",
                    "asi_desc": "***Ability Score Increase.*** Your Strength score increases by 2.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "Drow Heritage",
                    "slug": "drow-heritage",
                    "desc": "Your darakhul character was a drow before transforming into a darakhul. Your place within the highly regimented drow society doesn't feel that much different from your new place in the darakhul empires. But an uncertainty buzzes in your mind, and a hunger gnaws at your gut. You are now what you once hated and feared. Does it feel right, or is it something you fight against?",
                    "asi": [
                        {
                            "attributes": [
                                "Intelligence"
                            ],
                            "value": 2
                        }
                    ],
                    "traits": "***Poison Bite.*** When you hit with your bite attack, you can release venom into your foe. If you do, your bite deals an extra 1d6 poison damage. The damage increases to 3d6 at 11th level. After you release this venom into a creature, you can't do so again until you finish a short or long rest.",
                    "asi_desc": "***Ability Score Increase.*** Your Intelligence score increases by 2.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "Dwarf Heritage",
                    "slug": "dwarf-heritage",
                    "desc": "Your darakhul character was a dwarf before transforming into a darakhul. The hum of the earth, the tranquility of the stone and the dust, drained from you as the darakhul fever overwhelmed your once-resilient body. The stone is still there, but its touch has gone from a welcome embrace to a cold grip of death. But it's all the same to you now. ",
                    "asi": [
                        {
                            "attributes": [
                                "Wisdom"
                            ],
                            "value": 2
                        }
                    ],
                    "traits": "***Dwarven Stoutness.*** Your hit point maximum increases by 1, and it increases by 1 every time you gain a level.",
                    "asi_desc": "***Ability Score Increase.*** Your Wisdon score increases by 2.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "Elf/Shadow Fey Heritage",
                    "slug": "elfshadow-fey-heritage",
                    "desc": "Your darakhul character was an elf or shadow fey (see *Midgard Heroes Handbook*) before transforming into a darakhul. The deathly power coursing through you reminds you of the lithe beauty and magic of your former body. If you just use your imagination, the blood tastes like wine once did. The smell of rotting flesh has the bouquet of wildflowers. The moss beneath the surface feels like the leaves of the forest.",
                    "asi": [
                        {
                            "attributes": [
                                "Dexterity"
                            ],
                            "value": 2
                        }
                    ],
                    "traits": "***Supernatural Senses.*** Your keen elven senses are honed even more by the power of undeath and the hunger within you. You can now smell when blood is in the air. You have proficiency in the Perception skill, and you have advantage on Wisdom (Perception) checks to notice or find a creature within 30 feet of you that doesn't have all of its hit points.",
                    "asi_desc": "***Ability Score Increase.*** Your Dexterity score increases by 2.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "Gnome Heritage",
                    "slug": "gnome-heritage",
                    "desc": "Your darakhul character was a gnome before transforming into a darakhul. The spark of magic that drove you before your transformation still burns inside of you, but now it is a constant ache instead of a source of creation and inspiration. This ache is twisted by your hunger, making you hunger for magic itself. ",
                    "asi": [
                        {
                            "attributes": [
                                "Intelligence"
                            ],
                            "value": 2
                        }
                    ],
                    "traits": "***Magical Hunger.*** When a creature you can see within 30 feet of you casts a spell, you can use your reaction to consume the spell's residual magic. Your consumption doesn't counter or otherwise affect the spell or the spellcaster. When you consume this residual magic, you gain temporary hit points (minimum of 1) equal to your Constitution modifier, and you can't use this trait again until you finish a short or long rest.",
                    "asi_desc": "***Ability Score Increase.*** Your Intelligence score increases by 2.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "Halfling Heritage",
                    "slug": "halfling-heritage",
                    "desc": "Your darakhul character was a halfling before transforming into a darakhul. Everything you loved as a halfling—food, drink, exploration, adventure— still drives you in your undead form; it is simply a more ghoulish form of those pleasures now: raw flesh instead of stew, warm blood instead of cold mead. You still want to explore the dark corners of the world, but now you seek something different. ",
                    "asi": [
                        {
                            "attributes": [
                                "Dexterity"
                            ],
                            "value": 2
                        }
                    ],
                    "traits": "***Ill Fortune.*** Your uncanny halfling luck has taken a dark turn since your conversion to an undead creature. When a creature rolls a 20 on the d20 for an attack roll against you, the creature must reroll the attack and use the new roll. If the second attack roll misses you, the attacking creature takes necrotic damage equal to twice your Constitution modifier (minimum of 2).",
                    "asi_desc": "***Ability Score Increase.*** Your Dexterity score increases by 2.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "Human/Half-Elf Heritage",
                    "slug": "humanhalf-elf-heritage",
                    "desc": "Your darakhul character was a human or half-elf before transforming into a darakhul. Where there was once light there is now darkness. Where there was once love there is now hunger. You know if the darkness and hunger become all-consuming, you are truly lost. But the powers of your new form are strangely comfortable. How much of your old self is still there, and what can this new form give you that your old one couldn't? ",
                    "asi": [
                        {
                            "attributes": [
                                "Any"
                            ],
                            "value": 2
                        }
                    ],
                    "traits": "***Versatility.*** The training and experience of your early years was not lost when you became a darakhul. You have proficiency in two skills and one tool of your choice.",
                    "asi_desc": "***Ability Score Increase.*** One ability score of your choice, other than Constitution, increases by 2.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "Kobold Heritage",
                    "slug": "kobold-heritage",
                    "desc": "Your darakhul character was a kobold before transforming into a darakhul. The dark, although it was often your home, generally held terrors that you needed to survive. Now you are the dark, and its pull on your soul is strong. You fight to keep a grip on the intellect and cunning that sustained you in your past life. Sometimes it is easy, but often the driving hunger inside you makes it hard to think as clearly as you once did.",
                    "asi": [
                        {
                            "attributes": [
                                "Intelligence"
                            ],
                            "value": 2
                        }
                    ],
                    "traits": "***Devious Bite.*** When you hit a creature with your bite attack and you have advantage on the attack roll, your bite deals an extra 1d4 piercing damage.",
                    "asi_desc": "***Ability Score Increase.*** Your Intelligence score increases by 2.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "Ravenfolk",
                    "slug": "ravenfolk",
                    "desc": "Your darakhul character was a ravenfolk (see Midgard Heroes Handbook) before transforming into a darakhul. Your new form feels different. It is more powerful and less fidgety, and your beak has become razor sharp. There is still room for trickery, of course. But with your new life comes a disconnection from the All Father. Does this loss gnaw at you like your new hunger or do you feel freed from the destiny of your people?",
                    "asi": [
                        {
                            "attributes": [
                                "Dexterity"
                            ],
                            "value": 2
                        }
                    ],
                    "traits": "***Sudden Bite and Flight.*** If you surprise a creature during the first round of combat, you can make a bite attack as a bonus action. If it hits, you can immediately take the Dodge action as a reaction.",
                    "asi_desc": "***Ability Score Increase.*** Your Dexterity score increases by 2.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "Tiefling Heritage",
                    "slug": "tiefling-heritage",
                    "desc": "Your darakhul character was a tiefling before transforming into a darakhul. You are no stranger to the pull of powerful forces raging through your blood. You have traded one dark pull for another, and this one seems much stronger. Is that a good feeling, or do you miss your old one?",
                    "asi": [
                        {
                            "attributes": [
                                "Charisma"
                            ],
                            "value": 1
                        }
                    ],
                    "traits": "***Necrotic Rebuke.*** When you are hit by a weapon attack, you can use a reaction to envelop the attacker in shadowy flames. The attacker takes necrotic damage equal to your Charisma modifier (minimum of 1), and it has disadvantage on attack rolls until the end of its next turn. You must finish a long rest before you can use this feature again.",
                    "asi_desc": "***Ability Score Increase.*** Your Charisma score increases by 1.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "Trollkin Heritage",
                    "slug": "trollkin-heritage",
                    "desc": "Your darakhul character was a trollkin (see *Midgard Heroes Handbook*) before transforming into a darakhul. Others saw you as a monster because of your ancestry. You became inured to the fearful looks and hurried exits of those around you. If only they could see you now. Does your new state make you seek revenge on them, or are you able to maintain your self-control despite the new urges you feel?",
                    "asi": [
                        {
                            "attributes": [
                                "Strength"
                            ],
                            "value": 2
                        }
                    ],
                    "traits": "***Regenerative Bite.*** The regenerative powers of your trollkin heritage are less potent than they were in life and need a little help. As an action, you can make a bite attack against a creature that isn't undead or a construct. On a hit, you regain hit points (minimum of 1) equal to half the amount of damage dealt. Once you use this trait, you can't use it again until you finish a long rest.",
                    "asi_desc": "***Ability Score Increase.*** Your Strength score increases by 2.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                }
            ],
            "document__slug": "toh",
            "document__title": "Tome of Heroes",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
        },
        {
            "name": "Derro",
            "slug": "derro",
            "desc": "## Derro Traits\nYour derro character has certain characteristics in common with all other derro.",
            "asi_desc": "***Ability Score Increase.*** Your Dexterity score increases by 2.",
            "asi": [
                {
                    "attributes": [
                        "Dexterity"
                    ],
                    "value": 2
                }
            ],
            "age": "***Age.*** Derro reach maturity by the age of 15 and live to be around 75.",
            "alignment": "***Alignment.*** The derro's naturally unhinged minds are nearly always chaotic, and many, but not all, are evil.",
            "size": "***Size.*** Derro stand between 3 and 4 feet tall with slender limbs and wide shoulders. Your size is Small.",
            "size_raw": "Medium",
            "speed": {
                "walk": 30
            },
            "speed_desc": "***Speed.*** Derro are fast for their size. Your base walking speed is 30 feet.",
            "languages": "***Languages.*** You can speak, read, and write Dwarvish and your choice of Common or Undercommon.",
            "vision": "***Superior Darkvision.*** Accustomed to life underground, you can see in dim light within 120 feet of you as if it were bright light, and in darkness as if it were dim light. You can't discern color in darkness, only shades of gray.",
            "traits": "***Eldritch Resilience.*** You have advantage on Constitution saving throws against spells.\n\n***Sunlight Sensitivity.*** You have disadvantage on attack rolls and on Wisdom (Perception) checks that rely on sight when you, the target of your attack, or whatever you are trying to perceive is in direct sunlight.",
            "subraces": [
                {
                    "name": "Far-Touched",
                    "slug": "far-touched",
                    "desc": "You grew up firmly ensconced in the mad traditions of the derro, your mind touched by the raw majesty and power of your society's otherworldly deities. Your abilities in other areas have made you more than a typical derro, of course. But no matter how well-trained and skilled you get in other magical or martial arts, the voices of your gods forever reverberate in your ears, driving you forward to do great or terrible things.",
                    "asi": [
                        {
                            "attributes": [
                                "Charisma"
                            ],
                            "value": 1
                        }
                    ],
                    "traits": "***Insanity.*** You have advantage on saving throws against being charmed or frightened. In addition, you can read and understand Void Speech, but you can speak only a few words of the dangerous and maddening language—the words necessary for using the spells in your Mad Fervor trait.\n\n***Mad Fervor.*** The driving force behind your insanity has blessed you with a measure of its power. You know the vicious mockery cantrip. When you reach 3rd level, you can cast the enthrall spell with this trait, and starting at 5th level, you can cast the fear spell with it. Once you cast a non-cantrip spell with this trait, you can't do so again until you finish a long rest. Charisma is your spellcasting ability for these spells. If you are using Deep Magic for 5th Edition, these spells are instead crushing curse, maddening whispers, and alone, respectively.",
                    "asi_desc": "***Ability Score Increase.*** Your Charisma score increases by 1.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "Mutated",
                    "slug": "mutated",
                    "desc": "Most derro go through the process of indoctrination into their society and come out of it with visions and delusion, paranoia and mania. You, on the other hand, were not affected as much mentally as you were physically. The connection to the dark deities of your people made you stronger and gave you a physical manifestation of their gift that other derro look upon with envy and awe.",
                    "asi": [
                        {
                            "attributes": [
                                "Strength"
                            ],
                            "value": 1
                        }
                    ],
                    "traits": "***Athletic Training.*** You have proficiency in the Athletics skill, and you are proficient with two martial weapons of your choice.\n\n***Otherworldly Influence.*** Your close connection to the strange powers that your people worship has mutated your form. Choose one of the following:\n* **Alien Appendage.** You have a tentacle-like growth on your body. This tentacle is a natural melee weapon, which you can use to make unarmed strikes. When you hit with it, your tentacle deals bludgeoning damage equal to 1d4 + your Strength modifier, instead of the bludgeoning damage normal for an unarmed strike. This tentacle has a reach of 5 feet and can lift a number of pounds equal to double your Strength score. The tentacle can't wield weapons or shields or perform tasks that require manual precision, such as performing the somatic components of a spell, but it can perform simple tasks, such as opening an unlocked door or container, stowing or retrieving an object, or pouring the contents out of a vial.\n* **Tainted Blood.** Your blood is tainted by your connection with otherworldly entities. When you take piercing or slashing damage, you can use your reaction to force your blood to spray out of the wound. You and each creature within 5 feet of you take necrotic damage equal to your level. Once you use this trait, you can't use it again until you finish a short or long rest.\n* **Tenebrous Flesh.** Your skin is rubbery and tenebrous, granting you a +1 bonus to your Armor Class.",
                    "asi_desc": "***Ability Score Increase.*** Your Strength score increases by 1. ",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "Uncorrupted",
                    "slug": "uncorrupted",
                    "desc": "Someone in your past failed to do their job of driving you to the brink of insanity. It might have been a doting parent that decided to buck tradition. It might have been a touched seer who had visions of your future without the connections to the mad gods your people serve. It might have been a whole outcast community of derro rebels who refused to serve the madness of your ancestors. Whatever happened in your past, you are quite sane—or at least quite sane for a derro.",
                    "asi": [
                        {
                            "attributes": [
                                "Wisdom"
                            ],
                            "value": 1
                        }
                    ],
                    "traits": "***Psychic Barrier.*** Your time among your less sane brethren has inured you to their madness. You have resistance to psychic damage, and you have advantage on ability checks and saving throws made against effects that inflict insanity, such as spells like contact other plane and symbol, and effects that cause short-term, long-term, or indefinite madness.\n\n***Studied Insight.*** You are skilled at discerning other creature's motives and intentions. You have proficiency in the Insight skill, and, if you study a creature for at least 1 minute, you have advantage on any initiative checks in combat against that creature for the next hour.",
                    "asi_desc": "***Ability Score Increase.*** Your Wisdom score increases by 1.",
                    "document__slug": "toh",
                    "document__title": "Tome of Her
........


Char Class List
list: API endpoint for returning a list of classes and archetypes.
retrieve: API endpoint for returning a particular class or archetype.

GET /v1/classes/
HTTP 200 OK
Allow: GET, HEAD, OPTIONS
Content-Type: application/json
Vary: Accept

{
    "count": 12,
    "next": null,
    "previous": null,
    "results": [
        {
            "name": "Barbarian",
            "slug": "barbarian",
            "desc": "### Rage \n \nIn battle, you fight with primal ferocity. On your turn, you can enter a rage as a bonus action. \n \nWhile raging, you gain the following benefits if you aren't wearing heavy armor: \n \n* You have advantage on Strength checks and Strength saving throws. \n* When you make a melee weapon attack using Strength, you gain a bonus to the damage roll that increases as you gain levels as a barbarian, as shown in the Rage Damage column of the Barbarian table. \n* You have resistance to bludgeoning, piercing, and slashing damage. \n \nIf you are able to cast spells, you can't cast them or concentrate on them while raging. \n \nYour rage lasts for 1 minute. It ends early if you are knocked unconscious or if your turn ends and you haven't attacked a hostile creature since your last turn or taken damage since then. You can also end your rage on your turn as a bonus action. \n \nOnce you have raged the number of times shown for your barbarian level in the Rages column of the Barbarian table, you must finish a long rest before you can rage again. \n \n### Unarmored Defense \n \nWhile you are not wearing any armor, your Armor Class equals 10 + your Dexterity modifier + your Constitution modifier. You can use a shield and still gain this benefit. \n \n### Reckless Attack \n \nStarting at 2nd level, you can throw aside all concern for defense to attack with fierce desperation. When you make your first attack on your turn, you can decide to attack recklessly. Doing so gives you advantage on melee weapon attack rolls using Strength during this turn, but attack rolls against you have advantage until your next turn. \n \n### Danger Sense \n \nAt 2nd level, you gain an uncanny sense of when things nearby aren't as they should be, giving you an edge when you dodge away from danger. \n \nYou have advantage on Dexterity saving throws against effects that you can see, such as traps and spells. To gain this benefit, you can't be blinded, deafened, or incapacitated. \n \n### Primal Path \n \nAt 3rd level, you choose a path that shapes the nature of your rage. Choose the Path of the Berserker or the Path of the Totem Warrior, both detailed at the end of the class description. Your choice grants you features at 3rd level and again at 6th, 10th, and 14th levels. \n \n### Ability Score Improvement \n \nWhen you reach 4th level, and again at 8th, 12th, 16th, and 19th level, you can increase one ability score of your choice by 2, or you can increase two ability scores of your choice by 1. As normal, you can't increase an ability score above 20 using this feature. \n \n### Extra Attack \n \nBeginning at 5th level, you can attack twice, instead of once, whenever you take the Attack action on your turn. \n \n### Fast Movement \n \nStarting at 5th level, your speed increases by 10 feet while you aren't wearing heavy armor. \n \n### Feral Instinct \n \nBy 7th level, your instincts are so honed that you have advantage on initiative rolls. \n \nAdditionally, if you are surprised at the beginning of combat and aren't incapacitated, you can act normally on your first turn, but only if you enter your rage before doing anything else on that turn. \n \n### Brutal Critical \n \nBeginning at 9th level, you can roll one additional weapon damage die when determining the extra damage for a critical hit with a melee attack. \n \nThis increases to two additional dice at 13th level and three additional dice at 17th level. \n \n### Relentless Rage \n \nStarting at 11th level, your rage can keep you fighting despite grievous wounds. If you drop to 0 hit points while you're raging and don't die outright, you can make a DC 10 Constitution saving throw. If you succeed, you drop to 1 hit point instead. \n \nEach time you use this feature after the first, the DC increases by 5. When you finish a short or long rest, the DC resets to 10. \n \n### Persistent Rage \n \nBeginning at 15th level, your rage is so fierce that it ends early only if you fall unconscious or if you choose to end it. \n \n### Indomitable Might \n \nBeginning at 18th level, if your total for a Strength check is less than your Strength score, you can use that score in place of the total. \n \n### Primal Champion \n \nAt 20th level, you embody the power of the wilds. Your Strength and Constitution scores increase by 4. Your maximum for those scores is now 24.",
            "hit_dice": "1d12",
            "hp_at_1st_level": "12 + your Constitution modifier",
            "hp_at_higher_levels": "1d12 (or 7) + your Constitution modifier per barbarian level after 1st",
            "prof_armor": "Light armor, medium armor, shields",
            "prof_weapons": "Simple weapons, martial weapons",
            "prof_tools": "None",
            "prof_saving_throws": "Strength, Constitution",
            "prof_skills": "Choose two from Animal Handling, Athletics, Intimidation, Nature, Perception, and Survival",
            "equipment": "You start with the following equipment, in addition to the equipment granted by your background: \n \n* (*a*) a greataxe or (*b*) any martial melee weapon \n* (*a*) two handaxes or (*b*) any simple weapon \n* An explorer's pack and four javelins",
            "table": "| Level  | Proficiency Bonus | Features                      | Rages     | Rage Damage | \n|--------|-------------------|-------------------------------|-----------|-------------| \n| 1st    | +2                | Rage, Unarmored Defense       | 2         | +2          | \n| 2nd    | +2                | Reckless Attack, Danger Sense | 2         | +2          | \n| 3rd    | +2                | Primal Path                   | 3         | +2          | \n| 4th    | +2                | Ability Score Improvement     | 3         | +2          | \n| 5th    | +3                | Extra Attack, Fast Movement   | 3         | +2          | \n| 6th    | +3                | Path feature                  | 4         | +2          | \n| 7th    | +3                | Feral Instinct                | 4         | +2          | \n| 8th    | +3                | Ability Score Improvement     | 4         | +2          | \n| 9th    | +4                | Brutal Critical (1 die)       | 4         | +3          | \n| 10th   | +4                | Path feature                  | 4         | +3          | \n| 11th   | +4                | Relentless                    | 4         | +3          | \n| 12th   | +4                | Ability Score Improvement     | 5         | +3          | \n| 13th   | +5                | Brutal Critical (2 dice)      | 5         | +3          | \n| 14th   | +5                | Path feature                  | 5         | +3          | \n| 15th   | +5                | Persistent Rage               | 5         | +3          | \n| 16th   | +5                | Ability Score Improvement     | 5         | +4          | \n| 17th   | +6                | Brutal Critical (3 dice)      | 6         | +4          | \n| 18th   | +6                | Indomitable Might             | 6         | +4          | \n| 19th   | +6                | Ability Score Improvement     | 6         | +4          | \n| 20th   | +6                | Primal Champion               | Unlimited | +4          | ",
            "spellcasting_ability": "",
            "subtypes_name": "Primal Paths",
            "archetypes": [
                {
                    "name": "Path of the Berserker",
                    "slug": "path-of-the-berserker",
                    "desc": "For some barbarians, rage is a means to an end- that end being violence. The Path of the Berserker is a path of untrammeled fury, slick with blood. As you enter the berserker's rage, you thrill in the chaos of battle, heedless of your own health or well-being. \n \n##### Frenzy \n \nStarting when you choose this path at 3rd level, you can go into a frenzy when you rage. If you do so, for the duration of your rage you can make a single melee weapon attack as a bonus action on each of your turns after this one. When your rage ends, you suffer one level of exhaustion (as described in appendix A). \n \n##### Mindless Rage \n \nBeginning at 6th level, you can't be charmed or frightened while raging. If you are charmed or frightened when you enter your rage, the effect is suspended for the duration of the rage. \n \n##### Intimidating Presence \n \nBeginning at 10th level, you can use your action to frighten someone with your menacing presence. When you do so, choose one creature that you can see within 30 feet of you. If the creature can see or hear you, it must succeed on a Wisdom saving throw (DC equal to 8 + your proficiency bonus + your Charisma modifier) or be frightened of you until the end of your next turn. On subsequent turns, you can use your action to extend the duration of this effect on the frightened creature until the end of your next turn. This effect ends if the creature ends its turn out of line of sight or more than 60 feet away from you. \n \nIf the creature succeeds on its saving throw, you can't use this feature on that creature again for 24 hours. \n \n##### Retaliation \n \nStarting at 14th level, when you take damage from a creature that is within 5 feet of you, you can use your reaction to make a melee weapon attack against that creature.",
                    "document__slug": "wotc-srd",
                    "document__title": "5e Core Rules",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd"
                },
                {
                    "name": "Path of the Juggernaut",
                    "slug": "path-of-the-juggernaut",
                    "desc": "Honed to assault the lairs of powerful threats to their way of life, or defend against armed hordes of snarling goblinoids, the juggernauts represent the finest of frontline destroyers within the primal lands and beyond.\n\n##### Thunderous Blows\nStarting when you choose this path at 3rd level, your rage instills you with the strength to batter around your foes, making any battlefield your domain. Once per turn while raging, when you damage a creature with a melee attack, you can force the target to make a Strength saving throw (DC 8 + your proficiency bonus + your Strength modifier). On a failure, you push the target 5 feet away from you, and you can choose to immediately move 5 feet into the target’s previous position. ##### Stance of the Mountain\nYou harness your fury to anchor your feet to the earth, shrugging off the blows of those who wish to topple you. Upon choosing this path at 3rd level, you cannot be knocked prone while raging unless you become unconscious.\n\n##### Demolishing Might\nBeginning at 6th level, you can muster destructive force with your assault, shaking the core of even the strongest structures. All of your melee attacks gain the siege property (your attacks deal double damage to objects and structures). Your melee attacks against creatures of the construct type deal an additional 1d8 weapon damage.\n\n##### Overwhelming Cleave\nUpon reaching 10th level, you wade into armies of foes, great swings of your weapon striking many who threaten you. When you make a weapon attack while raging, you can make another attack as a bonus action with the same weapon against a different creature that is within 5 feet of the original target and within range of your weapon.\n\n##### Unstoppable\nStarting at 14th level, you can become “unstoppable” when you rage. If you do so, for the duration of the rage your speed cannot be reduced, and you are immune to the frightened, paralyzed, and stunned conditions. If you are frightened, paralyzed, or stunned, you can still take your bonus action to enter your rage and suspend the effects for the duration of the rage. When your rage ends, you suffer one level of exhaustion (as described in appendix A, PHB).",
                    "document__slug": "taldorei",
                    "document__title": "Critical Role: Tal’Dorei Campaign Setting",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "https://https://greenronin.com/blog/2017/09/25/ronin-round-table-integrating-wizards-5e-adventures-with-the-taldorei-campaign-setting/"
                },
                {
                    "name": "Path of Booming Magnificence",
                    "slug": "path-of-booming-magnificence",
                    "desc": "Barbarians who walk the Path of Booming Magnificence strive to be as lions among their people: symbols of vitality, majesty, and courage. They serve at the vanguard, leading their allies at each charge and drawing their opponents' attention away from more vulnerable members of their group. As they grow more experienced, members of this path often take on roles as leaders or in other integral positions.\n\n##### Roar of Defiance\nBeginning at 3rd level, you can announce your presence by unleashing a thunderous roar as part of the bonus action you take to enter your rage. Until the beginning of your next turn, each creature of your choice within 30 feet of you that can hear you has disadvantage on any attack roll that doesn't target you.\n  Until the rage ends, if a creature within 5 feet of you that heard your Roar of Defiance deals damage to you, you can use your reaction to bellow at them. Your attacker must succeed on a Constitution saving throw or take 1d6 thunder damage. The DC is equal to 8 + your proficiency bonus + your Charisma modifier. The damage you deal with this feature increases to 2d6 at 10th level. Once a creature takes damage from this feature, you can't use this feature on that creature again during this rage.\n\n##### Running Leap\nAt 3rd level, while you are raging, you can leap further. When you make a standing long jump, you can leap a number of feet equal to your Strength score. With a 10-foot running start, you can long jump a number of feet equal to twice your Strength score.\n\n##### Lion's Glory\nStarting at 6th level, when you enter your rage, you can choose a number of allies that can see you equal to your Charisma modifier (minimum 1). Until the rage ends, when a chosen ally makes a melee weapon attack, the ally gains a bonus to the damage roll equal to the Rage Damage bonus you gain, as shown in the Rage Damage column of the Barbarian table. Once used, you can't use this feature again until you finish a long rest.\n\n##### Resonant Bellow\nAt 10th level, your roars can pierce the fog of fear. As a bonus action, you can unleash a mighty roar, ending the frightened condition on yourself and each creature of your choice within 60 feet of you and who can hear you. Each creature that ceases to be frightened gains 1d12 + your Charisma modifier (minimum +1) temporary hit points for 1 hour. Once used, you can't use this feature again until you finish a short or long rest.\n\n##### Victorious Roar\nAt 14th level, you exult in your victories. When you hit with at least two attacks on the same turn, you can use a bonus action to unleash a victorious roar. One creature you can see within 30 feet of you must make a Wisdom saving throw with a DC equal to 8 + your proficiency bonus + your Charisma modifier. On a failure, the creature takes psychic damage equal to your barbarian level and is frightened until the end of its next turn. On a success, it takes half the damage and isn't frightened.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "Path of Hellfire",
                    "slug": "path-of-hellfire",
                    "desc": "Devils have long been known to grant power to mortals as part of a pact or bargain. While this may take the form of unique magic or boons, those who follow the Path of Hellfire are gifted with command over the fires of the Lower Planes, which they channel for short periods to become powerful and furious fighting machines.\n  While some of these barbarians are enlisted to support the devils' interests as soldiers or enforcers, some escape their devilish fates, while others still are released after their term of service.\n\n#####Hellish Aspect\nBeginning at 3rd level, when you enter your rage, you take on minor fiendish aspects. The way these aspects manifest is up to you and can include sprouting horns from your head, changing the color of your skin, growing fangs or a tail, or other small physical changes. Though infused with fiendish power, you aren't a fiend. While raging, you have resistance to fire damage, and the first creature you hit on each of your turns with a weapon attack takes 1d6 extra fire damage. This damage increases to 2d6 at 10th level.\n\n#####Hell's Vengeance\nAt 6th level, you can use your hellfire to punish enemies. If an ally you can see within 60 feet of you takes damage while you are raging, you can use your reaction to surround the attacker with hellfire, dealing fire damage equal to your proficiency bonus to it.\n\n#####Hellfire Shield\nStarting at 10th level, when you enter your rage, you can surround yourself with flames. This effect works like the fire shield spell, except you are surrounded with a warm shield only and it ends when your rage ends. Once used, you can't use this feature again until you finish a short or long rest.\n\n#####Devilish Essence\nAt 14th level, while raging, you have advantage on saving throws against spells and other magical effects, and if you take damage from a spell, you can use your reaction to gain temporary hit points equal to your barbarian level.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "Path of Mistwood",
                    "slug": "path-of-mistwood",
                    "desc": "The first barbarians that traveled the path of mistwood were elves who expanded upon their natural gifts to become masters of the forests. Over time, members of other races who saw the need to protect and cherish the green places of the world joined and learned from them. Often these warriors haunt the woods alone, only seen when called to action by something that would despoil their home.\n\n##### Bonus Proficiency\nAt 3rd level, you gain proficiency in the Stealth skill. If you are already proficient in Stealth, you gain proficiency in another barbarian class skill of your choice.\n\n##### Mistwood Defender\nStarting at 3rd level, you can use the Reckless Attack feature on ranged weapon attacks with thrown weapons, and, while you aren't within melee range of a hostile creature that isn't incapacitated, you can draw and throw a thrown weapon as a bonus action.\n  In addition, when you make a ranged weapon attack with a thrown weapon using Strength while raging, you can add your Rage Damage bonus to the damage you deal with the thrown weapon.\n\n##### From the Mist\nBeginning at 6th level, mist and fog don't hinder your vision. In addition, you can cast the misty step spell, and you can make one attack with a thrown weapon as part of the same bonus action immediately before or immediately after you cast the spell. You can cast this spell while raging. You can use this feature a number of times equal to your proficiency bonus, and you regain all expended uses when you finish a long rest.\n\n##### Mist Dance\nStarting at 10th level, when you use the Attack action while raging, you can make one attack against each creature within 5 feet of you in place of one of your attacks. You can use this feature a number of times equal to your proficiency bonus, and you regain all expended uses when you finish a long rest.\n\n##### War Band's Passage\nStarting at 14th level, when you use your From the Mist feature to cast misty step, you can bring up to two willing creatures within 5 feet of you along with you, as long as each creature isn't carrying more than its carrying capacity. Attacks against you and any creatures you bring with you have disadvantage until the start of your next turn.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "Path of the Dragon",
                    "slug": "path-of-the-dragon",
                    "desc": "Few creatures embody the power and majesty of dragons. By walking the path of the dragon, you don't solely aspire to emulate these creatures—you seek to become one. The barbarians who follow this path often do so after surviving a dragon encounter or are raised in a culture that worships them. Dragons tend to have a mixed view of the barbarians who choose this path. Some dragons, in particular the metallic dragons, view such a transformation as a flattering act of admiration. Others may recognize or even fully embrace them as useful to their own ambitions. Still others view this path as embarrassing at best and insulting at worst, for what puny, two-legged creature can ever hope to come close to the natural ferocity of a dragon? When choosing this path, consider what experiences drove you to such a course. These experiences will help inform how you deal with the judgment of dragons you encounter in the world.\n\n##### Totem Dragon\nStarting when you choose this path at 3rd level, you choose which type of dragon you seek to emulate. You can speak and read Draconic, and you are resistant to the damage type of your chosen dragon.\n\n| Dragon | Damage Type | \n|---------------------|-------------| \n| Black or Copper | Acid | \n| Blue or Bronze | Lightning | \n| Brass, Gold, or Red | Fire | \n| Green | Poison | \n| Silver or White | Cold |\n\n##### Wyrm Teeth\nAt 3rd level, your jaws extend and become dragon-like when you enter your rage. While raging, you can use a bonus action to make a melee attack with your bite against one creature you can see within 5 feet of you. You are proficient with the bite. When you hit with it, your bite deals piercing damage equal to 1d8 + your Strength modifier + damage of the type associated with your totem dragon equal to your proficiency bonus.\n\n##### Legendary Might\nStarting at 6th level, if you fail a saving throw, you can choose to succeed instead. Once you use this feature, you can't use it again until you finish a long rest. When you reach 14th level in this class, you can use this feature twice between long rests.\n\n##### Aspect of the Dragon\nAt 10th level, you take on additional draconic features while raging. When you enter your rage, choose one of the following aspects to manifest.\n\n***Dragon Heart.*** You gain temporary hit points equal to 1d12 + your barbarian level. Once you manifest this aspect, you must finish a short or long rest before you can manifest it again.\n\n***Dragon Hide.*** Scales sprout across your skin. Your Armor Class increases by 2.\n\n***Dragon Sight.*** Your senses become those of a dragon. You have blindsight out to a range of 60 feet.\n\n***Dragon Wings.*** You sprout a pair of wings that resemble those of your totem dragon. While the wings are present, you have a flying speed of 30 feet. You can't manifest your wings while wearing armor unless it is made to accommodate them, and clothing not made to accommodate your wings might be destroyed when you manifest them.\n\n##### Wyrm Lungs\nAt 14th level, while raging, you can use an action to make a breath weapon attack. You exhale your breath in a 60-foot cone. Each creature in the area must make a Dexterity saving throw (DC equal to 8 + your proficiency bonus + your Constitution modifier), taking 12d8 damage of the type associated with your totem dragon on a failed save, or half as much damage on a successful one. Once you use this feature, you can't use it again until you finish a long rest.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "Path of the Herald",
                    "slug": "path-of-the-herald",
                    "desc": "In northern lands, the savage warriors charge into battle behind chanting warrior-poets. These wise men and women collect the histories, traditions, and accumulated knowledge of the people to preserve and pass on. Barbarians who follow the Path of the Herald lead their people into battle, chanting the tribe's sagas and spurring them on to new victories while honoring the glory of the past.\n\n##### Oral Tradition\nWhen you adopt this path at 3rd level, you gain proficiency in History and Performance. If you already have proficiency in one of these skills, your proficiency bonus is doubled for ability checks you make using that skill.\n\n##### Battle Fervor\nStarting when you choose this path at 3rd level, when you enter a rage, you can expend one additional daily use of rage to allow a number of willing creatures equal to half your proficiency bonus (minimum of 1) within 30 feet of you to enter a rage as well. A target must be able to see and hear you to enter this rage. Each target gains the benefits and restrictions of the barbarian Rage class feature. In addition, the rage ends early on a target if it can no longer see or hear you.\n\n##### Lorekeeper\nAs a historian, you know how much impact the past has on the present. At 6th level, you can enter a trance and explore your people's sagas to cast the augury, comprehend languages, or identify spell, but only as a ritual. After you cast a spell in this way, you can't use this feature again until you finish a short or long rest.\n\n##### Bolstering Chant\nAt 10th level, when you end your rage as a bonus action, you regain a number of hit points equal to your barbarian level *x* 3. Alternatively, if you end your rage and other creatures are also raging due to your Battle Fervor feature, you and each creature affected by your Battle Fervor regains a number of hit points equal to your barbarian level + your Charisma modifier.\n\n##### Thunderous Oratory\nAt 14th level, while you are raging, your attacks deal an extra 2d6 thunder damage. If a creature is raging due to your Battle Fervor feature, its weapon attacks deal an extra 1d6 thunder damage. In addition, when you or a creature affected by your Battle Fervor scores a critical hit with a melee weapon attack, the target must succeed on a Strength saving throw (DC equal to 8 + your proficiency bonus + your Charisma modifier) or be pushed up to 10 feet away and knocked prone in addition to any extra damage from the critical hit.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "Path of the Inner Eye",
                    "slug": "path-of-the-inner-eye",
                    "desc": "The barbarians who follow the Path of the Inner Eye elevate their rage beyond anger to glimpse premonitions of the future.\n\n##### Anticipatory Stance\nWhen you choose this path at 3rd level, you can't be surprised unless you are incapacitated, and attacks against you before your first turn have disadvantage. If you take damage before your first turn, you can enter a rage as a reaction, gaining resistance to bludgeoning, piercing, and slashing damage from the triggering attack.\n  When you reach 8th level in this class, you get 1 extra reaction on each of your turns. This extra reaction can be used only for features granted by the Path of the Inner Eye, such as Insightful Dodge or Preemptive Parry. When you reach 18th level in this class, this increases to 2 extra reactions on each of your turns.\n\n##### Insightful Dodge\nBeginning at 6th level, when you are hit by an attack while raging, you can use your reaction to move 5 feet. If this movement takes you beyond the range of the attack, the attack misses instead. You can use this feature a number of times equal to your proficiency bonus. You regain all expended uses when you finish a long rest.\n\n##### Foretelling Tactics\nStarting at 10th level, when you hit a creature with a weapon attack while raging, up to two creatures of your choice who can see and hear you can each use a reaction to immediately move up to half its speed toward the creature you hit and make a single melee or ranged weapon attack against that creature. This movement doesn't provoke opportunity attacks. Once you use this feature, you can't use it again until you finish a short or long rest.\n\n##### Preemptive Parry\nAt 14th level, if you are raging and a creature you can see within your reach hits another creature with a weapon attack, you can use your reaction to force the attacker to reroll the attack and use the lower of the two rolls. If the result is still a hit, reduce the damage dealt by your weapon damage die + your Strength modifier.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "Path of Thorns",
                    "slug": "path-of-thorns",
                    "desc": "Path of Thorns barbarians use ancient techniques developed by the druids of old that enable them to grow thorns all over their body. The first barbarians of this path fought alongside these druids to defend the natural order. In the centuries since, the knowledge of these techniques has spread, allowing others access to this power.\n  Though named for the thorns that covered the first barbarians to walk this path, current followers of this path can display thorns, spines, or boney growths while raging.\n\n##### Blossoming Thorns\nBeginning at 3rd level, when you enter your rage, hard, sharp thorns emerge over your whole body, turning your unarmed strikes into dangerous weapons. When you hit with an unarmed strike while raging, your unarmed strike deals piercing damage equal to 1d4 + your Strength modifier, instead of the bludgeoning damage normal for an unarmed strike. In addition, while raging, when you use the Attack action with an unarmed strike on your turn, you can make one unarmed strike as a bonus action.\n  The unarmed strike damage you deal while raging increases when you reach certain levels in this class: to 1d6 at 8th level and to 1d8 at 14th level.\n\n##### Thorned Grasp\nAlso at 3rd level, when you use the Attack action to grapple a creature while raging, the target takes 1d4 piercing damage if your grapple check succeeds, and it takes 1d4 piercing damage at the start of each of your turns, provided you continue to grapple the creature and are raging. When you reach 10th level in this class, this damage increases to 2d4.\n\n##### Nature's Blessing\nAt 6th level, the thorns you grow while raging become more powerful and count as magical for the purpose of overcoming resistance and immunity to nonmagical attacks and damage. When you are hit by a melee weapon attack by a creature within 5 feet of you while raging, that creature takes 1d4 piercing damage. When you reach 10th level in this class, this damage increases to 2d4.\n  Alternatively, while raging, you can use your reaction to disarm a creature that hits you with a melee weapon while within 5 feet of you by catching its weapon in your thorns instead of the attacker taking damage from your thorns. The attacker must succeed on a Strength saving throw (DC equal to 8 + your Constitution modifier + your proficiency bonus) or drop the weapon it used to attack you. The weapon lands at its feet. The attacker must be wielding a weapon for you to use this reaction.\n\n##### Toxic Infusion\nStarting at 10th level, when you enter your rage or as a bonus action while raging, you can infuse your thorns with toxins for 1 minute. While your thorns are infused with toxins, the first creature you hit on each of your turns with an unarmed strike must succeed on a Constitution saving throw (DC equal to 8 + your Constitution modifier + your proficiency bonus) or be poisoned until the end of its next turn.\n  You can use this feature a number of times equal to your proficiency bonus. You regain all expended uses when you finish a long rest.\n\n##### Thorn Barrage\nAt 14th level, you can use an action to shoot the thorns from your body while raging. Each creature within 10 feet of you must make a Dexterity saving throw (DC equal to 8 + your Constitution modifier + your proficiency bonus), taking 4d6 piercing damage on a failed save, or half as much damage on a successful one.\n  You can use this feature a number of times equal to your proficiency bonus. You regain all expended uses when you finish a long rest.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                }
            ],
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd"
        },
        {
            "name": "Bard",
            "slug": "bard",
            "desc": "### Spellcasting \n \nYou have learned to untangle and reshape the fabric of reality in harmony with your wishes and music. \n \nYour spells are part of your vast repertoire, magic that you can tune to different situations. \n \n#### Cantrips \n \nYou know two cantrips of your choice from the bard spell list. You learn additional bard cantrips of your choice at higher levels, as shown in the Cantrips Known column of the Bard table. \n \n#### Spell Slots \n \nThe Bard table shows how many spell slots you have to cast your spells of 1st level and higher. To cast one of these spells, you must expend a slot of the spell's level or higher. You regain all expended spell slots when you finish a long rest. \n \nFor example, if you know the 1st-level spell *cure wounds* and have a 1st-level and a 2nd-level spell slot available, you can cast *cure wounds* using either slot. \n \n#### Spells Known of 1st Level and Higher \n \nYou know four 1st-level spells of your choice from the bard spell list. \n \nThe Spells Known column of the Bard table shows when you learn more bard spells of your choice. Each of these spells must be of a level for which you have spell slots, as shown on the table. For instance, when you reach 3rd level in this class, you can learn one new spell of 1st or 2nd level. \n \nAdditionally, when you gain a level in this class, you can choose one of the bard spells you know and replace it with another spell from the bard spell list, which also must be of a level for which you have spell slots. \n \n#### Spellcasting Ability \n \nCharisma is your spellcasting ability for your bard spells. Your magic comes from the heart and soul you pour into the performance of your music or oration. You use your Charisma whenever a spell refers to your spellcasting ability. In addition, you use your Charisma modifier when setting the saving throw DC for a bard spell you cast and when making an attack roll with one. \n \n**Spell save DC** = 8 + your proficiency bonus + your Charisma modifier \n \n**Spell attack modifier** = your proficiency bonus + your Charisma modifier \n \n#### Ritual Casting \n \nYou can cast any bard spell you know as a ritual if that spell has the ritual tag. \n \n#### Spellcasting Focus \n \nYou can use a musical instrument (see chapter 5, “Equipment”) as a spellcasting focus for your bard spells. \n \n### Bardic Inspiration \n \nYou can inspire others through stirring words or music. To do so, you use a bonus action on your turn to choose one creature other than yourself within 60 feet of you who can hear you. That creature gains one Bardic Inspiration die, a d6. \n \nOnce within the next 10 minutes, the creature can roll the die and add the number rolled to one ability check, attack roll, or saving throw it makes. The creature can wait until after it rolls the d20 before deciding to use the Bardic Inspiration die, but must decide before the GM says whether the roll succeeds or fails. Once the Bardic Inspiration die is rolled, it is lost. A creature can have only one Bardic Inspiration die at a time. \n \nYou can use this feature a number of times equal to your Charisma modifier (a minimum of once). You regain any expended uses when you finish a long rest. \n \nYour Bardic Inspiration die changes when you reach certain levels in this class. The die becomes a d8 at 5th level, a d10 at 10th level, and a d12 at 15th level. \n \n### Jack of All Trades \n \nStarting at 2nd level, you can add half your proficiency bonus, rounded down, to any ability check you make that doesn't already include your proficiency bonus. \n \n### Song of Rest \n \nBeginning at 2nd level, you can use soothing music or oration to help revitalize your wounded allies during a short rest. If you or any friendly creatures who can hear your performance regain hit points at the end of the short rest by spending one or more Hit Dice, each of those creatures regains an extra 1d6 hit points. \n \nThe extra hit points increase when you reach certain levels in this class: to 1d8 at 9th level, to 1d10 at 13th level, and to 1d12 at 17th level. \n \n### Bard College \n \nAt 3rd level, you delve into the advanced techniques of a bard college of your choice: the College of Lore or the College of Valor, both detailed at the end of \n \nthe class description. Your choice grants you features at 3rd level and again at 6th and 14th level. \n \n### Expertise \n \nAt 3rd level, choose two of your skill proficiencies. Your proficiency bonus is doubled for any ability check you make that uses either of the chosen proficiencies. \n \nAt 10th level, you can choose another two skill proficiencies to gain this benefit. \n \n### Ability Score Improvement \n \nWhen you reach 4th level, and again at 8th, 12th, 16th, and 19th level, you can increase one ability score of your choice by 2, or you can increase two ability scores of your choice by 1. As normal, you can't increase an ability score above 20 using this feature. \n \n### Font of Inspiration \n \nBeginning when you reach 5th level, you regain all of your expended uses of Bardic Inspiration when you finish a short or long rest. \n \n### Countercharm \n \nAt 6th level, you gain the ability to use musical notes or words of power to disrupt mind-influencing effects. As an action, you can start a performance that lasts until the end of your next turn. During that time, you and any friendly creatures within 30 feet of you have advantage on saving throws against being frightened or charmed. A creature must be able to hear you to gain this benefit. The performance ends early if you are incapacitated or silenced or if you voluntarily end it (no action required). \n \n### Magical Secrets \n \nBy 10th level, you have plundered magical knowledge from a wide spectrum of disciplines. Choose two spells from any class, including this one. A spell you choose must be of a level you can cast, as shown on the Bard table, or a cantrip. \n \nThe chosen spells count as bard spells for you and are included in the number in the Spells Known column of the Bard table. \n \nYou learn two additional spells from any class at 14th level and again at 18th level. \n \n### Superior Inspiration \n \nAt 20th level, when you roll initiative and have no uses of Bardic Inspiration left, you regain one use.",
            "hit_dice": "1d8",
            "hp_at_1st_level": "8 + your Constitution modifier",
            "hp_at_higher_levels": "1d8 (or 5) + your Constitution modifier per bard level after 1st",
            "prof_armor": "Light armor",
            "prof_weapons": "Simple weapons, hand crossbows, longswords, rapiers, shortswords",
            "prof_tools": "Three musical instruments of your choice",
            "prof_saving_throws": "Dexterity, Charisma",
            "prof_skills": "Choose any three",
            "equipment": "You start with the following equipment, in addition to the equipment granted by your background: \n \n* (*a*) a rapier, (*b*) a longsword, or (*c*) any simple weapon \n* (*a*) a diplomat's pack or (*b*) an entertainer's pack \n* (*a*) a lute or (*b*) any other musical instrument \n* Leather armor and a dagger",
            "table": "| Level | Proficiency Bonus | Features                                             | Cantrips Known | Spells Known | 1st | 2nd | 3rd | 4th | 5th | 6th | 7th | 8th | 9th | \n|-------|------------------|------------------------------------------------------|--------------|----------------|-----|-----|-----|-----|-----|-----|-----|-----|-----| \n| 1st   | +2               | Spellcasting, Bardic Inspiration (d6)                | 2            | 4              | 2   | -   | -   | -   | -   | -   | -   | -   | -   | \n| 2nd   | +2               | Jack of All Trades, Song of Rest (d6)                | 2            | 5              | 3   | -   | -   | -   | -   | -   | -   | -   | -   | \n| 3rd   | +2               | Bard College, Expertise                              | 2            | 6              | 4   | 2   | -   | -   | -   | -   | -   | -   | -   | \n| 4th   | +2               | Ability Score Improvement                            | 3            | 7              | 4   | 3   | -   | -   | -   | -   | -   | -   | -   | \n| 5th   | +3               | Bardic Inspiration (d8), Font of Inspiration         | 3            | 8              | 4   | 3   | 2   | -   | -   | -   | -   | -   | -   | \n| 6th   | +3               | Countercharm, Bard College Feature                   | 3            | 9              | 4   | 3   | 3   | -   | -   | -   | -   | -   | -   | \n| 7th   | +3               | -                                                    | 3            | 10             | 4   | 3   | 3   | 1   | -   | -   | -   | -   | -   | \n| 8th   | +3               | Ability Score Improvement                            | 3            | 11             | 4   | 3   | 3   | 2   | -   | -   | -   | -   | -   | \n| 9th   | +4               | Song of Rest (d8)                                    | 3            | 12             | 4   | 3   | 3   | 3   | 1   | -   | -   | -   | -   | \n| 10th  | +4               | Bardic Inspiration (d10), Expertise, Magical Secrets | 4            | 14             | 4   | 3   | 3   | 3   | 2   | -   | -   | -   | -   | \n| 11th  | +4               | -                                                    | 4            | 15             | 4   | 3   | 3   | 3   | 2   | 1   | -   | -   | -   | \n| 12th  | +4               | Ability Score Improvement                            | 4            | 15             | 4   | 3   | 3   | 3   | 2   | 1   | -   | -   | -   | \n| 13th  | +5               | Song of Rest (d10)                                   | 4            | 16             | 4   | 3   | 3   | 3   | 2   | 1   | 1   | -   | -   | \n| 14th  | +5               | Magical Secrets, Bard College Feature                | 4            | 18             | 4   | 3   | 3   | 3   | 2   | 1   | 1   | -   | -   | \n| 15th  | +5               | Bardic Inspiration (d12)                             | 4            | 19             | 4   | 3   | 3   | 3   | 2   | 1   | 1   | 1   | -   | \n| 16th  | +5               | Ability Score Improvement                            | 4            | 19             | 4   | 3   | 3   | 3   | 2   | 1   | 1   | 1   | -   | \n| 17th  | +6               | Song of Rest (d12)                                   | 4            | 20             | 4   | 3   | 3   | 3   | 2   | 1   | 1   | 1   | 1   | \n| 18th  | +6               | Magical Secrets                                      | 4            | 22             | 4   | 3   | 3   | 3   | 3   | 1   | 1   | 1   | 1   | \n| 19th  | +6               | Ability Score Improvement                            | 4            | 22             | 4   | 3   | 3   | 3   | 3   | 2   | 1   | 1   | 1   | \n| 20th  | +6               | Superior Inspiration                                 | 4            | 22             | 4   | 3   | 3   | 3   | 3   | 2   | 2   | 1   | 1   | ",
            "spellcasting_ability": "Charisma",
            "subtypes_name": "Bard Colleges",
            "archetypes": [
                {
                    "name": "College of Lore",
                    "slug": "college-of-lore",
                    "desc": "Bards of the College of Lore know something about most things, collecting bits of knowledge from sources as diverse as scholarly tomes and peasant tales. Whether singing folk ballads in taverns or elaborate compositions in royal courts, these bards use their gifts to hold audiences spellbound. When the applause dies down, the audience members might find themselves questioning everything they held to be true, from their faith in the priesthood of the local temple to their loyalty to the king. \n \nThe loyalty of these bards lies in the pursuit of beauty and truth, not in fealty to a monarch or following the tenets of a deity. A noble who keeps such a bard as a herald or advisor knows that the bard would rather be honest than politic. \n \nThe college's members gather in libraries and sometimes in actual colleges, complete with classrooms and dormitories, to share their lore with one another. They also meet at festivals or affairs of state, where they can expose corruption, unravel lies, and poke fun at self-important figures of authority. \n \n##### Bonus Proficiencies \n \nWhen you join the College of Lore at 3rd level, you gain proficiency with three skills of your choice. \n \n##### Cutting Words \n \nAlso at 3rd level, you learn how to use your wit to distract, confuse, and otherwise sap the confidence and competence of others. When a creature that you can see within 60 feet of you makes an attack roll, an ability check, or a damage roll, you can use your reaction to expend one of your uses of Bardic Inspiration, rolling a Bardic Inspiration die and subtracting the number rolled from the creature's roll. You can choose to use this feature after the creature makes its roll, but before the GM determines whether the attack roll or ability check succeeds or fails, or before the creature deals its damage. The creature is immune if it can't hear you or if it's immune to being charmed. \n \n##### Additional Magical Secrets \n \nAt 6th level, you learn two spells of your choice from any class. A spell you choose must be of a level you can cast, as shown on the Bard table, or a cantrip. The chosen spells count as bard spells for you but don't count against the number of bard spells you know. \n \n##### Peerless Skill \n \nStarting at 14th level, when you make an ability check, you can expend one use of Bardic Inspiration. Roll a Bardic Inspiration die and add the number rolled to your ability check. You can choose to do so after you roll the die for the ability check, but before the GM tells you whether you succeed or fail.",
                    "document__slug": "wotc-srd",
                    "document__title": "5e Core Rules",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd"
                },
                {
                    "name": "College of Echoes",
                    "slug": "college-of-echoes",
                    "desc": "In the caverns beneath the surface of the world, sound works differently. Your exposure to echoes has taught you about how sound changes as it moves and encounters obstacles. Inspired by the effect caves and tunnels have on sounds, you have learned to manipulate sound with your magic, curving it and altering it as it moves. You can silence the most violent explosions, you can make whispers seem to reverberate forever, and you can even change the sounds of music and words as they are created.\n\n##### Echolocation\nWhen you join the College of Echoes at 3rd level, you learn how to see with your ears as well as your eyes. As long as you can hear, you have blindsight out to a range of 10 feet, and you have disadvantage on saving throws against effects that would deafen you. At 14th level, your blindsight is now out to a range of 15 feet, and you no longer have disadvantage on saving throws against effects that would deafen you.\n\n##### Alter Sound\n \nAt 3rd level, you can manipulate the sounds of your speech to mimic any sounds you've heard, including voices. A creature that hears the sounds can tell they are imitations with a successful Wisdom (Insight) check contested by your Charisma (Deception) check.\n  In addition, you can manipulate some of the sounds around you. You can use your reaction to cause one of the following effects. \n\n***Enhance.*** You can increase the volume of a sound originating within 30 feet of you, doubling the range it can be heard and granting creatures in range of the sound advantage on Wisdom (Perception) checks to detect the sound. In addition, when a hostile creature within 30 feet of you takes thunder damage, you can expend one use of Bardic Inspiration and increase the thunder damage by an amount equal to the number you roll on the Bardic Inspiration die.\n\n***Dampen.*** You can decrease the volume of a sound originating within 30 feet of you, halving the range it can be heard and granting creatures in range of the sound disadvantage on Wisdom (Perception) checks to detect the sound. In addition, when a friendly creature within 30 feet of you takes thunder damage, you can expend one use of Bardic Inspiration and decrease the thunder damage by an amount equal to the number you roll on the Bardic Inspiration die.\n\n**Distort.** You can change 1 word or up to 2 notes within 30 feet of you to another word or other notes. You can expend one use of Bardic Inspiration to change a number of words within 30 feet of you equal to 1 + the number you roll on the Bardic Inspiration die, or you can change a number of notes of a melody within 30 feet of you equal to 2 + double the number you roll on the Bardic Inspiration die. A creature that can hear the sound can notice it was altered by succeeding on a Wisdom (Perception) check contested by your Charisma (Deception) check. At your GM's discretion, this effect can alter sounds that aren't words or melodies, such as altering the cries of a young animal to sound like the roars of an adult.\n\n***Disrupt.*** When a spellcaster casts a spell with verbal components within 30 feet of you, you can expend one use of your Bardic Inspiration to disrupt the sounds of the verbal components. The spellcaster must succeed on a concentration check (DC 8 + the number you roll on the Bardic Inspiration die) or the spell fails and has no effect. You can disrupt a spell only if it is of a spell level you can cast.\n\n##### Resounding Strikes\nStarting at 6th level, when you hit a creature with a melee weapon attack, you can expend one spell slot to deal thunder damage to the target, in addition to the weapon's damage. The extra damage is 1d6 for a 1st-level spell slot, plus 1d6 for each spell level higher than 1st, to a maximum of 6d6. The damage increases by 1d6 if the target is made of inorganic material such as stone, crystal, or metal.\n\n##### Reverberating Strikes\nAt 14th level, your Bardic Inspiration infuses your allies' weapon attacks with sonic power. A creature that has a Bardic Inspiration die from you can roll that die and add the number rolled to a weapon damage roll it just made, and all of the damage from that attack becomes thunder damage. The target of the attack must succeed on a Strength saving throw against your spell save DC or be knocked prone.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "College of Investigation",
                    "slug": "college-of-investigation",
                    "desc": "Bards pick up all sorts of information as they travel the land. Some bards focus on a certain type of information, like epic poetry, love ballads, or bawdy drinking songs. Others, however, turn to the shadowy occupation of investigating crimes. These bards use their knack for gathering information to learn about criminals and vigilantes, their tactics, and their weaknesses. Some work with agents of the law to catch criminals, but shadier members of this college use their dark knowledge to emulate the malefactors they have studied for so long.\n\n##### Bonus Proficiencies\nWhen you join the College of Investigation at 3rd level, you gain proficiency in the Insight skill and in two of the following skills of your choice: Acrobatics, Deception, Investigation, Performance, Sleight of Hand, or Stealth.\n\n##### Quick Read\nAt 3rd level, your knowledge of underhanded tactics allows you to gain insight into your foes' strategies. As a bonus action, you can expend one use of Bardic Inspiration to make a Wisdom (Insight) check against one creature you can see within 30 feet contested by the creature's Charisma (Deception) check. Add the number you roll on the Bardic Inspiration die to the result of your check. You have disadvantage on this check if the target is not a humanoid, and the check automatically fails against creatures with an Intelligence score of 3 or lower. On a success, you gain one of the following benefits: \n* The target has disadvantage on attack rolls against you for 1 minute. \n* You have advantage on saving throws against the target's spells and magical effects for 1 minute. \n* You have advantage on attack rolls against the target for 1 minute.\n\n##### Bardic Instinct\nStarting at 6th level, you can extend your knowledge of criminal behavior to your companions. When a creature that has a Bardic Inspiration die from you is damaged by a hostile creature's attack, it can use its reaction to roll that die and reduce the damage by twice the number rolled. If this reduces the damage of the attack to 0, the creature you inspired can make one melee attack against its attacker as part of the same reaction.\n\n##### Hot Pursuit\nStarting at 14th level, when a creature fails a saving throw against one of your bard spells, you can designate it as your mark for 24 hours. You know the direction to your mark at all times unless it is within an antimagic field, it is protected by an effect that prevents scrying such as nondetection, or there is a barrier of lead at least 1 inch thick between you.\n  In addition, whenever your mark makes an attack roll, you can expend one use of Bardic Inspiration to subtract the number rolled from the mark's attack roll. Alternatively, whenever you make a saving throw against a spell or magical effect from your mark, you can expend one use of Bardic Inspiration to add the number rolled to your saving throw. You can choose to expend the Bardic Inspiration after the attack or saving throw is rolled but before the outcome is determined.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "College of Shadows",
                    "slug": "college-of-shadows",
                    "desc": "Some bards are as proficient in the art of espionage as they are in poetry and song. Their primary medium is information and secrets, though they are known to slip a dagger between ribs when necessary. Masters of insight and manipulation, these bards use every tool at their disposal in pursuit of their goals, and they value knowledge above all else. The more buried a secret, the deeper they delve to uncover it. Knowledge is power; it can cement empires or topple dynasties.\n  College of Shadows bards undergo careful training before they're sent out into the world. Skilled in both music and manipulation, they're the perfect blend of charm and cunning. The tricks they learn in their tutelage make them ideal for the subtle work of coaxing out secrets, entrancing audiences, and dazzling the minds of their chosen targets.\n\n##### Bonus Proficiencies\nWhen you join the College of Shadows at 3rd level, you gain proficiency in Stealth and in two other skills of your choice.\n\n##### Mantle of Shadows\nStarting at 3rd level, while you are in dim light or darkness, you can use an action to twist the shadows around you for 1 minute or until your concentration ends. For the duration, you have advantage on Dexterity (Stealth) checks, and you can take the Dash action as a bonus action on each of your turns.\n\n##### Cunning Insight\nStarting at 6th level, you know exactly where to hit your enemies. You can use an action to focus on a creature you can see within 60 feet of you. The target must make a Wisdom saving throw against your spell save DC. You can use this feature as a bonus action if you expend a Bardic Inspiration die. If you do, roll the die and subtract the number rolled from the target's saving throw roll. If the target fails the saving throw, choose one of the following: \n* You have advantage on your next attack roll against the target. \n* You know the target's damage vulnerabilities. \n* You know the target's damage resistances and damage immunities. \n* You know the target's condition immunities. \n* You see through any illusions obscuring or affecting the target for 1 minute.\n\n##### Shadowed Performance\nStarting at 14th level, you are a master at weaving stories and influencing the minds of your audience. If you perform for at least 1 minute, you can attempt to make or break a creature's reputation by relaying a tale to an audience through song, poetry, play, or other medium. At the end of the performance, choose a number of humanoids who witnessed the entire performance, up to a number equal to 1 plus your Charisma modifier. Each target must make a Wisdom saving throw against your spell save DC. On a failed save, a target suffers one of the following (your choice): \n* For 24 hours, the target believes the tale you told is true and will tell others the tale as if it were truth. \n* For 1 hour, the target believes *someone* nearby knows their darkest secret, and they have disadvantage on Charisma, Wisdom, and Intelligence ability checks and saving throws as they are distracted and overcome with paranoia. \n* The target becomes convinced that you (or one of your allies if you choose to sing the praises of another) are a fearsome opponent. For 1 minute, the target is frightened of you (or your ally), and you (or your ally) have advantage on attack rolls against the target. A *remove curse* or *greater restoration* spell ends this effect early. You can't use this feature again until you finish a short or long rest.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "College of Sincerity",
                    "slug": "college-of-sincerity",
                    "desc": "Bards of the College of Sincerity know it is easier for someone to get what they want when they mask their true intentions behind a pleasant façade. These minstrels gain a devoted following and rarely lack for company. Some of their devotees go so far as to put themselves at the service of the bard they admire. Though members of the college can be found as traveling minstrels and adventuring troubadours, they gravitate to large urban areas where their silver tongues and mind-bending performances have the greatest influence. Devious rulers sometimes seek out members of the college as counsellors, but the rulers must be wary lest they become a mere pawn of their new aide.\n\n##### Entourage\nWhen you join the College of Sincerity at 3rd level, you gain the service of two commoners. Your entourage is considered charmed by you and travels with you to see to your mundane needs, such as making your meals and doing your laundry. If you are in an urban area, they act as your messengers and gofers. When you put on a performance, they speak your praises and rouse the crowd to applause. In exchange for their service, you must provide your entourage a place to live and pay the costs for them to share the same lifestyle as you.\n  Your entourage doesn't join combat or venture into obviously dangerous areas or situations. If you or your companions abuse or mistreat your entourage, they leave your service immediately. If this occurs, you can gain the service of a new entourage by traveling to a different urban area where you must perform at least 1 hour each day for one week.\n  You gain another commoner at 6th level, and a final one at 14th level. If you prefer, instead of gaining a new commoner at 6th level, one member of your entourage can become a guard. At 14th level, if you have a guard, it can become your choice of a spy or veteran, instead of taking on a new commoner. If one member of your entourage becomes a guard, spy, or veteran, that person accompanies you into dangerous situations, but they only use the Help action to aid you, unless you use a bonus action to direct them to take a specific action. At the GM's discretion, you can replace the guard with another humanoid of CR 1/8 or lower, the spy with another humanoid of CR 1 or lower, and the veteran with another humanoid of CR 3 or lower.\n\n##### Kind-Eyed Smile\nAlso at 3rd level, when you cast an enchantment spell, such as *charm person*, your target remains unaware of your attempt to affect its mind, regardless of the result of its saving throw. When the duration of an enchantment spell you cast ends, your target remains unaware that you enchanted it. If the description of the spell you cast states the creature is aware you influenced it with magic, it isn't aware you enchanted it unless it succeeds on a Charisma saving throw against your spell save DC.\n\n##### Lingering Presence\nStarting at 6th level, if a creature fails a saving throw against an enchantment or illusion spell you cast, it has disadvantage on subsequent saving throws it makes to overcome the effects of your spell. For example, a creature affected by your *hold person* spell has disadvantage on the saving throw it makes at the end of each of its turns to end the paralyzed effect.\n\n##### Artist of Renown\nAt 14th level, you can expend a Bardic Inspiration die to cast an enchantment spell you don't know using one of your spell slots. When you do so, you must be able to meet all of the spell's requirements, and you must have an available spell slot of sufficient level.\n  You can't use your Font of Inspiration feature to regain Bardic Inspiration dice expended to cast spells with this feature after a short rest. Bardic Inspiration dice expended by this feature are regained only after you finish a long rest.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "College of Tactics",
                    "slug": "college-of-tactics",
                    "desc": "Bards of the College of Tactics are calculating strategists who scour historical records of famous battles for tricks they can use to give their own troops, and those of their patrons, an edge on the battlefield. Members of this college travel from war zone to combat site and interview the veterans of those engagements, trying to discern how the victors won the day and leveraging that information for their personal glory.\n\n##### Combat Tactician\nWhen you join the College of Tactics at 3rd level, you gain proficiency with medium armor, shields, and one martial weapon of your choice. In addition, you can use Bardic Inspiration a number of times equal to your Charisma modifier (a minimum of 1) + your proficiency bonus. You regain expended uses when you finish a long rest (or short rest if you have the Font of Inspiration feature), as normal.\n\n##### Setting the Board\nAlso at 3rd level, you can move your allies into more advantageous positions, just as a general moves troop markers on a map. As a bonus action, you can command up to three willing allies who can see or hear you to use a reaction to move. Each target can move up to half its speed. This movement doesn't provoke opportunity attacks.\n  You can use this feature a number of times equal to your proficiency bonus. You regain all expended uses when you finish a long rest.\n\n##### Song of Strategy\nBeginning at 6th level, you can share your tactical knowledge with your allies in the heat of battle. A creature that has a Bardic Inspiration die from you can roll that die and perform one of the following strategies. For the purpose of these strategies, “you” refers to the creature with the Bardic Inspiration die.\n\n***Bait and Bleed.*** If you take the Dodge action, you can make one melee attack against a creature that is within 5 feet of you, adding the number rolled to your attack roll.\n\n***Counter Offensive.*** If you take damage from a creature, you can use your reaction to make one attack against your attacker, adding the number rolled to your attack roll. You can't use this strategy if the attacker is outside your weapon's normal range or reach.\n\n***Distraction.*** You can take the Disengage action as a bonus action, increasing your speed by 5 feet *x* the number rolled.\n\n***Frightening Charge.*** If you take the Dash action, you can make one melee attack at the end of the movement, adding the number rolled to your attack roll. If the attack is a critical hit, the target is frightened until the start of your next turn.\n\n***Hold Steady.*** If you take the Ready action and the trigger for the readied action doesn't occur, you can make one weapon or spell attack roll after all other creatures have acted in the round, adding the number rolled to the attack roll.\n\n***Indirect Approach.*** If you take the Help action to aid a friendly creature in attacking a creature within 5 feet of you, the friendly creature can add the number rolled to their attack roll against the target, and each other friendly creature within 5 feet of you has advantage on its first attack roll against the target.\n\n##### Ablative Inspiration\nStarting at 14th level, when you take damage from a spell or effect that affects an area, such as the *fireball* spell or a dragon's breath weapon, you can expend one use of your Bardic Inspiration as a reaction to redirect and dissipate some of the spell's power. Roll the Bardic Inspiration die and add the number rolled to your saving throw against the spell. If you succeed on the saving throw, each friendly creature within 10 feet of you is also treated as if it succeeded on the saving throw.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "College of the Cat",
                    "slug": "college-of-the-cat",
                    "desc": "Scholars and spies, heroes and hunters: whether wooing an admirer in the bright sunlight or stalking prey under the gentle rays of the moon, bards of the College of the Cat excel at diverse skills and exhibit contrary tendencies. The adventurous spirits who favor the College of the Cat let their curiosity and natural talents get them into impossible places. Most are skilled, cunning, and vicious enough to extricate themselves from even the most dangerous situations.\n\n##### Bonus Proficiencies\nWhen you join the College of the Cat at 3rd level, you gain proficiency with the Acrobatics and Stealth skills and with thieves' tools if you don't already have them. In addition, if you're proficient with a simple or martial melee weapon, you can use it as a spellcasting focus for your bard spells.\n\n##### Inspired Pounce\nAlso at 3rd level, you learn to stalk unsuspecting foes engaged in combat with your allies. When an ally you can see uses one of your Bardic Inspiration dice on a weapon attack roll against a creature, you can use your reaction to move up to half your speed and make one melee weapon attack against that creature. You gain a bonus on your attack roll equal to the result of the spent Bardic Inspiration die.\n  When you reach 6th level in this class, you gain a climbing speed equal to your walking speed, and when you use Inspired Pounce, you can move up to your speed as part of the reaction.\n\n##### My Claws Are Sharp\nBeginning at 6th level, you can attack twice, instead of once, whenever you take the Attack action on your turn. In addition, when you use two-weapon fighting to make an attack as a bonus action, you can give a Bardic Inspiration die to a friendly creature within 60 feet of you as part of that same bonus action.\n\n##### Catlike Tread\nStarting at 14th level, while a creature has one of your Bardic Inspiration dice, it has advantage on Dexterity (Stealth) checks. When you have no uses of Bardic Inspiration left, you have advantage on Dexterity (Stealth) checks.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "College of Skalds",
                    "slug": "college-of-skalds",
                    "desc": "Skalds are poets of battle, recounting the deeds of heroes and the bloody battles that shook nations. But you do more than just tell stories; a skald draws on the tales of past greatness in his own quest for glory on the battlefield. While learning the sagas of bygone years, you have also taken up a practical study of combat, allowing you to use more weapons and with greater effectiveness than most bards. When you sing the song of battle to bolster your allies, you are right alongside them, going toe to toe with formidable foes to become worthy of the poems from the skalds who will recount your tale.\n\n##### Combat Aptitude\n\nWhen you choose the College of Skalds at 3rd level, you become proficient in all martial weapons, as well as in the use of medium armor and shields.\n\n##### Saga of Deeds\n\nStarting at 3rd level, you can use your stories of the great battles of legend to inspire your allies in combat. The dice gained from your Bardic Inspiration feature can be used in the following ways:\n\n* After rolling damage for a successful weapon attack, a creature can choose to roll a Bardic Inspiration die and add the result to the damage dealt.\n* When a creature is the target of an attack roll, before knowing whether the rolled number is a hit or a miss, it may roll a Bardic Inspiration die as a reaction, adding the result to its armor class for this specific attack only.\n\n##### Battle Fury\n\nAt 6th level, you can unleash even more fury in combat. When you use the attack action, you can make two attacks instead of one.\n\n##### Song and Strike\n\nStarting at 14th level, you can wade into combat even as you wield your bardic magic. Any time you cast a bard spell as an action, you can use your bonus action to make a single weapon attack.",
                    "document__slug": "o5e",
                    "document__title": "Open5e Original Content",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "open5e.com"
                }
            ],
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd"
        },
        {
            "name": "Cleric",
            "slug": "cleric",
            "desc": "### Spellcasting \n \nAs a conduit for divine power, you can cast cleric spells. \n \n#### Cantrips \n \nAt 1st level, you know three cantrips of your choice from the cleric spell list. You learn additional cleric cantrips of your choice at higher levels, as shown in the Cantrips Known column of the Cleric table. \n \n#### Preparing and Casting Spells \n \nThe Cleric table shows how many spell slots you have to cast your spells of 1st level and higher. To cast one of these spells, you must expend a slot of the spell's level or higher. You regain all expended spell slots when you finish a long rest. \n \nYou prepare the list of cleric spells that are available for you to cast, choosing from the cleric spell list. When you do so, choose a number of cleric spells equal to your Wisdom modifier + your cleric level (minimum of one spell). The spells must be of a level for which you have spell slots. \n \nFor example, if you are a 3rd-level cleric, you have four \n1st-level and two 2nd-level spell slots. With a Wisdom of 16, your list of prepared spells can include six spells of 1st or 2nd level, in any combination. If you prepare the 1st-level spell *cure wounds*, you can cast it using a 1st-level or 2nd-level slot. Casting the spell doesn't remove it from your list of prepared spells. \n \nYou can change your list of prepared spells when you finish a long rest. Preparing a new list of cleric spells requires time spent in prayer and meditation: at least 1 minute per spell level for each spell on your list. \n \n#### Spellcasting Ability \n \nWisdom is your spellcasting ability for your cleric spells. The power of your spells comes from your devotion to your deity. You use your Wisdom whenever a cleric spell refers to your spellcasting ability. In addition, you use your Wisdom modifier when setting the saving throw DC for a cleric spell you cast and when making an attack roll with one. \n \n**Spell save DC** = 8 + your proficiency bonus + your Wisdom modifier \n \n**Spell attack modifier** = your proficiency bonus + your Wisdom modifier \n \n#### Ritual Casting \n \nYou can cast a cleric spell as a ritual if that spell has the ritual tag and you have the spell prepared. \n \n#### Spellcasting Focus \n \nYou can use a holy symbol (see chapter 5, “Equipment”) as a spellcasting focus for your cleric spells. \n \n### Divine Domain \n \nChoose one domain related to your deity: Knowledge, Life, Light, Nature, Tempest, Trickery, or War. Each domain is detailed at the end of the class description, and each one provides examples of gods associated with it. Your choice grants you domain spells and other features when you choose it at 1st level. It also grants you additional ways to use Channel Divinity when you gain that feature at 2nd level, and additional benefits at 6th, 8th, and 17th levels. \n \n#### Domain Spells \n \nEach domain has a list of spells-its domain spells- that you gain at the cleric levels noted in the domain description. Once you gain a domain spell, you always have it prepared, and it doesn't count against the number of spells you can prepare each day. \n \nIf you have a domain spell that doesn't appear on the cleric spell list, the spell is nonetheless a cleric spell for you. \n \n### Channel Divinity \n \nAt 2nd level, you gain the ability to channel divine energy directly from your deity, using that energy to fuel magical effects. You start with two such effects: Turn Undead and an effect determined by your domain. Some domains grant you additional effects as you advance in levels, as noted in the domain description. \n \nWhen you use your Channel Divinity, you choose which effect to create. You must then finish a short or long rest to use your Channel Divinity again. \n \nSome Channel Divinity effects require saving throws. When you use such an effect from this class, the DC equals your cleric spell save DC. \n \nBeginning at 6th level, you can use your Channel \n \nDivinity twice between rests, and beginning at 18th level, you can use it three times between rests. When you finish a short or long rest, you regain your expended uses. \n \n#### Channel Divinity: Turn Undead \n \nAs an action, you present your holy symbol and speak a prayer censuring the undead. Each undead that can see or hear you within 30 feet of you must make a Wisdom saving throw. If the creature fails its saving throw, it is turned for 1 minute or until it takes any damage. \n \nA turned creature must spend its turns trying to move as far away from you as it can, and it can't willingly move to a space within 30 feet of you. It also can't take reactions. For its action, it can use only the Dash action or try to escape from an effect that prevents it from moving. If there's nowhere to move, the creature can use the Dodge action. \n \n### Ability Score Improvement \n \nWhen you reach 4th level, and again at 8th, 12th, 16th, and 19th level, you can increase one ability score of your choice by 2, or you can increase two ability scores of your choice by 1. As normal, you can't increase an ability score above 20 using this feature. \n \n### Destroy Undead \n \nStarting at 5th level, when an undead fails its saving throw against your Turn Undead feature, the creature is instantly destroyed if its challenge rating is at or below a certain threshold, as shown in the Destroy Undead table. \n \n**Destroy Undead (table)** \n \n| Cleric Level | Destroys Undead of CR... | \n|--------------|--------------------------| \n| 5th          | 1/2 or lower             | \n| 8th          | 1 or lower               | \n| 11th         | 2 or lower               | \n| 14th         | 3 or lower               | \n| 17th         | 4 or lower               | \n \n### Divine Intervention \n \nBeginning at 10th level, you can call on your deity to intervene on your behalf when your need is great. \n \nImploring your deity's aid requires you to use your action. Describe the assistance you seek, and roll percentile dice. If you roll a number equal to or lower than your cleric level, your deity intervenes. The GM chooses the nature of the intervention; the effect of any cleric spell or cleric domain spell would be appropriate. \n \nIf your deity intervenes, you can't use this feature again for 7 days. Otherwise, you can use it again after you finish a long rest. \n \nAt 20th level, your call for intervention succeeds automatically, no roll required.",
            "hit_dice": "1d8",
            "hp_at_1st_level": "8 + your Constitution modifier",
            "hp_at_higher_levels": "1d8 (or 5) + your Constitution modifier per cleric level after 1st",
            "prof_armor": "Light armor, medium armor, shields",
            "prof_weapons": "Simple weapons",
            "prof_tools": "None",
            "prof_saving_throws": "Wisdom, Charisma",
            "prof_skills": "Choose two from History, Insight, Medicine, Persuasion, and Religion",
            "equipment": "You start with the following equipment, in addition to the equipment granted by your background: \n \n* (*a*) a mace or (*b*) a warhammer (if proficient) \n* (*a*) scale mail, (*b*) leather armor, or (*c*) chain mail (if proficient) \n* (*a*) a light crossbow and 20 bolts or (*b*) any simple weapon \n* (*a*) a priest's pack or (*b*) an explorer's pack \n* A shield and a holy symbol",
            "table": "| Level | Proficiency Bonus | Features                                                                | Cantrips Known | 1st | 2nd | 3rd | 4th | 5th | 6th | 7th | 8th | 9th | \n|-------|-------------------|-------------------------------------------------------------------------|----------------|-----|-----|-----|-----|-----|-----|-----|-----|-----| \n| 1st   | +2                | Spellcasting, Divine Domain                                             | 3              | 2   | -   | -   | -   | -   | -   | -   | -   | -   | \n| 2nd   | +2                | Channel Divinity (1/rest), Divine Domain Feature                        | 3              | 3   | -   | -   | -   | -   | -   | -   | -   | -   | \n| 3rd   | +2                | -                                                                       | 3              | 4   | 2   | -   | -   | -   | -   | -   | -   | -   | \n| 4th   | +2                | Ability Score Improvement                                               | 4              | 4   | 3   | -   | -   | -   | -   | -   | -   | -   | \n| 5th   | +3                | Destroy Undead (CR 1/2)                                                 | 4              | 4   | 3   | 2   | -   | -   | -   | -   | -   | -   | \n| 6th   | +3                | Channel Divinity (2/rest), Divine Domain Feature                        | 4              | 4   | 3   | 3   | -   | -   | -   | -   | -   | -   | \n| 7th   | +3                | -                                                                       | 4              | 4   | 3   | 3   | 1   | -   | -   | -   | -   | -   | \n| 8th   | +3                | Ability Score Improvement, Destroy Undead (CR 1), Divine Domain Feature | 4              | 4   | 3   | 3   | 2   | -   | -   | -   | -   | -   | \n| 9th   | +4                | -                                                                       | 4              | 4   | 3   | 3   | 3   | 1   | -   | -   | -   | -   | \n| 10th  | +4                | Divine Intervention                                                     | 5              | 4   | 3   | 3   | 3   | 2   | -   | -   | -   | -   | \n| 11th  | +4                | Destroy Undead (CR 2)                                                   | 5              | 4   | 3   | 3   | 3   | 2   | 1   | -   | -   | -   | \n| 12th  | +4                | Ability Score Improvement                                               | 5              | 4   | 3   | 3   | 3   | 2   | 1   | -   | -   | -   | \n| 13th  | +5                | -                                                                       | 5              | 4   | 3   | 3   | 3   | 2   | 1   | 1   | -   | -   | \n| 14th  | +5                | Destroy Undead (CR 3)                                                   | 5              | 4   | 3   | 3   | 3   | 2   | 1   | 1   | -   | -   | \n| 15th  | +5                | -                                                                       | 5              | 4   | 3   | 3   | 3   | 2   | 1   | 1   | 1   | -   | \n| 16th  | +5                | Ability Score Improvement                                               | 5              | 4   | 3   | 3   | 3   | 2   | 1   | 1   | 1   | -   | \n| 17th  | +6                | Destroy Undead (CR 4), Divine Domain Feature                            | 5              | 4   | 3   | 3   | 3   | 2   | 1   | 1   | 1   | 1   | \n| 18th  | +6                | Channel Divinity (3/rest)                                               | 5              | 4   | 3   | 3   | 3   | 3   | 1   | 1   | 1   | 1   | \n| 19th  | +6                | Ability Score Improvement                                               | 5              | 4   | 3   | 3   | 3   | 3   | 2   | 1   | 1   | 1   | \n| 20th  | +6                | Divine Intervention improvement                                         | 5              | 4   | 3   | 3   | 3   | 3   | 2   | 2   | 1   | 1   |",
            "spellcasting_ability": "Wisdom",
            "subtypes_name": "Divine Domains",
            "archetypes": [
                {
                    "name": "Life Domain",
                    "slug": "life-domain",
                    "desc": "The Life domain focuses on the vibrant positive energy-one of the fundamental forces of the universe-that sustains all life. The gods of life promote vitality and health through healing the sick and wounded, caring for those in need, and driving away the forces of death and undeath. Almost any non-evil deity can claim influence over this domain, particularly agricultural deities (such as Chauntea, Arawai, and Demeter), sun gods (such as Lathander, Pelor, and Re-Horakhty), gods of healing or endurance (such as Ilmater, Mishakal, Apollo, and Diancecht), and gods of home and community (such as Hestia, Hathor, and Boldrei). \n \n**Life Domain Spells (table)** \n \n| Cleric Level | Spells                               | \n|--------------|--------------------------------------| \n| 1st          | bless, cure wounds                   | \n| 3rd          | lesser restoration, spiritual weapon | \n| 5th          | beacon of hope, revivify             | \n| 7th          | death ward, guardian of faith        | \n| 9th          | mass cure wounds, raise dead         | \n \n##### Bonus Proficiency \n \nWhen you choose this domain at 1st level, you gain proficiency with heavy armor. \n \n##### Disciple of Life \n \nAlso starting at 1st level, your healing spells are more effective. Whenever you use a spell of 1st level or higher to restore hit points to a creature, the creature regains additional hit points equal to 2 + the spell's level. \n \n##### Channel Divinity: Preserve Life \n \nStarting at 2nd level, you can use your Channel Divinity to heal the badly injured. \n \nAs an action, you present your holy symbol and evoke healing energy that can restore a number of hit points equal to five times your cleric level. Choose any creatures within 30 feet of you, and divide those hit points among them. This feature can restore a creature to no more than half of its hit point maximum. You can't use this feature on an undead or a construct. \n \n##### Blessed Healer \n \nBeginning at 6th level, the healing spells you cast on others heal you as well. When you cast a spell of 1st level or higher that restores hit points to a creature other than you, you regain hit points equal to 2 + the spell's level. \n \n##### Divine Strike \n \nAt 8th level, you gain the ability to infuse your weapon strikes with divine energy. Once on each of your turns when you hit a creature with a weapon attack, you can cause the attack to deal an extra 1d8 radiant damage to the target. When you reach 14th level, the extra damage increases to 2d8. \n \n##### Supreme Healing \n \nStarting at 17th level, when you would normally roll one or more dice to restore hit points with a spell, you instead use the highest number possible for each die. For example, instead of restoring 2d6 hit points to a creature, you restore 12.",
                    "document__slug": "wotc-srd",
                    "document__title": "5e Core Rules",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd"
                },
                {
                    "name": "Blood Domain",
                    "slug": "blood-domain",
                    "desc": "The Blood domain centers around the understanding of the natural life force within one’s own physical body. The power of blood is the power of sacrifice, the balance of life and death, and the spirit’s anchor within the mortal shell. The Gods of Blood seek to tap into the connection between body and soul through divine means, exploit the hidden reserves of will within one’s own vitality, and even manipulate or corrupt the body of others through these secret rites of crimson. Almost any neutral or evil deity can claim some influence over the secrets of blood magic and this domain, while the gods who watch from more moral realms shun its use beyond extenuating circumstance./n When casting divine spells as a Blood Domain cleric, consider ways to occasionally flavor your descriptions to tailor the magic’s effect on the opponent’s blood and vitality. Hold person might involve locking a target’s body into place from the blood stream out, preventing them from moving. Cure wounds may feature the controlling of blood like a needle and thread to close lacerations. Guardian of faith could be a floating, crimson spirit of dripping viscera who watches the vicinity with burning red eyes. Have fun with the themes!\n\n **Blood Domain Spells**\n | Cleric Level | Spells                                | \n |--------------|-------------------------------------------| \n | 1st          | *sleep*, *ray of sickness*                | \n | 3rd          | *ray of enfeeblement*, *crown of madness* | \n | 5th          | *haste*, *slow*                           | \n | 7th          | *blight*, *stoneskin*                     | \n | 9th          | *dominate person*, *hold monster*         |\n\n ##### Bonus Proficiencies\nAt 1st Level, you gain proficiency with martial weapons.\n\n ##### Bloodletting Focus\nFrom 1st level, your divine magics draw the blood from inflicted wounds, worsening the agony of your nearby foes. When you use a spell of 1st level or higher to damage to any creatures that have blood, those creatures suffer additional necrotic damage equal to 2 + the spell’s level.\n\n ##### Channel Divinity: Blood Puppet\nStarting at 2nd level, you can use your Channel Divinity to briefly control a creature’s actions against their will. As an action, you target a Large or smaller creature that has blood within 60 feet of you. That creature must succeed on a Constitution saving throw against your spell save DC or immediately move up to half of their movement in any direction of your choice and make a single weapon attack against a creature of your choice within range. Dead or unconscious creatures automatically fail their saving throw. At 8th level, you can target a Huge or smaller creature.\n\n ##### Channel Divinity: Crimson Bond\nStarting at 6th level, you can use your Channel Divinity to focus on a sample of blood from a creature that is at least 2 ounces, and that has been spilt no longer than a week ago. As an action, you can focus on the blood of the creature to form a bond and gain information about their current circumstances. You know their approximate distance and direction from you, as well as their general state of health, as long as they are within 10 miles of you. You can maintain Concentration on this bond for up to 1 hour.\nDuring your bond, you can spend an action to attempt to connect with the bonded creature’s senses. The target makes a Constitution saving throw against your spell save DC. If they succeed, the connection is resisted, ending the bond. You suffer 2d6 necrotic damage. Upon a failed saving throw, you can choose to either see through the eyes of or hear through their ears of the target for a number of rounds equal to your Wisdom modifier (minimum of 1). During this time, you are blind or deaf (respectively) with regard to your own senses. Once this connection ends, the Crimson Bond is lost.\n\n **Health State Examples**\n | 100%    | Untouched            | \n | 99%-50% | Injured              | \n | 49%-1%  | Heavily Wounded      | \n | 0%      | Unconscious or Dying | \n | –       | Dead                 |\n\n ##### Sanguine Recall\nAt 8th level, you can sacrifice a portion of your own vitality to recover expended spell slots. As an action, you recover spell slots that have a combined level equal to or less than half of your cleric level (rounded up), and none of the slots can be 6th level or higher. You immediately suffer 1d6 damage per spell slot level recovered. You can’t use this feature again until you finish a long rest.\nFor example, if you’re a 4th-level Cleric, you can recover up to two levels of spell slots. You can recover either a 2nd-level spell slot or two 1st-level spell slots. You then suffer 2d6 damage.\n\n ##### Vascular Corruption Aura\nAt 17th level, you can emit a powerful aura as an action that extends 30 feet out from you that pulses necrotic energy through the veins of nearby foes, causing them to burst and bleed. For 1 minute, any enemy creatures with blood that begin their turn within the aura or enter it for the first time on their turn immediately suffer 2d6 necrotic damage. Any enemy creature with blood that would regain hit points while within the aura only regains half of the intended number of hit points (rounded up).\nOnce you use this feature, you can’t use it again until you finish a long rest.",
                    "document__slug": "taldorei",
                    "document__title": "Critical Role: Tal’Dorei Campaign Setting",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "https://https://greenronin.com/blog/2017/09/25/ronin-round-table-integrating-wizards-5e-adventures-with-the-taldorei-campaign-setting/"
                },
                {
                    "name": "Hunt Domain",
                    "slug": "hunt-domain",
                    "desc": "Many terrible creatures prey on the villages, towns, and inns that dot the forests of Midgard. When such creatures become particularly aggressive or can't be dissuaded by local druids, the settlements often call on servants of gods of the hunt to solve the problem.\n  Deities devoted to hunting value champions who aid skillful hunters or who lead hunts themselves. Similarly, deities focused on protecting outlier settlements or who promote strengthening small communities also value such clerics. While these clerics might not have the utmost capability for tracking and killing prey, their gods grant them blessings to ensure successful hunts. These clerics might use their abilities to ensure their friends and communities have sufficient food to survive difficult times, or they might enjoy the sport of pursuing and slaying intelligent prey.\n\n**Hunt Domain Spells**\n| Cleric Level | Spells                                 | \n|--------------|----------------------------------------| \n| 1st          | *bloodbound*, *illuminate spoor*       | \n| 3rd          | *instant snare*, *mark prey*           | \n| 5th          | *going in circles*, *tracer*           | \n| 7th          | *heart-seeking arrow*, *hunting stand* | \n| 9th          | *harrying hounds*, *maim*              |\n\n##### Blessing of the Hunter\nAt 1st level, you gain proficiency in Survival. You can use your action to touch a willing creature other than yourself to give it advantage on Wisdom (Survival) checks. This blessing lasts for 1 hour or until you use this feature again.\n\n##### Bonus Proficiency\nAt 1st level, you gain proficiency with martial weapons.\n\n##### Channel Divinity: Heart Strike\nStarting at 2nd level, you can use your Channel Divinity to inflict grievous wounds. When you hit a creature with a weapon attack, you can use your Channel Divinity to add +5 to the attack's damage. If you score a critical hit with the attack, add +10 to the attack's damage instead.\n\n##### Pack Hunter\nStarting at 6th level, when an ally within 30 feet of you makes a weapon attack roll against a creature you attacked within this round, you can use your reaction to grant that ally advantage on the attack roll.\n\n##### Divine Strike\nAt 8th level, you gain the ability to infuse your weapon strikes with divine energy. Once on each of your turns when you hit a creature with a weapon attack, you can cause the attack to deal an extra 1d8 damage of the same type dealt by the weapon to the target. When you reach 14th level, the extra damage increases to 2d8.\n\n##### Deadly Stalker\nAt 17th level, you can use an action to describe or name a creature that is familiar to you or that you can see within 120 feet. For 24 hours or until the target is dead, whichever occurs first, you have advantage on Wisdom (Survival) checks to track your target and Wisdom (Perception) checks to detect your target. In addition, you have advantage on weapon attack rolls against the target. You can't use this feature again until you finish a short or long rest.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "Mercy Domain",
                    "slug": "mercy-domain",
                    "desc": "Mercy can mean promoting healing instead of harm, but it can also mean ending suffering with a quick death. These often-contradictory ideals are the two sides of mercy. The tenets of deities who embody mercy promote ways to end bloody conflicts or deliver healing magics to those in need. While mercy for some may be benevolent, for others it is decidedly not so. More pragmatic mercy gods teach the best method to relieve the agony and torment brought on by monsters and the forces of evil is to bring about the end of that evil.\n **Mercy Domain Spells (table)**\n| Cleric Level | Spells                              | \n|--------------|-------------------------------------| \n| 1st          | *divine favor*, *healing word*      | \n| 3rd          | *aid*, *ray of enfeeblement*        | \n| 5th          | *bardo*, *revivify*                 | \n| 7th          | *death ward*, *sacrificial healing* | \n| 9th          | *antilife shell*, *raise dead*      |\n\n##### Bonus Proficiencies\nWhen you choose this domain at 1st level, you take your place on the line between the two aspects of mercy: healing and killing. You gain proficiency in the Medicine skill and with the poisoner's kit. In addition, you gain proficiency with heavy armor and martial weapons.\n\n##### Threshold Guardian\nAlso at 1st level, when you hit a creature that doesn't have all of its hit points with a melee weapon attack, the weapon deals extra radiant or necrotic damage (your choice) equal to half your proficiency bonus.\n\n##### Channel Divinity: Involuntary Aid\nStarting at 2nd level, you can use your Channel Divinity to wrest the lifeforce from an injured creature and use it to heal allies. As an action, you present your holy symbol to one creature you can see within 30 feet of you that doesn't have all of its hit points. The target must make a Wisdom saving throw, taking radiant or necrotic damage (your choice) equal to three times your cleric level on a failed save, or half as much damage on a successful one. Then, one friendly creature you can see within 30 feet of you regains a number of hit points equal to the amount of damage dealt to the target.\n\n##### Bolster the Living\nAt 6th level, you gain the ability to manipulate a portion of the lifeforce that escapes a creature as it perishes. When a creature you can see dies within 30 feet of you, you can use your reaction to channel a portion of that energy into a friendly creature you can see within 30 feet of you. The friendly creature gains a bonus to attack and damage rolls equal to half your proficiency bonus until the end of its next turn.\n\n##### Divine Strike of Mercy\nAt 8th level, you gain the ability to infuse your weapon strikes with the dual nature of mercy. Once on each of your turns when you hit a creature with a weapon attack, you can cause the attack to deal an extra 1d6 radiant or necrotic damage (your choice) to the target. If the target dies from this attack, a friendly creature you can see within 5 feet of you regains hit points equal to half the damage dealt. If no friendly creature is within 5 feet of you, you regain the hit points instead. When you reach 14th level, the extra damage increases to 2d6.\n\n##### Hand of Grace and Execution\nAt 17th level, you imbue the two sides of mercy into your spellcasting. Once on each of your turns, if you cast a spell that restores hit points to one creature or deals damage to one creature, you can add your proficiency bonus to the amount of hit points restored or damage dealt.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "Portal Domain",
                    "slug": "portal-domain",
                    "desc": "You have dedicated yourself to the study and protection of the doors, gateways, and rips in the boundaries between the physical world and the infinite planar multiverse. Stepping through portals is a sacred prayer and woe betide any who seek to misuse them. Domain Spells You gain domain spells at the cleric levels listed in the Portal Domain Spells table. See the Divine Domain class feature for how domain spells work.\n\n**Portal Domain Spells**\n| Cleric Level | Spells                                    | \n|--------------|-------------------------------------------| \n| 1st          | *adjust position*, *expeditious retreat*  | \n| 3rd          | *glyph of shifting*, *misty step*         | \n| 5th          | *dimensional shove*, *portal jaunt*       | \n| 7th          | *dimension door*, *reposition*            | \n| 9th          | *pierce the veil*, *teleportation circle* |\n\n##### Bonus Proficiencies\nWhen you choose this domain at 1st level, you gain proficiency with heavy armor and either cartographer's tools or navigator's tools (your choice). In addition, you gain proficiency in the Arcana skill.\n\n##### Portal Magic\nStarting at 1st level, you gain access to spells that connect places or manipulate the space between places. Each spell with “(liminal)” listed alongside its school is a cleric spell for you, even if it doesn't appear on the cleric spell list, and you can prepare it as you would any other spell on the cleric spell list. Liminal spells include *bardo*, *devouring darkness*, *door of the far traveler*, *ethereal stairs*, *hypnagogia*, *hypnic jerk*, *mind maze*, *mirror realm*, *pierce the veil*, *reciprocating portal*, *rive*, *subliminal aversion*, and *threshold slip*. See the Magic and Spells chapter for details on these spells.\n\n##### Portal Bond\nAt 1st level, you learn to forge a bond between yourself and another creature. At the end of a short or long rest, you can touch one willing creature, establishing a magical bond between you. While bonded to a creature, you know the direction to the creature, though not its exact location, as long as you are both on the same plane of existence. As an action, you can teleport the bonded creature to an unoccupied space within 5 feet of you or to the nearest unoccupied space, provided the bonded creature is willing and within a number of miles of you equal to your proficiency bonus. Alternatively, you can teleport yourself to an unoccupied space within 5 feet of the bonded creature.\n  Once you teleport a creature in this way, you can't use this feature again until you finish a long rest. You can have only one bonded creature at a time. If you bond yourself to a new creature, the bond on the previous creature ends. Otherwise, the bond lasts until you die or dismiss it as an action.\n\n##### Channel Divinity: Dimensional Shift\nStarting at 2nd level, you can use your Channel Divinity to harness the magic of portals and teleportation. As an action, you teleport a willing target you can see, other than yourself, to an unoccupied space within 30 feet of you that you can see. When you reach 10th level in this class, you can teleport an unwilling target. An unwilling target that succeeds on a Wisdom saving throw is unaffected.\n\n##### Portal Touch\nAt 6th level, you can use a bonus action to create a small portal in a space you can see within 30 feet of you. This portal lasts for 1 minute, and it doesn't occupy the space where you create it. When you cast a spell with a range of touch, you can touch any creature within your reach or within 5 feet of the portal. While the portal is active, you can use a bonus action on each of your turns to move the portal up to 30 feet. The portal must remain within 30 feet of you. If you or the portal are ever more than 30 feet apart, the portal fades. You can have only one portal active at a time. If you create another one, the previous portal fades.\n  You can use this feature a number of times equal to your proficiency bonus. You regain all expended uses when you finish a long rest.\n\n##### Transpositional Divine Strike\nAt 8th level, you gain the ability to imbue your weapon strikes with portal magic. Once on each of your turns when you hit a creature with a weapon attack, you deal damage to the target as normal, and you open a brief portal next to your target or another creature you can see within 30 feet of you. That creature takes 1d8 damage of your weapon's type as a duplicate of your weapon lashes out at the creature from the portal. When you reach 14th level, you can choose two creatures, creating a portal next to each and dealing 1d8 damage of your weapon's type to each. Alternatively, you can choose one creature and deal 2d8 damage to it.\n\n##### Portal Mastery\nAt 17th level, when you see a creature use a magical gateway, teleport, or cast a spell that would teleport itself or another creature, you can use your reaction to reroute the effect, changing the destination to be an unoccupied space of your choice that you can see within 100 feet of you. Once you use this feature, you can't use it again until you finish a long rest, unless you expend a spell slot of 5th level or higher to use this feature again.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "Serpent Domain",
                    "slug": "serpent-domain",
                    "desc": "You embody the deadly, secretive, and mesmerizing nature of serpents. Others tremble at your majesty. You practice the stealth and envenomed attacks that give serpents their dreaded reputation, but you also learn the shedding of skin that has made snakes into symbols of medicine.\n\n**Serpent Domain Spells**\n| Cleric Level | Spells                                              | \n|--------------|-----------------------------------------------------| \n| 1st          | *charm person*, *find familiar* (snakes only)       | \n| 3rd          | *enthrall*, *protection from poison*                | \n| 5th          | *conjure animals* (snakes only), *hypnotic pattern* | \n| 7th          | *freedom of movement*, *polymorph* (snakes only)    | \n| 9th          | *dominate person*, *mislead*                        |\n\n##### Envenomed\nWhen you choose this domain at 1st level, you learn the *poison spray* cantrip. In addition, you gain proficiency in the Deception skill, with a poisoner's kit, and with martial weapons that have the Finesse property. You can apply poison to a melee weapon or three pieces of ammunition as a bonus action.\n\n##### Ophidian Tongue\nAlso at 1st level, you can communicate telepathically with serpents, snakes, and reptiles within 100 feet of you. A creature's responses, if any, are limited by its intelligence and typically convey the creature's current or most recent state, such as “hungry” or “in danger.”\n\n##### Channel Divinity: Serpent Stealth\nBeginning at 2nd level, you can use your Channel Divinity to help your allies move undetected. As an action, choose up to five creatures you can see within 30 feet of you. You and each target have advantage on Dexterity (Stealth) checks for 10 minutes.\n\n##### Serpent's Blood\nStarting at 6th level, you are immune to the poisoned condition and have resistance to poison damage.\n\n##### Divine Strike\nBeginning at 8th level, you can infuse your weapon strikes with venom. Once on each of your turns when you hit a creature with a weapon attack, you can cause the attack to deal an extra 1d8 poison damage. When you reach 14th level, the extra damage increases to 2d8.\n\n##### Transformative Molt\nBeginning at 17th level, as part of a short or long rest, you can assume a new form, your old skin crumbling to dust. You decide what your new form looks like, including height, weight, facial features, vocal tone, coloration, and distinguishing characteristics, if any. This feature works like the Change Appearance aspect of the *alter self* spell, except it lasts until you finish a short or long rest.\n  In addition, when you are reduced to less than half your hit point maximum, you can end this transformation as a reaction to regain hit points equal to 3 times your cleric level. Once you end the transformation in this way, you can't use this feature to change your appearance again until you finish a long rest.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "Shadow Domain",
                    "slug": "shadow-domain",
                    "desc": "The shadow domain embraces the darkness that surrounds all things and manipulates the transitory gray that separates light from dark. Shadow domain clerics walk a subtle path, frequently changing allegiances and preferring to operate unseen.\n\n**Shadow Domain Spells**\n| Cleric Level | Spells                                    | \n|--------------|-------------------------------------------| \n| 1st          | *bane*, *false life*                      | \n| 3rd          | *blindness/deafness*, *darkness*          | \n| 5th          | *blink*, *fear*                           | \n| 7th          | *black tentacles*, *greater invisibility* | \n| 9th          | *cone of cold*, *dream*                   |\n\n##### Cover of Night\nWhen you choose this domain at 1st level, you gain proficiency in the Stealth skill and darkvision out to a range of 60 feet. If you already have darkvision, its range increases by 30 feet. In addition, when you are in dim light or darkness, you can use a bonus action to Hide.\n\n##### Lengthen Shadow\nStarting at 1st level, you can manipulate your own shadow to extend your reach. When you cast a cleric spell with a range of touch, your shadow can deliver the spell as if you had cast the spell. Your target must be within 15 feet of you, and you must be able to see the target. You can use this feature even if you are in an area where you cast no shadow.\n  When you reach 10th level in this class, your shadow can affect any target you can see within 30 feet of you.\n\n##### Channel Divinity: Shadow Grasp\nStarting at 2nd level, you can use your Channel Divinity to turn a creature's shadow against them. As an action, choose one creature that you can see within 30 feet of you. That creature must make a Strength saving throw. If the creature fails the saving throw, it is restrained by its shadow until the end of your next turn. If the creature succeeds, it is grappled by its shadow until the end of your next turn. You can use this feature even if the target is in an area where it casts no shadow.\n\n##### Fade to Black\nAt 6th level, you can conceal yourself in shadow. As a bonus action when you are in dim light or darkness, you can magically become invisible for 1 minute. This effect ends early if you attack or cast a spell. You can use this feature a number of times equal to your proficiency bonus. You regain all expended uses when you finish a long rest.\n\n##### Potent Spellcasting\nStarting at 8th level, you add your Wisdom modifier to the damage you deal with any cleric cantrip.\n\n##### Army of Shadow\nAt 17th level, you can manipulate multiple shadows simultaneously. When you use Shadow Grasp, you can affect a number of creatures equal to your proficiency bonus.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "Vermin Domain",
                    "slug": "vermin-domain",
                    "desc": "You exemplify the cunning, stealth, and invasiveness of vermin (rodents, scorpions, spiders, ants, and other insects). As your dedication to this domain grows in strength, you realize a simple truth: vermin are everywhere, and you are legion.\n\n**Vermin Domain Spells**\n| Cleric Level | Spells  | \n|--------------|---------| \n| 1st          | *detect poison and disease*, *speak with animals* (vermin only)  | \n| 3rd          | *spider climb*, *web*  | \n| 5th          | *conjure animals* (vermin only), *fear*  | \n| 7th          | *dominate beast* (vermin only), *giant insect*  | \n| 9th          | *contagion*, *insect plague*  |\n\n##### The Unseen\nWhen you choose this domain at 1st level, you gain proficiency with shortswords and hand crossbows. You also gain proficiency in Stealth and Survival. You can communicate simple ideas telepathically with vermin, such as mice, spiders, and ants, within 100 feet of you. A vermin's responses, if any, are limited by its intelligence and typically convey the creature's current or most recent state, such as “hungry” or “in danger.”\n\n##### Channel Divinity: Swarm Step\nStarting at 2nd level, you can use your Channel Divinity to evade attackers. As a bonus action, or as reaction when you are attacked, you transform into a swarm of vermin and move up to 30 feet to an unoccupied space that you can see. This movement doesn't provoke opportunity attacks. When you arrive at your destination, you revert to your normal form.\n\n##### Legion of Bites\nAt 6th level, you can send hundreds of spectral vermin to assail an enemy and aid your allies. As an action, choose a creature you can see within 30 feet of you. That creature must succeed on a Constitution saving throw against your spell save DC or be covered in spectral vermin for 1 minute. Each time one of your allies hits the target with a weapon attack, the target takes an extra 1d4 poison damage. A creature that is immune to disease is immune to this feature.\n  You can use this feature a number of times equal to your Wisdom modifier (minimum of once). You regain all expended uses when you finish a long rest.\n\n##### Divine Strike\nAt 8th level, you gain the ability to infuse your weapon strikes with divine energy. Once on each of your turns when you hit a creature with a weapon attack, you can cause the attack to deal an extra 1d8 poison damage to the target. When you reach 14th level, the extra damage increases to 2d8.\n\n##### Verminform Blessing\nAt 17th level, you become a natural lycanthrope. You use the statistics of a wererat, though your form can take on insectoid aspects, such as mandibles, compound eyes, or antennae, instead of rat aspects; whichever aspects are most appropriate for your deity. Your alignment doesn't change as a result of this lycanthropy, and you can't spread the disease of lycanthropy.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "Wind Domain",
                    "slug": "wind-domain",
                    "desc": "You have dedicated yourself to the service of the primordial winds. In their service, you are the gentle zephyr brushing away adversity or the vengeful storm scouring the stones from the mountainside.\n\n**Wind Domain Spells**\n| Cleric Level | Spells                                                        | \n|--------------|---------------------------------------------------------------| \n| 1st          | *feather fall*, *thunderwave*                                 | \n| 3rd          | *gust of wind*, *misty step*                                  | \n| 5th          | *fly*, *wind wall*                                            | \n| 7th          | *conjure minor elementals* (air only), *freedom of movement*  | \n| 9th          | *cloudkill*, *conjure elemental* (air only)                   |\n\n##### Wind's Chosen\nWhen you choose this domain at 1st level, you learn the *mage hand* cantrip and gain proficiency in the Nature skill. When you cast *mage hand*, you can make the hand invisible, and you can control the hand as a bonus action.\n\n##### Channel Divinity: Grasp Not the Wind\nAt 2nd level, you can use your Channel Divinity to end the grappled condition on yourself and gain a flying speed equal to your walking speed until the end of your turn. You don't provoke opportunity attacks while flying in this way.\n\n##### Stormshield\nAt 6th level, when you take lightning or thunder damage, you can use your reaction to gain resistance to lightning and thunder damage, including against the triggering attack, until the start of your next turn. You can use this feature a number of times equal to your Wisdom modifier (minimum of once). You regain all expended uses when you finish a long rest.\n\n##### Divine Strike\nAt 8th level, you infuse your weapon strikes with divine energy. Once on each of your turns when you hit a creature with a weapon attack, you can cause the attack to deal an extra 1d8 thunder damage to the target. When you reach 14th level, the extra damage increases to 2d8.\n\n##### Dire Tempest\nAt 17th level, you can create a 20-foot-radius tornado of swirling wind and debris at a point you can see within 120 feet. The storm lasts until the start of your next turn. All Huge or smaller creatures within the area must make a Strength saving throw against your spell save DC. On a failure, a creature takes 8d6 bludgeoning damage and is thrown 1d4 *x* 10 feet into the air. On a success, a creature takes half the damage and isn't thrown into the air. Creatures thrown into the air take falling damage as normal and land prone.\n  In addition, each creature that starts its turn within 15 feet of the tornado must succeed on a Strength saving throw against your spell save DC or be dragged into the tornado's area. A creature that enters the tornado's area is thrown 1d4 *x* 10 feet into the air, taking falling damage as normal and landing prone.\nOnce you use this feature, you can't use it again until you finish a long rest.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "Demise Domain",
                    "slug": "demise-domain",
                    "desc": "*Compare to the core book’s Death Domain*\n\nWhile deities oversee all realms of nature and the cosmos, perhaps none is more important to mortals than their purveyance over the afterlife. The demise domain covers both gods who rule over kingdoms of the dead, such as Arawn, Ereshkigal, Mictlāntēcutli, Hades, Hel, and Osiris; it is also held by deities who oversee conflict and the actual moment of one’s demise, for instance the Morrigan and Nergal, and deities of suffering (Kiputytto) and disease (Loviatar). It includes many winter deities like Hel and Marzanna that oversee the metaphorical death of spring, and patrons of the undead like Koschei the Deathless are also served by clerics of the demise domain. The domain is often favored by evil deities like Erlik, but is not exclusive to them; noble judges of souls like Anubis and helpful psychopomps like Xolotl also have the demise domain in their portfolio. Similarly, while the demise domain is often favored by evil cultists, clerics who seek to comfort the dying or uphold the natural progression of the afterlife may also select this domain.\n\nNote: this subclass is primarily for NPCs, but a player can choose it at their Game Master’s discretion.\n\n**Demise Domain Spells (table)**\n\n| Cleric Level | Spells                                  |\n|--------------|-----------------------------------------|\n| 1st          | false life, ray of sickness             |\n| 3rd          | blindness/deafness, ray of enfeeblement |\n| 5th          | animate dead, vampiric touch            |\n| 7th          | blight, death ward                      |\n| 9th          | antilife shell, cloudkill               |\n\n##### Bonus Proficiency\n\nWhen you choose this domain at 1st level, you gain the martial weapon proficiency.\n\n#### Death’s Cut\n\nYour connection to death means that your necromantic powers can cut through more foes. You learn an additional cantrip of the necromancy school from any class spell list. When you cast any necromancy cantrip that targets a single creature, you can target a second creature within the spell’s range if it is within 5 feet of the first target.\n\n#### Channel Divinity: Killing Touch\n\nBeginning at 2nd level, when one of your melee attacks hit a creature, you can make use of your Channel Divinity to add necrotic damage equal to your cleric level times two, plus 5.\n\n#### Death Comes for All\n\nJust as death comes for all creatures, at 6th level your deathly powers affect even those who could normally withstand them. You ignore a creature’s necrotic resistance when you deal damage via spells or your Channel Divinity.\n\n##### Divine Strike\n\nAt 8th level, you gain the ability to infuse your weapon strikes with divine energy. Once on each of your turns when you hit a creature with a weapon attack, you can cause the attack to deal an extra 1d8 necrotic damage to the target. When you reach 14th level, the extra damage increases to 2d8.\n\n#### Improved Death’s Cut\n\nBeginning at 17th level, your Death’s Cut feature can apply to spells of the necromancy school of up to 5th-level in addition to cantrips. However, you must double the amount of material components used if the spell calls for them.",
                    "document__slug": "o5e",
                    "document__title": "Open5e Original Content",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "open5e.com"
                },
                {
                    "name": "Mischief Domain",
                    "slug": "mischief-domain",
                    "desc": "While most deities inspire awe with their might and power, some prefer subtler methods. Gods of the mischief domain favor cunning to advance their agendas, and they encourage this trait in the followers as well. Some deities of mischief, like Anansi and Hermes, are good natured tricksters. Some, like the impetuous Susanoo, vacillate between being helpful or hindering on a whim. Deities like Loki and Veles are primarily antagonistic to their respective pantheons, but their mercurial nature means they might make the odd alliance with their more serious kin. Gods associated with the moon, like Hecate, mirror the moon’s changing shape as patrons of mischief. Gods of fortune, like Tyche and Bes, are often tricksters who make their own luck. Meanwhile, culture heroes like Kokopelli, Lemminkäinen, and Maui often use deceit to bring prosperity to their people. These diverse deities count among their worshippers criminals, freedom fighters, and free spirits alike, united only by their willingness to upset the status quo. Some use tricks to lead people to a greater truth, while others use mischief to stay one step ahead of the competition.\n\n**Mischeif Domain Spells (table)**\n\n| Cleric Level | Spells                           |\n|--------------|----------------------------------|\n| 1st          | charm person, disguise self      |\n| 3rd          | mirror image, pass without trace |\n| 5th          | blink, dispel magic              |\n| 7th          | dimension door, polymorph        |\n| 9th          | dominate person, modify memory   |\n\n#### Spreader of Mischief\n\nAt 1st level, when you choose this domain, you can endow others with the power to make mischief. As an action, you may touch a willing creature, and that creature gains advantage when making Dexterity (Stealth) checks for the next hour. The effect ends early if you use the feature on a different creature. You may not use this feature on yourself.\n\n#### Channel Divinity: Double Trouble\n\nOnce you reach 2nd level, you gain the power to create an illusory double of yourself with the Channel Divinity class feature. You may use your action to manifest the illusion in an unoccupied space visible to you and within 30 feet of yourself. You must concentrate to maintain the illusion as if it were a spell, and you can do so for up to 1 minute. On your turn, you can use a bonus action to move up to 30 feet, but it must remain in your view and cannot move more than 120 feet away from you.\n\nWhile you maintain the illusion, when you cast a spell, you can use the position of the illusion rather than your own for determining range, area of effect, and line of sight. However, you cannot actually “see” through the illusion’s eyes, so you must rely on your own vision if the spell requires you to see a target or space.\n\nYour illusion can disorient foes, so you gain advantage on attack rolls against any creature that can see the illusion if both you and the illusion are within 5 feet of the creature.\n\n#### Channel Divinity: Walk Unseen\n\nBeginning at 6th level, with your Channel Divinity feature, you can use an action to become invisible. This invisibility lasts until the end of your next turn, or if you cast a spell or attack.\n\n#### Divine Strike\n\nAt 8th level, you gain the ability to infuse your weapon strikes with divine energy. Once on each of your turns when you hit a creature with a weapon attack, you can cause the attack to deal an extra 1d8 poison damage to the target. When you reach 14th level, the extra damage increases to 2d8.\n\n#### Double Trouble Doubled\n\nStarting at 17th level, your Double Trouble feature becomes more potent. Instead of one double, you can create up to four, and you can move as many of them as you like on your turn with a bonus action following the rules outlined in that feature.",
                    "document__slug": "o5e",
                    "document__title": "Open5e Original Content",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "open5e.com"
                },
                {
                    "name": "Storm Domain",
                    "slug": "storm-domain",
                    "desc": "Nothing inspires fear in mortals quite like a raging storm. This domain encompasses deities such as Enlil, Indra, Raijin, Taranis, Zeus, and Zojz. Many of these are the rulers of their respective pantheons, wielding the thunderbolt as a symbol of divine might. Most reside in the sky, but the domain also includes lords of the sea (like Donbettyr) and even the occasional chthonic fire deity (such as Pele). They can be benevolent (like Tlaloc), nourishing crops with life-giving rain; they can also be martial deities (such as Perun and Thor), splitting oaks with axes of lightning or battering their foes with thunderous hammers; and some (like Tiamat) are fearsome destroyers, spoken of only in whispers so as to avoid drawing their malevolent attention. Whatever their character, the awesome power of their wrath cannot be denied.\n\n**Storm Domain Spells (table)**\n\n| Cleric Level | Spells                               |\n|--------------|---------------------------------|\n| 1st          | fog cloud, thunderwave          |\n| 3rd          | gust of wind, shatter           |\n| 5th          | call lightning, sleet storm     |\n| 7th          | control water, ice storm        |\n| 9th          | destructive wave, insect plague |\n\n##### Bonus Proficiency\n\nWhen you choose this domain at 1st level, you gain proficiency with heavy armor as well as with martial weapons.\n\n##### Tempest’s Rebuke\n\nAlso starting at 1st level, you can strike back at your adversaries with thunder and lightning. If a creature hits you with an attack, you can use your reaction to target it with this ability. The creature must be within 5 feet of you, and you must be able to see it. The creature must make a Dexterity saving throw, taking 2d8 damage on a failure. On a success, the creature takes only half damage. You may choose to deal either lightning or thunder damage with this ability.\n\nYou may use this feature a number of times equal to your Wisdom modifier (at least once). When you finish a long rest, you regain your expended uses.\n\n##### Channel Divinity: Full Fury\n\nStarting at 2nd level, you can use your Channel Divinity to increase the fury of your storm based attacks. Whenever you would deal lightning or thunder damage from an attack, rather than roll damage, you can use the Channel Divinity feature to deal the maximum possible damage.\n\n##### Storm Blast\n\nBeginning at 6th level, you can choose to push a Large or smaller creature up to 10 feet away from you any time you deal lightning damage to it.\n\n##### Divine Strike\n\nAt 8th level, you gain the ability to infuse your weapon strikes with divine energy. Once on each of your turns when you hit a creature with a weapon attack, you can cause the attack to deal an extra 1d8 thunder damage to the target. When you reach 14th level, the extra damage increases to 2d8.\n\n##### Sky’s Blessing\n\nStarting at 17th level, you gain a flying speed whenever you are outdoors. Your flying speed is equal to your present walking speed.",
                    "document__slug": "o5e",
                    "document__title": "Open5e Original Content",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "open5e.com"
                }
            ],
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd"
        },
        {
            "name": "Druid",
            "slug": "druid",
            "desc": "### Druidic \n \nYou know Druidic, the secret language of druids. You can speak the language and use it to leave hidden messages. You and others who know this language automatically spot such a message. Others spot the message's presence with a successful DC 15 Wisdom (Perception) check but can't decipher it without magic. \n \n### Spellcasting \n \nDrawing on the divine essence of nature itself, you can cast spells to shape that essence to your will. \n \n#### Cantrips \n \nAt 1st level, you know two cantrips of your choice from the druid spell list. You learn additional druid cantrips of your choice at higher levels, as shown in the Cantrips Known column of the Druid table. \n \n#### Preparing and Casting Spells \n \nThe Druid table shows how many spell slots you have to cast your spells of 1st level and higher. To cast one of these druid spells, you must expend a slot of the spell's level or higher. You regain all expended spell slots when you finish a long rest. \n \nYou prepare the list of druid spells that are available for you to cast, choosing from the druid spell list. When you do so, choose a number of druid spells equal to your Wisdom modifier + your druid level (minimum of one spell). The spells must be of a level for which you have spell slots. \n \nFor example, if you are a 3rd-level druid, you have four 1st-level and two 2nd-level spell slots. With a Wisdom of 16, your list of prepared spells can include six spells of 1st or 2nd level, in any combination. If you prepare the 1st-level spell *cure wounds,* you can cast it using a 1st-level or 2nd-level slot. Casting the spell doesn't remove it from your list of prepared spells. \n \nYou can also change your list of prepared spells when you finish a long rest. Preparing a new list of druid spells requires time spent in prayer and meditation: at least 1 minute per spell level for each spell on your list. \n \n### Spellcasting Ability \n \nWisdom is your spellcasting ability for your druid spells, since your magic draws upon your devotion and attunement to nature. You use your Wisdom whenever a spell refers to your spellcasting ability. In addition, you use your Wisdom modifier when setting the saving throw DC for a druid spell you cast and when making an attack roll with one. \n \n**Spell save DC** = 8 + your proficiency bonus + your Wisdom modifier \n \n**Spell attack modifier** = your proficiency bonus + your Wisdom modifier \n \n### Ritual Casting \n \nYou can cast a druid spell as a ritual if that spell has the ritual tag and you have the spell prepared. \n \n#### Spellcasting Focus \n \nYou can use a druidic focus (see chapter 5, “Equipment”) as a spellcasting focus for your druid spells. \n \n### Wild Shape \n \nStarting at 2nd level, you can use your action to magically assume the shape of a beast that you have seen before. You can use this feature twice. You regain expended uses when you finish a short or long rest. \n \nYour druid level determines the beasts you can transform into, as shown in the Beast Shapes table. At 2nd level, for example, you can transform into any beast that has a challenge rating of 1/4 or lower that doesn't have a flying or swimming speed. \n \n**Beast Shapes (table)** \n \n| Level | Max. CR | Limitations                 | Example     | \n|-------|---------|-----------------------------|-------------| \n| 2nd   | 1/4     | No flying or swimming speed | Wolf        | \n| 4th   | 1/2     | No flying speed             | Crocodile   | \n| 8th   | 1       | -                           | Giant eagle | \n \nYou can stay in a beast shape for a number of hours equal to half your druid level (rounded down). You then revert to your normal form unless you expend another use of this feature. You can revert to your normal form earlier by using a bonus action on your turn. You automatically revert if you fall unconscious, drop to 0 hit points, or die. \n \nWhile you are transformed, the following rules apply: \n \n* Your game statistics are replaced by the statistics of the beast, but you retain your alignment, personality, and Intelligence, Wisdom, and Charisma scores. You also retain all of your skill and saving throw proficiencies, in addition to gaining those of the creature. If the creature has the same proficiency as you and the bonus in its stat block is higher than yours, use the creature's bonus instead of yours. If the creature has any legendary or lair actions, you can't use them. \n* When you transform, you assume the beast's hit points and Hit Dice. When you revert to your normal form, you return to the number of hit points you had before you transformed. However, if you revert as a result of dropping to 0 hit points, any excess damage carries over to your normal form. For example, if you take 10 damage in animal form and have only 1 hit point left, you revert and take 9 damage. As long as the excess damage doesn't reduce your normal form to 0 hit points, you aren't knocked unconscious. \n* You can't cast spells, and your ability to speak or take any action that requires hands is limited to the capabilities of your beast form. Transforming doesn't break your concentration on a spell you've already cast, however, or prevent you from taking actions that are part of a spell, such as *call lightning*, that you've already cast. \n* You retain the benefit of any features from your class, race, or other source and can use them if the new form is physically capable of doing so. However, you can't use any of your special senses, such as darkvision, unless your new form also has that sense. \n* You choose whether your equipment falls to the ground in your space, merges into your new form, or is worn by it. Worn equipment functions as normal, but the GM decides whether it is practical for the new form to wear a piece of equipment, based on the creature's shape and size. Your equipment doesn't change size or shape to match the new form, and any equipment that the new form can't wear must either fall to the ground or merge with it. Equipment that merges with the form has no effect until you leave the form. \n \n### Druid Circle \n \nAt 2nd level, you choose to identify with a circle of druids: the Circle of the Land or the Circle of the Moon, both detailed at the end of the class description. Your choice grants you features at 2nd level and again at 6th, 10th, and 14th level. \n \n### Ability Score Improvement \n \nWhen you reach 4th level, and again at 8th, 12th, 16th, and 19th level, you can increase one ability score of your choice by 2, or you can increase two ability scores of your choice by 1. As normal, you can't increase an ability score above 20 using this feature. \n \n### Timeless Body \n \nStarting at 18th level, the primal magic that you wield causes you to age more slowly. For every 10 years that pass, your body ages only 1 year. \n \n### Beast Spells \n \nBeginning at 18th level, you can cast many of your druid spells in any shape you assume using Wild Shape. You can perform the somatic and verbal components of a druid spell while in a beast shape, but you aren't able to provide material components. \n \n### Archdruid \n \nAt 20th level, you can use your Wild Shape an unlimited number of times. \n \nAdditionally, you can ignore the verbal and somatic components of your druid spells, as well as any material components that lack a cost and aren't consumed by a spell. You gain this benefit in both your normal shape and your beast shape from Wild Shape.",
            "hit_dice": "1d8",
            "hp_at_1st_level": "8 + your Constitution modifier",
            "hp_at_higher_levels": "1d8 (or 5) + your Constitution modifier per druid level after 1st",
            "prof_armor": "Light armor, medium armor, shields (druids will not wear armor or use shields made of metal)",
            "prof_weapons": "Clubs, daggers, darts, javelins, maces, quarterstaffs, scimitars, sickles, slings, spears",
            "prof_tools": "Herbalism kit",
            "prof_saving_throws": "Intelligence, Wisdom",
            "prof_skills": "Choose two from Arcana, Animal Handling, Insight, Medicine, Nature, Perception, Religion, and Survival",
            "equipment": "You start with the following equipment, in addition to the equipment granted by your background: \n \n* (*a*) a wooden shield or (*b*) any simple weapon \n* (*a*) a scimitar or (*b*) any simple melee weapon \n* Leather armor, an explorer's pack, and a druidic focus",
            "table": "| Level | Proficiency Bonus | Features                                          | Cantrips Known | 1st | 2nd | 3rd | 4th | 5th | 6th | 7th | 8th | 9th | \n|-------|-------------------|---------------------------------------------------|----------------|-----|-----|-----|-----|-----|-----|-----|-----|-----| \n| 1st   | +2                | Druidic, Spellcasting                             | 2              | 2   | -   | -   | -   | -   | -   | -   | -   | -   | \n| 2nd   | +2                | Wild Shape, Druid Circle                          | 2              | 3   | -   | -   | -   | -   | -   | -   | -   | -   | \n| 3rd   | +2                | -                                                 | 2              | 4   | 2   | -   | -   | -   | -   | -   | -   | -   | \n| 4th   | +2                | Wild Shape Improvement, Ability Score Improvement | 3              | 4   | 3   | -   | -   | -   | -   | -   | -   | -   | \n| 5th   | +3                | -                                                 | 3              | 4   | 3   | 2   | -   | -   | -   | -   | -   | -   | \n| 6th   | +3                | Druid Circle feature                              | 3              | 4   | 3   | 3   | -   | -   | -   | -   | -   | -   | \n| 7th   | +3                | -                                                 | 3              | 4   | 3   | 3   | 1   | -   | -   | -   | -   | -   | \n| 8th   | +3                | Wild Shape Improvement, Ability Score Improvement | 3              | 4   | 3   | 3   | 2   | -   | -   | -   | -   | -   | \n| 9th   | +4                | -                                                 | 3              | 4   | 3   | 3   | 3   | 1   | -   | -   | -   | -   | \n| 10th  | +4                | Druid Circle feature                              | 4              | 4   | 3   | 3   | 3   | 2   | -   | -   | -   | -   | \n| 11th  | +4                | -                                                 | 4              | 4   | 3   | 3   | 3   | 2   | 1   | -   | -   | -   | \n| 12th  | +4                | Ability Score Improvement                         | 4              | 4   | 3   | 3   | 3   | 2   | 1   | -   | -   | -   | \n| 13th  | +5                | -                                                 | 4              | 4   | 3   | 3   | 3   | 2   | 1   | 1   | -   | -   | \n| 14th  | +5                | Druid Circle feature                              | 4              | 4   | 3   | 3   | 3   | 2   | 1   | 1   | -   | -   | \n| 15th  | +5                | -                                                 | 4              | 4   | 3   | 3   | 3   | 2   | 1   | 1   | 1   | -   | \n| 16th  | +5                | Ability Score Improvement                         | 4              | 4   | 3   | 3   | 3   | 2   | 1   | 1   | 1   | -   | \n| 17th  | +6                | -                                                 | 4              | 4   | 3   | 3   | 3   | 2   | 1   | 1   | 1   | 1   | \n| 18th  | +6                | Timeless Body, Beast Spells                       | 4              | 4   | 3   | 3   | 3   | 3   | 1   | 1   | 1   | 1   | \n| 19th  | +6                | Ability Score Improvement                         | 4              | 4   | 3   | 3   | 3   | 3   | 2   | 1   | 1   | 1   | \n| 20th  | +6                | Archdruid                                         | 4              | 4   | 3   | 3   | 3   | 3   | 2   | 2   | 1   | 1   | ",
            "spellcasting_ability": "Wisdom",
            "subtypes_name": "Druid Circles",
            "archetypes": [
                {
                    "name": "Circle of the Land",
                    "slug": "circle-of-the-land",
                    "desc": "The Circle of the Land is made up of mystics and sages who safeguard ancient knowledge and rites through a vast oral tradition. These druids meet within sacred circles of trees or standing stones to whisper primal secrets in Druidic. The circle's wisest members preside as the chief priests of communities that hold to the Old Faith and serve as advisors to the rulers of those folk. As a member of this circle, your magic is influenced by the land where you were initiated into the circle's mysterious rites. \n \n##### Bonus Cantrip \n \nWhen you choose this circle at 2nd level, you learn one additional druid cantrip of your choice. \n \n##### Natural Recovery \n \nStarting at 2nd level, you can regain some of your magical energy by sitting in meditation and communing with nature. During a short rest, you choose expended spell slots to recover. The spell slots can have a combined level that is equal to or less than half your druid level \n(rounded up), and none of the slots can be 6th level or higher. You can't use this feature again until you finish a long rest. \n \nFor example, when you are a 4th-level druid, you can recover up to two levels worth of spell slots. You can recover either a 2nd-level slot or two 1st-level slots. \n \n##### Circle Spells \n \nYour mystical connection to the land infuses you with the ability to cast certain spells. At 3rd, 5th, 7th, and 9th level you gain access to circle spells connected to the land where you became a druid. Choose that land-arctic, coast, desert, forest, grassland, mountain, or swamp-and consult the associated list of spells. \n \nOnce you gain access to a circle spell, you always have it prepared, and it doesn't count against the number of spells you can prepare each day. If you gain access to a spell that doesn't appear on the druid spell list, the spell is nonetheless a druid spell for you. \n \n**Arctic (table)** \n \n| Druid Level | Circle Spells                     | \n|-------------|-----------------------------------| \n| 3rd         | hold person, spike growth         | \n| 5th         | sleet storm, slow                 | \n| 7th         | freedom of movement, ice storm    | \n| 9th         | commune with nature, cone of cold | \n \n**Coast (table)** \n \n| Druid Level | Circle Spells                      | \n|-------------|------------------------------------| \n| 3rd         | mirror image, misty step           | \n| 5th         | water breathing, water walk        | \n| 7th         | control water, freedom of movement | \n| 9th         | conjure elemental, scrying         | \n \n**Desert (table)** \n \n| Druid Level | Circle Spells                                 | \n|-------------|-----------------------------------------------| \n| 3rd         | blur, silence                                 | \n| 5th         | create food and water, protection from energy | \n| 7th         | blight, hallucinatory terrain                 | \n| 9th         | insect plague, wall of stone                  | \n \n**Forest (table)** \n \n| Druid Level | Circle Spells                    | \n|-------------|----------------------------------| \n| 3rd         | barkskin, spider climb           | \n| 5th         | call lightning, plant growth     | \n| 7th         | divination, freedom of movement  | \n| 9th         | commune with nature, tree stride | \n \n**Grassland (table)** \n \n| Druid Level | Circle Spells                    | \n|-------------|----------------------------------| \n| 3rd         | invisibility, pass without trace | \n| 5th         | daylight, haste                  | \n| 7th         | divination, freedom of movement  | \n| 9th         | dream, insect plague             | \n \n**Mountain (table)** \n \n| Druid Level | Circle Spells                   | \n|-------------|---------------------------------| \n| 3rd         | spider climb, spike growth      | \n| 5th         | lightning bolt, meld into stone | \n| 7th         | stone shape, stoneskin          | \n| 9th         | passwall, wall of stone         | \n \n**Swamp (table)** \n \n| Druid Level | Circle Spells                        | \n|-------------|--------------------------------------| \n| 3rd         | acid arrow, darkness                 | \n| 5th         | water walk, stinking cloud           | \n| 7th         | freedom of movement, locate creature | \n| 9th         | insect plague, scrying               | \n \n##### Land's Stride \n \nStarting at 6th level, moving through nonmagical difficult terrain costs you no extra movement. You can also pass through nonmagical plants without being slowed by them and without taking damage from them if they have thorns, spines, or a similar hazard. \n \nIn addition, you have advantage on saving throws against plants that are magically created or manipulated to impede movement, such those created by the *entangle* spell. \n \n##### Nature's Ward \n \nWhen you reach 10th level, you can't be charmed or frightened by elementals or fey, and you are immune to poison and disease. \n \n##### Nature's Sanctuary \n \nWhen you reach 14th level, creatures of the natural world sense your connection to nature and become hesitant to attack you. When a beast or plant creature attacks you, that creature must make a Wisdom saving throw against your druid spell save DC. On a failed save, the creature must choose a different target, or the attack automatically misses. On a successful save, the creature is immune to this effect for 24 hours. \n \nThe creature is aware of this effect before it makes its attack against you. \n \n> ### Sacred Plants and Wood \n> \n> A druid holds certain plants to be sacred, particularly alder, ash, birch, elder, hazel, holly, juniper, mistletoe, oak, rowan, willow, and yew. Druids often use such plants as part of a spellcasting focus, incorporating lengths of oak or yew or sprigs of mistletoe. \n> \n> Similarly, a druid uses such woods to make other objects, such as weapons and shields. Yew is associated with death and rebirth, so weapon handles for scimitars or sickles might be fashioned from it. Ash is associated with life and oak with strength. These woods make excellent hafts or whole weapons, such as clubs or quarterstaffs, as well as shields. Alder is associated with air, and it might be used for thrown weapons, such as darts or javelins. \n> \n> Druids from regions that lack the plants described here have chosen other plants to take on similar uses. For instance, a druid of a desert region might value the yucca tree and cactus plants. \n \n> ### Druids and the Gods \n> \n> Some druids venerate the forces of nature themselves, but most druids are devoted to one of the many nature deities worshiped in the multiverse (the lists of gods in appendix B include many such deities). The worship of these deities is often considered a more ancient tradition than the faiths of clerics and urbanized peoples.",
                    "document__slug": "wotc-srd",
                    "document__title": "5e Core Rules",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd"
                },
                {
                    "name": "Circle of Ash",
                    "slug": "circle-of-ash",
                    "desc": "Druids of the Circle of Ash believe in the power of rebirth and resurrection, both physical and spiritual. The ash they take as their namesake is the result of burning and death, but it can fertilize the soil and help bring forth new life. For these druids, ash is the ultimate symbol of the elegant cycle of life and death that is the foundation of the natural world. Some such druids even use fresh ash to clean themselves, and the residue is often kept visible on their faces.\n  Druids of this circle often use the phoenix as their symbol, an elemental creature that dies and is reborn from its own ashes. These druids aspire to the same purity and believe resurrection is possible if they are faithful to their beliefs. Others of this circle are drawn to volcanos and find volcanic eruptions and their resulting ash clouds to be auspicious events.\n  All Circle of Ash druids request to be cremated after death, and their ashes are often given over to others of their order. What later happens with these ashes, none outside the circle know.\n\n##### Ash Cloud\nAt 2nd level, you can expend one use of your Wild Shape and, rather than assuming a beast form, create a small, brief volcanic eruption beneath the ground, causing it to spew out an ash cloud. As an action, choose a point within 30 feet of you that you can see. Each creature within 5 feet of that point must make a Dexterity saving throw against your spell save DC, taking 2d8 bludgeoning damage on a failed save, or half as much damage on a successful one.\n  This eruption creates a 20-foot-radius sphere of ash centered on the eruption point. The cloud spreads around corners, and its area is heavily obscured. When a creature enters the cloud for the first time on a turn or starts its turn there, that creature must succeed on a Constitution saving throw against your spell save DC or have disadvantage on ability checks and saving throws until the start of its next turn. Creatures that don't need to breathe or that are immune to poison automatically succeed on this saving throw.\n  You automatically succeed on this saving throw while within the area of your ash cloud, but you don't automatically succeed if you are in another Circle of Ash druid's ash cloud.\n  The cloud lasts for 1 minute, until you use a bonus action to dismiss it, or until a wind of moderate or greater speed (at least 10 miles per hour) disperses it.\n\n##### Firesight\nStarting at 2nd level, your vision can't be obscured by ash, fire, smoke, fog, or the cloud created by your Ash Cloud feature, but it can still be obscured by other effects, such as dim light, dense foliage, or rain. In addition, you have advantage on saving throws against gas or cloud-based effects, such as from the *cloudkill* or *stinking cloud* spells, a gorgon's petrifying breath, or a kraken's ink cloud.\n#### Covered in Ash\nAt 6th level, when a creature within 30 feet of you that you can see (including yourself) takes damage, you can use your reaction to cover the creature in magical ash, giving it temporary hit points equal to twice your proficiency bonus. The target gains the temporary hit points before it takes the damage. You can use this feature a number of times equal to your proficiency bonus. You regain all expended uses when you finish a long rest.\n  In addition, while your Ash Cloud feature is active and you are within 30 feet of it, you can use a bonus action to teleport to an unoccupied space you can see within the cloud. You can use this teleportation no more than once per minute.\n\n##### Feed the Earth\nAt 10th level, your Ash Cloud feature becomes more potent. Instead of the normal eruption effect, when you first create the ash cloud, each creature within 10 feet of the point you chose must make a Dexterity saving throw against your spell save DC, taking 2d8 bludgeoning damage and 2d8 fire damage on a failed save, or half as much damage on a successful one.\n  In addition, when a creature enters this more potent ash cloud for the first time on a turn or starts its turn there, that creature has disadvantage on ability checks and saving throws while it remains within the cloud. Creatures are affected even if they hold their breath or don't need to breathe, but creatures that are immune to poison are immune to this effect.\n  If at least one creature takes damage from the ash cloud's eruption, you can use your reaction to siphon that destructive energy into the rapid growth of vegetation. The area within the cloud becomes difficult terrain that lasts while the cloud remains. You can't cause this growth in an area that can't accommodate natural plant growth, such as the deck of a ship or inside a building.\n  The ash cloud now lasts for 10 minutes, until you use a bonus action to dismiss it, or until a wind of moderate or greater speed (at least 10 miles per hour) disperses it.\n\n##### From the Ashes\nBeginning at 14th level, when you are reduced to 0 hit points, your body is consumed in a fiery explosion. Each creature of your choice within 30 feet of you must make a Dexterity saving throw against your spell save DC, taking 6d6 fire damage on a failed save, or half as much damage on a successful one. After the explosion, your body becomes a pile of ashes.\n  At the end of your next turn, you reform from the ashes with all of your equipment and half your maximum hit points. You can choose whether or not you reform prone. If your ashes are moved before you reform, you reform in the space that contains the largest pile of your ashes or in the nearest unoccupied space. After you reform, you suffer one level of exhaustion.\n  Once you use this feature, you can't use it again until you finish a long rest.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "Circle of Bees",
                    "slug": "circle-of-bees",
                    "desc": "Druids of the Circle of Bees are friends to all stinging insects but focus their attention on honeybees and other pollinating insects. When not adventuring, they tend hives, either created by the insects or by themselves. They tap into the horror inherent in stinging insects to protect their allies or the fields hosting their bee friends.\n\n##### Circle Spells\nYour bond with bees and other stinging beasts grants you knowledge of certain spells. At 2nd level, you learn the true strike cantrip. At 3rd, 5th, 7th, and 9th levels, you gain access to the spells listed for those levels in the Circle of Bees Spells table.\n  Once you gain access to a circle spell, you always have it prepared, and it doesn't count against the number of spells you can prepare each day. If you gain access to a spell that doesn't appear on the druid spell list, the spell is nonetheless a druid spell for you.\n\n**Circle of Bee Spells**\n| Druid Level  | Spells                             | \n|--------------|------------------------------------| \n| 3rd          | *blur*, *bombardment of stings*    | \n| 5th          | *fly*, *haste*                     | \n| 7th          | *giant insect*, *locate creature*  | \n| 9th          | *insect plague*, *telepathic bond* |\n\n##### Bee Bond\nWhen you choose this circle at 2nd level, you gain proficiency in the Acrobatics or Stealth skill (your choice), and you can speak and understand Bee Dance, a language shared by bees that involves flying in dance-like patterns. Bees refuse to attack you, even with magical coercion.\n  When a beast other than a bee attacks you with a weapon that deals poison damage, such as a giant spider's bite or a scorpion's sting, it must succeed on a Charisma saving throw against your spell save DC or have disadvantage on its attack rolls against you until the start of its next turn.\n\n##### Bee Stinger\nAlso at 2nd level, you can use an action and expend one use of your Wild Shape to grow a bee's stinger, typically growing from your wrist, which you can use to make unarmed strikes. When you hit with an unarmed strike while this stinger is active, you use Wisdom instead of Strength for the attack, and your unarmed strike deals piercing damage equal to 1d4 + your Wisdom modifier + poison damage equal to half your proficiency bonus, instead of the bludgeoning damage normal for an unarmed strike.\n  The stinger lasts for a number of hours equal to half your druid level (rounded down) or until you use your Wild Shape again.\n  When you reach 6th level in this class, your unarmed strikes count as magical for the purpose of overcoming resistance and immunity to nonmagical attacks and damage, and the poison damage dealt by your stinger equals your proficiency bonus. In addition, the unarmed strike damage you deal while the stringer is active increases to 1d6 at 6th level, 1d8 at 10th level, and 1d10 at 14th level.\n\n##### Bumblebee Rush\nAt 6th level, you can take the Dash action as a bonus action. When you do so, creatures have disadvantage on attack rolls against you until the start of your next turn. You can use this feature a number of times equal to your proficiency bonus. You regain all expended uses when you finish a long rest.\n\n##### Hive Mind\nAt 10th level, when you cast *telepathic bond*, each creature in the link has advantage on Intelligence, Wisdom, and Charisma checks if at least one creature in the link has proficiency in a skill that applies to that check. In addition, if one creature in the link succeeds on a Wisdom (Perception) check to notice a hidden creature or on a Wisdom (Insight) check, each creature in the link also succeeds on the check. Finally, when a linked creature makes an attack, it has advantage on the attack roll if another linked creature that can see it uses a reaction to assist it.\n\n##### Mantle of Bees\nAt 14th level, you can use an action to cover yourself in bees for 1 hour or until you dismiss them (no action required). While you are covered in a mantle of bees, you gain a +2 bonus to AC, and you have advantage on Charisma (Intimidation) checks. In addition, when a creature within 5 feet of you hits you with a melee weapon, it must make a Constitution saving throw against your spell save DC. On a failure, the attacker takes 1d8 piercing damage and 1d8 poison damage and is poisoned until the end of its next turn. On a successful save, the attacker takes half the damage and isn't poisoned.\n  While the mantle is active, you can use an action to direct the bees to swarm a 10-foot-radius sphere within 60 feet of you. Each creature in the area must make a Constitution saving throw against your spell save DC. On a failure, a creature takes 4d6 piercing damage and 4d6 poison damage and is poisoned for 1 minute. On a success, a creature takes half the damage and isn't poisoned. The bees then disperse, and your mantle ends.\n  Once you use this feature, you can't use it again until you finish a short or long rest, unless you expend a spell slot of 5th level or higher to create the mantle again.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "Circle of Crystals",
                    "slug": "circle-of-crystals",
                    "desc": "Circle of Crystals druids first arose in subterranean environments, where they helped tend giant crystal gardens, but now they can be found most anywhere with access to underground caverns or geothermal activity. These druids view crystals as a naturally occurring form of order and perfection, and they value the crystals' slow growth cycle, as it reminds them the natural world moves gradually but eternally. This teaches young druids patience and assures elder druids their legacy will be carried on in each spire of crystal. As druids of this circle tend their crystals, they learn how to use the harmonic frequencies of different crystals to create a variety of effects, including storing magic.\n\n##### Resonant Crystal\nWhen you choose this circle at 2nd level, you learn to create a special crystal that can take on different harmonic frequencies and properties. It is a Tiny object and can serve as a spellcasting focus for your druid spells. As a bonus action, you can cause the crystal to shed bright light in a 10-foot radius and dim light for an additional 10 feet. You can end the light as a bonus action.\n  Whenever you finish a long rest, you can attune your crystal to one of the following harmonic frequencies. The crystal can have only one harmonic frequency at a time, and you gain the listed benefit while you are wearing or carrying the crystal. The crystal retains the chosen frequency until you finish a long rest. \n* **Clarity.** You have advantage on saving throws against being frightened or charmed. \n* **Cleansing.** You have advantage on saving throws against being poisoned, and you have resistance to poison damage. \n* **Focus.** You have advantage on Constitution saving throws that you make to maintain concentration on a spell when you take damage. \n* **Healing.** When you cast a spell of 1st level or higher that restores hit points to a creature, the creature regains additional hit points equal to your proficiency bonus. \n* **Vitality.** Whenever you cast a spell of 1st level or higher using the resonant crystal as your focus, one creature of your choice that you can see within 30 feet of you gains temporary hit points equal to twice your proficiency bonus. The temporary hit points last for 1 minute.\nTo create or replace a lost resonant crystal, you must perform a 1-hour ceremony. This ceremony can be performed during a short or long rest, and it destroys the previous crystal, if one existed. If a previous crystal had a harmonic frequency, the new crystal has that frequency, unless you create the new crystal during a long rest.\n\n##### Crystalline Skin\nStarting at 6th level, when you take damage, you can use a reaction to cause your skin to become crystalline until the end of your next turn. While your skin is crystalline, you have resistance to cold damage, radiant damage and bludgeoning, piercing, and slashing damage from nonmagical attacks, including to the triggering damage if it is of the appropriate type. You choose the exact color and appearance of the crystalline skin.\n  You can use this feature a number of times equal to your proficiency bonus. You regain all expended uses when you finish a long rest.\n\n##### Magical Resonance\nAt 10th level, you can draw on stored magical energy in your resonant crystal to restore some of your spent magic. While wearing or carrying the crystal, you can use a bonus action to recover one expended spell slot of 3rd level or lower. If you do so, you can't benefit from the resonant crystal's harmonic frequency for 1 minute.\n  Once you use this feature, you can't use it again until you finish a long rest.\n\n##### Crystalline Form\nAt 14th level, as a bonus action while wearing or carrying your resonant crystal, you can expend one use of your Wild Shape feature to assume a crystalline form instead of transforming into a beast. You gain the following benefits while in this form: \n* You have resistance to cold damage, radiant damage, and bludgeoning, piercing, and slashing damage from nonmagical attacks. \n* You have advantage on saving throws against spells and other magical effects. \n* Your resonant crystal pulses with power, providing you with the benefits of all five harmonic frequencies. When you cast a spell of 1st level or higher, you can choose to activate only the Healing or Vitality harmonic frequencies or both. If you activate both, you can choose two different targets or the same target.\nThis feature lasts 1 minute, or until you dismiss it as a bonus action.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "Circle of Sand",
                    "slug": "circle-of-sand",
                    "desc": "The Circle of Sand originally arose among the desert dunes, where druids forged an intimate connection with the sands that surrounded them. Now such circles gather anywhere with excess sand, including coastlines or badlands.\n  While the unacquainted might view sand as lifeless and desolate, druids of this circle know the truth—there is life within the sand, as there is almost anywhere. These druids have witnessed the destructive power of sand and the sandstorm and know to fear and respect them. Underestimating the power of sand is only for the foolish.\n\n##### Sand Form\nWhen you join this circle at 2nd level, you learn to adopt a sandy form. You can use a bonus action to expend one use of your Wild Shape feature and transform yourself into a form made of animated sand rather than transforming into a beast form. While in your sand form, you retain your game statistics. Because your body is mostly sand, you can move through a space as narrow as 1 inch wide without squeezing, and you have advantage on ability checks and saving throws to escape a grapple or the restrained condition.\n\nYou choose whether your equipment falls to the ground in your space, merges into your new form, or is worn by it. Worn equipment functions as normal, but the GM decides whether it is practical for the equipment to move with you if you flow through particularly narrow spaces.\n\nYou can stay in your sand form for 10 minutes, or until you dismiss it (no action required), are incapacitated, die, or use this feature again. While in your sand form, you can use a bonus action to do one of the following: \n* **Abrasive Blast.** You launch a blast of abrasive sand at a creature you can see within 30 feet of you. Make a ranged spell attack. On a hit, the creature takes slashing damage equal to 1d8 + your Wisdom modifier. \n* **Stinging Cloud.** You emit a cloud of fine sand at a creature you can see within 5 feet of you. The target must succeed on a Constitution saving throw against your spell save DC or be blinded until the end of its next turn.\n\nWhen you reach 10th level in this class, you can stay in your sand form for 1 hour or until you dismiss it. In addition, the damage of Abrasive Blast increases to 2d8, and the range of Stinging Cloud increases to 10 feet.\n\n##### Diffuse Form\nAlso at 2nd level, when you are hit by a weapon attack while in your Sand Form, you can use your reaction to gain resistance to nonmagical bludgeoning, piercing, and slashing damage until the start of your next turn. You can use this feature a number of times equal to your proficiency bonus. You regain all expended uses when you finish a long rest.\n\n##### Sand Dervish\nStarting at 6th level, you can use a bonus action to create a sand dervish in an unoccupied space you can see within 30 feet of you. The sand dervish is a cylinder of whirling sand that is 10 feet tall and 5 feet wide. A creature that ends its turn within 5 feet of the sand dervish must make a Strength saving throw against your spell save DC. On a failed save, the creature takes 1d8 slashing damage and is pushed 10 feet away from the dervish. On a successful save, the creature takes half as much damage and isn't pushed.\n  As a bonus action on your turn, you can move the sand dervish up to 30 feet in any direction. If you ram the dervish into a creature, that creature must make the saving throw against the dervish's damage, and the dervish stops moving this turn. When you move the dervish, you can direct it over barriers up to 5 feet tall and float it across pits up to 10 feet wide.\nThe sand dervish lasts for 1 minute or until you dismiss it as a bonus action. Once you use this feature, you can't use it again until you finish a short or long rest.\nWhen you reach 10th level in this class, the damage dealt by the dervish increases to 2d8.\n\n##### Echo of the Dunes\nAt 10th level, your connection with sand deepens, and you can call on the power of the deep dunes to do one of the following: \n* **Sand Sphere.** You can use an action to conjure a 20-foot radius sphere of thick, swirling sand at a point you can see within 90 feet. The sphere spreads around corners, and its area is heavily obscured. A creature moving through the area must spend 3 feet of movement for every 1 foot it moves. The sphere lasts for 1 minute or until you dismiss it (no action required). \n* **Whirlwind.** You can use an action to transform into a whirlwind of sand until the start of your next turn. While in this form, your movement speed is doubled, and your movement doesn't provoke opportunity attacks. While in whirlwind form, you have resistance to all damage, and you can't be grappled, petrified, knocked prone, restrained, or stunned, but you also can't cast spells, can't make attacks, and can't manipulate objects that require fine dexterity.\nOnce you use one of these options, you can't use this feature again until you finish a short or long rest.\n\n##### Sandstorm\nAt 14th level, you can use an action to create a sandstorm of swirling wind and stinging sand. The storm rages in a cylinder that is 10 feet tall with a 30-foot radius centered on a point you can see within 120 feet. The storm spreads around corners, its area is heavily obscured, and exposed flames in the area are doused. The buffeting winds and sand make the area difficult terrain. The storm lasts for 1 minute or until you dismiss it as a bonus action.\n  When a creature enters the area for the first time on a turn or starts its turn there, that creature must make a Strength saving throw against your spell save DC. On a failed save, it takes 2d8 slashing damage and is knocked prone. On a successful save, it takes half as much damage and isn't knocked prone.\n  You are immune to the effects of the storm, and you can extend that immunity to a number of creatures that you can see within 120 feet of you equal to your proficiency bonus.\n  Once you use this feature, you can't use it again until you finish a long rest.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "Circle of the Green",
                    "slug": "circle-of-the-green",
                    "desc": "Druids of the Circle of the Green devote themselves to the plants and green things of the world, recognizing the role of plants in giving life. By continued communion with plant life, they believe they draw nearer to what they call “The Green,” a cosmic thread that binds all plant life. Druids of this circle believe they gain their abilities by tapping into the Green, and they use this connection to summon a spirit from it.\n\n##### Circle Spells\nWhen you join this circle at 2nd level, you form a bond with a plant spirit, a creature of the Green. Your link with this spirit grants you access to some spells when you reach certain levels in this class, as shown on the Circle of the Green Spells table.\n  Once you gain access to one of these spells, you always have it prepared, and it doesn't count against the number of spells you can prepare each day. If you gain access to a spell that doesn't appear on the druid spell list, the spell is nonetheless a druid spell for you.\n\n**Circle of the Green Spells**\n| Druid Level  | Spells                               | \n|--------------|--------------------------------------| \n| 2nd          | *entangle*, *goodberry*              | \n| 3rd          | *barkskin*, *spike growth*           | \n| 5th          | *speak with plants*, *vine carpet*   | \n| 7th          | *dreamwine*, *hallucinatory terrain* | \n| 9th          | *enchanted bloom*, *tree stride*     |\n\n##### Summon Green Spirit\nStarting at 2nd level, you can summon a spirit of the Green, a manifestation of primordial plant life. As an action, you can expend one use of your Wild Shape feature to summon the Green spirit rather than assuming a beast form.\n  The spirit appears in an unoccupied space of your choice that you can see within 30 feet of you. When the spirit appears, the area in a 10-foot radius around it becomes tangled with vines and other plant growth, becoming difficult terrain until the start of your next turn.\n  The spirit is friendly to you and your companions and obeys your commands. See this creature's game statistics in the Green Spirit stat block, which uses your proficiency bonus (PB) in several places.\n  You determine the spirit's appearance. Some spirits take the form of a humanoid figure made of gnarled branches and leaves, while others look like creatures with leafy bodies and heads made of gourds or fruit. Some even resemble beasts, only made entirely of plant material.\n  In combat, the spirit shares your initiative count, but it takes its turn immediately after yours. The green spirit can move and use its reaction on its own, but, if you don't issue any commands to it, the only action it takes is the Dodge action. You can use your bonus action to direct it to take the Attack, Dash, Disengage, Help, Hide, or Search action or an action listed in its statistics. If you are incapacitated, the spirit can take any action of its choice, not just Dodge.\n  The spirit remains for 1 hour, until it is reduced to 0 hit points, until you use this feature to summon the spirit again, or until you die. When it manifests, the spirit bears 10 fruit that are infused with magic. Each fruit works like a berry created by the *goodberry* spell.\n\n##### Gift of the Green\nAt 6th level, the bond with your green spirit enhances your restorative spells and gives you the power to cast additional spells. Once before the spirit's duration ends, you can cast one of the following spells without expending a spell slot or material components: *locate animals or plants*, *pass without trace* (only in environments with ample plant life), *plant growth*, or *speak with plants*. You can't cast a spell this way again until the next time you summon your green spirit.\n  Whenever you cast a spell that restores hit points while your green spirit is summoned, roll a d8 and add the result to the total hit points restored.\n  In addition, when you cast a spell with a range other than self, the spell can originate from you or your green spirit.\n\n##### Verdant Interference\nStarting at 10th level, when a creature you can see within 30 feet of you or your green spirit is attacked, you can use your reaction to cause vines and vegetation to burst from the ground and grasp at the attacker, giving the attacker disadvantage on attack rolls until the start of your next turn.\n  You can use this feature a number of times equal to your proficiency bonus. You regain all expended uses when you finish a long rest.\n\n##### Spirit Symbiosis\nAt 14th level, while your green spirit is within 30 feet of you, you can use an action to join with it, letting its plant matter grow around you. While so joined, you gain the following benefits: \n* You gain temporary hit points equal to your green spirit's current hit points. \n* You gain a climbing speed of 30 feet. \n* You have advantage on Constitution saving throws. \n* The ground within 10 feet of you is difficult terrain for creatures hostile to you. \n* You can use a bonus action on each of your turns to make a tendril attack against one creature within 10 feet of you that you can see. Make a melee spell attack. On a hit, the target takes bludgeoning damage equal to 2d8 + your Wisdom modifier.\nThis feature lasts until the temporary hit points you gained from this feature are reduced to 0, until the spirit's duration ends, or until you use an action to separate. If you separate, the green spirit has as many hit points as you had temporary hit points remaining. If this effect ends because your temporary hit points are reduced to 0, the green spirit disappears until you summon it again.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "Circle of the Shapeless",
                    "slug": "circle-of-the-shapeless",
                    "desc": "Druids of the Circle of the Shapeless believe that oozes, puddings, and jellies serve an important and integral role in the natural world, particularly in decomposition and in clearing detritus. Druids of this circle also admire the adaptability of these gelatinous creatures and study them to learn how to duplicate some of their abilities.\n\nThe sworn enemies of Circle of the Shapeless druids are the so-called ooze lords and their servants who pervert the natural order by controlling and weaponizing such creatures.\n\n##### Circle Spells\nWhen you join this circle at 2nd level, your connection with oozes grants you access to certain spells. At 2nd level, you learn the *acid splash* cantrip. At 3rd, 5th, 7th, and 9th level you gain access to the spells listed for that level in the Circle of the Shapeless Spells table. Once you gain access to one of these spells, you always have it prepared, and it doesn't count against the number of spells you can prepare each day. If you gain access to a spell that doesn't appear on the druid spell list, the spell is nonetheless a druid spell for you.\n\n**Circle of the Shapeless Spells**\n| Druid Level  | Spells                           | \n|--------------|----------------------------------| \n| 3rd          | *enlarge/reduce*, *spider climb* | \n| 5th          | *iron gut*, *meld into stone*    | \n| 7th          | *blight*, *freedom of movement*  | \n| 9th          | *contagion*, *seeming*           |\n\n##### Ooze Form\nStarting at 2nd level, you learn to adopt an ooze form. You can use a bonus action to expend one use of your Wild Shape feature to take on an ooze-like form rather than transforming into a beast.\n  While in your ooze form, you retain your game statistics, but your body becomes less substantial and appears wet and slimy. Your skin may change in color and appearance, resembling other forms of ooze like black pudding, ochre jelly, gray ooze, or even translucent, like a gelatinous cube.\n  You choose whether your equipment falls to the ground in your space, merges into your new form, or is worn by it. Worn equipment functions as normal, but the GM decides whether it is practical for the equipment to move with you if you flow through particularly narrow spaces.\n  Your ooze form lasts for 10 minutes or until you dismiss it (no action required), are incapacitated, die, or use this feature again.\nWhile in ooze form, you gain the following benefits: \n* **Acid Weapons.** Your melee weapon attacks deal an extra 1d6 acid damage on a hit. \n* **Amorphous.** You can move through a space as narrow as 1 inch wide without squeezing. \n* **Climber.** You have a climbing speed of 20 feet. \n* **Oozing Form.** When a creature touches you or hits you with a melee attack while within 5 feet of you, you can use your reaction to deal 1d6 acid damage to that creature.\n\n##### Slimy Pseudopod\nAt 6th level, you can use a bonus action to cause an oozing pseudopod to erupt from your body for 1 minute or until you dismiss it as a bonus action. On the turn you activate this feature, and as a bonus action on each of your subsequent turns, you can make a melee spell attack with the pseudopod against a creature within 5 feet of you. On a hit, the target takes 1d6 acid damage.\n  You can use this feature a number of times equal to your proficiency bonus. You regain all expended uses when you finish a long rest. When you reach 10th level in this class, the acid damage dealt by your pseudopod increases to 2d6.\n\n##### Improved Ooze Form\nAt 10th level, your ooze form becomes more powerful. It now lasts 1 hour, and the acid damage dealt by your Acid Weapons and Oozing Form increases to 2d6.\n\n##### Engulfing Embrace\nAt 14th level, while in your ooze form, you can use an action to move into the space of a creature within 5 feet of you that is your size or smaller and try to engulf it. The target creature must make a Dexterity saving throw against your spell save DC.\n  On a successful save, the creature can choose to be pushed 5 feet away from you or to an unoccupied space within 5 feet of you. A creature that chooses not to be pushed suffers the consequences of a failed saving throw.\n  On a failed save, you enter the creature's space, and the creature takes 2d6 acid damage and is engulfed. The engulfed creature is restrained and has total cover against attacks and other effects outside of your body. The engulfed creature takes 4d6 acid damage at the start of each of your subsequent turns. When you move, the engulfed creature moves with you.\n  An engulfed creature can attempt to escape by taking an action to make a Strength (Athletics) check against your spell save DC. On a success, the creature escapes and enters a space of its choice within 5 feet of you.\n  Once you use this feature, you can't use it again until you finish a long rest, unless you expend a spell slot of 5th level or higher to try to engulf another creature.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "Circle of Wind",
                    "slug": "circle-of-wind",
                    "desc": "Founded in deserts, badlands, and grasslands, where wind dominates and controls the landscape, the teachings of the Circle of Wind have spread far and wide, like a mighty storm. Druids who follow this circle's teachings embrace the mercurial winds to create several effects.\n\n##### Bonus Cantrip\nAt 2nd level when you choose this circle, you learn the *message* cantrip.\n\n##### Circle Spells\nThe magic of the wind flows through you, granting access to certain spells. At 3rd, 5th, 7th, and 9th level, you gain access to the spells listed for that level in the Circle of Wind Spells table.\n  Once you gain access to one of these spells, you always have it prepared, and it doesn't count against the number of spells you can prepare each day. If you gain access to a spell that doesn't appear on the druid spell list, the spell is nonetheless a druid spell for you.\n\n**Circle of Wind Spells**\n| Druid Level  | Spells                                                | \n|--------------|-------------------------------------------------------| \n| 3rd          | *blur*, *gust of wind*                                | \n| 5th          | *fly*, *lightning bolt*                               | \n| 7th          | *conjure minor elementals*, *freedom of movement*     | \n| 9th          | *cloudkill*, *conjure elemental* (air elemental only) |\n\n##### Feathered Form\nStarting at 2nd level, when you use your Wild Shape to magically assume the shape of a beast, it can have a flying speed (you ignore “no flying speed” in the Limitations column of the Beast Shapes table but must abide by the other limitations there).\n\n##### Comforting Breezes\nBeginning at 6th level, as an action, you can summon a gentle breeze that extends in a 30-foot cone from you. Choose a number of targets in the area equal to your Wisdom modifier (minimum of 1). You end one disease or the blinded, deafened, paralyzed, or poisoned condition on each target. Once you use this feature, you can't use it again until you finish a long rest.\n\n##### Updraft\nAlso at 6th level, you can expend one use of Wild Shape as a bonus action to summon a powerful wind. You and each creature of your choice within 10 feet of you end the grappled or restrained conditions. You can fly up to 30 feet as part of this bonus action, and each creature that you affect with this wind can use a reaction to fly up to 30 feet. This movement doesn't provoke opportunity attacks.\n\n##### Vizier of the Winds\nStarting at 10th level, you can ask the winds one question, and they whisper secrets back to you. You can cast *commune* without preparing the spell or expending a spell slot. Once you use this feature, you can't use it again until you finish a long rest.\n\n##### Hunger of Storm's Fury\nBeginning at 14th level, when you succeed on a saving throw against a spell or effect that deals lightning damage, you take no damage and instead regain a number of hit points equal to the lightning damage dealt. Once you use this feature, you can't use it again until you finish a long rest.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "Circle of the Many",
                    "slug": "circle-of-the-many",
.......


Magic Item List
list: API endpoint for returning a list of magic items.
retrieve: API endpoint for returning a particular magic item.

«123…33»
GET /v1/magicitems/
HTTP 200 OK
Allow: GET, HEAD, OPTIONS
Content-Type: application/json
Vary: Accept

{
    "count": 1618,
    "next": "https://api.open5e.com/v1/magicitems/?page=2",
    "previous": null,
    "results": [
        {
            "slug": "aberrant-agreement",
            "name": "Aberrant Agreement",
            "type": "Scroll",
            "desc": "This long scroll bears strange runes and seals of eldritch powers. When you use an action to present this scroll to an aberration whose Challenge Rating is equal to or less than your level, the binding powers of the scroll compel it to listen to you. You can then attempt to strike a bargain with the aberration, negotiating a service from it in exchange for a reward. The aberration is under no compulsion to strike the bargain; it is compelled only to parley long enough for you to present a bargain and allow for negotiations. If you or your allies attack or otherwise attempt to harm the aberration, the truce is broken, and the creature can act normally. If the aberration refuses the offer, it is free to take any actions it wishes. Should you and the aberration reach an agreement that is satisfactory to both parties, you must sign the agreement and have the aberration do likewise (or make its mark, if it has no form of writing). The writing on the scroll changes to reflect the terms of the agreement struck. The magic of the charter holds both you and the aberration to the agreement until its service is rendered and the reward paid, at which point the scroll blackens and crumbles to dust. An aberration's thinking is alien to most humanoids, and vaguely worded contracts may result in unintended consequences, as the creature may have different thoughts as to how to best meet the goal. If either party breaks the bargain, that creature immediately takes 10d6 psychic damage, and the charter is destroyed, ending the contract.",
            "rarity": "rare",
            "requires_attunement": "",
            "document__slug": "vom",
            "document__title": "Vault of Magic",
            "document__url": "https://koboldpress.com/kpstore/product/vault-of-magic-for-5th-edition/"
        },
        {
            "slug": "absurdist-web-a5e",
            "name": "Absurdist Web",
            "type": "Wondrous Item",
            "desc": "When you try to unfold this bed sheet-sized knot of spidersilk, you occasionally unearth a long-dead sparrow or a cricket that waves thanks before hopping away. It’s probably easier just to wad it up and stick it in your pocket. The interior of this ball of web is an extradimensional space equivalent to a 10-foot cube. To place things into this space you must push it into the web, so it cannot hold liquids or gasses. You can only retrieve items you know are inside, making it excellent for smuggling. Retrieving items takes at least 2 actions (or more for larger objects) and things like loose coins tend to get lost inside it. No matter how full, the web never weighs more than a half pound.\n\nA creature attempting to divine the contents of the web via magic must first succeed on a DC 28 Arcana check which can only be attempted once between _long rests_ .\n\nAny creature placed into the extradimensional space is placed into stasis for up to a month, needing no food or water but still healing at a natural pace. Dead creatures in the web do not decay. If a living creature is not freed within a month, it is shunted from the web and appears beneath a large spider web 1d6 miles away in the real world.",
            "rarity": "Very Rare",
            "requires_attunement": "",
            "document__slug": "a5e",
            "document__title": "Level Up Advanced 5e",
            "document__url": "https://a5esrd.com/a5esrd"
        },
        {
            "slug": "accursed-idol",
            "name": "Accursed Idol",
            "type": "Wondrous item",
            "desc": "Carved from a curious black stone of unknown origin, this small totem is fashioned in the macabre likeness of a Great Old One. While attuned to the idol and holding it, you gain the following benefits:\n- You can speak, read, and write Deep Speech.\n- You can use an action to speak the idol's command word and send otherworldly spirits to whisper in the minds of up to three creatures you can see within 30 feet of you. Each target must make a DC 13 Charisma saving throw. On a failed save, a creature takes 2d6 psychic damage and is frightened of you for 1 minute. On a successful save, a creature takes half as much damage and isn't frightened. If a target dies from this damage or while frightened, the otherworldly spirits within the idol are temporarily sated, and you don't suffer the effects of the idol's Otherworldly Whispers property at the next dusk. Once used, this property of the idol can't be used again until the next dusk.\n- You can use an action to cast the augury spell from the idol. The idol can't be used this way again until the next dusk.",
            "rarity": "uncommon",
            "requires_attunement": "requires attunement",
            "document__slug": "vom",
            "document__title": "Vault of Magic",
            "document__url": "https://koboldpress.com/kpstore/product/vault-of-magic-for-5th-edition/"
        },
        {
            "slug": "adamantine-armor",
            "name": "Adamantine Armor",
            "type": "Armor (medium or heavy)",
            "desc": "This suit of armor is reinforced with adamantine, one of the hardest substances in existence. While you're wearing it, any critical hit against you becomes a normal hit.",
            "rarity": "uncommon",
            "requires_attunement": "",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd"
        },
        {
            "slug": "aegis-of-the-eternal-moon-a5e",
            "name": "Aegis of the Eternal Moon",
            "type": "Armor",
            "desc": "The circular surface of this gleaming silver shield is marked by dents and craters making it reminiscent of a full moon. While holding this medium shield, you gain a magical +1 bonus to AC. This item has 3 charges and regains 1 charge each night at moonrise. \n\nWhile this shield is equipped, you may expend 1 charge as an action to cast _moonbeam_ , with the following exceptions: the spell manifests as a line of moonlight 10 feet long and 5 feet wide emanating from the shield, and you may move the beam by moving the shield (no action required). When the first charge is expended, the shield fades to the shape of a gibbous moon and loses its magical +1 bonus to AC. When the second charge is expended, the shield fades to the shape of a crescent moon and becomes a light shield, granting only a +1 bonus to AC. When the final charge is expended, the shield fades away completely, leaving behind its polished silver handle. When the shield regains charges, it reforms according to how many charges it has remaining.",
            "rarity": "Very Rare",
            "requires_attunement": "requires attunement",
            "document__slug": "a5e",
            "document__title": "Level Up Advanced 5e",
            "document__url": "https://a5esrd.com/a5esrd"
        },
        {
            "slug": "aerodite-the-autumn-queens-true-name-a5e",
            "name": "Aerodite the Autumn Queen’s True Name",
            "type": "Wondrous Item",
            "desc": "This slip of parchment contains the magically bound name “Airy Nightengale” surrounded by shifting autumn leaves. While you are attuned to it, you can use a bonus action to invoke the name on this parchment to summon a vision of a powerful _archfey_  beside you for 1 minute. Airy acts catty and dismissive but mellows with flattery. Once a vision is summoned in this way, it cannot be summoned again for the next 24 hours.\n\nYou can use an action to verbally direct the vision to do any of the following: \n\n* Perform minor acts of nature magic (as _druidcraft_ ).\n* Whisper charming words to a target creature within 5 feet. Creatures whispered to in this way must make a DC 13 Charisma _saving throw_ , on a failed save targets become _charmed_  by the vision until the end of their next turn, treating the vision and you as friendly allies.\n* Bestow a magical fly speed of 10 feet on a creature within 5 feet for as long as the vision remains.\n\nAlternatively, as an action while the vision is summoned you can agree to revoke your claim on Aerodite in exchange for her direct assistance. When you do so the parchment disappears in a flurry of autumn leaves, and for the next minute the figment transforms into an alluring vision of the Dreaming at a point you choose within 60 feet (as __hypnotic pattern_ , save DC 13). Once you have revoked your claim in this way, you can never invoke Aerodite’s true name again.",
            "rarity": "Uncommon",
            "requires_attunement": "requires attunement",
            "document__slug": "a5e",
            "document__title": "Level Up Advanced 5e",
            "document__url": "https://a5esrd.com/a5esrd"
        },
        {
            "slug": "agile-armor",
            "name": "Agile Armor",
            "type": "Armor",
            "desc": "This magically enhanced armor is less bulky than its nonmagical version. While wearing a suit of medium agile armor, the maximum Dexterity modifier you can add to determine your Armor Class is 3, instead of 2. While wearing a suit of heavy agile armor, the maximum Dexterity modifier you can add to determine your Armor Class is 1, instead of 0.",
            "rarity": "common",
            "requires_attunement": "",
            "document__slug": "vom",
            "document__title": "Vault of Magic",
            "document__url": "https://koboldpress.com/kpstore/product/vault-of-magic-for-5th-edition/"
        },
        {
            "slug": "air-charm-a5e",
            "name": "Air Charm",
            "type": "Wondrous Item",
            "desc": "While wearing this charm you can hold your breath for an additional 10 minutes, or you can break the charm to release its power, destroying it to activate one of the following effects.\n\n* **Flight**: Cast __fly ._\n* **Float**: Cast _feather fall_ .\n* **Whirl**: Cast __whirlwind kick_  (+7 spell attack bonus, spell save DC 15).\n\n**Curse**. Releasing the charm’s power attracts the attention of a _djinni_  who seeks you out to request a favor.",
            "rarity": "Uncommon",
            "requires_attunement": "",
            "document__slug": "a5e",
            "document__title": "Level Up Advanced 5e",
            "document__url": "https://a5esrd.com/a5esrd"
        },
        {
            "slug": "air-seed",
            "name": "Air Seed",
            "type": "Wondrous item",
            "desc": "This plum-sized, nearly spherical sandstone is imbued with a touch of air magic. Typically, 1d4 + 4 air seeds are found together. You can use an action to throw the seed up to 60 feet. The seed explodes on impact and is destroyed. When it explodes, the seed releases a burst of fresh, breathable air, and it disperses gas or vapor and extinguishes candles, torches, and similar unprotected flames within a 10-foot radius of where the seed landed. Each suffocating or choking creature within a 10-foot radius of where the seed landed gains a lung full of air, allowing the creature to hold its breath for 5 minutes. If you break the seed while underwater, each creature within a 10-foot radius of where you broke the seed gains a lung full of air, allowing the creature to hold its breath for 5 minutes.",
            "rarity": "uncommon",
            "requires_attunement": "",
            "document__slug": "vom",
            "document__title": "Vault of Magic",
            "document__url": "https://koboldpress.com/kpstore/product/vault-of-magic-for-5th-edition/"
        },
        {
            "slug": "akaasit-blade",
            "name": "Akaasit Blade",
            "type": "Weapon",
            "desc": "You gain a +1 bonus to attack and damage rolls made with this magic weapon. This dagger is crafted from the arm blade of a defeated Akaasit (see Tome of Beasts 2). You can use an action to activate a small measure of prescience within the dagger for 1 minute. If you are attacked by a creature you can see within 5 feet of you while this effect is active, you can use your reaction to make one attack with this dagger against the attacker. If your attack hits, the dagger loses its prescience, and its prescience can't be activated again until the next dawn.",
            "rarity": "rare",
            "requires_attunement": "",
            "document__slug": "vom",
            "document__title": "Vault of Magic",
            "document__url": "https://koboldpress.com/kpstore/product/vault-of-magic-for-5th-edition/"
        },
        {
            "slug": "alabaster-salt-shaker",
            "name": "Alabaster Salt Shaker",
            "type": "Wondrous item",
            "desc": "This shaker is carved from purest alabaster in the shape of an owl. It is 7 inches tall and contains enough salt to flavor 25 meals. When the shaker is empty, it can't be refilled, and it becomes nonmagical. When you or another creature eat a meal salted by this shaker, you don't need to eat again for 48 hours, at which point the magic wears off. If you don't eat within 1 hour of the magic wearing off, you gain one level of exhaustion. You continue gaining one level of exhaustion for each additional hour you don't eat.",
            "rarity": "rare",
            "requires_attunement": "",
            "document__slug": "vom",
            "document__title": "Vault of Magic",
            "document__url": "https://koboldpress.com/kpstore/product/vault-of-magic-for-5th-edition/"
        },
        {
            "slug": "alchemical-lantern",
            "name": "Alchemical Lantern",
....... 

Weapon List
list: API endpoint for returning a list of weapons.
retrieve: API endpoint for returning a particular weapon.

«12»
GET /v2/weapons/
HTTP 200 OK
Allow: GET, HEAD, OPTIONS
Content-Type: application/json
Vary: Accept

{
    "count": 75,
    "next": "https://api.open5e.com/v2/weapons/?page=2",
    "previous": null,
    "results": [
        {
            "url": "https://api.open5e.com/v2/weapons/srd-2024_battleaxe/",
            "key": "srd-2024_battleaxe",
            "document": {
                "name": "System Reference Document 5.2",
                "key": "srd-2024",
                "type": "SOURCE",
                "display_name": "5e 2024 Rules",
                "publisher": {
                    "name": "Wizards of the Coast",
                    "key": "wizards-of-the-coast",
                    "url": "https://api.open5e.com/v2/publishers/wizards-of-the-coast/"
                },
                "gamesystem": {
                    "name": "5th Edition 2024",
                    "key": "5e-2024",
                    "url": "https://api.open5e.com/v2/gamesystems/5e-2024/"
                },
                "permalink": "https://dnd.wizards.com/resources/systems-reference-document"
            },
            "properties": [
                {
                    "property": {
                        "name": "Topple",
                        "type": "Mastery",
                        "url": "/v2/weaponproperties/srd-2024_topple-mastery/",
                        "desc": "If you hit a creature with this weapon, you can force the creature to make a Constitution saving throw (DC 8 plus the ability modifier used to make the attack roll and your Proficiency Bonus). On a failed save, the creature has the Prone condition."
                    },
                    "detail": null
                },
                {
                    "property": {
                        "name": "Versatile",
                        "type": null,
                        "url": "/v2/weaponproperties/srd-2024_versatile-wp/",
                        "desc": "A Versatile weapon can be used with one or two hands. A damage value in parentheses appears with the property. The weapon deals that damage when used with two hands to make a melee attack."
                    },
                    "detail": "1d10"
                }
            ],
            "damage_type": {
                "name": "Slashing",
                "key": "slashing",
                "url": "https://api.open5e.com/v2/damagetypes/slashing/"
            },
            "distance_unit": "feet",
            "name": "Battleaxe",
            "damage_dice": "1d8",
            "range": 0.0,
            "long_range": 0.0,
            "is_simple": false,
            "is_improvised": false
        },
        {
            "url": "https://api.open5e.com/v2/weapons/srd-2024_blowgun/",
            "key": "srd-2024_blowgun",
            "document": {
                "name": "System Reference Document 5.2",
                "key": "srd-2024",
                "type": "SOURCE",
                "display_name": "5e 2024 Rules",
                "publisher": {
                    "name": "Wizards of the Coast",
                    "key": "wizards-of-the-coast",
                    "url": "https://api.open5e.com/v2/publishers/wizards-of-the-coast/"
                },
                "gamesystem": {
                    "name": "5th Edition 2024",
                    "key": "5e-2024",
                    "url": "https://api.open5e.com/v2/gamesystems/5e-2024/"
                },
                "permalink": "https://dnd.wizards.com/resources/systems-reference-document"
            },
            "properties": [
                {
                    "property": {
                        "name": "Ammunition",
                        "type": null,
                        "url": "/v2/weaponproperties/srd-2024_ammunition-wp/",
                        "desc": "You can use a weapon that has the Ammunition property to make a ranged attack only if you have ammunition to fire from it. The type of ammunition required is specified with the weapon's range. Each attack expends one piece of ammunition. Drawing the ammunition is part of the attack (you need a free hand to load a one-handed weapon). After a fight, you can spend 1 minute to recover half the ammunition (round down) you used in the fight; the rest is lost."
                    },
                    "detail": "Range 25/100; Needle"
                },
                {
                    "property": {
                        "name": "Loading",
                        "type": null,
                        "url": "/v2/weaponproperties/srd-2024_loading-wp/",
                        "desc": "You can fire only one piece of ammunition from a Loading weapon when you use an action, a Bonus Action, or a Reaction to fire it, regardless of the number of attacks you can normally make."
                    },
                    "detail": null
                },
                {
                    "property": {
                        "name": "Vex",
                        "type": "Mastery",
                        "url": "/v2/weaponproperties/srd-2024_vex-mastery/",
                        "desc": "If you hit a creature with this weapon and deal damage to the creature, you have Advantage on your next attack roll against that creature before the end of your next turn."
                    },
                    "detail": null
                }
            ],
            "damage_type": {
                "name": "Piercing",
                "key": "piercing",
                "url": "https://api.open5e.com/v2/damagetypes/piercing/"
            },
            "distance_unit": "feet",
            "name": "Blowgun",
            "damage_dice": "1",
            "range": 25.0,
            "long_range": 100.0,
            "is_simple": false,
            "is_improvised": false
        },
        {
            "url": "https://api.open5e.com/v2/weapons/srd-2024_club/",
            "key": "srd-2024_club",
            "document": {
                "name": "System Reference Document 5.2",
                "key": "srd-2024",
                "type": "SOURCE",
                "display_name": "5e 2024 Rules",
                "publisher": {
                    "name": "Wizards of the Coast",
                    "key": "wizards-of-the-coast",
                    "url": "https://api.open5e.com/v2/publishers/wizards-of-the-coast/"
                },
                "gamesystem": {
                    "name": "5th Edition 2024",
                    "key": "5e-2024",
                    "url": "https://api.open5e.com/v2/gamesystems/5e-2024/"
                },
                "permalink": "https://dnd.wizards.com/resources/systems-reference-document"
            },
            "properties": [
                {
                    "property": {
                        "name": "Light",
                        "type": null,
                        "url": "/v2/weaponproperties/srd-2024_light-wp/",
                        "desc": "When you take the Attack action on your turn and attack with a Light weapon, you can make one extra attack as a Bonus Action later on the same turn. That extra attack must be made with a different Light weapon, and you don't add your ability modifier to the extra attack's damage unless that modifier is negative."
                    },
                    "detail": null
                },
                {
                    "property": {
                        "name": "Slow",
                        "type": "Mastery",
                        "url": "/v2/weaponproperties/srd-2024_slow-mastery/",
                        "desc": "If you hit a creature with this weapon and deal damage to it, you can reduce its Speed by 10 feet until the start of your next turn. If the creature is hit more than once by weapons that have this property, the Speed reduction doesn't exceed 10 feet."
                    },
                    "detail": null
                }
            ],
            "damage_type": {
                "name": "Bludgeoning",
                "key": "bludgeoning",
                "url": "https://api.open5e.com/v2/damagetypes/bludgeoning/"
            },
            "distance_unit": "feet",
            "name": "Club",
            "damage_dice": "1d4",
            "range": 0.0,
            "long_range": 0.0,
            "is_simple": true,
            "is_improvised": false
        },
        {
            "url": "https://api.open5e.com/v2/weapons/srd-2024_dagger/",
            "key": "srd-2024_dagger",
            "document": {
                "name": "System Reference Document 5.2",
                "key": "srd-2024",
                "type": "SOURCE",
                "display_name": "5e 2024 Rules",
                "publisher": {
                    "name": "Wizards of the Coast",
                    "key": "wizards-of-the-coast",
                    "url": "https://api.open5e.com/v2/publishers/wizards-of-the-coast/"
                },
                "gamesystem": {
                    "name": "5th Edition 2024",
                    "key": "5e-2024",
                    "url": "https://api.open5e.com/v2/gamesystems/5e-2024/"
                },
                "permalink": "https://dnd.wizards.com/resources/systems-reference-document"
            },
            "properties": [
                {
                    "property": {
                        "name": "Finesse",
                        "type": null,
                        "url": "/v2/weaponproperties/srd-2024_finesse-wp/",
                        "desc": "When making an attack with a Finesse weapon, use your choice of your Strength or Dexterity modifier for the attack and damage rolls. You must use the same modifier for both rolls."
                    },
                    "detail": null
                },
                {
                    "property": {
                        "name": "Light",
                        "type": null,
                        "url": "/v2/weaponproperties/srd-2024_light-wp/",
                        "desc": "When you take the Attack action on your turn and attack with a Light weapon, you can make one extra attack as a Bonus Action later on the same turn. That extra attack must be made with a different Light weapon, and you don't add your ability modifier to the extra attack's damage unless that modifier is negative."
                    },
                    "detail": null
                },
                {
                    "property": {
                        "name": "Nick",
                        "type": "Mastery",
                        "url": "/v2/weaponproperties/srd-2024_nick-mastery/",
                        "desc": "When you make the extra attack of the Light property, you can make it as part of the Attack action instead of as a Bonus Action. You can make this extra attack only once per turn."
                    },
                    "detail": null
                },
                {
                    "property": {
                        "name": "Thrown",
                        "type": null,
                        "url": "/v2/weaponproperties/srd-2024_thrown-wp/",
                        "desc": "If a weapon has the Thrown property, you can throw the weapon to make a ranged attack, and you can draw that weapon as part of the attack. If the weapon is a Melee weapon, use the same ability modifier for the attack and damage rolls that you use for a melee attack with that weapon."
                    },
                    "detail": "Range 20/60"
                }
            ],
            "damage_type": {
                "name": "Piercing",
                "key": "piercing",
                "url": "https://api.open5e.com/v2/damagetypes/piercing/"
            },
            "distance_unit": "feet",
            "name": "Dagger",
            "damage_dice": "1d4",
            "range": 20.0,
            "long_range": 60.0,
            "is_simple": true,
            "is_improvised": false
        },
        {
            "url": "https://api.open5e.com/v2/weapons/srd-2024_dart/",
            "key": "srd-2024_dart",
            "document": {
                "name": "System Reference Document 5.2",
                "key": "srd-2024",
                "type": "SOURCE",
                "display_name": "5e 2024 Rules",
                "publisher": {
                    "name": "Wizards of the Coast",
                    "key": "wizards-of-the-coast",
                    "url": "https://api.open5e.com/v2/publishers/wizards-of-the-coast/"
                },
                "gamesystem": {
                    "name": "5th Edition 2024",
                    "key": "5e-2024",
                    "url": "https://api.open5e.com/v2/gamesystems/5e-2024/"
                },
                "permalink": "https://dnd.wizards.com/resources/systems-reference-document"
            },
            "properties": [
                {
                    "property": {
                        "name": "Finesse",
                        "type": null,
                        "url": "/v2/weaponproperties/srd-2024_finesse-wp/",
                        "desc": "When making an attack with a Finesse weapon, use your choice of your Strength or Dexterity modifier for the attack and damage rolls. You must use the same modifier for both rolls."
                    },
                    "detail": null
                },
                {
                    "property": {
                        "name": "Thrown",
                        "type": null,
                        "url": "/v2/weaponproperties/srd-2024_thrown-wp/",
                        "desc": "If a weapon has the Thrown property, you can throw the weapon to make a ranged attack, and you can draw that weapon as part of the attack. If the weapon is a Melee weapon, use the same ability modifier for the attack and damage rolls that you use for a melee attack with that weapon."
                    },
                    "detail": "Range 20/60"
                },
                {
                    "property": {
                        "name": "Vex",
                        "type": "Mastery",
                        "url": "/v2/weaponproperties/srd-2024_vex-mastery/",
                        "desc": "If you hit a creature with this weapon and deal damage to the creature, you have Advantage on your next attack roll against that creature before the end of your next turn."
                    },
                    "detail": null
                }
            ],
            "damage_type": {
                "name": "Piercing",
                "key": "piercing",
                "url": "https://api.open5e.com/v2/damagetypes/piercing/"
            },
            "distance_unit": "feet",
            "name": "Dart",
            "damage_dice": "1d4",
            "range": 20.0,
            "long_range": 60.0,
            "is_simple": true,
            "is_improvised": false
        },
        {
            "url": "https://api.open5e.com/v2/weapons/srd-2024_flail/",
            "key": "srd-2024_flail",
            "document": {
                "name": "System Reference Document 5.2",
                "key": "srd-2024",
                "type": "SOURCE",
                "display_name": "5e 2024 Rules",
                "publisher": {
                    "name": "Wizards of the Coast",
                    "key": "wizards-of-the-coast",
                    "url": "https://api.open5e.com/v2/publishers/wizards-of-the-coast/"
                },
........


Weapon Instance
list: API endpoint for returning a list of weapons.
retrieve: API endpoint for returning a particular weapon.

GET /v2/weapons/srd-2024_flail/
HTTP 200 OK
Allow: GET, HEAD, OPTIONS
Content-Type: application/json
Vary: Accept

{
    "url": "https://api.open5e.com/v2/weapons/srd-2024_flail/",
    "key": "srd-2024_flail",
    "document": {
        "name": "System Reference Document 5.2",
        "key": "srd-2024",
        "type": "SOURCE",
        "display_name": "5e 2024 Rules",
        "publisher": {
            "name": "Wizards of the Coast",
            "key": "wizards-of-the-coast",
            "url": "https://api.open5e.com/v2/publishers/wizards-of-the-coast/"
        },
        "gamesystem": {
            "name": "5th Edition 2024",
            "key": "5e-2024",
            "url": "https://api.open5e.com/v2/gamesystems/5e-2024/"
        },
        "permalink": "https://dnd.wizards.com/resources/systems-reference-document"
    },
    "properties": [
        {
            "property": {
                "name": "Sap",
                "type": "Mastery",
                "url": "/v2/weaponproperties/srd-2024_sap-mastery/",
                "desc": "If you hit a creature with this weapon, that creature has Disadvantage on its next attack roll before the start of your next turn."
            },
            "detail": null
        }
    ],
    "damage_type": {
        "name": "Bludgeoning",
        "key": "bludgeoning",
        "url": "https://api.open5e.com/v2/damagetypes/bludgeoning/"
    },
    "distance_unit": "feet",
    "name": "Flail",
    "damage_dice": "1d8",
    "range": 0.0,
    "long_range": 0.0,
    "is_simple": false,
    "is_improvised": false
}



Armor List
list: API endpoint for returning a list of armor.
retrieve: API endpoint for returning a particular armor.

GET /v2/armor/
HTTP 200 OK
Allow: GET, HEAD, OPTIONS
Content-Type: application/json
Vary: Accept

{
    "count": 25,
    "next": null,
    "previous": null,
    "results": [
        {
            "url": "https://api.open5e.com/v2/armor/srd-2024_breastplate/",
            "key": "srd-2024_breastplate",
            "ac_display": "14 + Dex modifier (max 2)",
            "category": "medium",
            "document": {
                "name": "System Reference Document 5.2",
                "key": "srd-2024",
                "type": "SOURCE",
                "display_name": "5e 2024 Rules",
                "publisher": {
                    "name": "Wizards of the Coast",
                    "key": "wizards-of-the-coast",
                    "url": "https://api.open5e.com/v2/publishers/wizards-of-the-coast/"
                },
                "gamesystem": {
                    "name": "5th Edition 2024",
                    "key": "5e-2024",
                    "url": "https://api.open5e.com/v2/gamesystems/5e-2024/"
                },
                "permalink": "https://dnd.wizards.com/resources/systems-reference-document"
            },
            "name": "Breastplate",
            "grants_stealth_disadvantage": false,
            "strength_score_required": null,
            "ac_base": 14,
            "ac_add_dexmod": true,
            "ac_cap_dexmod": 2
        },
        {
            "url": "https://api.open5e.com/v2/armor/srd-2024_chain-mail/",
            "key": "srd-2024_chain-mail",
            "ac_display": "16",
            "category": "heavy",
            "document": {
                "name": "System Reference Document 5.2",
                "key": "srd-2024",
                "type": "SOURCE",
                "display_name": "5e 2024 Rules",
                "publisher": {
                    "name": "Wizards of the Coast",
                    "key": "wizards-of-the-coast",
                    "url": "https://api.open5e.com/v2/publishers/wizards-of-the-coast/"
                },
                "gamesystem": {
                    "name": "5th Edition 2024",
                    "key": "5e-2024",
                    "url": "https://api.open5e.com/v2/gamesystems/5e-2024/"
                },
                "permalink": "https://dnd.wizards.com/resources/systems-reference-document"
            },
            "name": "Chain Mail",
            "grants_stealth_disadvantage": true,
            "strength_score_required": 13,
            "ac_base": 16,
            "ac_add_dexmod": false,
            "ac_cap_dexmod": null
        },
        {
            "url": "https://api.open5e.com/v2/armor/srd-2024_chain-shirt/",
            "key": "srd-2024_chain-shirt",
            "ac_display": "13 + Dex modifier (max 2)",
            "category": "medium",
            "document": {
                "name": "System Reference Document 5.2",
                "key": "srd-2024",
                "type": "SOURCE",
                "display_name": "5e 2024 Rules",
                "publisher": {
                    "name": "Wizards of the Coast",
                    "key": "wizards-of-the-coast",
                    "url": "https://api.open5e.com/v2/publishers/wizards-of-the-coast/"
                },
                "gamesystem": {
                    "name": "5th Edition 2024",
                    "key": "5e-2024",
                    "url": "https://api.open5e.com/v2/gamesystems/5e-2024/"
                },
                "permalink": "https://dnd.wizards.com/resources/systems-reference-document"
            },
            "name": "Chain Shirt",
            "grants_stealth_disadvantage": false,
            "strength_score_required": null,
            "ac_base": 13,
            "ac_add_dexmod": true,
            "ac_cap_dexmod": 2
        },
        {
            "url": "https://api.open5e.com/v2/armor/srd-2024_half-plate-armor/",
            "key": "srd-2024_half-plate-armor",
            "ac_display": "15 + Dex modifier (max 2)",
            "category": "medium",
            "document": {
                "name": "System Reference Document 5.2",
                "key": "srd-2024",
                "type": "SOURCE",
                "display_name": "5e 2024 Rules",
                "publisher": {
                    "name": "Wizards of the Coast",
                    "key": "wizards-of-the-coast",
                    "url": "https://api.open5e.com/v2/publishers/wizards-of-the-coast/"
                },
                "gamesystem": {
                    "name": "5th Edition 2024",
                    "key": "5e-2024",
                    "url": "https://api.open5e.com/v2/gamesystems/5e-2024/"
                },
                "permalink": "https://dnd.wizards.com/resources/systems-reference-document"
            },
            "name": "Half Plate Armor",
            "grants_stealth_disadvantage": true,
            "strength_score_required": null,
            "ac_base": 15,
            "ac_add_dexmod": true,
            "ac_cap_dexmod": 2
        },
        {
            "url": "https://api.open5e.com/v2/armor/srd-2024_hide-armor/",
            "key": "srd-2024_hide-armor",
            "ac_display": "12 + Dex modifier (max 2)",
            "category": "medium",
            "document": {
                "name": "System Reference Document 5.2",
                "key": "srd-2024",
                "type": "SOURCE",
........


Armor Instance
list: API endpoint for returning a list of armor.
retrieve: API endpoint for returning a particular armor.

GET /v2/armor/srd-2024_chain-shirt/
HTTP 200 OK
Allow: GET, HEAD, OPTIONS
Content-Type: application/json
Vary: Accept

{
    "url": "https://api.open5e.com/v2/armor/srd-2024_chain-shirt/",
    "key": "srd-2024_chain-shirt",
    "ac_display": "13 + Dex modifier (max 2)",
    "category": "medium",
    "document": {
        "name": "System Reference Document 5.2",
        "key": "srd-2024",
        "type": "SOURCE",
        "display_name": "5e 2024 Rules",
        "publisher": {
            "name": "Wizards of the Coast",
            "key": "wizards-of-the-coast",
            "url": "https://api.open5e.com/v2/publishers/wizards-of-the-coast/"
        },
        "gamesystem": {
            "name": "5th Edition 2024",
            "key": "5e-2024",
            "url": "https://api.open5e.com/v2/gamesystems/5e-2024/"
        },
        "permalink": "https://dnd.wizards.com/resources/systems-reference-document"
    },
    "name": "Chain Shirt",
    "grants_stealth_disadvantage": false,
    "strength_score_required": null,
    "ac_base": 13,
    "ac_add_dexmod": true,
    "ac_cap_dexmod": 2
}



Publisher Instance
list: API endpoint for returning a list of publishers.
retrieve: API endpoint for returning a particular publisher.

GET /v2/publishers/wizards-of-the-coast/
HTTP 200 OK
Allow: GET, HEAD, OPTIONS
Content-Type: application/json
Vary: Accept

{
    "url": "https://api.open5e.com/v2/publishers/wizards-of-the-coast/",
    "key": "wizards-of-the-coast",
    "name": "Wizards of the Coast"
}