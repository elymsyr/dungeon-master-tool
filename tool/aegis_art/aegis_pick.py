#!/usr/bin/env python3
"""Aegis art seçici: out* klasörlerindeki aynı isimli resimleri altalta gösterir,
birini seçip yorum eklersin. Seçimler tarayıcıda tutulur; en alttaki tek Kaydet
butonu hepsini verdiğin klasöre kopyalar ve picks.json yazar.

Kullanım:  python3 aegis_pick.py   ->  http://127.0.0.1:8765
"""
import argparse, json, shutil, webbrowser
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).parent

_ap = argparse.ArgumentParser(description="Aegis art secici")
_ap.add_argument("--outdir", default="out_final", help="hedef klasor (footer'da onerilen)")
_ap.add_argument("--missing-from", metavar="KLASOR",
                 help="yalnizca bu klasorde karsiligi OLMAYAN kartlari goster")
_ap.add_argument("--only-in", metavar="KLASOR",
                 help="yalnizca bu klasorde karsiligi OLAN kartlari goster")
_ap.add_argument("--dirs", metavar="A,B",
                 help="kaynak klasorleri elle ver (panel sirasi yazdigin sira); "
                      "verilmezse butun out* klasorleri")
_ap.add_argument("--key", default="aegis",
                 help="localStorage anahtar oneki — ayri tur icin ayri anahtar ver, "
                      "boylece onceki turun secimleri ve yorumlari bozulmaz")
_ap.add_argument("--port", type=int, default=8765)
ARGS = _ap.parse_args()

def _dir(name: str) -> Path:
    d = ROOT / name
    if not d.is_dir():
        raise SystemExit(f"HATA: klasor yok: {d}")
    return d


if ARGS.dirs:
    # Elle verilen sira panel sirasidir.
    DIRS = [_dir(n.strip()) for n in ARGS.dirs.split(",") if n.strip()]
else:
    # Hedef ve referans klasorler kaynak olarak gosterilmez: zaten secilmis
    # kopyalar, fazladan panel olarak cikip karistirmasin.
    _HIDE = {ARGS.outdir, ARGS.missing_from, ARGS.only_in}
    DIRS = sorted(d for d in ROOT.iterdir()
                  if d.is_dir() and d.name.startswith("out") and d.name not in _HIDE)

# --missing-from: o klasorde .webp'si olan kartlar listeden dusulur.
# --only-in:     yalnizca o klasorde .webp'si OLAN kartlar kalir.
SKIP_FILES: set[str] = set()
KEEP_FILES: set[str] | None = None
if ARGS.missing_from:
    SKIP_FILES = {f.name for f in _dir(ARGS.missing_from).iterdir() if f.is_file()}
if ARGS.only_in:
    KEEP_FILES = {f.name for f in _dir(ARGS.only_in).iterdir() if f.is_file()}

IMG_EXT = {".webp", ".png", ".jpg", ".jpeg"}

NAMES = {}
for jl in ROOT.glob("art_jobs*.jsonl"):
    for line in jl.read_text().splitlines():
        try:
            j = json.loads(line)
            NAMES.setdefault(j["uuid"], f'{j.get("category","?")} / {j.get("name","?")}')
        except Exception:
            pass


def items():
    groups = {}
    for d in DIRS:
        for f in d.iterdir():
            if f.is_file() and f.suffix.lower() in IMG_EXT:
                groups.setdefault(f.name, []).append(d.name)
    return [
        {"file": n, "label": NAMES.get(Path(n).stem, Path(n).stem), "dirs": sorted(ds)}
        for n, ds in sorted(groups.items())
        if n not in SKIP_FILES and (KEEP_FILES is None or n in KEEP_FILES)
    ]


