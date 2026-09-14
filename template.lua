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