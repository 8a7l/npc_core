-- storage.lua
-- Збереження індексу NPC у mod_storage.
--
-- "Індекс" — це легка таблиця id → {def, pos, chunk, yaw}.
-- Повні дані NPC (діалоги, торгівля, телепорти) лежать у def'ах.
-- Самі entity зберігаються рушієм у чанках автоматично.

npc_core.storage = {}

local INDEX_KEY    = "npc_index"
local DEFS_KEY     = "custom_defs"
local SETTINGS_KEY = "settings"

local storage_handle = minetest.get_mod_storage()


-- ---------------------------------------------------------------------------
-- Індекс NPC
-- ---------------------------------------------------------------------------

function npc_core.storage.load_index()
	if not storage_handle then
		return { index = {}, removed = {} }
	end

	local raw = storage_handle:get_string(INDEX_KEY)

	if not raw or raw == "" then
		return { index = {}, removed = {} }
	end

	local data = minetest.deserialize(raw)

	if not data or type(data) ~= "table" then
		return { index = {}, removed = {} }
	end

	data.index = data.index or {}
	data.removed = data.removed or {}

	return data
end


function npc_core.storage.save_index(data)
	if not storage_handle then
		return
	end

	storage_handle:set_string(INDEX_KEY, minetest.serialize(data))
end


-- ---------------------------------------------------------------------------
-- Кастомні def'и
-- ---------------------------------------------------------------------------

function npc_core.storage.load_defs()
	if not storage_handle then
		return {}
	end

	local raw = storage_handle:get_string(DEFS_KEY)
	if not raw or raw == "" then
		return {}
	end

	local data = minetest.deserialize(raw)
	if not data or type(data) ~= "table" then
		return {}
	end

	return data
end


function npc_core.storage.save_defs(defs)
	if not storage_handle then
		return
	end

	storage_handle:set_string(DEFS_KEY, minetest.serialize(defs))
end


-- ---------------------------------------------------------------------------
-- Налаштування (індикатори тощо)
-- ---------------------------------------------------------------------------

function npc_core.storage.load_settings()
	if not storage_handle then
		return {}
	end

	local raw = storage_handle:get_string(SETTINGS_KEY)
	if not raw or raw == "" then
		return {}
	end

	local data = minetest.deserialize(raw)
	if not data or type(data) ~= "table" then
		return {}
	end

	return data
end


function npc_core.storage.save_settings(data)
	if not storage_handle then
		return
	end

	storage_handle:set_string(SETTINGS_KEY, minetest.serialize(data))
end