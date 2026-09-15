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

-- chatcommands.lua
-- NPC Core commands.
--   * /npc            - GUI
--   * /npc_spawn      - create from template
--   * /npc_here       - move to self
--   * /npc_remove     - delete nearest
--   * /npc_delete     - delete by id (works for unloaded)
--   * /npc_list       - list (paginated)
--   * /npc_count      - statistics
--   * /npc_yaw        - rotate

local S = minetest.get_translator("npc_core")

local LIST_PER_PAGE = 20


-- ---------------------------------------------------------------------------
-- Main command
-- ---------------------------------------------------------------------------

minetest.register_chatcommand("npc", {
	privs = { npc_admin = true },
	description = S("Open NPC admin panel"),

	func = function(name)
		local player = minetest.get_player_by_name(name)
		if not player then return end

		npc_core.admin.show_main(player)
		return true
	end,
})


-- ---------------------------------------------------------------------------
-- Spawn
-- ---------------------------------------------------------------------------

minetest.register_chatcommand("npc_spawn", {
	privs = { npc_admin = true },
	params = "<def_id>",
	description = S("Create NPC from template in front of you"),

	func = function(name, param)
		if not param or param == "" then
			return false, S("Specify def_id (e.g. template)")
		end

		local player = minetest.get_player_by_name(name)
		if not player then return false, S("Player not found") end

		local id, err = npc_core.spawn_npc(player, param)

		if id then
			return true, S("NPC created: @1", id)
		else
			return false, S("Error: @1", err or "unknown")
		end
	end,
})


-- ---------------------------------------------------------------------------
-- Move
-- ---------------------------------------------------------------------------

minetest.register_chatcommand("npc_here", {
	privs = { npc_admin = true },
	description = S("Move nearest NPC to yourself"),

	func = function(name)
		local player = minetest.get_player_by_name(name)
		if not player then return false, S("Player not found") end

		local npc = npc_core.get_nearest_npc(player:get_pos(), 5)
		if not npc then return false, S("NPC not found nearby") end

		local data = npc.npc_data
		if not data then return false, S("No data in NPC") end

		local target = player:get_pos()

		npc.object:set_pos(target)

		data.pos = {x = target.x, y = target.y, z = target.z}

		npc_core.registry.update_pos(data.id, target, data.yaw)
		npc_core.registry.flush()

		return true, S("NPC moved")
	end,
})


-- ---------------------------------------------------------------------------
-- Delete
-- ---------------------------------------------------------------------------

-- Internal: delete NPC by id.
-- Works whether NPC is active or in unloaded chunk.
local function delete_npc_by_id(id)
	if not id then return false, S("Specify id") end

	local entry = npc_core.registry.get(id)

	local npc = npc_core.npcs[id]
	if npc and npc.object then
		npc.object:remove()
		npc_core.npcs[id] = nil
	end

	npc_core.registry.remove(id)
	npc_core.registry.flush()

	-- If chunk unloaded - force-load it so engine clears entity from staticdata
	if entry and entry.pos and not npc then
		local pos = entry.pos

		minetest.emerge_area(
			{x = pos.x - 1, y = pos.y - 1, z = pos.z - 1},
			{x = pos.x + 1, y = pos.y + 1, z = pos.z + 1},
			function(blockpos, action, calls_remaining)
				if calls_remaining > 0 then return end

				local objects = minetest.get_objects_inside_radius(pos, 2)

				for _, obj in ipairs(objects) do
					local ent = obj:get_luaentity()
					if ent and ent.npc_data and ent.npc_data.id == id then
						obj:remove()
					end
				end
			end
		)
	end

	return true, S("Deleted: @1", id)
end


minetest.register_chatcommand("npc_remove", {
	privs = { npc_admin = true },
	description = S("Delete nearest NPC (radius 5)"),

	func = function(name)
		local player = minetest.get_player_by_name(name)
		if not player then return false, S("Player not found") end

		local npc = npc_core.get_nearest_npc(player:get_pos(), 5)
		if not npc then return false, S("NPC not found nearby") end

		return delete_npc_by_id(npc.npc_data.id)
	end,
})


minetest.register_chatcommand("npc_delete", {
	privs = { npc_admin = true },
	params = "<id>",
	description = S("Delete NPC by id (works for unloaded)"),

	func = function(name, param)
		if not param or param == "" then
			return false, S("Specify id")
		end

		return delete_npc_by_id(param)
	end,
})


-- ---------------------------------------------------------------------------
-- List / statistics
-- ---------------------------------------------------------------------------

minetest.register_chatcommand("npc_list", {
	privs = { npc_admin = true },
	params = "[page]",
	description = S("List of active NPCs (paginated)"),

	func = function(name, param)
		local page = tonumber(param) or 1
		if page < 1 then page = 1 end

		local list = {}

		for id, npc in pairs(npc_core.npcs) do
			local def_name = npc.npc_data and npc.npc_data.def or "?"
			local def = npc_core.npc_defs[def_name]
			local display = def and def.name or def_name

			table.insert(list, id .. " = " .. display)
		end

		if #list == 0 then
			return true, S("No active NPCs nearby")
		end

		table.sort(list)

		local total_pages = math.ceil(#list / LIST_PER_PAGE)
		if page > total_pages then page = total_pages end

		local first = (page - 1) * LIST_PER_PAGE + 1
		local last = math.min(page * LIST_PER_PAGE, #list)

		local result = {}

		for i = first, last do
			table.insert(result, list[i])
		end

		local header = S("Active NPCs (@1), page @2/@3",
			#list, page, total_pages)

		return true, header .. "\n" .. table.concat(result, "\n")
	end,
})


minetest.register_chatcommand("npc_count", {
	privs = { npc_admin = true },
	description = S("NPC statistics"),

	func = function()
		local active = 0
		for _ in pairs(npc_core.npcs) do active = active + 1 end

		local total = 0
		for _ in pairs(npc_core.registry.index) do total = total + 1 end

		return true, S("Active: @1", active) .. "\n"
			.. S("Total in index: @1", total)
	end,
})


-- ---------------------------------------------------------------------------
-- Rotate
-- ---------------------------------------------------------------------------

minetest.register_chatcommand("npc_yaw", {
	params = "<angle>",
	privs = { npc_admin = true },
	description = S("Rotate nearest NPC to given angle"),

	func = function(name, param)
		local angle = tonumber(param)
		if not angle then return false, S("Example: /npc_yaw 90") end

		local player = minetest.get_player_by_name(name)
		if not player then return false, S("Player not found") end

		local npc = npc_core.get_nearest_npc(player:get_pos(), 5)
		if not npc then return false, S("NPC not found nearby") end

		npc.npc_data.yaw = math.rad(angle)
		npc.object:set_yaw(npc.npc_data.yaw)

		npc_core.registry.update_pos(
			npc.npc_data.id, npc.object:get_pos(), npc.npc_data.yaw)
		npc_core.registry.flush()

		return true, S("NPC rotated to @1", angle)
	end,
})


-- ---------------------------------------------------------------------------
-- Utility: nearest NPC via engine spatial index
-- ---------------------------------------------------------------------------

function npc_core.get_nearest_npc(pos, radius)
	radius = radius or 5

	local objects = minetest.get_objects_inside_radius(pos, radius)

	local nearest = nil
	local nearest_dist = radius

	for _, obj in ipairs(objects) do
		local ent = obj:get_luaentity()

		if ent and ent.npc_data and ent.npc_data.id then
			local d = vector.distance(pos, obj:get_pos())

			if d <= nearest_dist then
				nearest = ent
				nearest_dist = d
			end
		end
	end

	return nearest
end
