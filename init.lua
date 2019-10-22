eventkeys = {}
local MP = minetest.get_modpath("eventkeys").."/"



local add_key_entity = function(pos)
	local meta = minetest.get_meta(pos)
	if not meta or meta:get_string("key") == "" then return end

	minetest.add_entity(pos, "eventkeys:key_entity")
end

local remove_key_entity = function(pos)
	local objects = minetest.get_objects_inside_radius(pos, 0.001)
	if objects then
		for _,o in ipairs(objects) do
			if o and o:get_luaentity() and o:get_luaentity().name == "eventkeys:key_entity" then
				o:remove()
			end
		end
	end
end



local particle_amount = tonumber(minetest.settings:get("eventkeys_particle_amount") or 25)
local particle_time = tonumber(minetest.settings:get("eventkeys_particle_time") or 2)

local spawn_teleport_particles = function(pos, start_y, vel, duration)
	minetest.add_particlespawner({
		amount = particle_amount,
		time = particle_time,
		minpos = {x=pos.x-0.4, y=pos.y+start_y, z=pos.z-0.4},
		maxpos = {x=pos.x+0.4, y=pos.y+start_y, z=pos.z+0.4},
		minvel = {x=0, y=vel, z=0},
		maxvel = {x=0, y=vel, z=0},
		minacc = {x=0, y=0, z=0},
		maxacc = {x=0, y=0, z=0},
		minexptime = duration,
		maxexptime = duration,
		minsize = 0.2,
		maxsize = 0.4,
		collisiondetection = false,
		vertical = true,
		texture = "eventkeys_particle.png",
		glow = 15
	})
end

local get_key = function(player_name, name)
	for _,e in pairs(eventkeys.events) do
		for _,k in pairs(e.keys) do
			if k[1] == name then
				return k
			end
		end
	end
	if player_name then
		minetest.chat_send_player(player_name, "Invalid key: "..name)
	end
	return nil
end

local get_event = function(player_name, name)
	for _,e in pairs(eventkeys.events) do
		if e.name == name then
			if e.enabled ~= true then
				minetest.chat_send_player(player_name, "Disabled event: "..name)
				return nil
			end
			return e
		end
	end
	minetest.chat_send_player(player_name, "Invalid event: "..name)
	return nil
end

local give_prize = function(event, player, player_name)
	if event == nil then return end

	local inv = player:get_inventory()

	-- check for keys and empty slots
	local keys = {}
	local missing_keys = {}
	for _,k in pairs(event.key_names) do table.insert(missing_keys, "eventkeys:item_"..k) end
	local nr_keys_found = 0
	local empty_slots = 0
	for _,s in pairs(inv:get_list('main') or {}) do
		local slot = s:get_name()
		if slot == "" then
			empty_slots = empty_slots + 1
		else
			for i,k in pairs(missing_keys) do
				if slot == k then
					nr_keys_found = nr_keys_found + 1
					table.insert(keys, table.remove(missing_keys, i))
					break
				end
			end
		end
	end
	if nr_keys_found < event.nr_keys then
		minetest.chat_send_player(player_name, "You have "..nr_keys_found.." of the "..event.nr_keys.." keys, keep looking!")
-- TODO: tell player which keys are missing?
		return
	end
	if empty_slots < event.nr_prizes then
		minetest.chat_send_player(player_name, "You need "..event.nr_prizes.." empty inventory slot(s) to receive your prize(s)")
		return
	end

	-- add prize items to player's inventory
	for _,k in pairs(event.prizes) do
		local quantity = k[1]
		local prize = k[2]
		inv:add_item("main", prize.." "..quantity)
		minetest.log("action", "give "..quantity.." "..prize.." event prize to "..player:get_player_name())
	end

	-- remove keys from player's inventory
	for _,s in pairs(inv:get_list('main') or {}) do
		local slot = s:get_name()
		if slot ~= "" then
			for i,k in pairs(keys) do
				if slot == k then
					inv:remove_item('main', s)
					table.remove(keys, i)
					break
				end
			end
			if keys[1] == nil then break end
		end
	end

	-- play sound when prize is given
	if event.sound then minetest.sound_play(event.sound, {pos = player:getpos(), gain = 1.0, max_hear_distance = 5}) end
	-- send message when prize is given
	if event.message then minetest.chat_send_player(player_name, event.message) end
