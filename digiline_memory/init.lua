-- Written by numberZero
-- Based on the original code by jogag
-- Part of the Digiline Stuff pack
-- Mod: digiline memory chip
-- A memory chip you can use to store several strings
-- Input format: {cmd=<string>, addr=<integer>, value=<anything>}
-- Output format: {ok=<bool>, value=<anything>}
-- Commands: get, set, clear
-- Addresses are zero-based integers

digiline_memory = {}

local CHIP_DESCRIPTION = "Digiline %d-bit Memory Chip (%d rows)"
local CHIP_INFOTEXT = "Memory Chip (%d-bit)"
local CHIP_FORMSPEC = "field[channel;Channel;${channel}]"
local ROW_SIZE_LIMIT = 4 * 1024
local MSG_INVALID_ADDRESS = "Invalid address"
local MSG_DATA_TOO_LONG = "Data too long"

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

local get_meta_field_name = function(addr, desc)
	if type(addr) ~= "number" then
		return false
	end
	local int, frac = math.modf(addr)
	if frac ~= 0 or int < 0 or int >= desc.size then
		return false
	end
	return true, "data_"..int
end

digiline_memory.on_digiline_receive = function(pos, node, channel, msg)
	if type(msg) ~= "table" or not msg.cmd then
		return
	end
	local meta = minetest.get_meta(pos)
	if channel ~= meta:get_string("channel") then
		return
	end
	local ok = false
	local addr
	local value
	local desc = minetest.registered_nodes[minetest.get_node(pos).name].digiline_memory
	if msg.cmd == "get" then
		ok, addr = get_meta_field_name(msg.addr, desc)
		if ok then
			value = minetest.deserialize(meta:get_string(addr))
		else
			value = MSG_INVALID_ADDRESS
		end
	elseif msg.cmd == "set" then
		ok, addr = get_meta_field_name(msg.addr, desc)
		if ok then
			if msg.value == nil then
				value = ""
			else
				value = minetest.serialize(msg.value)
			end
			if #value > ROW_SIZE_LIMIT then
				ok = false
				value = MSG_DATA_TOO_LONG
			else
				meta:set_string(addr, value)
				value = nil -- don't send it back
			end
		else
			value = MSG_INVALID_ADDRESS
		end
	elseif msg.cmd == "clear" then
		ok = true
		meta:from_table({
			inventory = {},
			fields = {
				formspec = CHIP_FORMSPEC,
				infotext = desc.label,
				channel = channel,
			}})
	end
	digiline:receptor_send(pos, digiline.rules.default, channel, {ok=ok, value=value})
end

for bus_width = 4,10 do
	local row_count = 2^bus_width
	local label = string.format(CHIP_INFOTEXT, bus_width)
	minetest.register_node("digiline_memory:memory_"..row_count, {
		description = string.format(CHIP_DESCRIPTION, bus_width, row_count),
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
			label = label,
			size = row_count,
		},
		on_construct = function(pos)
			local meta = minetest.get_meta(pos)
			meta:from_table({
				inventory = {},
				fields = {
					formspec = CHIP_FORMSPEC,
					infotext = label,
					channel = "",
				}})
		end,
		on_receive_fields = function(pos, formname, fields, sender)
			if fields.channel then minetest.get_meta(pos):set_string("channel", fields.channel) end
		end,
	})
end

for base_bus_width = 4,9 do
	local base_size = 2^base_bus_width
	local next_size = 2 * base_size
	minetest.register_craft({
		type = "shapeless",
		output = "digiline_memory:memory_"..next_size,
		recipe = {
			"digiline_memory:memory_"..base_size,
			"digiline_memory:memory_"..base_size,
		},
	})
end
