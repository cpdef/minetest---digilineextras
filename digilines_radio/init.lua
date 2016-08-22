local filename=minetest.get_worldpath() .. "/satellites"


local rec_db = nil

local function save_rec_db()
	local file, err = io.open(filename, "w")
	if file then
		file:write(minetest.serialize(rec_db))
		io.close(file)
	else
		error(err)
	end
end

local function read_rec_db()
	local file = io.open(filename, "r")
	if file ~= nil then
		local file_content = file:read("*all")
		io.close(file)

		if file_content and file_content ~= "" then
			rec_db = minetest.deserialize(file_content)
			return rec_db -- we read sucessfully
		end
	end
	rec_db = {}
	return rec_db
end

local function hash(pos)
	return string.format("%d", minetest.hash_node_position(pos))
end

local function save_as_receiver(pos)
        local rec_db = rec_db or read_rec_db()
        rec_db[hash(pos)] = minetest.pos_to_string(pos)
        save_rec_db()
end

local function remove_receiver(pos)
	local rec_db = sat_db or read_rec_db()
        rec_db[hash(pos)] = nil
        save_rec_db()
end

local function send_to_every_receiver(msg, channel, sendpos)
    local rec_db = rec_db or read_rec_db()
    for i, v in pairs(rec_db) do
        if (v ~= minetest.pos_to_string(sendpos)) then
            local pos = minetest.string_to_pos(v)
            local node = minetest.get_node_or_nil(pos)
            --print("DEBUG NODE", node.name, v)
            if (node.name == "digilines_radio:radio_tra_rec") then
                digiline:receptor_send(pos, digiline.rules.default, channel, msg)
            else
                remove_receiver(pos)
            end
        end
    end
    --print("DEBUG", "done")
end


-----------------------------------------------------------------------------------------------------------
--DEFAULT NODES
-----------------------------------------------------------------------------------------------------------

local on_digiline_receive = function(pos, node, channel, msg)
    --print("DEBUG", "send to all", channel, minetest.pos_to_string(pos))
    send_to_every_receiver(msg, channel, pos)
end

minetest.register_node("digilines_radio:radio_tra_rec",{
		description = "digiline radio transmitter/receiver",
		drawtype = "normal",
		tiles = {"digilines_satellitestatio.png"},

		paramtype = "light",
		paramtype2 = "facedir",
		groups = {dig_immediate=2},
		digiline = {
			receptor = {},
			effector = { action = on_digiline_receive },
		},
		on_construct = function(pos)
			save_as_receiver(pos)
		end,
	})
        
 