end

local set_key_infotext = function(player_name, meta)
	local key = get_key(player_name, meta:get_string("key"))
	if key == nil then
		meta:set_string("infotext", "Not configured!")
	else
		meta:set_string("infotext", key[2])
	end
end

local set_prize_infotext = function(meta)
	if meta:get_string("event") == "" then
		meta:set_string("infotext", "Not configured!")
	else
		meta:set_string("infotext", "Walk over to claim prize.")
	end
end



local max_coord = tonumber(minetest.settings:get("map_generation_limit") or 31000)
local key_node_timer = tonumber(minetest.settings:get("eventkeys_key_node_timer") or 0.5)
local prize_node_timer = tonumber(minetest.settings:get("eventkeys_prize_node_timer") or 2.0)

local is_int_or_float = function(str)
	if string.match(str, '^-?%d+$') == nil and string.match(str, '^-?%d+[.]%d+$') == nil then return false end
	return true
end

local parse_teleport_coords = function(str)
	if not str or str == "" then return nil end

	local x,y,z = string.match(str, "^ *(-?[.%d]+) *, *(-?[.%d]+) *, *(-?[.%d]+) *$")
	if x == nil or y == nil or z == nil then
		return nil
	end
	if not is_int_or_float(x) then return nil end
	if not is_int_or_float(y) then return nil end
	if not is_int_or_float(z) then return nil end
	x = x + 0.0
	y = y + 0.0
	z = z + 0.0

	if x < -max_coord or x > max_coord
	or y < -max_coord or y > max_coord
	or z < -max_coord or z > max_coord then
		return nil
	end

	return {x=x, y=y, z=z}
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if string.sub(formname, 0, string.len("eventkeys:form_")) ~= "eventkeys:form_" then return end

	local pos_str = string.sub(formname, string.len("eventkeys:form_")+1)
	local pos = minetest.string_to_pos(pos_str)
	if minetest.is_protected(pos, player:get_player_name()) then return end

	local meta = minetest.get_meta(pos)
	if not meta then return end

	if fields.cancel then return end

	if fields.coords ~= nil then
		-- key node

		meta:set_string("key", fields.key)
		remove_key_entity(pos)
		if get_key(nil, fields.key) then
			add_key_entity(pos)
		end
		minetest.get_node_timer(pos):start(key_node_timer)

		local dst_pos = parse_teleport_coords(fields.coords)
		if dst_pos ~= nil then
			meta:set_float("x", dst_pos.x)
			meta:set_float("y", dst_pos.y)
			meta:set_float("z", dst_pos.z)
		end

		local yaw = tonumber(fields.yaw)
		if yaw < 0 then
			yaw = 0
		elseif yaw > 359 then
			yaw = 359
		end
		meta:set_int("yaw", yaw)

		set_key_infotext(player:get_player_name(), meta)
	elseif fields.event ~= nil then
		-- prize node

		meta:set_string("event", fields.event)
		get_event(player:get_player_name(), fields.event)
		minetest.get_node_timer(pos):start(prize_node_timer)

		set_prize_infotext(meta)
	end
end)



dofile(MP.."config.lua")
for _,e in pairs(eventkeys.events) do
	if e.name == nil or e.name == "" then
		minetest.log("error", "each event in config.lua eventkeys.events MUST have an event name")
	elseif e.keys == nil then
		minetest.log("error", "each event in config.lua eventkeys.events MUST have at least one key")
	elseif e.prizes == nil then
		minetest.log("error", "each event in config.lua eventkeys.events MUST have at least one prize")
	elseif e.enabled == true then
		-- register keys
		e.nr_keys = 0
		e.key_names = {}
		for _,k in pairs(e.keys) do
			local name = k[1]
			local desc = k[2]
			local image = k[3]

			e.nr_keys = e.nr_keys + 1

			table.insert(e.key_names, name)

			minetest.register_tool("eventkeys:item_"..name, {
				description = desc,
				inventory_image = image,
				on_use = function(itemstack, user, pointed_thing) return itemstack end,
				on_place = function(itemstack, user, pointed_thing) return itemstack end,
			})
		end

		e.nr_prizes = 0
		for _ in pairs(e.prizes) do e.nr_prizes = e.nr_prizes + 1 end
	end
