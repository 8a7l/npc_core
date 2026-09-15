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

-- defs.lua
-- Управління def'ами NPC: вбудовані + кастомні (зі storage).

npc_core.custom_defs = {}


-- Завантажити кастомні def'и зі storage і злити з вбудованими.
function npc_core.defs.load_custom()
	npc_core.custom_defs = npc_core.storage.load_defs()

	local count = 0
	for id, def in pairs(npc_core.custom_defs) do
		def.custom = true
		npc_core.npc_defs[id] = def
		count = count + 1
	end

	npc_core.log("loaded custom defs: " .. count)
end


-- Оновити всіх активних NPC, які використовують цей def.
-- Викликається після зміни def'а, щоб застосувати:
--   * нову текстуру
--   * інші properties, які залежать від def
local function refresh_world_npcs(def_id)
	local def = npc_core.npc_defs[def_id]
	if not def then return end

	local count = 0

	for _, npc in pairs(npc_core.npcs) do
		if npc.npc_data and npc.npc_data.def == def_id
			and npc.object then

			-- Оновлюємо текстуру
			if def.texture then
				npc.object:set_properties({
					textures = { def.texture },
				})
			end

			-- Оновлюємо nametag
			if npc_core.update_npc_nametag then
				npc_core.update_npc_nametag(npc)
			end

			count = count + 1
		end
	end

	npc_core.log("refreshed " .. count .. " npcs for def " .. def_id)
end


-- Зберегти кастомний def + одразу оновити всіх NPC у світі.
function npc_core.defs.save_custom(id, def)
	def.custom = true
	npc_core.custom_defs[id] = def
	npc_core.npc_defs[id] = def

	npc_core.storage.save_defs(npc_core.custom_defs)

	-- Оновлюємо активних NPC у світі
	refresh_world_npcs(id)
end


-- Видалити кастомний def.
function npc_core.defs.remove_custom(id)
	npc_core.custom_defs[id] = nil
	npc_core.npc_defs[id] = nil

	npc_core.storage.save_defs(npc_core.custom_defs)
end


-- Чи це кастомний (редагований) def.
function npc_core.defs.is_custom(id)
	return npc_core.custom_defs[id] ~= nil
end


-- Згенерувати унікальний id для нового def'а.
function npc_core.defs.generate_id()
	local base = "custom_"
	local n = 1

	while npc_core.npc_defs[base .. n] do
		n = n + 1
	end

	return base .. n
end
