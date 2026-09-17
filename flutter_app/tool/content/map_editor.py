#!/usr/bin/env python3
"""Bundled bir dünyanın harita pinlerini tarayıcıda düzenler.

    python3 tool/content/map_editor.py --dir assets/worlds/aegis/aegis-act1

`world-blueprint.json` içindeki `map_data` bloğunu okur/yazar. Kurulumda
`BundledWorldsInstaller` bu bloğu `world_map_data` satırına taşıdığı için
dünya kurulduğunda pinler hazır gelir; editörü tekrar açmak kaldığı yerden
devam ettirir.

Uygulamayla aynı model:

* **Tek ana harita** — aktif era'nın `image_path`'i.
* **Drill-in pinden** — bir pin bir location'a bağlıysa ve o location'ın
  görseli varsa pin panelinden haritası açılır, pinleri
  `eras[i].location_maps[<location id>]` altında durur (derinlik ne olursa
  olsun depolama düz).
* **Era** — birden çok zaman dilimi. Era'lar arasındaki sınırlar
  `waypoints`; era adı iki sınırın arasıdır (`era_start_label` … `era_end_label`).
  Bir location'ın era'ya özel görseli kartın `map_per_era[<era id>]` alanına
  yazılır, yoksa `map`'e düşer — `world_map_notifier` de aynısını yapar.

Sadece stdlib. Koordinatlar görselin kendi pikselleri — uygulamanın kullandığı
uzayla aynı.
"""
import argparse
import json
import mimetypes
import os
import posixpath
import threading
import uuid
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import unquote, urlparse

# world_blueprint_converter.dart ile birebir aynı olmalı.
NAMESPACE = uuid.UUID("2f1c9b3e-6d54-4a7c-9f2b-0c5a8e1d7b40")
IMAGE_EXT = (".webp", ".png", ".jpg", ".jpeg", ".gif")


def entity_id(package: str, slug: str, name: str) -> str:
    return str(uuid.uuid5(NAMESPACE, f"{package}:{slug}:{name.lower().strip()}"))


def load_world(world_dir):
    with open(os.path.join(world_dir, "manifest.json"), encoding="utf-8") as f:
        manifest = json.load(f)
    bp_path = os.path.join(world_dir, "world-blueprint.json")
    with open(bp_path, encoding="utf-8") as f:
        blueprint = json.load(f)
    return manifest, blueprint, bp_path


def first_image(value):
    """`map` / `imagePath` alanı string ya da tek elemanlı liste olabilir."""
    if isinstance(value, str):
        return value
    if isinstance(value, list) and value and isinstance(value[0], str):
        return value[0]
    return ""


def list_images(world_dir):
    """`media/` altındaki bütün görseller — era görseli seçiciye gider."""
    root = os.path.join(world_dir, "media")
    out = []
    for base, _dirs, files in os.walk(root):
        for f in files:
            if f.lower().endswith(IMAGE_EXT):
                rel = os.path.relpath(os.path.join(base, f), world_dir)
                out.append(rel.replace(os.sep, "/"))
    out.sort()
    return out


# Uzun düzyazı ve medya alanları pin panelinde işe yaramıyor — kartın "nerede,
# neyin parçası, ne durumda" özeti lazım. Blocklist tutmak kategori başına alan
# tablosu tutmaktan ucuz: geri kalan her kısa alan otomatik görünür.
DETAIL_SKIP = {
    "name", "imagePath", "images", "map", "map_per_era", "battlemaps",
    "description_long", "secrets", "dmNotes", "beats", "stat_block",
    "traits_md", "appearance", "mannerisms", "goals", "objective", "reward",
}
DETAIL_MAX = 160


def ref_text(value):
    """`{lookup, match, value}` soft ref'i (ya da listesi) okunur metne çevirir."""
    if isinstance(value, dict) and "value" in value:
        return str(value["value"])
    if isinstance(value, list):
        parts = [ref_text(v) for v in value]
        return ", ".join(p for p in parts if p)
    if isinstance(value, (str, int, float)):
        return str(value)
    return ""


