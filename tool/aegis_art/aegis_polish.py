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
STYLE = ("hand-painted oil painting, thick oil-painted texture, expressive painterly brushstrokes, "
         "matte finish")
TAIL = ("subtle tonal variation across surfaces, visible brush texture in the paint, "
        "irregular handmade pigment density, classic fantasy tabletop roleplaying game art")
FULL_BLEED = ("full-bleed square artwork, the scene runs off all four edges and is "
              "cropped by them, every pixel out to the corners is part of the scene itself")
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

# --- anakronizm/sacmalik duzeltmeleri (ilk turdan sonra) -----------------
# "crane" celik kule vinci, "jeweller's lamp" modern masa lambasi,
# "great mirror" el aynasi, "winch crank" gemi dumeni cizdirdi.
"location|Rıhtım":
 "Three uneven wooden jetties reaching out over green water at first light, planks sagging "
 "underfoot with the sea showing between them, barrels and crates stacked and marked in chalk "
 "with arrows crosses and numbers instead of stamps, every load moved by hand, a dozen "
 "dockhands hauling by rope and shoulder hook and rolling barrels down the planks, a "
 "two-masted wooden cargo boat and a fishing skiff moored alongside, a barefoot halfling boy "
 "swinging his legs on a barrel, tarred sheds and a sheer cliff rising behind the shore end "
 "of the piers",
"npc|Mine":
 "A short stocky dwarf woman over a hundred years old, red beard worked into one thick braid "
 "with a small iron ring at its end, heavy brows, small watchful eyes and round ears, two red "
 "dents on the bridge of her nose from spectacles, wearing a scarred leather apron, holding a "
 "ring on a mandrel with fine pliers, a cramped back-room bench behind her with files, punches "
 "and a single clay oil lamp burning on an open wick",
"npc|Gümrük Valisi":
 "A short plump human man in his fifties, round clean-shaven face with red cheeks, thin oiled "
 "hair, three rings on his fingers with a dark ruby in one, wearing a dark green "
 "gold-embroidered coat straining at its buttons over the stomach, seated behind a desk of "
 "open ledgers, a tall window behind him looking down on a river mouth crowded with the masts "
 "of wooden sailing ships",
"npc|Nehir Muhafızı Çavuşu":
 "A bony tall human woman in her forties, face reddened and flaking from the river wind, "
 "cracked lips, red hair cut very short, two fingers of her right hand crushed and badly "
 "healed, wearing the guard's blue-grey cloak over leather armour, one hand resting on the "
 "wooden bar of a hand capstan, a stone river tower behind her with a timber ballista on its "
 "top and a great rusted iron chain running down into the water",
"npc|Vinç Ustası":
 "A short muscular gnome in his fifties, coal-black beard shortened in patches by burns, a "
 "clean ring of skin around the eyes left by smoked-glass brass goggles pushed up on his "
 "forehead, the rest of the face darkened with grease, wearing a stained leather apron with "
 "three sizes of iron spanner hanging from his belt, standing on the timber roof platform of "
 "a warehouse beside the oak gear housing and hemp rope drum of a great wooden treadwheel "
 "crane, the masts of sailing ships and stacked stone terraces behind him",
"npc|Kule Nöbetçisi — Vrask":
 "A young powerfully built dragonborn, bronze scales dulled by salt and wind, a row of short "
 "spines running from the back of the head down the neck with one snapped off, bright yellow "
 "eyes, wearing the grey cloak and light armour of a coast watch, one callused hand on the "
 "chain of a great polished bronze signal disc as tall as he is mounted on an iron swivel "
 "frame, a signal tower parapet and an iron fire basin behind him",
"scene|Gümrük Rıhtımı":
 "A customs officer on a stone quay having a crate lid prised open and entering the contents "
 "on a writing board, bolts of cloth and sacks of clove counted out, one sack split and "
 "spilling dark spice across the wet stone, behind him a great wooden treadwheel crane of oak "
 "beams and hemp rope swinging the next load overhead with two men walking inside its wheel, "
 "a moored sailing ship and terraced warehouses beyond",
