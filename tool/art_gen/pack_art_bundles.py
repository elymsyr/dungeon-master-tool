#!/usr/bin/env python3
"""Paket başına tek bir art zip'i üretip R2 catalog'una yükler.

  GET {worker}/catalog/art-bundle/{slug}@{version}.zip  → public

Neden: kurulumda görselleri tek tek çekmek 1000+ istek demek ve worker'ın
public catalog rate limit'ini (300/dk/IP) aşıyor; kalanlar sessizce 429 yiyip
düşüyordu. Zip tek istek. İstemci zip yoksa tek tek indirmeye düşer, yani bu
script'i çalıştırmamak bozmaz — sadece yavaşlatır.

App bundle'ında zaten olan SRD görselleri zip'e girmez (`assets/art/srd/`) —
build_catalog'un `art_bytes` sayımıyla aynı kural.

Yükleme worker'ın PUT route'u yerine doğrudan `wrangler r2 object put` ile
yapılır: en büyük zip 100 MB'ı aşıyor, Worker istek gövdesi limiti aşmıyor.

  python3 tool/art_gen/pack_art_bundles.py [--dry-run] [--only slug]
"""
import argparse, json, subprocess, sys, zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
APP = ROOT.parent.parent / "flutter_app"
PACKS = APP / "assets" / "open5e_packs"
BUNDLED = APP / "assets" / "art" / "srd"
ART_PREFIX = "dmt-art://"


def art_names(payload: dict) -> list[str]:
    out = []
    for row in payload.get("entities", {}).values():
        ref = str(row.get("image_path") or "")
        if ref.startswith(ART_PREFIX):
            out.append(ref[len(ART_PREFIX):])
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--packs", type=Path, default=PACKS)
    ap.add_argument("--src", type=Path, default=ROOT / "out")
    ap.add_argument("--out", type=Path, default=ROOT / "bundles")
    ap.add_argument("--only")
    ap.add_argument("--bucket", default="dmt-assets")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()

    a.out.mkdir(parents=True, exist_ok=True)
    for f in sorted(a.packs.glob("*.pkg.json")):
        payload = json.loads(f.read_text())
        meta = payload.get("metadata") or {}
        slug = meta.get("package_name") or f.name[: -len(".pkg.json")]
        if a.only and slug != a.only:
            continue
        version = meta.get("pack_version") or "1.0.0"
        # Bundle'dakiler zip'e girmez; istemci onları asset'ten okur.
        names = [n for n in art_names(payload) if not (BUNDLED / n).exists()]
        if not names:
            continue

        key = f"art-bundle/{slug}@{version}.zip"
        zpath = a.out / f"{slug}@{version}.zip"
        missing = 0
        # webp zaten sıkıştırılmış — ZIP_STORED, tekrar deflate boşuna CPU.
        with zipfile.ZipFile(zpath, "w", zipfile.ZIP_STORED) as z:
            for n in names:
                src = a.src / n
                if not src.exists():
                    missing += 1
                    continue
                z.write(src, arcname=n)
        if missing == len(names):
            # Tek görsel bile yoksa boş zip yüklemenin anlamı yok — kurulumda
            # 404 ile aynı sonucu verir, sadece sessizce.
            print(f"{slug}@{version}: atlandi ({missing} gorsel out/ icinde yok)")
            zpath.unlink(missing_ok=True)
            continue
        size = zpath.stat().st_size
        print(f"{slug}@{version}: {len(names) - missing} görsel, "
              f"{size / 1e6:.1f} MB{f', {missing} eksik' if missing else ''}")
        if a.dry_run:
            continue

        r = subprocess.run([
            "npx", "wrangler", "r2", "object", "put",
            f"{a.bucket}/catalog/{key}", "--file", str(zpath),
            "--content-type", "application/zip", "--remote",
        ])
        if r.returncode != 0:
            sys.exit(f"upload failed {key}")
        print(f"  → {key}")


if __name__ == "__main__":
    main()
