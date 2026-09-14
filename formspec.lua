-- formspec.lua
-- Formspec handling + player dialogs.

local S = minetest.get_translator("npc_core")


-- ---------------------------------------------------------------------------
-- Formspec handling
-- ---------------------------------------------------------------------------

minetest.register_on_player_receive_fields(function(player, formname, fields)
	local pname = player:get_player_name()

	-- Old NPC editor
	if formname == "npc_core:edit" then
		if fields.save then
			local npc = npc_core.editing[pname]
			if npc and fields.def then
				npc.npc_data.def = fields.def

				local def = npc_core.npc_defs[fields.def]
				if def and def.texture then
					npc.object:set_properties({
						textures = { def.texture },
					})
				end
			end
			npc_core.editing[pname] = nil
		end
		return
	end

	-- NPC directory
	if formname == "npc_core:npc_directory" then
		if not fields.npcs then return end

		local event = minetest.explode_textlist_event(fields.npcs)

		if event.type == "CHG" or event.type == "DCL" then
			local npc_id = npc_core.directory_list[event.index]

			if npc_id then
				npc_core.selected_npc[pname] = npc_id

				minetest.after(0, function()
					local p = minetest.get_player_by_name(pname)
					if p then
						npc_core.show_npc_directory(p)
					end
				end)
			end
		end

		return
	end

	-- Dialog option selection
	if fields.options then
		local event = minetest.explode_textlist_event(fields.options)
		if event.type ~= "DCL" then return end

		local options = npc_core.current_options[pname]
		if not options then return end

		local option = options[event.index]
		if not option then return end

		local npc_name = formname:match("^npc_core:([^:]+):")
		if not npc_name then return end

		if option.action then
			npc_core.log("action = " .. tostring(option.action))

			local tp_id = option.action:match("^tp_(.+)$")
			if tp_id then
				npc_core.teleports.use(player, npc_name, tp_id)
				return
			end

			local trade_id = option.action:match("^trade_(%d+)$")
			if trade_id then
				local shop_npc = npc_core.current_shop[pname]
				npc_core.trade.buy(player, shop_npc, tonumber(trade_id))
				return
			end

			local show_id = option.action:match("^show_info_(.+)$")
			if show_id then
				npc_core.show_npc_info(player, show_id)
				return
			end

			local action = npc_core.actions[option.action]
			if action then
				action(player, npc_name)
				return
			end

			local def = npc_core.npc_defs[npc_name]
			if def and def[option.action] then
				def[option.action](player)
				return
			end

			return
		end

		if option.next then
			npc_core.show_dialog(player, npc_name, option.next)
			return
		end
	end

	-- Dialog buttons
	local npc_name = formname:match("^npc_core:([^:]+):")
	if not npc_name then return end

	for button in pairs(fields) do
		if button ~= "quit" and button ~= "dialog"
			and button ~= "close" then
			local def = npc_core.npc_defs[npc_name]

			if def and def[button] then
				def[button](player)
				return
			end

			npc_core.show_dialog(player, npc_name, button)
			return
		end
	end
end)


-- ---------------------------------------------------------------------------
-- Escape for hypertext
-- ---------------------------------------------------------------------------

local function escape_hypertext(s)
	s = s:gsub("&", "&amp;")
	s = s:gsub("<", "&lt;")
	s = s:gsub(">", "&gt;")
	return s
end


-- ---------------------------------------------------------------------------
-- Dialog with pages
-- ---------------------------------------------------------------------------

