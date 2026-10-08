# SRD Türkçe — sürüm notu taslağı

Sürüm yükseltilince (`docs/VERSION-BUMP-GUIDE.md` §5) aşağıdaki bölümler o sürümün notuna
taşınır; başlık, tarih ve sürüm numarası orada yazılır. Notlar İngilizce (`RELEASE_NOTES.md` dili).

---

### Highlights

- **SRD content in Turkish** — all 6,404 texts of the SRD 5.2.1 pack (spells, monsters, items, classes, species, feats, rules) now show in Turkish when the app language is Turkish.

---

### SRD content in Turkish

#### The whole SRD, in your language
When the app language is Turkish, every SRD card shows in Turkish: names, descriptions, field labels, monster actions and spell text. Terms follow the official Turkish Baldur's Gate 3 and Baldur's Gate: Enhanced Edition translations, so they match what Turkish players already know. Your data is not changed: cards are still stored in English, and switching the language back shows English at once.

#### Every player sees their own language
Each device shows SRD content in its own app language. If the DM plays in Turkish and a player plays in English, the player sees the shared cards and the battle map in English, and the DM sees them in Turkish. The DM's second window and screencast follow the DM's language.

#### Where it shows
Card lists and cards, the card picker and preview, the character sheet (ability scores, saving throws, skills, class resources, header chips), the character builder, level-up choices, combat tracker and battle map tokens, conditions, the mind map, and everything projected to players.

- Search finds a card by its English or its Turkish name ("Fireball" and "Ateştopu" both work).
- A name you typed yourself (a renamed monster like "Goblin 2", your own card text) stays as you wrote it.

---

### Smaller improvements

- **Level-up choices** — "Pick 2 spells", "Choose a subclass" and the other level-up labels, plus the spell summary in the level-up window, are now translated.
- **Character list** — the HP and AC chips are labeled in your language.
- **Turkish headings** — upper-case headings now write "İ" correctly in Turkish ("KABİLİYET", not "KABILIYET").
- **l10n** — new keys for level-up choice labels, the level-up spell summary and the HP / AC / proficiency bonus labels in English, Turkish, German and French.

---

### Known issues

- **Map pin labels** keep the name a pin had when it was placed; they are not translated.
- **Combat log** lines stay in English.

---

### For developers

- **Display-only translation** — tables live in `assets/srd_l10n/<lang>/<scope>.json` (English text → translation); `ContentTranslator` applies them at render time. Data, refs and the rules engine never see a translation.
- **Projection** — payloads stay English and carry scopes (`EntitySnapshot.parts`, `TokenSnapshot.nameScope`); each receiver translates.
- **CI guard** — `test/tool/srd_l10n_coverage_test.dart` fails on any SRD text without a translation and on any table key no longer in the source. After changing SRD text, run `dart run tool/srd_l10n/bin/extract.dart` and translate the new keys.
