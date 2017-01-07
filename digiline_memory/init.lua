-- Created by jogag
-- Rewritten by numberZero
-- Part of the Digiline Stuff pack
-- Mod: digiline memory chip
-- A memory chip you can use to store several strings
-- Input format: {cmd=<string>, addr=<integer>, value=<anything>}
-- Output format: {ok=<bool>, value=<anything>}
-- Commands: get, set, clear
-- Addresses are zero-based integers

digiline_memory = {}

-- list with the various chip sizes
-- (put two equal chips in crafting grid to upgrade)
local MEMORY_CHIPS = { 16, 32, 64, 128, 256, 512, 1024 }
local EMPTY_MEMORY = "return {}"

-- all taken from digiline RTC mod
local chip_nodebox =
{
	type = "fixed",
	fixed = {
		{ -8/16, -8/16, -8/16, 8/16, -7/16, 8/16 }, -- bottom slab
		{ -7/16, -7/16, -7/16, 7/16, -5/16,  7/16 },
	}
}

local chip_selbox =
{
	type = "fixed",
	fixed = {{ -8/16, -8/16, -8/16, 8/16, -3/16, 8/16 }}
}

local validate_addr = function(addr, desc)
	if type(addr) ~= "number" then
		return false
	end
	local int, frac = math.modf(addr)
	if frac ~= 0 or int < 0 or int >= desc.size then
		return false
	end
	return true, int
end

digiline_memory.on_digiline_receive = function(pos, node, channel, msg)
	if type(msg) ~= "table" or not msg.cmd then
		return
	end
	local meta = minetest.get_meta(pos)
	if channel ~= meta:get_string("channel") then
		return
	end
	local data = minetest.deserialize(meta:get_string("data"))
	local ok = false
	local addr, value
	local desc = minetest.registered_nodes[minetest.get_node(pos).name].digiline_memory
	if msg.cmd == "get" then
		ok, addr = validate_addr(msg.addr, desc)
		if ok then
			value = data[addr]
		end
	elseif msg.cmd == "set" then
		ok, addr = validate_addr(msg.addr, desc)
		if ok then
			data[addr] = msg.value
			meta:set_string("data", minetest.serialize(data))
		end
	elseif msg.cmd == "clear" then
		ok = true
		meta:set_string("data", EMPTY_MEMORY)
	end
	digiline:receptor_send(pos, digiline.rules.default, channel, {ok=ok, value=value})
end

for i, s in ipairs(MEMORY_CHIPS) do
	minetest.register_node("digiline_memory:memory_"..s, {
		description = "Digiline Memory Chip ("..s.." addresses)",
		drawtype = "nodebox",
		tiles = {"digiline_memory.png"},

		paramtype = "light",
		paramtype2 = "facedir",
		groups = {dig_immediate=2},
		selection_box = chip_selbox,
		node_box = chip_nodebox,
		digiline = {
			receptor = {},
			effector = { action = digiline_memory.on_digiline_receive },
		},
		digiline_memory = {
			size = s,
		},
		on_construct = function(pos)
			local meta = minetest.get_meta(pos)
			meta:set_string("formspec", "field[channel;Channel;${channel}]")
			meta:set_string("infotext", "Memory Chip ("..s.." addresses)")
			meta:set_string("channel", "")
			meta:set_string("data", EMPTY_MEMORY)
		end,
		on_receive_fields = function(pos, formname, fields, sender)
			if fields.channel then minetest.get_meta(pos):set_string("channel", fields.channel) end
		end,
	})

	if i ~= 1 then
		minetest.register_craft({
			type = "shapeless",
			output = "digiline_memory:memory_"..s,
			recipe = {
				"digiline_memory:memory_"..(s / 2),
				"digiline_memory:memory_"..(s / 2),
			},
		})
	end
end
