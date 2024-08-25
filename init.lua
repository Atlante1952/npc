--[[
Copyright (C) 2023
Atlante/Zoldrexs
atlanteetdocteur@gmail.com

                      GNU GENERAL PUBLIC LICENSE
                       Version 3, 29 June 2007

 Copyright (C) 2007 Free Software Foundation, Inc. <https://fsf.org/>
 Everyone is permitted to copy and distribute verbatim copies
 of this license document, but changing it is not allowed.

                            Preamble

  The GNU General Public License is a free, copyleft license for
software and other kinds of works.
]]

minetest.register_entity("npc:npc", {
    initial_properties = {
        physical = true,
        collide_with_objects = true,
        visual = "mesh",
        visual_size = {x = 1, y = 1},
        collisionbox = {-0.35,0.0,-0.35, 0.35,1.8,0.35},
        mesh = "character.b3d",
        textures = {"character.png"},
    },

    on_step = function(self, dtime)
        local pos = self.object:get_pos()
        local players = minetest.get_connected_players()
        for _, player in ipairs(players) do
            local player_pos = player:get_pos()
            local distance = vector.distance(pos, player_pos)
            if distance <= 7 then
                local look_dir = vector.direction(pos, player_pos)
                self.object:set_yaw(math.atan2(-look_dir.x, look_dir.z))
                break
            end
        end
    end,

    play_animation = function(self, anim)
        self.object:set_animation({x = anim, y = anim + 80}, 30, 0)
    end,

    get_staticdata = function(self)
        return minetest.serialize({
            nametag = self.npc_name,
            skin = self.skin,
        })
    end,

    on_activate = function(self, staticdata, dtime_s)
        if staticdata then
            local data = minetest.deserialize(staticdata)
                self.object:set_armor_groups({immortal = 1})
            if data and data.skin then
                self.skin = data.skin
                self:set_texture(self.skin)
            end
            if data and data.nametag then
                self.npc_name = data.nametag
            end
        end

        self:play_animation(0)
    end,

    set_texture = function(self, texture)
        if texture and texture ~= "" then
            local properties = self.object:get_properties()
            properties.textures = {texture}
            self.object:set_properties(properties)
        end
    end,

    on_rightclick = function(self, clicker)
        local staticdata = self:get_staticdata()
        local data = minetest.deserialize(staticdata)
        if data and data.nametag and data.skin then
            local npc_name = data.nametag
            local skin = data.skin
            local npc_path = minetest.get_worldpath() .. "/npc/npc_" .. npc_name .. ".txt"
            local file = io.open(npc_path, "r")
            local file_content = ""
            if file then
                file_content = file:read("*all")
                io.close(file)
            end

            local button_give = ""
            local button_tp = ""
            local give_items = {}

            for item, quantity in file_content:gmatch("%[btn_give%s+(%S+)%s+(%d+)%]") do
                table.insert(give_items, {item = item, quantity = tonumber(quantity)})
            end

            if #give_items > 0 then
                button_give = "button[0,5.5;2,1;btn_give;" .. minetest.formspec_escape("Give") .. "]"
            end

            local tp_x, tp_y, tp_z = file_content:match("%[btn_tp%s+([%d.-]+)%s+([%d.-]+)%s+([%d.-]+)%]")
            if tp_x and tp_y and tp_z then
                button_tp = "button[2,5.5;2,1;btn_tp;" .. minetest.formspec_escape("Teleport") .. "]"
            end

            file_content = file_content:gsub("%[btn_give%s+(%S+)%s+(%d+)%]", ""):gsub("%[btn_tp%s+([%d.-]+)%s+([%d.-]+)%s+([%d.-]+)%]", "")

            minetest.show_formspec(clicker:get_player_name(), "npc_info:" .. npc_name,
                "size[8,6]" ..
                "hypertext[3,1;5.5,5;;<style size=16>" .. minetest.formspec_escape(file_content) .. "</style>]" ..
                "box[0,0.5;7.75,5;#000000]" ..
                "model[0.25,0.25;2.6,6.2;character.b3d;character.b3d;" .. skin .. ";{0,210};;]" ..
                "tabheader[0,0;npc_tabs;   Dialogue   ;1]" ..
                button_give ..
                button_tp ..
                "label[0.25,-0.07;" .. minetest.colorize("orange","Discussion with the named npc: " .. npc_name .. "]") ..
                "button_exit[6,5.5;2,1;close;Close]"
            )

            if #give_items > 0 then
                minetest.register_on_player_receive_fields(function(player, formname, fields)
                    if formname == "npc_info:" .. npc_name and fields.btn_give then
                        for _, item_data in ipairs(give_items) do
                            local item_name = item_data.item
                            local quantity = item_data.quantity
                            local item_stack = ItemStack(item_name .. " " .. tostring(quantity))
                            local leftover = player:get_inventory():add_item("main", item_stack)
                            if not leftover:is_empty() then
                                minetest.add_item(player:get_pos(), leftover)
                            end
                        end
                        minetest.chat_send_player(player:get_player_name(), "[Server] -!- You have received items.")
                        minetest.log("action", "[npc_info:" .. npc_name .. "] " .. player:get_player_name() .. " received items from the npc " .. npc_name)
                    elseif formname == "npc_info:" .. npc_name and fields.btn_tp then
                        local x = tonumber(tp_x)
                        local y = tonumber(tp_y)
                        local z = tonumber(tp_z)
                        if x and y and z then
                            player:set_pos({x = x, y = y, z = z})
                            minetest.chat_send_player(player:get_player_name(), minetest.colorize("#74f016", "[Server] -!- You have been teleported."))
                            minetest.log("action", "[npc_info:" .. npc_name .. "] " .. player:get_player_name() .. " was teleported by " .. npc_name)
                        else
                            minetest.chat_send_player(player:get_player_name(), minetest.colorize("#74f016", "[Server] -!- Invalid teleport coordinates."))
                        end
                    end
                end)
            end
        end
    end,
})