def detail_of(mapping):
    """Pin panelinde gösterilecek kısa alanlar — parent location, faction, ..."""
    out = []
    for key, value in mapping.items():
        if key in DETAIL_SKIP:
            continue
        text = ref_text(value)
        if not text.strip():
            continue
        if len(text) > DETAIL_MAX:
            text = text[:DETAIL_MAX].rstrip() + "…"
        out.append([key, text])
    return out


def collect(manifest, blueprint):
    """Pin bağlanabilecek kartlar + location kartlarının mapping'leri.

    `per_era`: location id → {era id: görsel}. Kartın kendi `map_per_era`
    alanından okunur, kaydederken oraya geri yazılır.
    """
    package = manifest["slug"]
    entities, locs, per_era = [], {}, {}
    for slug, rows in (blueprint.get("categories") or {}).items():
        if not isinstance(rows, list):
            continue
        for row in rows:
            mapping = (row or {}).get("mapping") or {}
            name = mapping.get("name")
            if not isinstance(name, str) or not name.strip():
                continue
            eid = entity_id(package, slug, name)
            image = first_image(mapping.get("map")) or \
                first_image(mapping.get("battlemaps"))
            entities.append({"id": eid, "slug": slug, "name": name,
                             "detail": detail_of(mapping),
                             "map": image if slug == "location" else ""})
            if slug == "location":
                locs[eid] = mapping
                pe = mapping.get("map_per_era")
                if isinstance(pe, dict) and pe:
                    per_era[eid] = {k: first_image(v) for k, v in pe.items()
                                    if first_image(v)}
    entities.sort(key=lambda e: (e["slug"], e["name"]))
    return entities, locs, per_era


def apply_per_era(locs, per_era):
    """Era'ya özel görselleri location kartlarına yaz — boşalanı temizle."""
    for eid, mapping in locs.items():
        value = {k: v for k, v in (per_era.get(eid) or {}).items() if v}
        if value:
            mapping["map_per_era"] = value
        else:
            mapping.pop("map_per_era", None)


def new_era(image_path=""):
    return {"id": str(uuid.uuid4()), "image_path": image_path, "pins": [],
            "timeline_pins": [], "location_maps": {}}


def empty_map_data():
    return {
        "image_path": "",
        "pins": [],
        "timeline": [],
        "eras": [new_era()],
        "waypoints": [],
        "active_era_index": 0,
        "era_start_label": "Başlangıç",
        "era_end_label": "Son",
        "pin_size": "medium",
    }


def read_map_data(blueprint):
    md = blueprint.get("map_data")
    if not isinstance(md, dict) or not md.get("eras"):
        return empty_map_data()
    md.setdefault("pin_size", "medium")
    md.setdefault("waypoints", [])
    md.setdefault("era_start_label", "Başlangıç")
    md.setdefault("era_end_label", "Son")
    md["active_era_index"] = min(int(md.get("active_era_index") or 0),
                                 len(md["eras"]) - 1)
    for era in md["eras"]:
        era.setdefault("id", str(uuid.uuid4()))
        era.setdefault("image_path", "")
        era.setdefault("pins", [])
        era.setdefault("timeline_pins", [])
        era.setdefault("location_maps", {})
    return md


def write_map_data(bp_path, blueprint, md):
    era = md["eras"][0]
    # Uygulamanın legacy kökü era[0]'ın aynası — notifier ikisini de okuyor.
    md["image_path"] = era.get("image_path", "")
    md["pins"] = era.get("pins", [])
    md["timeline"] = era.get("timeline_pins", [])
    blueprint["map_data"] = md
    tmp = bp_path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(blueprint, f, ensure_ascii=False, indent=2)
        f.write("\n")
    os.replace(tmp, bp_path)