end



minetest.register_tool("eventkeys:coord_tool", {
	description = "sneak left-click to save coordinates and yaw  •  sneak right-click key node to configure",
	inventory_image = "default_stick.png",
	on_use = function(itemstack, user, pointed_thing)
		if not user or not user:get_player_control()["sneak"] then return itemstack end

		local tool_meta = itemstack:get_meta()
		if tool_meta == nil then return itemstack end

		local pos = user:getpos()
		tool_meta:set_float("x", pos.x)
		tool_meta:set_float("y", pos.y)
		tool_meta:set_float("z", pos.z)
		tool_meta:set_int("yaw", 360*user:get_look_horizontal()/(2*math.pi))

		minetest.chat_send_player(user:get_player_name(), "Current position and yaw saved in tool.")

		return itemstack
	end,
	on_place = function(itemstack, user, pointed_thing)
		if not user or not user:get_player_control()["sneak"] then return itemstack end
		if pointed_thing.type ~= "node" then return itemstack end
		local pos = pointed_thing.under
		local node = minetest.get_node(pos)
		if node.name ~= "eventkeys:key_node" or minetest.is_protected(pos, user:get_player_name()) then return itemstack end

		local tool_meta = itemstack:get_meta()
		if tool_meta == nil then return itemstack end
		local meta = minetest.get_meta(pos)
		if meta == nil then return itemstack end

		meta:set_float("x", tool_meta:get_float("x"))
		meta:set_float("y", tool_meta:get_float("y"))
		meta:set_float("z", tool_meta:get_float("z"))
		meta:set_int("yaw", tool_meta:get_int("yaw"))

		minetest.chat_send_player(user:get_player_name(), "Position and yaw transfered to key node.")

		return itemstack
	end,
})

minetest.register_entity("eventkeys:key_entity", {
	hp_max = 1,
	visual = "wielditem",
	visual_size = {x = 0.333, y = 0.333},
	textures = {"air"},
	collisionbox = {0,0,0,0,0,0},
	physical = false,
	_yaw = 0.0,
	on_step = function(self, dtime)
		self._yaw = self._yaw + 0.0125
		if self._yaw >= 2 then self._yaw = 0.0 end
		self.object:setyaw(self._yaw*math.pi)
	end,
	on_blast = function(self, damage)
		-- immortal doesn't stop TNT from destroying entity
		return false, false, {} -- do_damage, do_knockback, entity_drops
	end,
	on_activate = function(self, staticdata)
		self.object:set_armor_groups({immortal = 1})
		local meta = minetest.get_meta(self.object:get_pos())
		if meta ~= nil then
			local key = meta:get_string("key")
			self.object:set_properties({textures = {"eventkeys:item_"..key}})
		end
	end
})

local node_activation_radius = tonumber(minetest.settings:get("eventkeys_node_activation_radius") or 0.75)

