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

-- registry.lua
-- Легкий індекс NPC + автозбереження.

npc_core = npc_core or {}

npc_core.registry = {
	index = {},
	removed = {},
	dirty = false,
	autosave_timer = 0,
}

local AUTOSAVE_INTERVAL = 30


-- ---------------------------------------------------------------------------
-- Допоміжне
-- ---------------------------------------------------------------------------

-- Чанк за позицією (стандартний розмір чанка Luanti — 16×16)
local function chunk_key(pos)
	if not pos then return nil end
	local cx = math.floor(pos.x / 16)
	local cz = math.floor(pos.z / 16)
	return cx .. "," .. cz
end


-- ---------------------------------------------------------------------------
-- Завантаження / збереження стану
-- ---------------------------------------------------------------------------

function npc_core.registry.load_state()
	local data = npc_core.storage.load_index()

	npc_core.registry.index = data.index or {}
	npc_core.registry.removed = data.removed or {}
	npc_core.registry.dirty = false
end


function npc_core.registry.flush()
	if not npc_core.registry.dirty then return end

	npc_core.storage.save_index({
		index = npc_core.registry.index,
		removed = npc_core.registry.removed,
	})

	npc_core.registry.dirty = false
end


-- ---------------------------------------------------------------------------
-- Операції з індексом
-- ---------------------------------------------------------------------------

-- Зареєструвати NPC в індексі.
function npc_core.registry.register(id, npc_data)
	if not id then return end
	if not npc_data then return end
	if npc_core.registry.removed[id] then return end

	npc_core.registry.index[id] = {
		def    = npc_data.def,
		pos    = npc_data.pos,
		chunk  = chunk_key(npc_data.pos),
		yaw    = npc_data.yaw,
		stress = npc_data.stress,
	}

	npc_core.registry.dirty = true
end


-- Сумісність зі старим API.
function npc_core.registry.set(id, npc_data)
	npc_core.registry.register(id, npc_data)
end


-- Отримати запис індексу.
function npc_core.registry.get(id)
	return npc_core.registry.index[id]
end


-- Видалити NPC з індексу.
function npc_core.registry.remove(id)
	npc_core.registry.index[id] = nil
	npc_core.registry.removed[id] = true
	npc_core.registry.dirty = true

	if npc_core.forget_nametag then
		npc_core.forget_nametag(id)
	end
end


-- Оновити позицію і поворот NPC в індексі.
function npc_core.registry.update_pos(id, pos, yaw)
	if not pos then return end

	local entry = npc_core.registry.index[id]
	if not entry then return end

	entry.pos = { x = pos.x, y = pos.y, z = pos.z }
	entry.chunk = chunk_key(pos)

	if yaw then
		entry.yaw = yaw
	end

	npc_core.registry.dirty = true
end


-- Оновити запис з entity (позиція, yaw).
function npc_core.registry.sync_from_entity(npc)
	if not npc or not npc.npc_data then return end
	if not npc.object then return end

	local id = npc.npc_data.id
	if npc_core.registry.removed[id] then return end

	local pos = npc.object:get_pos()
	if pos then
		npc_core.registry.update_pos(id, pos, npc.object:get_yaw())
	end
end


-- Заглушка (сумісність зі старим init.lua).
function npc_core.registry.restore_all()
	npc_core.log("[registry] restore_all() is deprecated")
end


-- ---------------------------------------------------------------------------
-- Автозбереження
-- ---------------------------------------------------------------------------

minetest.register_globalstep(function(dtime)
	npc_core.registry.autosave_timer =
		npc_core.registry.autosave_timer + dtime

	if npc_core.registry.autosave_timer >= AUTOSAVE_INTERVAL then
		npc_core.registry.autosave_timer = 0

		for _, npc in pairs(npc_core.npcs) do
			npc_core.registry.sync_from_entity(npc)
		end

		npc_core.registry.flush()
	end
end)


minetest.register_on_shutdown(function()
	for _, npc in pairs(npc_core.npcs) do
		npc_core.registry.sync_from_entity(npc)
	end
	npc_core.registry.flush()
end)
