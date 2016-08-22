
-- Created by cpdef/juli
-- Part of digiline_enhanced
-- Mod: digiline copier

local OK_MSG = "OK"
local NO_SPACE_MSG   = "NOSPACE"
local NO_PAPER_MSG   = "NOPAPER"
local BUSY_MSG       = "BUSY"
local PRINT_DELAY    = 3
local SPLIT_CHAR     = "$"
local DEFAULT_SIGNUM = "THE COPIER"

local nodebox =
{
	type = "fixed",
	fixed = {
		{ -0.4, -0.5, -0.4, 0.4, 0.5, 0.4}, -- bottom slab
                -- x     y     z    x    y     z
		{ -0.5, -0.5, -0.5, 0.5, 0.4, 0.5},
	}
}

-- taken from pipeworks mod
local function facedir_to_dir(facedir)
	--a table of possible dirs
	return ({{x=0, y=0, z=1},
		{x=1, y=0, z=0},
		{x=0, y=0, z=-1},
		{x=-1, y=0, z=0},
		{x=0, y=-1, z=0},
		{x=0, y=1, z=0}})
		
			--indexed into by a table of correlating facedirs
			[({[0]=1, 2, 3, 4, 
				5, 2, 6, 4,
				6, 2, 5, 4,
				1, 5, 3, 6,
				1, 6, 3, 5,
				1, 4, 3, 2})
				
				--indexed into by the facedir in question
				[facedir]]
end

local print_paper = function(inv, pos, node, msg, signum)
        --get front pos
	local vel = facedir_to_dir(node.param2)
	local front = { x = pos.x - vel.x, y = pos.y - vel.y, z = pos.z - vel.z }
	
	if inv:is_empty("paper") then digiline:receptor_send(pos, digiline.rules.default, channel, NO_PAPER_MSG)
	elseif minetest.get_node(front).name ~= "air" then digiline:receptor_send(pos, digiline.rules.default, channel, NO_SPACE_MSG)
	else
                --remove one item from paper stack:
		local paper = inv:get_stack("paper", 1)
		paper:take_item()
		inv:set_stack("paper", 1, paper)
		
                --print the letter
		minetest.add_node(front, {
			name = (msg == "" and "memorandum:letter_empty" or "memorandum:letter_written"),
			param2 = node.param2
		})
		
                --set text of letter
		local meta = minetest.get_meta(front)
		meta:set_string("text", msg)
		meta:set_string("signed", signum)
		meta:set_string("infotext", 
                "On this piece of paper is written: " ..msg .. " Signed by " .. signum)
		
                --done :-)
		digiline:receptor_send(pos, digiline.rules.default, channel, OK_MSG)
	end
	minetest.get_meta(pos):set_string("infotext", "Copier Idle")
end

local copy = function(inv, pos, copier, node, scanpos)
         local vel = facedir_to_dir(copier.param2)
	 local front = { x = pos.x - vel.x, y = pos.y - vel.y, z = pos.z - vel.z }

         if inv:is_empty("paper") then digiline:receptor_send(pos, digiline.rules.default, channel, NO_PAPER_MSG)
         elseif minetest.get_node(front).name ~= "air" then digiline:receptor_send(pos, digiline.rules.default, channel, NO_SPACE_MSG)
         else
             local paper = inv:get_stack("paper", 1)
             paper:take_item(1)
             inv:set_stack("paper", 1, paper)

             minetest.add_node(front, node)
             local meta     = minetest.get_meta(front  )
             local scanmeta = minetest.get_meta(scanpos)
             meta:set_string("text",     scanmeta:get_string("text"    ))
             meta:set_string("signed",   scanmeta:get_string("signed"  ))
             meta:set_string("infotext", scanmeta:get_string("infotext"))

             digiline:receptor_send(pos, digiline.rules.default, channel, OK_MSG)
         end
         minetest.get_meta(pos):set_string("infotext", "Copier Idle")
end        

