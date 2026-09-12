#!/usr/bin/env python3
"""Yorumu olan secilmis kartlar icin duzeltilmis bir job dosyasi yazar.

Tek girdi: `out_choosen/000art_jobs_chosen.jsonl` — secilen 146 gorselin her
biri icin o gorseli URETEN prompt+seed, yaninda `source_dir` ve `comment`.

Yorumsuz kartlara dokunulmaz. Yorumlu olan her kart icin taban, kartin kendi
prompt'udur: cerceveleme / isik / stil kuyrugu aynen korunur, yalnizca prompt'un
1. satiri (SUBJECT) yorumun istedigi kadar degistirilir. Seed de korunur, boylece
begenilen kompozisyonun duzeltilmis hali gelir, bambaska bir resim degil.

    python3 aegis_missing.py --check      # yorum -> yeni konu cumlesi listesi
    python3 aegis_missing.py              # art_jobs_final_missing.jsonl yaz
    python3 aegis_generate.py --jobs art_jobs_final_missing.jsonl --out out_fix
"""
from __future__ import annotations
import argparse, json, sys
from pathlib import Path

BASE = Path(__file__).resolve().parent
CHOSEN = BASE / "out_choosen" / "000art_jobs_chosen.jsonl"
OUT = BASE / "art_jobs_final_missing.jsonl"

# ---------------------------------------------------------------------------
# Duzeltilmis konu cumleleri — anahtar "kategori|ad"
#
# Kanon dayanagi (flutter_app/assets/worlds/aegis/lore/canon):
#   - drake = KANATSIZ ejderha, `beast`, hicbir seviyede ucus yok  (alt-siniflar.md §2.2-2.3)
#   - Fare · Alton · Merla · Milo = halfling                        (act1.md §7.4, bolgeler.md)
#   - Kromanna = tiefling, blight onu erken guclendiriyor           (npc/Kromanna)
#   - Donusmus = humanoid, "tanidik bir yuz, tanidik bir giysi"     (monster/Donusmus)
#   - Kayit Ruhu = Clockwork Soul, Mechanus carki — ruh degil       (subclass/Clockwork Soul)
#   - Kuzeyin Gozculeri = druid kabilesi                            (lore/Kuzeyin Gozculeri)
# ---------------------------------------------------------------------------
SUBJECT: dict[str, str] = {
    # "kanatsiz ejderha dedik bildigin timsah cizdi" — gecen turda "crocodile-bodied"
    # yazmistik, model de tam onu cizdi. Bu turda hayvan yine ACIKCA ejderha:
    # boynuz, ceneden geriye frill, disari tasan disler, uzun bacakli derin gogus
    # (timsahin hicbirinde yok) — ve kanadin gelecegi sirt bastan sona kemik
    # dikenlerle dolu. "wingless dragon / wyrm" ikilisi caption uzayinda kanatsiz
    # govdeye baglaniyor; cfg=1'de olumsuzlama okunmadigi icin tarif POZITIF.
    "trait|Bağıt Yoldaşı":
        "A ranger with one arm outstretched as a wingless dragon arrives in a spray of stone dust on the "
        "empty ground before them, a wyrm the size of a big hound with a long narrow draconic head, a ridged "
        "bony brow and two horns swept back from the skull, a spined frill behind the jaw, slit amber eyes and "
        "fangs showing outside the lip, its deep narrow chest carried high on four long clawed legs, a row of "
        "bony spines running from the base of the skull down the whole length of its back to the tail tip, "
        "olive-green scale over shoulders and flanks with no wings and nothing folded on its back, the runes on "
        "a nearby standing stone lit faintly along the same line, wind-bent plateau grass and fog behind",

    "subclass|Pul Bağıtlısı":
        "A human ranger with a weathered bearded human face and a fur-trimmed leather coat kneeling with one "
        "palm on a rune-carved standing stone, a wingless dragon the size of a big dog pressed against his knee "
        "— a wyrm with a long narrow draconic head, a ridged bony brow and two horns swept back from the skull, "
        "a spined frill behind the jaw, fangs showing outside the lip, a deep narrow chest on four long clawed "
        "legs and a row of bony spines running from the base of the skull all the way down its back to the tail "
        "tip, its scaled shoulders and flanks bare with no wings and nothing folded on its back — its neck "
        "glands swollen, a hunting bow across the man's back, fresh stone dust in the rune grooves, a fog-bound "
        "plateau of standing stones behind",

    "creature-action|Isırık":
        "A wingless dragon seen very close, its head neck and shoulders filling the frame as its jaws lock onto "
        "an armoured forearm, a wyrm with a long narrow draconic head, a ridged bony brow and two horns swept "
        "back from the skull, a spined frill behind the jaw, slit amber eyes and small conical teeth sunk deep, "
        "the head twisting hard for the pull, a row of bony spines running back from the base of the skull over "
        "scaled shoulders that carry no wings and nothing folded on them, neck glands swollen hard, acid smoking "
        "where it drips from the jaw, wet rock and bent grass just below",

    "trait|Pul ve Diş":
        "A grown wingless dragon the size of a pony hooked high on a rock face with its claws driven into the "
        "stone, a wyrm with a long narrow draconic head, a ridged bony brow and two horns swept back from the "
        "skull, a spined frill behind the jaw and fangs showing outside the lip, a deep chest and long powerful "
        "clawed legs spread flat against the rock, a row of bony spines running from the base of the skull down "
        "its back to the thick tail counterbalancing out over the drop, a strapped saddle blanket buckled over "
        "that spined back with no wings and nothing else on it, the head turned back over the shoulder, a "
        "fog-filled plateau gorge far below",

    # "sadece ejderha kafasi gozuksun vucudu kanat falan tam gozukmesin, agzindan
    # asit puskursun" — kadraji kafa+boyuna kadar daralttik: kanadin girecegi yer
    # kalmiyor. Kuyruktaki "smoking blade" de kilici geri cagiriyordu, TAIL_FIX'te.
    "creature-action|Salgılı Vuruş":
        "An extreme close-up of a wingless dragon's head and neck filling the whole frame, jaws open wide "
        "spitting a thin arc of viscous acid, a long narrow draconic head with a ridged bony brow, two horns "
        "swept back from the skull, a spined frill behind the jaw, slit amber eyes and fangs showing outside the "
        "lip, swollen glands along the throat, the body cropped away entirely below the shoulder, an armoured "
        "figure small and out of focus at the edge of the frame recoiling as the acid lands smoking on the "
        "breastplate, fog-bound plateau rock behind",

    # "saci basi biraz daha dagimik, yuzu daha puruzlu ve kirli"
    "npc|Fare":
        "A barefoot halfling girl of fourteen, stocky and thick-armed from hauling crates, her face smeared "
        "thick with black soot and harbour filth in uneven streaks, skin rough and pitted and shining with "
        "grime, dirt caked under torn fingernails, a scabbed scar through one eyebrow, a badly crooked broken "
        "nose and one front tooth snapped off, heavy uneven features and a wide chapped cracked mouth, black "
        "hair hacked short with a knife and standing out in wild greasy matted tufts falling over her eyes, "
        "wearing a stained sailor's shirt three sizes too large with the sleeves rolled many times and "
        "grease-blackened trousers cut off at the calf, a string-tied purse and a wooden whistle at her waist, "
        "sitting on a barrel on a wooden jetty swinging her legs while two dockhands passing behind grin and "
        "wave at her, moored boats behind",

    # "catilar daha renkli olabilir, ara ara tahta ev de olsun, genel beyaz mimariyi
    # koru" — govde yine beyaz mermer, renk catilarda ve arada bir ahsap evde.
    "location|Lucid Triton":
        "A vast white marble capital seen from a high terrace in the late afternoon, hand-cut stone everywhere "
        "and nothing taller than three storeys, the roofs above the narrow stepped lanes tiled in many colours — "
        "terracotta red, deep blue, moss green, ochre and dark copper patched side by side over the white "
        "facades — and here and there among the marble a timber-framed house with dark beams, plastered walls "
        "and wooden shutters, carved cornices above the lanes, broad avenues lined with crimson orange and "
        "violet leaved trees running between the marble facades, ox carts and handcarts on the flagstones, "
        "cloth awnings and clerks' stalls along the arcades, a great square holding a colossal stone statue of "
        "an architect on its plinth, a quiet crowd of small figures queuing at doors with papers and folios in "
        "their hands, lamplighters starting their round with poles and oil lanterns, the city wall and open "
        "plains beyond, the low sun setting the marble glowing pink and gold",
}


