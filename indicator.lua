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

-- indicator.lua
-- Візуальні індикатори над NPC.

local S = minetest.get_translator("npc_core")

npc_core.indicators = {
	enabled = true,
	mode = "all",
	hide_distance = 32,
	min_interval = 2,
	max_interval = 6,
}

local ICON_SHOP     = "$"
local ICON_TELEPORT = "→"
local ICON_DIALOG   = "!"

local nametag_visible = {}
local nametag_timer = 0

local check_all_nametags


-- ---------------------------------------------------------------------------
-- Збереження / завантаження налаштувань
-- ---------------------------------------------------------------------------

local function save_indicator_settings()
	if not npc_core.storage or not npc_core.storage.save_settings then
		return
	end

	local settings = npc_core.storage.load_settings() or {}

	settings.indicator_mode = npc_core.indicators.mode
	settings.indicator_enabled = npc_core.indicators.enabled
	settings.indicator_hide_distance = npc_core.indicators.hide_distance

	npc_core.storage.save_settings(settings)
end


local function load_indicator_settings()
	if not npc_core.storage or not npc_core.storage.load_settings then
		return
	end

	local settings = npc_core.storage.load_settings()

	if settings.indicator_mode then
		npc_core.indicators.mode = settings.indicator_mode
	end

	if settings.indicator_enabled ~= nil then
		npc_core.indicators.enabled = settings.indicator_enabled
	end

	if settings.indicator_hide_distance then
		npc_core.indicators.hide_distance =
			settings.indicator_hide_distance
	end
end


-- Завантажуємо при ініціалізації моду
load_indicator_settings()


local function build_nametag(def)
	if not def then return "?" end
	if not npc_core.indicators.enabled then return "" end

	local mode = npc_core.indicators.mode
	if mode == "none" then return "" end

	local icons = ""

	if mode == "all" or mode == "icons" then
		if def.trade and #def.trade > 0 then
			icons = icons .. ICON_SHOP
		end
		if def.teleports and #def.teleports > 0 then
			icons = icons .. ICON_TELEPORT
		end
		if def.pages then
			icons = icons .. ICON_DIALOG
		end
	end

	local name = ""
	if mode == "all" or mode == "name" then
		name = def.name or "?"
	end

	if icons ~= "" and name ~= "" then
		return "[" .. icons .. "] " .. name
	end
	if icons ~= "" then
		return "[" .. icons .. "]"
	end
	return name
end


function npc_core.update_npc_nametag(npc)
	if not npc or not npc.object then return end
	if not npc.npc_data then return end

	local def = npc_core.npc_defs[npc.npc_data.def]
	if not def then return end

	npc.object:set_properties({
		nametag = build_nametag(def),
		nametag_color = "#ffffff",
	})

	nametag_visible[npc.npc_data.id] = nil
end


-- Встановити видимість (викликається з check_all_nametags)
local function set_nametag_visible(npc, visible)
	if not npc.object then return end

	if visible then
		npc.object:set_nametag_attributes({
			color = {a = 255, r = 255, g = 255, b = 255},
		})
	else
		npc.object:set_nametag_attributes({
			color = {a = 0, r = 255, g = 255, b = 255},
		})
	end
end


-- Публічна — примусово приховати nametag одного NPC і оновити кеш
function npc_core.hide_nametag_now(npc)
	if not npc or not npc.object or not npc.npc_data then return end

	set_nametag_visible(npc, false)
	nametag_visible[npc.npc_data.id] = false
end


function npc_core.refresh_all_nametags()
	for _, npc in pairs(npc_core.npcs) do
		npc_core.update_npc_nametag(npc)
	end
	check_all_nametags()
end


function npc_core.forget_nametag(id)
	nametag_visible[id] = nil
end


function npc_core.set_indicator_mode(mode)
	local valid = {all = true, name = true, icons = true, none = true}

	if not valid[mode] then
		return false, S("Invalid mode. Available: all, name, icons, none")
	end

	npc_core.indicators.mode = mode
	save_indicator_settings()
	npc_core.refresh_all_nametags()

	return true, S("Indicator mode: @1", mode)
end


function check_all_nametags()
	if not npc_core.indicators.enabled then return end

	local players = minetest.get_connected_players()
	local should_be_visible = {}

	-- 1. Запитуємо «хто поруч» у кожного гравця
	if #players > 0 then
		local hide_dist = npc_core.indicators.hide_distance

		for _, player in ipairs(players) do
			local ppos = player:get_pos()
			local objects = minetest.get_objects_inside_radius(ppos, hide_dist)

			for _, obj in ipairs(objects) do
				local ent = obj:get_luaentity()
				if ent and ent.npc_data and ent.npc_data.id then
					should_be_visible[ent.npc_data.id] = true
				end
			end
		end
	end

	-- 2. Проходимось по ВСІХ активних NPC і встановлюємо стан,
	--    ТІЛЬКИ якщо він змінився (або невідомий).
	local mode_none = npc_core.indicators.mode == "none"

	for id, npc in pairs(npc_core.npcs) do
		if npc.object then
			local should = (not mode_none) and (should_be_visible[id] or false)

			if nametag_visible[id] ~= should then
				set_nametag_visible(npc, should)
				nametag_visible[id] = should
			end
		else
			nametag_visible[id] = nil
		end
	end

	-- 3. Прибираємо з кешу NPC, яких більше немає
	for id in pairs(nametag_visible) do
		if not npc_core.npcs[id] then
			nametag_visible[id] = nil
		end
	end
end


local function get_check_interval()
	local n = #minetest.get_connected_players()

	if n <= 10 then
		return npc_core.indicators.min_interval
	elseif n <= 40 then
		return npc_core.indicators.min_interval + 1
	elseif n <= 80 then
		return npc_core.indicators.min_interval + 2
	else
		return npc_core.indicators.max_interval
	end
end


minetest.register_globalstep(function(dtime)
	nametag_timer = nametag_timer + dtime

	if nametag_timer >= get_check_interval() then
		nametag_timer = 0
		check_all_nametags()
	end
end)


minetest.register_on_joinplayer(function()
	minetest.after(1, check_all_nametags)
end)


minetest.register_on_leaveplayer(function()
	check_all_nametags()
end)


minetest.register_chatcommand("npc_indicators", {
	privs = { npc_admin = true },
	params = "<all|name|icons|none>",
	description = S("Set nametag indicator mode above NPCs"),

	func = function(name, param)
		if not param or param == "" then
			return true, S("Current mode: @1", npc_core.indicators.mode)
				.. "\n" .. S("Available: all, name, icons, none")
		end

		return npc_core.set_indicator_mode(param)
	end,
})
