-- player walks over key node to receive key and teleport to another location
-- a player detector and command block can be used to call "eventkeys_giveprize <event> @nearest" when player enters a room with all keys
-- or player can walk over a prize node with all keys

-- for those without access to the config.lua file:
	-- use /eventkeys_list to see all events
	-- use /eventkeys_list <event> to see all keys for an event

eventkeys.events = {
	{
		-- setting to false disables the event
		enabled = true,

		-- enter event name in prize node
		-- only use letters, numbers and underscores in event name
		name = "event1",

		-- <short name> <descriptive name> <image>
		-- every key is required to claim prize(s)
		-- enter short name in key node
		-- only use letters, numbers and underscores in short name
		-- add new images to the textures directory in this mod
		keys = {
			{"e1_red", "Red Key", "eventkeys_key.png^[colorize:#f00"},
			{"e1_green", "Green Key", "eventkeys_key.png^[colorize:#0f0"},
			{"e1_blue", "Blue Key", "eventkeys_key.png^[colorize:#00f"},
		},

		-- <quantity> <item>
		-- player must have enough inventory to hold all keys and prizes simultaneously
		-- prizes are given first, then keys are removed
		prizes = {
			{1, "default:sword_diamond"},
		},

		-- play sound for player when prize given
		-- add new sounds to the sounds directory in this mod
		sound = "tnt_ignite",

		-- send message to player when prize given
		message = "Enjoy your sword!",
	},

	-- can have multiple active events
	{
		enabled = true,
		name = "event2",
		keys = {
			{"e2_yellow", "Yellow Key", "eventkeys_key.png^[colorize:#ff0"},
			{"e2_cyan", "Cyan Key", "eventkeys_key.png^[colorize:#0ff"},
			{"e2_magenta", "Magenta Key", "eventkeys_key.png^[colorize:#f0f"},
			{"e2_black", "Black Key", "eventkeys_key.png^[colorize:#000"},
		},
		prizes = {
			{99, "default:stone"},
			{999, "default:dirt"},
		},
		sound = "tnt_ignite",
		message = "Enjoy your prize!",
	},
}
