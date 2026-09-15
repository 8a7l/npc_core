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

-- stress_test.lua
-- ТИМЧАСОВИЙ файл для тестування продуктивності.
-- Видалити перед публікацією.

npc_core.stress = {
	queue          = nil,
	spawned        = 0,
	skipped        = 0,
	target         = 0,
	player_name    = nil,
	batch_per_tick = 30,
	forceloaded    = {},
}


-- ---------------------------------------------------------------------------
-- Утиліти
-- ---------------------------------------------------------------------------

local function chunk_of(pos)
	return {
		x = math.floor(pos.x / 16),
		y = math.floor(pos.y / 16),
		z = math.floor(pos.z / 16),
	}
end


local function chunk_key(c)
	return c.x .. "," .. c.y .. "," .. c.z
end


-- ---------------------------------------------------------------------------
-- Запуск
-- ---------------------------------------------------------------------------

function npc_core.stress.start(player, count, radius)
	if npc_core.stress.queue then
		return false, "Уже виконується тест. Дочекайтесь або /npc_stress_clear"
	end

	radius = radius or 40
	count = math.min(count, 50000)

	local center = player:get_pos()

	-- 1. Генеруємо позиції
	local queue = {}

	for i = 1, count do
		local angle = math.random() * math.pi * 2
		local dist = math.sqrt(math.random()) * radius
		local x = center.x + math.cos(angle) * dist
		local z = center.z + math.sin(angle) * dist
		local y = center.y + math.random(-2, 2)

		queue[i] = { x = x, y = y, z = z }
	end

	-- 2. Примусово завантажуємо всі унікальні чанки
	npc_core.stress.forceloaded = {}
	local unique = {}

	for _, pos in ipairs(queue) do
		local c = chunk_of(pos)
		local key = chunk_key(c)

		if not unique[key] then
			unique[key] = true
			minetest.forceload_block(c, true)
			table.insert(npc_core.stress.forceloaded, c)
		end
	end

	local chunks_count = #npc_core.stress.forceloaded

	npc_core.stress.queue = queue
	npc_core.stress.spawned = 0
	npc_core.stress.skipped = 0
	npc_core.stress.target = count
	npc_core.stress.player_name = player:get_player_name()

	return true, "Спавн " .. count .. " NPC у радіусі "
		.. radius .. " розпочато...\n"
		.. "Завантажено чанків: " .. chunks_count
end


-- ---------------------------------------------------------------------------
-- Очищення
-- ---------------------------------------------------------------------------

function npc_core.stress.clear()
	local count = 0
	local active_removed = 0

	local to_remove = {}

	for id, entry in pairs(npc_core.registry.index) do
		if entry.stress then
			table.insert(to_remove, id)
		end
	end

	for _, id in ipairs(to_remove) do
		local npc = npc_core.npcs[id]

		if npc and npc.object then
			npc.object:remove()
			npc_core.npcs[id] = nil
			active_removed = active_removed + 1
		end

		npc_core.registry.remove(id)
		count = count + 1
	end

	npc_core.registry.flush()

	-- Знімаємо forceload
	local freed = 0
	for _, c in ipairs(npc_core.stress.forceloaded or {}) do
		minetest.forceload_free_block(c, true)
		freed = freed + 1
	end
	npc_core.stress.forceloaded = {}

	return true, "Видалено з індексу: " .. count
		.. "\nЗ них активних: " .. active_removed
		.. "\nЗвільнено чанків: " .. freed
end


-- ---------------------------------------------------------------------------
-- Статистика
-- ---------------------------------------------------------------------------

function npc_core.stress.status()
	local active = 0
	for _ in pairs(npc_core.npcs) do active = active + 1 end

	local total = 0
	local stress = 0
	for _, entry in pairs(npc_core.registry.index) do
		total = total + 1
		if entry.stress then stress = stress + 1 end
	end

	local queue_len = npc_core.stress.queue
		and #npc_core.stress.queue or 0

	local lines = {
		"=== NPC Core Stress Status ===",
		"Активних у RAM: " .. active,
		"Усього в індексі: " .. total,
		"Stress NPC: " .. stress,
		"У черзі спавну: " .. queue_len,
		"Пропущено: " .. npc_core.stress.skipped,
	}

	return true, table.concat(lines, "\n")
end


-- ---------------------------------------------------------------------------
-- Globalstep
-- ---------------------------------------------------------------------------

minetest.register_globalstep(function(dtime)
	local q = npc_core.stress.queue
	if not q then return end

	local batch = npc_core.stress.batch_per_tick

	for i = 1, batch do
		local pos = q[#q]
		if not pos then
			local msg = "[stress] Готово: створено "
				.. npc_core.stress.spawned .. " NPC"
				.. ", пропущено " .. npc_core.stress.skipped

			minetest.chat_send_all(msg)
			minetest.log("action", msg)

			npc_core.stress.queue = nil
			npc_core.registry.flush()
			return
		end

		q[#q] = nil

		local node = minetest.get_node_or_nil(pos)

		if not node then
			npc_core.stress.skipped = npc_core.stress.skipped + 1
		else
			local id = "stress_" .. npc_core.generate_id()

			local data = {
				id     = id,
				def    = "template",
				pos    = pos,
				yaw    = 0,
				stress = true,
			}

			local obj = minetest.add_entity(
				pos, "npc_core:npc", minetest.serialize(data))

			if obj then
				npc_core.stress.spawned = npc_core.stress.spawned + 1
			else
				npc_core.stress.skipped = npc_core.stress.skipped + 1
			end
		end
	end
end)


-- ---------------------------------------------------------------------------
-- Чат-команди
-- ---------------------------------------------------------------------------

minetest.register_chatcommand("npc_stress", {
	privs = { server = true },
	params = "<count> [radius]",
	description = "Стресс-тест: спавнить багато NPC навколо гравця",

	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if not player then return false, "Гравця не знайдено" end

		local count, radius = param:match("^(%d+)%s*(%d*)$")

		count = tonumber(count)
		radius = tonumber(radius) or 40

		if not count or count < 1 then
			return false,
				"Приклад: /npc_stress 1000\n"
				.. "/npc_stress 5000 60"
		end

		return npc_core.stress.start(player, count, radius)
	end,
})


minetest.register_chatcommand("npc_stress_clear", {
	privs = { server = true },
	description = "Видалити всі stress-NPC",

	func = function()
		return npc_core.stress.clear()
	end,
})


minetest.register_chatcommand("npc_stress_status", {
	privs = { server = true },
	description = "Статистика стрес-тесту",

	func = function()
		return npc_core.stress.status()
	end,
})
