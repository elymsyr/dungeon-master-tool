#!/usr/bin/env python3
"""Kart arka planları — her kart için ikinci bir görsel.

Kart görseli sahnenin *eli*; BG o sahnenin **boş odası**: bir adım geri
çekilmiş, ana nesnesi kaldırılmış, orta karesi sakin. Üstüne kart metni
basılabilsin diye.

  python3 aegis_bg.py                 # art_bg_jobs.jsonl yaz
  python3 aegis_bg.py --sample 2      # örnek bas
"""
from __future__ import annotations

import argparse, json, re, uuid as _uuid
from pathlib import Path

from aegis_prompts import (
    _NAMESPACE, entity_uuid,
    FULL_BLEED, DND_CONTEXT, AEGIS_PALETTE, AEGIS_STYLE, STYLE_TAIL,
    AEGIS_LIGHT_LAMP, AEGIS_LIGHT_DAY, AEGIS_LIGHT_DAWN, AEGIS_LIGHT_HEARTH,
)

OUT = Path(__file__).resolve().parent / "art_bg_jobs.jsonl"
# ref/<kart adı>.<uzantı> varsa o BG img2img ile referansa sadık üretilir.
REF_DIR = Path(__file__).resolve().parent / "ref"
REF_DENOISE = 0.30


def _refkey(s: str) -> str:
    """Boşluk/tire/kesme farkını yok say — "Lucid Triton" ~ "Lucid-Triton"."""
    return re.sub(r"[^0-9a-zçğıöşü]+", "", s.lower())

LIGHT = {"LAMP": AEGIS_LIGHT_LAMP, "DAY": AEGIS_LIGHT_DAY,
         "DAWN": AEGIS_LIGHT_DAWN, "HEARTH": AEGIS_LIGHT_HEARTH}

# Kart kuyruğundan tek farkı bu: merkez boş, derinlik geniş, kontrast düşük.
BG_CLAUSE = (
    "empty background plate, no central subject, no figure in the middle, "
    "wide establishing depth, quiet uncluttered mid-frame, "
    "soft low-contrast tonal field"
)

# (name, light, bg subject) — ışık kart kategorisinin sabitini ezer.
LORE_BG = [
 ("İrade Çağı", "DAY",
  "An empty white marble plaza after rain, wet flagstones reflecting a flat overcast sky, "
  "the long shadow of an unseen statue falling across the stones from off-frame, "
  "low civic buildings of white stone far back"),
 ("Tanrılar ve Fısıltı", "DAY",
  "The cracked flagstone floor of a roofless chapel, empty stone niches along bare ivy-covered walls, "
  "broken roof beams overhead, shafts of pale daylight and drifting dust, no altar"),
 ("Blight — Bilinen Hali", "DAWN",
  "A narrow village lane between plastered cottage walls, fresh chalk quarantine lines drawn on "
  "several shuttered doors receding into the distance, grey ash dust settled on the packed earth, "
  "cold weak morning light"),
 ("Vorstrand — Bilinen Hali", "DAY",
  "A wide empty grey sea seen over a ship's rail, wet deck planks along the bottom edge, "
  "a low dark strip of unfamiliar coastline half swallowed by fog on the far horizon, "
  "gulls low over the water"),
 ("Konsey ve Lonca Meclisi", "LAMP",
  "The rear wall of a high cold stone hall, five house sigils mounted in a row — a hammer, "
  "a balance scale, a pair of compasses, a sword, a key — and one bare unmarked patch of stone "
  "beside them, empty flagstone floor below"),
 ("Sancak Kaydı", "LAMP",
  "A wall of identical bound ledger spines on tall iron shelving receding into dim lamp-light, "
  "brass shelf labels, one lamp on a bracket, no desk"),
 ("Büyücü Loncası", "DAY",
  "An empty vaulted academy hall, faint residue of a blue chalk teleportation circle worn into the "
  "flagstone floor, tall shelves of bound codices along the walls, high narrow windows throwing "
  "pale light across the stone"),
 ("Sınır ve Ticaret Loncası", "LAMP",
  "The interior of a shuttered border gatehouse, grain dust across a plank floor, folded empty sacks "
  "stacked against the wall, a hanging lantern, a closed customs shutter, no desk"),
 ("Demircilik ve İşçi Loncası", "HEARTH",
  "A soot-dark workshop wall with hanging tongs and hammers in silhouette, a banked forge mouth "
  "glowing low, swept slag and coal dust on the floor, an empty anvil block far to one side"),
 ("Simya ve Şifacılar Loncası", "LAMP",
  "A green-painted apothecary shelf wall, rows of cork-stoppered bottles of cloudy brown and amber "
  "liquid, dried herb bundles hanging above, one oil lamp, an empty wiped counter below"),
 ("Askeri Hukuk Loncası", "DAY",
  "A cold grey stone corridor ending at a heavy barred door, an iron chain and lead seal hanging "
  "unused on a wall hook, flat light from a high slit window, bare worn flagstones"),
 ("Mimarlık ve Planlama Loncası", "DAY",
  "A curtain wall under construction seen through a tall open window, timber scaffolding and hoisting "
  "cranes against a pale sky, chalk and stone dust on the sill, no drafting table"),
 ("İrade Yolu", "DAY",
  "A dusty open crossroads on a dry country road, wind-bent grass, a worn milestone at the verge, "
  "low hills and a wide pale overcast sky, the road empty in both directions"),
 ("Sessiz Mabetler", "LAMP",
  "A narrow damp back alley of close brick walls, washing lines strung overhead, the cobbles wet, "
  "a single faint candle glow in a recess at the far end, no shrine visible"),
 ("Hizmet Basamakları", "DAY",
  "A plain guildhall stairwell, broad stone treads hollowed by boots rising steeply between bare "
  "whitewashed walls, a bright open doorway at the top, no markings on the steps"),
 ("Onur Mahkemeleri", "DAY",
  "An open exile gate in a city wall seen from inside, an empty dirt road running out to flat grey "
  "country beyond, deep shadow under the arch, overcast sky"),
 ("Gümüş Kalkan Nişanı", "DAY",
  "An empty rampart walk along a white limestone curtain wall, worn stone crenellations, a grey bay "
  "and low headland beyond, cold flat daylight, no figures"),
 ("Kuzeyin Gözcüleri", "DAWN",
  "A wind-flattened plateau of coarse grass under thick cold fog, the dim silhouettes of standing "
  "stones at the far edges of the frame, wet ground, no runes lit, no figures"),
 ("Liman Ahdi", "DAWN",
  "The weathered planks and pilings of a crooked wooden pier running out into a still cove, tarred "
  "sheds and a dark cliff face rising behind, a few unflagged boats moored far off, early grey light"),
 ("Kural Sapmaları", "LAMP",
  "Rough dark sailcloth spread over a bare stone table, hardened wax drips and old scorch marks "
  "worked into the weave, a lamp low and off to one side, nothing laid out"),
]