"scene|Susan Kule":
 "Night on a clifftop signal tower, an iron fire basin burning at the parapet with the next "
 "tower's fire visible far down the coast, a dragonborn watchman standing beside a great "
 "polished bronze signal disc as tall as he is mounted on an iron swivel frame, the watch "
 "register open on a table, wind tearing at the flames, black sea and a chain of distant fires "
 "along the shore",
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
"location|Elymsyr": "clear bright late afternoon, cool white sunlight on pale grey limestone, crisp blue shadows between the terraces, only the painted roofs and awnings carrying colour, sparkling water, faint sea haze",
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
"npc|Başkumandan — Varhan": "clean cold courtyard daylight, hard white highlights on flawless plate, a grey sky above",
"npc|Kapı Komutanı — Nevra": "the shade of a gatehouse arch with cold light from outside, the open register bright under her hand",
"npc|Başkumandan Yardımcısı — Aren": "one shuttered window throwing a single bar of light across a dim stone chamber, most of the face in shadow",
"npc|Kule Nöbetçisi — Vrask": "hard coastal sun and mirror glare, salt haze, bronze scales flashing",
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



# ---------------------------------------------------------------------------
# 0.9.0 v3 — Lucid Triton alt mekanlari (12 kart), sifirdan yazildi.
# Onceki iki tur "donem filmi" gibi cikti: hepsi ayni yumusak gunduz isiginda, goz
# hizasinda, on kalem detay dagilmis halde. v3'un kurali: KART BASINA TEK BASKIN
# GORUNTU, dramatik kamera, tek guclu isik kaynagi, ve 12 kart arasinda isik
# cesitliligi (gece / mavi saat / safak / tepe isigi / mesale). Stil bloklari
# (DND, ERA, FULL_BLEED, STYLE, TAIL, FLAVOR) degismedi.

FRAMING.update({
    "location|Meclis Binası": ("low vantage at the foot of the steps looking up the full height of the facade, "
                               "colossal columns cropped by the top of the frame, the crowd small at their base"),
    "location|Kalem Binası": ("three-quarter view of a tall broad building from across a lane at night, its "
                              "upper storeys rising past the top of the frame, its lit doorway the warm heart of "
                              "the picture, an even larger hall looming behind it, figures small at the step"),
    "location|Kayıt Salonu": ("close on the open ledger in the foreground with the hand and quill large, "
                              "the hall opening out behind it in deep receding perspective"),
    "location|Sınır ve Ticaret Loncası Divanhanesi": ("enormous palatial interior, the ceiling far out of frame, "
                                                     "one small figure dwarfed at the bottom of a huge gilded room, "
                                                     "vast window shaft crossing the whole picture"),
    "location|Büyücü Loncası Akademisi": ("night scene lit from a single source on the ground, faces lit from below, "
                                          "the master silhouetted against the glow, cloister arches receding into dark"),
    "location|Şifacılar Kışlası": ("steam-filled dispensary, shelves of glassware towering on both sides, "
                                   "an arch at the back opening onto rows of cots, strong lamp light in the middle"),
    "location|Yukarı Çarşı": ("extreme foreground close on a workbench with hands at work, "
                              "the sunlit arcade market blazing away behind in deep perspective"),
    "location|Aşağı Çarşı": ("dusk, crush of stalls in the lower two thirds lit by braziers, "
                             "the vast wall above catching the last daylight, strong warm and cool split"),
    "location|Mimar Meydanı": ("blue hour, immense open square stretching far back to distant marble facades, "
                               "the colossal statue towering over a tiny crowd, ring after ring of lamps being lit, "
                               "long reflections running across a huge expanse of wet marble"),
    "location|Şehir Kapıları": ("close three-quarter view from just above the water, the gatehouse and the near "
                                "span of the bridge filling most of the frame, the bridge deck running diagonally "
                                "out of the bottom corner, only a narrow band of city roofs above the wall, cool "
                                "grey-blue stone against warm lamplight"),
    "location|Sessiz Sokak": ("night, close on a wall niche full of candle flames with a face lit beside it, "
                              "the alley falling away behind into blue dark"),
    "location|Nehir Yükleme Alanı": ("dawn mist, steep upward shot from water level, a sheer wall of stone rising "
                                     "the full height of a tall vertical frame with its battlements near the very "
                                     "top, cranes leaning out far overhead, barges and shacks tiny along the foot, "
                                     "extreme scale contrast"),
})

