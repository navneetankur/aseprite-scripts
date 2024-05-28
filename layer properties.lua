----------------------------------------------------------------------
-- A customizable toolbar that can be useful in touch-like devices
-- (e.g. on a Microsoft Surface).
--
-- Feel free to add new commands and modify it as you want.
----------------------------------------------------------------------


local show_layer_properties_dialogue
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
				app.layer.properties[name] = pvalue
				add_prop_dlg:close()
				show_layer_properties_dialogue()
			end,
	}
	add_prop_dlg:show()
end
show_layer_properties_dialogue = function ()
	local layer = app.layer
	local dlg = Dialog("Layer: ".. layer.name)

	:button {
		text = "ok",
	}
	dlg:button {
		text = "+",
		onclick = function ()
			dlg:close()
			change_dialog(Dialog(""))
		end
	}
	for key,value in pairs(layer.properties) do
		dlg:label{ id = key, label = key, text = tostring(value) }
		:button { text = "-", onclick = function ()
				layer.properties[key] = nil
				dlg:close()
				show_layer_properties_dialogue()
			end }
	end
	dlg:show()
end
show_layer_properties_dialogue()





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
