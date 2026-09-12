#!/usr/bin/env python3
"""art_jobs_final.orig.jsonl -> art_jobs_final.jsonl (elden gecirilmis prompt'lar)

Neden bu dosya var:
  - Isik kategoriye sabitti (butun location'lar "flat overcast daylight", butun
    NPC'ler "hearth glow") -> her kartin arka plani birbirinin ayni cikiyordu.
    Artik isik/atmosfer KART BASINA veriliyor (LIGHT).
  - Mekan konulari belgesel gibiydi, kamera ve olcek dili yoktu -> Meclis Salonu
    minik bir odaya donusuyordu. Artik cerceveleme kart basina secilir (FRAMING)
    ve onemli mekanlar epik vista olarak yeniden yazildi (SUBJECT).
  - Prompt'a "{isim}, Aegis {kategori}" basligi giriyordu; Mine/Fare/Kandil gibi
    adlar text encoder'da yanlis anlam uretiyor (Mine -> maden ocagi). Baslik
    tamamen kaldirildi; kimlik zaten jsonl alanlarinda.

Konu metni SUBJECT'te varsa o kullanilir, yoksa .orig dosyasindaki metin korunur.

    python3 aegis_polish.py --check      # dogrula + ornek bas, dosya yazma
    python3 aegis_polish.py              # art_jobs_final.jsonl yaz
"""
from __future__ import annotations
import argparse, json, sys
from pathlib import Path

BASE = Path(__file__).resolve().parent

# ---------------------------------------------------------------------------
# Ortak stil — kart basina degismeyen tek blok. Palet artik burada DEGIL;
# her kartin rengini kendi isigi tasiyor (yoksa hepsi ayni bej oluyor).
# ---------------------------------------------------------------------------
DND = "Dungeons & Dragons 5th edition tabletop roleplaying game illustration"
# Anakronizm freni: Elymsyr'e lokomotif/vapur ciziyordu. Sadece cevre goren
# kartlara takilir; yakin plan bir yuzuge "sail and horse" demenin anlami yok.
ERA = "medieval fantasy world of timber, stone, sail and horse"
ERA_CATEGORIES = {"campaign", "location", "scene", "quest", "encounter", "lore", "background"}
STYLE = ("hand-painted oil painting on canvas, expressive painterly brushstrokes, "
         "matte finish")
TAIL = ("subtle tonal variation across surfaces, slightly uneven hand-drawn edges, "
        "irregular handmade pigment density, classic fantasy tabletop roleplaying game art")
FULL_BLEED = ("full-bleed square artwork, edge-to-edge composition, no margins, "
              "no border, no frame, no vignette, environment extends to all edges")
FLAVOR = ["bold confident strokes", "loose sketchy marks", "soft blended edges",
          "crisp detailed lines", "gritty worn texture"]

# ---------------------------------------------------------------------------
# Cerceveleme
# ---------------------------------------------------------------------------
EPIC = ("sweeping epic establishing shot, high vantage looking out across the whole place, "
        "vast sense of scale, layered foreground midground and far distance, "
        "small figures giving human scale, deep atmospheric perspective")
INTERIOR = ("monumental interior, wide angle, great height rising out of the top of the frame, "
            "deep receding perspective, figures small against the architecture")
INTIMATE = ("warm crowded interior seen from the doorway, wide angle, "
            "layered depth through the room, figures reading clearly")
PORTRAIT = ("waist-up character portrait, the figure large and dominant in frame, "
            "the setting behind falling away into soft depth")
CREATURE = ("dramatic creature study, low viewpoint close to the ground, "
            "the animal filling most of the frame, sense of weight and muscle")
ACTION = ("dynamic action moment caught mid-motion, close dramatic angle, "
          "strong diagonal composition")
SCENE = ("cinematic storytelling composition, layered staging front to back, "
         "figures reading clearly against the space")
OBJECT = ("close still-life study, the object filling the frame, "
          "softly suggested depth behind, tactile surface detail")
SYMBOL = ("strong single focal subject, deliberate symbolic staging, "
          "clear silhouette, depth falling away behind")

FRAMING_BY_CATEGORY = {
    "campaign": EPIC, "location": EPIC, "lore": SYMBOL, "npc": PORTRAIT,
    "background": PORTRAIT, "monster": CREATURE, "animal": CREATURE,
    "creature-action": ACTION, "trait": ACTION, "scene": SCENE,
    "encounter": ACTION, "quest": SCENE, "curse": OBJECT,
    "adventuring-gear": OBJECT, "trinket": OBJECT, "subclass": PORTRAIT,
}

FRAMING = {
    "location|Mühür Salonu": INTERIOR,
    "location|Meclis Salonu": INTERIOR,
    "location|Karşı-İmza Masası": INTERIOR,
    "location|Goodbarrel'ın Ocak Başı": INTIMATE,
    "location|Kulübe": ("close establishing shot, low angle looking up the path at the cabin, "
                        "the forest pressing in from every side, oppressive depth"),
    "location|Vorstrand": ("distant establishing shot seen over a ship's rail, "
                           "immense empty middle distance, tiny ship for scale"),
    "lore|Konsey ve Lonca Meclisi": INTERIOR,
    "lore|Büyücü Loncası": INTERIOR,
    "lore|Hizmet Basamakları": INTERIOR,
    "lore|Gümüş Kalkan Nişanı": ("heroic low-angle group shot, shields filling the frame edge to edge, "
                                 "figures larger than the viewer"),
    "scene|Meclis Oturumu": INTERIOR,
    "scene|Susan Kule": ("cinematic night composition, high clifftop vantage, "
                         "the coastline receding into the dark"),
    "subclass|Pul Bağıtlısı": ("heroic pair composition, ranger and drake together, "
                               "figures large in frame, the plateau opening up behind"),
}