function npc_core.show_dialog(player, npc_name, page)
	local pname = player:get_player_name()

	local def = npc_core.npc_defs[npc_name]
	if not def then
		npc_core.log("NPC def not found: " .. tostring(npc_name))
		return
	end

	local dialog = def.pages
	if not dialog then return end

	local node = dialog[page]
	if not node then return end

	local title = def.name or npc_name
	local text = escape_hypertext(node.text or "")

	local formspec = "size[14,10]" ..
		"label[0.3,0.2;" ..
			minetest.formspec_escape(S("Dialog: @1", title)) .. "]" ..
		"hypertext[0.3,0.7;8.2,8.5;dialog;<normal>" ..
			text .. "</normal>]"

	if node.options then
		npc_core.current_options[pname] = node.options

		local list = {}
		for _, option in ipairs(node.options) do
			table.insert(list, option.text)
		end

		formspec = formspec ..
			"label[8.7,0.7;" .. S("Reply options:") .. "]" ..
			"textlist[8.7,1.1;4.8,7;options;" ..
			table.concat(list, ",") .. ";0]"
	end

	formspec = formspec ..
		"button_exit[11,8.7;2.5,0.8;close;" .. S("Close") .. "]"

	minetest.show_formspec(pname, "npc_core:" .. npc_name .. ":" .. page, formspec)
end


-- ---------------------------------------------------------------------------
-- Custom dialog
-- ---------------------------------------------------------------------------

function npc_core.show_custom_dialog(player, npc_name, title, text, options)
	local pname = player:get_player_name()

	npc_core.current_options[pname] = options

	local list = {}
	for _, option in ipairs(options) do
		table.insert(list, option.text)
	end

	local escaped = escape_hypertext(text or "")

	local formspec = "size[14,10]" ..
		"label[0.3,0.2;" ..
			minetest.formspec_escape(S("Dialog: @1", title)) .. "]" ..
		"hypertext[0.3,0.7;8.2,8.5;dialog;<normal>" ..
			escaped .. "</normal>]" ..
		"label[8.7,0.7;" .. S("Reply options:") .. "]" ..
		"textlist[8.7,1.1;4.8,7;options;" ..
			table.concat(list, ",") .. ";0]" ..
		"button_exit[11,8.7;2.5,0.8;close;" .. S("Close") .. "]"

	minetest.show_formspec(pname, "npc_core:" .. npc_name .. ":custom", formspec)
end


-- ---------------------------------------------------------------------------
-- NPC directory
-- ---------------------------------------------------------------------------

function npc_core.show_npc_directory(player)
	local pname = player:get_player_name()

	local names = {}
	local ids = {}

	for id, def in pairs(npc_core.npc_defs) do
		if id ~= "template" then
			local n = (def.name or id):gsub(",", "·")
			table.insert(names, n)
			table.insert(ids, id)
		end
	end

	local sorted = {}
	for i, name in ipairs(names) do
		table.insert(sorted, { name = name, id = ids[i] })
	end
	table.sort(sorted, function(a, b) return a.name < b.name end)

	names = {}
	npc_core.directory_list = {}

	for _, e in ipairs(sorted) do
		table.insert(names, e.name)
		table.insert(npc_core.directory_list, e.id)
	end

	local selected_idx = 0
	local selected = npc_core.selected_npc[pname]

	if selected then
		for i, id in ipairs(npc_core.directory_list) do
			if id == selected then
				selected_idx = i
				break
			end
		end
	end

	local info = S("Choose a resident from the list.")

	if selected then
		local def = npc_core.npc_defs[selected]
		if def then
			info = S("Name: @1", def.name or selected) .. "\n\n" ..
				S("Profession: @1", def.profession or "-") .. "\n\n" ..
				(def.info or "-") .. "\n\n" ..
				S("Location: @1", def.location or "-")
		end
	end

	info = info:gsub("&", "&amp;")
	info = info:gsub("<", "&lt;")
	info = info:gsub(">", "&gt;")

	minetest.show_formspec(pname, "npc_core:npc_directory",
		"size[14,10]" ..
		"label[0.3,0.2;" .. S("Residents directory") .. "]" ..
		"hypertext[0.3,0.7;8.2,8.5;info;<normal>" ..
			info .. "</normal>]" ..
		"label[8.7,0.7;" .. S("Residents:") .. "]" ..
		"textlist[8.7,1.1;4.8,7;npcs;" ..
			table.concat(names, ",") .. ";" .. selected_idx .. "]" ..
		"button_exit[11,8.7;2.5,0.8;close;" .. S("Close") .. "]"
	)
end