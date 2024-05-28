local pluginKey = "navneetankut/tiled"
local LAST_PATH_KEY = "lastpath"

local spr = app.activeSprite
if not spr then return print "No active sprite" end

if ColorMode.TILEMAP == nil then ColorMode.TILEMAP = 4 end
assert(ColorMode.TILEMAP == 4)

local TILESIZE = 16

local fs = app.fs
local pc = app.pixelColor
local path_without_ext = fs.filePathAndTitle(spr.filename)
local tileset = spr.tilesets[1]
local image_n = 0
local tileset_n = 0

local function get_path_without_ext()
	local lastpath = spr.properties(pluginKey)[LAST_PATH_KEY]
	if not lastpath then
		lastpath = path_without_ext..".tmx"
	end
	local dlg = Dialog("Export to")
	dlg:file{
		id="file",
		label="file",
		title="file",
		open=false,
		save=true,
		filename = lastpath,
		-- filename=string | { string1,string2,string3... },
		filetypes={ "tmx" },
		-- onchange=function 
	}
	dlg:button {text = "Ok", focus = true}
	dlg:show()
	local new_path = dlg.data["file"]
	spr.properties(pluginKey)[LAST_PATH_KEY] = new_path
	return fs.filePathAndTitle(new_path)
end

path_without_ext = get_path_without_ext()

local filename_without_ext = fs.fileName(path_without_ext)

local function get_tile(name, tileset)
	for i = 0,#tileset-1 do
	  local ctile = tileset:tile(i)
	  if ctile.properties["name"] == name then
		  return ctile
	  end
	end
end

local function xml_doc()
	return {
		type = "document",
		name = "#doc",
		kids = {},
	}
end
local function xml_element(name)
	return {
		type = "element",
		name = name,
		attr = {},
		kids = {},
	}
end
local function xml_add_attr(element, attr)
	table.insert(element.attr, attr)
end
local function xml_add_child(element, child)
	table.insert(element.kids, child)
end
local function xml_attr(name, value)
	local value_str = tostring(value)
	if value_str:sub(-2) == ".0" then
		value_str = value_str:sub(1,-3)
	end
	return {
		type = "attribute",
		name = name,
		value = value_str,
	}
end
local function xml_text(text)
	return {
		type = "text",
		name = "#text",
		value = text,
	}
end

local function write_json_data(filename, data)
  local json = dofile('./json.lua')
  local file = io.open(filename, "w")
  file:write(json.encode(data))
  file:close()
end

local function fill_user_data(t, obj)
  if obj.color.alpha > 0 then
    if obj.color.alpha == 255 then
      t.color = string.format("#%02x%02x%02x",
                              obj.color.red,
                              obj.color.green,
                              obj.color.blue)
    else
      t.color = string.format("#%02x%02x%02x%02x",
                              obj.color.red,
                              obj.color.green,
                              obj.color.blue,
                              obj.color.alpha)
    end
  end
  if pcall(function() return obj.data end) then -- a tag doesn't have the data field pre-v1.3
    if obj.data and obj.data ~= "" then
      t.data = obj.data
    end
  end
end

