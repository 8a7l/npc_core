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

-- editor.lua
-- In-game NPC editor.

local S = minetest.get_translator("npc_core")

npc_core.editor = {
	editing_def = {},
	creating    = {},
	list        = {},
	selected    = {},
}

npc_core.editor.dialogs = {
	editing_def = {},
	editing_page = {},
	page_list    = {},
	selected     = {},
}

npc_core.editor.options = {
	ctx = {},
	list = {},
	selected = {},
	editing = {},
}


-- ---------------------------------------------------------------------------
-- Texture scanning
-- ---------------------------------------------------------------------------

local cached_textures = nil

local function scan_textures()
	if cached_textures then return cached_textures end

	local modpath = minetest.get_modpath("npc_core")
	local files = minetest.get_dir_list(modpath .. "/textures/", false)

	local list = {}
	for _, f in ipairs(files) do
		if f:match("%.png$") then
			if f == "character.png" or f:match("^npc_") then
				table.insert(list, f)
			end
		end
	end

	table.sort(list)

	cached_textures = list
	return list
end


local function find_texture_index(list, name)
	if not name then return 1 end
	for i, f in ipairs(list) do
		if f == name then return i end
	end
	return 1
end


-- ---------------------------------------------------------------------------
-- Def list
-- ---------------------------------------------------------------------------

function npc_core.editor.show_list(player)
	local pname = player:get_player_name()

	local entries = {}

	for id, def in pairs(npc_core.npc_defs) do
		local display = def.name or id
		if def.custom then
			display = display .. " *"
		end
		table.insert(entries, { name = display, id = id })
	end

	table.sort(entries, function(a, b) return a.name < b.name end)

	local names = {}
	npc_core.editor.list = {}

	for _, e in ipairs(entries) do
		table.insert(names, e.name)
		table.insert(npc_core.editor.list, e.id)
	end

	local selected_idx = 0
	local current_sel = npc_core.editor.selected[pname]
	if current_sel then
		for i, id in ipairs(npc_core.editor.list) do
			if id == current_sel then
				selected_idx = i
				break
			end
		end
	end

	local sel = npc_core.editor.selected[pname] or "-"

	minetest.show_formspec(pname, "npc_core:editor_list",
		"size[10,8]" ..
		"label[0.3,0.2;" .. S("NPC editor") .. "]" ..
		"label[0.3,0.5;" .. S("* = created via editor") .. "]" ..
		"label[0.3,7.5;" ..
			minetest.formspec_escape(S("Selected: @1", sel)) .. "]" ..
		"textlist[0.3,1;6,6;defs;" .. table.concat(names, ",") ..
			";" .. selected_idx .. "]" ..
		"button[6.5,1;3,0.8;new;" .. S("New NPC") .. "]" ..
		"button[6.5,2;3,0.8;edit;" .. S("Edit") .. "]" ..
		"button[6.5,3;3,0.8;clone;" .. S("Clone") .. "]" ..
		"button[6.5,4;3,0.8;delete;" .. S("Delete") .. "]" ..
		"button_exit[6.5,6;3,0.8;close;" .. S("Close") .. "]"
	)
end


-- ---------------------------------------------------------------------------
-- Def edit form
-- ---------------------------------------------------------------------------