local function create_npc(name, skin, pos)
    local npc_path = minetest.get_worldpath() .. "/npc/"
    if not minetest.mkdir(npc_path) then
        return false, minetest.colorize("#74f016", "[Server] -!- Unable to create folder for npc.")
    end

    local filename = npc_path .. "npc_" .. name .. ".txt"
    local file = io.open(filename, "r")
    if file then
        io.close(file)
        return false, minetest.colorize("#74f016", "[Server] -!- An npc with this name already exists.")
    end

    file = io.open(filename, "w")
    if not file then
        return false, minetest.colorize("#74f016", "[Server] -!- Failed to create file for npc.")
    end
    file:write("")
    io.close(file)

    local npc_entity = minetest.add_entity(pos, "npc:npc", name)
    if npc_entity then
        local npc = npc_entity:get_luaentity()
        npc.skin = skin
        npc.npc_name = name
        npc:set_texture(skin)
        return true, minetest.colorize("#74f016", "[Server] -!- npc '" .. name .. "' created successfully")
    else
        return false, minetest.colorize("#74f016", "[Server] -!- Error creating the npc.")
    end
end

minetest.register_chatcommand("cr_npc", {
    params = "<npc_skin.png> <npc_name>",
    privs = {ban = true},
    description = "Creates an npc with the specified name and specified skin.",
    func = function(name, param)
        local skin, npc_name = param:match("(%S+)%s+(%S+)")
        if skin and npc_name then
            local player = minetest.get_player_by_name(name)
            if player then
                local pos = player:get_pos()
                local success, message = create_npc(npc_name, skin, pos)
                minetest.chat_send_player(name, message)
            else
                minetest.chat_send_player(name, minetest.colorize("#74f016", "[Server] -!- Unable to find your location."))
            end
        else
            minetest.chat_send_player(name, minetest.colorize("#74f016", "[Server] -!- Incorrect use of the command. Usage: /cr_npc <npc_skin.png> <npc_name>"))
        end
    end,
})

minetest.register_chatcommand("ed_npc", {
    params = "<npc_name>",
    privs = {ban = true},
    description = "Opens the npc editor for the specified npc.",
    func = function(name, param)
        local npc_name = param:match("%S+")
        if npc_name then
            local player = minetest.get_player_by_name(name)
            if player then
                local npc_path = minetest.get_worldpath() .. "/npc/npc_" .. npc_name .. ".txt"
                local file = io.open(npc_path, "r")
                local file_content = ""
                if file then
                    file_content = file:read("*all")
                    io.close(file)
                end

                minetest.show_formspec(name, "npc_edit:" .. npc_name,
                    "size[8,6]" ..
                    "textarea[0.5,0.5;7.5,4.5;edit_content;;" .. minetest.formspec_escape(file_content) .. "]" ..
                    "button_exit[6,5.5;2,1;close;Close]" ..
                    "tabheader[0,0;npc_tabs;   Edit   ;1]" ..
                    "button[4,5.5;2,1;save;Save]" ..
                    "label[0.25,-0.07;" .. minetest.colorize("orange","Editing text of the named npc: " .. npc_name .. "]")
                )
            else
                minetest.chat_send_player(name, minetest.colorize("#74f016", "[Server] -!- Unable to find your location."))
            end
        else
            minetest.chat_send_player(name, minetest.colorize("#74f016", "[Server] -!- Incorrect use of the command. Usage: /edit_npc <npc_name>"))
        end
    end,
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname:find("^npc_edit:") and fields.save then
        local npc_name = formname:sub(10)
        local edit_content = fields.edit_content or ""
        local npc_path = minetest.get_worldpath() .. "/npc/npc_" .. npc_name .. ".txt"
        local file = io.open(npc_path, "w")
        if file then
            file:write(edit_content)
            io.close(file)
            minetest.chat_send_player(player:get_player_name(), minetest.colorize("#74f016", "[Server] -!- NPC file saved successfully."))
        else
            minetest.chat_send_player(player:get_player_name(), minetest.colorize("#74f016", "[Server] -!- Error saving NPC file."))
        end
    end
end)

minetest.register_chatcommand("dl_npc", {
    params = "<npc_name>",
    privs = {ban = true},
    description = "Deletes the npc entity with the specified name.",
    func = function(name, param)
        local npc_name = param:match("%S+")
        if npc_name then
            local entities = minetest.get_objects_inside_radius({x = 0, y = 0, z = 0}, 10000)
            local deleted = false
            for _, obj in ipairs(entities) do
                if obj:get_luaentity() and obj:get_luaentity().npc_name == npc_name then
                    obj:remove()
                    deleted = true
                    break
                end
            end
            if deleted then
                minetest.chat_send_player(name, minetest.colorize("#74f016", "[Server] -!- NPC '" .. npc_name .. "' deleted successfully."))
            else
                minetest.chat_send_player(name, minetest.colorize("#ff0000", "[Server] -!- NPC '" .. npc_name .. "' not found."))
            end
        else
            minetest.chat_send_player(name, minetest.colorize("#74f016", "[Server] -!- Incorrect use of the command. Usage: /dl_npc <npc_name>"))
        end
    end,
})