LIGHT.update({
    "location|Meclis Binası": "hard high midday sun blazing off white marble, deep black shade inside the portico, shadows of the columns thrown across the steps",
    "location|Kalem Binası": "night, one warm lamp burning over a doorway, a cold blue moonlit wall above, breath visible in the air",
    "location|Kayıt Salonu": "a single steep shaft of daylight from a high window landing straight on the open page, the rest of the hall in warm brown shade",
    "location|Sınır ve Ticaret Loncası Divanhanesi": "one enormous cold grey shaft from a two storey window cutting across a great dim hall, dust hanging in it, pale marble and dark wood taking the light, a few small gilded mouldings catching faint sparks far up in the gloom, a cold swept hearth",
    "location|Büyücü Loncası Akademisi": "night, a cold blue-white glow rising out of a chalk circle on the ground as the only real light, warm amber squares of library windows above",
    "location|Şifacılar Kışlası": "warm lamp and brazier light through dense steam, glass and copper catching highlights, cold green daylight at the far arch",
    "location|Yukarı Çarşı": "a forge brazier glowing on the bench in the foreground, brilliant white sunlight flooding the arcade behind, strong contrast between the two",
    "location|Aşağı Çarşı": "last orange daylight on the top of the wall, the lane below already in blue shadow lit by charcoal braziers and hanging oil lamps",
    "location|Mimar Meydanı": "deep blue twilight, the first lamps burning warm gold in a ring around the square, marble going violet, one lamp still dark",
    "location|Şehir Kapıları": "overcast dusk, cold grey-blue light on pale stone and slate roofs, warm orange lantern and torch glow pooling in the gate passages and along the bridge, the wide river below burning gold with reflected sky, smoke from chimneys drifting",
    "location|Sessiz Sokak": "night, dozens of small candle flames in wall niches as the only light, warm on faces and stone, deep blue dark above",
    "location|Nehir Yükleme Alanı": "cold grey dawn with river mist, torches still burning on the quay, a thin band of pink light on the top of the wall",
})