minetest.register_node("eventkeys:key_node", {
	description = "Event Key Giver",
	tiles = {{name="eventkeys_U_anim.png", animation={type="vertical_frames", aspect_w=16, aspect_h=16, length=4}},
		"eventkeys_S.png","eventkeys_S.png","eventkeys_S.png","eventkeys_S.png","eventkeys_S.png"},
	sounds = default.node_sound_stone_defaults(),
	groups = {dig_immediate = 2},
	is_ground_content = false,
	light = 15,
	paramtype = "light", -- entities inside the node are black without this

	wield_image = "eventkeys_U.png",
	drawtype = "nodebox",
	walkable = true,
	sunlight_propagates = true,
	node_box = {
		type = "fixed",
		fixed = {-0.5, -0.5, -0.5, 0.5, -7/16, 0.5}
	},
	selection_box = {
		type = "fixed",
		fixed = {-0.5, -0.5, -0.5, 0.5, -7/16, 0.5}
	},

	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		if meta ~= nil then
			meta:set_string("key", "")
			meta:set_float("x", pos.x)
			meta:set_float("y", pos.y)
			meta:set_float("z", pos.z)
			meta:set_int("yaw", 0)
			set_key_infotext(nil, meta)
		end
	end,

	-- configure key name and teleport position/yaw
	on_rightclick = function(pos, node, clicker, itemstack)
		if minetest.is_protected(pos, clicker:get_player_name()) then return end

		local meta = minetest.get_meta(pos)
		if meta ~= nil then
			minetest.show_formspec(clicker:get_player_name(), "eventkeys:form_"..minetest.pos_to_string(pos),
				"size[8,5.5]"..default.gui_bg..default.gui_bg_img

				.."label[0.8,0.15;Key name]"
				.."field[2.5,0.5;4.5,0.5;key;;"..meta:get_string("key").."]"

				.."label[0.25,1.25;Enter coordinates of teleport destination (e.g 100,20.0,-300)]"
				.."field[1.75,2.25;5,0.5;coords;;"
						..string.format("%.2f", meta:get_float("x"))..", "
						..string.format("%.2f", meta:get_float("y"))..", "
						..string.format("%.2f", meta:get_float("z")).."]"

				.."label[1.3,2.75;Enter player's yaw after teleport (0 to 359)]"
				.."field[3.5,3.75;1.5,0.5;yaw;;"..meta:get_int("yaw").."]"

				.."button_exit[0.95,5;3,0.5;save;Save]"
				.."button_exit[4.05,5;3,0.5;cancel;Cancel]")
		end
	end,

	on_destruct = remove_key_entity,
	on_punch = function(pos, node, puncher)
		local meta = minetest.get_meta(pos)
		if meta == nil then return end

		local player_name = puncher:get_player_name()

		if minetest.is_protected(pos, player_name) then return end

		set_key_infotext(player_name, meta)
		remove_key_entity(pos)
		if get_key(player_name, meta:get_string("key")) then
			add_key_entity(pos)
		end
		minetest.get_node_timer(pos):start(key_node_timer)
	end,

	on_timer = function(pos)
		local meta = minetest.get_meta(pos)
		if meta == nil then return false end
		local key = meta:get_string("key")
		if key == "" then return false end
		local objs = minetest.get_objects_inside_radius(pos, node_activation_radius)
		if #objs == 0 then return true end

		for n = 1, #objs do
			if objs[n]:is_player() then
				local player = objs[n]

				-- add key to player's inventory
				local leftovers = player:get_inventory():add_item("main", "eventkeys:item_"..key.." 1")
				if not leftovers:is_empty() then
					minetest.chat_send_player(player:get_player_name(), "You need an empty inventory slot to receive the key")
					return true
				end
				minetest.log("action", "give event key "..key.." to "..player:get_player_name())

				-- sound and particles at source position
				minetest.sound_play("portal_close", {pos = pos, gain = 1.0, max_hear_distance = 5})
				spawn_teleport_particles(pos, 2.3 - 15/16, -1, 1.7)

				-- teleport player to destination
				local dst_pos = {x=meta:get_float("x"), y=meta:get_float("y"), z=meta:get_float("z")}
				player:setpos({x=dst_pos.x, y=dst_pos.y+0.25, z=dst_pos.z})
				player:set_look_pitch(0)
				player:set_look_yaw(meta:get_int("yaw")*0.0174533)

				-- sound and particles at destination position
				minetest.sound_play("portal_close", {pos = dst_pos, gain = 1.0, max_hear_distance = 5})
				spawn_teleport_particles(dst_pos, 0.5, 1, 1.7)
			end
		end
		return true
	end,
})