local function export_tileset(tileset, no_of_cols)
  local grid = tileset.grid
  local size = grid.tileSize
  if #tileset > 0 then
    local spec = spr.spec
    spec.width = TILESIZE * no_of_cols
    spec.height = TILESIZE * math.ceil((#tileset-1)/no_of_cols)
    local image = Image(spec)
    image:clear()
    for i = 0,#tileset-2 do
      local tile = tileset:getTile(i+1)
	  local row = math.floor(i/no_of_cols)
	  local col = i - row * no_of_cols
      image:drawImage(tile, (col)*TILESIZE, row*TILESIZE)
    end

    tileset_n = tileset_n + 1
    -- local imageFn = fs.joinPath(output_folder, "tileset" .. tileset_n .. ".png")
    local imageFn = path_without_ext .. ".png"
    image:saveAs(imageFn)
  end
  return #tileset - 1
end

local function export_tilesets(tilesets)
  local t = {}
  for _,tileset in ipairs(tilesets) do
    table.insert(t, export_tileset(tileset))
  end
  return t
end

local function export_frames(frames)
  local t = {}
  for _,frame in ipairs(frames) do
    table.insert(t, { duration=frame.duration })
  end
  return t
end

local function export_cel(cel)
	if cel.image.colorMode == ColorMode.TILEMAP then
		--slaxml
		local t = xml_element("data")
		t.attr[1] = xml_attr("encoding", "csv")
		--slaxml end
		local bounds={
			x=cel.bounds.x,
			y=cel.bounds.y,
			width=cel.bounds.width,
			height=cel.bounds.height,
		}
		local tilemap = cel.image
		local tiles = {}

		local total_no_of_cols = spr.width / TILESIZE
		local total_no_of_row = spr.height / TILESIZE
		for _=1,total_no_of_row*total_no_of_cols do
			table.insert(tiles, 0)
		end

		local row_start = math.floor(bounds.y / TILESIZE)
		local row_end = tilemap.height + row_start
		local col_start = math.floor(bounds.x / TILESIZE)
		local col_end = tilemap.width + col_start

		local pixels = tilemap:pixels()
		for row=row_start,row_end-1 do
			for col=col_start,col_end-1 do
				tiles[row * total_no_of_cols + col + 1] = pixels()()
			end
		end
		-- slaxml
		local tile_str = table.concat(tiles, ",")
		xml_add_child(t, xml_text(tile_str))
		-- slaxml end
		return t
	end
	return nil
end

local function get_tileset_index(layer)
  for i,tileset in ipairs(layer.sprite.tilesets) do
    if layer.tileset == tileset then
      return i-1
    end
  end
  return -1
end

local function export_layer(layer)
	if layer.isImage then
		--slaxml start
		local t = xml_element("layer")
		xml_add_attr(t, xml_attr("name", layer.name))
		--slaxml end
		t.width = spr.width / TILESIZE
		t.height = spr.height / TILESIZE
		if layer.opacity < 255 then
			t.opacity = layer.opacity/255
		end
		if #layer.cels >= 1 then
			local cell = layer.cels[1]
			local ldata = export_cel(cell)
			if not ldata then
				return nil
			end
			xml_add_child(t, ldata)
		end
		-- fill_user_data(t, layer)
		return t
	end
	return nil
end

local function export_layers(layers)
	local t = {}
	local lid = 1
	for _,layer in ipairs(layers) do
		if layer.isVisible then
			local xlayer = export_layer(layer)
			if xlayer then
				xml_add_attr(xlayer, xml_attr("id", lid))
				lid = lid + 1
				xml_add_attr(xlayer, xml_attr("width", spr.width/TILESIZE))
				xml_add_attr(xlayer, xml_attr("height", spr.height/TILESIZE))
				table.insert(t, xlayer)
			end
		end
	end
	return t
end

local function ani_dir(d)
  local values = { "forward", "reverse", "pingpong" }
  return values[d+1]
end

local function export_tag(tag)
  local t = {
    name=tag.name,
    from=tag.fromFrame.frameNumber-1,
    to=tag.toFrame.frameNumber-1,
    aniDir=ani_dir(tag.aniDir)
  }
  fill_user_data(t, tag)
  return t
end

local function export_tags(tags)
  local t = {}
  for _,tag in ipairs(tags) do
    table.insert(t, export_tag(tag, export_tags))
  end
  return t
end

local function export_slice(slice)
  local t = {
    name=slice.name,
    bounds={ x=slice.bounds.x,
             y=slice.bounds.y,
             width=slice.bounds.width,
             height=slice.bounds.height }
  }
  if slice.center then
    t.center={ x=slice.center.x,
               y=slice.center.y,
               width=slice.center.width,
               height=slice.center.height }
  end
  if slice.pivot then
    t.pivot={ x=slice.pivot.x,
               y=slice.pivot.y }
  end
  fill_user_data(t, slice)
  return t
end

local function export_slices(slices)
  local t = {}
  for _,slice in ipairs(slices) do
    table.insert(t, export_slice(slice, export_slices))
  end
  return t
end

----------------------------------------------------------------------
-- Creates output folder

-- fs.makeDirectory(output_folder)

----------------------------------------------------------------------
-- Write /sprite.json file in the output folder
--
local tmx = xml_doc()
local map = xml_element("map")
xml_add_attr(map, xml_attr("version", "1.10"))
xml_add_attr(map, xml_attr("tiledversion", "1.10.2"))
xml_add_attr(map, xml_attr("orientation", "orthogonal"))
xml_add_attr(map, xml_attr("renderorder", "right-down"))
xml_add_attr(map, xml_attr("width",spr.width/TILESIZE))
xml_add_attr(map, xml_attr("height",spr.height/TILESIZE))
xml_add_attr(map, xml_attr("tilewidth",TILESIZE))
xml_add_attr(map, xml_attr("tileheight",TILESIZE))
xml_add_attr(map, xml_attr("infinite","0"))
xml_add_attr(map, xml_attr("nextobjectid","1"))
xml_add_child(tmx, map)
local xtileset = xml_element("tileset")
xml_add_attr(xtileset, xml_attr("firstgid", "1"))
-- xml_add_attr(xtileset, xml_attr("source", "tileset1.tsx"))
xml_add_attr(xtileset, xml_attr("source", path_without_ext..".tsx"))
xml_add_child(map, xtileset)

local layers = export_layers(spr.layers)
local no_of_layers = 1
for i,layer in ipairs(layers) do
	xml_add_child(map, layer)
	no_of_layers = i
end
xml_add_attr(map, xml_attr("nextlayerid",no_of_layers + 1))
-- local tmx_filename = fs.joinPath(output_folder, "tilemap.tmx")
local tmx_filename = path_without_ext .. ".tmx"
local SLAXML = require 'slaxdom'
local file = io.open(tmx_filename, "w")
local xml = SLAXML:xml(tmx, {indent = "\t"})
file:write(xml)
file:close()

local tileset_max_no_of_cols = 4
local no_of_tiles = export_tileset(spr.tilesets[1], tileset_max_no_of_cols)
local tileset_width = tileset_max_no_of_cols
local tileset_height = math.ceil(no_of_tiles/tileset_max_no_of_cols)

local tsx = xml_doc()
local xtileset = xml_element("tileset")
xml_add_child(tsx, xtileset)
xml_add_attr(xtileset, xml_attr("version", "1.10"))
xml_add_attr(xtileset, xml_attr("tiledversion", "1.10.2"))
xml_add_attr(xtileset, xml_attr("name", filename_without_ext))
xml_add_attr(xtileset, xml_attr("tilewidth",TILESIZE))
xml_add_attr(xtileset, xml_attr("tileheight",TILESIZE))
local transformations = xml_element("transformations")
xml_add_attr(transformations, xml_attr("hflip", "1"))
xml_add_attr(transformations, xml_attr("vflip", "1"))
xml_add_attr(transformations, xml_attr("rotate", "1"))
xml_add_attr(transformations, xml_attr("preferuntransformed", "1"))
xml_add_child(xtileset, transformations)

local image = xml_element("image")
xml_add_attr(image, xml_attr("source", path_without_ext..".png"))
xml_add_attr(image, xml_attr("width", tileset_width * TILESIZE))
xml_add_attr(image, xml_attr("height", tileset_height))
xml_add_child(xtileset, image)

local function cross(a, b, o)
   return (a[1] - o[1]) * (b[2] - o[2]) - (a[2] - o[2]) * (b[1] - o[1])
end

-- /**
--  * @param points to sorted array of [X, Y] coordinates
--  */
local function convexHull(points)
   local lower = {};
   for i = 1, #points do
      while (#lower >= 2 and cross(lower[#lower - 1], lower[#lower], points[i]) <= 0) do
         table.remove(lower)
	  end
      table.insert(lower,points[i]);
	end

   local upper = {};
   for i = #points,1,-1 do
      while (#upper >= 2 and cross(upper[#upper - 1], upper[#upper], points[i]) <= 0) do
         table.remove(upper)
	 end
      table.insert(upper,points[i]);
  end

         table.remove(upper)
         table.remove(lower)
   -- return lower.concat(upper);
   for _,v in ipairs(upper) do
   	table.insert(lower, v)
   end
   return lower
end
local object_id = 2
for i=1,#tileset do
	local tile = tileset:tile(i)
	local has_property = false
	if tile then
		local xtile = xml_element("tile")
		xml_add_attr(xtile, xml_attr("id", pc.tileI(tile.index) - 1))
		local xproperties = xml_element("properties")
		xml_add_child(xtile, xproperties)
		for name,value in pairs(tile.properties) do
			local xproperty = xml_element("property")
			local prop_type = type(value)
			if prop_type == "boolean" then
				prop_type = "bool"
			end
			xml_add_attr(xproperty, xml_attr("name", name))
			xml_add_attr(xproperty, xml_attr("value", value))
			xml_add_attr(xproperty, xml_attr("type", prop_type))
			xml_add_child(xproperties, xproperty)
			has_property = true

			local red = pc.rgba(255, 0, 0)
			if name == "asp_collision_by" then
				local xobjectgroup = xml_element("objectgroup")
				xml_add_child(xtile, xobjectgroup)
				xml_add_attr(xobjectgroup, xml_attr("draworder", "index"))
				xml_add_attr(xobjectgroup, xml_attr("id", "1"))
				local xobject = xml_element("object")
				xml_add_child(xobjectgroup, xobject)
				xml_add_attr(xobject, xml_attr("id", object_id))
				object_id = object_id + 1
				xml_add_attr(xobject, xml_attr("x", "0"))
				xml_add_attr(xobject, xml_attr("y", "0"))

				local ctile = get_tile(value, tileset)
				local points = {}
				local pixels = ctile.image:pixels()
				for y=0,TILESIZE - 1 do
					for x=0,TILESIZE - 1 do
						local current_pixel = pixels()()
						if current_pixel == red then
							table.insert(points,{x + 0.5,y + 0.5})
						end
					end
				end
				local convex_hull = convexHull(points)
				local points2 = {}
				for _,point in ipairs(convex_hull) do
					table.insert(points2, table.concat(point,","))
				end

				local xpolygon = xml_element("polygon")
				xml_add_attr(xpolygon, xml_attr("points", table.concat(points2, " ")))
				xml_add_child(xobject, xpolygon)
			end

		end
		if has_property then
			xml_add_child(xtileset, xtile)
		end
	end
end

-- local tsx_filename = fs.joinPath(output_folder, "tileset1.tsx")
local tsx_filename = path_without_ext .. ".tsx"
local file = io.open(tsx_filename, "w")
local xml = SLAXML:xml(tsx, {indent = "\t"})
file:write(xml)
file:close()