SUBJECT.update({
"location|Meclis Binası":
 "The towering white marble front of a guild assembly building seen from the foot of its steps, "
 "colossal fluted columns rising past the top of the frame, six enormous banners hung the full "
 "height between them each bearing one guild sigil, a hammer, a balance scale, a pair of "
 "compasses, a sword, a key, and one banner of plain undyed cloth, a queue of petitioners "
 "winding up the wide steps clutching folios, dwarves, gnomes, halflings and humans among them, "
 "two clerks at a table on the top step turning people back",
"location|Kalem Binası":
 "A substantial four storey marble clerks' hall standing alone on a lane at night, broad "
 "fronted with eleven bays of windows and a heavy cornice, seen from "
 "across the lane, warm lamplight pouring out of its tall open doorway and down the worn hollow "
 "of its threshold onto the flagstones, a lantern on an iron bracket beside the door, both its "
 "upper windows shuttered but two showing a thin line of candlelight, a short queue of three "
 "people waiting on the step with folded papers held against their chests, a gnome among them "
 "stamping his feet against the cold, and behind the hall the colossal moonlit flank of "
 "the assembly hall rising into the night sky",
"location|Kayıt Salonu":
 "A colossal open registry ledger filling the foreground on a marble table, its page ruled into "
 "four columns of names in brown ink, a clerk's hand with a quill poised over the empty fourth "
 "column, a brass weight and a sand shaker at the page edge, and beyond the book a family "
 "standing waiting, a woman holding an infant and a tiefling man with curling horns behind her, "
 "benches of waiting people receding into the depth of a tall marble hall",
"location|Sınır ve Ticaret Loncası Divanhanesi":
 "The colossal audience hall of a wealthy merchant guild, a deep coffered ceiling of dark "
 "carved oak far above with a thin gilded line picking out its ribs, walls of polished white "
 "and grey-green marble, two storeys of plain carved galleries running around the room packed "
 "with leather ledgers, a two storey arched window pouring one huge grey shaft of light across "
 "an inlaid stone floor, an immense chimneypiece of carved marble with a key cut into its "
 "lintel and a cold swept grate, a long council table of dark polished wood with twenty "
 "high-backed leather chairs and only one occupied, a sweeping double staircase with an iron "
 "balustrade, restrained and severe rather than gilded, and one small clerk alone at the foot "
 "of it filling in a tally sheet",
"location|Büyücü Loncası Akademisi":
 "A chalk circle drawn on the flagstones of a white marble cloister at night, burning with a "
 "cold blue-white light that throws the kneeling students' faces into hard lit relief, a tall "
 "elf master standing at the edge of the circle in silhouette with one hand raised, thin steam "
 "lifting off the dry stone inside the ring, crimson leaved branches black against the glow, "
 "amber library windows burning high above the cloister arches",
"location|Şifacılar Kışlası":
 "A dispensary thick with steam, shelves of glass bottles and stoneware jars towering on both "
 "sides to the ceiling, three copper alembics working over charcoal fires with their coils "
 "dripping, a gnome apprentice halfway up a ladder passing a bottle down, bunches of drying "
 "herbs hung from every beam, and through a broad arch at the back a long dim ward of narrow "
 "cots receding into shadow",
"location|Yukarı Çarşı":
 "A hallmarking bench filling the foreground, a bearded dwarf master's hands holding a steel "
 "punch against a small metal ring with a hammer raised over it, a glowing brazier and a bronze "
 "balance scale at his elbow, struck marks bitten into the bench top, and behind him a great "
 "white marble arcade market in full sunlight, stalls of cloth and fruit and knives under the "
 "arches with licence plaques at every corner and a crowd moving between the piers",
"location|Aşağı Çarşı":
 "A crush of second-hand stalls jammed into a lane at the foot of an enormous marble city wall "
 "at dusk, patched awnings strung wall to wall overhead, charcoal braziers and hanging oil "
 "lamps lighting heaps of mended boots, worn tools and dented pots from below, a halfling "
 "cobbler working with a knife in the foreground, a tiefling and a human leaning close over a "
 "stall with empty hands between them, the top of the wall far above still catching orange "
 "daylight",
"location|Mimar Meydanı":
 "An immense paved marble square at blue twilight, at its centre a colossal statue of a founder "
 "carved entirely from one block of white marble, statue and plinth and every detail the same "
 "pale stone with no metal and no gilding anywhere, a long spear held upright in his right "
 "hand, a thick book held against his side in his left, a shallow round boss of grey-white marble carved "
 "flat against his chest below the throat, its rim in soft stone shadow, the whole figure one "
 "single colour of unpainted pale marble from spear to plinth, only two carved lines cut into the plinth below him, and rising behind him "
 "across the far side of the square an enormous palatial assembly building approached by a very "
 "wide flight of high steps and a deep columned portico at their head, and on its roof exactly "
 "three enormous square stone towers standing in a row, tall slender shafts with crenellated "
 "parapets and narrow slit windows, no bells and no spires and nothing religious, the middle "
 "tower rising twice as high again as the two beside it and towering over everything in the "
 "picture, the hall itself a huge deep block running far back into the city so that its long "
 "flank recedes in perspective behind the towers, storey on storey of stone, the building standing in the middle of a dense city with ordinary three "
 "storey houses, shop fronts, tiled roofs, chimneys and narrow streets pressed up against its "
 "flanks and crowding away behind it, no city wall and no fortification around it, smaller "
 "three storey colonnaded houses and halls crowded along the square on either side of it, rings of wrought iron lamp posts marching away "
 "across the emptiness with lamplighters up ladders lighting them one after another, warm gold "
 "pools spreading on violet wet marble, crimson and orange leaved trees at the square edges "
 "shedding leaves across the paving, a horse-drawn cart crossing the far side, small knots of "
 "people scattered over the vast pavement and one dense crowd near the plinth gathered around a "
 "family whose child holds a new apprentice coat, one lamp at the far edge still dark",
"location|Şehir Kapıları":
 "A massive pale stone gatehouse at dusk seen close from just above the river, two square "
 "crenellated towers flanking one tall lamplit arched passage with portcullis teeth in its "
 "vault, its foot planted on the bank where a long low bridge meets it, and that bridge "
 "swinging out of the bottom of the picture on heavy round arches with thick cutwater piers "
 "standing in the gold-lit water, a stone parapet with iron lamp posts and crooked "
 "timber-framed booths built along it, a small square turret standing astride the bridge "
 "halfway out, ox waggons and handcarts and cloaked travellers crowding through the gate "
 "passage, a clerk with a ledger at a stone kiosk in the archway, spearmen on the tower tops, "
 "a colossal armoured statue on a plinth beside the gate, laden barges passing under the "
 "arches, and only a thin band of steep slate roofs and one distant tower showing above the "
 "battlements behind",
"location|Sessiz Sokak":
 "A wall niche at night crowded with burning candle stubs, offerings pressed in among them, a "
 "heel of bread, a ribbon, a handful of salt, a bird bone, wax running down onto old marble "
 "footings, an old woman's face lit warm from below as she stands before it with her lips "
 "moving, and behind her a very narrow alley falling away into blue dark with more small flames "
 "burning in niche after niche down both walls",
"location|Nehir Yükleme Alanı":
 "A sheer white marble city wall of enormous height at cold misty dawn, rising like a cliff "
 "twenty times the height of the boats at its foot, its battlements far up near the top of the "
 "sky, seen from the water far below, huge "
 "timber crane jibs mounted on top of the battlements and leaning far out over the wall head "
 "into the open air, great treadwheel hoists and counterweights standing behind them on the "
 "wall walk with crews working them, rope falls running from the jib tips all the way down to "
 "the river, a row of small lamplit openings pierced low in the wall face below, net slings and crates of cargo hanging in mid air halfway up, flat-bottomed barges "
 "moored in a row at the foot of the wall with their ropes stretched tight, a cramped strip of "
 "mud between wall and water crowded with crooked wooden shacks and warehouses on stilts "
 "overhanging the river, plank walkways between them, torches still burning, broad shouldered "
 "dwarf labourers hooking sacks onto a rope fall and a halfling clerk writing in a ledger "
 "beside a great timber and iron weighing balance",
})


