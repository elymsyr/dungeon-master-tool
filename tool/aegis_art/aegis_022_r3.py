#!/usr/bin/env python3
"""0.22 üçüncü tur (elymsyr'in out_022r_secim yorumları).

Orklar: maymun gibi kıllı değil, LotR orku derisi (yanık, çatlak, yara); renk mor-kahverengi-gri, mor az.
Borda Borda: uzak açı, iki geminin yapısı ve boyu doğru, ayrıntı abartısız.
Gemiler: yalnız tek üretim; katlar aynı boy ve yönde yan yana, kuşbakışı; yelken yalnız güvertede ve sarılı
(Dürüst Terazi üç direk, ötekiler iki); alt katlar gövdenin içi olduğu belli olacak.

    python3 aegis_022_r3.py
    for v in a b; do python3 aegis_generate.py --jobs art_jobs_022r3_$v.jsonl --out out_022r3$v --crop 0; done
    python3 aegis_pick.py --dirs out_022r3_eski,out_022r3a,out_022r3b --outdir out_022r3_secim --key aegis022r3
"""
import json
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import aegis_polish as P  # noqa: E402
from aegis_prompts import entity_uuid  # noqa: E402
import aegis_022_kara_yelken as K  # noqa: E402,F401  (FRAMING ve LIGHT'ı doldurur)

BASE = Path(__file__).resolve().parent
VARIANTS = {"a": 31337, "b": 271828}

LOTR = ("a grotesque misshapen orc like the Uruk-hai and Moria orcs of Peter Jackson's Lord of the Rings films, "
        "humanoid in build")
SKIN = ("coarse leathery hide that is scarred, burned, pitted and peeling, cracked like old bark, mottled dirty "
        "grey, muddy brown and sallow ochre with dull purple-brown bruising, a bald scarred scalp with only a few "
        "lank strands of black hair, a flat broad nose with slit nostrils, a wide lipless mouth of jagged yellow "
        "fangs, long pointed ears")
OOZE = "thick dark purple-black ichor"
ORCS = {
    "monster|Dönüşmüş Ork": (
        # iri ve kaslı yazınca maymuna dönüyor; ince ve sinirli yazınca LotR orku
        "A wiry sinewy transformed orc sailor climbing up out of a square hatch in the wooden deck of a ship, seen "
        "from the waist up, " + LOTR + ": his spine crooked and one shoulder hunched far higher than the other, a "
        "gaunt skull-like lopsided face with the jaw pulled to one side, pale bulging eyes, jagged yellow teeth "
        "with one broken fang, long pointed ears, a bald scarred scalp, grey and muddy brown skin stretched tight "
        "over his bones, cracked like dried mud, burned and bruised dull purple-brown; " + OOZE + " seeping from "
        "a few deep cracks in his shoulder and from the corner of his mouth, a torn sailor's shirt, a black-dyed "
        "crew rag knotted around his neck, a rusted cleaver in one hand",
        "cold grey light from above, black shadow in the hatch below him",
    ),
    "trait|Düşmeyen": (
        "A tall gaunt transformed orc woman beaten down to one knee on a wet ship deck, " + LOTR + ": her limbs "
        "too long and bent at wrong angles, ribs and spine showing through stretched skin, the left side of her "
        "face sagging and swollen, one milky white eye, " + SKIN + "; " + OOZE + " leaking from a broken spear "
        "shaft in her side and running from her eyes like tears, torn canvas trousers and a ragged sailor's vest, "
        "one clawed hand flat on the planks pushing herself back up, still coming",
        "cold grey light, rain and spray on the deck, deep shadow",
    ),
    "creature-action|Ritim": (
        "On the raised stern deck of a black ship a single orc drummer in black leather beats a huge black war "
        "drum; in the foreground a crowd of transformed orcs on the deck below all turn their heads toward the "
        "drum at the same moment, their clawed hands empty and hanging, " + LOTR + " each, every one misshapen "
        "differently: one hugely swollen and hunched, one thin and twisted with one arm far too long, one with a "
        "bulging lopsided skull, one whose face is split by a dark weeping crack; " + SKIN + "; " + OOZE + " "
        "oozing from their cracks, eyes and mouths, torn sailors' clothes",
        "dim overcast light, a cold glow on the drum skin, the crowd below in shadow",
    ),
    "encounter|Borda Borda": (
        "A wide distant view of two sailing ships locked hull to hull on a grey open sea, both ships seen whole "
        "from bow to stern and small in the frame, lots of sea and sky around them: on the left a slightly smaller "
        "two-masted orc warship with a black tarred hull and matte black sails; on the right a slightly larger "
        "three-masted merchant carrack with a honey-brown hull and cream-white sails; grappling chains stretched "
        "across the narrow gap of churning water between them; tiny figures swarming over the rails, dark "
        "misshapen shapes pouring up from a hatch on the black ship; simple painterly forms, accurate ship "
        "construction, restrained detail",
        "stormy overcast light, flying spray, cold grey sea",
    ),
}

