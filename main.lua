meta.name = "Mod Jam 7 - Tiamat Hazards"
meta.author = "Super Ninja Fat & The Greeni Porcini"
meta.description = "Adds horizontal forcefields and Tiamat-themed hazards to Neo Babylon"
meta.version = "1"
meta.online_safe = true

register_option_int(
	"chance",
	"Spawn Chance (1/N)",
	"1 in N chance the feeling spawns. Set to 1 to always spawn.",
	3,
	1,
	100
)

-- Custom tile codes for horizontal forcefields
-- These spawn properly oriented horizontal forcefields like in Tiamat's Throne
define_tile_code("forcefield_horizontal")
set_pre_tile_code_callback(function(x, y, layer)
	local uid = spawn_grid_entity(ENT_TYPE.FLOOR_HORIZONTAL_FORCEFIELD, x, y, layer)
	local ent = get_entity(uid)
	ent.angle = 3 * math.pi / 2
	return true
end, "forcefield_horizontal")

define_tile_code("forcefield_horizontal_top")
set_pre_tile_code_callback(function(x, y, layer)
	local uid = spawn_grid_entity(ENT_TYPE.FLOOR_HORIZONTAL_FORCEFIELD_TOP, x, y, layer)
	local ent = get_entity(uid)
	ent.angle = 3 * math.pi / 2
	return true
end, "forcefield_horizontal_top")

-- Bubble platform spawning from liquid surfaces (adapted from HDmod acid bubbles)

local feeling_active = false
local surface_locations = {}
local gameframe_cb = -1

local BUBBLE_PADDING <const> = 300
local BUBBLE_RANGE <const> = 200

---@param initial boolean? skip the constant padding for bubbles that spawn near level start
---@return integer
local function set_bubble_timeout(initial)
	local prng = get_local_prng()
	return (initial and 0 or BUBBLE_PADDING) + prng:random_int(0, BUBBLE_RANGE, PRNG_CLASS.PARTICLES)
end

-- Collect all water tile positions during level gen via tile code callback
local water_tiles = {} -- set of "x,y" keys

set_post_tile_code_callback(function(x, y, layer)
	if feeling_active and layer == LAYER.FRONT then
		water_tiles[x .. "," .. y] = true
	end
end, "water")

local function init_bubble_surface_locations()
	surface_locations = {}
	-- A surface tile is water with no water directly above it
	for key in pairs(water_tiles) do
		local x, y = key:match("(.+),(.+)")
		x, y = tonumber(x), tonumber(y)
		if not water_tiles[x .. "," .. (y + 1)] then
			surface_locations[#surface_locations + 1] = {
				x = x,
				y = y,
				timer = set_bubble_timeout(true),
			}
		end
	end
	water_tiles = {}
end

local function bubble_spawning_update()
	local layer <const> = LAYER.FRONT
	for _, location in ipairs(surface_locations) do
		-- Check for water surface FX at this position (handles dynamic liquid changes)
		local hitbox = AABB:new(location.x - 0.05, location.y + 0.05, location.x + 0.05, location.y - 0.05)
		local surface_uids = get_entities_overlapping_hitbox(ENT_TYPE.FX_WATER_SURFACE, MASK.FX, hitbox, layer)

		-- Disable when surface is gone or tile above is solid
		if
			#surface_uids == 0
			or test_flag(get_entity_flags(get_grid_entity_at(location.x, location.y + 1, layer)), ENT_FLAG.SOLID)
		then
			location.timer = -1
			goto continue
		end

		if location.timer == 0 then
			-- Spawn bubble platform directly (no warning particles)
			local surface_uid = surface_uids[get_local_prng():random_index(#surface_uids, PRNG_CLASS.PARTICLES)]
			local x, y = get_position(surface_uid)
			if get_entity(surface_uid) and get_liquids_at(x, y - 0.1, layer) > 0 then
				spawn_entity(ENT_TYPE.ACTIVEFLOOR_BUBBLE_PLATFORM, x, y, layer, 0, 0)
			end
			location.timer = set_bubble_timeout()
		elseif location.timer == -1 then
			-- Re-enable with a fresh timeout
			location.timer = set_bubble_timeout(true)
		else
			location.timer = location.timer - 1
		end

		::continue::
	end
end

-- Load custom level file on Neo Babylon levels
set_callback(function(ctx)
	local state = get_local_state()
	feeling_active = false
	if state.screen ~= SCREEN.LEVEL or state.theme ~= THEME.NEO_BABYLON then
		return
	end
	if get_local_prng():random_chance(options.chance, PRNG_CLASS.LEVEL_GEN) then
		feeling_active = true
		ctx:add_level_files({ "bubbleonarea.lvl" })
		toast("Tiamat's influence seeps through the walls...")
	end
end, ON.PRE_LOAD_LEVEL_FILES)

-- After level is built, scan for liquid surfaces and start bubble spawning
set_callback(function()
	if not feeling_active then return end
	init_bubble_surface_locations()
	clear_callback(gameframe_cb)
	gameframe_cb = set_callback(bubble_spawning_update, ON.GAMEFRAME)
end, ON.POST_LEVEL_GENERATION)

-- Clean up on level destruction
set_callback(function()
	surface_locations = {}
	clear_callback(gameframe_cb)
	gameframe_cb = -1
end, ON.PRE_LEVEL_DESTRUCTION)
