#!/usr/bin/env python3
"""0.18 turu: blueprint'te görselsiz kalan 10 kart.

Konu + ışık elle yazıldı; prompt aegis_polish.build() ile kurulur (6.1'deki yol).
Her kart için 3 seed varyantı: art_jobs_018_{a,b,c}.jsonl → out_018{a,b,c}.

    python3 aegis_018_missing.py
    python3 aegis_generate.py --jobs art_jobs_018_a.jsonl --out out_018a   # b, c aynı
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import aegis_polish as P  # noqa: E402
from aegis_prompts import entity_uuid  # noqa: E402

BASE = Path(__file__).resolve().parent

# kategori|ad → (konu, ışık)
CARDS = {
    "location|Açık Deniz": (
        "The open sea between two continents seen from the deck of a wooden sailing ship far from any land, "
        "the bow rising over a long grey-green swell, hemp rigging and patched canvas sails straining in the wind, "
        "spray blowing back over the rail, nothing but water and sky to every horizon, "
        "a single gull riding the wind beside the mast",
        "wide open sea light under a high torn cloud sky, sun breaking through in moving patches on the water, "
        "salt haze, cold blue-green shadows in the troughs",
    ),
    "npc|İmzacı — Selvi": (
        "A thin upright human woman in her forties, short dark hair, a reading glass perched on her nose "
        "hanging from a cord around her neck, fingertips permanently stained blue with ink, a shawl over a dark "
        "wool robe and fingerless gloves, seated at a writing desk in a cold stone chamber reading a pass document "
        "line by line with her lips moving, three separate inkwells, a stick of sealing wax and a smooth stone "
        "paperweight on the desk, the quill held ready above an empty line",
        "cold grey window light falling across the desk from one side, an unlit hearth behind her, "
        "breath faintly visible in the chill air",
    ),
    "npc|Hancı — Aysel": (
        "A tiefling innkeeper couple in their fifties behind the scarred oak counter of a smoky riverside tavern: "
        "the wife broad-shouldered and thick-wristed with ash-red skin and short horns curving back from her brow, "
        "greying black hair tied back in a cloth behind the horns, sleeves rolled to the elbow, an ale-stained apron, "
        "wiping the counter with a rag; beside her the husband a head taller, thin and slightly stooped, an ordinary "
        "tired weathered face, dusky ash-grey skin with only a faint muted violet tint, short greying hair, "
        "small dark horns with the tip of the left one broken off, a thin tail curling by his boots, a cask cloth over "
        "his shoulder as he pulls the bung from a wooden cask; behind them a wall covered in columns of chalk tally "
        "marks, and at the end of the counter the top of a narrow stone stair going down into dark",
        "smoky tavern lamplight from hanging clay oil lamps, warm amber on her face, the stairwell beside her "
        "falling into deep shadow",
    ),
    "npc|Mavnacı — Rüstem": (
        "A big sun-darkened human man in his late thirties, a thick black beard threaded with white, rope-callused "
        "hands with an old rope burn scar across the right palm, a sleeveless vest and trousers rolled to the knee, "
        "dried river mud on his bare feet, a bundle of paper weighing tickets tied to his belt with string, "
        "seated at a tavern table counting the tickets one by one with his lips moving, a moored river barge "
        "visible through the open door behind him",
        "late afternoon river light pouring through an open doorway, warm dusty gold on his shoulders, "
        "the tavern interior dim and brown around him",
    ),
    "npc|İğne": (
        "A tiny wiry elderly gnome woman in her sixties, white hair in a tight bun with three or four sewing "
        "needles stuck through it, a pincushion pinned to the chest of her plain dark dress, sharp bright eyes "
        "and no spectacles, threading a needle at a cluttered cellar work table, an ink pot, a pair of iron "
        "shears and stacks of folded clothing around her: a clerk's coat, a sailor's shirt, an apprentice's "
        "kaftan, rough stone cellar walls and wooden casks behind",
        "a single clay oil lamp on the table lighting her hands and face from below, "
        "the cellar falling away into warm brown darkness",
    ),
    "npc|Kaptan — Maren": (
        "A short stocky human woman in her fifties, grey hair in a tight bun at the nape, a face darkened by sun "
        "and salt with deep lines at the corners of the eyes, two fingers of her right hand missing below the "
        "second knuckle, a worn but clean grey wool captain's coat with the corner of a crew list sticking out "
        "of the breast pocket, a pen case and a rope knife on her belt, standing on the deck of a merchant ship "
        "studying the signature on a folded paper, sailors hauling rope behind her",
        "bright windy harbour morning, low sun from the side, crisp shadows across the deck, "
        "white sails glowing behind her",
    ),
    "npc|Şifacı — Iven": (
        "A slender human man in his late twenties, short brown hair stuck to his forehead with sweat, fingertips "
        "and nail beds stained green from herbs, a sleeveless vest woven from pale bamboo fibre and cloth leg "
        "wrappings to the knee, many small leather pouches hanging from his belt, crouched by a small fire "
        "stirring a clay pot of dark syrup while snapping a dried root in his other hand, bundles of herbs drying "
        "on a rack behind him under green forest trees",
        "dappled green forest light from above mixed with the orange glow of the small fire, "
        "drifting smoke catching the light",
    ),
    "npc|Ozan — Tamsin": (
        "A stout round-faced halfling woman in her forties, short curly hair just turning grey with a black raven "
        "feather tucked behind one ear, a long shirt of woven bamboo fibre that looks like linen, a small "
        "stringed instrument made of tree bark held against her chest, mouth open mid-song, standing among "
        "giant ancient standing stones in a forest clearing with listeners seated on the grass around her",
        "warm evening light, the last low sun glowing between the standing stones, long shadows across the grass, "
        "a fire beginning to glow at the edge of the circle",
    ),
    "scene|Kara Göründü": (
        "Sailors crowding the rail of a wooden sailing ship all turned the same way toward a low grey still "
        "shadow of land rising out of the sea on the far horizon, the crew a mix of fantasy folk: a half-orc, "
        "a red-bearded dwarf, a dark-skinned human woman shading her eyes with her hand, an elf, "
        "and one sailor stretching his arm out pointing straight at the land, "
        "a gull circling the mast and flying off toward it, "
        "rope, sail and wet planks filling the foreground",
        "pale cold sea light under a vast overcast sky, a thin band of brighter light along the horizon "
        "behind the grey land, wind-whipped spray",
    ),
    "quest|Ufuktaki Kıta": (
        "A traveller seen from behind standing at the bow of a wooden sailing ship, one hand on the stem post, "
        "a travel bag at their feet, looking out over an endless sea toward a faint far coastline on the horizon, "
        "the ship's wake trailing back toward a white stone harbour city small and fading behind",
        "early morning light low over the sea, a long golden path of sunlight on the water leading toward the "
        "far horizon, cool mist on the distant coast",
    ),
}

VARIANTS = {"a": 0, "b": 7919, "c": 104729}

# Seçim turu yorumları (out_018_choosen/picks.json) — seçilen varyantın seed'iyle yeniden üretilir.
# kart → seçilen görselin seed ofseti (Aysel: önceki turun fixb'si)
FIX = {"scene|Kara Göründü": 0, "npc|Hancı — Aysel": 7919}
# ikinci seçenek: art_jobs_018_fixb.jsonl → out_018fixb
FIX_EXTRA = {"scene|Kara Göründü": 104729, "npc|Hancı — Aysel": 7919}


def main() -> None:
    base_jobs = []
    for key, (subject, light) in CARDS.items():
        cat, name = key.split("|", 1)
        job = {"uuid": entity_uuid(cat, name), "category": cat, "name": name}
        P.LIGHT[key] = light
        job["prompt"] = P.build(job, subject)
        job["seed"] = int(job["uuid"][:8], 16)
        base_jobs.append(job)

    # aegis_pick etiketleri ROOT/art_jobs*.jsonl'den okur
    (BASE / "art_jobs_018_missing.jsonl").write_text(
        "".join(json.dumps(j, ensure_ascii=False) + "\n" for j in base_jobs), encoding="utf-8")
    for v, off in VARIANTS.items():
        lines = [json.dumps({**j, "seed": (j["seed"] + off) % 2**32}, ensure_ascii=False)
                 for j in base_jobs]
        (BASE / f"art_jobs_018_{v}.jsonl").write_text("\n".join(lines) + "\n", encoding="utf-8")
    fix = [{**j, "seed": (j["seed"] + FIX[f'{j["category"]}|{j["name"]}']) % 2**32}
           for j in base_jobs if f'{j["category"]}|{j["name"]}' in FIX]
    assert len(fix) == len(FIX)
    (BASE / "art_jobs_018_fix.jsonl").write_text(
        "".join(json.dumps(j, ensure_ascii=False) + "\n" for j in fix), encoding="utf-8")
    (BASE / "art_jobs_018_fixb.jsonl").write_text(
        "".join(json.dumps({**j, "seed": (j["seed"] + FIX_EXTRA[f'{j["category"]}|{j["name"]}']) % 2**32}, ensure_ascii=False) + "\n"
                for j in fix), encoding="utf-8")
    print(len(base_jobs), "kart x", len(VARIANTS), "varyant;", len(fix), "düzeltme")


if __name__ == "__main__":
    main()