local on_digiline_receive = function(pos, node, channel, msg)
        if msg == "" then return end
	local meta = minetest.get_meta(pos)
        local msg = msg:split(SPLIT_CHAR)
	if channel == meta:get_string("channel") then
                --DIGILINE COMMANDS
                --usable for more than one function
                local scanpos = {x = pos.x, y = pos.y+1, z = pos.z}
                local scanmeta = minetest.get_meta(scanpos)
                local inv = minetest.get_meta(pos):get_inventory()
                --SCAN:
                if msg[1] == "SCAN" then
                    if minetest.get_node_or_nil(scanpos).name == "memorandum:letter_written" then
                        local text = scanmeta:to_table().fields.text
                        text = text .. " signed: " .. scanmeta:get_string("signed")
                        digiline:receptor_send(pos, digiline.rules.default, channel, text) 
                    end

                --PRINT:
                elseif msg[1] == "PRINT" then
                    if (  meta:get_string("infotext"):find("Busy") == nil  ) then
                        meta:set_string("infotext", "Digiline Printer Busy")
                        if (msg[2]) then
                            if (msg[3]) then
                                minetest.after(PRINT_DELAY, print_paper, inv, pos, node, msg[2], msg[3])
                            else
                                minetest.after(PRINT_DELAY, print_paper, inv, pos, node, msg[2], DEFAULT_SIGNUM)
                            end
                        end
	            else
                        digiline:receptor_send(pos, digiline.rules.default, channel, BUSY_MSG)
                    end

                elseif msg[1] == "COPY" then
                    if (  meta:get_string("infotext"):find("Busy") == nil  ) then
                        meta:set_string("infotext", "Digiline Printer Busy")
                        local scannode = minetest.get_node_or_nil(scanpos)
                        if (scannode and scannode.name == "memorandum:letter_written") then
                            minetest.after(PRINT_DELAY, copy,         
                                          inv, pos, node ,scannode, scanpos)
                        end
	            else
                        digiline:receptor_send(pos, digiline.rules.default, channel, BUSY_MSG)
                    end
                 
                --get paper laying on copier
                elseif msg[1] == "GETPAPER" then
                    if (minetest.get_node_or_nil(scanpos).name == "default:paper"
                      or minetest.get_node_or_nil(scanpos).name == "memorandum:letter_empty") 
                      then
                        local paper = inv:get_stack("paper", 1)
                        paper:add_item("default:paper")
		        inv:set_stack("paper", 1, paper)
                        minetest.remove_node(scanpos)
                    end

                elseif msg[1] == "IDLE" then
                       minetest.get_meta(pos):set_string("infotext", "Copier Idle")
                end

                --COMMAND END
	end
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
        if string.sub(formname, 0, string.len("digiline_copier:")) == "digiline_copier:" then

		local pos_s = string.sub(formname, string.len("digiline_copier:") + 1)
		local pos = minetest.string_to_pos(pos_s)
		local meta = minetest.get_meta(pos)
                meta:set_string("channel", fields.channel)

	end

end)


minetest.register_node("digiline_copier:copier", {
		description = "copy, scan and print device",
		drawtype = "nodebox",
	        tiles = {"copier.png","copier_sides.png","copier_sides.png",
			"copier_sides.png","copier_sides.png","copier_front.png"},

		paramtype = "light",
		paramtype2 = "facedir",
		groups = {dig_immediate=2},
		--selection_box = chip_selbox,
                drawtype = "nodebox",
		node_box = nodebox,
		digiline = {
			receptor = {},
			effector = { action = on_digiline_receive },
		},

		on_construct = function(pos)
			local meta = minetest.get_meta(pos)
			meta:set_string("channel", "DEFAULT")
			meta:set_string("data", "return {}")
                        local inv = meta:get_inventory()
		        inv:set_size("paper", 1)
		end,

                on_rightclick = nil, 

                --TODO: formspec ...
                on_punch = function(pos, node, player, pointed_thing)
                        local meta = minetest.get_meta(pos)
                        local channel = meta:get_string("channel")
                        local posstring = "nodemeta:"..pos.x..","..pos.y..","..pos.z
                        local formname = "digilines_copier:"..minetest.pos_to_string(pos)
                        local formspec = "size[8,10]" .. 
                                "field[1,2;6,1;channel;Channel;".. channel .."]" ..      --set channel
                                "list["..posstring..";paper; 3.5,4;1,1;]" ..   --paper stack
                                "label[1,4;Paper]"..
                                "list[current_player;main;0,6;8,4;]"
                        minetest.show_formspec(player:get_player_name(), formname, formspec)
                end,
                
                --SET CHANNEL
		on_receive_fields = function(pos, formname, fields, sender)
			if fields.channel then minetest.get_meta(pos):set_string("channel", fields.channel) end
                end,

                --allowed to put in something?
                allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		        if minetest.is_protected(pos, player:get_player_name()) then return 0 end
		        return (stack:get_name() == "default:paper" and stack:get_count() or 0)
	        end,
                
                --allowed to take out something?
	        allow_metadata_inventory_take = function(pos, listname, index, stack, player)
                        if minetest.is_protected(pos, player:get_player_name()) 
                            then return 0 end
                        if (minetest.get_meta(pos):get_string("infotext"):find("Busy") == nil) then
                            return stack:get_count()
                        else return 0
                        end
	        end,
                
                --allowed to dig?
                can_dig = function(pos, player)
		        return minetest.get_meta(pos):get_inventory():is_empty("paper")
	        end,
	})
	
	minetest.register_craft({
			type = "shapeless",
			output = "digilines_copier:copier",
			recipe = {
				"default:dirt",
				"default:dirt",
			},
		})