# ---------------------------------------------------------------------------
# 0.9.1 — Elymsyr turu. Yeni kanon: kent bir kiyi kenti degil bir AGIZ kentidir.
# Iki kanyon duvari arasinda, nehrin genis agzinda, IKI YAKAYA birden kurulu;
# kopru yok, mavna var. Kent iki parca: suya kazik ustune kurulan giris yapilari
# (isler) + kayaya basamak basamak kurulan bal rengi kirectasi teraslar (yasar).
# Kapi HER ZAMAN ACIK; zincir suyun altinda gevsek yatiyor; balistalarin uzeri
# ziftli bezle ortulu (bakim degil, gorunti meselesi). Beyaz mermer DEGIL.

FRAMING.update({
    "location|Gümrük Binası": INTERIOR,
    "location|Aşağı Rıhtım": ("working quay seen from a moored barge at water level, the wharf and the "
                              "warehouse fronts running away on a strong diagonal, the cliff terraces of "
                              "the city rising above them and filling the top of the frame, cargo and "
                              "labourers large in the foreground"),
    "location|Kanyon Asansörleri": ("vertiginous shot from a timber platform pinned to a canyon wall, the "
                                    "opposite wall rising the full height of the frame, the river a narrow "
                                    "green thread far below, extreme vertical scale"),
})

LIGHT.update({
    "location|Gümrük Binası": "steep dusty shafts of daylight from high clerestory windows landing on the chalked floor squares, the rest of the long hall in warm brown shade, one lamp over the weighing scale",
    "location|Aşağı Rıhtım": "cold clear early morning just after sunrise, long low light down the river throwing crane shadows across the quay, steam from a cargo lift catching the sun, water silver",
    "location|Kanyon Asansörleri": "high overhead sun reaching only the upper canyon wall, the gorge below in deep cool shadow, one hot band of light across the timber platforms",
})