HTML = r"""<!doctype html>
<html lang="tr"><head><meta charset="utf-8"><title>Harita editörü</title>
<style>
 :root{color-scheme:dark}
 body{margin:0;display:flex;height:100vh;font:14px system-ui;background:#16181d;color:#e6e6e6}
 #side{width:280px;flex:none;overflow:auto;border-right:1px solid #2c3039;padding:10px}
 #side h3{margin:14px 0 6px;font-size:12px;text-transform:uppercase;color:#8b93a3}
 #side select,#side input[type=text]{width:100%;box-sizing:border-box;margin:2px 0;
      background:#121419;color:#eee;border:1px solid #333a46;border-radius:4px;padding:4px}
 .m{padding:5px 8px;border-radius:6px;cursor:pointer}
 .m:hover{background:#232833} .m.on{background:#2f6fd0}
 #crumb{padding:6px 0;font-size:13px;color:#8b93a3}
 #crumb span{cursor:pointer;color:#bcd} #crumb span:hover{text-decoration:underline}
 #stage{flex:1;overflow:auto;position:relative}
 #wrap{position:relative;transform-origin:0 0}
 #img{display:block;max-width:none}
 #empty{padding:24px;color:#8b93a3}
 .pin{position:absolute;transform:translate(-50%,-50%);cursor:grab;
      border:2px solid #fff;border-radius:50%;box-shadow:0 0 0 2px #0008}
 .pin span{position:absolute;left:50%;top:110%;transform:translateX(-50%);
      white-space:nowrap;font-size:11px;background:#000a;padding:1px 4px;border-radius:3px}
 .pin.deep{box-shadow:0 0 0 2px #0008,0 0 0 5px #ffb74d}
 #bar{position:fixed;right:12px;top:12px;background:#1d2029;border:1px solid #2c3039;
      border-radius:8px;padding:10px;width:260px;max-height:92vh;overflow:auto}
 #bar input,#bar select,#bar textarea{width:100%;box-sizing:border-box;margin:3px 0;
      background:#121419;color:#eee;border:1px solid #333a46;border-radius:4px;padding:4px}
 button{background:#2f6fd0;color:#fff;border:0;border-radius:5px;padding:6px 10px;cursor:pointer}
 button.g{background:#3a414f} button:disabled{opacity:.4;cursor:default}
 #msg{color:#7fd08a;font-size:12px;min-height:16px}
 #pdetail{font-size:12px;margin:4px 0;max-height:180px;overflow:auto}
 #pdetail div{display:flex;gap:6px;padding:1px 0;border-bottom:1px solid #23262e}
 #pdetail b{color:#8b93a3;font-weight:500;flex:none;min-width:88px}
 #pdetail i{color:#d99;font-style:normal}
 label{font-size:11px;color:#8b93a3}
</style></head><body>
<div id="side">
  <button onclick="save()">Kaydet</button> <span id="msg"></span>
  <h3>Era</h3><div id="eras"></div>
  <button class="g" onclick="addEra()">+ era</button>
  <button class="g" onclick="delEra()">son era'yı sil</button>
  <label>ilk era'nın başı</label><input type="text" id="lstart">
  <label>son era'nın sonu</label><input type="text" id="lend">
  <h3>Ana harita <span id="eraname" style="color:#8b93a3"></span></h3>
  <select id="rootimg"></select>
  <h3>Zum</h3><input id="zoom" type="range" min="10" max="200" value="100" style="width:100%">
</div>
<div id="stage">
  <div id="crumb"></div>
  <div id="wrap"><img id="img" hidden><div id="pins"></div></div>
  <div id="empty" hidden></div>
</div>
<div id="bar" hidden>
  <div><b id="ptitle">Pin</b></div>
  <input id="plabel" placeholder="etiket">
  <input id="pentity" list="elist" placeholder="kart ara — yaz ya da seç" autocomplete="off">
  <datalist id="elist"></datalist>
  <div id="pdetail"></div>
  <div id="pmap"></div>
  <textarea id="pnote" rows="3" placeholder="not"></textarea>
  <input id="pcolor" type="color" value="#42a5f5">
  <button class="g" onclick="delPin()">Sil</button>
  <button class="g" onclick="closeBar()">Kapat</button>
</div>
<script>
let D=null, stack=[], sel=null, z=1, byKey={}, ents={};
const $=id=>document.getElementById(id);
const uid=()=>crypto.randomUUID();
const esc=t=>String(t).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));

fetch('/state').then(r=>r.json()).then(d=>{D=d;init()});

function md(){return D.map_data}
function era(){return md().eras[md().active_era_index]}
function cur(){return stack.length?stack[stack.length-1]:null}
function bucket(){ // düzenlenen harita: kök (era) ya da location_maps[id]
  const c=cur(); if(!c) return era();
  const lm=era().location_maps||(era().location_maps={});
  return lm[c]||(lm[c]={pins:[],timeline_pins:[]});
}
// Uygulamayla aynı sıra: map_per_era[aktif era] → map → (battlemap).
function imgOf(id){
  const e=ents[id]; if(!e) return '';
  return (D.per_era[id]||{})[era().id] || e.map || '';
}
function curImage(){ const c=cur(); return c?imgOf(c):(era().image_path||''); }

function init(){
  D.entities.forEach(e=>{byKey[e.slug+'/'+e.name]=e; ents[e.id]=e});
  $('elist').innerHTML=D.entities.map(e=>`<option value="${esc(e.slug+'/'+e.name)}">`).join('');
  $('rootimg').innerHTML='<option value="">— seçilmedi —</option>'+
    D.images.map(i=>`<option value="${esc(i)}">${esc(i.replace('media/',''))}</option>`).join('');
  $('rootimg').onchange=e=>{era().image_path=e.target.value; render()};
  $('zoom').oninput=e=>{z=e.target.value/100;$('wrap').style.transform=`scale(${z})`};
  $('lstart').oninput=e=>{md().era_start_label=e.target.value; drawEras()};
  $('lend').oninput=e=>{md().era_end_label=e.target.value; drawEras()};
  render();
}

// Era adı iki sınırın arası — world_map_notifier.eraNames ile aynı kural.
function eraNames(){
  const m=md(), wps=m.waypoints||[];
  if(m.eras.length<=1) return ['Tek era'];
  return m.eras.map((e,i)=>{
    const l=i===0?m.era_start_label:((wps[i-1]||{}).label||'?');
    const r=i>=wps.length?m.era_end_label:((wps[i]||{}).label||'?');
    return l+' – '+r;
  });
}
function drawEras(){
  const names=eraNames();
  $('eras').innerHTML=names.map((n,i)=>
    `<div class="m${i===md().active_era_index?' on':''}" onclick="setEra(${i})">${esc(n)}</div>`).join('');
  $('eraname').textContent=md().eras.length>1?'· '+names[md().active_era_index]:'';
  $('lstart').value=md().era_start_label||'';
  $('lend').value=md().era_end_label||'';
}
function setEra(i){ md().active_era_index=i; closeBar(); render(); }
function addEra(){
  const label=prompt("Yeni era'yı ayıran sınırın adı (ör. Blight'tan sonra)");
  if(!label) return;
  const src=era(), copy=confirm("Bu era'nın pinleri yeni era'ya kopyalansın mı?");
  md().waypoints.push({id:uid(), label});
  md().eras.push(copy
    ? JSON.parse(JSON.stringify({...src, id:uid()}))
    : new_era(src.image_path));
  setEra(md().eras.length-1);
}
function new_era(image_path){
  return {id:uid(), image_path:image_path||'', pins:[], timeline_pins:[], location_maps:{}};
}
function delEra(){
  const m=md();
  if(m.eras.length<2) return alert('Tek era silinemez.');
  if(!confirm("Son era ve pinleri silinsin mi?")) return;
  m.eras.pop(); m.waypoints.pop();
  setEra(Math.min(m.active_era_index, m.eras.length-1));
}

function render(){
  drawEras();
  $('rootimg').value=era().image_path||'';
  $('crumb').innerHTML='<span onclick="up(0)">Ana harita</span>'+
    stack.map((id,i)=>` › <span onclick="up(${i+1})">${esc((ents[id]||{}).name||id)}</span>`).join('');
  const src=curImage();
  $('img').hidden=!src; $('empty').hidden=!!src;
  if(!src){
    $('pins').innerHTML='';
    $('empty').textContent=cur()
      ? 'Bu location için bu era\'da görsel yok — pin panelinden seç.'
      : 'Ana harita seçilmedi — soldaki listeden bir görsel seç.';
    return;
  }
  $('img').src='/file/'+src.split('/').map(encodeURIComponent).join('/');
  $('img').onload=draw;
  if($('img').complete) draw();
}
function up(depth){ if(depth>=stack.length+1) return; stack=stack.slice(0,depth); closeBar(); render(); }

function draw(){
  const b=bucket();
  $('pins').innerHTML='';
  (b.pins||[]).forEach(p=>{
    const d=document.createElement('div');
    d.className='pin'+(p.entityId&&imgOf(p.entityId)?' deep':'');
    d.style.left=p.x+'px'; d.style.top=p.y+'px';
    d.style.width=d.style.height='18px';
    d.style.background=p.color||'#42a5f5';
    d.innerHTML=p.label?`<span>${esc(p.label)}</span>`:'';
    d.onmousedown=ev=>{ev.stopPropagation();drag(ev,p,d)};
    d.ondblclick=ev=>{ev.stopPropagation();edit(p)};
    $('pins').appendChild(d);
  });
}
$('img').onmousedown=ev=>{
  const r=$('img').getBoundingClientRect();
  const p={id:uid(),x:Math.round((ev.clientX-r.left)/z),y:Math.round((ev.clientY-r.top)/z),
           label:'',pinType:'default',entityId:null,note:'',color:'#42a5f5',style:{}};
  bucket().pins.push(p); draw(); edit(p);
};
function drag(ev,p,el){
  const r=$('img').getBoundingClientRect();
  const mv=e=>{p.x=Math.round((e.clientX-r.left)/z);p.y=Math.round((e.clientY-r.top)/z);
               el.style.left=p.x+'px';el.style.top=p.y+'px'};
  const up_=()=>{document.removeEventListener('mousemove',mv);document.removeEventListener('mouseup',up_)};
  document.addEventListener('mousemove',mv);document.addEventListener('mouseup',up_);
}
function edit(p){
  sel=p; $('bar').hidden=false; $('ptitle').textContent='Pin @ '+p.x+','+p.y;
  $('plabel').value=p.label||''; $('pnote').value=p.note||'';
  $('pcolor').value=p.color||'#42a5f5';
  const linked=ents[p.entityId];
  $('pentity').value=linked?linked.slug+'/'+linked.name:'';
  showDetail(linked); showMap(linked);
  $('plabel').oninput=e=>{p.label=e.target.value;draw()};
  $('pnote').oninput=e=>{p.note=e.target.value};
  $('pcolor').oninput=e=>{p.color=e.target.value;draw()};
  $('pentity').oninput=e=>{
    const key=e.target.value.trim();
    const en=byKey[key]||(key?D.entities.find(x=>x.name===key):null);
    p.entityId=en?en.id:null;
    p.pinType=en?en.slug:'default';
    if(en&&!p.label){p.label=en.name;$('plabel').value=en.name}
    showDetail(en, key); showMap(en);
    draw();
  };
}
// Kartın özeti: parent location, faction, durum gibi kısa alanlar. Uzun
// düzyazı sunucu tarafında zaten eleniyor.
function showDetail(en, typed){
  const d=$('pdetail');
  if(!en){ d.innerHTML = typed ? '<div><i>eşleşen kart yok</i></div>' : ''; return; }
  d.innerHTML = `<div><b>kategori</b><span>${esc(en.slug)}</span></div>` +
    en.detail.map(([k,v])=>`<div><b>${esc(k)}</b><span>${esc(v)}</span></div>`).join('');
}
// Drill-in + era görseli. Location'a era'ya özel görsel verilirse kartın
// `map_per_era` alanına yazılır; boş bırakılırsa `map`'e düşer.
function showMap(en){
  const d=$('pmap');
  if(!en||en.slug!=='location'){ d.innerHTML=''; return; }
  const sel_=(D.per_era[en.id]||{})[era().id]||'';
  d.innerHTML=`<button class="g" id="pgo">Haritayı aç →</button>
    <label>bu era'nın görseli${en.map?' (varsayılan: '+esc(en.map.replace('media/',''))+')':''}</label>
    <select id="pera"><option value="">— varsayılan —</option>`+
    D.images.map(i=>`<option value="${esc(i)}"${i===sel_?' selected':''}>${esc(i.replace('media/',''))}</option>`).join('')+
    `</select>`;
  $('pgo').disabled=!imgOf(en.id);
  $('pgo').onclick=()=>{ closeBar(); stack.push(en.id); render(); };
  $('pera').onchange=e=>{
    const m=D.per_era[en.id]||(D.per_era[en.id]={});
    if(e.target.value) m[era().id]=e.target.value; else delete m[era().id];
    $('pgo').disabled=!imgOf(en.id); draw();
  };
}
function delPin(){ const b=bucket(); b.pins=b.pins.filter(x=>x.id!==sel.id); closeBar(); draw(); }
function closeBar(){ $('bar').hidden=true; sel=null; }
function save(){
  fetch('/save',{method:'POST',body:JSON.stringify({map_data:md(), per_era:D.per_era})})
    .then(r=>r.text()).then(t=>{$('msg').textContent=t;setTimeout(()=>$('msg').textContent='',2500)});
}
</script></body></html>
"""


