# How It Fits Together

## Building blocks

- **Template**: the skeleton of a game system. It defines the **categories** (Monster, Spell, Location…) and each category's **fields** and layout. [Templates](help:templates)
- **Card**: one record in a category, such as an NPC, a spell or a sword. A card holds only field values; its template decides what they mean and how they are shown.
- **World**: one campaign. It holds its cards plus everything else the campaign uses: maps, mind maps, encounters, PDFs, sounds. [Worlds](help:worlds)
- **Package**: a bundle of cards with no campaign around it, for example a bestiary. It is imported into worlds. [Packages](help:packages)
- **Character**: a player character, built on the template's player category. It can belong to a world. [Characters](help:characters)

## How they connect

- Every world and package is built on a template and **keeps its own copy** of it. Deleting or editing the template never breaks them. Edits to your own templates arrive as an update offer the next time the world opens.
- Importing a package brings its cards into the world. A card that came from a package follows the package's updates until you edit it in the world.
- Cards point to each other through `@` mentions in text and through card-link fields (a character's class, a monster's actions).

## Where the rules come from

The built-in **D&D 5e (SRD 5.2.1)** template ships with the SRD content (spells, monsters, items, classes, species…) and the rules logic: the step-by-step character creator, level up, rests, rolls from the sheet.

On this template a character sheet is **computed every time it is shown**, from the cards the character points to: species, class, subclass, background, feats, equipment. Change a feat card and every character with that feat changes with it. If a card a character needs is missing (its package was removed), the sheet still opens and shows a warning.

Your own templates have no rules engine. They get a blank sheet with a guide, level tables, grants and rests you set up yourself. [Your own character sheet](help:free-sheet)

## Where the data lives

A local database on this device is the source of truth. Taking a world or package online adds a cloud copy that is kept in sync; nothing else leaves the device. [Saving & your data](help:saving) · [Playing online](help:online-play)