SUBJECT.update({
"location|Elymsyr":
 "A great living city built at the wide mouth of a river that bursts out between two enormous "
 "canyon walls into the sea, the city standing on both banks at once and spilling outside the "
 "mouth onto the coast, in the foreground timber landing halls and jetties built out over the "
 "water on driven piles with moored ships alongside, and rising behind them a dense crowded "
 "town climbing the cliff in stacked pale grey and white limestone terraces, cool grey stone not "
 "yellow stone, not warehouses but a city, buildings of every size crowded together, squat "
 "workshops beside four storey merchant houses, slender watchtowers and bell towers standing up "
 "here and there along both cliffsides, tall narrow houses shoulder to shoulder with painted roof "
 "tiles in red, green, "
 "blue and ochre, balconies, washing lines and potted plants between them, striped awnings and "
 "canvas market canopies over a stepped bazaar street packed with stalls, a domed bathhouse, a "
 "temple dome, a caravanserai with an arcaded courtyard, inn signs hanging over lanes, chimney "
 "smoke, stairways and switchback lanes threading between the terraces, a walled governor\'s "
 "palace on the topmost terrace, warehouse quays with gnome built roof cranes only along the "
 "waterline below, and outside the mouth the city carrying straight on out over the open water, "
 "whole streets of houses, taverns and shrines standing on driven piles above the sea linked by "
 "plank causeways and little bridges, the river mouth enormously wide here, a great open harbour basin miles across "
 "opening into the sea, in the middle of the harbour one huge wooden cargo ship dominating the "
 "picture, a high sided three masted carrack with a tall aftcastle, square sails brailed up on "
 "her yards and cargo nets swinging off her side, small boats clustered around her hull, and "
 "around her ships of every other size coming and going, round bellied cogs being warped in, small fishing "
 "skiffs and rowing lighters darting between them, moored ships in rows along both quays, flat ferry barges crossing between the two banks, the two sides of "
 "the city joined by no bridge at all, an unbroken open channel of water from the sea to the "
 "canyon, "
 "two stone watchtowers set into the rock at the throat, crowds of small figures everywhere in "
 "the lanes and on the quays, humans, dwarves, gnomes, halflings, half elves, a tabaxi and a "
 "dragonborn among them, robes, turbans, sailors\' slops, guild coats and foreign dress all "
 "mixed together, laden donkeys and handcarts on the stairs, the canyon narrowing away inland "
 "behind the city, low sun turning cliff, painted roofs and water molten gold",
"location|Gümrük Binası":
 "The interior of a colossal stone customs hall as big as a cathedral nave, a vaulted roof far "
 "overhead carried on two rows of great piers, the hall running so far back that its end is lost "
 "in haze, the flagstone floor ruled into dozens of big chalked squares with one cargo standing in "
 "each, the floor crowded with cargo everywhere, towering stacks of crates, walls of bales, rows of "
 "amphorae in sand cradles, roped barrels, rolled carpets, sacks split open with spice spilling "
 "out, caged birds, ivory tusks, coils of rope and timber baulks leaving barely a lane to walk, "
 "every "
 "square busy, hundreds of people spread right across the hall and in among the cargo, "
 "porters carrying sacks, dockhands levering crate lids open, a cooper hammering a hoop, two men "
 "arguing over a bale, a guard leaning on a spear, only a few clerks with ledgers among them, "
 "humans, dwarves with braided beards, gnomes up stepladders, halflings with tally sticks, half "
 "elves interpreting, a tabaxi sailor and a dragonborn cargo master waiting their turn, robes, turbans, furs, sailors' "
 "slops and guild coats all mixed together, argument and paperwork everywhere, one crate lid levered up with straw pulled out of it by the handful, a great copper "
 "weighing pan hung on chains from the roof beams at the far end of the hall with its chain "
 "swinging, a clerk calling out a figure while another writes it into a ledger, a side doorway "
 "stacked with rolled manifests, armed guards at the entrance watching the crates and not the "
 "people",
"location|Aşağı Rıhtım":
 "A crowded medieval fantasy river quay at the foot of a canyon city before full sunrise, a broad "
 "stone wharf running away along the near bank with a long line of high gabled stone and timber "
 "warehouses behind it, pale grey limestone terraces of the city climbing the cliff face directly "
 "above their roofs, gnome built timber treadwheel cranes standing on the warehouse roofs and "
 "leaning out over the water, a counterweighted rope hoist lifting a stack of crates up towards an "
 "upper terrace, wooden sailing ships and barges moored gunwale to gunwale along the wharf with "
 "gangplanks down, the far bank across the water carrying the same warehouses and cranes, the "
 "wharf packed with work, dwarves and gnomes swarming over a crane\'s gearing with tools, human "
 "porters bent under sacks, halflings marking barrels, a half elf standing at the head of the "
 "jetty folding a paper into a pocket, a tabaxi deckhand coiling rope and a dragonborn cargo "
 "master shouting orders, stacked bales, nets, amphorae and coiled hawsers everywhere on the "
 "stones, mules and handcarts, no machinery but wood, rope and iron",
"location|Kanyon Asansörleri":
 "Timber platforms and narrow plank walkways spiked into the sheer face of a river canyon far "
 "above the water, rope elevators with counterweights and great pulley blocks hanging between "
 "them, a loaded cage lift rising with its boards creaking while ropemen haul below in rhythm, "
 "the opposite canyon wall rising the full height of the picture, the river a narrow green "
 "thread far down with barges on it the size of saucers, bales and barrels stacked waiting on "
 "the platforms",
})


