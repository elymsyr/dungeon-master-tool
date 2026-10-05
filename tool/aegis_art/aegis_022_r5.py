#!/usr/bin/env python3
"""0.22 beşinci tur (elymsyr'in out_022r4_secim yorumları).

Orklar: bozulma yalnız yuvarlak şişlik ve delik olmasın, vücudun her yerinde farklı olsun. "lump, blister,
sore, wart" gibi sözcükler balon çizdiriyor; yerine yapısal bozulmalar (çökük kafatası, yırtık yanaktan dişler,
deriden çıkan kemik, kaynaşmış parmaklar, eriyip parlamış yanık deri). Referanstaki kabarcıklar da median
filtreyle silinir, model yeniden boyar.
Gemiler: daha büyük gövde; alt katta tavan kirişleri perspektif hatası yapıyordu (raf gibi), yerine döşeme ve
kaburga; renk ve hacim için gölgeli yerleşim ve prompt.

    python3 aegis_022_r5.py
    python3 aegis_generate.py --jobs art_jobs_022r5_ork.jsonl --out out_022r5_ork --crop 0
    python3 aegis_generate.py --jobs art_jobs_022r5_gemi1.jsonl --out out_022r5_gemi1 --crop 0
    python3 aegis_generate.py --jobs art_jobs_022r5_gemi2.jsonl --out out_022r5_gemi2 --crop 0
    # en iyi ikişer tanesi elle out_022r5a/b'ye kopyalanır
    python3 aegis_pick.py --dirs out_022r5_eski,out_022r5a,out_022r5b --outdir out_022r5_secim --key aegis022r5
"""
import json
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
import aegis_polish as P  # noqa: E402
from aegis_prompts import entity_uuid  # noqa: E402
import aegis_022_kara_yelken as K  # noqa: E402,F401  (FRAMING ve LIGHT'ı doldurur)
import aegis_022_r3 as R3  # noqa: E402
import aegis_022_r4 as R4  # noqa: E402

BASE = Path(__file__).resolve().parent
PREV = BASE / "out_022r4_secim"
GUIDES = BASE / "guides_022r5"
ORK_RUNS = [(0, 0.6), (7919, 0.6), (104729, 0.7), (31337, 0.7)]  # (seed kayması, denoise)
SEEDS = 5

# --- orklar --------------------------------------------------------------------------------------
# LotR orkları: asimetrik, yanık, dikişli, kemik ve diş dışarıda; bozulma her yerde başka türlü.
TWISTED = ("each part of the body deformed in a different way: a dented misshapen skull, a crooked jaw too "
           "wide for the face with broken teeth jutting out through a torn cheek, lips rotted away from the "
           "gums, the nose gone leaving two raw slits, a shard of bone pushing out through the skin of the "
           "forearm, fingers fused together and too long with black split nails, ribs and a twisted spine "
           "showing under skin stretched thin as old leather, one patch of skin melted smooth and shiny like "
           "wax from an old burn, long torn gashes crudely stitched shut, hairless, skin colored ashen grey, "
           "dirty ochre and muddy brown")  # "purple" yazınca deri mora dönüyor; mor yalnız sızan sıvıda
ORCS = {
    "monster|Dönüşmüş Ork": (
        PREV / "c2952226-bfac-5845-8147-aa745998bf26.webp",
        "A wiry sinewy transformed orc sailor climbing up out of a square hatch in the wooden deck of a ship, "
        "a grotesque misshapen orc like the Mordor orcs of Peter Jackson's Lord of the Rings films, crooked "
        "spine with one shoulder hunched higher, one arm thinner and longer than the other, one eye sunken "
        "and milky, long pointed ears; " + TWISTED + "; thick dark purple-black ichor seeping from the "
        "stitched gashes and the corner of his mouth, a black-dyed crew rag knotted around his neck, a rusted "
        "cleaver at his belt",
        "cold grey light from above, black shadow in the hatch below him",
    ),
    "creature-action|Ritim": (
        PREV / "7e2c6a98-5663-532d-af60-8c0b6329dc4f.webp",
        "On the deck of a black ship several transformed orcs crowd around a big black war drum and pound it "
        "with heavy drumsticks, all in the same rhythm, mouths open, misshapen orcs like those of Peter "
        "Jackson's Lord of the Rings films, every one deformed differently: one with a caved-in skull and a "
        "jaw hanging crooked, one with a bone shard through the shoulder and an overlong arm, one whose face "
        "is half burned smooth and has no nose, one with teeth jutting through a torn cheek; " + TWISTED +
        "; thick dark purple-black ichor running from their gashes, torn sailors' clothes and leather straps",
        "dim overcast light, a cold glow on the drum skin",
    ),
}