# Location kartları zaten mekân resmi — BG'leri aynı yerin bir adım geri
# çekilmiş, odak yapısı kaldırılmış, ortası sakin hali.
LOCATION_BG = [
 ("Aegis", "DAY",
  "A wide open stretch of grey-blue sea under a tall pale sky, a green headland of white stone "
  "cliffs entering from the left edge with a few tiled roofs among the trees, a dark far coast "
  "under standing fog along the right horizon, empty shipping water between them, long cloud "
  "shadows, no harbour and no ships in the middle of the frame"),
 ("Meridia", "DAY",
  "Snow-dusted pine mountain slopes seen from above, a pale road switchbacking down through the "
  "trees toward open ground, bare granite outcrops and a frozen stream, the white walls of a "
  "distant fortification just visible at the top edge, empty forested middle ground"),
 ("Vorstrand", "DAWN",
  "A cold grey harbour basin at first light, dark stone breakwater arms curving in from both edges, "
  "wet quay stones in the near foreground, bare masts of moored ships clustered far off along the "
  "left wall, drifting fog over flat water, empty open basin in the middle"),
 ("Gümüşsu", "DAY",
  "A clearing floor of packed earth and moss in a deep pine forest, log cabin walls and a woodpile "
  "at the far edges of the frame, thin chimney smoke rising behind the treeline, drying laundry on "
  "a line to one side, dappled green daylight, empty swept ground in the centre"),
 ("Kulübe", "DAWN",
  "A narrow overgrown path through waist-high wet scrub toward dense dark forest, mossy stones and "
  "ferns crowding both sides, a mossy plank wall and a corner of thatch just entering the left "
  "edge, cold grey morning light and low mist between the trunks"),
 ("Goodbarrel'ın Ocak Başı", "HEARTH",
  "The warm interior of a timber-framed tavern, heavy ceiling beams, panelled wall of dark wood, "
  "the orange glow of an unseen hearth washing across the boards from the left, hanging copper pots "
  "and antlers along the wall, empty scrubbed floor in the middle, no table and no figures"),
 ("Gizli Liman", "DAY",
  "A narrow cove of still dark green water walled by towering wet rock faces, weathered carvings "
  "worn into the stone high on one side, a plank walkway and a few tied skiffs hugging the far "
  "edges, a strip of bright sky far above, quiet empty water at centre"),
 ("Rıhtım", "LAMP",
  "Weathered plank decking and rope-wrapped bollards along the near edge of a timber pier, dark "
  "harbour water and moored boats receding to the sides, stilt sheds with lit windows small against "
  "a black cliff face behind, hanging lantern glow on wet wood, empty centre of the deck"),
 ("Lucid Triton", "DAY",
  "A broad white stone boulevard seen down its length, pale flagstones scrubbed clean, rows of "
  "autumn-red and violet trees and tall white civic facades receding on both sides, iron lamp posts, "
  "a soft warm sky at the end of the street, the middle of the avenue empty of people and monuments"),
 ("Mühür Salonu", "LAMP",
  "A long high office hall where tall arched windows begin above head height and show only pale sky, "
  "a wall of wooden pigeonhole racks stuffed with folded papers along the far end, dark panelling and "
  "worn stone floor, warm lamp and low sun light across the boards, no desks and no clerks"),
 ("Meclis Salonu", "LAMP",
  "A round domed council chamber of pale ribbed stone, shallow carved guild sigils spaced around the "
  "curved wall, narrow windows throwing warm light down the ribs, worn stone floor, the seating and "
  "the speaking table removed, empty floor at the centre"),
 ("Karşı-İmza Masası", "LAMP",
  "A narrow stone record room, arched windows along one wall with warm evening light, a tall dark "
  "cabinet and stacked paper bundles pushed against the far corner, a candle stub burning low on a "
  "wall ledge, bare flagstone floor, no desk and no figures"),
 ("Elymsyr", "DAY",
  "A steep fjord channel of pale green water between towering grey cliffs, timber stairways and "
  "landings clinging to the rock on both sides, a lifting crane arm small against the sky at the "
  "top right, open water and empty stone in the middle, cool bright overcast light"),
 ("Votumar", "DAY",
  "An empty courtyard of pale limestone flagstones inside a white curtain wall, crenellated ramparts "
  "and a squat corner tower at the frame edges, bright flat daylight and short hard shadows, a few "
  "iron cannon and stacked shot pushed to the walls, nothing at the centre"),
 ("Gözcü Kuleleri Hattı", "DAWN",
  "A cold windswept ridge of coarse grass and bare rock, a line of squat grey stone watchtowers "
  "receding into thick fog along the crest, unlit beacon baskets on their tops, wet ground and low "
  "cloud, the near ground empty"),
 ("Ravenhall Avlusu", "DAY",
  "A walled rocky courtyard of moss and scattered stone slabs backed by dark pines, weathered "
  "standing markers leaning along the outer edges, a heavy closed timber door set into the rock "
  "face at the back, flat grey overcast light, open empty ground in the middle"),
 ("Cinervik", "DAY",
  "A wide dirt crossroads of a small village, packed earth rutted by cart wheels, half-timbered and "
  "thatched houses lining both sides and falling away behind, a fence and a water trough at the "
  "edge, warm late afternoon light, the crossing itself empty"),
 ("Argenfon", "DAWN",
  "A steep lane of grey slate-roofed stone houses stepping down toward a cold harbour, weathered "
  "walls and shuttered windows crowding both sides, drying nets and an upturned boat at the lower "
  "edge, flat pale morning light, the lane empty end to end"),
]