function npc_core.editor.show_form(player, def_id, is_new, overrides)
	local pname = player:get_player_name()

	local def = npc_core.npc_defs[def_id] or {}

	local display = {}
	for k, v in pairs(def) do
		display[k] = v
	end
	if overrides then
		for k, v in pairs(overrides) do
			display[k] = v
		end
	end

	npc_core.editor.editing_def[pname] = def_id
	npc_core.editor.creating[pname] = is_new or false

	local title
	if is_new then
		title = S("New NPC (@1)", def_id)
	else
		title = S("Editing: @1", display.name or def_id)
	end

	local tex_list = scan_textures()
	local tex_name = display.texture or "character.png"
	local tex_idx = find_texture_index(tex_list, tex_name)

	local formspec = "size[14,10]" ..
		"label[0.3,0.2;" .. minetest.formspec_escape(title) .. "]" ..

		"field[0.3,0.7;13,0.8;name;" .. S("Name") .. ";" ..
			minetest.formspec_escape(display.name or "") .. "]" ..

		"field[0.3,1.7;13,0.8;profession;" .. S("Profession") .. ";" ..
			minetest.formspec_escape(display.profession or "") .. "]" ..

		"field[0.3,2.7;13,0.8;location;" .. S("Location") .. ";" ..
			minetest.formspec_escape(display.location or "") .. "]" ..

		"field[0.3,3.7;5,0.8;texture;" .. S("Texture") .. ";" ..
			minetest.formspec_escape(tex_name) .. "]" ..

		"dropdown[5.5,3.7;5,0.8;texture_pick;" ..
			table.concat(tex_list, ",") .. ";" .. tex_idx .. "]" ..

		"image[11.2,3.65;1.5,1.5;" ..
			minetest.formspec_escape(tex_name) .. "]" ..

		"textarea[0.3,5.4;13,3.3;info;" .. S("Description") .. ";" ..
			minetest.formspec_escape(display.info or "") .. "]" ..

		"button[0.3,8.9;2,0.8;save;" .. S("Save") .. "]" ..
		"button[2.5,8.9;2,0.8;cancel;" .. S("Cancel") .. "]" ..
		"button[4.7,8.9;2,0.8;dialogs;" .. S("Dialogs") .. "]" ..
		"button[6.9,8.9;2,0.8;trades_btn;" .. S("Trade") .. "]" ..
		"button[9.1,8.9;2,0.8;teleports_btn;" .. S("Teleports") .. "]" ..
		"button[11.3,8.9;2,0.8;spawn_btn;" .. S("Spawn") .. "]"

	minetest.show_formspec(pname, "npc_core:editor_form", formspec)
end


-- ---------------------------------------------------------------------------
-- Dialog pages editor
-- ---------------------------------------------------------------------------

function npc_core.editor.show_dialogs(player, def_id)
	local pname = player:get_player_name()
	local def = npc_core.npc_defs[def_id]

	if not def then
		minetest.chat_send_player(pname, S("NPC not found: @1", def_id))
		return
	end

	if not def.pages then
		def.pages = {}
	end

	local entries = {}
	for page_id in pairs(def.pages) do
		table.insert(entries, page_id)
	end
	table.sort(entries)

	npc_core.editor.dialogs.page_list[pname] = entries
	npc_core.editor.dialogs.editing_def[pname] = def_id

	local title = S("Dialogs: @1", def.name or def_id)

	local selected_idx = 0
	local current_sel = npc_core.editor.dialogs.selected[pname]
	if current_sel then
		for i, e in ipairs(entries) do
			if e == current_sel then
				selected_idx = i
				break
			end
		end
	end

	local sel = npc_core.editor.dialogs.selected[pname] or "-"

	local can_edit = npc_core.defs.is_custom(def_id)

	local new_button = ""
	local del_button = ""
	if can_edit then
		new_button = "button[6.5,1;3,0.8;new_page;" ..
			S("New page") .. "]"
		del_button = "button[6.5,3;3,0.8;delete_page;" ..
			S("Delete") .. "]"
	end

	minetest.show_formspec(pname, "npc_core:editor_dialogs",
		"size[10,8]" ..
		"label[0.3,0.2;" .. minetest.formspec_escape(title) .. "]" ..
		"label[0.3,0.5;" ..
			S("Dialog pages (sorted by ID)") .. "]" ..
		"label[0.3,7.5;" ..
			minetest.formspec_escape(S("Page: @1", sel)) .. "]" ..
		"textlist[0.3,1;6,6;pages;" .. table.concat(entries, ",") ..
			";" .. selected_idx .. "]" ..
		new_button ..
		"button[6.5,2;3,0.8;edit_page;" .. S("Edit") .. "]" ..
		del_button ..
		"button[6.5,5;3,0.8;back;" .. S("Back to NPC") .. "]" ..
		"button_exit[6.5,6;3,0.8;close;" .. S("Close") .. "]"
	)
end


