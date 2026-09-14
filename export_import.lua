-- export_import.lua
-- Export and import NPC templates as JSON files.
--
-- Files are stored in: <worldpath>/npc_core_exports/

local S = minetest.get_translator("npc_core")

npc_core.exporter = {
	file_list = {},
}


-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function get_export_dir()
	return minetest.get_worldpath() .. "/npc_core_exports"
end


local function ensure_dir()
	local dir = get_export_dir()
	minetest.mkdir(dir)
	return dir
end


local function sanitize_filename(name)
	return (name:gsub("[^%w_%.%-]", "_"))
end


local function generate_import_id()
	local base = "imported_"
	local n = 1

	while npc_core.npc_defs[base .. n] do
		n = n + 1
	end

	return base .. n
end


-- ---------------------------------------------------------------------------
-- Export
-- ---------------------------------------------------------------------------

function npc_core.exporter.export_def(def_id)
	local def = npc_core.npc_defs[def_id]
	if not def then
		return false, S("Template not found: @1", def_id)
	end

	ensure_dir()

	local copy = minetest.deserialize(minetest.serialize(def))
	copy.custom = nil

	local json = minetest.write_json(copy, true)
	if not json then
		return false, S("Failed to serialize to JSON")
	end

	local filename = sanitize_filename(def_id) .. ".json"
	local path = get_export_dir() .. "/" .. filename

	local ok, err = minetest.safe_file_write(path, json)

	if not ok then
		return false, S("Write error: @1", tostring(err))
	end

	return true, S("Saved: @1", filename)
end


-- ---------------------------------------------------------------------------
-- List of exports
-- ---------------------------------------------------------------------------

function npc_core.exporter.list_files()
	local dir = ensure_dir()

	local files = minetest.get_dir_list(dir, false)

	local result = {}
	for _, f in ipairs(files) do
		if f:match("%.json$") then
			table.insert(result, f)
		end
	end

	table.sort(result)
	return result
end


-- ---------------------------------------------------------------------------
-- Import
-- ---------------------------------------------------------------------------

function npc_core.exporter.import_def(filename)
	if not filename or filename == "" then
		return false, S("File name not specified")
	end

	-- Path traversal protection
	if filename:find("[/\\]") or filename:find("%.%. ") then
		return false, S("Invalid file name")
	end

	local path = get_export_dir() .. "/" .. filename

	local f = io.open(path, "r")
	if not f then
		return false, S("File not found: @1", filename)
	end

	local content = f:read("*a")
	f:close()

	local data = minetest.parse_json(content)
	if not data or type(data) ~= "table" then
		return false, S("Invalid JSON in file")
	end

	-- Minimal validation
	if not data.pages and not data.trade and not data.teleports then
		return false, S("File does not look like an NPC template")
	end

	local new_id = generate_import_id()

	if not data.name or data.name == "" then
		data.name = new_id
	else
		data.name = data.name .. " (import)"
	end

	data.custom = true

	npc_core.defs.save_custom(new_id, data)

	return true, S("Imported as: @1", new_id)
end


-- ---------------------------------------------------------------------------
-- GUI: export
-- ---------------------------------------------------------------------------

function npc_core.exporter.show_export(player)
	local pname = player:get_player_name()

	local entries = {}
	for id, def in pairs(npc_core.npc_defs) do
		local display = def.name or id
		if def.custom then display = display .. " *" end
		table.insert(entries, { name = display, id = id })
	end
	table.sort(entries, function(a, b) return a.name < b.name end)

	local names = {}
	local ids = {}

	for _, e in ipairs(entries) do
		local n = (e.name:gsub(",", "·"))
		table.insert(names, n)
		table.insert(ids, e.id)
	end

	npc_core.exporter.selected = npc_core.exporter.selected or {}
	npc_core.exporter.def_list = ids

	local selected_idx = 0
	local cur = npc_core.exporter.selected[pname]
	if cur then
		for i, id in ipairs(ids) do
			if id == cur then selected_idx = i break end
		end
	end

	minetest.show_formspec(pname, "npc_core:export",
		"size[10,7]" ..
		"label[0.3,0.2;" .. S("Export NPC template") .. "]" ..
		"label[0.3,0.5;" ..
			S("Files are stored in the world folder") .. "]" ..
		"textlist[0.3,1;6,5;defs;" .. table.concat(names, ",") ..
			";" .. selected_idx .. "]" ..

		"button[6.5,1;3,1;export;" .. S("Export") .. "]" ..
		"button[6.5,2.5;3,0.8;back;" .. S("Back") .. "]" ..
		"button_exit[6.5,5;3,0.8;close;" .. S("Close") .. "]"
	)
end