MAP = ("Hand-painted top-down fantasy RPG battle map seen from directly overhead, orthographic, realistic painted "
       "textures of real wood grain, tar, rope, canvas and iron, accurate historical sailing ship construction, "
       "objects cast soft shadows, no grid, no text, no labels, no people")
# "sails furled" yetmiyor, model açık yelken çiziyor; sarılı bezi ve çıplak sereni betimlemek gerek.
# Alt katı "geminin içi" diye yazınca güverteye benziyor; "bir kat aşağıdan yatay kesilmiş gövde, fenerli oda" tutuyor.
TOP = ("the open main deck seen from above, {m} bare masts with their yards, the canvas rolled into thin tight "
       "bundles lashed along each yard")
BELOW = ("the same hull cut open horizontally one level further down, a dark lantern-lit wooden room shaped like "
         "the hull, thick dark wooden walls all around, heavy ceiling beams casting shadows across the floor, warm "
         "orange lantern glow in the gloom")
# Gemi: (gövde betimi, direk sayısı, [(kat adı, kat betimi), ...]) — ilk kat güverte
SHIPS = {
    "Kara-Yelken": (
        "a mid-sized black-tarred orc warship, its hull and planks tarred almost black", 2,
        [("Güverte", "a raised stern deck at the bottom with a huge round war drum in front of the tiller, round "
                     "wooden shields hung along both rails, javelin racks, a heavy iron-banded hatch amidships "
                     "just forward of the mainmast, coils of chain with three-pronged grappling hooks at the bow"),
         ("Alt-Kat", "at the stern a cramped captain's cabin with a table covered in papers, a sea chest and a "
                     "cot; amidships barrels, crates and sacks and a pile of plundered shields and a ship's bell; "
                     "at the bow the sealed forward hold walled off by a thick iron-banded plank bulkhead, empty "
                     "inside, dirty straw, deep scratch marks on the boards, dark stains, a ladder up to the "
                     "square hatch")]),
    "Dürüst-Terazi": (
        "a sturdy merchant carrack, slightly larger, honey-brown oiled planks, well kept", 3,
        [("Güverte", "a forecastle at the top with the anchor and capstan, two cargo hatches lashed shut with "
                     "crossed ropes, a ship's boat lashed upside down on deck, coiled ropes, a raised stern deck "
                     "at the bottom with the tiller and a heavy wooden ballista on a swivel mount"),
         ("Ara-Güverte", "at the stern the captain's cabin with a chart table and an unrolled map, a bunk and a "
                         "writing desk; forward of it the guards' bunks with a rack of spears and shields; "
                         "amidships rows of crew hammocks, a small iron galley stove, sea chests, ladders"),
         ("Ambar", "the lowest cargo hold at the bottom of the ship: sacks of spices, stacked crates and water "
                   "barrels lashed in neat rows between the curved ribs of the hull, a little bilge water in the "
                   "bottom, a ladder")]),
    "Caelynn": (
        "a clean, sturdy mid-sized merchant ship with pale scrubbed planks, everything stowed", 2,
        [("Güverte", "neatly coiled ropes, two closed cargo hatches, a compass binnacle and the tiller on the "
                     "raised stern deck, a small captain's cabin roof, buckets and a water cask, all orderly"),
         ("Ambar", "long tidy rows of small lamp-oil barrels lashed in place, neatly stacked crates, and a cleared "
                   "corner near the ladder with bedrolls for passengers")]),
    "Holg": (
        "a small shabby smuggler's ship with weathered grey planks, cluttered and badly kept", 2,
        [("Güverte", "the rail patched in two places, one patch of fresh unpainted pale planks, loose ropes, dice "
                     "and empty bottles, a dented water cask, a crooked hatch, a tiller at the stern"),
         ("Ambar", "rum barrels stacked carelessly, dirty bilge water sloshing between the ribs, loose sacks, a "
                   "few rats, and a damp corner with a filthy blanket where passengers sleep")]),
}
# kare tuvalde üç kat gemiyi yandan/yatay çizdiriyor; biraz daha uzun tuval dikey tutuyor
ONE_SIZE = {2: (1152, 1536), 3: (1344, 1600)}