# Kuyrukta konuyu geri cagiran parcalar (yalnizca gerektiginde).
TAIL_FIX: dict[str, tuple[str, str]] = {
    # kuyruktaki "drake" kelimesi kanatli sablonu ceken tek kalinti.
    "trait|Pul ve Diş": (
        "the drake lit hard from above",
        "the animal lit hard from above",
    ),
    # "hala kilici var" sorununun kaynagi: kuyrukta kilic yaziyordu.
    "creature-action|Salgılı Vuruş": (
        "the smoking blade the brightest thing in frame",
        "the smoking acid the brightest thing in frame",
    ),
}


def main() -> None:
    p = argparse.ArgumentParser(description="yorumlu kartlar -> duzeltilmis job dosyasi")
    p.add_argument("--check", action="store_true", help="dogrula ve listele, dosyaya yazma")
    p.add_argument("--chosen", type=Path, default=CHOSEN)
    p.add_argument("--out", type=Path, default=OUT)
    a = p.parse_args()

    rows, seen = [], set()
    for line in a.chosen.read_text().splitlines():
        if not line.strip():
            continue
        job = json.loads(line)
        comment = job.get("comment", "").strip()
        if not comment:
            continue
        key = f'{job["category"]}|{job["name"]}'
        seen.add(key)
        if key not in SUBJECT:
            print(f"HATA: yorumlu ama duzeltmesi yazilmamis kart: {key}", file=sys.stderr)
            sys.exit(1)

        _, tail = job["prompt"].split("\n", 1)
        if key in TAIL_FIX:
            src, dst = TAIL_FIX[key]
            if src not in tail:
                print(f"HATA: TAIL_FIX parcasi bulunamadi: {key}", file=sys.stderr)
                sys.exit(1)
            tail = tail.replace(src, dst)
        job["prompt"] = SUBJECT[key] + "\n" + tail
        job["source"] = "comment-fix"
        rows.append(job)
        if a.check:
            print(f"### {key}  [{job.get('source_dir', '?')}]\n{comment}\n"
                  f"-> {SUBJECT[key]}\n", file=sys.stderr)

    if extra := set(SUBJECT) - seen:
        print("HATA: karsiligi olmayan anahtar(lar): " + ", ".join(sorted(extra)), file=sys.stderr)
        sys.exit(1)

    print(f"{len(rows)} yorumlu kart", file=sys.stderr)
    if not a.check:
        a.out.write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in rows))
        print(f"-> {a.out}", file=sys.stderr)


if __name__ == "__main__":
    main()