function npc_core.editor.show_page(player, page_id)
	local pname = player:get_player_name()

	local def_id = npc_core.editor.dialogs.editing_def[pname]
	local def = npc_core.npc_defs[def_id]
	if not def or not def.pages or not def.pages[page_id] then
		minetest.chat_send_player(pname, S("Page not found."))
		return
	end

	local page = def.pages[page_id]

	npc_core.editor.dialogs.editing_page[pname] = page_id

	local formspec = "size[10,8]" ..
		"label[0.3,0.2;" ..
			minetest.formspec_escape(S("Editing page: @1",
				page_id)) .. "]" ..

		"field[0.3,0.7;9,0.8;page_id;" .. S("Page ID") .. ";" ..
			minetest.formspec_escape(page_id) .. "]" ..

		"textarea[0.3,1.7;9,5;text;" .. S("Text") .. ";" ..
			minetest.formspec_escape(page.text or "") .. "]" ..

		"button[0.3,7;2,0.8;save_page;" .. S("Save") .. "]" ..
		"button[2.5,7;2,0.8;cancel_page;" .. S("Cancel") .. "]" ..
		"button[4.7,7;2,0.8;options_btn;" .. S("Options") .. "]"

	minetest.show_formspec(pname, "npc_core:editor_page", formspec)
end


-- ---------------------------------------------------------------------------
-- Page options editor
-- ---------------------------------------------------------------------------

function npc_core.editor.show_options(player, def_id, page_id)
	local pname = player:get_player_name()

	local def = npc_core.npc_defs[def_id]
	if not def or not def.pages or not def.pages[page_id] then
		minetest.chat_send_player(pname, S("Page not found."))
		return
	end

	local page = def.pages[page_id]
	local options = page.options or {}

	npc_core.editor.options.ctx[pname] = {
		def_id = def_id,
		page_id = page_id,
	}

	local names = {}
	local indices = {}

	for i, opt in ipairs(options) do
		local label = opt.text or S("(no text)")

		if opt.next then
			label = label .. "  → " .. opt.next
		elseif opt.action then
			label = label .. "  ⚡ " .. opt.action
		end

		table.insert(names, label)
		table.insert(indices, i)
	end

	npc_core.editor.options.list[pname] = indices

	local title = S("Options: @1 / @2", def.name or def_id, page_id)
	local can_edit = npc_core.defs.is_custom(def_id)

	local new_btn = ""
	local del_btn = ""
	local up_btn = ""
	local down_btn = ""
	if can_edit then
		new_btn = "button[6.5,1;3,0.8;new_opt;" ..
			S("Add option") .. "]"
		del_btn = "button[6.5,3;3,0.8;delete_opt;" ..
			S("Delete") .. "]"
		up_btn = "button[6.5,4;1.4,0.8;opt_up;↑]"
		down_btn = "button[8.1,4;1.4,0.8;opt_down;↓]"
	end

	local list_str = table.concat(names, ",")

	local selected = npc_core.editor.options.selected[pname] or 0
	if selected < 0 or selected > #names then
		selected = 0
	end

	minetest.show_formspec(pname, "npc_core:editor_options",
		"size[10,8]" ..
		"label[0.3,0.2;" .. minetest.formspec_escape(title) .. "]" ..
		"textlist[0.3,1;6,6;opts;" .. list_str .. ";" .. selected .. "]" ..
		new_btn ..
		"button[6.5,2;3,0.8;edit_opt;" .. S("Edit") .. "]" ..
		del_btn ..
		up_btn ..
		down_btn ..
		"button[6.5,5;3,0.8;back_to_page;" ..
			S("Back to page") .. "]" ..
		"button_exit[6.5,6;3,0.8;close;" .. S("Close") .. "]"
	)
end