def ship_prompt(hull, masts, decks):
    n = len(decks)
    pos = ["LEFT", "RIGHT"] if n == 2 else ["LEFT", "MIDDLE", "RIGHT"]
    views = [f"{pos[0]}: {TOP.format(m=masts)}, {decks[0][1]}"]
    views += [f"{pos[i]}: {BELOW}{', the lowest level' if i == 2 else ''}, {d}" for i, (_, d) in enumerate(decks) if i]
    if masts == 3:
        views[0] = views[0].replace("3 bare masts", "three bare masts, foremast, mainmast and mizzenmast,")
    return (f"A {n}-level battle map sheet of {hull}, shown as {n} tall narrow vertical panels side by side, each "
            f"panel a straight-down view of one level, same size, same hull outline, "
            f"all vertical with the bow pointing straight up, each filling the full height of the image. "
            + ". ".join(views) + ". Dark sea-blue background. " + MAP)


def main() -> None:
    base = []
    for key, (subject, light) in ORCS.items():
        cat, name = key.split("|", 1)
        job = {"uuid": entity_uuid(cat, name), "category": cat, "name": name}
        P.LIGHT[key] = light
        job["prompt"] = P.build(job, subject)
        job["seed"] = int(job["uuid"][:8], 16)
        base.append(job)
    for i, (ship, (hull, masts, dks)) in enumerate(SHIPS.items()):
        base.append({"uuid": f"bm-{ship}-tek", "category": "battlemap", "name": f"{ship} — tek üretim",
                     "prompt": ship_prompt(hull, masts, dks), "seed": 22000 + i * 13,
                     "width": ONE_SIZE[len(dks)][0], "height": ONE_SIZE[len(dks)][1]})
    for v, off in VARIANTS.items():
        (BASE / f"art_jobs_022r3_{v}.jsonl").write_text(
            "".join(json.dumps({**j, "seed": (j["seed"] + off) % 2**32}, ensure_ascii=False) + "\n" for j in base),
            encoding="utf-8")
    # seçicide "eski" sütunu: elymsyr'in bir önceki turda seçtikleri (katlar-ayrı olanlar hariç)
    old = BASE / "out_022r3_eski"
    old.mkdir(exist_ok=True)
    for j in base:
        src = BASE / "out_022r_secim" / f"{j['uuid']}.webp"
        if src.exists():
            shutil.copy2(src, old / src.name)
    print(len(base), "job x", len(VARIANTS))


if __name__ == "__main__":
    main()
