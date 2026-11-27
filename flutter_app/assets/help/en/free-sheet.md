# Your Own Character Sheet

How characters work on [your own template](help:templates). The app does not know your rules; it moves cards and numbers the way the template says, and the players read the rest.

## Creating

**New character** with such a template shows a note, then opens a **blank sheet** at level 1 in the player card's layout. If the template has a **Guide**, it walks through it step by step: it scrolls to and highlights a field and shows the step's text. **Back**, **Close** (pauses; **Guide** in the header resumes), **OK**. Nothing is enforced; every field stays editable.

The guide is written in the editor: each step is an optional field plus Markdown text. [Template editor](help:template-editor)

## Levels

- **Level**: the character's main level, on the player card.
- **Level table** categories (Class, Subclass…) give things row by row. Each has a mode:
  - **Separate**: each card has its own level. On **Level up** you pick one card per such category (or add a new one, starting at 1). This is how multiclassing works.
  - **Together**: cards follow the main level; one added later catches up through every row.
- **Level up**: main level +1, picked cards +1, newly reached rows apply, then a **summary**: cards added, items into the Pool, text to read, resources that changed.

## Grants and the Pool

- A card's **Grants** (and its level table rows) pass items to the carrier the moment it joins one of its lists, at any level. Granted cards go into the list that takes their category; a granted card's own grants apply too.
- Whatever no list takes goes into the **Pool**: resources first (tap boxes to spend), then other items grouped by the card that gave them. The Pool is rebuilt from the cards each time; it is not stored.
- Same-name resources: from the same card, the highest reached row wins; from different cards, the larger maximum wins.

## Rests

**Short Rest** and **Long Rest** apply each resource's setting (fill, empty, leave) to the player card's Resource fields, the HP in Combat stats and every resource in the Pool. Nothing else changes; rules like "spend Hit Dice to heal" are applied by hand.

## In combat

Encounter columns come from the template's Combat stats. Each combatant gets its own copy of the values; damage to a player character is written back to the sheet. [Session & combat](help:session)
