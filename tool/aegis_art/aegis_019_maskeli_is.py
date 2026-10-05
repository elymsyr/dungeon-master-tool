#!/usr/bin/env python3
"""0.19 turu: Maskeli İş görevinin 12 kartı (7 kart + 5 eylem).

Konu + ışık elle yazıldı; prompt aegis_polish.build() ile kurulur (aegis_018_missing.py ile aynı yol).
Her kart için 3 seed varyantı: art_jobs_019_{a,b,c}.jsonl → out_019{a,b,c}.

    python3 aegis_019_maskeli_is.py
    python3 aegis_generate.py --jobs art_jobs_019_a.jsonl --out out_019a   # b, c aynı
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import aegis_polish as P  # noqa: E402
from aegis_prompts import entity_uuid  # noqa: E402

BASE = Path(__file__).resolve().parent

# CREATURE çerçevesi hayvan içindir ("the animal filling the frame"); bunlar insan.
FIGURE = ("three-quarter figure study, the figure large and dominant in frame, slightly low viewpoint, "
          "the room falling away into shadow behind")
P.FRAMING.update({
    "location|Askeri Hukuk Odası": "street-level establishing shot looking up a stepped lane, the house filling the middle of the frame",
    # Yorum 2: dövüş sahnesi tutarsızdı (havaya silah, oturan, kılıcı tabanca gibi tutan); dövüş öncesi sakin an.
    "encounter|Gece Şantiyesi": ("wide calm view from the open front doorway into the room, everyone still and "
                                 "unaware, a quiet moment before trouble"),
    "quest|Maskeli İş": "close first-person composition, the offered mask reaching toward the viewer, the figure large in frame",
    "monster|Şantiye Bekçisi": FIGURE,
    "monster|Kiralık Pala": FIGURE,
    "monster|Bekçibaşı": FIGURE,
})

PISTOL = "a single-shot flintlock pistol with a wooden grip and a short iron barrel"

# kategori|ad → (konu, ışık)
CARDS = {
    # Yorum 2: eski seçimin biçimi ve merdiveni daha iyiydi; o görsel ref, üst kat boyasız taze tahta (Y2).
    "location|Askeri Hukuk Odası": (
        "A narrow stepped terrace lane high on the hillside of a pale grey limestone harbour city, and in the middle "
        "of the row an old two-storey stone townhouse still under construction: its upper storey is a new frame of "
        "raw unpainted timber, fresh pale yellow planks and bare wooden studs with no paint, the wood grain and nail "
        "heads showing, wrapped in a cage of rough wooden scaffolding with a ladder and walk planks, half of its roof "
        "only bare rafters with the sky showing between them, a stack of fresh logs against the wall, tar buckets by "
        "the door, a new blank wooden signboard nailed above a single oak door with two worn stone steps, warm light "
        "leaking through one window",
        "deep blue dusk, the last violet light in the sky between the bare rafters, a warm orange lantern glow "
        "from the window, cool shadows in the lane",
    ),
    "npc|Valinin Yardımcısı": (
        "A tall slender red dragonborn man in his early forties, a humanoid with a dragon's head, dark brick-red "
        "scales turning coppery under the chin and down the throat, short horns curving back from his head and "
        "filed smooth with thin gold rings on their tips, calm unblinking yellow eyes, wearing an immaculate "
        "midnight-blue velvet coat with mother-of-pearl buttons and a stiff starched bright white collar, not a "
        "single crease on his sleeves, thin black leather gloves, standing with polite composure in the arcaded "
        "stone courtyard of a customs house, one gloved hand turned out in a courteous gesture of invitation, "
        "ship masts and timber cranes beyond the arches",
        "bright harbour afternoon light filtered through the courtyard arches, soft sheen on the velvet, "
        "cool shade behind him",
    ),
    "monster|Şantiye Bekçisi": (
        "A rough human dock labourer hired as a night watchman, in his thirties, stubbled, a patched leather vest "
        "over a coarse shirt, pulling a sharp iron cargo hook from his belt, his lantern set down on the cobbles "
        "beside him, his back to the stone wall of a house under construction, turning toward a sound in the "
        "dark, his breath steaming in the cold air",
        "night, the lantern on the ground lighting him from below in warm orange, cold blue darkness of the "
        "street all around",
    ),
    "monster|Kiralık Pala": (
        "A single hired sellsword, an out-of-work human sailor in his thirties with a gold hoop earring and a "
        "half-faded ship tattoo on his forearm, a stained linen shirt and a leather vest, rising from a bench at a "
        "long rough wooden table with his cutlass in hand, dice and copper coins on the table in front of him, "
        "looking sharply toward the door, a stone hearth behind him",
        "warm hearth firelight from one side and a single lantern on the table, deep brown shadows",
    ),
    "monster|Bekçibaşı": (
        "A weathered human former ship's captain in his fifties, grey hair tied at the nape, a face tanned like "
        "leather, leaning back on a chair tipped onto its back legs with his boots up on a new clerk's writing "
        "desk, " + PISTOL + " resting across his lap, a slender rapier at his hip, a single iron key "
        "hanging from his belt, unimpressed and not getting up, his eyes on the viewer, crates of papers and "
        "empty new shelves behind him",
        "lantern light from the desk, warm gold on his face, the rest of the room in shadow",
    ),
    "encounter|Gece Şantiyesi": (
        "Inside the ground floor of a half-finished stone townhouse at night, three hired guards keeping watch and "
        "not expecting anyone: at the back a stone hearth with a low fire, in front of it a long rough wooden table "
        "where a sailor with a gold earring sits alone on a bench rolling dice, his cutlass lying sheathed on the "
        "table; a stubbled dock labourer in a patched leather vest dozes on a stool against the stone wall, an iron "
        "cargo hook hanging from his belt; on the right a grey-haired captain with a ponytail leans back on a chair "
        "with his boots up on a clerk's writing desk, a flintlock pistol resting in his lap; new pale wooden "
        "partition walls with no door yet, crates of papers, empty new shelves, a square wooden trapdoor in the "
        "floorboards beside the table, a wooden staircase along the right wall rising to the bare joists of an "
        "unfinished upper floor, fresh lumber leaning in a corner, a lantern on the desk",
        "night, warm hearth and lantern light pooling on the floor, deep brown shadows in the corners",
    ),
    "quest|Maskeli İş": (
        "A tall red dragonborn with a smooth red-scaled dragon head, short swept-back horns with thin gold rings "
        "and calm yellow eyes, in an immaculate midnight-blue velvet coat with mother-of-pearl buttons, a starched "
        "white collar and black leather gloves, holding out a plain black cloth mask straight toward the viewer "
        "with a courteous slight bow, standing at the corner of a dark narrow terrace lane at night, behind him "
        "down the lane a stone house wrapped in wooden scaffolding with a sliver of lantern light from its shutter",
        "deep night, cold moonlight on the stone and on the velvet, a warm sliver of lantern light far down the lane",
    ),
    "creature-action|Çengel": (
        "A rusty iron cargo hook swung in a hard arc by a dock labourer's fist, its point catching a sleeve "
        "and tearing it, a lantern knocked over on the cobbles",
        "lantern light from below, warm orange on the iron, cold dark behind",
    ),
    "creature-action|Pala": (
        "A curved cutlass slashing down across a long wooden table, scattering two small white dice and copper "
        "coins into the air, a sailor's tattooed forearm behind the blade",
        "warm hearth light reflected in a bright streak along the steel, coins glinting in the air",
    ),
    "creature-action|Üç Saldırı": (
        "A grey-haired captain in a long coat, his hair tied back, fencing in a rapid flurry with a long thin "
        "rapier, three bright arcs of motion trailing the blade around him, a small crossbow hanging at his belt, "
        "papers flying off a writing desk",
        "lantern light swinging, streaks of warm light along the steel, deep shadow",
    ),
    "creature-action|İnce Kılıç": (
        "A weathered former ship's captain with long grey hair tied back at the nape, lunging forward in a "
        "fencing thrust with a rapier: a very long, very thin blade no wider than a finger, a swept hilt of curved "
        "metal bars around his hand, the needle point coming at the viewer, his long coat flaring behind",
        "a single lantern behind the blade, a bright line of light down the steel",
    ),
    "creature-action|Pistol": (
        "A plain cheap single-shot flintlock pistol, a rough unpolished wooden grip, a short plain iron barrel "
        "with no decoration, held in a weathered hand and aimed at the viewer",
        "lantern light glinting dully on the iron barrel, darkness behind",
    ),
}

VARIANTS = {"a": 0, "b": 7919, "c": 104729}

# Seçim turu: ilk turda tutmayan kartlar (arbalet tüfeğe döndü, kemik zar, maskeli yardımcı) yeni konuyla
# yeniden üretilir: art_jobs_019_fix{a,b,c}.jsonl → out_019fix{a,b,c}.
FIX = ["monster|Bekçibaşı", "quest|Maskeli İş", "creature-action|Pala", "creature-action|Üç Saldırı",
       "creature-action|İnce Kılıç", "creature-action|Pistol"]
FIX_VARIANTS = {"a": 31337, "b": 62674, "c": 94011}
# İkinci tur: Üç Saldırı rapier akınına çevrildi, İnce Kılıç'ta saç ve rapier; arbalet yerine SRD Pistol
# (elymsyr'in kararı), Bekçibaşı ve Pistol tabancayla: art_jobs_019_fix2{a,b,c}.jsonl → out_019fix2{a,b,c}.
FIX2 = ["creature-action|Üç Saldırı", "creature-action|İnce Kılıç", "monster|Bekçibaşı", "creature-action|Pistol"]
FIX2_VARIANTS = {"a": 271828, "b": 314159, "c": 161803}
# Yorum turu (out_019_yorum/picks.json): Kiralık Pala tek düşman, Gece Şantiyesi daha ayrıntılı, yardımcı maskeyi
# bakana uzatıyor, ucuz sade tabanca, ev daha büyük ve etrafı açık: art_jobs_019_r{a,b,c}.jsonl → out_019r{a,b,c}.
YORUM = ["location|Askeri Hukuk Odası", "monster|Kiralık Pala", "encounter|Gece Şantiyesi", "quest|Maskeli İş",
         "creature-action|Pistol"]
YORUM_VARIANTS = {"a": 0, "b": 7919, "c": 104729}
# Yorum 2 (out_019_yorum2/picks.json): Gece Şantiyesi sakin an, üç seed; ev eski seçimden img2img, üç denoise:
# art_jobs_019_y2{a,b,c}.jsonl → out_019y2{a,b,c}.
Y2_VARIANTS = {"a": 1, "b": 2, "c": 3}
Y2_REF = {"location|Askeri Hukuk Odası": "out_aegis/refs/bee4865d-8e7d-5111-a020-f4ff22d76ec7.webp"}
Y2_DENOISE = {"a": 0.5, "b": 0.58, "c": 0.66}


def main() -> None:
    base_jobs = []
    for key, (subject, light) in CARDS.items():
        cat, name = key.split("|", 1)
        job = {"uuid": entity_uuid(cat, name), "category": cat, "name": name}
        P.LIGHT[key] = light
        job["prompt"] = P.build(job, subject)
        job["seed"] = int(job["uuid"][:8], 16)
        base_jobs.append(job)

    (BASE / "art_jobs_019_missing.jsonl").write_text(
        "".join(json.dumps(j, ensure_ascii=False) + "\n" for j in base_jobs), encoding="utf-8")
    for v, off in VARIANTS.items():
        lines = [json.dumps({**j, "seed": (j["seed"] + off) % 2**32}, ensure_ascii=False)
                 for j in base_jobs]
        (BASE / f"art_jobs_019_{v}.jsonl").write_text("\n".join(lines) + "\n", encoding="utf-8")
    for name, keys, variants in (("fix", FIX, FIX_VARIANTS), ("fix2", FIX2, FIX2_VARIANTS),
                                  ("r", YORUM, YORUM_VARIANTS)):
        fix = [j for j in base_jobs if f'{j["category"]}|{j["name"]}' in keys]
        assert len(fix) == len(keys)
        for v, off in variants.items():
            (BASE / f"art_jobs_019_{name}{v}.jsonl").write_text(
                "".join(json.dumps({**j, "seed": (j["seed"] + off) % 2**32}, ensure_ascii=False) + "\n" for j in fix),
                encoding="utf-8")
    for v, off in Y2_VARIANTS.items():
        jobs = []
        for j in base_jobs:
            k = f'{j["category"]}|{j["name"]}'
            if k == "encounter|Gece Şantiyesi":
                jobs.append({**j, "seed": (j["seed"] + off * 4241) % 2**32})
            elif k in Y2_REF:
                jobs.append({**j, "ref": str(BASE / Y2_REF[k]), "denoise": Y2_DENOISE[v]})
        (BASE / f"art_jobs_019_y2{v}.jsonl").write_text(
            "".join(json.dumps(j, ensure_ascii=False) + "\n" for j in jobs), encoding="utf-8")
    print(len(base_jobs), "kart x", len(VARIANTS), "varyant;", len(FIX), "+", len(FIX2), "düzeltme")


if __name__ == "__main__":
    main()
