-- NPC Core — NPC framework for Luanti (Minetest)
-- Copyright (C) 2026 Vasyl Onufriichuk
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program. If not, see <https://www.gnu.org/licenses/>.

npc_core = {}

-- Реєструємо привілей
minetest.register_privilege("npc_admin", {
	description = "Can manage NPC Core entities and templates",
	give_to_singleplayer = true,
})

-- Стан
npc_core.npc_defs = {}
npc_core.npcs = {}          -- ТІЛЬКИ активні (поруч із гравцями)
npc_core.actions = {}
npc_core.defs = {}
npc_core.editor = {}
npc_core.admin = {}

npc_core.current_options = {}
npc_core.current_shop = {}
npc_core.selected_npc = {}
npc_core.editing = {}

-- Конфігурація
npc_core.debug = false

function npc_core.log(msg)
	if npc_core.debug then
		minetest.log("action", "[npc_core] " .. tostring(msg))
	end
end

function npc_core.generate_id()
	return tostring(os.time()) .. "_" .. math.random(1000, 9999)
end

-- Вбудовані дії
npc_core.actions.show_npc_directory = function(player)
	npc_core.show_npc_directory(player)
end

-- Завантаження файлів
local modpath = minetest.get_modpath("npc_core")

dofile(modpath .. "/storage.lua")
dofile(modpath .. "/registry.lua")

-- Завантажуємо легкий індекс (id → def, pos, chunk, yaw).
-- Самі entity НЕ створюємо — рушій зробить це, коли
-- гравець підійде до чанку.
npc_core.registry.load_state()

dofile(modpath .. "/defs.lua")
dofile(modpath .. "/trade.lua")
dofile(modpath .. "/teleport.lua")
dofile(modpath .. "/entity.lua")
dofile(modpath .. "/spawn.lua")
dofile(modpath .. "/chatcommands.lua")
dofile(modpath .. "/formspec.lua")
dofile(modpath .. "/indicator.lua")
dofile(modpath .. "/export_import.lua")
dofile(modpath .. "/editor.lua")
dofile(modpath .. "/admin.lua")

dofile(modpath .. "/template.lua")

-- Stress-тест вимкнено. Увімкнути ТІЛЬКИ для тестування
-- на локальному сервері.
--
-- dofile(modpath .. "/stress_test.lua")

minetest.register_on_mods_loaded(function()
	npc_core.defs.load_custom()

	-- БЕЗ restore_all() — рушій сам відновить entity
	-- зі staticdata чанків, коли гравець підійде.
end)

minetest.register_on_leaveplayer(function(player)
	local name = player:get_player_name()

	npc_core.current_options[name] = nil
	npc_core.current_shop[name] = nil
	npc_core.selected_npc[name] = nil
	npc_core.editing[name] = nil
end)
