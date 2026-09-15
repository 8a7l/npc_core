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

npc_core.npc_defs.template = {
	name = "NPC",
	profession = "",
	location = "",
	texture = "character.png",
	info = "",

	pages = {
		start = {
			text = S("Hi."),
			options = {
				{ text = S("Who are you?"), next = "about" },
			},
		},

		about = {
			text = S("I'm an NPC."),
			options = {
				{ text = S("Back"), next = "start" },
			},
		},
	},
}
