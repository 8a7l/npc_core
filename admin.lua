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

-- admin.lua
-- NPC Core admin panel.

local S = minetest.get_translator("npc_core")

npc_core.admin = {
	selected_world = {},
	selected_def   = {},
	world_list     = {},
	def_list       = {},
}


local function safe_text(str)
	return (str:gsub(",", "·"))
end


-- ---------------------------------------------------------------------------
-- Move NPC
-- ---------------------------------------------------------------------------

local function move_npc_to(npc, target_pos)
	if not npc or not npc.object then
		return false, S("NPC not found: @1", "?")
	end

	local data = npc.npc_data
	if not data then
		return false, S("No data in NPC")
	end

	npc.object:set_pos(target_pos)

	data.pos = {
		x = target_pos.x,
		y = target_pos.y,
		z = target_pos.z,
	}

	npc_core.registry.update_pos(data.id, target_pos, data.yaw)
	npc_core.registry.flush()

	return true
end


-- ---------------------------------------------------------------------------
-- Main menu
-- ---------------------------------------------------------------------------

function npc_core.admin.show_main(player)
	local pname = player:get_player_name()

	local active_count = 0
	for _ in pairs(npc_core.npcs) do
		active_count = active_count + 1
	end

	local total_count = 0
	for _ in pairs(npc_core.registry.index) do
		total_count = total_count + 1
	end

	local def_count = 0
	for _ in pairs(npc_core.npc_defs) do
		def_count = def_count + 1
	end

	minetest.show_formspec(pname, "npc_core:admin_main",
		"size[10,8]" ..
		"label[0.3,0.2;" .. S("NPC Core - Admin panel") .. "]" ..
		"label[0.3,0.7;" ..
			S("Active NPC: @1 (total in index: @2)",
				active_count, total_count) .. "]" ..
		"label[0.3,1.1;" .. S("Templates: @1", def_count) .. "]" ..

		"button[0.3,2;4.5,1;spawn_btn;" .. S("Create NPC") .. "]" ..
		"button[5.2,2;4.5,1;world_btn;" .. S("NPC nearby") .. "]" ..

		"button[0.3,3.3;4.5,1;editor_btn;" ..
			S("Template editor") .. "]" ..
		"button[5.2,3.3;4.5,1;here_btn;" .. S("NPC to me") .. "]" ..

		"button[0.3,4.6;4.5,1;export_btn;" .. S("Export") .. "]" ..
		"button[5.2,4.6;4.5,1;import_btn;" .. S("Import") .. "]" ..

		"button[0.3,5.9;4.5,1;indicators_btn;" ..
			S("Indicators: @1", npc_core.indicators.mode) .. "]" ..
		"button[5.2,5.9;4.5,1;close;" .. S("Close") .. "]"
	)
end


-- ---------------------------------------------------------------------------
-- Create NPC - template selection
-- ---------------------------------------------------------------------------

function npc_core.admin.show_spawn(player)
	local pname = player:get_player_name()

	local entries = {}
	for id, def in pairs(npc_core.npc_defs) do
		local display = def.name or id
		if def.custom then display = display .. " *" end
		table.insert(entries, { name = display, id = id })
	end
	table.sort(entries, function(a, b) return a.name < b.name end)

	local names = {}
	npc_core.admin.def_list = {}

	for _, e in ipairs(entries) do
		table.insert(names, safe_text(e.name))
		table.insert(npc_core.admin.def_list, e.id)
	end

	local selected_idx = 0
	local cur = npc_core.admin.selected_def[pname]
	if cur then
		for i, id in ipairs(npc_core.admin.def_list) do
			if id == cur then selected_idx = i break end
		end
	end

	minetest.show_formspec(pname, "npc_core:admin_spawn",
		"size[10,7]" ..
		"label[0.3,0.2;" .. S("Create NPC - choose template") .. "]" ..
		"label[0.3,0.5;" .. S("* = created via editor") .. "]" ..
		"textlist[0.3,1;6,5;defs;" .. table.concat(names, ",") ..
			";" .. selected_idx .. "]" ..

		"button[6.5,1;3,1;spawn;" .. S("Create nearby") .. "]" ..
		"button[6.5,2.5;3,0.8;back;" .. S("Back") .. "]" ..
		"button[6.5,5;3,0.8;close;" .. S("Close") .. "]"
	)
end


-- ---------------------------------------------------------------------------
-- NPC in world (active only)
-- ---------------------------------------------------------------------------

