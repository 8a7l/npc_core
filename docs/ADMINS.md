# NPC Core — Admin Guide

A detailed guide for server admins who manage NPCs.

## Table of contents

1. [Getting started](#getting-started)
2. [Creating your first NPC](#creating-your-first-npc)
3. [Writing dialogs](#writing-dialogs)
4. [Setting up a shop](#setting-up-a-shop)
5. [Setting up teleports](#setting-up-teleports)
6. [Indicators](#indicators)
7. [Export / Import](#export--import)
8. [Working with many NPCs](#working-with-many-npcs)
9. [Troubleshooting](#troubleshooting)

---

## Getting started

Grant yourself the admin privilege:

```
/grant <your_name> npc_admin
```

In singleplayer, you already have it (via `server` privilege).

Open the admin panel:

```
/npc
```

The panel shows:
- Active NPC count (near you) and total count (in the world index)
- Number of templates
- Buttons to create, edit, export, and manage

---

## Creating your first NPC

1. `/npc` → **Template editor** → **New NPC**.
2. Fill in:
   - **Name** — display name
   - **Profession** — shown in directory
   - **Location** — shown in directory
   - **Texture** — pick from dropdown (all `npc_*.png` in `textures/`)
   - **Description** — free-form text
3. Click **Save**.
4. Back in the main menu, click **Create NPC** and select your template.
5. The NPC appears 2 blocks in front of you, facing you.

**Tip:** To place an NPC somewhere specific, stand there, then click
**Create NPC**.

---

## Writing dialogs

Every template has **pages**. A page has an ID, text, and options.

### Basic structure

```
start  ──[option]──>  about
  ↑                     │
  └──────[option]───────┘
```

### Creating a page

1. Edit template → **Dialogs** → **New page**.
2. Fill in:
   - **Page ID** — unique string (e.g. `start`, `about`, `shop`)
   - **Text** — dialog text
3. Click **Save**.

**Important:** the page `start` is shown when a player first
right-clicks the NPC. It must exist.

### Adding options

1. Edit the page → **Options** → **Add option**.
2. Fill in:
   - **Option text** — what the player sees
   - **Type** — `next` or `action`
   - **Target** — page ID or action name
3. Click **Save**.

### Types

- **`next`** — jump to another page.
  Target = page ID (e.g. `about`).
- **`action`** — trigger something.
  Target = action name (see below).

### Built-in actions

| Action | What it does |
|--------|--------------|
| `show_shop` | Opens the NPC shop |
| `tp_<N>` | Uses teleport with id N |
| `show_npc_directory` | Opens resident directory |
| `show_info_<def_id>` | Shows info about another NPC |

### Example: a simple dialog

```
Page: start
Text: Hi, traveler. I'm a blacksmith.

Options:
  - Text: "Who are you?"
    Type: next
    Target: about
  - Text: "Show wares"
    Type: action
    Target: show_shop

Page: about
Text: I forge weapons and armor.

Options:
  - Text: "Back"
    Type: next
    Target: start
```

---

## Setting up a shop

1. Edit template → **Trade** → **New**.
2. Fill in:
   - **Name** — item name shown to player
   - **You give** — items player needs to provide
   - **You receive** — items player gets
3. Click **Save**.

### Item format

- `mod:item` — 1 piece
- `mod:item 10` — 10 pieces
- Multiple items — comma-separated: `default:steel_ingot 10, default:iron_lump 5`

### To make the shop visible

Add a `show_shop` action somewhere in the dialog (usually on `start`).

### Example: three trades

```
Trade 1:
  Name: Steel Sword
  You give: default:steel_ingot 10
  You receive: default:sword_steel

Trade 2:
  Name: Steel Axe
  You give: default:steel_ingot 8
  You receive: default:axe_steel

Trade 3:
  Name: Bundle
  You give: default:sword_steel 1, default:sword_stone 1, default:sword_bronze 1
  You receive: default:steel_ingot 10
```

Use the **↑** and **↓** buttons in the editor to reorder trades.

---

## Setting up teleports

1. Edit template → **Teleports** → **New**.
2. Fill in:
   - **Name** — shown in dialog
   - **X / Y / Z** — target coordinates
     - Click **Here** to use your current position
   - **Price** — leave empty for free, or set item (e.g. `default:mese_crystal 1`)
3. Click **Save**.

### To make teleports visible

Add an action `<tp_id>` in the dialog, where `<tp_id>` = `tp_` + the ID.

Example: teleport ID = 1 → action = `tp_1`.

### Example

```
Teleport:
  Name: To City
  X: 100
  Y: 10
  Z: 100
  Price: default:mese_crystal 1

Option:
  Text: "To City (1 Mese Crystal)"
  Type: action
  Target: tp_1
```

---

## Indicators

Set the mode via chat or admin panel:

```
/npc_indicators all
/npc_indicators name
/npc_indicators icons
/npc_indicators none
```

| Mode | What's shown |
|------|--------------|
| `all` | `[$→!] Name` |
| `name` | `Name` |
| `icons` | `[$→!]` |
| `none` | nothing |

The setting is saved globally in `mod_storage`. Individual NPCs cannot
have different modes.

---

## Export / Import

Templates can be exported as JSON files.

### Location

```
worlds/<your_world>/npc_core_exports/
```

### Via chat

```
/npc_export arthur
/npc_import arthur.json
/npc_exports
```

### Via admin panel

- **Export** — select template → **Export**
- **Import** — select file → **Import**

### Use cases

- **Backup** — copy the folder to keep your templates
- **Migration** — move templates between worlds or servers
- **Sharing** — publish JSON on a forum, others can import

**Note:** import always creates a **new** template with a
`imported_N` id. The original is not overwritten.

---

## Working with many NPCs

NPC Core uses a lightweight index in `mod_storage`:

- All NPCs are recorded as `{id, def, pos, chunk, yaw}` — about 100 bytes each.
- Entity data is stored by the engine in chunks (as `staticdata`).
- Only NPCs near players are loaded into RAM.

### What this means

- **10,000 NPCs** → ~1 MB index. Startup is instant.
- **Active NPCs** (near players) — a few hundred at most.
- **Autosave** every 30 seconds — updates position of active NPCs only.

### Performance tips

- **Don't spawn 5000 NPCs in one chunk.** Spread them out.
- **Use `active_block_range`** in `minetest.conf` to control render range:
  ```
  active_block_range = 3
  ```
- **Use `/npc_count`** to see active vs total.
- **For stress test** — the module includes `/npc_stress <count> [radius]`
  (disabled by default, see `init.lua`).

### Cleaning up

To remove all NPCs of one template:

```
/npc_delete <id>
```

For bulk deletion, use the admin panel → **NPC nearby** → **Delete**.

---

## Troubleshooting

**"Place occupied by another NPC"**
- There's already an NPC within 1 block. Move or delete it first.

**NPC doesn't show a nametag**
- `/npc_indicators` might be set to `none`. Set to `all`.
- The NPC might be too far away (`hide_distance` = 32 blocks).

**Dialog doesn't open**
- The template may not have a `pages.start` entry.
- Re-save the template via the editor.

**Shop shows "no wares"**
- The template has no trades. Add at least one via **Trade**.

**Teleport action does nothing**
- Check the action name in the dialog: it must be `tp_<id>`, where `<id>`
  matches the teleport's ID (visible in the teleport editor).

**Changes don't apply to already placed NPCs**
- Texture and nametag update live.
- Dialog / trade / teleport changes take effect on the next click.

**Export file is not found**
- Check `<world>/npc_core_exports/` — that's where files land.
- `/npc_exports` shows all available files.

**Server crashes with "attempt to index nil"**
- Usually means a custom template is missing `pages` or has invalid syntax.
- Check `/npc_editor` for a broken template and fix or delete it.