function npc_core.editor.show_option(player, index)
	local pname = player:get_player_name()

	local ctx = npc_core.editor.options.ctx[pname]
	if not ctx then return end

	local def = npc_core.npc_defs[ctx.def_id]
	local page = def.pages[ctx.page_id]
	local opt = page.options and page.options[index] or { text = "" }

	npc_core.editor.options.editing[pname] = index

	local opt_type = "next"
	local target = ""

	if opt.action then
		opt_type = "action"
		target = opt.action
	elseif opt.next then
		opt_type = "next"
		target = opt.next
	end

	local dropdown_index = (opt_type == "next") and 1 or 2

	local pages_hint = {}
	for pid in pairs(def.pages) do
		table.insert(pages_hint, pid)
	end
	table.sort(pages_hint)

	local hint = S("Pages: @1", table.concat(pages_hint, ", "))

	if npc_core.actions then
		local acts = {}
		for name in pairs(npc_core.actions) do
			table.insert(acts, name)
		end
		table.sort(acts)
		if #acts > 0 then
			hint = hint .. "\n" .. S("Actions: @1",
				table.concat(acts, ", "))
		end
	end

	if def.teleports and #def.teleports > 0 then
		local tps = {}
		for _, tp in ipairs(def.teleports) do
			table.insert(tps, "tp_" .. tp.id ..
				" (" .. (tp.name or "?") .. ")")
		end
		hint = hint .. "\n" .. S("Teleports: @1",
			table.concat(tps, ", "))
	end

	local title = S("Option #@1", index)

	minetest.show_formspec(pname, "npc_core:editor_option",
		"size[10,8]" ..
		"label[0.3,0.2;" .. minetest.formspec_escape(title) .. "]" ..

		"field[0.3,0.7;9,0.8;text;" .. S("Option text") .. ";" ..
			minetest.formspec_escape(opt.text or "") .. "]" ..

		"label[0.3,1.6;" .. S("Type:") .. "]" ..
		"dropdown[0.3,1.9;3,0.8;opt_type;next,action;" ..
			dropdown_index .. "]" ..

		"field[0.3,2.9;9,0.8;target;" ..
			S("Target (page id or action)") .. ";" ..
			minetest.formspec_escape(target) .. "]" ..

		"textarea[0.3,3.9;9,2.5;hint;" ..
			S("Available targets") .. ";" ..
			minetest.formspec_escape(hint) .. "]" ..

		"button[0.3,6.7;2,0.8;save_opt;" .. S("Save") .. "]" ..
		"button[2.5,6.7;2,0.8;cancel_opt;" .. S("Cancel") .. "]"
	)
end


-- ---------------------------------------------------------------------------
-- Formspec handlers
-- ---------------------------------------------------------------------------