# ---------------------------------------------------------------------------
# Yeniden yazilan konular. Burada olmayan kartlar .orig metnini korur.
# ---------------------------------------------------------------------------
SUBJECT = {
# --- campaign -------------------------------------------------------------
"campaign|Aegis":
 "A vast dawn valley seen from a high forest ridge: in the near foreground a clearing of "
 "mossy-roofed timber houses with one crooked single-room hut standing apart beyond the last "
 "fence, in the midground a river road winding east through black pines, and far away across "
 "the plain the white marble terraces and pale spires of a great coastal city rising above a "
 "grey sea where tall-masted ships lie at anchor, ground mist lying in long ribbons between "
 "the trees, the first sun breaking under a towering cloud bank",

# --- location -------------------------------------------------------------
"location|Aegis":
 "A vast ocean seen from high above the cloud line at golden hour, a green continent on the "
 "left edged with white-stone port cities catching the low sun, a darker far shore on the "
 "right drowned in standing fog, and strung between them across the open water a shipping "
 "lane of a dozen tall-masted sailing ships, immense cloud shadows sweeping the sea, gulls "
 "wheeling far below over white cliffs",
"location|Meridia":
 "An immense continental panorama seen from an impossible height in the late afternoon: "
 "snow-capped grey mountains along the left with a silver river bursting out of a cleft and "
 "running down to the sea, a white limestone coast of sheer cliffs on the right where a "
 "single deep bay holds a castle, a fog-drowned plateau along the far top edge, dark pine "
 "forest across the bottom, and between them golden plains threaded with cart roads and pale "
 "stone towns, great shafts of sunlight breaking through heavy cloud onto the land",
"location|Vorstrand":
 "A forbidding far coastline seen across open sea at dusk from the rail of a ship, low black "
 "headlands and unfamiliar angular towers half dissolved in standing fog, a cold heavy swell "
 "rolling through the foreground, one small outbound ship dark against the water, not a "
 "single harbour light anywhere on that shore, an enormous flat cloud bank pressing down on "
 "the horizon",
"location|Gümüşsu":
 "A small forest village in a clearing seen from the ridge path at dawn, mossy shingled "
 "timber houses strung along a rutted track, straight columns of woodsmoke standing in the "
 "cold air, a copper cauldron boiling over a fire in one yard, washed linen hanging on a "
 "line, fresh chalk marks and a palm-sized carved wooden charm nailed beside two doorways, a "
 "young villager with a spear sitting on a stump at the village mouth, and towering over all "
 "of it enormous dark pines closing the clearing in on every side, low sun cutting between "
 "the trunks through ground mist",
"location|Kulübe":
 "A crooked single-room cabin of thick nailed planks standing at the end of a narrow path "
 "through waist-high scrub, moss stuffed into every gap between the boards, a covered cooking "
 "pot left untouched on the flat stone before the shut door with fat congealed at its rim, "
 "one shuttered window, the wet black forest crowding the cabin from behind and leaning over "
 "it, nothing else anywhere near it",
"location|Goodbarrel'ın Ocak Başı":
 "The packed common room of a two-storey village inn on a winter evening, a great stone "
 "hearth blazing on the far wall with a black pot hanging on its hook, six long tables with "
 "villagers crowded along the benches talking and eating, muddy boots steaming in a row "
 "before the fire, bundles of dried herbs and two sets of deer antlers on the walls, dark low "
 "beams overhead, and behind the plank counter a round-cheeked halfling innkeeper standing up "
 "on a tall stool polishing a tankard with a cloth over his shoulder, a rack of tankards and "
 "two barrels on the shelf behind him, a narrow stair climbing into the dark at the back",
"location|Gizli Liman":
 "A hidden cove seen from high on the cliff road at sunset, two headlands almost closing the "
 "mouth of the water, three crooked wooden jetties reaching out far below with boats of every "
 "size tied along them and not one flag on any mast, tarred plank sheds smoking against the "
 "base of the rock, half-erased ancient symbols carved into the cliff face at head height, "
 "the first lanterns showing along the piers, a burning red-gold sky over the open sea beyond "
 "the headlands",
"location|Rıhtım":
 "Three uneven wooden jetties reaching out over green water at first light, planks sagging "
 "underfoot with the sea showing between them, barrels and crates stacked and marked in chalk "
 "with arrows crosses and numbers instead of stamps, no crane anywhere, dockhands hauling a "
 "load by rope and shoulder hook, a two-masted wooden cargo boat and a fishing skiff moored "
 "alongside, a barefoot halfling boy swinging his legs on a barrel, tarred sheds and a sheer "
 "cliff rising behind the shore end of the piers",
"location|Lucid Triton":
 "A vast white marble capital seen from a high terrace in the late afternoon, the whole city "
 "laid out below: broad avenues lined with crimson orange and violet leaved trees running "
 "between two and three storey marble facades of flawless stonework, a great square holding a "
 "colossal stone statue of an architect on its plinth, a large quiet crowd of small figures "
 "moving with papers and folios in their hands, lamplighters beginning their round along the "
 "avenues, the city wall and open plains beyond, the low sun setting the marble glowing pink "
 "and gold",
"location|Mühür Salonu":
 "An immensely long sealing hall whose windows begin far above head height so that only bright "
 "sky shows through them, two rows of desks receding into deep perspective toward the far end "
 "of the room, each desk carrying an open ledger, a small copper wax burner and an opened seal "
 "box, clerks working in total silence, threads of smoke rising through the shafts of high "
 "window light, a wall of pigeonholed cabinets closing the far end",
"location|Meclis Salonu":
 "A monumental vaulted council chamber of cold grey stone, the ribbed ceiling rising far out "
 "of the top of the frame and lost in shadow, six heavy dark wooden chairs set in a half "
 "circle on a raised stone dais at the far end and dwarfed by the height of the hall, five "
 "house sigils mounted high on the wall behind them, a hammer, a balance scale, a pair of "
 "compasses, a sword and a key, bare unmarked stone behind the sixth chair, a low worn wooden "
 "petitioners' railing running across the foreground polished bright where hands have gripped "
 "it, tall candle sconces on the piers, one clerk at a lectern small on the vast stone floor",
"location|Karşı-İmza Masası":
 "An endlessly long windowless stone corridor in steep one-point perspective, wall lamps "
 "dropping yellow rings of light onto the flagstones one after another into the dark, a single "
 "desk at the very far end with a slow queue of petitioners strung back along the corridor "
 "toward the viewer, every one of them holding an unfolded paper, a leaning stack of unsigned "
 "documents at the corner of the desk with the lowest sheets yellowed at the edges",
"location|Elymsyr":
 "A great terraced port city climbing a steep hillside where a river bursts out of a mountain "
 "cleft and opens into the sea, seen from across the water at golden hour: stone terraces "
 "stacked in steps up the slope with domes, arcades and towers among them, long warehouse "
 "quays lining the river below with gnome-built timber and brass treadwheel cranes turning on "
 "their roofs, a forest of masts where tall wooden sailing ships crowd the river mouth, two "
 "high stone watchtowers guarding the narrow throat with spear points glinting on their tops, "
 "a governor's palace on the topmost terrace, the low sun turning cliffs, stone and water "
 "molten gold",
"location|Votumar":
 "A towering white limestone castle rising in tiers straight out of sheer sea cliffs above a "
 "grey bay, curtain walls growing out of the living rock, heavy storm swell smashing at the "
 "cliff foot and throwing spray halfway up the walls, catapult emplacements ranked along the "
 "ramparts, a narrow gate road climbing from the shore where two paladins in plate stand "
 "motionless behind tower shields taller than themselves, slate storm cloud stacked over the "
 "sea, a cold break of sun striking the wet white stone",
"location|Gözcü Kuleleri Hattı":
 "A line of stone signal towers strung along a high clifftop coast and running away into the "
 "far distance, seen from beside the nearest tower at midday: its great bronze mirror turning "
 "and throwing a hard beam of caught sunlight down the coast to the next tower, and that one "
 "answering far away, ranks of catapults with their arms raised on the open ground between "
 "the towers, a lighthouse standing on black rocks at the last point, a bright hammered sea "
 "and salt haze below",
"location|Ravenhall Avlusu":
 "A flat windswept northern plateau emerging out of thick fog, a great ring of standing stones "
 "with the smallest as tall as a man, rune grooves cut a finger deep into their faces holding "
 "a slow amber glow, a raven with ruffled feathers on the tallest stone, a door carved into "
 "the trunk of an enormous ancient tree beyond the ring, one narrow path climbing to the "
 "plateau edge and dropping away into white cloud, wet black rock and wind-bent grass",
"location|Cinervik":
 "A long road village at dusk with the northern highway running straight through the middle of "
 "it and coating everything in the same grey dust, half a dozen inns with enormous signboards "
 "down both sides, a farrier's forge glowing orange at the roadside with tethered horses "
 "outside it, mostly empty tables in front of the inns, a water trough at the verge with a "
 "boy standing beside it, dust hanging gold in the last light, the empty road running away to "
 "the horizon in both directions",
"location|Argenfon":
 "A coastal fishing village of plain stone houses facing a grey sea, seaward walls built an "
 "arm thick with only narrow slits for windows, fishing nets drying on frames before the "
 "doors, upturned boats on the shingle, a small square by the water where a paladin in plate "
 "with a wool cloak thrown over it stands laughing with boatmen, a white castle small on the "
 "headland beyond, breaking waves and low racing cloud",

# --- lore (yalnizca olcek sorunu olanlar) ---------------------------------
"lore|İrade Çağı":
 "A colossal stone statue of a crowned king from the waist up, so huge that the people "
 "crossing the empty white marble plaza at its feet reach no higher than its ankles, a thick "
 "iron chain snapped at his neck and hanging loose across his chest, a bronze clock face set "
 "into the cracked breast with its hands stopped at midnight, an iron laurel wreath on his "
 "brow, empty eye sockets streaked with dried black mortar, a huge flat sky behind him",
"lore|Konsey ve Lonca Meclisi":
 "Six heavy dark wooden chairs set in a half circle on a raised dais in a towering cold stone "
 "hall whose vault is lost in shadow above, five of them with a house sigil mounted high on "
 "the wall behind, a hammer, a balance scale, a pair of compasses, a sword and a key, the "
 "sixth backed by bare unmarked stone, a low worn wooden railing facing them across a vast "
 "empty floor",
"lore|Büyücü Loncası":
 "A great vaulted academy hall with a large teleportation circle drawn in blue chalk on the "
 "flagstone floor, concentric rings of script running out across the stone, three students in "
 "navy robes standing small at its edge with slates under their arms, towering shelves of "
 "bound codices climbing the walls out of frame, tall narrow windows throwing long shafts of "
 "pale light down across the circle",
"lore|Hizmet Basamakları":
 "A broad worn stone staircase rising steeply out of the dark and filling the frame, a trade "
 "token set into each step, an apprentice's chalk, a journeyman's hammer, a master's seal, a "
 "soldier's buckle and an officer's braid, the lower steps hollowed by generations of boots, "
 "the top step lost in a blazing bright doorway, plain guildhall walls rising on both sides",

# --- drake kartlari: 'low scaled reptile' degil, kanatsiz drake -----------
"animal|Pullu":
 "A wingless drake the size of a large dog, low and broad, its dragon-shaped body armoured in "
 "hard overlapping olive-green scales with a pale grey belly, a blunt wedge-shaped reptilian "
 "head with horizontal slit pupils and a short crest of horn spines running back from the "
 "skull, two fist-sized glands swelling either side of the neck as it breathes, a heavy "
 "tapering tail laid out behind, short powerful clawed legs planted wide, its back completely "
 "bare with no wings and no wing stubs anywhere, standing on wet rune-carved stone at the foot "
 "of a fog-bound plateau",
"subclass|Pul Bağıtlısı":
 "A ranger in a fur-trimmed leather coat kneeling with one palm pressed flat on a rune-carved "
 "standing stone, a wingless olive-scaled drake the size of a large dog pressed against their "
 "knee with its neck glands swollen and its dragon-shaped head raised, no wings anywhere on "
 "its back, a hunting bow across the ranger's shoulder, fresh stone dust in the rune grooves, "
 "a ring of standing stones and fog-bound plateau behind them",
"trait|Bağıt Yoldaşı":
 "A ranger with one arm outstretched as a wingless olive-scaled drake the size of a large dog "
 "arrives in a burst of stone dust on the empty ground before them, its dragon-shaped head "
 "low and its back bare of wings, the runes on a nearby standing stone lit faintly along the "
 "same line, wind-bent plateau grass and fog behind",
"trait|Salgı":
 "A close view of a wingless drake's neck and jaw, hard olive-green scales in overlapping "
 "plates, the two fist-sized glands behind the jaw swollen tight and beaded with a clear "
 "caustic fluid, the scales around them unmarked and clean where the drops run off, a slit "
 "pupil and a row of small conical teeth at the frame edge, wet rock and moss beneath",
"trait|Pul ve Diş":
 "A grown wingless drake the size of a pony hooked high on a rock face with its claws driven "
 "into the stone, broad armoured shoulders, a dragon-shaped head turned back over the "
 "shoulder, a thick tail counterbalancing out over the drop, no wings and no wing stubs "
 "anywhere on its back, a saddle blanket strapped over its spine, a fog-filled plateau gorge "
 "far below",
"trait|Tam Bağıt":
 "An enormous wingless drake standing as tall as a warhorse with a rider seated easily on its "
 "back, broad clawed feet spread on bare stone, heavy tail low, armoured olive-green scales, "
 "a long dragon-shaped head lowered and neck glands flared wide, its back entirely wingless, "
 "a full ring of lit standing stones behind under rolling fog",
"trait|Refleks Direnci":
 "A ranger and a wingless olive-scaled drake standing back to back, both flinching in the same "
 "instant, a taut thread of rune-light joining the ranger's wrist to the drake's collar, an "
 "incoming spear breaking its force against the ranger's side, rune-carved standing stones "
 "behind them",
"creature-action|Isırık":
 "A wingless drake the size of a large dog lunging forward with its jaws locked onto an "
 "armoured forearm, small conical teeth sunk in, dragon-shaped head twisting for the pull, "
 "neck glands swollen hard, acid smoking where it drips from the jaw onto the ground, clawed "
 "feet planted wide, its back bare of wings, wet rock and bent grass underfoot",
"creature-action|Salgı Püskürtmesi":
 "A wingless olive-scaled drake with its neck glands swollen hard, head low and mouth open, "
 "jetting a wide cone of thick acid spray across the frame, droplets pitting the stone and "
 "grass where they land, a companion ranger crouched behind it shielding their face, a foggy "
 "plateau slope beyond",
"creature-action|Salgılı Vuruş":
 "A swordsman's blade striking home while a wingless olive-scaled drake beside him flicks its "
 "dragon-shaped head and coats the steel with a thin viscous secretion, the liquid running "
 "down the blade and smoking against the target's armour, a plateau slope in fog behind",

# --- scene ----------------------------------------------------------------
"scene|Meclis Oturumu":
 "A towering vaulted stone council chamber, six council seats raised on a dais in a half "
 "circle facing the viewer and small against the height of the hall, an elf rector with his "
 "fingers joined, a gnome apothecary, a dwarf guild master turning a page, a rigid human law "
 "lord, a plan-holder with a rolled drawing and an old man in a worn coat, a clerk reading "
 "aloud from a register at a lectern, petitioners standing at the low wooden railing across "
 "the foreground with their backs to the viewer",
}

