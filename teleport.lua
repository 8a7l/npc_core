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

-- teleport.lua
-- NPC teleports:
--   * free and paid
--   * stored in NPC def (like trade)
--   * editor in /npc_editor

local S = minetest.get_translator("npc_core")

npc_core.teleports = {}
npc_core.teleports_editor = {
	def_id = {},
	index = {},
}


-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function validate_cost(str)
	if not str or str == "" then
		return true  -- free
	end

	local stack = ItemStack(str)
	if stack:is_empty() then
		return false, S("invalid format")
	end

	if not minetest.registered_items[stack:get_name()] then
		return false, S("unknown item: @1", stack:get_name())
	end

	return true
end


local function find_tp(def, id)
	local tps = def.teleports or {}

	for _, tp in ipairs(tps) do
		if tp.id == id then
			return tp
		end
	end

	return nil
end


-- ---------------------------------------------------------------------------
-- Use teleport
-- ---------------------------------------------------------------------------

function npc_core.teleports.use(player, npc_name, tp_id)
	local pname = player:get_player_name()
	local def = npc_core.npc_defs[npc_name]

	if not def then
		minetest.chat_send_player(pname,
			S("NPC not found: @1", npc_name))
		return
	end

	tp_id = tonumber(tp_id)

	local tp = find_tp(def, tp_id)
	if not tp then
		minetest.chat_send_player(pname, S("Teleport not found."))
		return
	end

	local inv = player:get_inventory()

	if tp.cost and tp.cost ~= "" then
		if not inv:contains_item("main", tp.cost) then
			minetest.chat_send_player(pname,
				S("Not enough resources for teleport."))
			return
		end
		inv:remove_item("main", tp.cost)
	end

	player:set_pos(tp.pos)
	minetest.show_formspec(pname, "", "")

	minetest.chat_send_player(pname,
		S("Teleport complete: @1", tp.name or "?"))
end


-- ---------------------------------------------------------------------------
-- Teleport editor
-- ---------------------------------------------------------------------------

function npc_core.teleports.editor_show_list(player, def_id)
	local pname = player:get_player_name()
	local def = npc_core.npc_defs[def_id]

	if not def then
		minetest.chat_send_player(pname,
			S("NPC not found: @1", def_id))
		return
	end

	npc_core.teleports_editor.def_id[pname] = def_id

	local tps = def.teleports or {}
	local names = {}

	for i, tp in ipairs(tps) do
		local cost_label = (tp.cost and tp.cost ~= "")
			and (" (" .. tp.cost .. ")")
			or " " .. S(" (free)")

		table.insert(names, (tp.name or S("TP @1", i)) .. cost_label)
	end

	local can_edit = npc_core.defs.is_custom(def_id)

	local new_btn = ""
	local del_btn = ""
	local up_btn = ""
	local down_btn = ""
	if can_edit then
		new_btn = "button[6.5,1;3,0.8;new_tp;" .. S("New") .. "]"
		del_btn = "button[6.5,3;3,0.8;delete_tp;" .. S("Delete") .. "]"
		up_btn = "button[6.5,4;1.4,0.8;tp_up;↑]"
		down_btn = "button[8.1,4;1.4,0.8;tp_down;↓]"
	end

	local list_str = #names > 0 and table.concat(names, ",") or ""

	local selected = npc_core.teleports_editor.index[pname] or 0
	if selected < 0 or selected > #names then
		selected = 0
	end

	minetest.show_formspec(pname, "npc_core:tp_list",
		"size[12,8]" ..
		"label[0.3,0.2;" ..
			minetest.formspec_escape(S("Teleports: @1",
				def.name or def_id)) .. "]" ..
		"label[0.3,0.5;" ..
			S("Price format: mod:item 5 - 5 pieces. Empty - free.") ..
			"]" ..
		"textlist[0.3,1;6,6;tps;" .. list_str .. ";" .. selected .. "]" ..
		new_btn ..
		"button[6.5,2;3,0.8;edit_tp;" .. S("Edit") .. "]" ..
		del_btn ..
		up_btn ..
		down_btn ..
		"button[6.5,5;3,0.8;tp_back;" .. S("Back to NPC") .. "]" ..
		"button_exit[6.5,6;3,0.8;close;" .. S("Close") .. "]"
	)
end