# ---------------------------------------------------------------------------
# 0.11.0 — Votumar kadrosu: dort yeni NPC + Yazilmayan Emir gorevi.
# Ayni kural: kart basina tek baskin goruntu, tek guclu isik kaynagi.
# ---------------------------------------------------------------------------

FRAMING.update({
    "npc|Kıyı Kardeşleri — Kessa, Bram ve Tomas": ("warm three figure group composition, all "
                                                    "three faces visible and lit, the boat and "
                                                    "the open sea behind them, figures large in "
                                                    "frame"),
    "quest|Yazılmayan Emir": ("close three-quarter view down onto the open register on the table, "
                              "the gate and the empty courtyard falling away behind it"),
})

LIGHT.update({
"npc|Ocak Ustası — Torvun":
 "orange forge light from below and one side, the vault overhead lost in dark, coal glow and "
 "sparks the only colour in the frame",
"npc|Şato Kâtibi — Nerion":
 "flat cold daylight through an open shutter with one small warm brazier at his elbow, ink and "
 "paper the brightest things in the room",
"npc|Kıyı Kardeşleri — Kessa, Bram ve Tomas":
 "bright clear morning sun off the water, warm skin tones, the white cliffs glowing behind them "
 "and light bouncing up from the wet stones, the happiest light in the set",
"npc|Gözcü Yüzbaşısı — Drahan":
 "hard late afternoon sun off the sea behind him, his face in its own shadow, the bronze disc "
 "throwing one hard bright reflection",
"quest|Yazılmayan Emir":
 "cold grey daylight from an open gate, the empty column of the page the brightest surface in "
 "the picture",
})

SUBJECT.update({
"npc|Ocak Ustası — Torvun":
 "A short barrel-chested dwarf smith in his sixties standing at the mouth of a forge cut into "
 "living rock, a broad blunt nose and small round human ears, no pointed ears, the lower half of "
 "his face smudged with soot, a thick red beard split into two braids "
 "gathered in leather rings with the ends singed short, no eyebrows, wearing a leather apron "
 "pitted with dozens of small burn holes, one hand on the haft of a hammer resting on an anvil, "
 "behind him the iron gearing and rope drum of a wall winch and the glowing throat of a charcoal "
 "forge, pale limestone vaults overhead, a small ledger and a stub of chalk on the anvil beside him",
"npc|Şato Kâtibi — Nerion":
 "A slender long-fingered elf clerk seated at a writing table in a cold stone record room, the "
 "side of his right hand permanently greyed with ink, hair gathered at the nape with one loose "
 "strand fallen forward, a quill still in his hand but not writing, a small brazier burning at "
 "his elbow and a shutter open to grey daylight, tall shelves of bound watch registers and rolled "
 "supply lists behind him, one register lying open with a page corner turned in",
"npc|Kıyı Kardeşleri — Kessa, Bram ve Tomas":
 "Three teenage siblings laughing together on a stony beach below white limestone cliffs on a "
 "bright morning, a seventeen year old human girl standing beside a small clinker built boat "
 "drawn up on the stones with a net over her shoulder and her hair in one thick braid, wearing a "
 "man's oversized waxed canvas coat with the sleeves rolled twice, a fifteen year old human boy "
 "balanced on the upturned keel pointing out to sea in the middle of a story with his mouth open, "
 "knees patched, and a fourteen year old tiefling boy sitting on the gunwale grinning, red skin, "
 "short backward curving horns, a slim tail with a scrap of rope tied at its tip, tying a knot in "
 "a net cord with that tail to show off, buckets of fish and coiled net on the stones around them, "
 "small coast flowers and a rune scratched into a rock at the waterline, the great white castle "
 "wall far above on the cliff",
"npc|Gözcü Yüzbaşısı — Drahan":
 "An old heavy built dragonborn, a draconic humanoid with a scaled reptilian head and a blunt "
 "muzzle, curved horns swept back from the skull, slit yellow eyes, no hair and no human face, "
 "grey green scales worn thin at the muzzle and on the backs of the hands, a thin straight scar "
 "above the left eye, wearing the grey cloak of a coast watch clasped at one "
 "shoulder, standing with his hands clasped behind his back in the doorway of a signal station, "
 "the line register lying closed on a stool beside him, an iron fire basin and a great polished "
 "bronze signal disc on its swivel frame behind him, a chain of stone towers receding along the "
 "cliffs",
"quest|Yazılmayan Emir":
 "An open watch register on a gatehouse table in a white limestone castle, the column headed for "
 "orders empty down page after page, a quill dried in its stand and a stick of sealing wax never "
 "used, one line of entry with no matching line of return, the great gate standing open beyond "
 "with a single paladin in a white cloak on watch and the courtyard empty behind him",
})