function npc_core.admin.show_world(player)
	local pname = player:get_player_name()

	local entries = {}
	for id, npc in pairs(npc_core.npcs) do
		local def_id = npc.npc_data and npc.npc_data.def or "?"
		local def = npc_core.npc_defs[def_id]
		local name = def and def.name or def_id

		local pos = npc.object and npc.object:get_pos()
		local pos_str = pos and string.format("(%d %d %d)",
			math.floor(pos.x), math.floor(pos.y), math.floor(pos.z))
			or "(?)"

		table.insert(entries, {
			display = safe_text(name) .. " " .. pos_str,
			id = id,
			sort_key = name,
		})
	end
	table.sort(entries, function(a, b) return a.sort_key < b.sort_key end)

	local names = {}
	npc_core.admin.world_list = {}

	for _, e in ipairs(entries) do
		table.insert(names, e.display)
		table.insert(npc_core.admin.world_list, e.id)
	end

	local list_str = #names > 0 and table.concat(names, ",") or ""

	local selected_idx = 0
	local cur = npc_core.admin.selected_world[pname]
	if cur then
		for i, id in ipairs(npc_core.admin.world_list) do
			if id == cur then selected_idx = i break end
		end
	end

	local title = S("Active NPCs nearby (@1)", #entries)

	minetest.show_formspec(pname, "npc_core:admin_world",
		"size[12,8]" ..
		"label[0.3,0.2;" .. title .. "]" ..
		"label[0.3,0.5;" ..
			S("Only NPCs in loaded chunks shown") .. "]" ..
		"textlist[0.3,1;7,6.5;npcs;" .. list_str ..
			";" .. selected_idx .. "]" ..

		"button[7.5,1;4,0.9;to_me;" .. S("To me") .. "]" ..
		"button[7.5,2.2;4,0.9;edit_def;" ..
			S("Edit template") .. "]" ..
		"button[7.5,3.4;4,0.9;delete;" ..
			S("Delete NPC") .. "]" ..
		"button[7.5,4.6;4,0.9;refresh;" .. S("Refresh") .. "]" ..
		"button[7.5,6;2,0.8;back;" .. S("Back") .. "]" ..
		"button[9.5,6;2,0.8;close;" .. S("Close") .. "]"
	)
end


-- ---------------------------------------------------------------------------
-- Formspec handlers
-- ---------------------------------------------------------------------------

minetest.register_on_player_receive_fields(function(player, formname, fields)
	local pname = player:get_player_name()

	-- Main menu
	if formname == "npc_core:admin_main" then

		if fields.close then
			minetest.close_formspec(pname, "npc_core:admin_main")
			return
		end

		if fields.spawn_btn then
			npc_core.admin.show_spawn(player)
			return
		end

		if fields.world_btn then
			npc_core.admin.show_world(player)
			return
		end

		if fields.editor_btn then
			npc_core.editor.show_list(player)
			return
		end

		if fields.here_btn then
			local npc = npc_core.get_nearest_npc(player:get_pos(), 5)
			if not npc then
				minetest.chat_send_player(pname,
					S("NPC not found nearby"))
				return
			end

			local ok, err = move_npc_to(npc, player:get_pos())

			if ok then
				minetest.chat_send_player(pname, S("NPC moved to you."))
			else
				minetest.chat_send_player(pname, S("Error: @1", err))
			end
			return
		end

		if fields.export_btn then
			npc_core.exporter.show_export(player)
			return
		end

		if fields.import_btn then
			npc_core.exporter.show_import(player)
			return
		end

		if fields.indicators_btn then
			local order = {"all", "name", "icons", "none"}
			local cur = npc_core.indicators.mode
			local next_mode = "all"

			for i, m in ipairs(order) do
				if m == cur then
					next_mode = order[i % #order + 1]
					break
				end
			end

			npc_core.set_indicator_mode(next_mode)
			npc_core.admin.show_main(player)
			return
		end
	end


	-- Create NPC
	if formname == "npc_core:admin_spawn" then

		if fields.close then
			minetest.close_formspec(pname, "npc_core:admin_spawn")
			return
		end

		if fields.defs then
			local event = minetest.explode_textlist_event(fields.defs)
			if event.type == "CHG" or event.type == "DCL" then
				local id = npc_core.admin.def_list[event.index]
				if id then
					npc_core.admin.selected_def[pname] = id
					npc_core.admin.show_spawn(player)
				end
			end
			return
		end

		if fields.spawn then
			local def_id = npc_core.admin.selected_def[pname]
			if not def_id then
				minetest.chat_send_player(pname,
					S("Select template first."))
				return
			end

			local id, err = npc_core.spawn_npc(player, def_id)

			if id then
				minetest.chat_send_player(pname,
					S("NPC created: @1", id))
			else
				minetest.chat_send_player(pname,
					S("Error: @1", err or "unknown"))
			end
			return
		end

		if fields.back then
			npc_core.admin.show_main(player)
			return
		end
	end


	-- NPC in world
	if formname == "npc_core:admin_world" then

		if fields.close then
			minetest.close_formspec(pname, "npc_core:admin_world")
			return
		end

		if fields.npcs then
			local event = minetest.explode_textlist_event(fields.npcs)
			if event.type == "CHG" or event.type == "DCL" then
				local id = npc_core.admin.world_list[event.index]
				if id then
					npc_core.admin.selected_world[pname] = id
					npc_core.admin.show_world(player)
				end
			end
			return
		end

		local sel_id = npc_core.admin.selected_world[pname]
		local npc = sel_id and npc_core.npcs[sel_id]

		if fields.to_me then
			if not npc then
				minetest.chat_send_player(pname, S("Select NPC first."))
				return
			end

			local ok, err = move_npc_to(npc, player:get_pos())

			if ok then
				minetest.chat_send_player(pname, S("NPC moved to you."))
			else
				minetest.chat_send_player(pname, S("Error: @1", err))
			end

			npc_core.admin.selected_world[pname] = nil
			npc_core.admin.show_world(player)
			return
		end

		if fields.edit_def then
			if not npc then
				minetest.chat_send_player(pname, S("Select NPC first."))
				return
			end

			local def_id = npc.npc_data.def
			if not def_id then
				minetest.chat_send_player(pname, S("NPC has no def."))
				return
			end

			npc_core.editor.show_form(player, def_id, false)
			return
		end

		if fields.delete then
			if not npc then
				minetest.chat_send_player(pname, S("Select NPC first."))
				return
			end

			local id = npc.npc_data.id

			npc_core.registry.remove(id)
			npc_core.registry.flush()

			npc.object:remove()
			npc_core.npcs[id] = nil

			npc_core.admin.selected_world[pname] = nil

			minetest.chat_send_player(pname, S("Deleted: @1", id))

			npc_core.admin.show_world(player)
			return
		end

		if fields.refresh then
			npc_core.admin.show_world(player)
			return
		end

		if fields.back then
			npc_core.admin.show_main(player)
			return
		end
	end
end)