minetest.register_on_player_receive_fields(function(player, formname, fields)
	local pname = player:get_player_name()

	-- Def list
	if formname == "npc_core:editor_list" then

		if fields.defs then
			local event = minetest.explode_textlist_event(fields.defs)
			if event.type == "CHG" or event.type == "DCL" then
				local id = npc_core.editor.list[event.index]
				if id then
					npc_core.editor.selected[pname] = id
					npc_core.editor.show_list(player)
				end
			end
			return
		end

		local selected = npc_core.editor.selected[pname]

		if fields.new then
			local new_id = npc_core.defs.generate_id()
			npc_core.editor.show_form(player, new_id, true)
			return
		end

		if fields.edit then
			if not selected then
				minetest.chat_send_player(pname,
					S("Select NPC from list first."))
				npc_core.editor.show_list(player)
				return
			end
			npc_core.editor.show_form(player, selected, false)
			return
		end

		if fields.clone then
			if not selected then
				minetest.chat_send_player(pname,
					S("Select NPC from list first."))
				return
			end

			local src = npc_core.npc_defs[selected]
			if not src then
				minetest.chat_send_player(pname,
					S("NPC not found: @1", selected))
				return
			end

			local new_id = npc_core.defs.generate_id()
			local copy = minetest.deserialize(minetest.serialize(src))
			copy.name = (copy.name or new_id) .. " (clone)"
			copy.custom = true

			npc_core.defs.save_custom(new_id, copy)
			npc_core.editor.selected[pname] = new_id

			minetest.chat_send_player(pname,
				S("Clone created: @1", new_id))

			npc_core.editor.show_list(player)
			return
		end

		if fields.delete then
			if not selected then
				minetest.chat_send_player(pname,
					S("Select NPC from list first."))
				return
			end

			if not npc_core.defs.is_custom(selected) then
				minetest.chat_send_player(pname,
					S("Built-in NPC cannot be deleted. Copy it via Clone."))
				return
			end

			npc_core.defs.remove_custom(selected)
			npc_core.editor.selected[pname] = nil

			minetest.chat_send_player(pname,
				S("Deleted: @1", selected))

			npc_core.editor.show_list(player)
			return
		end
	end


	-- Def edit form
	if formname == "npc_core:editor_form" then

		-- Buttons FIRST (dropdown sends its field on every event)

		if fields.teleports_btn then
			local def_id = npc_core.editor.editing_def[pname]
			if def_id then
				npc_core.teleports.editor_show_list(player, def_id)
			end
			return
		end

		if fields.trades_btn then
			local def_id = npc_core.editor.editing_def[pname]
			if def_id then
				npc_core.trade.editor_show_list(player, def_id)
			end
			return
		end

		if fields.spawn_btn then
			local def_id = npc_core.editor.editing_def[pname]
			if not def_id then return end

			if not npc_core.npc_defs[def_id] then
				minetest.chat_send_player(pname,
					S("Save NPC first (Save button)."))
				return
			end

			local id, err = npc_core.spawn_npc(player, def_id)

			if id then
				minetest.chat_send_player(pname,
					S("NPC created in world: @1", id))
			else
				minetest.chat_send_player(pname,
					S("Error: @1", err or "unknown"))
			end
			return
		end

		if fields.dialogs then
			local def_id = npc_core.editor.editing_def[pname]
			if def_id then
				npc_core.editor.show_dialogs(player, def_id)
			end
			return
		end

		if fields.cancel then
			npc_core.editor.editing_def[pname] = nil
			npc_core.editor.creating[pname] = nil
			npc_core.editor.show_list(player)
			return
		end

		if fields.save then
			local def_id = npc_core.editor.editing_def[pname]
			if not def_id then return end

			local is_new = npc_core.editor.creating[pname]

			local def = npc_core.npc_defs[def_id] or {}

			def.name       = fields.name       or def.name
			def.profession = fields.profession or def.profession
			def.location   = fields.location   or def.location
			def.texture    = fields.texture    or def.texture or "character.png"
			def.info       = fields.info       or def.info

			if not def.name or def.name == "" then
				def.name = def_id
			end

			if not def.pages then
				def.pages = {
					start = {
						text = "Hi.",
						options = {},
					},
				}
			end

			npc_core.defs.save_custom(def_id, def)

			npc_core.editor.editing_def[pname] = nil
			npc_core.editor.creating[pname] = nil
			npc_core.editor.selected[pname] = def_id

			minetest.chat_send_player(pname,
				is_new and S("Created: @1", def_id)
					or S("Updated: @1", def_id))

			npc_core.editor.show_list(player)
			return
		end

		-- Texture dropdown — LAST.
		if fields.texture_pick
			and not fields.save
			and not fields.cancel
			and not fields.dialogs
			and not fields.trades_btn
			and not fields.spawn_btn
			and not fields.teleports_btn then

			local def_id = npc_core.editor.editing_def[pname]
			if not def_id then return end

			npc_core.editor.show_form(player, def_id,
				npc_core.editor.creating[pname],
				{
					name       = fields.name or "",
					profession = fields.profession or "",
					location   = fields.location or "",
					info       = fields.info or "",
					texture    = fields.texture_pick,
				})
			return
		end
	end


	-- Dialog pages list
	if formname == "npc_core:editor_dialogs" then

		if fields.pages then
			local event = minetest.explode_textlist_event(fields.pages)
			if event.type == "CHG" or event.type == "DCL" then
				local page_id = npc_core.editor.dialogs
					.page_list[pname][event.index]
				if page_id then
					npc_core.editor.dialogs.selected[pname] = page_id
					local def_id = npc_core.editor.dialogs
						.editing_def[pname]
					npc_core.editor.show_dialogs(player, def_id)
				end
			end
			return
		end

		local selected = npc_core.editor.dialogs.selected[pname]
		local def_id = npc_core.editor.dialogs.editing_def[pname]

		if fields.new_page then
			if not npc_core.defs.is_custom(def_id) then
				minetest.chat_send_player(pname,
					S("Built-in NPC cannot be edited. Clone it."))
				return
			end

			local def = npc_core.npc_defs[def_id]
			def.pages = def.pages or {}

			local n = 1
			while def.pages["page_" .. n] do
				n = n + 1
			end

			local new_id = "page_" .. n

			def.pages[new_id] = {
				text = "New page.",
			}

			npc_core.defs.save_custom(def_id, def)

			npc_core.editor.dialogs.selected[pname] = new_id
			npc_core.editor.show_page(player, new_id)
			return
		end

		if fields.edit_page then
			if not selected then
				minetest.chat_send_player(pname,
					S("Select page first."))
				return
			end
			npc_core.editor.show_page(player, selected)
			return
		end

		if fields.delete_page then
			if not selected then
				minetest.chat_send_player(pname,
					S("Select page first."))
				return
			end

			if not npc_core.defs.is_custom(def_id) then
				minetest.chat_send_player(pname,
					S("Built-in NPC cannot be edited."))
				return
			end

			local def = npc_core.npc_defs[def_id]
			local count = 0
			for _ in pairs(def.pages) do
				count = count + 1
			end

			if count <= 1 then
				minetest.chat_send_player(pname,
					S("Cannot delete the last page."))
				return
			end

			def.pages[selected] = nil
			npc_core.defs.save_custom(def_id, def)

			npc_core.editor.dialogs.selected[pname] = nil
			npc_core.editor.show_dialogs(player, def_id)
			return
		end

		if fields.back then
			npc_core.editor.show_form(player, def_id, false)
			return
		end
	end


	-- Page edit form
	if formname == "npc_core:editor_page" then

		if fields.options_btn then
			local def_id = npc_core.editor.dialogs.editing_def[pname]
			local page_id = npc_core.editor.dialogs.editing_page[pname]
			if def_id and page_id then
				npc_core.editor.show_options(player, def_id, page_id)
			end
			return
		end

		if fields.cancel_page then
			local def_id = npc_core.editor.dialogs.editing_def[pname]
			npc_core.editor.show_dialogs(player, def_id)
			return
		end

		if fields.save_page then
			local def_id = npc_core.editor.dialogs.editing_def[pname]
			local old_id = npc_core.editor.dialogs.editing_page[pname]

			local def = npc_core.npc_defs[def_id]
			if not def or not def.pages or not def.pages[old_id] then
				return
			end

			local page = def.pages[old_id]
			page.text = fields.text or page.text or ""

			local new_id = fields.page_id
			if new_id and new_id ~= "" and new_id ~= old_id then

				if def.pages[new_id] then
					minetest.chat_send_player(pname,
						S("Page with this ID already exists."))
					return
				end

				def.pages[old_id] = nil
				def.pages[new_id] = page

				npc_core.editor.dialogs.selected[pname] = new_id
			end

			npc_core.defs.save_custom(def_id, def)

			npc_core.editor.dialogs.editing_page[pname] = nil
			npc_core.editor.show_dialogs(player, def_id)
			return
		end
	end


	-- Options list
	if formname == "npc_core:editor_options" then

		if fields.opts then
			local event = minetest.explode_textlist_event(fields.opts)
			if event.type == "CHG" or event.type == "DCL" then
				local index = npc_core.editor.options
					.list[pname][event.index]
				if index then
					npc_core.editor.options.selected[pname] = index
					local ctx = npc_core.editor.options.ctx[pname]
					npc_core.editor.show_options(
						player, ctx.def_id, ctx.page_id)
				end
			end
			return
		end

		local ctx = npc_core.editor.options.ctx[pname]
		local selected = npc_core.editor.options.selected[pname]

		if fields.new_opt then
			if not ctx or not npc_core.defs.is_custom(ctx.def_id) then
				minetest.chat_send_player(pname,
					S("Built-in NPC cannot be edited."))
				return
			end

			local def = npc_core.npc_defs[ctx.def_id]
			local page = def.pages[ctx.page_id]
			page.options = page.options or {}

			local n = #page.options + 1

			page.options[n] = {
				text = "New option",
				next = "start",
			}

			npc_core.defs.save_custom(ctx.def_id, def)

			npc_core.editor.options.selected[pname] = n
			npc_core.editor.show_option(player, n)
			return
		end

		if fields.edit_opt then
			if not selected then
				minetest.chat_send_player(pname,
					S("Select option first."))
				return
			end
			npc_core.editor.show_option(player, selected)
			return
		end

		if fields.delete_opt then
			if not selected then
				minetest.chat_send_player(pname,
					S("Select option first."))
				return
			end

			if not ctx or not npc_core.defs.is_custom(ctx.def_id) then
				minetest.chat_send_player(pname,
					S("Built-in NPC cannot be edited."))
				return
			end

			local def = npc_core.npc_defs[ctx.def_id]
			local page = def.pages[ctx.page_id]

			table.remove(page.options, selected)
			npc_core.defs.save_custom(ctx.def_id, def)

			npc_core.editor.options.selected[pname] = nil
			npc_core.editor.show_options(player, ctx.def_id, ctx.page_id)
			return
		end

		if fields.opt_up then
			if not ctx or not npc_core.defs.is_custom(ctx.def_id) then
				minetest.chat_send_player(pname,
					S("Built-in NPC cannot be edited."))
				return
			end

			if not selected or selected <= 1 then return end

			local def = npc_core.npc_defs[ctx.def_id]
			local opts = def.pages[ctx.page_id].options

			opts[selected], opts[selected - 1] =
				opts[selected - 1], opts[selected]

			npc_core.editor.options.selected[pname] = selected - 1
			npc_core.defs.save_custom(ctx.def_id, def)
			npc_core.editor.show_options(player, ctx.def_id, ctx.page_id)
			return
		end

		if fields.opt_down then
			if not ctx or not npc_core.defs.is_custom(ctx.def_id) then
				minetest.chat_send_player(pname,
					S("Built-in NPC cannot be edited."))
				return
			end

			if not selected then return end

			local def = npc_core.npc_defs[ctx.def_id]
			local opts = def.pages[ctx.page_id].options

			if selected >= #opts then return end

			opts[selected], opts[selected + 1] =
				opts[selected + 1], opts[selected]

			npc_core.editor.options.selected[pname] = selected + 1
			npc_core.defs.save_custom(ctx.def_id, def)
			npc_core.editor.show_options(player, ctx.def_id, ctx.page_id)
			return
		end

		if fields.back_to_page then
			if ctx then
				npc_core.editor.dialogs.editing_def[pname] = ctx.def_id
				npc_core.editor.show_page(player, ctx.page_id)
			end
			return
		end
	end


	-- Option edit form
	if formname == "npc_core:editor_option" then

		local ctx = npc_core.editor.options.ctx[pname]

		if fields.cancel_opt then
			if ctx then
				npc_core.editor.show_options(player,
					ctx.def_id, ctx.page_id)
			end
			return
		end

		if fields.save_opt then
			if not ctx then return end

			local index = npc_core.editor.options.editing[pname]
			if not index then return end

			local def = npc_core.npc_defs[ctx.def_id]
			local page = def.pages[ctx.page_id]
			local opt = page.options[index]
			if not opt then return end

			opt.text = fields.text or opt.text or ""

			local opt_type = fields.opt_type or "next"
			local target = fields.target or ""

			opt.next = nil
			opt.action = nil

			if target ~= "" then
				if opt_type == "next" then
					opt.next = target
				else
					opt.action = target
				end
			end

			npc_core.defs.save_custom(ctx.def_id, def)

			npc_core.editor.options.editing[pname] = nil
			npc_core.editor.show_options(player, ctx.def_id, ctx.page_id)
			return
		end
	end
end)


-- Chat command
minetest.register_chatcommand("npc_editor", {
	privs = { server = true },
	description = S("Open NPC editor"),

	func = function(name)
		local player = minetest.get_player_by_name(name)
		if not player then return false, S("Player not found") end

		npc_core.editor.show_list(player)
		return true
	end,
})
