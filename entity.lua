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

minetest.register_entity("npc_core:npc", {

	initial_properties = {
		visual = "mesh",
		mesh = "character.b3d",
		textures = { "character.png" },

		visual_size = { x = 1, y = 1 },

		collisionbox = { -0.4, 0, -0.4, 0.4, 2, 0.4 },
		selectionbox = { -0.4, 0, -0.4, 0.4, 2, 0.4 },

		physical = true,
		collide_with_objects = true,

		hp_max = 1,
	},

	-- -----------------------------------------------------------------------
	-- Збереження / завантаження
	-- -----------------------------------------------------------------------

	get_staticdata = function(self)
		if self.npc_data and self.object then
			local pos = self.object:get_pos()
			local yaw = self.object:get_yaw()

			if pos then
				self.npc_data.pos = { x = pos.x, y = pos.y, z = pos.z }
			end
			self.npc_data.yaw = yaw

			if npc_core.registry and npc_core.registry.update_pos then
				npc_core.registry.update_pos(self.npc_data.id, pos, yaw)
			end
		end

		return minetest.serialize(self.npc_data)
	end,

	on_activate = function(self, staticdata)
		if staticdata and staticdata ~= "" then
			local data = minetest.deserialize(staticdata)
			if data then
				self.npc_data = data
			end
		end

		if not self.npc_data then
			self.npc_data = { id = "unknown", def = "template" }
		end

		local id = self.npc_data.id

		-- Захист 1: видалений NPC
		if npc_core.registry.removed
			and npc_core.registry.removed[id] then
			self.object:remove()
			return
		end

		-- Захист 2: дублікат
		local existing = npc_core.npcs[id]
		if existing and existing ~= self and existing.object then
			self.object:remove()
			return
		end

		-- Текстура
		local def = npc_core.npc_defs[self.npc_data.def]
		if def and def.texture then
			self.object:set_properties({ textures = { def.texture } })
		end

		-- Поворот
		if self.npc_data.yaw then
			self.object:set_yaw(self.npc_data.yaw)
		end

		npc_core.npcs[id] = self
		npc_core.registry.register(id, self.npc_data)

		if npc_core.update_npc_nametag then
			npc_core.update_npc_nametag(self)
		end

		if npc_core.hide_nametag_now then
			npc_core.hide_nametag_now(self)
		end
	end,

	on_deactivate = function(self)
		if self.npc_data and self.npc_data.id then
			npc_core.npcs[self.npc_data.id] = nil
		end
	end,

	-- -----------------------------------------------------------------------
	-- Взаємодія
	-- -----------------------------------------------------------------------

	on_rightclick = function(self, clicker)
		local def_name = self.npc_data.def
		local def = npc_core.npc_defs[def_name]

		if def and def.pages then
			npc_core.show_dialog(clicker, def_name, "start")
			return
		end

		minetest.chat_send_player(
			clicker:get_player_name(),
			self.npc_data.dialog or "..."
		)
	end,

	on_punch = function(self, hitter)
		if hitter and hitter:is_player() then
			minetest.chat_send_player(
				hitter:get_player_name(),
				S("Don't hit me!")
			)
		end
		return true
	end,
})
