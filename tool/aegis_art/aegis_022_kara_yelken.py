#!/usr/bin/env python3
"""0.22 turu: Act 1'in son savaşı — Kara Yelken, Dürüst Terazi ve çevresi (22 kart).

Konu + ışık elle yazıldı; prompt aegis_polish.build() ile kurulur (aegis_019_maskeli_is.py ile aynı yol).
elymsyr'in isteği: herkes erkek insan olmasın — kaptan ork kadın, çavuş cüce kadın, tayfalar karışık.
Her kart için 3 seed varyantı: art_jobs_022_{a,b,c}.jsonl → out_022{a,b,c}.

    python3 aegis_022_kara_yelken.py
    python3 aegis_generate.py --jobs art_jobs_022_a.jsonl --out out_022a   # b, c aynı
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import aegis_polish as P  # noqa: E402
from aegis_prompts import entity_uuid  # noqa: E402

BASE = Path(__file__).resolve().parent

# CREATURE çerçevesi hayvan içindir; bunlar kişi.
FIGURE = ("three-quarter figure study, the figure large and dominant in frame, slightly low viewpoint, "
          "the ship falling away behind")
DECK = "wide deck-level view along the length of a ship, figures at several depths, open sea beyond the rail"
P.FRAMING.update({
    "location|Dürüst Terazi": DECK,
    "scene|Davul Sesi": DECK,
    "scene|Kaçakçı Güvertesi": DECK,
    "scene|Karantina Gecesi": ("low view inside a ship's hold looking up toward an open hatch, "
                               "figures close in the foreground, the square of the hatch above"),
    "encounter|Borda Borda": ("high wide view across two ships lashed side by side, the gap of water between "
                              "them in the middle of the frame, layered staging"),
    "monster|Ork Savaşçı": FIGURE,
    "monster|Kancacı": FIGURE,
    "monster|Davulcu": FIGURE,
    "monster|Ork Kaptan": FIGURE,
    "monster|Dönüşmüş Ork": FIGURE,
})

# Ortak betimler — kartlarla aynı.
ORC = "grey-green weathered skin, thick yellowed lower tusks, black soot smeared with the fingers from under the eyes down to the jaw"
MORDHA = ("a tall, powerfully built orc woman in her forties, " + ORC + ", the soot thicker than her crew's, the sides "
          "of her head shaved and her black hair in one thick braid down the nape, black-painted studded leather "
          "armour, a salt-whitened grey wool cloak, a single iron key on her belt")
HULDA = ("a short, broad dwarf woman in her sixties, no beard, grey hair in two thick braids with their ends tucked "
         "into her belt, a wind-reddened face, half of her left ear missing, a faded old blue-grey guard's cloak "
         "over a chain shirt, a short sword and a large iron winding key at her belt")
BLACK_SHIP = ("a black-hulled orc warship, the hull tarred pitch black, matte black sails that seem to swallow the "
              "light, a row of round shields along its rail")
TURNED = ("ash grey skin cracked into hard plates like bark at the throat and forearms, dried black streaks at the "
          "corners of the eyes, fingernails thickened into blunt grey horn")

CARDS = {
    "location|Kara Yelken": (
        BLACK_SHIP[0].upper() + BLACK_SHIP[1:] + ", cutting through a grey-green open sea under full sail, javelin points glinting between the "
        "shields, a huge barrel-sized war drum on the raised stern deck, a lone figure standing at the bow, no "
        "flag and no figurehead, white spray along the black bow",
        "overcast midday sea light, a pale glare on the water, the black sails dull and flat against a bright "
        "grey sky",
    ),
    "location|Dürüst Terazi": (
        "The deck of a sturdy mid-sized wooden merchant sailing ship on the open sea: cargo hatches lashed shut "
        "with crossed ropes, a human woman and a gnome sailor sitting cross-legged on a hatch stitching a patch of "
        "sailcloth, a half-orc sailor hauling a line, at the stern a heavy wooden ballista on a swivel mount half "
        "under a canvas cover with a halfling guard in a blue-grey cloak oiling its string, cream sails full of "
        "wind",
        "bright clear morning sun, glittering sea, crisp shadows of the rigging across the planks",
    ),
    "npc|Ork Kaptan — Mordha": (
        MORDHA + ", a two-handed greataxe resting on her shoulder, leaning on the stern rail of a black-sailed "
        "ship beside a great war drum, tapping the rail with one finger, her eyes lowered to an iron-banded "
        "hatch in the deck below rather than at the viewer",
        "cold overcast sea light, grey sky, the black sails dark behind her",
    ),
    "npc|Terazi Çavuşu — Hulda": (
        HULDA + ", standing beside a heavy wooden ballista on the stern deck of a merchant ship, one hand raised "
        "and counting heads along the deck with moving lips, sailors of many peoples blurred behind her",
        "warm late-afternoon sea sun low from one side, gold on the chain mail, the sea glittering behind",
    ),
    "encounter|Borda Borda": (
        "Two sailing ships grinding hull to hull: " + BLACK_SHIP + ", and a plain wooden merchant ship; three "
        "iron grappling hooks on taut chains bite into the merchant ship's rail across a narrow gap of dark "
        "churning water; on the black ship's deck two orcs heave up a heavy iron-banded hatch and grey ash-skinned "
        "figures in torn clothes are climbing out of the dark; at its stern an orc drummer at a huge war drum and "
        "a tall orc woman with a greataxe beside him; on the near merchant deck defenders brace with spears — a "
        "dwarf woman, a half-elf woman and a halfling among them",
        "stormy overcast light, flying spray, cold grey sea, the black sails looming",
    ),
    "scene|Davul Sesi": (
        "On the deck of a wooden merchant ship every sailor has stopped and stares the same way, toward the "
        "horizon, where a single black sail has appeared like a hole in the glittering water; a lookout high on "
        "the mast top points; the crew are of many peoples — a dwarf, a half-elf woman, a gnome, humans — and a "
        "young human woman runs aft along the deck",
        "bright midday sun, the sea a sheet of glitter, the distant black sail the only dark thing in the frame",
    ),
    "scene|Karantina Gecesi": (
        "In the dark hold of a ship, bitten sailors sit side by side on sacks in the light of a single lantern: a "
        "half-elf woman has unwound the bandage on her shoulder and stares at thin black lines spreading from "
        "the edge of the wound, a young human man coughs into his fist, an older dwarf sits with his head in his "
        "hands; above them through the open hatch a ring of crew faces looks down, keeping their distance, and "
        "one hand threads a rope through the iron ring of the hatch cover",
        "night, a single warm lantern in the hold, cold blue moonlight falling through the hatch above",
    ),
    "scene|Kaçakçı Güvertesi": (
        "Night on the cramped deck of a rough smuggler's ship leaving a hidden harbour, the harbour lights small "
        "and shrinking behind; a narrow gap between two barrels beside a cargo hatch where travellers are given "
        "a place; a rough crew watches from the shadows — a tiefling woman with a knife at her belt, a scarred "
        "half-orc man, a wiry human boy — pretending not to look; a sputtering lantern hangs from a spar, and a "
        "tall captain walks the deck toward the viewer",
        "dark night, one sputtering lantern of warm light, cold moonlight on the wet planks and black water",
    ),
    "monster|Ork Savaşçı": (
        "An orc woman warrior of a black ship's crew, " + ORC + ", a round wooden shield on her arm and a short "
        "heavy-headed javelin raised to throw, two more javelins on her back, standing in a row of shields along "
        "a black-tarred ship's rail, other orc men and women behind her in the line",
        "overcast sea light, spray in the air, the black sails above",
    ),
    "monster|Kancacı": (
        "A young orc woman at the bow of a black ship, no shield, " + ORC + ", iron chain wrapped around both "
        "forearms, swinging a three-pronged iron grappling hook on its chain in a circle over her head, her eyes "
        "fixed on the rail of a ship across the water",
        "overcast sea light, the chain a blur of grey motion against the sky",
    ),
    "monster|Davulcu": (
        "A bare-backed orc man drumming on the stern deck of a black ship, " + ORC + ", heavy muscled shoulders, "
        "eyes closed and lips moving as if counting, two leather-wrapped drumsticks raised over a huge barrel-sized "
        "war drum with a blackened skin and iron rings around its rim",
        "cold overcast light, sweat shining on his back, the black sails behind",
    ),
    "monster|Ork Kaptan": (
        MORDHA + ", swinging a broad-bladed two-handed greataxe in a hard arc on the stern deck of a black ship, "
        "her face set and calm, the great war drum behind her",
        "stormy grey sea light, spray in the air, a bright streak along the axe blade",
    ),
    "monster|Dönüşmüş Ork": (
        "A transformed orc man hauling himself up out of an open iron-banded ship's hatch, still plainly an orc "
        "and not a beast — an orc build a head taller than the others, his shoulders scraping the edges of the "
        "hatch, both hands gripping the deck planks — " + TURNED + ", one lower tusk broken, black fluid seeping "
        "from his lips, a black-dyed crew rag still knotted around his neck, his head turned toward the sound of "
        "a drum",
        "cold grey light falling into the dark hatch, deep black shadow below him",
    ),
    "creature-action|Cirit": (
        "A short heavy-headed javelin in flight across a gap of churning sea water between two ships, the "
        "grey-green arm of an orc woman just released behind it at a black-tarred rail lined with shields",
        "overcast sea light, spray hanging in the air, the iron head of the javelin glinting",
    ),
    "creature-action|Kanca": (
        "A three-pronged iron grappling hook biting deep into the wooden rail of a merchant ship, its chain pulled "
        "taut across a gap of dark water toward a black-hulled ship, splinters flying",
        "cold overcast light, wet iron glinting, spray",
    ),
    "creature-action|Tokmak": (
        "A heavy drumstick with a leather-wrapped head and an iron-ringed haft swung like a club by a bare-backed "
        "orc drummer, " + ORC + ", defending a huge war drum on a ship's stern deck",
        "cold overcast light, motion blur along the swing, spray",
    ),
    "creature-action|Ritim": (
        "A huge black war drum on a ship's stern being struck by two leather-headed drumsticks, the taut skin "
        "rippling, and down on the deck below a crowd of grey ash-skinned transformed people in torn clothes all "
        "turning their heads toward the drum at the same moment",
        "dim overcast light, a cold glow on the drum skin, the figures below in shadow",
    ),
    "creature-action|İki Saldırı": (
        "A tall orc woman captain with a black braid and soot-streaked face swinging a two-handed greataxe twice "
        "in quick succession, two bright arcs of motion trailing the blade, on the deck of a black ship",
        "stormy grey light, spray, bright streaks along the steel",
    ),
    "creature-action|Savaş Baltası": (
        "A broad-bladed two-handed greataxe with a salt-whitened leather-wrapped haft, swung down hard by a "
        "powerful grey-green orc arm, splitting a wooden ship's rail",
        "cold grey sea light, a bright line along the edge of the blade, splinters in the air",
    ),
    "trait|Düşmeyen": (
        "A transformed orc beaten down to one knee on a wet ship deck, " + TURNED + ", a broken spear shaft "
        "standing out of his side, one hand flat on the planks pushing himself back up, his empty eyes fixed "
        "forward, still coming",
        "cold grey light, spray and rain on the deck, deep shadow",
    ),
    "trinket|Kader'in Ad Tahtası": (
        "An old oak ship's name board pried off a stern, a fathom long, the word KADER carved into it in large "
        "letters with flaking yellow paint, broken nail holes along its edges, dried black tar on one corner, "
        "nailed to a black-tarred ship's rail among round shields, a dented ship's bell and a broken lantern glass",
        "cold overcast sea light, the worn yellow paint catching the light",
    ),
    "lore|Kara Donanma — Bilinen Hali": (
        "From the rail of a merchant ship at dusk, a distant ship with black sails sits on the horizon line of a "
        "dark sea; at the rail a grey-haired human woman sailor and a young half-elf sailor watch it in silence, "
        "one of them cupping a hand over a lantern to hide its light",
        "deep dusk, the last red light low on the horizon, the black sails a dark notch against it",
    ),
}

VARIANTS = {"a": 0, "b": 7919, "c": 104729}

# Düzeltme turu (ilk üç seed'den sonra): kaptan erkeğe döndü, İki Saldırı'da ork yerine insan çıktı,
# Dönüşmüş Ork trol gibi bir yaratığa döndü (kanon: dönüşmüş kişi, yaratık değil), Borda Borda'da iki gemi de
# kara yelkenli, ad tahtası yepyeni sarı: art_jobs_022_fix{a,b,c}.jsonl → out_022fix{a,b,c}.
WOMAN = ("clearly a woman, a broad strong feminine face with high cheekbones, full lips, a heavy brow but a "
         "woman's features, ")
TURNED_ORC = ("still plainly an orc person and not a beast or troll — an orc's build and proportions, wearing his "
              "own torn sailor's shirt, canvas trousers and boots — " + TURNED)
FIX = {
    "npc|Ork Kaptan — Mordha": (
        "Portrait of an orc woman ship's captain, " + WOMAN + MORDHA[2:] + ", a two-handed greataxe resting on "
        "her shoulder, leaning on the stern rail of a black-sailed ship beside a great war drum, her eyes lowered "
        "to an iron-banded hatch in the deck below rather than at the viewer",
        CARDS["npc|Ork Kaptan — Mordha"][1]),
    "monster|Ork Kaptan": (
        "An orc woman ship's captain, " + WOMAN + MORDHA[2:] + ", swinging a broad-bladed two-handed greataxe in "
        "a hard arc on the stern deck of a black ship, her face set and calm, the great war drum behind her",
        CARDS["monster|Ork Kaptan"][1]),
    "creature-action|İki Saldırı": (
        "An orc woman captain, " + WOMAN + ORC + ", grey-green skin and tusks, a thick black braid, swinging a "
        "two-handed greataxe twice in quick succession, two bright arcs of motion trailing the blade, on the deck "
        "of a black-sailed ship",
        CARDS["creature-action|İki Saldırı"][1]),
    "monster|Dönüşmüş Ork": (
        "A transformed orc sailor hauling himself up out of an open iron-banded ship's hatch, " + TURNED_ORC +
        ", a head taller than the other orcs, his shoulders scraping the edges of the hatch, both hands gripping "
        "the deck planks, one lower tusk broken, black fluid seeping from his lips, a black-dyed crew rag still "
        "knotted around his neck, his head turned toward the sound of a drum",
        CARDS["monster|Dönüşmüş Ork"][1]),
    "trait|Düşmeyen": (
        "A transformed orc sailor beaten down to one knee on a wet ship deck, " + TURNED_ORC + ", a broken spear "
        "shaft standing out of his side, one hand flat on the planks pushing himself back up, his empty eyes fixed "
        "forward, still coming",
        CARDS["trait|Düşmeyen"][1]),
    "encounter|Borda Borda": (
        "Two sailing ships grinding hull to hull: on the left a black-hulled orc warship with matte black sails and "
        "round shields along its rail; on the right a plain wooden merchant ship with cream-white sails and a "
        "honey-brown hull; three iron grappling hooks on taut chains bite into the merchant ship's rail across a "
        "narrow gap of dark churning water; on the black ship's deck orcs heave up a heavy iron-banded hatch and "
        "grey ash-skinned figures in torn clothes climb out of the dark; on the merchant deck defenders brace with "
        "spears — a dwarf woman, a half-elf woman and a halfling among them",
        CARDS["encounter|Borda Borda"][1]),
    "trinket|Kader'in Ad Tahtası": (
        "An old weathered oak ship's name board, grey and cracked with age, pried off a stern and nailed crookedly "
        "to a black-tarred ship's rail, the word KADER carved into it in large letters with only faint traces of "
        "faded flaking yellow paint left in the grooves, broken nail holes along its edges, dried black tar on one "
        "corner, round shields and a dented ship's bell beside it",
        CARDS["trinket|Kader'in Ad Tahtası"][1]),
}
FIX_VARIANTS = {"a": 31337, "b": 62674, "c": 94011}


def main() -> None:
    base_jobs = []
    for key, (subject, light) in CARDS.items():
        cat, name = key.split("|", 1)
        job = {"uuid": entity_uuid(cat, name), "category": cat, "name": name}
        P.LIGHT[key] = light
        job["prompt"] = P.build(job, subject)
        job["seed"] = int(job["uuid"][:8], 16)
        base_jobs.append(job)
    for v, off in VARIANTS.items():
        (BASE / f"art_jobs_022_{v}.jsonl").write_text(
            "".join(json.dumps({**j, "seed": (j["seed"] + off) % 2**32}, ensure_ascii=False) + "\n"
                    for j in base_jobs), encoding="utf-8")
    fix_jobs = []
    for key, (subject, light) in FIX.items():
        cat, name = key.split("|", 1)
        job = {"uuid": entity_uuid(cat, name), "category": cat, "name": name}
        P.LIGHT[key] = light
        job["prompt"] = P.build(job, subject)
        job["seed"] = int(job["uuid"][:8], 16)
        fix_jobs.append(job)
    for v, off in FIX_VARIANTS.items():
        (BASE / f"art_jobs_022_fix{v}.jsonl").write_text(
            "".join(json.dumps({**j, "seed": (j["seed"] + off) % 2**32}, ensure_ascii=False) + "\n"
                    for j in fix_jobs), encoding="utf-8")
    print(len(base_jobs), "kart x", len(VARIANTS), "varyant;", len(fix_jobs), "düzeltme")


if __name__ == "__main__":
    main()
