#!/usr/bin/env python3
"""`assets/open5e_packs/*.pkg.json` entity'lerine `dmt-art://` ref'i basar.

`art_jobs.jsonl`'deki her uuid için, o uuid'yi taşıyan pack entity'sinin
`image_path` alanı `dmt-art://{uuid}.webp` yapılır. Görselin bundle'da mı R2'de
mi olduğu ref'e girmez — çözümü `FirstPartyArtService` yapar.

Dolu bir `image_path` asla ezilmez (elle konmuş bir görsel kaybolmasın).

  python3 tool/art_gen/stamp_art_refs.py [--check]

`--check` hiçbir şey yazmaz, eksik/uyumsuz ref sayısını basar ve fark varsa
non-zero döner (CI için).
"""
import argparse, json, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PACKS = ROOT.parent.parent / "flutter_app" / "assets" / "open5e_packs"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--jobs", type=Path, default=ROOT / "art_jobs.jsonl")
    ap.add_argument("--packs", type=Path, default=PACKS)
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()

    arted = {
        json.loads(l)["uuid"]
        for l in a.jobs.read_text().splitlines()
        if l.strip()
    }
    stamped = already = kept = 0
    unmatched = set(arted)
    for f in sorted(a.packs.glob("*.pkg.json")):
        raw = f.read_text()
        data = json.loads(raw)
        # build_packs compact yazar, cairn/srd dump'ları girintili — dosyanın
        # kendi biçimini koru, yoksa tek satırlık ref eklemesi tüm dosyayı
        # yeniden biçimlendirip devasa bir diff çıkarıyor.
        indent = 2 if "\n" in raw else None
        changed = 0
        for uuid, row in data.get("entities", {}).items():
            unmatched.discard(uuid)
            if uuid not in arted:
                continue
            want = f"dmt-art://{uuid}.webp"
            cur = row.get("image_path") or ""
            if cur == want:
                already += 1
            elif cur:
                kept += 1  # elle konmuş görsel — dokunma
            else:
                row["image_path"] = want
                changed += 1
        stamped += changed
        if changed and not a.check:
            f.write_text(json.dumps(
                data,
                ensure_ascii=False,
                indent=indent,
                separators=None if indent else (",", ":"),
            ))
        print(f"{f.name:36} +{changed}")

    print(f"\n{stamped} basıldı, {already} zaten doğru, {kept} elle konmuş "
          f"(korundu), {len(unmatched)} görselin pack karşılığı yok")
    if a.check and stamped:
        sys.exit(1)


if __name__ == "__main__":
    main()
