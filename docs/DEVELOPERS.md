# NPC Core — Developer Guide

For mod developers who want to integrate with NPC Core.

## Overview

NPC Core is designed to be extendable:

- **Templates** — Lua tables describing an NPC's appearance and behavior
- **Actions** — functions triggered by dialog options
- **Callbacks** — hooks for custom NPC behavior

## Registering templates

Add your template to `npc_core.npc_defs` **after** NPC Core has loaded.

Create a file in your mod, e.g. `mymod/npc_defs/my_npc.lua`:

```lua
npc_core.npc_defs.my_guard = {
    name = "Guard",
    profession = "Town guard",
    location = "Gate",
    texture = "mymod_guard.png",
    info = "Protects the town.",

    pages = {
        start = {
            text = "Halt! Who goes there?",
            options = {
                { text = "A traveler.", next = "ok" },
                { text = "Attack!",    action = "attack" },
            },
        },
        ok = {
            text = "Move along.",
            options = {
                { text = "Thanks.", next = "start" },
            },
        },
    },
}
```

Load it from your mod's `init.lua`:

```lua
local modpath = minetest.get_modpath("mymod")

minetest.register_on_mods_loaded(function()
    dofile(modpath .. "/npc_defs/my_guard.lua")
end)
```

**Why `register_on_mods_loaded`?** NPC Core creates the
`npc_core.npc_defs` table when it loads. Registering templates from
your `init.lua` runs before that table exists. Use `on_mods_loaded`
to run after.

## Template structure

```lua
{
    name       = "Display name",           -- string
    profession = "Profession",             -- string, optional
    location   = "Location",               -- string, optional
    texture    = "texture.png",            -- string, required
    info       = "Short description",      -- string, optional

    pages      = { ... },                  -- dialog pages, required
    trade      = { ... },                  -- optional
    teleports  = { ... },                  -- optional
}
```

### `pages`

A table of pages indexed by ID:

```lua
pages = {
    start = {
        text = "Text shown to player",
        options = {
            { text = "Option text", next = "page_id" },
            { text = "Option text", action = "action_name" },
        },
    },
}
```

### `trade`

Array of trades:

```lua
trade = {
    {
        name = "Item name",
        need = "mod:item count, mod:item2 count2",
        give = "mod:item count",
    },
}
```

### `teleports`

Array of teleports:

```lua
teleports = {
    {
        id   = 1,
        name = "To City",
        pos  = { x = 100, y = 10, z = 100 },
        cost = "mod:item count",  -- empty string for free
    },
}
```

## Registering custom actions

Actions are global functions callable from any dialog option:

```lua
npc_core.actions.my_action = function(player, npc_name)
    local name = player:get_player_name()
    minetest.chat_send_player(name, "Action triggered!")
end
```

Then in a template:

```lua
options = {
    { text = "Do thing", action = "my_action" },
}
```

The action receives:

- **`player`** — `ObjectRef` of the player
- **`npc_name`** — template ID (string)

## Overriding behavior per-template

You can add callbacks directly to a template:

```lua
npc_core.npc_defs.my_npc.on_rightclick = function(self, clicker)
    minetest.chat_send_player(clicker:get_player_name(),
        "Hello from a custom callback!")
end
```

`self` is the Lua entity, `clicker` is the player.

**Note:** if a template has custom `on_rightclick`, it overrides the
default dialog behavior. To also open a dialog, call:

```lua
npc_core.show_dialog(clicker, "my_npc", "start")
```

## Runtime API

### `npc_core.npc_defs`

Table of all templates:

```lua
for id, def in pairs(npc_core.npc_defs) do
    print(id, def.name)
end
```

### `npc_core.npcs`

Table of **active** entities (near players):

```lua
for id, entity in pairs(npc_core.npcs) do
    print(id, entity.object:get_pos())
end
```

**Important:** this does NOT include NPCs in unloaded chunks.

### `npc_core.registry.index`

Lightweight index of **all** NPCs:

```lua
for id, entry in pairs(npc_core.registry.index) do
    print(id, entry.def, entry.pos)
end
```

Fields per entry: `def`, `pos`, `chunk`, `yaw`.

### `npc_core.registry.register(id, data)`

Register an NPC in the index.

### `npc_core.registry.remove(id)`

Remove an NPC from the index (marks as removed, prevents re-creation).

### `npc_core.registry.update_pos(id, pos, yaw)`

Update position and rotation of an NPC.

### `npc_core.spawn_npc(player, def_id)`

Create an NPC in front of the player. Returns `id` or `nil, err`.

### `npc_core.get_nearest_npc(pos, radius)`

Find nearest active NPC within radius. Returns entity or `nil`.

## Hooks

### `minetest.register_on_mods_loaded`

Load your templates here (see above).

### `minetest.register_on_shutdown`

Autosave runs here. If your mod changes NPC data mid-session, call
`npc_core.registry.flush()` to persist it.

### `npc_core.registry.flush()`

Force-save the index. Normally called every 30 seconds.

## Dialog API

### `npc_core.show_dialog(player, npc_name, page_id)`

Open a dialog page for a player.

### `npc_core.show_custom_dialog(player, npc_name, title, text, options)`

Open an ad-hoc dialog not tied to template pages.

`options` is an array of `{text = "...", next = "..."}` or
`{text = "...", action = "..."}`.

## Storage keys

- `npc_index` — the lightweight index (`npc_core.registry.index`)
- `custom_defs` — templates created via the in-game editor
- `settings` — indicator mode, hide distance

**Do not modify these directly.** Use registry API functions.

## Best practices

1. **Register templates in `on_mods_loaded`.** Never in `init.lua`.
2. **Use unique template IDs.** Prefix with your mod name:
   `mymod_guard`, not just `guard`.
3. **Don't include custom textures in NPC Core.** Put them in your mod's
   `textures/` folder. The editor scans `npc_core/textures/` only —
   other mods' textures work at runtime but won't appear in the dropdown.
4. **Use `S()` for translations** if your templates are shipped with
   your mod (see `locale/npc_core.en.tr` as example).
5. **Avoid heavy operations in actions.** The player is waiting.
6. **Test with `npc_core.debug = true`** to see log messages.

## Example: a shopkeeper who gives a quest

```lua
npc_core.npc_defs.mymod_questgiver = {
    name = "Hermit",
    profession = "Recluse",
    location = "Cave",
    texture = "mymod_hermit.png",

    pages = {
        start = {
            text = "You found me. What do you want?",
            options = {
                { text = "What do you need?",  next = "quest" },
                { text = "Show wares",         action = "show_shop" },
                { text = "Never mind.",        next = "bye" },
            },
        },
        quest = {
            text = "Bring me 10 apples.",
            options = {
                { text = "Accept",  action = "mymod_accept_quest" },
                { text = "Back",    next = "start" },
            },
        },
        bye = {
            text = "Then leave me alone.",
            options = {
                { text = "Back", next = "start" },
            },
        },
    },

    trade = {
        {
            name = "Magic Stone",
            need = "default:gold_ingot 5",
            give = "default:diamond 1",
        },
    },
}

npc_core.actions.mymod_accept_quest = function(player, npc_name)
    local name = player:get_player_name()
    minetest.chat_send_player(name, "Quest accepted: bring 10 apples.")
    -- Your quest tracking logic here
end
```

## Getting help

- Read `npc_core/npc_defs/template.lua` for a minimal example
- Check the admin editor for interactive template structure
- Open an issue on the repository