-- ---------------------------------------------------------------------------
-- GUI: import
-- ---------------------------------------------------------------------------

function npc_core.exporter.show_import(player)
	local pname = player:get_player_name()

	local files = npc_core.exporter.list_files()
	npc_core.exporter.file_list[pname] = files

	local display = {}
	for _, f in ipairs(files) do
		local n = (f:gsub(",", "·"))
		table.insert(display, n)
	end

	local list_str = #display > 0 and table.concat(display, ",") or ""

	local selected_idx = 0
	local cur = npc_core.exporter.selected_file
		and npc_core.exporter.selected_file[pname]

	if cur then
		for i, f in ipairs(files) do
			if f == cur then selected_idx = i break end
		end
	end

	local info
	if #files == 0 then
		info = S("No files to import. Export something first.")
	else
		info = S("Choose a file to import.")
	end

	minetest.show_formspec(pname, "npc_core:import",
		"size[10,7]" ..
		"label[0.3,0.2;" .. S("Import NPC template") .. "]" ..
		"label[0.3,0.5;" .. minetest.formspec_escape(info) .. "]" ..
		"textlist[0.3,1;6,5;files;" .. list_str ..
			";" .. selected_idx .. "]" ..

		"button[6.5,1;3,1;import;" .. S("Import") .. "]" ..
		"button[6.5,2.5;3,0.8;refresh;" .. S("Refresh") .. "]" ..
		"button[6.5,3.5;3,0.8;back;" .. S("Back") .. "]" ..
		"button_exit[6.5,5;3,0.8;close;" .. S("Close") .. "]"
	)
end


-- ---------------------------------------------------------------------------
-- Formspec handlers
-- ---------------------------------------------------------------------------

minetest.register_on_player_receive_fields(function(player, formname, fields)
	local pname = player:get_player_name()

	-- Export
	if formname == "npc_core:export" then

		if fields.defs then
			local event = minetest.explode_textlist_event(fields.defs)
			if event.type == "CHG" or event.type == "DCL" then
				local id = npc_core.exporter.def_list[event.index]
				if id then
					npc_core.exporter.selected[pname] = id
					npc_core.exporter.show_export(player)
				end
			end
			return
		end

		if fields.export then
			local def_id = npc_core.exporter.selected[pname]
			if not def_id then
				minetest.chat_send_player(pname,
					S("Select template first."))
				return
			end

			local ok, msg = npc_core.exporter.export_def(def_id)
			minetest.chat_send_player(pname, msg)
			return
		end

		if fields.back then
			npc_core.admin.show_main(player)
			return
		end
	end


	-- Import
	if formname == "npc_core:import" then

		if fields.files then
			local event = minetest.explode_textlist_event(fields.files)
			if event.type == "CHG" or event.type == "DCL" then
				local list = npc_core.exporter.file_list[pname]
				if list then
					npc_core.exporter.selected_file =
						npc_core.exporter.selected_file or {}
					npc_core.exporter.selected_file[pname] =
						list[event.index]
					npc_core.exporter.show_import(player)
				end
			end
			return
		end

		if fields.import then
			local sel = npc_core.exporter.selected_file
				and npc_core.exporter.selected_file[pname]

			if not sel then
				minetest.chat_send_player(pname,
					S("Select file first."))
				return
			end

			local ok, msg = npc_core.exporter.import_def(sel)
			minetest.chat_send_player(pname, msg)

			if ok then
				npc_core.exporter.show_import(player)
			end
			return
		end

		if fields.refresh then
			npc_core.exporter.show_import(player)
			return
		end

		if fields.back then
			npc_core.admin.show_main(player)
			return
		end
	end
end)


-- ---------------------------------------------------------------------------
-- Chat commands
-- ---------------------------------------------------------------------------

minetest.register_chatcommand("npc_export", {
	privs = { npc_admin = true },
	params = "<def_id>",
	description = S("Export NPC template to JSON file"),

	func = function(name, param)
		if not param or param == "" then
			return false, S("Specify def_id")
		end

		return npc_core.exporter.export_def(param)
	end,
})


minetest.register_chatcommand("npc_import", {
	privs = { npc_admin = true },
	params = "<filename>",
	description = S("Import NPC template from JSON file"),

	func = function(name, param)
		if not param or param == "" then
			return false, S("Specify file name (e.g. custom_1.json)")
		end

		return npc_core.exporter.import_def(param)
	end,
})


minetest.register_chatcommand("npc_exports", {
	privs = { npc_admin = true },
	description = S("List of exported files"),

	func = function()
		local files = npc_core.exporter.list_files()

		if #files == 0 then
			return true, S("No exported files")
		end

		return true, table.concat(files, "\n")
	end,
})