def make_handler(world_dir, state, bp_path, blueprint, locs, lock):
    class H(BaseHTTPRequestHandler):
        def log_message(self, *a):
            pass

        def _send(self, code, body, ctype="text/plain; charset=utf-8"):
            data = body if isinstance(body, bytes) else body.encode("utf-8")
            self.send_response(code)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def do_GET(self):
            path = unquote(urlparse(self.path).path)
            if path in ("/", "/index.html"):
                return self._send(200, HTML, "text/html; charset=utf-8")
            if path == "/state":
                return self._send(200, json.dumps(state, ensure_ascii=False),
                                  "application/json; charset=utf-8")
            if path.startswith("/file/"):
                rel = posixpath.normpath(path[len("/file/"):]).lstrip("/")
                full = os.path.realpath(os.path.join(world_dir, *rel.split("/")))
                # Dizin dışına çıkan yol servis edilmez.
                if not full.startswith(os.path.realpath(world_dir) + os.sep) \
                        or not os.path.isfile(full):
                    return self._send(404, "not found")
                ctype = mimetypes.guess_type(full)[0] or "application/octet-stream"
                with open(full, "rb") as f:
                    return self._send(200, f.read(), ctype)
            return self._send(404, "not found")

        def do_POST(self):
            if urlparse(self.path).path != "/save":
                return self._send(404, "not found")
            n = int(self.headers.get("Content-Length") or 0)
            try:
                body = json.loads(self.rfile.read(n).decode("utf-8"))
                md = body["map_data"]
                per_era = body.get("per_era") or {}
                assert isinstance(md, dict) and md.get("eras"), "bozuk map_data"
                assert isinstance(per_era, dict), "bozuk per_era"
            except Exception as e:  # noqa: BLE001 — kullanıcıya göstermek yeterli
                return self._send(400, f"✗ {e}")
            with lock:
                apply_per_era(locs, per_era)
                write_map_data(bp_path, blueprint, md)
                state["map_data"] = md
                state["per_era"] = per_era
            return self._send(200, f"✓ kaydedildi · {pin_count(md)} pin, "
                                   f"{len(md['eras'])} era")

    return H