# ---------------------------------------------------------------------------
# 0.13.0 — Votumar'in iki isi: iki gorev karti + muhurlu yazi.
# Gemini'nin cache konulari kanonla celisiyordu (kartal armasi, kirmizi mum,
# tartili kasa defteri); ucu de elle yeniden yazildi.
# ---------------------------------------------------------------------------

LIGHT.update({
"quest|Son Yazılı Emir":
 "cold grey daylight through one shuttered window falling across the table and the folded page, "
 "the rest of the chamber in deep shadow, a single candle burning low beside the wax",
"quest|Sayım Açığı":
 "one lantern hung low in a dark vaulted cellar, warm light on sacking and flagstone, "
 "the far end of the vault going black",
"adventuring-gear|Mühürlü Yazı":
 "one low candle from the left, the white wax the brightest thing in the frame, "
 "deep shadow lying along the fold",
})

SUBJECT.update({
"quest|Son Yazılı Emir":
 "A tall tiefling woman officer in her mid thirties standing behind a writing table in a bare "
 "white limestone chamber, dark red skin, two horns curving back from her brow, glossy black hair "
 "drawn tightly back at the nape, a faint old sword scar on her chin, wearing finely engraved "
 "plate armour under a spotless white cloak with the long grip of a greatsword rising over her "
 "left shoulder, holding out a small letter packet folded shut and closed with a thick oval of "
 "white sealing wax, the packet still sealed and compact in her red fingers, two travellers "
 "reaching weathered hands for it across the table, a slender male elf clerk in his middle years "
 "seated at the table end with close cut hair and the side of his right hand greyed with ink, "
 "blotting a second page with a quill still in his hand, a brass seal matrix and a stub of white "
 "sealing wax and a candle on the boards between them, a soldier in plain undyed civilian clothes "
 "pulling a travelling cloak over his shoulders in the doorway at the back, the door behind her shut",
"quest|Sayım Açığı":
 "A castle supply cellar under low pale limestone vaults, grain sacks stacked in neat courses "
 "against the wall, the stack ending early on one side so the top two courses step down to bare "
 "wall and a clean pale patch of swept flagstone lies in front of that end, wicker baskets of "
 "charcoal with coal dust trodden out in bootprints across the floor, a coiled roll of strap "
 "leather on a trestle with its cut end hanging loose, a slate tally board on the wall carrying "
 "rows of chalk strokes, a stocky broad-shouldered dwarf in his sixties standing before the "
 "stack with an open ledger in one hand, a weathered craggy face with heavy brows and a broad "
 "blunt nose, a thick red beard split into two braids gathered in leather rings, soot on the "
 "lower half of his face, a leather apron pitted with small burn holes, a stub of chalk in his "
 "free hand, a lantern hung from the vault above him",
"adventuring-gear|Mühürlü Yazı":
 "A small letter packet of thick cream castle paper folded shut into a compact rectangle and "
 "lying closed on dark oak boards, the creases pressed sharp and the edges trimmed straight, the "
 "loose flap held down by a thick oval of pure white sealing wax with a tower shield pressed deep "
 "into it, a smaller second stamp bitten into the lower rim of that wax, the wax bridging the "
 "flap and the body of the packet in one unbroken piece, one short line of handwritten dark ink "
 "script across the closed face, a brass seal matrix and a stub of white wax with a softened end "
 "lying beside it, a goose quill and a shallow ink horn at the edge of the boards",
})

if __name__ == "__main__":
    main()