# ---------------------------------------------------------------------------
# Isik + atmosfer + renk: KART BASINA. Bu sozluk "butun arka planlar ayni"
# sorununun asil carasi; kategori geneli bir isik birakilmadi.
# ---------------------------------------------------------------------------
LIGHT = {
"campaign|Aegis": "first dawn light breaking under a heavy cloud bank, ground mist in the valley, cold blue forest against warm gold on the far city",

"location|Aegis": "golden hour seen from above the clouds, warm light raking a wide sea, immense cloud shadows, luminous haze",
"location|Meridia": "late afternoon sun breaking through heavy cloud in long shafts, gold on the plains, cold blue on the mountains",
"location|Vorstrand": "the last cold blue light after sunset, a fog bank swallowing the far shore, black water, no warmth anywhere",
"location|Gümüşsu": "low dawn sun cutting between pine trunks, thick ground mist, warm woodsmoke against cold blue shade",
"location|Kulübe": "cold blue-grey morning half light, no sun, damp air, a sickly warm glow leaking through the door cracks",
"location|Goodbarrel'ın Ocak Başı": "firelit interior, the hearth the only strong light source, deep orange on faces and beams, blue night at the small shuttered windows, smoke haze under the ceiling",
"location|Gizli Liman": "burning red-gold sunset over open sea, the cove already sunk in violet shadow, first lantern points on the piers",
"location|Rıhtım": "cold silver first light off the water, long wet reflections, mist burning off the cove",
"location|Lucid Triton": "low golden late afternoon sun, white marble glowing pink and gold, long blue shadows across the squares",
"location|Mühür Salonu": "hard shafts of pale daylight falling from very high windows into a dim hall, warm candle and wax-burner glow at each desk, dust and smoke in the beams",
"location|Meclis Salonu": "cold grey daylight from high clerestory windows, deep shadow filling the vault above, small warm candle points on the piers",
"location|Karşı-İmza Masası": "a windowless corridor lit only by a receding line of wall lamps, yellow pools on stone, deep dark between them",
"location|Elymsyr": "molten golden hour, the low sun straight down the river mouth, warm light on stacked terraces, glittering water, sea haze",
"location|Votumar": "storm light, heavy slate cloud stacked over the sea, one cold break of sun striking wet white limestone, spray in the air",
"location|Gözcü Kuleleri Hattı": "hard bright midday sun, hammered glare off the sea, sharp black shadows, salt haze on the horizon",
"location|Ravenhall Avlusu": "moonlight breaking through thick fog, cold silver air, faint amber glow rising out of the rune grooves",
"location|Cinervik": "dusty gold last light, everything filmed with the same grey road dust, one forge mouth glowing orange, long shadows down the road",
"location|Argenfon": "warm low evening sun under a racing grey sky, wet shingle catching the light, cold sea behind",

"lore|İrade Çağı": "flat cold overcast, hard white plaza glare, almost no shadows, an oppressive empty sky",
"lore|Tanrılar ve Fısıltı": "grey daylight falling through a broken roof into a dim chapel, one small candle flame, drifting dust",
"lore|Blight — Bilinen Hali": "cold clinical daylight raking from one side, grey skin, sharp detail, the door behind in shade",
"lore|Vorstrand — Bilinen Hali": "flat sea light under low cloud, salt haze, a colourless horizon",
"lore|Konsey ve Lonca Meclisi": "cold high daylight in a great stone hall, deep shadow in the vault, small candle points on the piers",
"lore|Sancak Kaydı": "one lamp low and close over the open page, a warm tight pool of light, the shelves behind falling into black",
"lore|Büyücü Loncası": "pale daylight in long shafts from tall narrow windows, a cold blue chalk glow rising off the circle",
"lore|Sınır ve Ticaret Loncası": "hanging lantern light straight down onto the desk, papers bright, the shuttered window behind blue with evening",
"lore|Demircilik ve İşçi Loncası": "forge glow from behind, orange rim light along the anvil and tongs, soot dark everywhere else",
"lore|Simya ve Şifacılar Loncası": "a single oil lamp, warm light coming through amber and brown glass bottles, the green cabinet in soft shade",
"lore|Askeri Hukuk Loncası": "cold hard light from one high window, black desk, deep shadow, chain and lead seal picked out",
"lore|Mimarlık ve Planlama Loncası": "clean north daylight across the drafting table, ink and paper bright, the scaffolded wall sunlit behind",
"lore|İrade Yolu": "hard noon sun on a dusty open road, bleached stone, short sharp shadows, a hot pale sky",
"lore|Sessiz Mabetler": "a narrow alley in deep shade, three candle flames the only warm light, a strip of bright sky far above",
"lore|Hizmet Basamakları": "a dim stairwell rising toward a blazing white doorway at the top, strong light and dark contrast",
"lore|Onur Mahkemeleri": "cold grey indoor light on dark wood, and beyond the open gate a washed-out empty road under overcast",
"lore|Gümüş Kalkan Nişanı": "overcast sea light, a cold sheen along polished plate and locked shield rims, white cloaks against a grey bay",
"lore|Kuzeyin Gözcüleri": "fog-filtered dusk, cold blue air, amber rune glow thrown up onto faces and fur",
"lore|Liman Ahdi": "grey overcast noon in the cove, flat light on wet timber, green water",
"lore|Kural Sapmaları": "one low candle on a bare stone table, hard raking light across the objects, black behind",

"npc|Duran": "cool overcast forest-village daylight, soft light across a weathered face, woodsmoke and pines behind",
"npc|Umay": "bright shaded daylight by the well, clean cool light, drying herb bundles above",
"npc|Corvin": "dusk on a cliff track, cold blue sea behind, the last warm light on one side of his face",
"npc|Milo Goodbarrel": "hearth firelight from below and one side, deep orange, the warm dark inn behind him",
"npc|Alton Leagallow": "a dim cabin interior with one thin blade of grey door light crossing the face, everything else in shadow",
"npc|Merla Tealeaf": "dim cabin interior, cold grey light on ashen skin, deep shadow behind",
"npc|Kromanna": "grey doorway light behind her throwing her half into silhouette, cold light catching dark red skin",
"npc|Sicim": "overcast cove light, soft flat daylight on the open ledger, sea glare behind",
"npc|Fare": "bright midday sun on the jetty, sharp reflections off green water, hot clean light",
"npc|Kaptan Caelynn": "clean morning light on a scrubbed deck, cool blue shadows, salt-bright air",
"npc|Kaptan Holg": "warm afternoon sun on a patched deck, heavy shadow under the brows",
"npc|Kadife": "flat overcast dock light, his clean dark coat crisp against tarred timber",
"npc|Mine": "one jeweller's lamp close over the hands, a warm tight pool of light, the cramped back room dark around it",
"npc|Rektör — Quarion": "cool even daylight in a stone chamber, no warmth in it, pale silver hair lit from one side",
"npc|Sınır ve Ticaret — Orvan Sancar": "cold council-hall light from a high window, the worn coat in soft shade",
"npc|Kalfa Başı — Adrik Ferrun": "a table lamp lighting the face from below, the hammer sigil behind in shadow",
"npc|Baş Otacı — Caramip Kalender": "green-tinted light through rows of medicine bottles, warm lamp on the face",
"npc|Sicil Ağası — Valen Custar": "hard side light, half the face in shadow, black robe against cold stone",
"npc|Levha Sahibi — Perhun Mizan": "clean daylight over the drawing table, the plan bright, the man in soft even light",
"npc|Corin Sancar": "one corridor lamp above the desk, yellow light on a tired face and stacked paper, dark corridor behind",
"npc|Kildrak Ferrun": "workbench lamp with a bright flash off the silver ingot, warm dark workshop around",
"npc|Sindri": "cool daylight in a copy room, paper bright, ink stains vivid on the fingers",
"npc|Kandil": "overcast market light with white marble bouncing it back, the man greyer than the street",
"npc|Çavuş Krusk": "deep shade under a gate arch with bright street light behind, rim light along the tusks",
"npc|Gümrük Valisi": "a tall window blazing behind him with the river and cranes beyond, his face in warm shade",
"npc|Nehir Muhafızı Çavuşu": "hard wind-blown daylight on a tower platform, cold light, sea glare behind",
"npc|Vinç Ustası": "strong sun on a warehouse roof, high contrast, dust and grease catching the light",
"npc|Çevirmen": "busy quay daylight broken up by crowd and rigging, dappled light",
"npc|Başkumandan": "clean cold courtyard daylight, hard white highlights on flawless plate, a grey sky above",
"npc|Kapı Komutanı": "the shade of a gatehouse arch with cold light from outside, the open register bright under her hand",
"npc|Şüpheci Rütbeli": "one shuttered window throwing a single bar of light across a dim stone chamber, most of the face in shadow",
"npc|Kule Nöbetçisi": "hard coastal sun and mirror glare, salt haze, bronze scales flashing",
"npc|En Yaşlı Druid": "fog-diffused plateau light, cold silver air, a faint amber rune glow from below",
"npc|Patika Gözcüsü": "overcast cliff-path light, cold green-grey, wet rock",

"trait|Acıyı Tanımaz": "cold dawn light on wet trampled grass, long blue shadows, grey lifeless skin",
"trait|Bulaştıran Yara": "harsh close daylight, clinical and unflinching, sharp detail in the wound",
"trait|Durmayan Adım": "flat dawn light, the background streaked with motion, cold air",
"trait|Kesik Kesik": "dim cabin light with a hard split between the still half and the moving half",
"trait|Erken Güçlenme": "grey dawn fog behind, cold backlight, the figure dark and fast against it",
"trait|Kayıt Tezahürü": "warm lamplit study, gold light on the raised hand, dust in the air drawn into one straight line",
"trait|Dengeyi Geri Ver": "even quiet daylight on ruled ledger paper, precise undramatic light",
"trait|Fihrist Hali": "cool archive light, thin ink lines glowing faintly along the body",
"trait|Sayım": "shafts of dusty light in a wrecked hall, the beams themselves ordered and straight",
"trait|Bağıt Armağanı": "fog-diffused plateau light, fresh amber glow down in the new rune grooves",
"trait|Bağıt Yoldaşı": "cold fog light on the plateau, stone dust hanging in the air",
"trait|Salgı": "wet close daylight on hard scales, clear droplets catching the light",
"trait|Pul ve Diş": "bright fog-edged daylight on a cliff face, the drake lit hard from above, the drop below in white cloud",
"trait|Refleks Direnci": "grey plateau light, the thread of rune-light the only warm colour in the frame",
"trait|Tam Bağıt": "a low sun breaking through plateau fog, rider and drake backlit and huge against it",

"creature-action|Pençe": "grey dawn, cold flat light, the village lane blurred behind",
"creature-action|Pençe (Alton)": "low dawn light across wet grass, cold and colourless",
"creature-action|Pençe (Merla)": "dim doorway light, hard contrast, black streaks catching a shine",
"creature-action|Pençe (Kromanna)": "cold dawn fog with splintered timber and dust hanging in it",
"creature-action|Dengeyi Geri Ver": "a lamplit archive corridor, one warm pool of light on stone",
"creature-action|Mühür Kalkanı": "warm lamplight glowing through hanging red wax seals",
"creature-action|Fihrist Hali": "cool even archive light, faint ink glow along the body",
"creature-action|Sayım": "shafts of dusty light in a hall putting itself back together",
"creature-action|Salgı Püskürtmesi": "flat fog light with the acid cone catching a pale glow",
"creature-action|Refleks Direnci": "cold plateau light, one warm rune thread between them",
"creature-action|Isırık": "wet overcast light on rock and scales, acid smoke catching it",
"creature-action|Salgılı Vuruş": "grey fog light, the smoking blade the brightest thing in frame",

"monster|Dönüşmüş": "the first grey light on a village track, cold and drained of colour",
"monster|Dönüşmüş Alton": "grey dawn at a broken cabin door, flat cold light, wet grass",
"monster|Dönüşmüş Merla": "the very first light of day, almost colourless, black fluid catching a wet shine",
"monster|Dönüşmüş Kromanna": "cold dawn fog backlighting her through the broken doorway",
"curse|Blight — Enfeksiyon": "flat clinical daylight from one side, the plank wall behind in shade",

"scene|Köye Varış": "warm morning sun through pine trunks, smoke and cauldron steam catching the light",
"scene|Kulübe Sorgusu": "a hot dim interior, one lantern flame and a blade of grey door light",
"scene|Şafak Dönüşümü": "the first grey of dawn with all colour drained out of it, one warm lit window along the track",
"scene|Limana Kabul": "late afternoon light down the cliff road, the cove already in shadow below",
"scene|Geçiş Pazarlığı": "bright wet dock light between two hulls, reflections thrown up off green water",
"scene|Meclis Oturumu": "cold vaulted daylight from far above, small candle points, faces in flat even light",
"scene|Kapı Önündeki Teklif": "corridor lamps dropping warm rings of light, cold stone between them",
"scene|Geçiş Divanı'nda Sıra": "yellow lamplight down a dim windowless corridor, tired stale air",
"scene|Gümrük Rıhtımı": "hard midday sun on a stone quay, sharp shadows, spice dust hanging in the light",
"scene|Susan Kule": "night, the fire basin the only strong light, wind tearing the flame sideways, distant fires down a black coast",
"scene|Avluda Karşılanma": "fog-diffused dusk, amber rune light falling across half an old face",
"encounter|Şafak Çatışması": "the grey moment before sunrise, cold blue everywhere, sour haze catching the light",
"quest|Söylentinin Peşinde": "dusk on a muddy forest road, last warm light on the nailed notice, dark pines closing in",
"quest|Nereden Geldiler": "one desk lamp over the cut page, a warm close pool of light, the port window blue with evening behind",

"adventuring-gear|Tasnif Çantası": "dusty archive light from one side, a warm lamp behind the satchel",
"adventuring-gear|Kayıt Elifbası": "even library daylight, soft shadow, warm worn leather tones",
"adventuring-gear|Sancak Fihristi": "brass lamp light raking across the coloured leather tabs",
"adventuring-gear|Mertebe Kaftanı": "soft window light running down the folds of heavy cloth, warm cedar interior",
"adventuring-gear|Öğrenci Defteri": "cool academy daylight with a faint blue chalk glow off the floor circle",
"adventuring-gear|Yük Kancası": "flat overcast dock light on wet planks, green water showing between them",
"adventuring-gear|Seyir Defteri": "a swinging cabin lamp throwing moving warm light over salt-swollen pages",
"adventuring-gear|Direnç Şerbeti": "a single lamp behind the green bottle, light glowing through the dark syrup",
"trinket|Lonca Mührü": "warm desk lamp, a hard highlight along the silver, red wax glowing in the hollows",
"trinket|Lonca Rozeti": "soft doorway daylight on wool, one bright glint off polished brass",
"trinket|Aile Mührü": "portrait-lamp light on gold and velvet, deep shadow behind",
"trinket|Sahte Mühür": "a hard bright jeweller's lamp through the lens, cold metal, merciless detail",
"trinket|Kışla Künyesi": "cool barracks daylight on white wool, a clean highlight along the silver plate",
"trinket|Emir Mührü": "candle and lit taper, warm light on white sealing wax and dark polished wood",
"trinket|Mühürsüz Yüzük": "dim cabin light with one shaft catching the filed-flat gold face",
"background|Arşivci": "one bracket lamp in a dark stack, warm light on floating dust, the rows receding into black",
"background|Lonca Üyesi": "a bright guild yard through the open door behind, the workshop in warm shade",
"background|Mertebeli Lonca Çocuğu": "tall-window daylight across a panelled hall, soft rich tones",
"background|Sihir Loncası Öğrencisi": "cool library daylight, a pale blue chalk glow off the floor",
"background|Lonca Ajanı": "night alley, one lit window across the way, most of the figure in shadow",
"background|Rıhtım İşçisi": "hard harbour sun, sweat and salt catching the light",
"background|Gemi Kaptanı": "bright sea light at the gangplank, wind, water glare behind",
"background|Paladin Askeri": "flat overcast drill-yard light, white cloak against white limestone, cold grey sky",
"background|Paladin Rütbelisi": "clean castle daylight, a hard highlight on polished plate, white wax bright on the order",
"subclass|Kayıt Ruhu": "a warm lamplit register hall, the ink lines glowing faint blue-white off the hand",
"subclass|Pul Bağıtlısı": "fog-diffused plateau light, amber rune glow on the stone, the drake lit cool from above",
"animal|Pullu": "wet overcast plateau light, cold and clear, hard scales catching a dull sheen",
}