BG_BY_CATEGORY = {"lore": LORE_BG, "location": LOCATION_BG}


def build(category: str, name: str, light: str, subject: str) -> dict:
    uid = str(_uuid.uuid5(_NAMESPACE, f"bg/{category}/{name}"))
    prompt = (
        f"{name}, Aegis {category} card background\n"
        f"{subject}. "
        f"{BG_CLAUSE}, "
        f"{FULL_BLEED}, "
        f"{DND_CONTEXT}, "
        f"{AEGIS_PALETTE}, "
        f"{LIGHT[light]}, "
        f"{AEGIS_STYLE}, {STYLE_TAIL}"
    )
    ref = next((p for p in sorted(REF_DIR.iterdir())
                if _refkey(p.stem) == _refkey(name)), None) if REF_DIR.is_dir() else None
    return {
        "uuid": uid,
        "card_uuid": entity_uuid(category, name),
        **({"ref": str(ref), "denoise": REF_DENOISE} if ref else {}),
        "category": category,
        "name": name,
        "prompt": prompt,
        "seed": int(uid[:8], 16),
        "source": "handwritten",
    }


def jobs(categories: list[str] | None = None) -> list[dict]:
    out = []
    for cat, rows in BG_BY_CATEGORY.items():
        if categories and cat not in categories:
            continue
        out += [build(cat, *row) for row in rows]
    return out


def main() -> None:
    p = argparse.ArgumentParser(description="Aegis kart arka planı job'ları")
    p.add_argument("--categories", help="virgülle ayrılmış filtre, ör. lore")
    p.add_argument("--sample", type=int, help="sadece N örnek bas, dosya yazma")
    a = p.parse_args()

    rows = jobs(a.categories.split(",") if a.categories else None)
    if a.sample:
        for j in rows[:a.sample]:
            print(f"--- {j['name']} ---\n{j['prompt']}\n")
        return
    OUT.write_text("".join(json.dumps(j, ensure_ascii=False) + "\n" for j in rows), "utf-8")
    print(f"{len(rows)} job -> {OUT}")


if __name__ == "__main__":
    main()
