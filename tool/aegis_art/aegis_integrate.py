#!/usr/bin/env python3
"""out_artwork_choosen/{uuid}.webp → aegis-act1/media/Artwork/ kopyala + blueprint + manifest güncelle.

Kullanım:
    python3 aegis_integrate.py                # kuru çalıştır (değişiklik yok)
    python3 aegis_integrate.py --apply        # uygula
    python3 aegis_integrate.py --apply --check # uygula + dart --check çalıştır
"""
import argparse, json, re, shutil, subprocess, sys
from pathlib import Path

BASE = Path(__file__).resolve().parent
REPO = BASE.parent.parent
JOBS_FILE = BASE / "out_artwork_choosen" / "000out_choosen-art_jobs_chosen.jsonl"
# Secilen gorseller — art_jobs_final.jsonl'in ham ciktisi (out/) degil.
OUT_DIR = BASE / "out_artwork_choosen"
BP_DIR = REPO / "flutter_app" / "assets" / "worlds" / "aegis" / "aegis-act1"
BP_FILE = BP_DIR / "world-blueprint.json"
MANIFEST_FILE = BP_DIR / "manifest.json"
MEDIA_DIR = BP_DIR / "media" / "Artwork"


def sanitize(name: str) -> str:
    """Dosya adı için güvenli hale getir."""
    s = name
    s = s.replace("—", "-").replace("–", "-").replace("·", "-")
    s = s.replace("'", "").replace("'", "").replace("'", "")
    s = s.replace('"', "").replace('"', "").replace('"', "")
    s = re.sub(r"\s+", "-", s)
    s = re.sub(r"[^a-zA-Z0-9ığüşöçİĞÜŞÖÇ\-]", "", s, flags=re.UNICODE)
    s = re.sub(r"-{2,}", "-", s)
    return s.strip("-") or "unknown"


def load_jobs() -> list[dict]:
    return [json.loads(l) for l in JOBS_FILE.read_text().splitlines() if l.strip()]


def load_blueprint() -> dict:
    return json.load(open(BP_FILE))


def load_manifest() -> dict:
    return json.load(open(MANIFEST_FILE))


def main() -> None:
    p = argparse.ArgumentParser(description="Aegis artwork entegrasyonu")
    p.add_argument("--apply", action="store_true", help="Değişiklikleri uygula")
    p.add_argument("--check", action="store_true",
                   help="Uygulamadan sonra dart --check çalıştır")
    args = p.parse_args()

    dry = not args.apply
    if dry:
        print("=== KURU ÇALIŞTIRMA (--apply olmadan) ===\n", file=sys.stderr)

    jobs = load_jobs()
    bp = load_blueprint()
    manifest = load_manifest()

    # UUID → job eşleştirmesi
    job_by_uuid = {j["uuid"]: j for j in jobs}

    # out/ içindeki mevcut dosyalar
    existing = {p.stem: p for p in OUT_DIR.glob("*.webp")}

    # blueprint'te source_name → (category, index) haritası
    bp_index: dict[str, dict[str, int]] = {}
    for cat, items in bp.get("categories", {}).items():
        for i, entity in enumerate(items):
            name = entity["source_name"]
            bp_index.setdefault(name, {})[cat] = i

    # Birden fazla kategoride geçen job adları — dosya adına kategori öneki alırlar.
    # Blueprint'ten değil JOB'lardan sayılır: blueprint'te kart adı değişirse
    # (Refleks Direnci → Reflexive Resistance) önek düşer ve iki kategorinin
    # görseli aynı dosyaya yazılırdı.
    dupe_names = {n for n in (j["name"] for j in jobs)
                  if sum(1 for j in jobs if j["name"] == n) > 1}

    # Eşleştir ve kopyala
    copied, skipped, missing_bp = 0, 0, []
    file_list: list[str] = []

    for uuid, job in job_by_uuid.items():
        if uuid not in existing:
            continue

        name = job["name"]
        cat = job["category"]
        src = existing[uuid]
        fname = sanitize(name) + ".webp"

        # Aynı isim farklı kategori varsa kategori öneki ekle
        if name in dupe_names:
            fname = sanitize(f"{cat}-{name}") + ".webp"

        dst = MEDIA_DIR / fname
        rel_path = f"media/Artwork/{fname}"
        file_list.append(rel_path)

        # Blueprint'te imagePath ekle
        if name in bp_index and cat in bp_index[name]:
            idx = bp_index[name][cat]
            entity = bp["categories"][cat][idx]
            mapping = entity.get("mapping", {})
            if "imagePath" not in mapping:
                if not dry:
                    mapping["imagePath"] = rel_path
                    entity["mapping"] = mapping
                print(f"  imagePath: {cat}/{name} → {rel_path}")
            else:
                print(f"  SKIP (zaten imagePath var): {cat}/{name}")
        else:
            missing_bp.append(f"{cat}/{name}")

        if not dry:
            MEDIA_DIR.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
        copied += 1

    # Manifest'i güncelle
    artwork_key = sorted(file_list)
    old_files = manifest.get("files", {})
    old_media = old_files.get("media", {})
    old_artwork = old_media.get("artwork", [])

    if old_artwork != artwork_key:
        if not dry:
            old_media["artwork"] = artwork_key
            old_files["media"] = old_media
            manifest["files"] = old_files
        print(f"\n  manifest.json artwork listesi: {len(artwork_key)} dosya")
    else:
        print(f"\n  manifest.json artwork listesi zaten güncel ({len(artwork_key)} dosya)")

    # Kaydet
    if not dry:
        with open(BP_FILE, "w", encoding="utf-8") as f:
            json.dump(bp, f, ensure_ascii=False, indent=2)
            f.write("\n")
        with open(MANIFEST_FILE, "w", encoding="utf-8") as f:
            json.dump(manifest, f, ensure_ascii=False, indent=2)
            f.write("\n")

    # Özet
    print(f"\n{'='*50}")
    print(f"  Kopyalanan: {copied}")
    print(f"  Blueprint'te bulunamayan: {len(missing_bp)}")
    if missing_bp:
        for m in missing_bp:
            print(f"    - {m}")
    if dry:
        print(f"\n  Uygulamak için: python3 {Path(__file__).name} --apply")

    # --check
    if args.check and not dry:
        print(f"\n  convert_blueprint --check çalıştırılıyor...")
        result = subprocess.run(
            ["dart", "run", "tool/content/convert_blueprint.dart",
             "--dir", "assets/worlds/aegis/aegis-act1", "--check"],
            cwd=REPO / "flutter_app",
            capture_output=True, text=True,
        )
        print(result.stdout)
        if result.stderr:
            print(result.stderr, file=sys.stderr)
        sys.exit(result.returncode)


if __name__ == "__main__":
    main()