function npc_core.teleports.editor_show_tp(player, def_id, index)
	local pname = player:get_player_name()
	local def = npc_core.npc_defs[def_id]
	if not def then return end

	local tp = def.teleports and def.teleports[index] or {}

	npc_core.teleports_editor.def_id[pname] = def_id
	npc_core.teleports_editor.index[pname] = index

	local title
	if index then
		title = S("Teleport #@1", index)
	else
		title = S("New teleport")
	end

	local px = tp.pos and tp.pos.x or math.floor(player:get_pos().x)
	local py = tp.pos and tp.pos.y or math.floor(player:get_pos().y)
	local pz = tp.pos and tp.pos.z or math.floor(player:get_pos().z)

	local id_label = ""
	if tp.id then
		id_label = S("ID: tp_@1 (for dialog)", tp.id)
	end

	minetest.show_formspec(pname, "npc_core:tp_edit",
		"size[12,7]" ..
		"label[0.3,0.2;" .. minetest.formspec_escape(title) .. "]" ..
		"label[7.5,0.2;" .. minetest.formspec_escape(id_label) .. "]" ..

		"field[0.3,0.7;11,0.8;name;" .. S("Name") .. ";" ..
			minetest.formspec_escape(tp.name or "") .. "]" ..

		"field[0.3,1.7;3.5,0.8;x;X;" .. px .. "]" ..
		"field[4,1.7;3.5,0.8;y;Y;" .. py .. "]" ..
		"field[7.7,1.7;3.5,0.8;z;Z;" .. pz .. "]" ..

		"field[0.3,2.7;11,0.8;cost;" ..
			S("Price (empty - free)") .. ";" ..
			minetest.formspec_escape(tp.cost or "") .. "]" ..

		"label[0.3,3.7;" ..
			S("Format: default:mese_crystal 1 - 1 crystal.") .. "]" ..
		"label[0.3,4.2;" ..
			S("Empty price = free teleport.") .. "]" ..
		"label[0.3,4.7;" ..
			S("Button below - coordinates from current position.") .. "]" ..

		"button[0.3,5.5;3,0.8;here_pos;" .. S("Here") .. "]" ..
		"button[3.5,5.5;2,0.8;save_tp;" .. S("Save") .. "]" ..
		"button[5.7,5.5;2,0.8;cancel_tp;" .. S("Cancel") .. "]"
	)
end


-- ---------------------------------------------------------------------------
-- Formspec handlers
-- ---------------------------------------------------------------------------

