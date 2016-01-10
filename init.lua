
--[[

Copyright (C) 2015 - Auke Kok <sofar@foo-projects.org>

--]]

newdoor = {}
newdoor.open = function(pos, player)
	local state = minetest.get_meta(pos):get_int("state")
	if state % 2 == 1 then
		return false
	end
	return newdoor.toggle(pos, player)
end
newdoor.close = function(pos, player)
	local state = minetest.get_meta(pos):get_int("state")
	if state % 2 == 0 then
		return false
	end
	return newdoor.toggle(pos, player)
end
newdoor.toggle = function(pos, player)
	return toggle(pos, player)
end

-- this hidden node is placed on top of the bottom, and prevents
-- nodes from being placed in the top half of the door.
minetest.register_node("newdoor:hidden", {
	description = "You hacker! You...",
	drawtype = "airlike",
	buildable_to = false,
	selection_box = {},
	collision_box = {},
	pointable = false,
	walkable = false,
	groups = { not_in_creative_inventory = 1 },
})

local toggle = function(pos, clicker)
	local meta = minetest.get_meta(pos)
	local state = meta:get_int("state")
	local def = minetest.registered_nodes[minetest.get_node(pos).name]
	local name = def.door.basename

	local owner = meta:get_string("doors_owner")
	if owner ~= "" then
		if clicker:get_player_name() ~= owner then
			return false
		end
	end

	local old = state
	-- until Lua-5.2 we have no bitwise operators :(
	if state % 2 == 1 then
		state = state - 1
	else
		state = state + 1
	end

	local dir = minetest.get_node(pos).param2
	local transform = {
		{
			{ v = "_a", param2 = 3 },
			{ v = "_a", param2 = 0 },
			{ v = "_a", param2 = 1 },
			{ v = "_a", param2 = 2 },
		},
		{
			{ v = "_b", param2 = 1 },
			{ v = "_b", param2 = 2 },
			{ v = "_b", param2 = 3 },
			{ v = "_b", param2 = 0 },
		},
		{
			{ v = "_b", param2 = 1 },
			{ v = "_b", param2 = 2 },
			{ v = "_b", param2 = 3 },
			{ v = "_b", param2 = 0 },
		},
		{
			{ v = "_a", param2 = 3 },
			{ v = "_a", param2 = 0 },
			{ v = "_a", param2 = 1 },
			{ v = "_a", param2 = 2 },
		},
	}

	if state % 2 == 0 then
		minetest.sound_play(def.door.sounds[1], {pos = pos, gain = 0.3, max_hear_distance = 10})
	else
		minetest.sound_play(def.door.sounds[2], {pos = pos, gain = 0.3, max_hear_distance = 10})
	end

	minetest.swap_node(pos, {
		name = "newdoor:" .. name .. transform[state + 1][dir+1].v,
		param2 = transform[state + 1][dir+1].param2
	})
	meta:set_int("state", state)

	return true
end

newdoor.register = function(name, def)
	minetest.register_craftitem("newdoor:" .. name, {
		description = def.description,
		inventory_image = def.inventory_image,

		on_place = function(itemstack, placer, pointed_thing)
			local pos = pointed_thing.above
			local node = minetest.get_node(pos)

			if not minetest.registered_nodes[node.name].buildable_to then
				return itemstack
			end

			local above = { x = pos.x, y = pos.y + 1, z = pos.z }
			if not minetest.registered_nodes[minetest.get_node(above).name].buildable_to then
				return itemstack
			end

			local dir = minetest.dir_to_facedir(placer:get_look_dir())

			local ref = {
				{ x = -1, y = 0, z = 0 },
				{ x = 0, y = 0, z = 1 },
				{ x = 1, y = 0, z = 0 },
				{ x = 0, y = 0, z = -1 },
			}

			local aside = {
				x = pos.x + ref[dir + 1].x,
				y = pos.y + ref[dir + 1].y,
				z = pos.z + ref[dir + 1].z,
			}

			local state = 0
			if minetest.get_item_group(minetest.get_node(aside).name, "door") == 1 then
				state = state + 2
				minetest.set_node(pos, {name = "newdoor:" .. name .. "_b", param2 = dir})
			else
				minetest.set_node(pos, {name = "newdoor:" .. name .. "_a", param2 = dir})
			end
			minetest.set_node(above, { name = "newdoor:hidden" })

			local meta = minetest.get_meta(pos)
			meta:set_int("state", state)

			if def.protected then
				meta:set_string("doors_owner", placer:get_player_name())
				meta:set_string("infotext", "Owned by " .. placer:get_player_name())
			end

			if not minetest.setting_getbool("creative_mode") then
				itemstack:take_item()
			end

			return itemstack
		end
	})

	local can_dig = function(pos, digger)
		if not def.protected then
			return true
		end
		local meta = minetest.get_meta(pos)
		return meta:get_string("doors_owner") == digger:get_player_name()
	end

	def.groups.not_in_creative_inventory = 1
	def.groups.door = 1
	def.drop = "newdoor:" .. name
	def.door = {
		basename = name,
		sounds = { def.sound_close, def.sound_open },
	}

	def.on_rightclick = function(pos, node, clicker)
		toggle(pos, clicker)
	end
	def.after_dig_node = function(pos, node, meta, digger)
		minetest.remove_node({ x = pos.x, y = pos.y + 1, z = pos.z})
	end
	def.can_dig = function(pos, player)
		return can_dig(pos, player)
	end
	def.on_rotate = function(pos, node, user, mode, new_param2)
		return false
	end

	minetest.register_node("newdoor:" .. name .. "_a", {
		description = def.description,
		visual = "mesh",
		mesh = "door_a.obj",
		tiles = def.tiles,
		drawtype = "mesh",
		paramtype = "light",
		paramtype2 = "facedir",
		sunlight_propagates = true,
		use_texture_alpha = true,
		walkable = true,
		is_ground_content = false,
		buildable_to = false,
		paramtype = "light",
		drop = def.drop,
		groups = def.groups,
		sounds = def.sounds,
		door = def.door,
		on_rightclick = def.on_rightclick,
		after_dig_node = def.after_dig_node,
		can_dig = def.can_dig,
		on_rotate = def.on_rotate,
		selection_box = {
			type = "fixed",
			fixed = { -1/2,-1/2,-1/2,1/2,3/2,-6/16}
		},
		collision_box = {
			type = "fixed",
			fixed = { -1/2,-1/2,-1/2,1/2,3/2,-6/16}
		},
	})

	minetest.register_node("newdoor:" .. name .. "_b", {
		description = def.description,
		visual = "mesh",
		mesh = "door_b.obj",
		tiles = def.tiles,
		drawtype = "mesh",
		paramtype = "light",
		paramtype2 = "facedir",
		sunlight_propagates = true,
		use_texture_alpha = true,
		walkable = true,
		paramtype = "light",
		groups = def.groups,
		sounds = def.sounds,
		door = def.door,
		on_rightclick = def.on_rightclick,
		after_dig_node = def.after_dig_node,
		can_dig = def.can_dig,
		drop = def.drop,
		on_rotate = def.on_rotate,
		selection_box = {
			type = "fixed",
			fixed = { -1/2,-1/2,-1/2,1/2,3/2,-6/16}
		},
		collision_box = {
			type = "fixed",
			fixed = { -1/2,-1/2,-1/2,1/2,3/2,-6/16}
		},
	})

	minetest.register_craft({
		output = "newdoor:" .. name,
		recipe = {
			{def.material,def.material};
			{def.material,def.material};
			{def.material,def.material};
		}
	})
end

newdoor.register("door", {
		tiles = { "newdoor_wood.png" },
		description = "Wooden Door",
		inventory_image = "newdoor_item_wood.png",
		groups = { snappy = 1, choppy = 2, oddly_breakable_by_hand = 2, flammable = 2 },
		sounds = default.node_sound_wood_defaults(),
		sound_open = "doors_door_open",
		sound_close = "doors_door_close",
		material = "group:wood",
})

newdoor.register("door_steel", {
		tiles = { "newdoor_steel.png" },
		description = "Steel Door",
		inventory_image = "newdoor_item_steel.png",
		protected = true,
		groups = { snappy = 1, bendy = 2, cracky = 1, melty = 2, level = 2 },
		sounds = default.node_sound_wood_defaults(),
		sound_open = "doors_door_open",
		sound_close = "doors_door_close",
		material = "default:steel_ingot",
})
