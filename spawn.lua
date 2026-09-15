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

local S = minetest.get_translator("npc_core")


-- Перевірити, чи місце вільне від інших активних NPC.
local function is_free(pos, radius)
	radius = radius or 1.0

	local objects = minetest.get_objects_inside_radius(pos, radius)

	for _, obj in ipairs(objects) do
		local ent = obj:get_luaentity()
		if ent and ent.npc_data and ent.npc_data.id then
			return false
		end
	end

	return true
end


-- Створити NPC перед гравцем.
function npc_core.spawn_npc(player, def_id)
	if not player then return nil, S("Player not found") end
	if not def_id then return nil, S("Def not specified") end

	local def = npc_core.npc_defs[def_id]
	if not def then
		return nil, S("Def not found: @1", def_id)
	end

	local ppos = player:get_pos()
	local dir = player:get_look_dir()

	local target = {
		x = ppos.x + dir.x * 2,
		y = ppos.y,
		z = ppos.z + dir.z * 2,
	}

	if not is_free(target, 1.0) then
		return nil, S("Place occupied by another NPC")
	end

	local id = npc_core.generate_id()

	local vec = vector.subtract(ppos, target)
	local yaw = minetest.dir_to_yaw(vec)

	local npc_data = {
		id = id,
		def = def_id,
		pos = target,
		yaw = yaw,
	}

	local obj = minetest.add_entity(
		target,
		"npc_core:npc",
		minetest.serialize(npc_data)
	)

	if not obj then
		return nil, S("Failed to create entity")
	end

	if not npc_core.npcs[id] then
		local ent = obj:get_luaentity()
		ent.npc_data = npc_data
		npc_core.npcs[id] = ent
		npc_core.registry.register(id, npc_data)

		if npc_core.update_npc_nametag then
			npc_core.update_npc_nametag(ent)
		end
	end

	npc_core.registry.flush()

	return id
end