HTML = """<!doctype html><meta charset=utf-8><title>Aegis art sec</title>
<style>
body{font:14px system-ui;margin:0;background:#111;color:#eee;padding-bottom:70px}
header,footer{position:fixed;left:0;right:0;background:#1b1b1b;padding:10px 16px;display:flex;gap:10px;align-items:center;flex-wrap:wrap;z-index:2}
header{top:0;border-bottom:1px solid #333}
footer{bottom:0;border-top:1px solid #333}
input{flex:1;min-width:160px;padding:8px;background:#222;color:#eee;border:1px solid #444;border-radius:6px}
button{padding:8px 14px;border:0;border-radius:6px;background:#444;color:#fff;cursor:pointer}
button.go{background:#3a6}
.imgs{display:flex;flex-direction:column;gap:12px;padding:64px 16px 16px;align-items:center}
figure{margin:0;border:3px solid transparent;border-radius:10px;cursor:pointer;max-width:min(90vw,760px)}
figure.sel{border-color:#3a6}
figure img{width:100%;display:block;border-radius:7px}
figcaption{padding:4px 8px;color:#aaa}
#stat{color:#3a6}
</style>
<header>
  <button onclick=go(-1)>&larr; Onceki</button>
  <b id=title></b><span id=pos></span>
  <input id=c placeholder="yorum (opsiyonel)">
  <button class=go onclick=go(1)>Sonraki &rarr;</button>
</header>
<div class=imgs id=v></div>
<footer>
  <span id=stat></span>
  <input id=outdir placeholder="hedef klasor adi" value="__OUTDIR__">
  <button class=go onclick=saveAll()>Tumunu kaydet</button>
</footer>
<script>
const K='__KEY__';
let L=[],i=+(localStorage[K+'Idx']||0),S=JSON.parse(localStorage[K+'Picks']||'{}');
fetch('/api/items').then(r=>r.json()).then(d=>{L=d;i=Math.min(i,L.length-1);draw()});
function cur(){return S[L[i].file]||{}}
function draw(){const it=L[i];if(!it)return;
 title.textContent=it.label;pos.textContent=` (${i+1}/${L.length})`;
 c.value=cur().comment||'';
 v.innerHTML=it.dirs.map((d,n)=>`<figure onclick=pick('${d}') id=f${n}><img src="/img/${d}/${it.file}"><figcaption>${n+1}. ${d}</figcaption></figure>`).join('');
 if(it.dirs.length==1&&!cur().dir)pick(it.dirs[0]);else mark();
 stat.textContent=Object.keys(S).length+' secili';scrollTo(0,0)}
function pick(d){S[L[i].file]={dir:d,label:L[i].label,comment:c.value};flush();mark()}
function mark(){const d=cur().dir;[...v.children].forEach((f,n)=>f.classList.toggle('sel',L[i].dirs[n]==d))}
function flush(){const e=S[L[i].file];if(e)e.comment=c.value;localStorage[K+'Picks']=JSON.stringify(S);
 stat.textContent=Object.keys(S).length+' secili'}
function go(n){flush();i=Math.min(L.length-1,Math.max(0,i+n));localStorage[K+'Idx']=i;draw()}
c.oninput=flush;
function saveAll(){flush();
 const picks=Object.entries(S).map(([file,e])=>({file,...e}));
 if(!picks.length)return alert('secim yok');
 fetch('/api/save',{method:'POST',body:JSON.stringify({outdir:outdir.value,picks})})
  .then(r=>r.json()).then(r=>alert(r.copied+' resim -> '+r.outdir));}
document.onkeydown=e=>{if(document.activeElement==c){if(e.key=='Enter')go(1);return}
 const it=L[i];if(e.key>='1'&&e.key<='9'&&it.dirs[e.key-1])pick(it.dirs[e.key-1]);
 if(e.key=='ArrowRight')go(1);if(e.key=='ArrowLeft')go(-1)};
</script>"""


class H(BaseHTTPRequestHandler):
    def _send(self, body, ctype="application/json"):
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        p = unquote(self.path)
        if p == "/":
            return self._send(HTML.encode(), "text/html; charset=utf-8")
        if p == "/api/items":
            return self._send(json.dumps(items()).encode())
        if p.startswith("/img/"):
            f = (ROOT / p[5:]).resolve()
            if ROOT in f.parents and f.is_file():
                return self._send(f.read_bytes(), "image/webp")
        self.send_error(404)

    def do_POST(self):
        d = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        out = ROOT / (d.get("outdir") or "out_final").strip().replace("/", "_")
        out.mkdir(parents=True, exist_ok=True)
        n = 0
        srcdirs = set()
        rec = []
        for e in d["picks"]:
            src = ROOT / e["dir"] / e["file"]
            ok = src.is_file()
            if ok:
                shutil.copy2(src, out / e["file"])
                n += 1
                srcdirs.add(e["dir"])
            rec.append({"file": e["file"], "from": e["dir"], "label": e.get("label", ""),
                        "comment": e.get("comment", ""), "copied": ok})
        (out / "picks.json").write_text(
            json.dumps({"outdir": out.name, "count": n, "picks": rec},
                       ensure_ascii=False, indent=2), encoding="utf-8")
        for dname in sorted(srcdirs):
            for jl in (ROOT / dname).glob("000*"):
                shutil.copy2(jl, out / (jl.name if len(srcdirs) == 1
                                        else f"000{dname}-{jl.name[3:]}"))
        self._send(json.dumps({"copied": n, "outdir": out.name}).encode())

    def log_message(self, *a):
        pass


if __name__ == "__main__":
    HTML = HTML.replace("__OUTDIR__", ARGS.outdir).replace("__KEY__", ARGS.key)
    url = f"http://127.0.0.1:{ARGS.port}"
    print(f"kaynak klasorler: {[d.name for d in DIRS]}")
    if ARGS.missing_from or ARGS.only_in:
        print(f"{len(items())} kart gosteriliyor")
    print(f"hedef: {ARGS.outdir} · localStorage anahtari: {ARGS.key}\n{url}")
    webbrowser.open(url)
    HTTPServer(("127.0.0.1", ARGS.port), H).serve_forever()