def smooth_ref(src: Path) -> Path:
    """Mor/pembeyi kırar (R4.ashen), sonra küçük yuvarlak kabarcıkları median ile siler; kompozisyon kalır."""
    R4.GUIDES = GUIDES
    out = GUIDES / f"smooth-{src.stem}.png"
    Image.open(R4.ashen(src)).filter(ImageFilter.MedianFilter(9)).save(out)
    return out


# --- gemiler -------------------------------------------------------------------------------------
# hacim ve renk: prompt'ta ışık, gölge ve malzeme rengi; yerleşimde gövde gölgesi
LOOK = ("Richly colored and detailed, every object painted with real volume: highlights on top, soft shadows "
        "cast to the lower right, dark ambient occlusion where things meet the floor and the hull walls, "
        "strictly orthographic with no perspective, the floor flat, walls seen only as their thick top edges, "
        "the hull casting a shadow on the water. ")
SIZE = {"beam": 0.9, "length": 0.97, "ribs": True, "shadow": True}
SHIPS = {s: {**spec, **SIZE} for s, spec in R4.SHIPS.items()}
# kara güvertede demir kapak zeminle aynı tonda kalıp kayboluyordu: daha büyük ve açık demir, daha düşük denoise
SHIPS["Kara-Yelken"].update(iron=(150, 150, 158), hatches=[(0.47, 0.28)], seeds=range(5, 10), denoise=0.64)
SHIPS["Kara-Yelken"]["prompt"] = SHIPS["Kara-Yelken"]["prompt"].replace(
    "RIGHT: the hold one level below, dark and lantern-lit, heavy ceiling beams:",
    "RIGHT: the hold one level below, seen from straight above with the deck removed, dark and lantern-lit, "
    "plank floor and the hull's ribs along the walls:")
SHIPS["Dürüst-Terazi"]["prompt"] = SHIPS["Dürüst-Terazi"]["prompt"].replace(
    "MIDDLE: the deck below, dim and lantern-lit, ceiling beams,",
    "MIDDLE: the deck below, seen from straight above with the deck removed, dim and lantern-lit,")


def main() -> None:
    GUIDES.mkdir(exist_ok=True)
    orks = []
    for key, (ref, subject, light) in ORCS.items():
        cat, name = key.split("|", 1)
        job = {"uuid": entity_uuid(cat, name), "category": cat, "name": name, "ref": str(smooth_ref(ref))}
        P.LIGHT[key] = light
        job["prompt"] = P.build(job, subject)
        seed = int(job["uuid"][:8], 16)
        for k, (off, dn) in enumerate(ORK_RUNS):
            orks.append({**job, "uuid": f"{job['uuid']}-s{k}", "seed": (seed + off) % 2**32, "denoise": dn})
    p1, p2 = [], []
    for i, (ship, spec) in enumerate(SHIPS.items()):
        guide = GUIDES / f"{ship}.png"
        R4.draw_ship(spec).save(guide)
        for k in spec.get("seeds", range(SEEDS)):
            job = {"uuid": f"bm-{ship}-tek-s{k}", "category": "battlemap", "name": f"{ship} — tek üretim",
                   "prompt": spec["prompt"] + LOOK + R3.MAP, "seed": 24000 + i * 17 + k * 7919,
                   "ref": str(guide), "denoise": spec.get("denoise", 0.68), "width": spec["w"], "height": spec["h"]}
            p1.append(job)
            p2.append({**job, "seed": job["seed"] + 5, "denoise": 0.45,
                       "ref": str(BASE / "out_022r5_gemi1" / f"{job['uuid']}.webp")})
    for name, jobs in (("ork", orks), ("gemi1", p1), ("gemi2", p2)):
        (BASE / f"art_jobs_022r5_{name}.jsonl").write_text(
            "".join(json.dumps(j, ensure_ascii=False) + "\n" for j in jobs), encoding="utf-8")
    old = BASE / "out_022r5_eski"
    old.mkdir(exist_ok=True)
    for src in PREV.glob("*.webp"):
        shutil.copy2(src, old / src.name)
    print(len(orks), "ork job +", len(p1), "gemi job x 2 geçiş")


if __name__ == "__main__":
    main()