# Kart basina isik yoksa kategori yedegi (normalde kullanilmamali).
LIGHT_FALLBACK = {
    "location": "directional daylight with real shadows, weather in the sky, depth haze",
    "npc": "directional light from one side, the background in softer light than the face",
    "lore": "one strong light source, deep shadow behind",
}
LIGHT_DEFAULT = "one clear directional light source, honest shadows, depth behind"


def key_of(job: dict) -> str:
    return f"{job['category']}|{job['name']}"


def build(job: dict, orig_subject: str) -> str:
    k = key_of(job)
    subject = SUBJECT.get(k, orig_subject).strip().rstrip(". ")
    framing = FRAMING.get(k) or FRAMING_BY_CATEGORY.get(job["category"], SYMBOL)
    light = LIGHT.get(k) or LIGHT_FALLBACK.get(job["category"], LIGHT_DEFAULT)
    flavor = FLAVOR[int(job["uuid"][:8], 16) % len(FLAVOR)]
    era = f"{ERA}, " if job["category"] in ERA_CATEGORIES else ""
    return (f"{subject}\n"
            f"{framing}, {light}, {era}{DND}, {FULL_BLEED}, "
            f"{STYLE}, {TAIL}, {flavor}")


def main() -> None:
    p = argparse.ArgumentParser(description="Aegis art prompt'larini elden gecir")
    p.add_argument("--src", type=Path, default=BASE / "art_jobs_final.orig.jsonl")
    p.add_argument("--out", type=Path, default=BASE / "art_jobs_final.jsonl")
    p.add_argument("--check", action="store_true", help="yazma, sadece dogrula")
    p.add_argument("--show", type=str, help="tek bir kartin prompt'ini bas (kategori|ad)")
    args = p.parse_args()

    jobs = [json.loads(l) for l in args.src.read_text().splitlines() if l.strip()]
    keys = {key_of(j) for j in jobs}

    # Sozluk anahtarlari gercek kartlara oturuyor mu (Turkce harf/typo yakalar)
    bad = sorted((set(SUBJECT) | set(LIGHT) | set(FRAMING)) - keys)
    if bad:
        print("HATA: karsiligi olmayan anahtar(lar):", file=sys.stderr)
        for b in bad:
            print("  " + b, file=sys.stderr)
        sys.exit(1)

    missing = sorted(k for k in keys if k not in LIGHT)
    if missing:
        print(f"UYARI: {len(missing)} kartta kart-ozel isik yok: {missing}", file=sys.stderr)

    out = []
    for j in jobs:
        subject = j["prompt"].split("\n")[0]
        out.append({**j, "prompt": build(j, subject), "source": "handwritten"})

    if args.show:
        for j in out:
            if key_of(j) == args.show:
                print(j["prompt"])
        return

    rewritten = sum(1 for j in out if key_of(j) in SUBJECT)
    print(f"{len(out)} kart | {rewritten} konu yeniden yazildi | "
          f"{len(LIGHT)} kart-ozel isik", file=sys.stderr)

    if args.check:
        for j in out:
            assert "hand-painted oil painting" in j["prompt"]
            assert "full-bleed square artwork" in j["prompt"]
            assert "Dungeons & Dragons" in j["prompt"]
            assert j["prompt"].count("\n") == 1
        # eski sabit isik kuyruklari sizmasin
        for dead in ("flat overcast daylight, pale diffused sky",
                     "warm hearth glow from one side",
                     "deep earthy tones, weathered parchment hues"):
            leaked = [key_of(j) for j in out if dead in j["prompt"]]
            assert not leaked, f"eski kuyruk sizdi: {dead} -> {leaked}"
        print("OK", file=sys.stderr)
        return

    args.out.write_text("".join(json.dumps(j, ensure_ascii=False) + "\n" for j in out))
    print(f"yazildi: {args.out}", file=sys.stderr)


if __name__ == "__main__":
    main()
