-- trade.lua
-- NPC shop in dialog style.

local S = minetest.get_translator("npc_core")

npc_core.trade = {}
npc_core.trade_selected = {}

npc_core.trade_editor = {
	def_id = {},
	index = {},
}


-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function short_item_name(itemstring)
	local stack = ItemStack(itemstring)
	if stack:is_empty() then return "?" end

	local desc = stack:get_description() or stack:get_name()
	if desc == "" then
		desc = stack:get_name()
	end

	return desc
end


local function parse_item_list(str)
	local list = {}

	if not str or str == "" then
		return list
	end

	for item in str:gmatch("[^,]+") do
		item = item:match("^%s*(.-)%s*$")
		if item ~= "" then
			table.insert(list, item)
		end
	end

	return list
end


local function validate_single(str)
	if not str or str == "" then
		return false, S("empty")
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


local function validate_list(str)
	local list = parse_item_list(str)

	if #list == 0 then
		return false, S("empty")
	end

	for _, item in ipairs(list) do
		local ok, err = validate_single(item)
		if not ok then
			return false, err
		end
	end

	return true
end


local function escape_hypertext(s)
	s = s:gsub("&", "&amp;")
	s = s:gsub("<", "&lt;")
	s = s:gsub(">", "&gt;")
	return s
end


