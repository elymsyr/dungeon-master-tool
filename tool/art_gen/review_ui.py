#!/usr/bin/env python3
"""Art review: grid'de gez, begenmedigine yorum yaz, prompt'u Gemini ile duzelt, yeniden uret.

  python review_ui.py serve                 # http://127.0.0.1:8765  (tikla -> yorum)
  python review_ui.py rewrite               # yorumlu promptlari Gemini ile yeniden yaz
  python review_ui.py regen                 # yeni promptlarla goselleri yeniden uret
"""
import argparse, json, sys, urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

BASE = Path(__file__).resolve().parent
sys.path.insert(0, str(BASE))

REVIEWS = BASE / "art_reviews.json"      # uuid -> {comment, prompt, new_prompt}
JOBS = BASE / "art_jobs.jsonl"
OUT = BASE / "out"


def load_jobs():
    return {j["uuid"]: j for j in
            (json.loads(l) for l in JOBS.read_text().splitlines() if l.strip())}


def load_reviews():
    return json.loads(REVIEWS.read_text()) if REVIEWS.exists() else {}


def save_reviews(r):
    REVIEWS.write_text(json.dumps(r, ensure_ascii=False, indent=1))


PAGE = """<!doctype html><meta charset=utf-8><title>Art review</title>
<style>
body{background:#1e1e20;color:#eee;font:14px system-ui;margin:0;padding:12px}
#g{display:grid;grid-template-columns:repeat(auto-fill,minmax(190px,1fr));gap:10px}
figure{margin:0;background:#2a2a2e;border-radius:6px;padding:6px;cursor:pointer}
figure.done{outline:2px solid #e8a33d}
img{width:100%;display:block;border-radius:4px}
figcaption{font-size:12px;color:#bbb;margin-top:4px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
#m{position:fixed;inset:0;background:#000c;display:none;align-items:center;justify-content:center}
#b{background:#232327;padding:16px;border-radius:8px;max-width:min(900px,92vw);max-height:92vh;overflow:auto}
#b img{max-height:45vh;width:auto}
textarea{width:100%;height:90px;background:#111;color:#eee;border:1px solid #444}
pre{white-space:pre-wrap;font-size:11px;color:#999;max-height:150px;overflow:auto}
button{padding:6px 14px;margin-right:8px}
</style>
<div id=g></div>
<div id=m><div id=b>
 <h3 id=t></h3><img id=mi><pre id=mp></pre>
 <textarea id=c placeholder="Neyi begenmedin? (bos birakip kaydedersen yorum silinir)"></textarea>
 <p><button onclick=save()>Kaydet</button><button onclick=close_()>Kapat</button></p>
</div></div>
<script>
let jobs=[],cur=null;
fetch('/data').then(r=>r.json()).then(d=>{jobs=d;render()});
function render(){g.innerHTML='';jobs.forEach((j,i)=>{
 const f=document.createElement('figure');if(j.comment)f.className='done';
 f.innerHTML=`<img loading=lazy src="/img/${j.uuid}"><figcaption>${j.name} · ${j.type}</figcaption>`;
 f.onclick=()=>open_(i);g.appendChild(f);});}
function open_(i){cur=i;const j=jobs[i];t.textContent=j.name+' — '+j.package+' / '+j.type;
 mi.src='/img/'+j.uuid;mp.textContent=j.new_prompt||j.prompt;c.value=j.comment||'';m.style.display='flex';c.focus();}
function close_(){m.style.display='none'}
function save(){const j=jobs[cur];j.comment=c.value.trim();
 fetch('/save',{method:'POST',body:JSON.stringify({uuid:j.uuid,comment:j.comment})})
 .then(()=>{render();close_()});}
onkeydown=e=>{if(e.key=='Escape')close_();if(e.key=='Enter'&&e.ctrlKey)save()};
</script>"""


