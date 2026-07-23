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

-- Load custom level file on Neo Babylon levels
set_callback(function(ctx)
	local state = get_local_state()
	-- Only run the level feeling for NeoBabylon levels
	if state.screen ~= SCREEN.LEVEL or state.theme ~= THEME.NEO_BABYLON then
		return
	end
	if get_local_prng():random_chance(options.chance, PRNG_CLASS.LEVEL_GEN) then
		ctx:add_level_files({ "bubbleonarea.lvl" })
		toast("Tiamat's influence seeps through the walls...")
	end
end, ON.PRE_LOAD_LEVEL_FILES)