minetest.register_on_player_receive_fields(function(player, formname, fields)
	local pname = player:get_player_name()

	-- Teleport list
	if formname == "npc_core:tp_list" then

		if fields.tps then
			local event = minetest.explode_textlist_event(fields.tps)
			if event.type == "CHG" or event.type == "DCL" then
				npc_core.teleports_editor.index[pname] = event.index

				local def_id = npc_core.teleports_editor.def_id[pname]

				minetest.after(0, function()
					local p = minetest.get_player_by_name(pname)
					if p and def_id then
						npc_core.teleports.editor_show_list(p, def_id)
					end
				end)
			end
			return
		end

		local def_id = npc_core.teleports_editor.def_id[pname]
		local selected = npc_core.teleports_editor.index[pname]

		if fields.new_tp then
			if not npc_core.defs.is_custom(def_id) then
				minetest.chat_send_player(pname,
					S("Built-in NPC cannot be edited."))
				return
			end

			npc_core.teleports.editor_show_tp(player, def_id, nil)
			return
		end

		if fields.edit_tp then
			if not selected then
				minetest.chat_send_player(pname,
					S("Select a teleport first."))
				return
			end
			npc_core.teleports.editor_show_tp(player, def_id, selected)
			return
		end

		if fields.delete_tp then
			if not selected then
				minetest.chat_send_player(pname,
					S("Select a teleport first."))
				return
			end

			if not npc_core.defs.is_custom(def_id) then
				minetest.chat_send_player(pname,
					S("Built-in NPC cannot be edited."))
				return
			end

			local def = npc_core.npc_defs[def_id]
			table.remove(def.teleports, selected)
			npc_core.defs.save_custom(def_id, def)

			npc_core.teleports_editor.index[pname] = nil
			npc_core.teleports.editor_show_list(player, def_id)
			return
		end

		if fields.tp_up then
			if not selected or selected <= 1 then return end

			if not npc_core.defs.is_custom(def_id) then
				minetest.chat_send_player(pname,
					S("Built-in NPC cannot be edited."))
				return
			end

			local def = npc_core.npc_defs[def_id]
			local t = def.teleports

			t[selected], t[selected - 1] = t[selected - 1], t[selected]

			npc_core.teleports_editor.index[pname] = selected - 1
			npc_core.defs.save_custom(def_id, def)
			npc_core.teleports.editor_show_list(player, def_id)
			return
		end

		if fields.tp_down then
			if not selected then return end

			local def = npc_core.npc_defs[def_id]
			if selected >= #def.teleports then return end

			if not npc_core.defs.is_custom(def_id) then
				minetest.chat_send_player(pname,
					S("Built-in NPC cannot be edited."))
				return
			end

			local t = def.teleports
			t[selected], t[selected + 1] = t[selected + 1], t[selected]

			npc_core.teleports_editor.index[pname] = selected + 1
			npc_core.defs.save_custom(def_id, def)
			npc_core.teleports.editor_show_list(player, def_id)
			return
		end

		if fields.tp_back then
			npc_core.editor.show_form(player, def_id, false)
			return
		end
	end


	-- Teleport edit form
	if formname == "npc_core:tp_edit" then

		local def_id = npc_core.teleports_editor.def_id[pname]
		local index = npc_core.teleports_editor.index[pname]

		if fields.cancel_tp then
			npc_core.teleports.editor_show_list(player, def_id)
			return
		end

		if fields.here_pos then
			local pos = player:get_pos()
			local x = math.floor(pos.x)
			local y = math.floor(pos.y)
			local z = math.floor(pos.z)

			local name = fields.name or ""
			local cost = fields.cost or ""

			minetest.show_formspec(pname, "npc_core:tp_edit",
				"size[12,7]" ..
				"label[0.3,0.2;" ..
					minetest.formspec_escape(
						index and S("Teleport #@1", index)
							or S("New teleport")
					) .. "]" ..
				"label[7.5,0.2;" ..
					minetest.formspec_escape(
						index and S("ID: tp_@1 (for dialog)",
							npc_core.npc_defs[def_id]
								.teleports[index].id or "?")
							or ""
					) .. "]" ..
				"field[0.3,0.7;11,0.8;name;" .. S("Name") .. ";" ..
					minetest.formspec_escape(name) .. "]" ..
				"field[0.3,1.7;3.5,0.8;x;X;" .. x .. "]" ..
				"field[4,1.7;3.5,0.8;y;Y;" .. y .. "]" ..
				"field[7.7,1.7;3.5,0.8;z;Z;" .. z .. "]" ..
				"field[0.3,2.7;11,0.8;cost;" ..
					S("Price (empty - free)") .. ";" ..
					minetest.formspec_escape(cost) .. "]" ..
				"label[0.3,3.7;" ..
					S("Format: default:mese_crystal 1 - 1 crystal.") .. "]" ..
				"label[0.3,4.2;" ..
					S("Empty price = free teleport.") .. "]" ..
				"label[0.3,4.7;" ..
					S("Button below - coordinates from current position.") .. "]" ..
				"button[0.3,5.5;3,0.8;here_pos;" .. S("Here") .. "]" ..
				"button[3.5,5.5;2,0.8;save_tp;" .. S("Save") .. "]" ..
				"button[5.7,5.5;2,0.8;cancel_tp;" .. S("Cancel") .. "]"
			)
			return
		end

		if fields.save_tp then
			local name = fields.name or ""
			local cost = fields.cost or ""

			if name == "" then
				minetest.chat_send_player(pname, S("Enter name."))
				return
			end

			local x = tonumber(fields.x)
			local y = tonumber(fields.y)
			local z = tonumber(fields.z)

			if not x or not y or not z then
				minetest.chat_send_player(pname,
					S("Coordinates must be numbers."))
				return
			end

			local ok, err = validate_cost(cost)
			if not ok then
				minetest.chat_send_player(pname,
					S("Error in price: @1", err))
				return
			end

			local def = npc_core.npc_defs[def_id]
			def.teleports = def.teleports or {}

			if index then
				local tp = def.teleports[index]
				tp.name = name
				tp.pos = {x = x, y = y, z = z}
				tp.cost = cost
			else
				local max_id = 0
				for _, t in ipairs(def.teleports) do
					if t.id and t.id > max_id then
						max_id = t.id
					end
				end

				table.insert(def.teleports, {
					id = max_id + 1,
					name = name,
					pos = {x = x, y = y, z = z},
					cost = cost,
				})
			end

			npc_core.defs.save_custom(def_id, def)

			npc_core.teleports.editor_show_list(player, def_id)
			return
		end
	end
end)