minetest.register_node("eventkeys:prize_node", {
	description = "Event Prize Giver",
	tiles = {"eventkeys_S.png"},
	sounds = default.node_sound_stone_defaults(),
	groups = {dig_immediate = 2},
	is_ground_content = false,
	light = 15,
	paramtype = "light", -- entities inside the node are black without this

	wield_image = "eventkeys_S.png",
	drawtype = "nodebox",
	walkable = true,
	sunlight_propagates = true,
	node_box = {
		type = "fixed",
		fixed = {-0.5, -0.5, -0.5, 0.5, -7/16, 0.5}
	},
	selection_box = {
		type = "fixed",
		fixed = {-0.5, -0.5, -0.5, 0.5, -7/16, 0.5}
	},

	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		if meta ~= nil then
			meta:set_string("event", "")
			set_prize_infotext(meta)
		end
	end,

	-- configure event name
	on_rightclick = function(pos, node, clicker, itemstack)
		if minetest.is_protected(pos, clicker:get_player_name()) then return end

		local meta = minetest.get_meta(pos)
		if meta ~= nil then
			minetest.show_formspec(clicker:get_player_name(), "eventkeys:form_"..minetest.pos_to_string(pos),
				"size[8,2]"..default.gui_bg..default.gui_bg_img

				.."label[1,0.15;Event]"
				.."field[2.5,0.5;4.5,0.5;event;;"..meta:get_string("event").."]"

				.."button_exit[0.95,1.5;3,0.5;save;Save]"
				.."button_exit[4.05,1.5;3,0.5;cancel;Cancel]")
		end
	end,

	on_punch = function(pos, node, puncher)
		local meta = minetest.get_meta(pos)
		if meta == nil then return end

		if minetest.is_protected(pos, puncher:get_player_name()) then return end

		set_prize_infotext(meta)
		minetest.get_node_timer(pos):start(prize_node_timer)
	end,

	on_timer = function(pos)
		local meta = minetest.get_meta(pos)
		if meta == nil then return false end
		local objs = minetest.get_objects_inside_radius(pos, node_activation_radius)
		if #objs == 0 then return true end

		for n = 1, #objs do
			if objs[n]:is_player() then
				local player = objs[n]

				give_prize(get_event(player:get_player_name(), meta:get_string("event")), player, player:get_player_name())
			end
		end
		return true
	end,
})

local cmd_params_giveprize = "<event> <player>"
minetest.register_chatcommand("eventkeys_giveprize", {
	params = cmd_params_giveprize,
	description = "Give <event> prize to <player> if player has all event keys",
	privs = {give=true},
	func = function(runner, parameters)
		local found, _, event, target = parameters:find("^([^%s]+) ([^%s]+)$")
		if found == nil then
			minetest.chat_send_player(runner, "Invalid usage: "..parameters)
			minetest.chat_send_player(runner, "    /eventkeys_giveprize "..cmd_params_giveprize)
			return
		end

		local player = minetest.get_player_by_name(target)
		if player then
			give_prize(get_event(runner, event), player, target)
		else
			minetest.chat_send_player(runner, "Invalid target: "..target)
		end
	end
})

local cmd_params_list = "[<event>]"
minetest.register_chatcommand("eventkeys_list", {
	params = cmd_params_list,
	description = "List all events, or if optional <event> is given, list all keys for event.",
	privs = {give=true},
	func = function(runner, parameters)
		if parameters == "" then
			-- list events
			local events = ""
			for _,e in pairs(eventkeys.events) do
				if events == "" then events = e.name else events = events..", "..e.name end
				if e.enabled ~= true then events = events.." (disabled)" end
			end
			minetest.chat_send_player(runner, "Events: "..events)
		else
			local found, _, name = parameters:find("^([^%s]+)$")
			if found == nil then
				minetest.chat_send_player(runner, "Invalid usage: "..parameters)
				minetest.chat_send_player(runner, "    /eventkeys_list "..cmd_params_list)
				return
			end

			-- list keys
			for _,e in pairs(eventkeys.events) do
				if e.name == name then
					if e.enabled ~= true then
						minetest.chat_send_player(runner, "Event: "..name.." (disabled)")
					else
						minetest.chat_send_player(runner, "Event: "..name)
					end
					for _,k in pairs(e.keys) do
						minetest.chat_send_player(runner, "    "..k[1].."  •  "..k[2])
					end
					return
				end
			end
			minetest.chat_send_player(runner, "Invalid event: "..name)
		end
	end
})



print("[MOD] EventKeys loaded")
