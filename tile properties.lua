----------------------------------------------------------------------

-- url: https://gist.github.com/navneetankur/d6769bd941ec80deacb089d04e5604c0/tile properties.lua
-- ghgid: d6769bd941ec80deacb089d04e5604c0
-- A customizable toolbar that can be useful in touch-like devices
-- (e.g. on a Microsoft Surface).
--
-- Feel free to add new commands and modify it as you want.
----------------------------------------------------------------------

local spr = app.activeSprite
local fs = app.fs
local pc = app.pixelColor
local output_folder = fs.fileTitle(spr.filename)
local tileset = spr.tilesets[1]

local tile_index = app.preferences.color_bar.fg_tile
if not tile_index or tile_index == 0 then return end
local tile = tileset:tile(tile_index)
-- to remove
			-- for i = 0,#tileset-1 do
			--   local ctile = tileset:tile(i)
			--   ctile.properties["asp_collision_by"] = ctile.properties["collision_by"]
			--   ctile.properties["collision_by"] = nil
			-- end
-- to remove

local function rotated_to_orig()
	local orig_index = app.pixelColor.tileI(tile_index)
	local message_box = Dialog("message"):label{text = "flipped/rotated version of ".. orig_index}
		:button{text = "ok"}
	message_box:button{
			id = "btn_select",
			text = "select ".. orig_index,
			onclick = function ()
				app.preferences.color_bar.fg_tile = orig_index
				tile_index = orig_index
				tile = tileset:tile(tile_index)
				message_box:close()
			end
	}
	:show()

	if not message_box.data["btn_select"] then
		return false
	end
	return true
end

if not tile then
	if not rotated_to_orig() then
		return
	end
end


local show_tile_properties_dialogue
local function change_dialog(dlg_old)
	local dtype = dlg_old.data["property_type"]
	if not dtype then dtype = "string" end
	dlg_old:close()
	local add_prop_dlg = Dialog("Add Property")
	add_prop_dlg:combobox {
		id = "property_type",
		label = "type",
		option = dtype,
		options = {"string", "bool"},
		onchange = function () change_dialog(add_prop_dlg) end,
	}
	add_prop_dlg:entry {
		id = "property_name",
		label = "name",
	}
	if dtype == "string" then
		add_prop_dlg:entry {
			id = "property_value",
			label = "value",
		}
	elseif dtype == "bool" then
		add_prop_dlg:check {
			id = "property_value",
		}
	end
	add_prop_dlg:button { id = "btn_ok", text = "ok",
		onclick = function ()
				local name = add_prop_dlg.data["property_name"]
				local pvalue = add_prop_dlg.data["property_value"]
				tile.properties[name] = pvalue
				add_prop_dlg:close()
				show_tile_properties_dialogue()
			end,
	}
	add_prop_dlg:show()
end
show_tile_properties_dialogue = function ()
	local dlg = Dialog("Tile: ".. tile.index)

	:button {
		text = "ok",
	}
	dlg:button {
		id = "btn_add",
		text = "+",
		onclick = function ()
			dlg:close()
			change_dialog(Dialog(""))
		end
	}
	:button {
		id = "btn_collision_by",
		text = "collision_by",
		onclick = function ()
			dlg:close()
			local cb = tile.properties["asp_collision_by"]
			if not cb then
				local message_box = Dialog("not found")
				message_box:label{text = "not found"}
				message_box:show()
				return
			end

			for i = 0,#tileset-1 do
			  local ctile = tileset:tile(i)
			  if ctile.properties["name"] == cb then
			  	tile = ctile
				tile_index = ctile.index
				app.preferences.color_bar.fg_tile = ctile.index
			  end
			end
		end
	}
	for key,value in pairs(tile.properties) do
		dlg:label{ id = key, label = key, text = tostring(value) }
		:button { id = "btn_remove", text = "-", onclick = function ()
				tile.properties[key] = nil
				dlg:close()
				show_tile_properties_dialogue()
			end }
	end
	dlg:show()
end
show_tile_properties_dialogue()





-- dlg
--   :button{text="Undo",onclick=function() app.command.Undo() end}
--   :button{text="Redo",onclick=function() app.command.Redo() end}
--   :button{text="|<",onclick=function() app.command.GotoFirstFrame() end}
--   :button{text="<",onclick=function() app.command.GotoPreviousFrame() end}
--   :button{text=">",onclick=function() app.command.GotoNextFrame() end}
--   :button{text=">|",onclick=function() app.command.GotoLastFrame() end}
--   :button{text="+",onclick=function() app.command.NewFrame() end}
--   :button{text="-",onclick=function() app.command.RemoveFrame() end}
--   :show{wait=false}