-- Build hypertext for a single trade.
-- NOTE: in Luanti hypertext, line break is \n, not <br>.
-- The <item> tag draws an item icon.
local function build_trade_hypertext(trade)
	local parts = {}

	parts[#parts + 1] = "  " .. S("You give:") .. "\n"

	for _, need in ipairs(parse_item_list(trade.need)) do
		local stack = ItemStack(need)

		parts[#parts + 1] = "  <item name=\""
			.. stack:get_name() .. "\"> "

		parts[#parts + 1] = escape_hypertext(stack:get_count()
			.. " × " .. short_item_name(need)) .. "\n"
	end

	parts[#parts + 1] = "\n  " .. S("You receive:") .. "\n"

	for _, give in ipairs(parse_item_list(trade.give)) do
		local stack = ItemStack(give)

		parts[#parts + 1] = "  <item name=\""
			.. stack:get_name() .. "\"> "

		parts[#parts + 1] = escape_hypertext(stack:get_count()
			.. " × " .. short_item_name(give)) .. "\n"
	end

	return table.concat(parts, "")
end


-- ---------------------------------------------------------------------------
-- Show shop
-- ---------------------------------------------------------------------------

function npc_core.trade.show(player, npc_name)
	local pname = player:get_player_name()
	local def = npc_core.npc_defs[npc_name]

	if not def then
		minetest.chat_send_player(pname,
			S("NPC not found: @1", npc_name))
		return
	end

	local trades = def.trade or {}

	if #trades == 0 then
		minetest.show_formspec(pname, "npc_core:shop_empty:" .. npc_name,
			"size[6,3]" ..
			"label[0.3,0.5;" .. S("This NPC has no wares.") .. "]" ..
			"button_exit[2,2;2,0.8;close;" .. S("Close") .. "]"
		)
		return
	end

	local names = {}
	for i, t in ipairs(trades) do
		local n = (t.name or ("Item " .. i)):gsub(",", "·")
		table.insert(names, n)
	end

	local selected = npc_core.trade_selected[pname] or 1
	if selected < 1 or selected > #trades then
		selected = 1
	end
	npc_core.trade_selected[pname] = selected

	local trade = trades[selected]
	local content = build_trade_hypertext(trade)

	local formspec = "size[14,10]" ..
		"label[0.3,0.2;" ..
			minetest.formspec_escape(S("Shop: @1",
				def.name or npc_name)) .. "]" ..
		"label[0.3,0.7;" .. S("Wares:") .. "]" ..
		"textlist[0.3,1.1;4,8;trades;" ..
			table.concat(names, ",") .. ";" .. selected .. "]" ..

		"hypertext[5.4,0.7;8.4,7.8;shop_content;<normal>" ..
			content .. "</normal>]" ..

		"button[11,8.7;2.5,0.8;exchange;" .. S("Exchange") .. "]" ..
		"button_exit[11,9.6;2.5,0.5;close;" .. S("Close") .. "]"

	minetest.show_formspec(pname, "npc_core:shop:" .. npc_name, formspec)
end


-- ---------------------------------------------------------------------------
-- Exchange
-- ---------------------------------------------------------------------------

function npc_core.trade.exchange(player, npc_name, index)
	local pname = player:get_player_name()
	local def = npc_core.npc_defs[npc_name]
	if not def then return false, S("NPC not found: @1", npc_name) end

	local trades = def.trade or {}
	local trade = trades[index]
	if not trade then return false, "Item not found" end

	local inv = player:get_inventory()
	local need_list = parse_item_list(trade.need)
	local give_list = parse_item_list(trade.give)

	for _, need in ipairs(need_list) do
		if not inv:contains_item("main", need) then
			return false, S("Not enough: @1", short_item_name(need))
		end
	end

	for _, give in ipairs(give_list) do
		if not inv:room_for_item("main", give) then
			return false, S("No room for: @1", short_item_name(give))
		end
	end

	for _, need in ipairs(need_list) do
		inv:remove_item("main", need)
	end
	for _, give in ipairs(give_list) do
		inv:add_item("main", give)
	end

	return true, S("Trade complete")
end


function npc_core.actions.show_shop(player, npc_name)
	npc_core.trade.show(player, npc_name)
end


npc_core.show_shop = function(player, npc_name)
	npc_core.trade.show(player, npc_name)
end


-- ---------------------------------------------------------------------------
-- Trade editor
-- ---------------------------------------------------------------------------

function npc_core.trade.editor_show_list(player, def_id)
	local pname = player:get_player_name()
	local def = npc_core.npc_defs[def_id]

	if not def then
		minetest.chat_send_player(pname,
			S("NPC not found: @1", def_id))
		return
	end

	npc_core.trade_editor.def_id[pname] = def_id

	local trades = def.trade or {}
	local names = {}

	for i, t in ipairs(trades) do
		local n = (t.name or ("Item " .. i)):gsub(",", "·")
		table.insert(names, n)
	end

	local can_edit = npc_core.defs.is_custom(def_id)

	local new_btn = ""
	local del_btn = ""
	local up_btn = ""
	local down_btn = ""
	if can_edit then
		new_btn = "button[6.5,1;3,0.8;new_trade;" .. S("New") .. "]"
		del_btn = "button[6.5,3;3,0.8;delete_trade;" .. S("Delete") .. "]"
		up_btn = "button[6.5,4;1.4,0.8;move_up;↑]"
		down_btn = "button[8.1,4;1.4,0.8;move_down;↓]"
	end

	local list_str = #names > 0 and table.concat(names, ",") or ""

	local selected = npc_core.trade_editor.index[pname] or 0
	if selected < 0 or selected > #names then
		selected = 0
	end

	minetest.show_formspec(pname, "npc_core:trade_list",
		"size[10,8]" ..
		"label[0.3,0.2;" ..
			minetest.formspec_escape(S("Trade: @1",
				def.name or def_id)) .. "]" ..
		"textlist[0.3,1;6,6;trades;" .. list_str .. ";" .. selected .. "]" ..
		new_btn ..
		"button[6.5,2;3,0.8;edit_trade;" .. S("Edit") .. "]" ..
		del_btn ..
		up_btn ..
		down_btn ..
		"button[6.5,5;3,0.8;back;" .. S("Back to NPC") .. "]" ..
		"button[6.5,6;3,0.8;close;" .. S("Close") .. "]"
	)
end


function npc_core.trade.editor_show_trade(player, def_id, index)
	local pname = player:get_player_name()
	local def = npc_core.npc_defs[def_id]
	if not def then return end

	local trade = def.trade and def.trade[index] or {}

	npc_core.trade_editor.def_id[pname] = def_id
	npc_core.trade_editor.index[pname] = index

	local title
	if index then
		title = S("Item #@1", index)
	else
		title = S("New item")
	end

	minetest.show_formspec(pname, "npc_core:trade_edit",
		"size[12,7]" ..
		"label[0.3,0.2;" .. minetest.formspec_escape(title) .. "]" ..

		"field[0.3,0.7;11,0.8;name;" .. S("Item name") .. ";" ..
			minetest.formspec_escape(trade.name or "") .. "]" ..

		"field[0.3,1.7;11,0.8;need;" ..
			S("You give (comma-separated list)") .. ";" ..
			minetest.formspec_escape(trade.need or "") .. "]" ..

		"field[0.3,2.7;11,0.8;give;" ..
			S("You receive (comma-separated list)") .. ";" ..
			minetest.formspec_escape(trade.give or "") .. "]" ..

		"label[0.3,3.7;" ..
			S("Single item format: mod:item 10 - 10 pieces. Without number - 1.") ..
			"]" ..
		"label[0.3,4.2;" ..
			S("Multiple items - comma-separated: default:sword_steel 1, default:sword_stone 1") ..
			"]" ..

		"button[0.3,5;2,0.8;save_trade;" .. S("Save") .. "]" ..
		"button[2.5,5;2,0.8;cancel_trade;" .. S("Cancel") .. "]"
	)
end


-- ---------------------------------------------------------------------------
-- Formspec handlers
-- ---------------------------------------------------------------------------

minetest.register_on_player_receive_fields(function(player, formname, fields)
	local pname = player:get_player_name()

	if formname:match("^npc_core:shop:") then
		local npc_name = formname:match("^npc_core:shop:(.+)$")

		if fields.trades then
			local event = minetest.explode_textlist_event(fields.trades)
			if event.type == "CHG" or event.type == "DCL" then
				npc_core.trade_selected[pname] = event.index

				minetest.after(0, function()
					local p = minetest.get_player_by_name(pname)
					if p then
						npc_core.trade.show(p, npc_name)
					end
				end)
			end
			return
		end

		if fields.exchange then
			local index = npc_core.trade_selected[pname] or 1
			local ok, msg = npc_core.trade.exchange(player, npc_name, index)
			minetest.chat_send_player(pname, msg)
			if ok then
				npc_core.trade.show(player, npc_name)
			end
			return
		end
	end


	if formname == "npc_core:trade_list" then

		if fields.close then
			minetest.close_formspec(pname, "npc_core:trade_list")
			return
		end

		if fields.trades then
			local event = minetest.explode_textlist_event(fields.trades)
			if event.type == "CHG" or event.type == "DCL" then
				npc_core.trade_editor.index[pname] = event.index

				local def_id = npc_core.trade_editor.def_id[pname]

				minetest.after(0, function()
					local p = minetest.get_player_by_name(pname)
					if p and def_id then
						npc_core.trade.editor_show_list(p, def_id)
					end
				end)
			end
			return
		end

		local def_id = npc_core.trade_editor.def_id[pname]
		local selected = npc_core.trade_editor.index[pname]

		if fields.new_trade then
			if not npc_core.defs.is_custom(def_id) then
				minetest.chat_send_player(pname,
					S("Built-in NPC cannot be edited."))
				return
			end
			npc_core.trade.editor_show_trade(player, def_id, nil)
			return
		end

		if fields.edit_trade then
			if not selected then
				minetest.chat_send_player(pname,
					S("Select an item first."))
				return
			end
			npc_core.trade.editor_show_trade(player, def_id, selected)
			return
		end

		if fields.delete_trade then
			if not selected then
				minetest.chat_send_player(pname,
					S("Select an item first."))
				return
			end

			if not npc_core.defs.is_custom(def_id) then
				minetest.chat_send_player(pname,
					S("Built-in NPC cannot be edited."))
				return
			end

			local def = npc_core.npc_defs[def_id]
			table.remove(def.trade, selected)
			npc_core.defs.save_custom(def_id, def)

			npc_core.trade_editor.index[pname] = nil
			npc_core.trade.editor_show_list(player, def_id)
			return
		end

		if fields.move_up then
			if not selected or selected <= 1 then return end

			if not npc_core.defs.is_custom(def_id) then
				minetest.chat_send_player(pname,
					S("Built-in NPC cannot be edited."))
				return
			end

			local def = npc_core.npc_defs[def_id]
			local t = def.trade

			t[selected], t[selected - 1] = t[selected - 1], t[selected]

			npc_core.trade_editor.index[pname] = selected - 1
			npc_core.defs.save_custom(def_id, def)
			npc_core.trade.editor_show_list(player, def_id)
			return
		end

		if fields.move_down then
			if not selected then return end

			local def = npc_core.npc_defs[def_id]
			local t = def.trade

			if selected >= #t then return end

			if not npc_core.defs.is_custom(def_id) then
				minetest.chat_send_player(pname,
					S("Built-in NPC cannot be edited."))
				return
			end

			t[selected], t[selected + 1] = t[selected + 1], t[selected]

			npc_core.trade_editor.index[pname] = selected + 1
			npc_core.defs.save_custom(def_id, def)
			npc_core.trade.editor_show_list(player, def_id)
			return
		end

		if fields.back then
			npc_core.editor.show_form(player, def_id, false)
			return
		end
	end


	if formname == "npc_core:trade_edit" then

		local def_id = npc_core.trade_editor.def_id[pname]
		local index = npc_core.trade_editor.index[pname]

		if fields.cancel_trade then
			npc_core.trade.editor_show_list(player, def_id)
			return
		end

		if fields.save_trade then
			local name = fields.name or ""
			local need = fields.need or ""
			local give = fields.give or ""

			if name == "" then
				minetest.chat_send_player(pname,
					S("Enter item name."))
				return
			end

			local ok_need, err_need = validate_list(need)
			if not ok_need then
				minetest.chat_send_player(pname,
					S("Error in \"You give\": @1", err_need))
				return
			end

			local ok_give, err_give = validate_list(give)
			if not ok_give then
				minetest.chat_send_player(pname,
					S("Error in \"You receive\": @1", err_give))
				return
			end

			local def = npc_core.npc_defs[def_id]
			def.trade = def.trade or {}

			local trade_data = {
				name = name,
				need = need,
				give = give,
			}

			if index then
				def.trade[index] = trade_data
			else
				table.insert(def.trade, trade_data)
			end

			npc_core.defs.save_custom(def_id, def)

			npc_core.trade.editor_show_list(player, def_id)
			return
		end
	end
end)