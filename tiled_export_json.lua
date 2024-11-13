local pluginKey = "navneetankur/tiled"

local LAST_PATH_KEY = "lastpath"

local spr = app.activeSprite
if not spr then return print "No active sprite" end

if ColorMode.TILEMAP == nil then ColorMode.TILEMAP = 4 end
assert(ColorMode.TILEMAP == 4)

local TILESIZE = 16

local fs = app.fs
local pc = app.pixelColor
local path_without_ext = fs.filePathAndTitle(spr.filename)
local name_without_ext = fs.fileTitle(spr.filename)
local tileset = spr.tilesets[1]
local tileset_n = 0

local function get_path_without_ext()
	local lastpath = spr.properties(pluginKey)[LAST_PATH_KEY]
	if not lastpath then
		lastpath = path_without_ext..".tmj"
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
		filetypes={ "tmj" },
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
local function export_cel(cel)
	if cel.image.colorMode == ColorMode.TILEMAP then
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
		return tiles
	end
	return nil
end
local function get_jproperty(name, value)
	local jproperty = {}
	local prop_type = type(value)
	if prop_type == "boolean" then
		prop_type = "bool"
	end
	jproperty.name = name
	jproperty.type = prop_type
	jproperty.value = value
	return jproperty
end

local function export_layer(layer)
	if layer.isImage and layer.isTilemap then
		local t = {}
		t.name = layer.name
		t.width = spr.width / TILESIZE
		t.height = spr.height / TILESIZE
		t.opacity = layer.opacity/255
		t.visible = true
		if #layer.cels >= 1 then
			local cell = layer.cels[1]
			local ldata = export_cel(cell)
			if not ldata then
				return nil
			end
			t.data = ldata
		end
		t.properties = {}
		local jproperties = t.properties
		for k,v in pairs(layer.properties) do
			local jproperty = get_jproperty(k,v)
			table.insert(jproperties, jproperty)
		end
		if not next(t.properties) then
			t.properties = nil
		end
		t["type"] = "tilelayer"
		return t
	end
	return nil
end

local function export_layers(layers)
	local t = {}
	local lid = 1
	for _,layer in ipairs(layers) do
		if layer.isVisible then
			local jlayer = export_layer(layer)
			if jlayer then
				jlayer.id = lid
				lid = lid + 1
				jlayer.width = spr.width/TILESIZE
				jlayer.height = spr.height/TILESIZE
				table.insert(t, jlayer)
			end
		end
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
local tmj = {}
tmj.version = "1.10"
tmj.orientation = "orthogonal"
tmj.renderorder = "right-down"
tmj.width = spr.width/TILESIZE
tmj.height = spr.height/TILESIZE
tmj.tilewidth = TILESIZE
tmj.tileheight = TILESIZE
tmj.infinite = false
tmj.nextobjectid = 1
-- add sprite properties to map
tmj.properties = {}
local jproperties = tmj.properties
for k,v in pairs(app.sprite.properties) do
	local jproperty = get_jproperty(k,v)
	table.insert(jproperties, jproperty);
end
if not next(tmj.properties) then
	tmj.properties = nil
end
tmj.tilesets = {}
local jtileset = {}
jtileset.firstgid = 1
jtileset.source = name_without_ext..".tsj"
table.insert(tmj.tilesets, jtileset)

local layers = export_layers(spr.layers)
tmj.layers = layers
tmj.nextlayerid = #layers + 1
local tmj_filename = path_without_ext .. ".tmj"
local file = io.open(tmj_filename, "w")
file:write(json.encode(tmj))
file:close()

local tileset_max_no_of_cols = 4
local no_of_tiles = export_tileset(spr.tilesets[1], tileset_max_no_of_cols)
local tileset_width = tileset_max_no_of_cols
local tileset_height = math.ceil(no_of_tiles/tileset_max_no_of_cols)

local tsj = {}
tsj["version"] =  "1.10"
tsj["tiledversion"] =  "1.10.2"
tsj["name"] =  filename_without_ext
tsj["tilewidth"] = TILESIZE
tsj["tileheight"] = TILESIZE
tsj["tilecount"] = no_of_tiles
tsj.transformations = {}
local transformations = tsj.transformations
transformations.hflip = true
transformations.vflip = true
transformations.rotate = true
transformations.preferuntransformed = true

tsj.image = name_without_ext..".png"
tsj.imageheight = tileset_height * TILESIZE
tsj.imagewidth = tileset_width * TILESIZE

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
jtileset.tiles = {}
for i=1,#tileset do
	local tile = tileset:tile(i)
	if tile then
		local jtile = {}
		jtile.id = i - 1
		jtile.properties = {}
		local jproperties = jtile.properties
		for name,value in pairs(tile.properties) do
			local jproperty = {}
			local prop_type = type(value)
			if prop_type == "boolean" then
				prop_type = "bool"
			end
			jproperty.name = name
			jproperty.value = value
			jproperty.type = prop_type
			table.insert(jproperties, jproperty)

			local red = pc.rgba(255, 0, 0)
			if name == "asp_collision_by" then
				jtile.objectgroup = {}
				local jogroup = jtile.objectgroup
				jogroup.draworder = "index"
				jogroup.id = 1
				jogroup.objects = {}
				local jobjects = jogroup.objects
				local jobject = {}
				table.insert(jobjects, jobject)
				jobject.id = object_id
				object_id = object_id + 1
				jobject.x = 0
				jobject.y = 0

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
					table.insert(points2, {x = point[1], y = point[2]})
				end
				jobject.polygon = points2
			end

		end
		if not next(jtile.properties) then
			table.insert(jtileset.tiles, jtile)
		end
	end
end

local tsj_filename = path_without_ext .. ".tsj"
local file = io.open(tsj_filename, "w")
file:write(json.encode(tsj))
file:close()
