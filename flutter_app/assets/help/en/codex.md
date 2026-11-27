# Codex

The world's encyclopedia. Every NPC, monster, location, item, spell and faction is a **card**. Categories and fields come from the world's [template](help:templates).

## Cards

- **Sidebar**: every card by category, with search and filters. Toggle it from the top bar.
- **Create** a card in a category and fill its fields. Needs **Edit mode**.
- **Text fields** take **Markdown**. Type `@` to mention a card; mentions become links. Long-press a link for a quick preview.
- **Card-link fields** point to other cards (a monster's actions, a character's class). Use **+** to pick; it ranks by name, tag and text and shows suggested rows.
- **Images**: right-click (long-press on touch) an image and pick **Project** to show it to players. [Player screen](help:projection)
- **DM notes** are private; players never receive them.
- **Built-in** cards (SRD content) cannot be deleted.

## Content from packages

**Import Package** adds a [package](help:packages)'s cards. The dialog checks the template:

- **Perfect match**: imports as is.
- **Compatible with differences**: fields are matched by key; fields this world does not have stay stored on the card but are not shown.
- **Incompatible**: can be forced; cards from categories the world does not have are skipped.

A package card follows the package's updates until you edit it in the world; from then on it is the world's own card.

## Sharing with players

In an [online world](help:online-play) players see **no card** until you share it. **Share with players** on a card:

- **All players**, or
- **Individual players** you pick.

The sidebar filter shows *shared*, *not shared* and *built-in (always shared)*. You can mark cards before going online; they go out when the world does.

How it works: shared cards are copied into each player's own app. The server strips DM notes and DM-only fields before sending. If you unshare a card, the player keeps the last copy, shown greyed out.