def pin_count(md):
    total = 0
    for era in md["eras"]:
        total += len(era.get("pins") or [])
        total += sum(len(v.get("pins") or [])
                     for v in (era.get("location_maps") or {}).values())
    return total


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dir", required=True, help="dünya dizini (manifest.json içeren)")
    ap.add_argument("--port", type=int, default=8777)
    ap.add_argument("--no-browser", action="store_true")
    args = ap.parse_args()

    world_dir = os.path.abspath(args.dir)
    manifest, blueprint, bp_path = load_world(world_dir)
    entities, locs, per_era = collect(manifest, blueprint)
    md = read_map_data(blueprint)
    state = {"world": manifest.get("title", manifest["slug"]),
             "entities": entities, "images": list_images(world_dir),
             "per_era": per_era, "map_data": md}

    server = ThreadingHTTPServer(("127.0.0.1", args.port),
                                make_handler(world_dir, state, bp_path,
                                             blueprint, locs, threading.Lock()))
    url = f"http://127.0.0.1:{args.port}/"
    print(f"{state['world']} · {len(md['eras'])} era, {pin_count(md)} pin, "
          f"{len(entities)} kart")
    print(f"→ {url}   (Ctrl-C ile kapat)")
    if not args.no_browser:
        threading.Timer(0.5, webbrowser.open, [url]).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nkapatıldı")