def serve(args):
    jobs = load_jobs()
    reviews = load_reviews()
    have = sorted((p for p in OUT.glob("*.webp") if p.stem in jobs),
                  key=lambda p: p.stat().st_mtime, reverse=True)
    if args.types:
        want = set(args.types.split(","))
        have = [p for p in have if jobs[p.stem]["type"] in want]
    if args.packages:
        want = set(args.packages.split(","))
        have = [p for p in have if jobs[p.stem]["package"] in want]
    have = have[:args.limit]
    print(f"{len(have)} gorsel -> http://{args.host}:{args.port}", file=sys.stderr)

    class H(BaseHTTPRequestHandler):
        def log_message(self, *a): pass

        def _send(self, body, ctype):
            self.send_response(200)
            self.send_header("content-type", ctype)
            self.send_header("content-length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self):
            path = urllib.parse.urlparse(self.path).path
            if path == "/":
                return self._send(PAGE.encode(), "text/html; charset=utf-8")
            if path == "/data":
                data = []
                for p in have:
                    j = jobs[p.stem]
                    r = reviews.get(p.stem, {})
                    data.append({k: j[k] for k in ("uuid", "name", "type", "package", "prompt")}
                                | {"comment": r.get("comment", ""),
                                   "new_prompt": r.get("new_prompt", "")})
                return self._send(json.dumps(data).encode(), "application/json")
            if path.startswith("/img/"):
                f = OUT / (path[5:] + ".webp")
                if f.exists():
                    return self._send(f.read_bytes(), "image/webp")
            self.send_error(404)

        def do_POST(self):
            body = json.loads(self.rfile.read(int(self.headers["content-length"])))
            uuid, comment = body["uuid"], body["comment"]
            if comment:
                r = reviews.setdefault(uuid, {})
                if r.get("comment") != comment:
                    r.pop("new_prompt", None)   # yorum degisti -> eski rewrite gecersiz
                r["comment"] = comment
                r["prompt"] = jobs[uuid]["prompt"]
            else:
                reviews.pop(uuid, None)
            save_reviews(reviews)
            self._send(b"{}", "application/json")

    ThreadingHTTPServer((args.host, args.port), H).serve_forever()


REWRITE_TMPL = """You rewrite text-to-image prompts for a D&D art pack.

Original prompt:
{prompt}

The art director rejected the resulting image with this feedback:
{comment}

Rewrite the prompt so the feedback is addressed. Keep the subject, the style
block and the composition boilerplate intact unless the feedback is about them.
Output ONLY the new prompt as a single paragraph, no preamble, no quotes."""


def rewrite(args):
    from subject_gen import gemini_subject
    reviews = load_reviews()
    todo = [u for u, r in reviews.items() if r.get("comment") and not r.get("new_prompt")]
    print(f"{len(todo)} prompt yeniden yazilacak", file=sys.stderr)
    for i, u in enumerate(todo, 1):
        r = reviews[u]
        try:
            r["new_prompt"] = gemini_subject(
                REWRITE_TMPL.format(prompt=r["prompt"], comment=r["comment"]), args.model)
        except Exception as e:
            print(f"HATA {u}: {e}", file=sys.stderr)
            continue
        save_reviews(reviews)
        print(f"{i}/{len(todo)} {u}", file=sys.stderr)


def regen(args):
    from generate import run_job, to_webp
    jobs = load_jobs()
    reviews = load_reviews()
    todo = [u for u, r in reviews.items() if r.get("new_prompt")]
    print(f"{len(todo)} gorsel yeniden uretilecek", file=sys.stderr)
    rejected = OUT / "rejected"
    rejected.mkdir(exist_ok=True)
    for i, u in enumerate(todo, 1):
        job = dict(jobs[u], prompt=reviews[u]["new_prompt"])
        try:
            png = run_job(args.host, job, args.model, args.text_encoder, args.vae,
                          args.size, args.timeout)
        except Exception as e:
            print(f"HATA {u} {job['name']}: {e}", file=sys.stderr)
            continue
        cur = OUT / f"{u}.webp"
        if cur.exists():
            cur.replace(rejected / f"{u}.webp")
        cur.write_bytes(to_webp(png, args.quality, args.crop))
        reviews[u]["regenerated"] = True
        save_reviews(reviews)
        print(f"{i}/{len(todo)} {job['name']}", file=sys.stderr)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("serve")
    s.add_argument("--host", default="127.0.0.1")
    s.add_argument("--port", type=int, default=8765)
    s.add_argument("--types")
    s.add_argument("--packages")
    s.add_argument("--limit", type=int, default=2000)
    s.set_defaults(fn=serve)

    w = sub.add_parser("rewrite")
    w.add_argument("--model", default="gemini-3.5-flash-lite")
    w.set_defaults(fn=rewrite)

    g = sub.add_parser("regen")
    g.add_argument("--host", default="http://192.168.1.12:8188")
    g.add_argument("--model", default="z_image_turbo_bf16.safetensors")
    g.add_argument("--text-encoder", default="qwen_3_4b.safetensors")
    g.add_argument("--vae", default="ae.safetensors")
    g.add_argument("--size", type=int, default=1024)
    g.add_argument("--quality", type=int, default=82)
    g.add_argument("--crop", type=float, default=0.05)
    g.add_argument("--timeout", type=int, default=300)
    g.set_defaults(fn=regen)

    args = p.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()