def _selftest():
    assert entity_id("aegis-act1", "location", "Gümüşsu") == \
        entity_id("aegis-act1", "location", " gümüşsu ")

    md = empty_map_data()
    md["eras"][0]["pins"].append({"id": "1", "x": 5, "y": 6})
    md["eras"][0]["location_maps"]["loc"] = {"pins": [{"id": "2"}], "timeline_pins": []}
    md["eras"].append(new_era("media/Maps/b.webp"))
    md["waypoints"].append({"id": "w", "label": "sonra"})
    md["eras"][1]["location_maps"]["loc"] = {"pins": [{"id": "3"}], "timeline_pins": []}
    md["active_era_index"] = 1
    bp = {}
    import tempfile
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
        path = f.name
    write_map_data(path, bp, md)
    again = read_map_data(json.load(open(path, encoding="utf-8")))
    assert again["eras"][0]["pins"][0]["x"] == 5
    assert again["pins"] == again["eras"][0]["pins"], "kök ayna era[0]'ı izlemeli"
    assert again["eras"][0]["location_maps"]["loc"]["pins"][0]["id"] == "2"
    assert again["eras"][1]["location_maps"]["loc"]["pins"][0]["id"] == "3", \
        "era'lar kendi location_maps'ini taşımalı"
    assert again["active_era_index"] == 1 and len(again["waypoints"]) == 1
    assert pin_count(again) == 3
    os.unlink(path)

    # map_per_era yazma/temizleme
    locs = {"a": {"name": "A", "map": "media/Maps/a.webp"},
            "b": {"name": "B", "map_per_era": {"e1": "media/Maps/old.webp"}}}
    apply_per_era(locs, {"a": {"e1": "media/Maps/x.webp"}, "b": {}})
    assert locs["a"]["map_per_era"] == {"e1": "media/Maps/x.webp"}
    assert "map_per_era" not in locs["b"], "boşalan map_per_era silinmeli"
    print("selftest ok")


if __name__ == "__main__":
    import sys
    if "--selftest" in sys.argv:
        _selftest()
    else:
        main()
