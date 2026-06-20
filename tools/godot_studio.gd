extends Node3D

const OBJECTS_FILE := WorldFile.OBJECTS
const HM_PATH := WorldFile.HEIGHTMAP
const BM_PATH := WorldFile.BIOME
const HM_MIN := WorldFile.HM_MIN
const HM_MAX := WorldFile.HM_MAX
const BOX_COLORS := [["Red", Color(0.85, 0.25, 0.25)], ["Orange", Color(0.90, 0.55, 0.20)],
	["Yellow", Color(0.92, 0.85, 0.30)], ["Green", Color(0.35, 0.72, 0.35)],
	["Blue", Color(0.30, 0.55, 0.85)], ["Purple", Color(0.60, 0.40, 0.80)],
	["Grey", Color(0.60, 0.62, 0.65)], ["White", Color(0.92, 0.93, 0.95)]]

const BIOMES := [
	{"name": "Grass",  "color": Color(0.30, 0.70, 0.18)},
	{"name": "Swamp",  "color": Color(0.55, 0.15, 0.65)},
	{"name": "Desert", "color": Color(1.00, 0.48, 0.03)},
	{"name": "Snow",   "color": Color(1.00, 1.00, 1.00)},
	{"name": "Rock",   "color": Color(0.52, 0.52, 0.55)},
]

enum {MODE_SCULPT, MODE_FLATTEN, MODE_BIOME, MODE_PLACE, MODE_ERASE, MODE_NOISE, MODE_MATCH, MODE_SETELEV, MODE_SELECT, MODE_AREA, MODE_CHAR}
const MODE_NAMES := {MODE_SELECT: "Select", MODE_SCULPT: "Sculpt", MODE_FLATTEN: "Flatten",
	MODE_MATCH: "Match height", MODE_SETELEV: "Set elevation", MODE_NOISE: "Noise",
	MODE_BIOME: "Material", MODE_PLACE: "Place objects", MODE_ERASE: "Erase objects",
	MODE_CHAR: "Character", MODE_AREA: "Group area"}
var _brush_hdr: Label = null
var _cursor_over_ui := false
var mode := MODE_SCULPT

var _select_sub: VBoxContainer = null
var _select_panel: PanelContainer = null
var _sel_info: Label = null
var _rotate_in_place := false
var _water_btn: CheckBox = null  # water layer eye; kept in sync with the shaders "Water" toggle
var _char_blend := 1.0
var _char_from_focus := Vector3.ZERO
var _char_from_dist := 0.0
var _char_from_pitch := 0.0
var _undo: Array = []
const UNDO_MAX := 80
var _bpanel: Control = null
var _sfx_place: AudioStreamPlayer
var _sfx_remove: AudioStreamPlayer
var _area_a = null               # area-select first corner (Vector3) while dragging
var _area_box: MeshInstance3D = null

var _map_slug := ""
var _map_name := ""
var _open_btn: Button = null
var _new_btn: Button = null
var _map_lbl: Label = null
var _open_menu_slugs: Array = []
var _layer_states := {"water": true, "terrain": true, "objects": true}
var _uid_counter := 0

var zoom_speed := 1.0
var chase_draw_dist := 150.0
var orbit_draw_dist := 4000.0
var orbit_shadow_dist := 220.0
var chase_shadow_dist := 90.0
var _low_cost := false
var _perf_detail := false
const SUN := Vector3(0.4, 0.82, 0.41)

var hm_img: Image
var bm_img: Image
var _hm_w := 0
var _hm_h := 0

const CHUNK := 50
var _chunks := {}
var _dirty_chunks := {}
var _ground_mat: StandardMaterial3D
var _water: MeshInstance3D
var _wh_img: Image
var _wh_tex: ImageTexture
var wm_img: Image
var wm_tex: ImageTexture
var _objects_visible := true
var _ui_layer: CanvasLayer = null
var _fps_lbl: Label = null
var _place_rot := 0.0
var _place_rot_explicit := false   # rotated by hand -> never randomize on commit
var _mode_btns := {}
var _terrain_menu_btn: MenuButton = null
var _water_sim: WaterSim = null    # flowing-water engine
var _sun: DirectionalLight3D
var _env_e: Environment
var _sky_e: ProceduralSkyMaterial
var _editor_tod := 0.5
var cam: Camera3D
var status: Label
var tree_ui: Tree
var filter: LineEdit
var biome_box: OptionButton
var _se: SpinBox
var _se_lbl: Label
var _tile_lbl: Label
var _tile_slider: HSlider
var _panel: Control
var _rpanel: Control
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _grid: MeshInstance3D = null
var _grid_mat: StandardMaterial3D = null
var _grid_btn: CheckBox = null   # LAYERS "gridlines" eye; the G key keeps it in sync
var _grid_dirty := false      # terrain changed; re-drape the slope grid (throttled)
var _grid_t := 0.0
var _folders := {}

var focus := Vector3.ZERO
var cam_dist := 100.0
var cam_yaw := 0.7
var cam_pitch := 0.62
var _orbit := false
var brush_radius := 8.0
var brush_strength := 1
const STRENGTH_UNIT := 0.000015   # normalized height per (strength*frame); FORMAT_RF accumulates sub-quantum
var target_elev := 5.0

## Strength response curve: near-linear at the low end, ramping hard toward 100.
func _str_amp(strn: int) -> float:
	return float(strn) * (1.0 + 9.0 * pow(float(strn) / 100.0, 3.0))

## Brush weight: full strength across the middle, soft taper over the outer third.
func _falloff(d: float, rpx: float) -> float:
	return 1.0 - smoothstep(rpx * 0.66, rpx, d)
var brush_opacity := 0.3
var biome_index := 0
var smart_on := false
var smart_sel := 0
var smart_mats: Array = []
var sid_img: Image
var _smart_cb: CheckBox
var _smart_panel: VBoxContainer
var smart_overlay_on := false
# Smart re-bake throttle (~1/sec): accumulate the dirty world rect, flush on cooldown.
var _smart_due := false
var _smart_last_ms := 0
var _smart_rect := Rect2()
const SMART_COLORS := [Color(0.92, 0.32, 0.28), Color(0.30, 0.62, 0.92), Color(0.42, 0.85, 0.42),
	Color(0.95, 0.82, 0.30), Color(0.80, 0.42, 0.92), Color(0.40, 0.85, 0.85)]
var _paint := 0
var _last_place_pos = null
const PLACE_SPACING := 2.5
var _dirty := false
var _height_dirty := false   # terrain (not just biome) changed -> recache heights
var _build_acc := 0.0
var _toast_panel: PanelContainer = null
var _toast_lbl: Label = null
var _flash_t := 0.0

var _objects: Array = []
var _spawned: Array = []
var _obj_tiles: Array = []
var _occupied := {}
var _last: Node3D = null
var _sel_idx := -1
var _hi_mat: StandardMaterial3D = null
var _hi_nodes: Array = []
var _ungroup_btn: Button = null
var _setground_btn: Button = null
var _applyground_btn: Button = null
var _ground_off := {}
const GROUND_OFF_FILE := "res://assets/world/ground_offsets.json"
var _sel: Array = []
var _selbox_a = null                     # Shift drag-box first corner (Vector3)
var _selbox_b = null                     # last valid drag-box end corner (so release commits even off-terrain)
var _selbox_screen := Vector2.ZERO
var _dragging_sel := false
var _sel_hold := 0.0
const SEL_DRAG_DELAY := 0.2    # must hold > this before the item starts following the cursor
var _select_btn: Button = null

func _ready() -> void:
	focus = Vector3(Config.GRID_COLS * 0.5, 0.0, Config.GRID_ROWS * 0.5)
	_map_slug = MapStore.active_or_migrate()
	_map_name = MapStore.display_name(_map_slug)
	_load_masks()
	_env_e = Environment.new()
	_sky_e = ProceduralSkyMaterial.new()
	var sky := Sky.new(); sky.sky_material = _sky_e
	_env_e.background_mode = Environment.BG_SKY; _env_e.sky = sky
	_env_e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env_e.ambient_light_color = Color(0.75, 0.78, 0.85); _env_e.ambient_light_energy = 0.9
	_env_e.tonemap_white = 6.0
	WorldLook.apply_pipeline(_env_e)
	_env_e.ssao_enabled = true
	_env_e.ssao_radius = 0.6
	_env_e.ssao_intensity = 2.0
	var we := WorldEnvironment.new(); we.environment = _env_e; add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-55, 35, 0); _sun.light_energy = 1.2
	_sun.shadow_enabled = true
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	_sun.shadow_normal_bias = 1.2
	_sun.directional_shadow_max_distance = 220.0
	add_child(_sun)
	_apply_wind()
	add_child(preload("res://scripts/ambient_motes.gd").new())
	cam = Camera3D.new(); cam.far = 4000.0; add_child(cam); cam.current = true
	cam_dist = clampf(Config.GRID_COLS * 0.42, 40.0, 800.0)
	_rebuild_hgrid()
	_build_chunks()
	_build_edge_line()
	_build_water()
	_make_ring()
	_load_cam()
	_update_cam()
	_register_builtin_shaders()
	# Drop-in "special" pack (gitignored res://special/): registers extra shader layers (fog/mist,
	# foam, …) BEFORE the shaders section builds, so they appear as toggles. Delete folder = clean base.
	if ResourceLoader.exists("res://special/special.gd"):
		var _sp: Object = load("res://special/special.gd").new()
		if _sp.has_method("apply"): _sp.apply(self)
	_build_ui()
	_load_ground_off()
	# TAA resolves the mist wall's temporal jitter; low-cost mode turns it back off.
	get_viewport().use_taa = true
	_apply_cursor(mode)   # startup mode never goes through _set_mode
	_water_sim = WaterSim.new()
	_water_sim.setup(
		func(x, z): return _height(float(x), float(z)),
		func(_cell): return false)
	_water_sim.physics_mask = Config.PHYS_SETPIECE
	add_child(_water_sim)
	_load_objects()
	_setup_sfx()
	_refresh_status()
	for a in OS.get_cmdline_args():
		if a == "--testchar":
			_run_testchar.call_deferred()
		elif a == "--testwater":
			_run_testwater.call_deferred()
		elif str(a).begins_with("--tod="):
			_editor_tod = float(str(a).substr(6))
			_apply_editor_time.call_deferred(_editor_tod)
		elif a == "--testreload":
			print("PROBE ", _dev_probe())
			get_tree().create_timer(3.0).timeout.connect(_dev_reload)
	get_tree().auto_accept_quit = false

	# Render editor UI at native pixel size (the project's canvas_items stretch blows tools up on big monitors).
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	if not "--shot" in OS.get_cmdline_args():
		get_window().grab_focus()
		_go_fullscreen.call_deferred()    # deferred: too early inside _ready (no-ops)
	if "--shot" in OS.get_cmdline_args():
		# Timer only — awaiting frame_post_draw can stall forever in a minimized window.
		await get_tree().create_timer(2.0).timeout
		get_viewport().get_texture().get_image().save_png("res://screenshots/godot_studio_preview.png")
		print("SHOT godot_studio_preview objects=", _objects.size())
		get_tree().quit()

## Headless check: a spring must GROW over time (not appear instantly, not stay one cell).
func _run_testwater() -> void:
	await get_tree().create_timer(1.5).timeout
	var c := Vector3(Config.GRID_COLS * 0.5, 0, Config.GRID_ROWS * 0.5)
	var cy := int(floor(_height(c.x, c.z))) + 1
	_try_place_entry({"kind": "water_src", "uid": _new_uid(),
		"x": floor(c.x) + 0.5, "y": cy + 0.5, "z": floor(c.z) + 0.5})
	await get_tree().create_timer(0.15).timeout
	var early: int = _water_sim._cells.size()
	await get_tree().create_timer(3.0).timeout
	var late: int = _water_sim._cells.size()
	print("TESTWATER early=%d late=%d -> %s" % [early, late,
		"PASS" if late > early and late >= 8 else "FAIL"])
	get_tree().quit()

## Headless check: the character must land ON the terrain, not fall through.
func _run_testchar() -> void:
	await get_tree().create_timer(1.5).timeout
	_set_mode(MODE_CHAR)
	await get_tree().create_timer(2.5).timeout
	var bp: Vector3 = _char_body.global_position
	var ground := _height(bp.x, bp.z)
	var diff := bp.y - ground
	print("TESTCHAR body_y=%.2f ground=%.2f diff=%.2f -> %s"
		% [bp.y, ground, diff, "PASS" if diff > -0.5 and diff < 1.5 else "FAIL"])
	get_tree().quit()

func _go_fullscreen() -> void:
	# MAXIMIZED, not fullscreen: true fullscreen can lock up the Linux desktop (F11 toggles it).
	await get_tree().process_frame   # wait one frame so the OS window exists
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	get_window().grab_focus()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Don't autosave during automated --shot/--test* runs (a SIGTERM'd test once saved a stray spring).
		var argv := OS.get_cmdline_args()
		if not ("--shot" in argv or "--testwater" in argv or "--testchar" in argv):
			_save()
			_save_cam()
			_save_ui_layout()
		get_tree().quit()

## Active-map file path (under user://maps/<slug>/).
func _mp(fname: String) -> String:
	return MapStore.path(_map_slug, fname)

## Load a bundle image straight from disk (user:// bypasses the import cache, so fresh bytes are seen at once).
func _load_map_img(p: String, keep_alpha := false) -> Image:
	if not FileAccess.file_exists(p):
		return null
	var img := Image.load_from_file(p)
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8 if keep_alpha else Image.FORMAT_RGB8)
	return img

func _read_entries(p: String) -> Array:
	if not FileAccess.file_exists(p):
		return []
	var d = JSON.parse_string(FileAccess.get_file_as_string(p))
	return d if d is Array else []

func _write_entries(p: String, entries: Array) -> void:
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(entries, "  "))
		f.close()

func _slurp(p: String) -> String:
	return FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else ""

func _load_masks() -> void:
	hm_img = _load_map_img(_mp(MapStore.F_HM))
	if hm_img == null:
		var dg := (8.8 - HM_MIN) / (HM_MAX - HM_MIN)
		hm_img = Image.create(256, 256, false, Image.FORMAT_RF); hm_img.fill(Color(dg, dg, dg))
	elif WorldFile.remap_legacy_heightmap(hm_img):
		hm_img.save_png(_mp(MapStore.F_HM))
		WorldFile.mark_heightmap_current()
		print("heightmap migrated to range %.0f..%.0f" % [HM_MIN, HM_MAX])
	# Edit elevation in 32-bit float: 8-bit can't represent a sub-1/255 brush step.
	if hm_img.get_format() != Image.FORMAT_RF:
		hm_img.convert(Image.FORMAT_RF)
	_hm_w = hm_img.get_width(); _hm_h = hm_img.get_height()
	bm_img = _load_map_img(_mp(MapStore.F_BM))
	if bm_img == null or bm_img.get_width() != _hm_w:
		bm_img = Image.create(_hm_w, _hm_h, false, Image.FORMAT_RGB8); bm_img.fill(Color(0, 0, 0))
	wm_img = _load_map_img(_mp(MapStore.F_WM))
	if wm_img == null or wm_img.get_width() != _hm_w:
		wm_img = Image.create(_hm_w, _hm_h, false, Image.FORMAT_RGB8); wm_img.fill(Color(0, 0, 0))
	sid_img = _load_map_img(_mp(MapStore.F_SM))
	if sid_img == null or sid_img.get_width() != _hm_w:
		sid_img = Image.create(_hm_w, _hm_h, false, Image.FORMAT_RGB8)
		sid_img.fill(Color(0, 0, 0))
	smart_mats = SmartMaterial.load_all(_mp(MapStore.F_SMART))

## keep_alpha: the CRAYON mask's doodles live in alpha — an RGB8 convert wipes it and an
func _load_img(path: String, keep_alpha := false) -> Image:
	if not ResourceLoader.exists(path):
		return null
	var tex = load(path)
	var img: Image = tex.get_image() if tex is Texture2D else null
	if img == null:
		return null
	if img.is_compressed(): img.decompress()
	img.convert(Image.FORMAT_RGBA8 if keep_alpha else Image.FORMAT_RGB8)
	return img

func _macro(x: float, z: float) -> float:
	var u := clampf(x / float(Config.GRID_COLS), 0.0, 1.0) * float(_hm_w - 1)
	var v := clampf(z / float(Config.GRID_ROWS), 0.0, 1.0) * float(_hm_h - 1)
	var x0 := int(u); var z0 := int(v)
	var x1 := mini(x0 + 1, _hm_w - 1); var z1 := mini(z0 + 1, _hm_h - 1)
	var fx := u - x0; var fz := v - z0
	var a := hm_img.get_pixel(x0, z0).r; var b := hm_img.get_pixel(x1, z0).r
	var c := hm_img.get_pixel(x0, z1).r; var d := hm_img.get_pixel(x1, z1).r
	var r := lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fz)
	return HM_MIN + r * (HM_MAX - HM_MIN)

var _hgrid: PackedFloat32Array = PackedFloat32Array()
var _hg_w := 0
var _hg_h := 0

func _rebuild_hgrid() -> void:
	_hg_w = Config.GRID_COLS + 1; _hg_h = Config.GRID_ROWS + 1
	_hgrid.resize(_hg_w * _hg_h)
	for z in _hg_h:
		for x in _hg_w:
			_hgrid[z * _hg_w + x] = _height_full(float(x), float(z))

func _height_full(x: float, z: float) -> float:
	var e := _macro(x, z)
	var landmask := clampf((e - Config.WATER_LEVEL) / 2.0, 0.0, 1.0)
	e += (_fbm(x * 0.09, z * 0.09) - 0.5) * 2.5 * landmask
	return maxf(e, -4.0)

func _height(x: float, z: float) -> float:
	if _hgrid.is_empty():
		return _height_full(x, z)
	return HeightField.sample_grid(_hgrid, _hg_w, _hg_h, x, z)

func _biome_at(x: float, z: float) -> int:
	var px := clampi(int(x / float(Config.GRID_COLS) * (_hm_w - 1)), 0, _hm_w - 1)
	var pz := clampi(int(z / float(Config.GRID_ROWS) * (_hm_h - 1)), 0, _hm_h - 1)
	return int(round(bm_img.get_pixel(px, pz).r * 255.0))

func _ihash(ix: int, iz: int) -> float:
	var n := ix * 374761393 + iz * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	return float((n ^ (n >> 16)) & 0xffff) / 65535.0

func _vnoise(x: float, z: float) -> float:
	var ix := floori(x); var iz := floori(z)
	var fx := x - ix; var fz := z - iz
	var ux := fx * fx * (3.0 - 2.0 * fx); var uz := fz * fz * (3.0 - 2.0 * fz)
	var a := _ihash(ix, iz); var b := _ihash(ix + 1, iz)
	var c := _ihash(ix, iz + 1); var d := _ihash(ix + 1, iz + 1)
	return lerpf(lerpf(a, b, ux), lerpf(c, d, ux), uz)

func _fbm(x: float, z: float) -> float:
	var v := 0.0; var amp := 0.5; var fx := x; var fz := z
	for i in 4:
		v += amp * _vnoise(fx, fz); fx *= 2.0; fz *= 2.0; amp *= 0.5
	return v

func _build_chunks() -> void:
	_ground_mat = StandardMaterial3D.new()
	_ground_mat.vertex_color_use_as_albedo = true
	_ground_mat.roughness = 1.0
	_ground_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var nc := int(ceil(float(Config.GRID_COLS) / CHUNK))
	var nr := int(ceil(float(Config.GRID_ROWS) / CHUNK))
	for cy in nr:
		for cx in nc:
			var c := Vector2i(cx, cy)
			var mi := MeshInstance3D.new()
			mi.material_override = _ground_mat
			add_child(mi); _chunks[c] = mi
			_rebuild_chunk(c)

## Re-mesh ONE chunk (only the edited chunk(s) rebuild while sculpting → fast).
func _rebuild_chunk(c: Vector2i) -> void:
	var mi: MeshInstance3D = _chunks.get(c)
	if mi == null:
		return
	var x0 := c.x * CHUNK; var z0 := c.y * CHUNK
	var x1 := mini((c.x + 1) * CHUNK, Config.GRID_COLS)
	var z1 := mini((c.y + 1) * CHUNK, Config.GRID_ROWS)
	var verts := PackedVector3Array(); var normals := PackedVector3Array()
	var colors := PackedColorArray(); var indices := PackedInt32Array()
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			verts.append(Vector3(x, _height(x, z), z))
			var col := Config.ground_color(_biome_at(x, z))
			if smart_overlay_on:
				var o := _smart_owner_at(x, z)
				if o >= 0: col = _smart_color(o)
			colors.append(col)
			var e := 0.5
			normals.append(Vector3(_height(x - e, z) - _height(x + e, z), 2.0 * e,
				_height(x, z - e) - _height(x, z + e)).normalized())
	var w := (x1 - x0) + 1
	for j in range(z1 - z0):
		for i in range(x1 - x0):
			var a := j * w + i
			indices.append(a); indices.append(a + w); indices.append(a + 1)
			indices.append(a + 1); indices.append(a + w); indices.append(a + w + 1)
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts; arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_COLOR] = colors; arr[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mi.mesh = mesh

## After an edit: terrain changed -> recache heights + rebuild touched chunks + water;
func _after_edit(p: Vector3, height_changed: bool, rad: float = -1.0) -> void:
	if not height_changed:
		var br := (rad if rad > 0.0 else brush_radius) + 2.0
		var bx0 := int(floor(p.x - br)); var bx1 := int(ceil(p.x + br))
		var bz0 := int(floor(p.z - br)); var bz1 := int(ceil(p.z + br))
		var bcx0 := int(floor(float(bx0 - 1) / CHUNK)); var bcx1 := int(floor(float(bx1 + 1) / CHUNK))
		var bcy0 := int(floor(float(bz0 - 1) / CHUNK)); var bcy1 := int(floor(float(bz1 + 1) / CHUNK))
		for cy in range(bcy0, bcy1 + 1):
			for cx in range(bcx0, bcx1 + 1):
				if _chunks.has(Vector2i(cx, cy)):
					_dirty_chunks[Vector2i(cx, cy)] = true
		_mini_dirty = true
		return
	var r := (rad if rad > 0.0 else brush_radius) + 2.0
	var tx0 := int(floor(p.x - r)); var tx1 := int(ceil(p.x + r))
	var tz0 := int(floor(p.z - r)); var tz1 := int(ceil(p.z + r))
	for z in range(maxi(0, tz0), mini(_hg_h - 1, tz1) + 1):
		for x in range(maxi(0, tx0), mini(_hg_w - 1, tx1) + 1):
			_hgrid[z * _hg_w + x] = _height_full(float(x), float(z))
	var cx0 := int(floor(float(tx0 - 1) / CHUNK)); var cx1 := int(floor(float(tx1 + 1) / CHUNK))
	var cy0 := int(floor(float(tz0 - 1) / CHUNK)); var cy1 := int(floor(float(tz1 + 1) / CHUNK))
	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			if _chunks.has(Vector2i(cx, cy)):
				_dirty_chunks[Vector2i(cx, cy)] = true
	_update_water_region(tx0, tz0, tx1, tz1)
	_request_smart_reapply(float(tx0), float(tz0), float(tx1), float(tz1))
	if _grid != null and _grid.visible:
		_grid_dirty = true   # re-drape the slope grid (throttled in _process)
	_mini_dirty = true

## Drive the editor's sun + sky from a time-of-day value (0..1), incl. night, over a full east->west arc.
func _apply_editor_time(t: float) -> void:
	if _sun == null:
		return
	# DayCycle arc drives the sun, so shadows and relief track the time of day.
	var day := DayCycle.day_amount(t)
	DayCycle.aim_sun(_sun, t)
	_sun.light_energy = lerpf(WorldLook.num("sun_night_energy"), WorldLook.num("sun_day_energy"), day)
	_sun.light_volumetric_fog_energy = WorldLook.num("godray")
	_sun.light_color = WorldLook.col("sun_warm").lerp(WorldLook.col("moon"), DayCycle.night_amount(t))
	if _env_e != null:
		_env_e.ambient_light_color = WorldLook.col("ambient_night").lerp(WorldLook.col("ambient_day"), day)
		_env_e.ambient_light_energy = WorldLook.ambient_energy(day)
	if _sky_e != null:
		_sky_e.sky_top_color = Color(0.02, 0.03, 0.07).lerp(Color(0.32, 0.52, 0.85), day)
		_sky_e.sky_horizon_color = Color(0.05, 0.06, 0.10).lerp(Color(0.62, 0.72, 0.86), day)
		_sky_e.ground_horizon_color = Color(0.04, 0.05, 0.09).lerp(Color(0.55, 0.62, 0.70), day)
		_sky_e.ground_bottom_color = Color(0.02, 0.03, 0.05).lerp(Color(0.40, 0.42, 0.42), day)

## A bright outline along the editable world's edge (the 0..GRID boundary).
func _build_edge_line() -> void:
	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true; mat.emission = Color(1.0, 0.35, 0.3)
	mat.albedo_color = Color(1.0, 0.35, 0.3); mat.no_depth_test = true; mat.render_priority = 15
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, mat)
	var g := float(Config.GRID_COLS); var gz := float(Config.GRID_ROWS); var n := 120
	var pts: Array[Vector2] = []
	for i in n + 1: pts.append(Vector2(g * i / n, 0.0))
	for i in n + 1: pts.append(Vector2(g, gz * i / n))
	for i in n + 1: pts.append(Vector2(g * (1.0 - float(i) / n), gz))
	for i in n + 1: pts.append(Vector2(0.0, gz * (1.0 - float(i) / n)))
	for pt in pts:
		im.surface_add_vertex(Vector3(pt.x, _height(pt.x, pt.y) + 0.6, pt.y))
	im.surface_end()
	var mi := MeshInstance3D.new(); mi.mesh = im; add_child(mi)

func _build_water() -> void:
	_water = MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(Config.GRID_COLS * 1.4, Config.GRID_ROWS * 1.4)
	pm.subdivide_width = 175; pm.subdivide_depth = 175
	_water.mesh = pm
	_water.position = Vector3(Config.GRID_COLS * 0.5, Config.WATER_LEVEL, Config.GRID_ROWS * 0.5)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.20, 0.40, 0.58, 0.62)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.08
	m.metallic = 0.0
	_water.material_override = m
	wm_tex = ImageTexture.create_from_image(wm_img)
	_wh_img = Image.create(Config.GRID_COLS, Config.GRID_ROWS, false, Image.FORMAT_RF)
	for z in Config.GRID_ROWS:
		for x in Config.GRID_COLS:
			_wh_img.set_pixel(x, z, Color(_height(x + 0.5, z + 0.5), 0.0, 0.0))
	_wh_tex = ImageTexture.create_from_image(_wh_img)
	add_child(_water)

## Refresh the water-depth texture in an edited region (cheap, brush-sized).
func _update_water_region(tx0: int, tz0: int, tx1: int, tz1: int) -> void:
	if _wh_img == null:
		return
	for z in range(maxi(0, tz0), mini(Config.GRID_ROWS - 1, tz1) + 1):
		for x in range(maxi(0, tx0), mini(Config.GRID_COLS - 1, tx1) + 1):
			_wh_img.set_pixel(x, z, Color(_height(x + 0.5, z + 0.5), 0.0, 0.0))
	_wh_tex.update(_wh_img)

## Yellow wireframe draped over the terrain to read slope/geometry. Toggle G; re-drapes after sculpts (throttled).
func _build_grid() -> void:
	var im := ImmediateMesh.new()
	if _grid_mat == null:
		_grid_mat = StandardMaterial3D.new()
		_grid_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_grid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_grid_mat.albedo_color = Color(1.0, 0.85, 0.1, 0.5)
		_grid_mat.emission_enabled = true
		_grid_mat.emission = Color(1.0, 0.85, 0.1)
		_grid_mat.emission_energy_multiplier = 0.6
	im.surface_begin(Mesh.PRIMITIVE_LINES, _grid_mat)
	var step := 2
	for x in range(0, Config.GRID_COLS + 1, step):
		for z in range(0, Config.GRID_ROWS, step):
			im.surface_add_vertex(Vector3(x, _height(x, z) + 0.06, z))
			im.surface_add_vertex(Vector3(x, _height(x, z + step) + 0.06, z + step))
	for z in range(0, Config.GRID_ROWS + 1, step):
		for x in range(0, Config.GRID_COLS, step):
			im.surface_add_vertex(Vector3(x, _height(x, z) + 0.06, z))
			im.surface_add_vertex(Vector3(x + step, _height(x + step, z) + 0.06, z))
	im.surface_end()
	if _grid == null:
		_grid = MeshInstance3D.new(); add_child(_grid)
	_grid.mesh = im
	_grid.visible = true
	_grid_dirty = false

## Show/hide the slope gridlines — the LAYERS "gridlines" eye and the G key share this.
func _set_grid(on: bool) -> void:
	if on:
		_build_grid()
	elif _grid != null:
		_grid.visible = false

func _toggle_grid() -> void:
	var want := not (_grid != null and _grid.visible)
	_set_grid(want)
	var vis := _grid != null and _grid.visible
	_layer_states["grid"] = vis
	if _grid_btn != null:
		_grid_btn.set_pressed_no_signal(vis)

## Low-cost build mode: strip shadows/SSGI/AO/glow + pull draw distance/tree sway in for speed.
func _set_low_cost(on: bool) -> void:
	_low_cost = on
	_sun.shadow_enabled = not on
	_env_e.ssao_enabled = not on
	get_viewport().use_taa = not on   # TAA is a look-mode luxury; off while building for speed
	if on:
		_env_e.ssil_enabled = false
		_env_e.sdfgi_enabled = false
		_env_e.glow_enabled = false
		WindRig.max_dist = 0.0
	else:
		WorldLook.apply_pipeline(_env_e)
		WindRig.max_dist = (chase_draw_dist if mode == MODE_CHAR else 90.0)
	_update_cam()
	_flash("low-cost mode " + ("ON" if on else "off"))

func _make_ring() -> void:
	_ring = MeshInstance3D.new()
	# A true RING (thin torus), not a disc: a disc + no_depth_test fills the screen when near the camera.
	var tor := TorusMesh.new()
	tor.inner_radius = 0.93; tor.outer_radius = 1.0
	tor.rings = 48; tor.ring_segments = 12
	_ring.mesh = tor
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring_mat.no_depth_test = true
	_ring_mat.render_priority = 20
	_ring_mat.emission_enabled = true
	_ring.material_override = _ring_mat
	_ring.sorting_offset = 4.0
	_ring.visible = false
	add_child(_ring)

# --- UI ---------------------------------------------------------------------

func _build_ui() -> void:
	var ui := CanvasLayer.new(); add_child(ui); _ui_layer = ui
	_fps_lbl = Label.new()
	_fps_lbl.name = "FpsReadout"
	_fps_lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_fps_lbl.offset_left = -160.0; _fps_lbl.offset_top = -96.0
	_fps_lbl.offset_right = -10.0; _fps_lbl.offset_bottom = -8.0
	_fps_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_fps_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps_lbl.add_theme_color_override("font_color", Color(0.86, 0.95, 1.0))
	_fps_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_fps_lbl.add_theme_constant_override("outline_size", 4)
	_fps_lbl.add_theme_font_size_override("font_size", 14)
	ui.add_child(_fps_lbl)
	var th := _studio_theme()
	var vb := _make_dock("tools", "TOOLS", ui, th)
	_panel = _docks["tools"]["panel"]
	_panel.position = Vector2(6, 6)
	_dock_snapshot("tools")
	var grid := GridContainer.new(); grid.columns = 6; vb.add_child(grid)
	var bg := ButtonGroup.new()
	for m in [["Select", MODE_SELECT, "select"], ["Sculpt", MODE_SCULPT, "sculpt"],
			["Material", MODE_BIOME, "material"],
			["Place objects", MODE_PLACE, "place"], ["Erase objects", MODE_ERASE, "erase"],
			["Character (run around!)", MODE_CHAR, "char"]]:
		var bt := Button.new(); bt.toggle_mode = true; bt.button_group = bg
		bt.tooltip_text = str(m[0])
		var ipath := "res://assets/editor_icons/%s.png" % m[2]
		var tex: Texture2D = load(ipath) if ResourceLoader.exists(ipath) else null
		if tex != null:
			bt.icon = tex
			bt.expand_icon = true
			bt.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			bt.custom_minimum_size = Vector2(25, 21)
			var tint: Color = _brush_tint(m[1])
			bt.add_theme_color_override("icon_normal_color", tint)
			bt.add_theme_color_override("icon_hover_color", tint.lightened(0.3))
			bt.add_theme_color_override("icon_pressed_color", Color(1, 1, 1))
		else:
			bt.text = str(m[0])
			bt.custom_minimum_size = Vector2(38, 0)
		bt.pressed.connect(_set_mode.bind(m[1]))
		if m[1] == MODE_SELECT:
			_select_btn = bt
		_mode_btns[m[1]] = bt
		grid.add_child(bt)
	_terrain_menu_btn = MenuButton.new()
	_terrain_menu_btn.custom_minimum_size = Vector2(46, 21)
	_terrain_menu_btn.add_theme_font_size_override("font_size", 10)
	_terrain_menu_btn.text = "Land ▾"
	_terrain_menu_btn.tooltip_text = "Terrain shaping — Flatten / Match height / Set elevation / Noise"
	var tpop := _terrain_menu_btn.get_popup()
	for opt in [["Flatten", MODE_FLATTEN], ["Match height", MODE_MATCH], ["Set elevation", MODE_SETELEV], ["Noise", MODE_NOISE]]:
		tpop.add_item(str(opt[0]), int(opt[1]))
	tpop.id_pressed.connect(func(id): _set_mode(id))
	grid.add_child(_terrain_menu_btn)
	grid.move_child(_terrain_menu_btn, 2)
	_brush_hdr = Label.new()
	_brush_hdr.add_theme_font_size_override("font_size", 11)
	_brush_hdr.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
	_brush_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_brush_hdr)
	biome_box = OptionButton.new()
	for i in Config.GROUND_MATERIALS.size():
		biome_box.add_item(str(Config.GROUND_MATERIALS[i]).capitalize(), i)
		var sw := Image.create(24, 24, false, Image.FORMAT_RGB8); sw.fill(Config.ground_color(i))
		biome_box.set_item_icon(i, ImageTexture.create_from_image(sw))
	biome_box.selected = biome_index
	biome_box.item_selected.connect(func(i): biome_index = i)
	vb.add_child(biome_box)
	_smart_cb = CheckBox.new()
	_smart_cb.text = "smart material (rules)"
	_smart_cb.tooltip_text = "Paint a preset that picks a texture per spot by steepness/height, then bakes it in. Static at runtime."
	_smart_cb.toggled.connect(func(on):
		smart_on = on
		_update_material_ui_visibility()
		_refresh_status())
	vb.add_child(_smart_cb)
	_smart_panel = VBoxContainer.new()
	vb.add_child(_smart_panel)
	_rebuild_smart_panel()
	_select_sub = VBoxContainer.new()
	_select_sub.add_child(_labeled("selection"))
	var srow := HBoxContainer.new(); _select_sub.add_child(srow)
	var sgroup := Button.new(); sgroup.text = "🔒 Group"
	sgroup.tooltip_text = "Lock the selected pieces together so they move as one (or drag a box)"
	sgroup.pressed.connect(func():
		if _sel_members().size() >= 2: _group_selection()
		else: _set_mode(MODE_AREA); _flash("drag a box around the build to GROUP it!"))
	srow.add_child(sgroup)
	_ungroup_btn = Button.new(); _ungroup_btn.text = "🔓 Ungroup"; _ungroup_btn.disabled = true
	_ungroup_btn.tooltip_text = "Split the selected group back into single pieces"
	_ungroup_btn.pressed.connect(_ungroup_sel)
	srow.add_child(_ungroup_btn)
	var grnd := HBoxContainer.new(); _select_sub.add_child(grnd)
	_setground_btn = Button.new(); _setground_btn.text = "⤓ Set ground"; _setground_btn.disabled = true
	_setground_btn.tooltip_text = "Remember the SELECTED item's height above ground as the seat for its type.\nRaise/lower it first with Alt+wheel (e.g. to sink a tree's roots), then click this."
	_setground_btn.pressed.connect(_set_ground_level)
	grnd.add_child(_setground_btn)
	_applyground_btn = Button.new(); _applyground_btn.text = "→ type"; _applyground_btn.disabled = true
	_applyground_btn.tooltip_text = "Seat every placed item of the selected type at that calibrated height"
	_applyground_btn.pressed.connect(_apply_ground_to_type)
	grnd.add_child(_applyground_btn)
	var reseatall_b := Button.new(); reseatall_b.text = "⤓ All→ground"
	reseatall_b.tooltip_text = "Re-seat EVERY placed item on the current terrain — un-bury things after terrain edits"
	reseatall_b.pressed.connect(_reseat_all)
	grnd.add_child(reseatall_b)
	var seldock := _make_dock("select", "SELECTION", ui, th)
	_sel_info = Label.new()
	_sel_info.add_theme_font_size_override("font_size", 12)
	_sel_info.add_theme_color_override("font_color", Color(0.95, 0.92, 0.7))
	_sel_info.text = "(nothing selected)"
	seldock.add_child(_sel_info)
	var sep := HSeparator.new(); seldock.add_child(sep)
	seldock.add_child(_select_sub)
	_select_panel = _docks["select"]["panel"]
	_select_panel.custom_minimum_size = Vector2(210, 132)
	_select_panel.position = Vector2(230, 6)
	_dock_snapshot("select")
	_select_panel.visible = false
	_tile_lbl = _labeled("material tiling"); vb.add_child(_tile_lbl)
	_tile_slider = HSlider.new()
	_tile_slider.min_value = 0.1; _tile_slider.max_value = 2.0; _tile_slider.step = 0.05; _tile_slider.value = 0.5
	vb.add_child(_tile_slider)
	var rvb := _make_dock("settings", "SETTINGS", ui, th)
	_rpanel = _docks["settings"]["panel"]
	_rpanel.anchor_left = 1.0; _rpanel.anchor_right = 1.0
	_rpanel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_rpanel.offset_right = -8.0; _rpanel.offset_top = 8.0
	_rpanel.custom_minimum_size = Vector2(180, 0)
	_dock_snapshot("settings")
	var gbox := GridContainer.new(); gbox.columns = 2; rvb.add_child(gbox)
	var save_btn := Button.new(); save_btn.text = "💾 Save"
	save_btn.pressed.connect(func():
		_save()
		_flash("saved ✔ (%d objects)" % _objects.size(), save_btn))
	gbox.add_child(save_btn)
	var help_btn := Button.new(); help_btn.text = "❔ Controls"
	help_btn.pressed.connect(_show_controls)
	gbox.add_child(help_btn)
	var light_btn := Button.new(); light_btn.text = "💡 Light"
	light_btn.tooltip_text = "Tune sun / sky / mist / ground — saved tweaks ship with the map"
	light_btn.pressed.connect(_toggle_look_panel)
	gbox.add_child(light_btn)
	var info_btn := Button.new(); info_btn.text = "ⓘ Objects"
	info_btn.pressed.connect(_show_counts)
	gbox.add_child(info_btn)
	var lay_btn := Button.new(); lay_btn.text = "⟲ Layout"
	lay_btn.tooltip_text = "Put every panel back in its corner, unfolded"
	lay_btn.pressed.connect(func():
		_reset_layout()
		_flash("layout reset", lay_btn))
	gbox.add_child(lay_btn)
	var dev_btn := Button.new(); dev_btn.text = "⟳ Reload"
	dev_btn.tooltip_text = "Hot-reload the editor's scripts from disk (F5). Saves first."
	dev_btn.pressed.connect(_dev_reload)
	gbox.add_child(dev_btn)
	var lvb := _make_dock("layers", "👁 LAYERS", ui, th)
	var lpanel: PanelContainer = _docks["layers"]["panel"]
	lpanel.position = Vector2(6, 340)
	_dock_snapshot("layers")
	var water_cb := CheckBox.new(); water_cb.text = "water"
	water_cb.toggled.connect(func(on):
		_layer_states["water"] = on
		if _water != null: _water.visible = on)
	lvb.add_child(water_cb)
	_water_btn = water_cb
	water_cb.button_pressed = bool(_layer_states.get("water", true))
	var tmesh_cb := CheckBox.new(); tmesh_cb.text = "terrain"
	tmesh_cb.toggled.connect(func(on):
		_layer_states["terrain"] = on
		for c in _chunks: (_chunks[c] as MeshInstance3D).visible = on)
	lvb.add_child(tmesh_cb)
	tmesh_cb.button_pressed = bool(_layer_states.get("terrain", true))
	var objs_cb := CheckBox.new(); objs_cb.text = "objects"
	objs_cb.toggled.connect(func(on):
		_layer_states["objects"] = on
		_objects_visible = on
		for n in _spawned:
			if is_instance_valid(n): n.visible = on)
	lvb.add_child(objs_cb)
	objs_cb.button_pressed = bool(_layer_states.get("objects", true))
	var grid_cb := CheckBox.new(); grid_cb.text = "gridlines"
	grid_cb.toggled.connect(func(on):
		_layer_states["grid"] = on
		_set_grid(on))
	lvb.add_child(grid_cb)
	_grid_btn = grid_cb
	grid_cb.button_pressed = bool(_layer_states.get("grid", false))
	_build_shaders_section(lvb)
	rvb.add_child(_section("camera"))
	rvb.add_child(_labeled("zoom speed (wheel)"))
	var zs := HSlider.new()
	zs.min_value = 0.2; zs.max_value = 2.5; zs.step = 0.05; zs.value = zoom_speed
	zs.value_changed.connect(func(v): zoom_speed = v)
	rvb.add_child(zs)
	var rip := CheckButton.new(); rip.text = "rotate in place"
	rip.tooltip_text = "Ctrl+wheel a selection:\nON = each piece spins where it stands\nOFF = a multi-selection orbits its anchor\n(a single object always spins in place)"
	rip.button_pressed = _rotate_in_place
	rip.toggled.connect(func(on): _rotate_in_place = on)
	rvb.add_child(rip)
	rvb.add_child(_labeled("orbit cam — draw distance"))
	var odd := HSlider.new()
	odd.min_value = 200.0; odd.max_value = 4000.0; odd.step = 50.0; odd.value = orbit_draw_dist
	odd.value_changed.connect(func(v):
		orbit_draw_dist = v
		if mode != MODE_CHAR: _update_cam())
	rvb.add_child(odd)
	rvb.add_child(_labeled("orbit cam — shadow distance"))
	var osd := HSlider.new()
	osd.min_value = 40.0; osd.max_value = 500.0; osd.step = 10.0; osd.value = orbit_shadow_dist
	osd.value_changed.connect(func(v):
		orbit_shadow_dist = v
		if mode != MODE_CHAR and not _low_cost: _sun.directional_shadow_max_distance = v)
	rvb.add_child(osd)
	rvb.add_child(_labeled("chase cam — draw distance"))
	var cdd := HSlider.new()
	cdd.min_value = 60.0; cdd.max_value = 600.0; cdd.step = 10.0; cdd.value = chase_draw_dist
	cdd.tooltip_text = "How far the Character (chase) cam renders — lower = faster in a dense forest"
	cdd.value_changed.connect(func(v):
		chase_draw_dist = v
		if mode == MODE_CHAR:
			WindRig.max_dist = v
			_update_cam())
	rvb.add_child(cdd)
	rvb.add_child(_labeled("chase cam — shadow distance"))
	var csd := HSlider.new()
	csd.min_value = 20.0; csd.max_value = 300.0; csd.step = 10.0; csd.value = chase_shadow_dist
	csd.value_changed.connect(func(v):
		chase_shadow_dist = v
		if mode == MODE_CHAR and not _low_cost: _sun.directional_shadow_max_distance = v)
	rvb.add_child(csd)
	var lowc := CheckButton.new(); lowc.text = "⚡ low-cost (build)"
	lowc.tooltip_text = "Strip heavy rendering while building: sun shadows, SSIL/SSAO/SDFGI and glow off,\nshorter draw distance, tree sway frozen. Toggle off to see the full look. (F3 = perf stats)"
	lowc.button_pressed = _low_cost
	lowc.toggled.connect(_set_low_cost)
	rvb.add_child(lowc)
	rvb.add_child(HSeparator.new())
	rvb.add_child(_section("map"))
	var mrow := HBoxContainer.new(); rvb.add_child(mrow)
	_open_btn = Button.new(); _open_btn.text = "Open"
	_open_btn.tooltip_text = "Switch which map is being edited"
	_open_btn.pressed.connect(_show_open_menu)
	mrow.add_child(_open_btn)
	_new_btn = Button.new(); _new_btn.text = "New"
	_new_btn.tooltip_text = "Create a fresh, blank map"
	_new_btn.pressed.connect(_show_new_dialog)
	mrow.add_child(_new_btn)
	_map_lbl = _labeled("map: " + _map_name); rvb.add_child(_map_lbl)
	rvb.add_child(HSeparator.new())
	rvb.add_child(_section("brush & time"))
	rvb.add_child(_labeled("brush opacity"))
	var op := HSlider.new()
	op.min_value = 0.0; op.max_value = 1.0; op.step = 0.05; op.value = brush_opacity
	op.value_changed.connect(func(v): brush_opacity = v)
	rvb.add_child(op)
	rvb.add_child(_labeled("time of day (night ↔ noon ↔ night)"))
	var tod := HSlider.new()
	tod.min_value = 0.0; tod.max_value = 1.0; tod.step = 0.01; tod.value = _editor_tod
	tod.value_changed.connect(func(v): _editor_tod = v; _apply_editor_time(v))
	rvb.add_child(tod)
	_apply_editor_time(_editor_tod)
	_se_lbl = _labeled("set-elevation target"); vb.add_child(_se_lbl)
	_se = SpinBox.new()
	_se.min_value = HM_MIN; _se.max_value = HM_MAX; _se.step = 0.5; _se.value = target_elev
	_se.value_changed.connect(func(v): target_elev = v)
	vb.add_child(_se)
	filter = LineEdit.new(); filter.placeholder_text = "filter…"
	filter.text_changed.connect(func(_t): _fill_tree())
	vb.add_child(filter)
	tree_ui = Tree.new(); tree_ui.custom_minimum_size = Vector2(220, 300)
	tree_ui.hide_root = true; tree_ui.focus_mode = Control.FOCUS_NONE
	tree_ui.item_selected.connect(_on_item_selected)
	vb.add_child(tree_ui)
	status = Label.new(); status.autowrap_mode = TextServer.AUTOWRAP_WORD
	vb.add_child(status)
	_fill_tree()
	_make_sel_ring()
	_build_minimap(ui, th)
	var rchip := PanelContainer.new()
	rchip.theme = th
	rchip.anchor_left = 0.5; rchip.anchor_right = 0.5
	rchip.anchor_top = 1.0; rchip.anchor_bottom = 1.0
	rchip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	rchip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	rchip.offset_bottom = -8.0
	rchip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(rchip)
	_readout_lbl = Label.new()
	_readout_lbl.add_theme_font_size_override("font_size", 11)
	_readout_lbl.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	rchip.add_child(_readout_lbl)
	_readout_lbl.visibility_changed.connect(func(): rchip.visible = _readout_lbl.visible)
	_load_ui_layout.call_deferred()
	if _select_btn != null: _select_btn.set_pressed_no_signal(true)
	_set_mode(MODE_SELECT)

func _set_mode_reset_rot() -> void:
	_place_rot = 0.0
	_place_rot_explicit = false

## Mode switch via keyboard: also press the matching icon button.
func _hotkey_mode(m: int) -> void:
	if _mode_btns.has(m):
		(_mode_btns[m] as Button).set_pressed_no_signal(true)
	_set_mode(m)

const _MODE_CURSOR := {MODE_SELECT: "select", MODE_SCULPT: "sculpt",
	MODE_FLATTEN: "flatten", MODE_MATCH: "match", MODE_SETELEV: "setelev",
	MODE_NOISE: "noise", MODE_BIOME: "material",
	MODE_ERASE: "erase"}
var _cursor_cache := {}

func _apply_cursor(m: int) -> void:
	if not _MODE_CURSOR.has(m):
		Input.set_custom_mouse_cursor(null)
		return
	var cname: String = _MODE_CURSOR[m]
	if not _cursor_cache.has(cname):
		var tex: Texture2D = load("res://assets/editor_icons/%s.png" % cname)
		if tex == null:
			_cursor_cache[cname] = null
		else:
			var img := tex.get_image()
			img.decompress()
			img.resize(26, 26, Image.INTERPOLATE_LANCZOS)
			_cursor_cache[cname] = ImageTexture.create_from_image(img)
	Input.set_custom_mouse_cursor(_cursor_cache[cname], Input.CURSOR_ARROW, Vector2(13, 13))

## Show the OS arrow while the pointer is over a panel; restore the brush cursor off them.
func _update_cursor_hover() -> void:
	var over := _over_ui()
	if over == _cursor_over_ui:
		return
	_cursor_over_ui = over
	if over:
		Input.set_custom_mouse_cursor(null)
	else:
		_apply_cursor(mode)

func _set_mode(m: int) -> void:
	if m != mode: _set_mode_reset_rot()
	var was_char := mode == MODE_CHAR
	mode = m
	_apply_cursor(m)
	_cursor_over_ui = false
	if _brush_hdr != null:
		_brush_hdr.text = "▸ " + str(MODE_NAMES.get(m, "?"))
	if _terrain_menu_btn != null:
		var tn := {MODE_FLATTEN: "Flatten", MODE_MATCH: "Match", MODE_SETELEV: "Set-lvl", MODE_NOISE: "Noise"}
		_terrain_menu_btn.text = (str(tn[m]) + " ▾") if tn.has(m) else "Land ▾"
		_terrain_menu_btn.modulate = Color(1.35, 1.15, 0.6) if tn.has(m) else Color.WHITE
	var place := m == MODE_PLACE
	tree_ui.visible = place; filter.visible = place
	_update_material_ui_visibility()
	if _select_panel != null:
		_select_panel.visible = m == MODE_SELECT
	_tile_lbl.visible = m == MODE_BIOME; _tile_slider.visible = m == MODE_BIOME
	_se.visible = m == MODE_SETELEV; _se_lbl.visible = m == MODE_SETELEV
	if m != MODE_SELECT:
		_deselect()
	if m == MODE_CHAR and not was_char:
		_char_enter()
	elif was_char and m != MODE_CHAR:
		_char_exit()
	_refresh_status()

# Selection glow: a translucent emissive material_overlay over every mesh, so textures show through but read "lit".
func _make_sel_ring() -> void:
	_hi_mat = StandardMaterial3D.new()
	_hi_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hi_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hi_mat.albedo_color = Color(0.3, 1.0, 0.5, 0.6)
	_hi_mat.emission_enabled = true
	_hi_mat.emission = Color(0.3, 1.0, 0.5)
	_hi_mat.emission_energy_multiplier = 4.0
	_hi_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

# Collect every GeometryInstance3D (MeshInstance3D + CSG shapes) — that's what carries material_overlay.
func _meshes_of(n: Node, out: Array) -> void:
	if n is GeometryInstance3D: out.append(n)
	for c in n.get_children():
		_meshes_of(c, out)

func _highlight(n: Node3D, on: bool) -> void:
	if n == null or not is_instance_valid(n): return
	var ms: Array = []
	_meshes_of(n, ms)
	for mi in ms:
		mi.material_overlay = _hi_mat if on else null

func _deselect() -> void:
	_sel_idx = -1
	_sel = []
	_dragging_sel = false
	for n in _hi_nodes: _highlight(n, false)
	_hi_nodes = []
	if _ungroup_btn != null: _ungroup_btn.disabled = true

## Everything the current selection OPERATES on: each selected index expanded
func _sel_members() -> Array:
	var gids := {}
	var out := {}
	for s in _sel:
		var i := int(s)
		if i < 0 or i >= _objects.size(): continue
		out[i] = true
		var gid := int(_objects[i].get("group", 0))
		if gid != 0: gids[gid] = true
	if not gids.is_empty():
		for i in _objects.size():
			if gids.has(int(_objects[i].get("group", 0))): out[i] = true
	var arr := out.keys()
	arr.sort()
	return arr

## Refresh glow + Ungroup button + status after any selection change.
func _after_sel_change() -> void:
	_update_sel_ring()
	var members := _sel_members()
	var grouped := false
	for i in members:
		if int(_objects[i].get("group", 0)) != 0: grouped = true; break
	if _ungroup_btn != null: _ungroup_btn.disabled = not grouped
	var has_sel := not members.is_empty()
	if _setground_btn != null: _setground_btn.disabled = not has_sel
	if _applyground_btn != null: _applyground_btn.disabled = not has_sel
	if members.is_empty():
		_refresh_status("selected nothing")
	elif members.size() == 1:
		_refresh_status("selected %s" % str(_objects[members[0]].get("type", _objects[members[0]].get("kind", "?"))))
	elif grouped:
		_refresh_status("selected GROUP 🔒 (%d pieces — moves as one)" % members.size())
	else:
		_refresh_status("selected %d items" % members.size())

# Keep the glow attached to the selection — ALL members of a group glow together.
func _update_sel_ring() -> void:
	var want: Array = []
	for i in _sel_members():
		if i < _spawned.size() and is_instance_valid(_spawned[i]):
			want.append(_spawned[i])
	if want == _hi_nodes: return
	for n in _hi_nodes: _highlight(n, false)
	_hi_nodes = want
	for n in _hi_nodes: _highlight(n, true)

## Index of the nearest placed object to p (generous radius so big set-pieces are easy to grab), or -1.
func _nearest_obj(p: Vector3) -> int:
	var best := -1; var bd := 64.0
	for i in _spawned.size():
		var n: Node3D = _spawned[i]
		if not is_instance_valid(n) or not n.visible: continue
		var d := Vector2(n.position.x - p.x, n.position.z - p.z).length_squared()
		if d < bd: bd = d; best = i
	return best

## Left-click in select mode: first click selects, clicking the selected item again arms dragging
func _select_click(p: Vector3, additive := false) -> void:
	var hit := _pick_object(p)
	if additive:
		if hit < 0: return
		if hit in _sel:
			_sel.erase(hit)
			if _sel_idx == hit: _sel_idx = int(_sel[0]) if not _sel.is_empty() else -1
		else:
			_sel.append(hit)
			_sel_idx = hit
		_dragging_sel = false
		_after_sel_change()
		return
	if hit >= 0 and hit == _sel_idx and hit in _sel:
		_dragging_sel = true
		_sel_hold = 0.0
		return
	_sel = [hit] if hit >= 0 else []
	_sel_idx = hit
	_dragging_sel = false
	_after_sel_change()

## Precise pick: ray vs every object's AABB (needed for stacked blocks), else nearest-to-p.
func _pick_object(p: Vector3) -> int:
	var mp := get_viewport().get_mouse_position()
	var o := cam.project_ray_origin(mp)
	var dir := cam.project_ray_normal(mp)
	var best := -1
	var bd := 1e18
	for i in _spawned.size():
		var n: Node3D = _spawned[i]
		if not is_instance_valid(n) or not n.visible: continue
		var ab := _aabb(n)
		if ab.size == Vector3.ZERO: continue
		var inv := n.global_transform.affine_inverse()
		var hit := _ray_aabb(inv * o, inv.basis * dir, ab.position, ab.position + ab.size)
		if hit.is_empty(): continue
		var wp: Vector3 = n.global_transform * (hit["pos"] as Vector3)
		var d := o.distance_to(wp)
		if d < bd: bd = d; best = i
	var near := _nearest_obj(p)
	var dnear := 1e9
	if near >= 0:
		dnear = Vector2(_spawned[near].position.x - p.x, _spawned[near].position.z - p.z).length()
	if _sel_idx >= 0 and _sel_idx < _spawned.size() and is_instance_valid(_spawned[_sel_idx]):
		var sp: Node3D = _spawned[_sel_idx]
		var dsel := Vector2(sp.position.x - p.x, sp.position.z - p.z).length()
		if dsel <= 2.5 and dsel <= dnear + 0.6:
			return _sel_idx
	var on_water := p.y <= Config.WATER_LEVEL + 0.1
	if best >= 0 and Vector2(_spawned[best].position.x - p.x, _spawned[best].position.z - p.z).length() <= 2.5:
		return best
	# Snap to nearest within a few tiles, but a click on open water must NOT grab a tree on dry land.
	if near >= 0 and dnear <= 3.0 and not (on_water and _spawned[near].position.y > Config.WATER_LEVEL + 0.1):
		return near
	if on_water:
		return -1
	return best

## Shift/Ctrl drag-box released: add everything inside the rect to the selection.
func _selbox_commit(a: Vector3, b: Vector3) -> void:
	var x0 := minf(a.x, b.x); var x1 := maxf(a.x, b.x)
	var z0 := minf(a.z, b.z); var z1 := maxf(a.z, b.z)
	var added := 0
	for i in _spawned.size():
		var n: Node3D = _spawned[i]
		if not is_instance_valid(n) or not n.visible: continue
		if n.position.x < x0 or n.position.x > x1 or n.position.z < z0 or n.position.z > z1: continue
		if not (i in _sel):
			_sel.append(i); added += 1
			_sel_idx = i
	_after_sel_change()
	if added > 0: _flash("+%d selected" % added)

## Slide the selected object to a new spot (keeps rotation + elevation). A GROUP moves rigidly:
func _move_sel_to(p: Vector3) -> void:
	if _sel_idx < 0 or _sel_idx >= _objects.size(): return
	var e: Dictionary = _objects[_sel_idx]
	var oldx := float(e["x"]); var oldz := float(e["z"])
	var ax := int(floor(p.x)); var az := int(floor(p.z))
	var newx := ax + 0.5; var newz := az + 0.5
	var members := _sel_members()
	var dx := newx - oldx; var dz := newz - oldz
	if dx == 0.0 and dz == 0.0: return
	for i in members:
		var m: Dictionary = _objects[i]
		for t in _obj_tiles[i]: _occupied.erase(t)
		m["x"] = float(m["x"]) + dx
		m["z"] = float(m["z"]) + dz
		_obj_tiles[i] = _tiles_for(m)
		for t in _obj_tiles[i]: _occupied[t] = true
		_position_obj(i)
	_dirty = true

## (Re)place the spawned node at its entry's x/z, terrain height + its y_off elevation.
func _position_obj(i: int) -> void:
	var e: Dictionary = _objects[i]
	var n: Node3D = _spawned[i]
	if not is_instance_valid(n): return
	var x := float(e["x"]); var z := float(e["z"])
	if str(e.get("kind", "")) in ["block", "decor"]:
		n.position = Vector3(x, float(e.get("y", _height(x, z))), z)
		n.rotation.y = float(e.get("rot", 0.0))
		_update_sel_ring()
		return
	var gy := _height(x, z) + float(e.get("y_off", 0.0))
	if str(e.get("kind", "")) == "prop":
		gy -= _aabb(n).position.y
	n.position = Vector3(x, gy, z)
	n.rotation.y = float(e.get("rot", 0.0))
	_update_sel_ring()

func _rotate_sel(delta_rad: float) -> void:
	if _sel_idx < 0: return
	var members := _sel_members()
	if members.size() > 1:
		var c := Vector2(float(_objects[_sel_idx]["x"]), float(_objects[_sel_idx]["z"]))
		for i in members:
			var m: Dictionary = _objects[i]
			if not _rotate_in_place:
				for t in _obj_tiles[i]: _occupied.erase(t)
				var off := (Vector2(float(m["x"]), float(m["z"])) - c).rotated(delta_rad)
				m["x"] = c.x + off.x; m["z"] = c.y + off.y
				_obj_tiles[i] = _tiles_for(m)
				for t in _obj_tiles[i]: _occupied[t] = true
			m["rot"] = float(m.get("rot", 0.0)) + delta_rad
			_position_obj(i)
		_dirty = true
		_refresh_status("rotated group %s" % ("in place" if _rotate_in_place else "around anchor"))
		return
	_objects[_sel_idx]["rot"] = float(_objects[_sel_idx].get("rot", 0.0)) + delta_rad
	_position_obj(_sel_idx); _dirty = true
	_refresh_status("rotated")

func _elevate_sel(dy: float) -> void:
	if _sel_idx < 0: return
	for i in _sel_members():
		var m: Dictionary = _objects[i]
		if str(m.get("kind", "")) in ["block", "decor"] and m.has("y"):
			m["y"] = float(m["y"]) + dy
		else:
			m["y_off"] = clampf(float(m.get("y_off", 0.0)) + dy, -30.0, 60.0)
		_position_obj(i)
	_dirty = true
	_refresh_status("elevated")

## Re-seat the selection flush on the ground (y_off → 0). Kit pieces (blocks/
func _reseat_sel() -> void:
	var members := _sel_members()
	if members.is_empty(): return
	var done := 0
	for i in members:
		if str(_objects[i].get("kind", "")) in ["block", "decor"]: continue
		_objects[i]["y_off"] = 0.0
		_position_obj(i)
		done += 1
	_dirty = true
	_refresh_status("re-seated %d to ground" % done if done > 0 else "kit pieces keep their height (stacking)")

# Ground seating: calibrate a per-type height-above-ground, then apply / un-bury.

## Seat key for an entry: its model, or for model-less nodes (rocks, ore) its type.
func _off_key(e: Dictionary) -> String:
	var m := str(e.get("model", ""))
	return m if m != "" else str(e.get("type", e.get("kind", "?")))

func _load_ground_off() -> void:
	if not FileAccess.file_exists(GROUND_OFF_FILE):
		return
	var f := FileAccess.open(GROUND_OFF_FILE, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		_ground_off = d

func _save_ground_off() -> void:
	var f := FileAccess.open(GROUND_OFF_FILE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_ground_off, "  "))

## Remember the SELECTED item's current height-above-ground (its y_off) as the normal seat for its
func _set_ground_level() -> void:
	if _sel_idx < 0:
		return
	var e: Dictionary = _objects[_sel_idx]
	if str(e.get("kind", "")) in ["block", "decor"]:
		_flash("kit pieces stack at an absolute height — no ground seat")
		return
	var key := _off_key(e)
	var off := float(e.get("y_off", 0.0))
	_ground_off[key] = off
	_save_ground_off()
	_refresh_status("ground seat for %s = %+.2f m" % [key, off])
	_flash("seat for %s set to %+.2f m — use → type to apply to the rest" % [key.get_file(), off])

## Seat every placed item of the selected item's type at that type's calibrated ground offset.
func _apply_ground_to_type() -> void:
	if _sel_idx < 0:
		return
	var key := _off_key(_objects[_sel_idx])
	var off: float = float(_ground_off.get(key, 0.0))
	var n := 0
	for i in _objects.size():
		if str(_objects[i].get("kind", "")) in ["block", "decor"]:
			continue
		if _off_key(_objects[i]) != key:
			continue
		_objects[i]["y_off"] = off
		_position_obj(i)
		n += 1
	_dirty = true
	_refresh_status("seated %d x %s at %+.2f m" % [n, key, off])
	_flash("applied seat to %d x %s" % [n, key.get_file()])

## Re-seat EVERY placed item on the current terrain (un-bury after terrain edits); kit pieces keep their stack.
func _reseat_all() -> void:
	var n := 0
	for i in _objects.size():
		if str(_objects[i].get("kind", "")) in ["block", "decor"]:
			continue
		_position_obj(i)
		n += 1
	_dirty = true
	_refresh_status("re-seated %d items on the ground" % n)
	_flash("re-seated %d items to the ground" % n)

func _fill_tree() -> void:
	tree_ui.clear()
	var root := tree_ui.create_item()
	var q := filter.text.to_lower()
	var boxes := tree_ui.create_item(root)
	boxes.set_text(0, "Boxes"); boxes.set_selectable(0, false)
	for bc in BOX_COLORS:
		var bname: String = str(bc[0])
		if q == "" or q in bname.to_lower():
			_leaf(boxes, bname + " box", {"kind": "box", "color": (bc[1] as Color).to_html(false)})
	_leaf(root, "★ Start location", {"kind": "start"})

func _leaf(parent: TreeItem, label: String, meta: Dictionary) -> TreeItem:
	var it := tree_ui.create_item(parent); it.set_text(0, label); it.set_metadata(0, meta); return it

func _labeled(text: String) -> Label:
	var l := Label.new(); l.text = text
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", Color(0.72, 0.75, 0.82))
	return l

const UI_CFG := "user://editor_ui.cfg"
const ACCENT := Color(0.88, 0.72, 0.35)
var _docks := {}
var _dock_drag := ""
var _dock_grab := Vector2.ZERO
var _dock_defaults := {}

## 9-slice vertical-gradient stylebox (StyleBoxFlat can't gradient): a tiny faded image with a 1px border, corners knocked out.
func _grad_box(top: Color, bottom: Color, border: Color) -> StyleBoxTexture:
	var s := 16
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		var c := top.lerp(bottom, float(y) / float(s - 1))
		for x in s:
			img.set_pixel(x, y, c)
	for i in s:
		img.set_pixel(i, 0, border); img.set_pixel(i, s - 1, border)
		img.set_pixel(0, i, border); img.set_pixel(s - 1, i, border)
	for cnr in [Vector2i(0, 0), Vector2i(s - 1, 0), Vector2i(0, s - 1), Vector2i(s - 1, s - 1)]:
		img.set_pixel(cnr.x, cnr.y, Color(0, 0, 0, 0))
	var sb := StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(img)
	sb.set_texture_margin_all(4.0)
	sb.set_content_margin_all(3)
	sb.content_margin_left = 7; sb.content_margin_right = 7
	return sb

## A distinct icon colour per brush so the tool row reads at a glance.
func _brush_tint(mode: int) -> Color:
	match mode:
		MODE_SELECT: return Color(0.70, 1.00, 0.72)
		MODE_SCULPT: return Color(0.90, 0.66, 0.45)
		MODE_FLATTEN: return Color(0.86, 0.78, 0.52)
		MODE_MATCH: return Color(0.62, 0.86, 0.74)
		MODE_SETELEV: return Color(0.74, 0.82, 0.60)
		MODE_NOISE: return Color(0.74, 0.68, 0.92)
		MODE_BIOME: return Color(0.58, 0.88, 0.50)
		MODE_PLACE: return Color(1.00, 0.82, 0.42)
		MODE_ERASE: return Color(1.00, 0.52, 0.50)
		MODE_CHAR: return Color(0.80, 0.62, 1.00)
	return Color(0.85, 0.88, 0.95)

func _studio_theme() -> Theme:
	var th := Theme.new()
	var thin := FontVariation.new()
	thin.base_font = ThemeDB.fallback_font
	thin.variation_embolden = 0.0
	th.default_font = thin
	th.default_font_size = 12
	th.set_font_size("font_size", "Tree", 13)
	th.set_constant("inner_item_margin_top", "Tree", 1)
	th.set_constant("inner_item_margin_bottom", "Tree", 1)
	th.set_constant("v_separation", "Tree", 2)
	var pan := StyleBoxFlat.new()
	pan.bg_color = Color(0.045, 0.055, 0.085, 0.93)
	pan.border_color = Color(0.5, 0.58, 0.75, 0.22)
	pan.set_border_width_all(1)
	pan.set_corner_radius_all(6)
	pan.set_content_margin_all(4)
	th.set_stylebox("panel", "PanelContainer", pan)
	var bn := _grad_box(Color(0.19, 0.22, 0.30, 0.95), Color(0.10, 0.115, 0.16, 0.92),
		Color(0.5, 0.58, 0.75, 0.20))
	var bh := _grad_box(Color(0.26, 0.30, 0.40, 0.97), Color(0.14, 0.16, 0.22, 0.94),
		Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.55))
	var bp := _grad_box(Color(0.46, 0.37, 0.17, 0.97), Color(0.24, 0.19, 0.10, 0.95), ACCENT)
	for sb in [bn, bh, bp]:
		sb.set_content_margin_all(2)
		sb.content_margin_left = 5; sb.content_margin_right = 5
	th.set_stylebox("normal", "Button", bn)
	th.set_stylebox("hover", "Button", bh)
	th.set_stylebox("pressed", "Button", bp)
	th.set_stylebox("hover_pressed", "Button", bp)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", Color(0.86, 0.88, 0.93))
	th.set_color("font_hover_color", "Button", Color(0.95, 0.96, 1.0))
	th.set_color("font_pressed_color", "Button", ACCENT.lightened(0.25))
	var le := StyleBoxFlat.new()
	le.bg_color = Color(0.08, 0.09, 0.13, 0.95)
	le.set_corner_radius_all(4)
	le.set_content_margin_all(3)
	le.content_margin_left = 7; le.content_margin_right = 7
	th.set_stylebox("normal", "LineEdit", le)
	var tip := pan.duplicate() as StyleBoxFlat
	tip.bg_color = Color(0.07, 0.08, 0.12, 0.97)
	tip.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.4)
	tip.set_content_margin_all(5)
	th.set_stylebox("panel", "TooltipPanel", tip)
	th.set_color("font_color", "TooltipLabel", Color(0.88, 0.9, 0.95))
	th.set_font_size("font_size", "TooltipLabel", 10)
	th.set_stylebox("normal", "OptionButton", bn.duplicate())
	th.set_stylebox("hover", "OptionButton", bh.duplicate())
	th.set_stylebox("pressed", "OptionButton", bp.duplicate())
	th.set_stylebox("normal", "CheckBox", bn.duplicate())
	th.set_stylebox("hover", "CheckBox", bh.duplicate())
	th.set_stylebox("pressed", "CheckBox", bn.duplicate())
	th.set_stylebox("hover_pressed", "CheckBox", bh.duplicate())
	th.set_color("font_pressed_color", "CheckBox", Color(0.86, 0.88, 0.93))
	th.set_color("font_hover_pressed_color", "CheckBox", Color(0.95, 0.96, 1.0))
	return th

## Collapsible subsection with a ▾ header and a per-section color band. Returns the content box — add children to IT.
func _fold_section(parent: Control, title: String, start_open := true,
		tint := Color(0.30, 0.34, 0.46)) -> VBoxContainer:
	var head := Button.new()
	head.alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.add_theme_font_size_override("font_size", 9)
	head.add_theme_color_override("font_color", Color(0.93, 0.94, 0.97))
	head.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	var glow := Color(minf(tint.r * 2.0 + 0.2, 1.0), minf(tint.g * 2.0 + 0.2, 1.0),
		minf(tint.b * 2.0 + 0.2, 1.0), 0.95)
	var band := _grad_box(Color(tint.r * 1.35, tint.g * 1.35, tint.b * 1.35, 0.95),
		Color(tint.r * 0.65, tint.g * 0.65, tint.b * 0.65, 0.9), glow)
	var band_h := _grad_box(Color(tint.r * 1.7, tint.g * 1.7, tint.b * 1.7, 1.0),
		Color(tint.r * 0.85, tint.g * 0.85, tint.b * 0.85, 0.95), Color(1, 1, 1, 0.9))
	head.add_theme_stylebox_override("normal", band)
	head.add_theme_stylebox_override("hover", band_h)
	head.add_theme_stylebox_override("pressed", band)
	parent.add_child(head)
	var box := VBoxContainer.new()
	box.visible = start_open
	parent.add_child(box)
	var retitle := func():
		head.text = ("▾ " if box.visible else "▸ ") + title.to_upper()
	retitle.call()
	head.pressed.connect(func():
		box.visible = not box.visible
		retitle.call())
	return box

## Gold small-caps section header (replaces ad-hoc separators/labels).
func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_size_override("font_size", 9)
	l.add_theme_color_override("font_color", Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.8))
	return l

func _make_dock(id: String, title: String, ui: CanvasLayer, th: Theme) -> VBoxContainer:
	var p := PanelContainer.new()
	p.theme = th
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(p)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 1)
	p.add_child(outer)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 2)
	outer.add_child(bar)
	var grip := Label.new()
	grip.text = "⠿ " + title
	grip.add_theme_font_size_override("font_size", 10)
	grip.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8))
	grip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grip.mouse_filter = Control.MOUSE_FILTER_STOP
	grip.mouse_default_cursor_shape = Control.CURSOR_MOVE
	grip.tooltip_text = "drag to move"
	bar.add_child(grip)
	var fold := Button.new()
	fold.text = "▾"
	fold.flat = true
	fold.custom_minimum_size = Vector2(20, 14)
	fold.tooltip_text = "fold / unfold"
	bar.add_child(fold)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 2)
	outer.add_child(content)
	fold.pressed.connect(func():
		content.visible = not content.visible
		fold.text = "▾" if content.visible else "▸"
		p.reset_size()
		_save_ui_layout())
	grip.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				_dock_drag = id
				_dock_grab = p.get_global_mouse_position() - p.global_position
			elif _dock_drag == id:
				_dock_drag = ""
				_save_ui_layout())
	_docks[id] = {"panel": p, "content": content, "fold": fold}
	return content

## Dragging runs from _process (gui_input motion stops once the cursor outruns the grip), following the global mouse.
func _dock_drag_tick() -> void:
	if _dock_drag.is_empty():
		return
	var p: PanelContainer = _docks[_dock_drag]["panel"]
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_dock_drag = ""
		p.modulate.a = 1.0
		_save_ui_layout()
		return
	p.modulate.a = 0.8
	p.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var vp := get_viewport().get_visible_rect().size
	var pos := get_viewport().get_mouse_position() - _dock_grab
	p.position = pos.clamp(Vector2(-p.size.x + 60, 0), vp - Vector2(60, 20))

## Snapshot this dock's factory placement so ⟲ Reset layout can restore it.
func _dock_snapshot(id: String) -> void:
	var p: PanelContainer = _docks[id]["panel"]
	_dock_defaults[id] = {
		"al": p.anchor_left, "at": p.anchor_top, "ar": p.anchor_right, "ab": p.anchor_bottom,
		"ol": p.offset_left, "ot": p.offset_top, "orr": p.offset_right, "ob": p.offset_bottom,
		"gh": p.grow_horizontal, "gv": p.grow_vertical, "pos": p.position}

func _reset_layout() -> void:
	for id in _docks:
		if not _dock_defaults.has(id):
			continue
		var p: PanelContainer = _docks[id]["panel"]
		var d: Dictionary = _dock_defaults[id]
		p.anchor_left = d["al"]; p.anchor_top = d["at"]
		p.anchor_right = d["ar"]; p.anchor_bottom = d["ab"]
		p.offset_left = d["ol"]; p.offset_top = d["ot"]
		p.offset_right = d["orr"]; p.offset_bottom = d["ob"]
		p.grow_horizontal = d["gh"]; p.grow_vertical = d["gv"]
		if d["al"] == 0.0 and d["ar"] == 0.0 and d["at"] == 0.0 and d["ab"] == 0.0:
			p.position = d["pos"]
		(_docks[id]["content"] as Control).visible = true
		(_docks[id]["fold"] as Button).text = "▾"
		p.reset_size()
	_save_ui_layout()
	_flash("layout reset ⟲")

func _save_ui_layout() -> void:
	var cf := ConfigFile.new()
	for id in _docks:
		var p: PanelContainer = _docks[id]["panel"]
		cf.set_value(id, "moved", p.anchor_left == 0.0 and p.anchor_top == 0.0 and p.anchor_right == 0.0)
		cf.set_value(id, "pos", p.position)
		cf.set_value(id, "folded", not (_docks[id]["content"] as Control).visible)
	cf.save(UI_CFG)

func _load_ui_layout() -> void:
	var cf := ConfigFile.new()
	if cf.load(UI_CFG) != OK:
		_flash("tip: drag the ⠿ bars to rearrange panels · ▾ folds them")
		_save_ui_layout()
		return
	var vp := get_viewport().get_visible_rect().size
	for id in _docks:
		if not cf.has_section(id):
			continue
		var p: PanelContainer = _docks[id]["panel"]
		if bool(cf.get_value(id, "moved", false)):
			p.set_anchors_preset(Control.PRESET_TOP_LEFT)
			p.position = (cf.get_value(id, "pos", p.position) as Vector2)\
				.clamp(Vector2(-200, 0), vp - Vector2(60, 20))
		if bool(cf.get_value(id, "folded", false)):
			(_docks[id]["content"] as Control).visible = false
			(_docks[id]["fold"] as Button).text = "▸"
			p.reset_size()

## Feedback toast chip. No anchor → top-center; with an anchor control it docks beside that control.
func _flash(text: String, anchor: Control = null) -> void:
	if _ui_layer == null: return
	if _toast_panel == null:
		_toast_panel = PanelContainer.new()
		# Saturated amber so feedback reads as an event, not another menu.
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.85, 0.58, 0.10, 0.97)
		sb.border_color = Color(1.0, 0.88, 0.45)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(6)
		sb.set_content_margin_all(8)
		sb.content_margin_left = 14; sb.content_margin_right = 14
		_toast_panel.add_theme_stylebox_override("panel", sb)
		_toast_panel.z_index = 120
		_toast_lbl = Label.new()
		_toast_lbl.add_theme_font_size_override("font_size", 13)
		_toast_lbl.add_theme_color_override("font_color", Color(0.13, 0.09, 0.02))
		_toast_panel.add_child(_toast_lbl)
		_ui_layer.add_child(_toast_panel)
	_toast_lbl.text = text
	_toast_panel.visible = true
	_toast_panel.modulate.a = 1.0
	_toast_panel.reset_size()
	var sz := _toast_panel.get_combined_minimum_size()
	var vp := get_viewport().get_visible_rect().size
	var pos := Vector2((vp.x - sz.x) * 0.5, 14.0)
	if anchor != null and is_instance_valid(anchor):
		var r := anchor.get_global_rect()
		pos = Vector2(r.position.x - sz.x - 10.0, r.position.y + (r.size.y - sz.y) * 0.5)
		if pos.x < 8.0:
			pos.x = r.end.x + 10.0
	pos.x = clampf(pos.x, 8.0, vp.x - sz.x - 8.0)
	pos.y = clampf(pos.y, 8.0, vp.y - sz.y - 8.0)
	_toast_panel.position = pos
	_flash_t = 1.6

func _selected() -> Dictionary:
	var it := tree_ui.get_selected()
	if it == null: return {}
	var m = it.get_metadata(0)
	return m if m is Dictionary else {}

func _on_item_selected() -> void:
	_refresh_status()

# --- terrain brush ----------------------------------------------------------

# Brush ops take params EXPLICITLY (negative = use the local brush size/strength).
func _brush_px(p: Vector3, rad: float) -> Array:
	var cu := p.x / float(Config.GRID_COLS) * float(_hm_w - 1)
	var cv := p.z / float(Config.GRID_ROWS) * float(_hm_h - 1)
	var rpx := rad / float(Config.GRID_COLS) * float(_hm_w - 1)
	return [cu, cv, rpx]

## Apply a brush op.
func _brush(op: String, p: Vector3, act: int, extra: float = 0.0) -> void:
	var seed_v := randi()   # one seed per op so a noise stroke stays internally consistent
	_apply_brush(op, p, act, brush_radius, brush_strength, extra, seed_v)

func _apply_brush(op: String, p: Vector3, act: int, rad: float, strn: int, extra: float, seed_v: int) -> void:
	match op:
		"sculpt":  _stamp(p, float(act), rad, strn)
		"flatten": _flatten(p, rad, strn)
		"noise":   _noise(p, rad, strn, seed_v)
		"match":   _match_brush(p, rad, strn)
		"setelev": _push_to_elev(p, extra, rad, strn)
		"erase":   _erase_area(p, rad)
		"biome":   _paint_biome(p, int(extra), rad)
		"smart":   _paint_smart(p, int(extra), rad)

## Roughen the terrain: add random per-tile bumps within the brush (feathered).
func _noise(p: Vector3, rad: float = -1.0, strn: int = -1, seed_v: int = -1) -> void:
	if rad < 0.0: rad = brush_radius
	if strn < 0: strn = brush_strength
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v if seed_v >= 0 else randi()
	var b := _brush_px(p, rad); var cu = b[0]; var cv = b[1]; var rpx = b[2]
	var amp := _str_amp(strn) * STRENGTH_UNIT * 8.0
	for yy in range(maxi(0, int(cv - rpx)), mini(_hm_h - 1, int(cv + rpx)) + 1):
		for xx in range(maxi(0, int(cu - rpx)), mini(_hm_w - 1, int(cu + rpx)) + 1):
			var d := Vector2(xx - cu, yy - cv).length()
			if d > rpx: continue
			var fall := _falloff(d, rpx)
			var nv := clampf(hm_img.get_pixel(xx, yy).r + (rng.randf() * 2.0 - 1.0) * amp * fall, 0.0, 1.0)
			hm_img.set_pixel(xx, yy, Color(nv, nv, nv))
	_after_edit(p, true, rad)

## Biome eyedropper (RMB): pick the most-common biome under the brush that ISN'T the
func _pick_biome(p: Vector3) -> void:
	var b := _brush_px(p, brush_radius); var cu = b[0]; var cv = b[1]; var rpx = b[2]
	var counts := {}
	for yy in range(maxi(0, int(cv - rpx)), mini(_hm_h - 1, int(cv + rpx)) + 1):
		for xx in range(maxi(0, int(cu - rpx)), mini(_hm_w - 1, int(cu + rpx)) + 1):
			if Vector2(xx - cu, yy - cv).length() > rpx: continue
			var id := int(round(bm_img.get_pixel(xx, yy).r * 255.0))
			if id != biome_index and id >= 0 and id < Config.GROUND_MATERIALS.size():
				counts[id] = int(counts.get(id, 0)) + 1
	var best := -1; var bc := 0
	for id in counts:
		if int(counts[id]) > bc: bc = int(counts[id]); best = id
	if best >= 0:
		biome_index = best
		if biome_box != null: biome_box.selected = best
		_flash(_mat_name(best))
		_refresh_status()

## Push brushed pixels toward a target grayscale height (shared by Match/SetElev).
func _push_toward(p: Vector3, target: float, rad: float, strn: int) -> void:
	var b := _brush_px(p, rad); var cu = b[0]; var cv = b[1]; var rpx = b[2]
	var rate := clampf(_str_amp(strn) / 100.0 * 0.05, 0.0006, 0.5)
	for yy in range(maxi(0, int(cv - rpx)), mini(_hm_h - 1, int(cv + rpx)) + 1):
		for xx in range(maxi(0, int(cu - rpx)), mini(_hm_w - 1, int(cu + rpx)) + 1):
			var d := Vector2(xx - cu, yy - cv).length()
			if d > rpx: continue
			var nv := clampf(lerpf(hm_img.get_pixel(xx, yy).r, target, rate * _falloff(d, rpx)), 0.0, 1.0)
			hm_img.set_pixel(xx, yy, Color(nv, nv, nv))
	_after_edit(p, true, rad)

## Match: push the area toward the height at the brush CENTRE.
func _match_brush(p: Vector3, rad: float = -1.0, strn: int = -1) -> void:
	if rad < 0.0: rad = brush_radius
	if strn < 0: strn = brush_strength
	var b := _brush_px(p, rad)
	var tx := clampi(int(b[0]), 0, _hm_w - 1); var tz := clampi(int(b[1]), 0, _hm_h - 1)
	_push_toward(p, hm_img.get_pixel(tx, tz).r, rad, strn)

func _push_to_elev(p: Vector3, target_gray: float, rad: float = -1.0, strn: int = -1) -> void:
	if rad < 0.0: rad = brush_radius
	if strn < 0: strn = brush_strength
	_push_toward(p, clampf(target_gray, 0.0, 1.0), rad, strn)

func _stamp(p: Vector3, sgn: float, rad: float = -1.0, strn: int = -1) -> void:
	if rad < 0.0: rad = brush_radius
	if strn < 0: strn = brush_strength
	var b := _brush_px(p, rad); var cu = b[0]; var cv = b[1]; var rpx = b[2]
	for yy in range(maxi(0, int(cv - rpx)), mini(_hm_h - 1, int(cv + rpx)) + 1):
		for xx in range(maxi(0, int(cu - rpx)), mini(_hm_w - 1, int(cu + rpx)) + 1):
			var d := Vector2(xx - cu, yy - cv).length()
			if d > rpx: continue
			var fall := _falloff(d, rpx)
			var nv := clampf(hm_img.get_pixel(xx, yy).r + sgn * (_str_amp(strn) * STRENGTH_UNIT) * fall, 0.0, 1.0)
			hm_img.set_pixel(xx, yy, Color(nv, nv, nv))
	_after_edit(p, true, rad)

func _flatten(p: Vector3, rad: float = -1.0, strn: int = -1) -> void:
	if rad < 0.0: rad = brush_radius
	if strn < 0: strn = brush_strength
	var b := _brush_px(p, rad); var cu = b[0]; var cv = b[1]; var rpx = b[2]
	var sum := 0.0; var n := 0
	for yy in range(maxi(0, int(cv - rpx)), mini(_hm_h - 1, int(cv + rpx)) + 1):
		for xx in range(maxi(0, int(cu - rpx)), mini(_hm_w - 1, int(cu + rpx)) + 1):
			if Vector2(xx - cu, yy - cv).length() <= rpx: sum += hm_img.get_pixel(xx, yy).r; n += 1
	if n == 0: return
	var avg := sum / float(n); var rate := clampf(_str_amp(strn) / 100.0 * 0.05, 0.0006, 0.5)
	for yy in range(maxi(0, int(cv - rpx)), mini(_hm_h - 1, int(cv + rpx)) + 1):
		for xx in range(maxi(0, int(cu - rpx)), mini(_hm_w - 1, int(cu + rpx)) + 1):
			var d := Vector2(xx - cu, yy - cv).length()
			if d > rpx: continue
			var fall := _falloff(d, rpx)
			var nv := clampf(lerpf(hm_img.get_pixel(xx, yy).r, avg, rate * fall), 0.0, 1.0)
			hm_img.set_pixel(xx, yy, Color(nv, nv, nv))
	_after_edit(p, true, rad)

func _paint_biome(p: Vector3, id: int, rad: float = -1.0) -> void:
	if rad < 0.0: rad = brush_radius
	var b := _brush_px(p, rad); var cu = b[0]; var cv = b[1]; var rpx = b[2]
	var r := id / 255.0
	for yy in range(maxi(0, int(cv - rpx)), mini(_hm_h - 1, int(cv + rpx)) + 1):
		for xx in range(maxi(0, int(cu - rpx)), mini(_hm_w - 1, int(cu + rpx)) + 1):
			if Vector2(xx - cu, yy - cv).length() <= rpx:
				bm_img.set_pixel(xx, yy, Color(r, r, r))
				# Releases the texel from any smart material so a later sculpt won't auto-revert it.
				if sid_img != null: sid_img.set_pixel(xx, yy, Color(0, 0, 0))
	_after_edit(p, false)

## Steepness at a world point: 1 - normal.y (0 flat, ~1 vertical), from the raw heightmap so it tracks the sculpted shape.
func _slope01(x: float, z: float) -> float:
	var e := 1.0
	var n := Vector3(_macro(x - e, z) - _macro(x + e, z), 2.0 * e,
		_macro(x, z - e) - _macro(x, z + e)).normalized()
	return clampf(1.0 - n.y, 0.0, 1.0)

## Paint a smart material: evaluate its rules per texel and bake the material index into biome.png,
func _paint_smart(p: Vector3, sidx: int, rad: float = -1.0) -> void:
	if sidx < 0 or sidx >= smart_mats.size():
		return
	if rad < 0.0: rad = brush_radius
	var preset: Dictionary = smart_mats[sidx]
	var b := _brush_px(p, rad); var cu = b[0]; var cv = b[1]; var rpx = b[2]
	var sid := (sidx + 1) / 255.0
	for yy in range(maxi(0, int(cv - rpx)), mini(_hm_h - 1, int(cv + rpx)) + 1):
		for xx in range(maxi(0, int(cu - rpx)), mini(_hm_w - 1, int(cu + rpx)) + 1):
			if Vector2(xx - cu, yy - cv).length() > rpx: continue
			var wx := float(xx) / float(_hm_w - 1) * float(Config.GRID_COLS)
			var wz := float(yy) / float(_hm_h - 1) * float(Config.GRID_ROWS)
			var mi := SmartMaterial.evaluate(preset, _macro(wx, wz), _slope01(wx, wz), _fbm(wx * 0.15, wz * 0.15) - 0.5)
			var c := mi / 255.0
			bm_img.set_pixel(xx, yy, Color(c, c, c))
			sid_img.set_pixel(xx, yy, Color(sid, sid, sid))
	_dirty = true
	_after_edit(p, false, rad)

## Re-run smart-material rules over a region after a sculpt; only texels owned by a smart material (sid_img > 0) change.
func _reapply_smart_region(wx0: float, wz0: float, wx1: float, wz1: float, only_sid := -1) -> void:
	if sid_img == null or smart_mats.is_empty():
		return
	var px0 := clampi(int(floor(wx0 / float(Config.GRID_COLS) * (_hm_w - 1))) - 1, 0, _hm_w - 1)
	var px1 := clampi(int(ceil(wx1 / float(Config.GRID_COLS) * (_hm_w - 1))) + 1, 0, _hm_w - 1)
	var pz0 := clampi(int(floor(wz0 / float(Config.GRID_ROWS) * (_hm_h - 1))) - 1, 0, _hm_h - 1)
	var pz1 := clampi(int(ceil(wz1 / float(Config.GRID_ROWS) * (_hm_h - 1))) + 1, 0, _hm_h - 1)
	var changed := false
	for yy in range(pz0, pz1 + 1):
		for xx in range(px0, px1 + 1):
			var sid := int(round(sid_img.get_pixel(xx, yy).r * 255.0))
			if sid <= 0 or sid > smart_mats.size():
				continue
			if only_sid >= 0 and sid != only_sid:
				continue
			var wx := float(xx) / float(_hm_w - 1) * float(Config.GRID_COLS)
			var wz := float(yy) / float(_hm_h - 1) * float(Config.GRID_ROWS)
			var mi := SmartMaterial.evaluate(smart_mats[sid - 1], _macro(wx, wz), _slope01(wx, wz), _fbm(wx * 0.15, wz * 0.15) - 0.5)
			if mi != int(round(bm_img.get_pixel(xx, yy).r * 255.0)):
				var c := mi / 255.0
				bm_img.set_pixel(xx, yy, Color(c, c, c))
				changed = true
	if changed:
		var ccx0 := int(floor((wx0 - 1.0) / CHUNK)); var ccx1 := int(floor((wx1 + 1.0) / CHUNK))
		var ccz0 := int(floor((wz0 - 1.0) / CHUNK)); var ccz1 := int(floor((wz1 + 1.0) / CHUNK))
		for cyy in range(ccz0, ccz1 + 1):
			for cxx in range(ccx0, ccx1 + 1):
				if _chunks.has(Vector2i(cxx, cyy)): _rebuild_chunk(Vector2i(cxx, cyy))
		_dirty = true

## Throttle smart-material re-bakes to ~1/sec: accumulate the dirty rect, flush on cooldown.
func _request_smart_reapply(wx0: float, wz0: float, wx1: float, wz1: float) -> void:
	var r := Rect2(wx0, wz0, maxf(0.0, wx1 - wx0), maxf(0.0, wz1 - wz0))
	_smart_rect = r if not _smart_due else _smart_rect.merge(r)
	_smart_due = true
	_maybe_flush_smart_reapply()

func _maybe_flush_smart_reapply() -> void:
	if not _smart_due or Time.get_ticks_msec() - _smart_last_ms < 1000:
		return
	_smart_due = false
	_smart_last_ms = Time.get_ticks_msec()
	_reapply_smart_region(_smart_rect.position.x, _smart_rect.position.y,
		_smart_rect.end.x, _smart_rect.end.y)

func _mk_mat_option(sel: int) -> OptionButton:
	var ob := OptionButton.new()
	for i in Config.GROUND_MATERIALS.size():
		ob.add_item(str(Config.GROUND_MATERIALS[i]).capitalize(), i)
	ob.selected = clampi(sel, 0, Config.GROUND_MATERIALS.size() - 1)
	return ob

## Show the single-texture dropdown or the smart-material editor per the Smart toggle (Material tool only).
func _update_material_ui_visibility() -> void:
	var in_mat := mode == MODE_BIOME
	if _smart_cb != null: _smart_cb.visible = in_mat
	if biome_box != null: biome_box.visible = in_mat and not smart_on
	if _smart_panel != null: _smart_panel.visible = in_mat and smart_on

func _smart_new() -> void:
	smart_mats.append(SmartMaterial.make_default("smart %d" % (smart_mats.size() + 1)))
	var _nc: Color = SMART_COLORS[(smart_mats.size() - 1) % SMART_COLORS.size()]
	smart_mats[smart_mats.size() - 1]["color"] = [_nc.r, _nc.g, _nc.b]
	smart_sel = smart_mats.size() - 1
	smart_on = true
	if _smart_cb != null: _smart_cb.button_pressed = true
	_update_material_ui_visibility()
	_rebuild_smart_panel()
	_refresh_status()
	_dirty = true

func _smart_delete() -> void:
	if smart_mats.is_empty(): return
	var gone := smart_sel + 1
	smart_mats.remove_at(smart_sel)
	if sid_img != null:
		for yy in _hm_h:
			for xx in _hm_w:
				var s := int(round(sid_img.get_pixel(xx, yy).r * 255.0))
				if s == gone:
					sid_img.set_pixel(xx, yy, Color(0, 0, 0))
				elif s > gone:
					var v := (s - 1) / 255.0
					sid_img.set_pixel(xx, yy, Color(v, v, v))
	smart_sel = clampi(smart_sel, 0, maxi(0, smart_mats.size() - 1))
	if smart_overlay_on: _rebuild_smart_overlay()
	_rebuild_smart_panel()
	_refresh_status()
	_dirty = true

## Live re-bake: after any edit to the current preset's rules, re-run it over just the
func _smart_changed() -> void:
	_reapply_smart_region(0.0, 0.0, float(Config.GRID_COLS), float(Config.GRID_ROWS), smart_sel + 1)
	_dirty = true

## The editor tint colour for smart material i (from its preset, else a palette fallback).
func _smart_color(i: int) -> Color:
	if i < 0 or i >= smart_mats.size(): return Color.WHITE
	var c = smart_mats[i].get("color", null)
	if c is Array and c.size() >= 3: return Color(float(c[0]), float(c[1]), float(c[2]))
	return SMART_COLORS[i % SMART_COLORS.size()]

func _smart_color_changed() -> void:
	if smart_overlay_on: _rebuild_smart_overlay()

## Editor overlay: recolor the vertex-colored ground by which smart material owns each texel.
func _rebuild_smart_overlay() -> void:
	for c in _chunks: _rebuild_chunk(c)

## Smart-material owner index at a world XZ (-1 = none), mirroring _biome_at's mapping.
func _smart_owner_at(x: float, z: float) -> int:
	if sid_img == null: return -1
	var px := clampi(int(x / float(Config.GRID_COLS) * (_hm_w - 1)), 0, _hm_w - 1)
	var pz := clampi(int(z / float(Config.GRID_ROWS) * (_hm_h - 1)), 0, _hm_h - 1)
	var s := int(round(sid_img.get_pixel(px, pz).r * 255.0))
	return (s - 1) if s > 0 else -1

func _set_smart_overlay(on: bool) -> void:
	smart_overlay_on = on
	_rebuild_smart_overlay()

## Rebuild the smart-material editor from smart_mats[smart_sel]. Called on any
func _rebuild_smart_panel() -> void:
	if _smart_panel == null:
		return
	for c in _smart_panel.get_children():
		c.queue_free()
	var top := HBoxContainer.new(); _smart_panel.add_child(top)
	var box := OptionButton.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if smart_mats.is_empty():
		box.add_item("(none yet)", 0); box.disabled = true
	else:
		for i in smart_mats.size():
			box.add_item(str(smart_mats[i].get("name", "preset %d" % i)), i)
		box.selected = clampi(smart_sel, 0, smart_mats.size() - 1)
	box.item_selected.connect(func(i): smart_sel = i; _rebuild_smart_panel(); _refresh_status())
	top.add_child(box)
	var newb := Button.new(); newb.text = "+"; newb.tooltip_text = "new smart material"
	newb.pressed.connect(_smart_new)
	top.add_child(newb)
	var delb := Button.new(); delb.text = "🗑"; delb.tooltip_text = "delete this smart material"
	delb.disabled = smart_mats.is_empty()
	delb.pressed.connect(_smart_delete)
	top.add_child(delb)
	var ov := CheckBox.new(); ov.text = "overlay"
	ov.tooltip_text = "Tint the ground by which smart material owns each spot (editor only)."
	ov.button_pressed = smart_overlay_on
	ov.toggled.connect(_set_smart_overlay)
	top.add_child(ov)
	if smart_mats.is_empty():
		var hint := Label.new(); hint.text = "Press + to make one."
		hint.add_theme_font_size_override("font_size", 10)
		_smart_panel.add_child(hint)
		return
	smart_sel = clampi(smart_sel, 0, smart_mats.size() - 1)
	var preset: Dictionary = smart_mats[smart_sel]
	if not preset.has("rules"): preset["rules"] = []
	var rules: Array = preset["rules"]
	var name_row := HBoxContainer.new(); _smart_panel.add_child(name_row)
	var nl := Label.new(); nl.text = "name"; name_row.add_child(nl)
	var ne := LineEdit.new(); ne.text = str(preset.get("name", ""))
	ne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ne.text_changed.connect(func(t): preset["name"] = t)
	ne.text_submitted.connect(func(_t): _rebuild_smart_panel(); _refresh_status())
	name_row.add_child(ne)
	var base_row := HBoxContainer.new(); _smart_panel.add_child(base_row)
	var bl := Label.new(); bl.text = "base"; base_row.add_child(bl)
	var bo := _mk_mat_option(int(preset.get("base", 0)))
	bo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bo.item_selected.connect(func(i): preset["base"] = bo.get_item_id(i); _smart_changed())
	base_row.add_child(bo)
	var color_row := HBoxContainer.new(); _smart_panel.add_child(color_row)
	var cl := Label.new(); cl.text = "overlay colour"; color_row.add_child(cl)
	var ccp := ColorPickerButton.new()
	ccp.color = _smart_color(smart_sel)
	ccp.custom_minimum_size = Vector2(0, 22)
	ccp.color_changed.connect(func(c): preset["color"] = [c.r, c.g, c.b]; _smart_color_changed())
	color_row.add_child(ccp)
	var blend_row := HBoxContainer.new(); _smart_panel.add_child(blend_row)
	var sl := Label.new(); sl.text = "blend"; blend_row.add_child(sl)
	var bsp := SpinBox.new()
	bsp.min_value = 0.0; bsp.max_value = 1.0; bsp.step = 0.05
	bsp.value = float(preset.get("blend", 0.25))
	bsp.tooltip_text = "Feather material transitions: 0 = hard edge, 1 = wide soft band. Stacks with the ground shader's own seam blend."
	bsp.value_changed.connect(func(v): preset["blend"] = v; _smart_changed())
	blend_row.add_child(bsp)
	var rlbl := Label.new(); rlbl.text = "rules (first match wins, live):"
	rlbl.add_theme_font_size_override("font_size", 10)
	_smart_panel.add_child(rlbl)
	for ri in rules.size():
		var rule: Dictionary = rules[ri]
		var row := HBoxContainer.new(); _smart_panel.add_child(row)
		var tb := OptionButton.new()
		for ti in SmartMaterial.PROP_TYPES.size():
			tb.add_item(str(SmartMaterial.PROP_TYPES[ti]), ti)
		tb.selected = maxi(0, SmartMaterial.PROP_TYPES.find(str(rule.get("type", "steepness"))))
		tb.tooltip_text = "steepness 0 flat..1 vertical   |   height = elevation in world metres (negative = below water).  op >  is above, op <  is below"
		tb.item_selected.connect(func(i): rule["type"] = SmartMaterial.PROP_TYPES[i]; _rebuild_smart_panel(); _smart_changed())
		row.add_child(tb)
		var opb := OptionButton.new()
		opb.add_item(">", 0); opb.add_item("<", 1)
		opb.selected = 0 if str(rule.get("op", ">")) == ">" else 1
		opb.item_selected.connect(func(i): rule["op"] = (">" if i == 0 else "<"); _smart_changed())
		row.add_child(opb)
		var sp := SpinBox.new()
		var is_steep := str(rule.get("type", "steepness")) == "steepness"
		sp.min_value = 0.0 if is_steep else HM_MIN
		sp.max_value = 1.0 if is_steep else HM_MAX
		sp.step = 0.01 if is_steep else 0.5
		sp.allow_lesser = false; sp.allow_greater = false
		sp.value = float(rule.get("value", 0.0))
		sp.value_changed.connect(func(v): rule["value"] = v; _smart_changed())
		row.add_child(sp)
		var mo := _mk_mat_option(int(rule.get("mat", 0)))
		mo.item_selected.connect(func(i): rule["mat"] = mo.get_item_id(i); _smart_changed())
		row.add_child(mo)
		var rm := Button.new(); rm.text = "×"; rm.tooltip_text = "remove rule"
		rm.pressed.connect(func(): rules.remove_at(ri); _rebuild_smart_panel(); _smart_changed())
		row.add_child(rm)
	var addr := Button.new(); addr.text = "+ add rule"
	addr.pressed.connect(func():
		rules.append({"type": "steepness", "op": ">", "value": 0.4, "mat": 0})
		_rebuild_smart_panel(); _smart_changed())
	_smart_panel.add_child(addr)

# --- object placement -------------------------------------------------------

func _tiles_for(entry: Dictionary) -> Array:
	if str(entry.get("kind", "")) in ["water_src", "block", "decor", "node", "prop"]:
		return []
	var ax := int(floor(float(entry["x"]))); var az := int(floor(float(entry["z"])))
	return [Vector2i(ax, az)]

func _new_uid() -> int:
	_uid_counter += 1
	var pid := 1
	return pid * 1000000 + _uid_counter

func _place(p: Vector3) -> void:
	var sel := _selected()
	if sel.is_empty(): _refresh_status("pick a type"); return
	var entry := {"kind": sel["kind"], "rot": _place_rot, "uid": _new_uid()}
	if sel.has("color"): entry["color"] = sel["color"]
	if sel.has("radius"): entry["radius"] = sel["radius"]
	var ax := int(floor(p.x)); var az := int(floor(p.z))
	entry["x"] = ax + 0.5; entry["z"] = az + 0.5
	if _try_place_entry(entry):
		_undo_push({"op": "add", "uid": int(entry["uid"])})
		_pop_sound()
	_refresh_status()

## Placement primitive (validate + spawn + bookkeep). One path for tools, undo, paste.
func _try_place_entry(entry: Dictionary) -> bool:
	if int(entry.get("uid", 0)) <= 0:
		entry["uid"] = _new_uid()
	if str(entry.get("kind", "")) == "start":
		_remove_existing_start()
	# Tiles are EXCLUSIVE: never two objects in one spot.
	var tiles := _tiles_for(entry)
	for t in tiles:
		if _occupied.has(t): return false
	var node := _spawn(entry)
	if node == null: return false
	node.visible = _objects_visible
	for t in tiles: _occupied[t] = true
	_objects.append(entry); _spawned.append(node); _obj_tiles.append(tiles); _last = node
	match str(entry.get("kind", "")):
		"water_src":
			if _water_sim != null:
				_water_sim.add_source(WaterSim.cell_of(Vector3(
					float(entry["x"]), float(entry.get("y", 0.0)), float(entry["z"]))))
	return true

## Remove the entry with this uid (removal by uid; list indices can drift, uids cannot).
func _remove_uid(uid: int) -> void:
	for i in _objects.size():
		if int(_objects[i].get("uid", -1)) == uid:
			_remove_at(i)
			return

func _apply_group(uids: Array, gid: int) -> void:
	for i in _objects.size():
		if int(_objects[i].get("uid", -1)) in uids:
			if gid == 0: _objects[i].erase("group")
			else: _objects[i]["group"] = gid
	_dirty = true

## Heal a legacy object that lacks a uid (group/move identify by uid; never match the -1 sentinel).
func _ensure_uid(i: int) -> int:
	var u := int(_objects[i].get("uid", 0))
	if u <= 0:
		u = _new_uid()
		_objects[i]["uid"] = u
		_dirty = true
	return u

func _group_area(a: Vector3, b: Vector3) -> void:
	var x0 := minf(a.x, b.x); var x1 := maxf(a.x, b.x)
	var z0 := minf(a.z, b.z); var z1 := maxf(a.z, b.z)
	var uids: Array = []
	var prev: Array = []
	for i in _objects.size():
		var e: Dictionary = _objects[i]
		if str(e.get("kind", "")) == "start": continue
		var ex := float(e["x"]); var ez := float(e["z"])
		if ex < x0 or ex > x1 or ez < z0 or ez > z1: continue
		uids.append(_ensure_uid(i))
		prev.append(int(e.get("group", 0)))
	_group_uids(uids, prev)

## Group the current multi-selection directly (no box needed).
func _group_selection() -> void:
	var members := _sel_members()
	var uids: Array = []
	var prev: Array = []
	for i in members:
		if str(_objects[i].get("kind", "")) == "start": continue
		uids.append(_ensure_uid(i))
		prev.append(int(_objects[i].get("group", 0)))
	_group_uids(uids, prev)
	_after_sel_change()

func _group_uids(uids: Array, prev: Array) -> void:
	if uids.size() < 2:
		_flash("need at least 2 things to group")
		return
	var gid := _new_uid()
	_apply_group(uids, gid)
	_undo_push({"op": "group", "uids": uids, "prev": prev})
	_pop_sound()
	_flash("grouped 🔒 %d pieces — they move as one now" % uids.size())

## Delete the whole selection (groups expand). One undo step restores all.
func _delete_sel() -> void:
	var members := _sel_members()
	if members.is_empty():
		_flash("nothing selected")
		return
	var entries: Array = []
	var uids: Array = []
	for i in members:
		entries.append((_objects[i] as Dictionary).duplicate(true))
		uids.append(int(_objects[i].get("uid", -1)))
	for u in uids:
		_remove_uid(int(u))
	_deselect()
	_undo_push({"op": "remove_multi", "entries": entries})
	_pop_sound(true)
	_dirty = true
	_flash("deleted %d" % uids.size())

## Ctrl+D: copy the selection one tile over, keep group structure (fresh ids),
func _duplicate_sel() -> void:
	var members := _sel_members()
	if members.is_empty():
		_flash("nothing selected")
		return
	var gid_map := {}
	var new_uids: Array = []
	var new_sel: Array = []
	for i in members:
		var e: Dictionary = (_objects[i] as Dictionary).duplicate(true)
		e["uid"] = _new_uid()
		e["x"] = float(e["x"]) + 1.0
		e["z"] = float(e["z"]) + 1.0
		var og := int(e.get("group", 0))
		if og != 0:
			if not gid_map.has(og): gid_map[og] = _new_uid()
			e["group"] = gid_map[og]
		if _try_place_entry(e):
			new_uids.append(int(e["uid"]))
			new_sel.append(_objects.size() - 1)
	if new_uids.is_empty():
		_flash("couldn't duplicate (space occupied)")
		return
	_sel = new_sel
	_sel_idx = int(new_sel[-1])
	_after_sel_change()
	_undo_push({"op": "group_add", "uids": new_uids})
	_pop_sound()
	_dirty = true
	_flash("duplicated %d — drag to place" % new_uids.size())

## F: swing the camera to whatever is selected (or do nothing politely).
func _frame_selection() -> void:
	var members := _sel_members()
	if members.is_empty():
		_flash("select something to frame (F)")
		return
	var c := Vector3.ZERO
	var lo := Vector3(1e9, 1e9, 1e9)
	var hi := Vector3(-1e9, -1e9, -1e9)
	for i in members:
		if i >= _spawned.size() or not is_instance_valid(_spawned[i]): continue
		var p: Vector3 = _spawned[i].position
		c += p
		lo = lo.min(p); hi = hi.max(p)
	c /= float(members.size())
	focus = c
	cam_dist = clampf((hi - lo).length() * 1.6 + 14.0, 12.0, 400.0)
	_update_cam()

var _ortho := false
var _ortho_prev_pitch := 0.0

const CAM_CFG := "user://editor_cam.cfg"

func _save_cam() -> void:
	var cf := ConfigFile.new()
	cf.set_value("cam", "focus", focus)
	cf.set_value("cam", "yaw", cam_yaw)
	cf.set_value("cam", "pitch", cam_pitch)
	cf.set_value("cam", "dist", cam_dist)
	cf.set_value("cam", "zoom_speed", zoom_speed)
	cf.set_value("cam", "orbit_draw", orbit_draw_dist)
	cf.set_value("cam", "orbit_shadow", orbit_shadow_dist)
	cf.set_value("cam", "chase_draw", chase_draw_dist)
	cf.set_value("cam", "chase_shadow", chase_shadow_dist)
	cf.set_value("cam", "tod", _editor_tod)
	cf.set_value("brush", "radius", brush_radius)
	cf.set_value("brush", "strength", brush_strength)
	cf.set_value("brush", "opacity", brush_opacity)
	cf.set_value("brush", "target_elev", target_elev)
	cf.set_value("layers", "states", _layer_states)
	cf.save(CAM_CFG)

func _load_cam() -> void:
	var cf := ConfigFile.new()
	if cf.load(CAM_CFG) != OK: return
	focus = cf.get_value("cam", "focus", focus)
	cam_yaw = cf.get_value("cam", "yaw", cam_yaw)
	cam_pitch = cf.get_value("cam", "pitch", cam_pitch)
	cam_dist = cf.get_value("cam", "dist", cam_dist)
	zoom_speed = cf.get_value("cam", "zoom_speed", zoom_speed)
	orbit_draw_dist = cf.get_value("cam", "orbit_draw", orbit_draw_dist)
	orbit_shadow_dist = cf.get_value("cam", "orbit_shadow", orbit_shadow_dist)
	chase_draw_dist = cf.get_value("cam", "chase_draw", chase_draw_dist)
	chase_shadow_dist = cf.get_value("cam", "chase_shadow", chase_shadow_dist)
	_editor_tod = cf.get_value("cam", "tod", _editor_tod)
	brush_radius = cf.get_value("brush", "radius", brush_radius)
	brush_strength = int(cf.get_value("brush", "strength", brush_strength))
	brush_opacity = cf.get_value("brush", "opacity", brush_opacity)
	target_elev = cf.get_value("brush", "target_elev", target_elev)
	if _sun != null: _sun.directional_shadow_max_distance = orbit_shadow_dist
	var ls = cf.get_value("layers", "states", null)
	if ls is Dictionary:
		for k in _layer_states:
			if ls.has(k): _layer_states[k] = bool(ls[k])

var _readout_on := true
var _readout_lbl: Label = null
var _readout_t := 0.0
var _mini_rect: TextureRect = null
var _mini_marks: Control = null
var _mini_tex: ImageTexture = null
var _mini_dirty := true
var _mini_t := 0.0
const MINI_RES := 125
const MINI_SIZE := 170.0

var _mini_panel: PanelContainer = null

func _build_minimap(ui: CanvasLayer, th: Theme) -> void:
	var vb := _make_dock("map", "MAP", ui, th)
	_mini_panel = _docks["map"]["panel"]
	_mini_panel.anchor_top = 1.0; _mini_panel.anchor_bottom = 1.0
	_mini_panel.anchor_left = 1.0; _mini_panel.anchor_right = 1.0
	_mini_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_mini_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_mini_panel.offset_right = -8.0; _mini_panel.offset_bottom = -40.0
	_dock_snapshot("map")
	_mini_rect = TextureRect.new()
	_mini_rect.custom_minimum_size = Vector2(MINI_SIZE, MINI_SIZE)
	_mini_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_mini_rect.gui_input.connect(_mini_input)
	vb.add_child(_mini_rect)
	_mini_marks = Control.new()
	_mini_marks.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mini_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mini_marks.draw.connect(_mini_draw)
	_mini_rect.add_child(_mini_marks)

func _mini_input(e: InputEvent) -> void:
	# Static map: a click jumps; everything else is swallowed so it can't reach the world underneath.
	_mini_rect.accept_event()
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var uv: Vector2 = (e as InputEventMouseButton).position / _mini_rect.size
		var wx := clampf(uv.x, 0.0, 1.0) * Config.GRID_COLS
		var wz := clampf(uv.y, 0.0, 1.0) * Config.GRID_ROWS
		focus = Vector3(wx, _height(wx, wz), wz)
		_update_cam()

## Repaint the overview image: height-shaded land, water, crayon doodles.
func _mini_rebuild() -> void:
	var img := Image.create(MINI_RES, MINI_RES, false, Image.FORMAT_RGB8)
	var step := float(Config.GRID_COLS) / float(MINI_RES)
	for py in MINI_RES:
		for px in MINI_RES:
			var wx := (px + 0.5) * step
			var wz := (py + 0.5) * step
			var h := _height(wx, wz)
			var c: Color
			if h <= Config.WATER_LEVEL + 0.05:
				c = Color(0.16, 0.32, 0.5)
			else:
				var k := clampf((h - Config.WATER_LEVEL) / 26.0, 0.0, 1.0)
				c = Color(0.22, 0.42, 0.2).lerp(Color(0.62, 0.58, 0.5), k)
				if h > 30.0: c = c.lerp(Color(0.92, 0.93, 0.96), clampf((h - 30.0) / 12.0, 0.0, 1.0))
			img.set_pixel(px, py, c)
	if _mini_tex == null:
		_mini_tex = ImageTexture.create_from_image(img)
		_mini_rect.texture = _mini_tex
	else:
		_mini_tex.update(img)

# LIGHTING PANEL — live-tunes WorldLook (sun/sky/mist/ground) through the shared code paths;
var _look_panel: PanelContainer = null

func _toggle_look_panel() -> void:
	if _look_panel == null:
		_build_look_panel()
		return   # freshly built + shown — don't immediately hide it
	_look_panel.visible = not _look_panel.visible

var _shaders: Array = []      # registry: {key,label,set_on:Callable,build_page:Callable,on_default:bool}
var _shader_pages: Array = []
var _shader_btns: Array = []

## THE shader registry. Every shader/effect — built-in or drop-in — registers here and ONLY here;
## the shaders toolbar is built from this list, so no shader exists without a toggle and none is
## applied silently. set_on(on) is the sole enable/disable path; build_page(vb) fills the sliders.
func register_shader(key: String, label: String, set_on: Callable, build_page: Callable, on_default: bool = true) -> void:
	_shaders.append({"key": key, "label": label, "set_on": set_on, "build_page": build_page, "on_default": on_default})

## Register the built-in shader layers (called before the shaders section builds).
func _register_builtin_shaders() -> void:
	register_shader("foliage", "Foliage", _shader_set_foliage, _page_foliage, true)
	register_shader("trees", "Trees", _shader_set_trees, _page_trees, true)
	register_shader("water", "Water", _shader_set_water, Callable(), bool(_layer_states.get("water", true)))
	register_shader("grade", "Colour grade", _shader_set_grade, _page_grade, true)
	register_shader("ground", "Ground tint", _shader_set_ground, _page_ground, bool(_layer_states.get("shader", true)))

func _shader_set_foliage(on: bool) -> void:
	RenderingServer.global_shader_parameter_set("foliage_enabled", 1.0 if on else 0.0)
func _shader_set_trees(on: bool) -> void:
	WindRig.force_idle = not on
func _shader_set_water(on: bool) -> void:
	_layer_states["water"] = on
	if _water != null: _water.visible = on
	if _water_btn != null: _water_btn.set_pressed_no_signal(on)
func _shader_set_grade(on: bool) -> void:
	_env_e.adjustment_enabled = on
func _shader_set_ground(on: bool) -> void:
	for c in _chunks: (_chunks[c] as MeshInstance3D).visible = on

func _page_foliage(vb: VBoxContainer) -> void:
	_lk_num(vb, "rounded volume (dome)", "foliage_normal_up", 0.0, 1.0)
	_lk_num(vb, "shaded edges", "foliage_edge_shade", 0.0, 0.8)
	_lk_num(vb, "leaf backlight", "foliage_backlight", 0.0, 1.0)
	_lk_num(vb, "colour variation", "foliage_variation", 0.0, 0.5)
	_lk_num(vb, "blade texture detail", "foliage_detail", 0.0, 1.5)
	_lk_num(vb, "sway strength", "wind_strength", 0.0, 0.6)
	_lk_num(vb, "wind speed", "wind_speed", 0.0, 4.0)
func _page_trees(vb: VBoxContainer) -> void:
	_lk_num(vb, "sway strength", "wind_strength", 0.0, 0.6)
	_lk_num(vb, "wind direction", "wind_angle", 0.0, 6.28)
func _page_grade(vb: VBoxContainer) -> void:
	_lk_num(vb, "brightness", "brightness", 0.5, 1.5)
	_lk_num(vb, "contrast", "contrast", 0.5, 1.5)
	_lk_num(vb, "saturation", "saturation", 0.0, 2.0)
	_lk_num(vb, "exposure", "exposure", 0.2, 2.0)
func _page_ground(vb: VBoxContainer) -> void:
	_lk_col(vb, "grass low", "ground_grass_low")
	_lk_col(vb, "grass high", "ground_grass_high")
	_lk_col(vb, "dirt", "ground_dirt")
	_lk_col(vb, "rock", "ground_rock")

## Shaders master-detail, a sub-section of the LAYERS dock: left column = on/off + name button,
## right column = the selected shader's sliders. Settings ride WorldLook (live preview + saved with the look).
func _build_shaders_section(parent: VBoxContainer) -> void:
	parent.add_child(HSeparator.new())
	parent.add_child(_section("shaders"))
	var row := HBoxContainer.new(); parent.add_child(row)
	var left := VBoxContainer.new(); row.add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	_shader_pages = []
	_shader_btns = []
	for i in _shaders.size():
		var spec: Dictionary = _shaders[i]
		var page := VBoxContainer.new()
		var builder: Callable = spec["build_page"]
		if builder.is_valid(): builder.call(page)
		right.add_child(page); _shader_pages.append(page)
		var r := HBoxContainer.new(); left.add_child(r)
		var cb := CheckBox.new()
		cb.button_pressed = bool(spec["on_default"])
		var setter: Callable = spec["set_on"]
		cb.toggled.connect(setter)
		r.add_child(cb)
		var b := Button.new(); b.text = str(spec["label"])
		b.toggle_mode = true; b.flat = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var idx := i
		b.pressed.connect(func(): _show_shader_page(idx))
		r.add_child(b)
		_shader_btns.append(b)
	if not _shaders.is_empty(): _show_shader_page(0)

func _show_shader_page(i: int) -> void:
	for j in _shader_pages.size():
		(_shader_pages[j] as Control).visible = (j == i)
		if j < _shader_btns.size():
			(_shader_btns[j] as Button).set_pressed_no_signal(j == i)
	if _docks.has("layers"):
		(_docks["layers"]["panel"] as Control).reset_size()

## Push authored wind to the shader globals (a host's foliage/tree shaders read these).
func _apply_wind() -> void:
	RenderingServer.global_shader_parameter_set("wind_angle", WorldLook.num("wind_angle"))
	RenderingServer.global_shader_parameter_set("wind_speed", WorldLook.num("wind_speed"))
	WorldLook.gate_wind(WorldLook.num("wind_strength"))

func _look_changed() -> void:
	# Re-apply through the same render paths — the preview IS the result.
	_apply_editor_time(_editor_tod)
	WorldLook.apply_pipeline(_env_e)
	_apply_wind()

func _lk_num(parent: Control, label: String, key: String, lo: float, hi: float) -> void:
	parent.add_child(_labeled(label))
	var s := HSlider.new()
	s.min_value = lo; s.max_value = hi; s.step = (hi - lo) / 100.0
	s.value = WorldLook.num(key)
	s.value_changed.connect(func(v):
		WorldLook.settings()[key] = v
		_look_changed())
	parent.add_child(s)

func _lk_col(parent: Control, label: String, key: String) -> void:
	var row := HBoxContainer.new(); parent.add_child(row)
	var l := _labeled(label); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var p := ColorPickerButton.new()
	p.custom_minimum_size = Vector2(42, 18)
	p.color = WorldLook.col(key)
	p.color_changed.connect(func(c: Color):
		WorldLook.settings()[key] = [c.r, c.g, c.b]
		_look_changed())
	row.add_child(p)

func _lk_flag(parent: Control, label: String, key: String) -> void:
	var row := HBoxContainer.new(); parent.add_child(row)
	var l := _labeled(label); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var c := CheckButton.new()
	c.button_pressed = WorldLook.flag(key)
	c.toggled.connect(func(on):
		WorldLook.settings()[key] = on
		_look_changed())
	row.add_child(c)

func _lk_opt(parent: Control, label: String, key: String, options: Array) -> void:
	parent.add_child(_labeled(label))
	var o := OptionButton.new()
	for nm in options:
		o.add_item(str(nm))
	o.selected = maxi(0, options.find(WorldLook.text(key)))
	o.item_selected.connect(func(i):
		WorldLook.settings()[key] = options[i]
		_look_changed())
	parent.add_child(o)

func _build_look_panel() -> void:
	var dock := _make_dock("look", "💡 WORLD LOOK", _ui_layer, _rpanel.theme)
	_look_panel = _docks["look"]["panel"]
	_look_panel.anchor_left = 1.0; _look_panel.anchor_right = 1.0
	_look_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_look_panel.offset_right = -200.0; _look_panel.offset_top = 8.0
	_dock_snapshot("look")
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(228, 520)
	dock.add_child(sc)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 2)
	sc.add_child(vb)
	vb.add_child(_section("sun & moon"))
	_lk_num(vb, "sun energy (day)", "sun_day_energy", 0.2, 3.0)
	_lk_num(vb, "sun energy (night)", "sun_night_energy", 0.0, 1.0)
	_lk_col(vb, "sun color", "sun_warm")
	_lk_col(vb, "moon color", "moon")
	vb.add_child(_section("ambient"))
	_lk_num(vb, "ambient (day)", "ambient_day_energy", 0.0, 1.5)
	_lk_num(vb, "ambient (night)", "ambient_night_energy", 0.0, 1.5)
	_lk_col(vb, "ambient day", "ambient_day")
	_lk_col(vb, "ambient night", "ambient_night")
	vb.add_child(_section("sky"))
	_lk_col(vb, "sky top (day)", "sky_top_day")
	_lk_col(vb, "horizon (day)", "sky_hor_day")
	_lk_col(vb, "sky top (night)", "sky_top_night")
	_lk_col(vb, "horizon (night)", "sky_hor_night")
	vb.add_child(HSeparator.new())
	vb.add_child(_section("ground"))
	_lk_col(vb, "grass (low)", "ground_grass_low")
	_lk_col(vb, "grass (high)", "ground_grass_high")
	_lk_col(vb, "dirt", "ground_dirt")
	_lk_col(vb, "sand", "ground_sand")
	_lk_col(vb, "rock", "ground_rock")
	_lk_num(vb, "texture tiling", "mat_tile", 0.1, 2.0)
	vb.add_child(HSeparator.new())
	vb.add_child(_section("post"))
	_lk_opt(vb, "tonemap", "tonemap", ["agx", "filmic", "aces", "reinhard"])
	_lk_num(vb, "exposure", "exposure", 0.2, 3.0)
	_lk_flag(vb, "glow / bloom", "glow")
	_lk_flag(vb, "indirect (SSIL)", "ssil")
	_lk_flag(vb, "global illum (SDFGI)", "sdfgi")
	_lk_num(vb, "foliage variation", "foliage_variation", 0.0, 0.4)
	_lk_num(vb, "blade texture detail", "foliage_detail", 0.0, 1.5)
	_lk_num(vb, "god rays (sun in fog)", "godray", 0.0, 4.0)
	vb.add_child(HSeparator.new())
	vb.add_child(_section("color grade"))
	_lk_num(vb, "brightness", "brightness", 0.5, 1.5)
	_lk_num(vb, "contrast", "contrast", 0.5, 1.5)
	_lk_num(vb, "saturation", "saturation", 0.0, 2.0)
	var brow := HBoxContainer.new(); vb.add_child(brow)
	var save_b := Button.new(); save_b.text = "💾 Save look"
	save_b.pressed.connect(func():
		WorldLook.save(WorldLook.settings())
		_flash("look saved — the runtime will match"))
	brow.add_child(save_b)
	var reset_b := Button.new(); reset_b.text = "↺ Defaults"
	reset_b.pressed.connect(func():
		WorldLook._cached = WorldLook.DEFAULTS.duplicate(true)
		_look_changed()
		_look_panel.queue_free(); _look_panel = null
		_toggle_look_panel()
		_flash("look reset (Save to keep)"))
	brow.add_child(reset_b)

# CHARACTER MODE — AvatarMotor drives a capsule against the TerrainCollider
var _char_motor: AvatarMotor = null
var _char_body: CharacterBody3D = null
var _char_vis: Node3D = null
var _char_world: Node3D = null     # terrain + block colliders, freed on exit
var _char_prev_dist := 0.0
var _char_prev_pitch := 0.0

func _char_enter() -> void:
	# Physics world (heightfield + blocks/stairs), built fresh since edits are disabled here.
	_char_world = Node3D.new()
	add_child(_char_world)
	var w := Config.GRID_COLS + 1
	var d := Config.GRID_ROWS + 1
	var heights := PackedFloat32Array()
	heights.resize(w * d)
	for z in d:
		for x in w:
			heights[z * w + x] = _height(float(x), float(z))
	var built := TerrainCollider.build(heights, w, d)
	_char_world.add_child(built[0])
	# The avatar: AvatarMotor body recipe + a simple readable figure.
	_char_motor = AvatarMotor.new()
	_char_body = AvatarMotor.make_body(0.62)
	add_child(_char_body)
	var vp := get_viewport().get_visible_rect().size
	var ro := cam.project_ray_origin(Vector2(vp.x * 0.5, vp.y * 0.78))
	var rd := cam.project_ray_normal(Vector2(vp.x * 0.5, vp.y * 0.78))
	var at := Vector3(cam.global_position.x, 0.0, cam.global_position.z)
	var rt := 0.0
	while rt < 4000.0:
		var pp := ro + rd * rt
		if pp.y <= _height(pp.x, pp.z):
			at = pp
			break
		rt += 2.0
	at.x = clampf(at.x, 1.0, float(Config.GRID_COLS - 1))
	at.z = clampf(at.z, 1.0, float(Config.GRID_ROWS - 1))
	_char_body.global_position = Vector3(at.x, _height(at.x, at.z) + 0.4, at.z)
	_char_vis = Node3D.new()
	var cap := MeshInstance3D.new()
	var cm := CapsuleMesh.new(); cm.radius = 0.17; cm.height = 0.62
	cap.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.5, 0.85)
	cap.material_override = mat
	cap.position = Vector3(0, 0.31, 0)
	_char_vis.add_child(cap)
	var nose := MeshInstance3D.new()
	var nb := BoxMesh.new(); nb.size = Vector3(0.1, 0.1, 0.14)
	nose.mesh = nb
	nose.material_override = mat
	nose.position = Vector3(0, 0.5, -0.2)
	_char_vis.add_child(nose)
	add_child(_char_vis)
	var cfwd := Vector3(-sin(cam_yaw), 0.0, -cos(cam_yaw))
	_char_vis.rotation.y = atan2(-cfwd.x, -cfwd.z)
	_char_prev_dist = cam_dist
	_char_prev_pitch = cam_pitch
	_char_from_focus = focus
	_char_from_dist = cam_dist
	_char_from_pitch = cam_pitch
	_char_blend = 0.0
	# FPV controls: lock the cursor, the mouse aims the camera (Esc/E exits).
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_ghost_hide()
	_ring.visible = false
	WindRig.max_dist = chase_draw_dist
	_sun.directional_shadow_max_distance = chase_shadow_dist
	_flash("WASD run · mouse look · Space jump · Esc/E exit")

func _char_exit() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	WindRig.max_dist = 90.0
	_sun.directional_shadow_max_distance = orbit_shadow_dist
	for n in [_char_world, _char_body, _char_vis]:
		if n != null and is_instance_valid(n): n.queue_free()
	_char_world = null; _char_body = null; _char_vis = null; _char_motor = null
	cam_dist = _char_prev_dist
	cam_pitch = _char_prev_pitch
	_update_cam()

## Per-physics-tick: camera-relative WASD + Space, straight into the motor.
func _char_tick(delta: float) -> void:
	if _char_body == null or not is_instance_valid(_char_body):
		return
	if Input.is_physical_key_pressed(KEY_SPACE):
		_char_motor.press_jump()
	# WASD mapping via ChaseCamControl.
	var dir := ChaseCamControl.move_dir(cam_yaw, ChaseCamControl.wasd())
	var sprinting := Input.is_physical_key_pressed(KEY_SHIFT)
	_char_motor.tick(_char_body, delta, dir, sprinting)
	_char_vis.global_position = _char_body.global_position
	if dir.length() > 0.1:
		_char_vis.rotation.y = atan2(-dir.x, -dir.z)
	if _char_blend < 1.0:
		_char_blend = minf(1.0, _char_blend + delta / 1.1)
		var k := smoothstep(0.0, 1.0, _char_blend)
		focus = _char_from_focus.lerp(_char_body.global_position, k)
		cam_dist = lerpf(_char_from_dist, ChaseCamControl.DIST_DEFAULT, k)
		cam_pitch = lerpf(_char_from_pitch, 0.45, k)
	else:
		focus = _char_body.global_position
	_update_cam()

func _physics_process(delta: float) -> void:
	if mode == MODE_CHAR:
		_char_tick(delta)

## Minimap markers: my view (white + frustum footprint).
func _mini_draw() -> void:
	var s := _mini_rect.size
	var me := Vector2(focus.x / Config.GRID_COLS, focus.z / Config.GRID_ROWS) * s
	var vps := get_viewport().get_visible_rect().size
	var reach := clampf(cam_dist * 3.0, 12.0, Config.GRID_COLS * 0.7)
	var quad := PackedVector2Array()
	for c in [Vector2(0.02, 0.98), Vector2(0.98, 0.98), Vector2(0.98, 0.02), Vector2(0.02, 0.02)]:
		var ro := cam.project_ray_origin(c * vps)
		var rd := cam.project_ray_normal(c * vps)
		var t := reach
		if rd.y < -0.001:
			t = minf(t, (focus.y - ro.y) / rd.y)
		var gp := ro + rd * t
		quad.append((Vector2(gp.x / Config.GRID_COLS, gp.z / Config.GRID_ROWS) * s)
			.clamp(Vector2.ZERO, s))   # never spill past the map edges
	for i in 4:
		_mini_marks.draw_line(quad[i], quad[(i + 1) % 4], Color(1, 1, 1, 0.55), 1.0)
	_mini_marks.draw_circle(me, 3.5, Color(1, 1, 1, 0.9))
func _toggle_ortho() -> void:
	_ortho = not _ortho
	if _ortho:
		_ortho_prev_pitch = cam_pitch
		cam_pitch = deg_to_rad(89.0)
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	else:
		cam_pitch = _ortho_prev_pitch
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	_update_cam()
	_flash("top-down ortho (O toggles)" if _ortho else "perspective")

func _ungroup_sel() -> void:
	var members := _sel_members()
	if members.size() <= 1:
		_flash("select a grouped build first")
		return
	var uids: Array = []
	var prev: Array = []
	for i in members:
		uids.append(int(_objects[i].get("uid", -1)))
		prev.append(int(_objects[i].get("group", 0)))
	_apply_group(uids, 0)
	_undo_push({"op": "group", "uids": uids, "prev": prev})
	if _ungroup_btn != null: _ungroup_btn.disabled = true
	_update_sel_ring()
	_pop_sound(true)
	_flash("ungrouped 🔓 (%d pieces move separately)" % uids.size())

func _remove_existing_start() -> void:
	for i in range(_objects.size() - 1, -1, -1):
		if str(_objects[i].get("kind", "")) == "start": _remove_at(i)

## A grey question-mark box where a model isn't available. The ENTRY survives in
func _missing_asset_stub(entry: Dictionary, x: float, gy: float, z: float) -> Node3D:
	var holder := Node3D.new()
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(0.8, 0.8, 0.8)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.45, 0.45, 0.5)
	mi.material_override = m
	mi.position = Vector3(0, 0.4, 0)
	holder.add_child(mi)
	var lbl := Label3D.new()
	lbl.text = "? " + str(entry.get("type", entry.get("kind", "")))
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size = 24; lbl.pixel_size = 0.01
	lbl.position = Vector3(0, 1.2, 0)
	holder.add_child(lbl)
	add_child(holder)
	holder.position = Vector3(x, gy, z)
	holder.rotation.y = float(entry.get("rot", 0.0))
	return holder

func _spawn(entry: Dictionary) -> Node3D:
	var x := float(entry["x"]); var z := float(entry["z"])
	var gy := _height(x, z) + float(entry.get("y_off", 0.0))
	match str(entry["kind"]):
		"box":
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new(); bm.size = Vector3(1, 1, 1)
			mi.mesh = bm
			mi.position = Vector3(x, gy + 0.5, z)
			mi.rotation.y = float(entry.get("rot", 0.0))
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(str(entry.get("color", "ffffff")))
			mi.material_override = m
			add_child(mi)
			return mi
		"start":
			return _spawn_start_marker(x, gy, z)
		"water_src":
			var ws := MeshInstance3D.new()
			var wb := BoxMesh.new(); wb.size = Vector3(0.5, 0.5, 0.5)
			ws.mesh = wb
			var wm := StandardMaterial3D.new()
			wm.albedo_color = Color(0.3, 0.65, 1.0, 0.9)
			wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			wm.emission_enabled = true
			wm.emission = Color(0.25, 0.55, 0.95)
			wm.emission_energy_multiplier = 1.6
			ws.material_override = wm
			add_child(ws)
			ws.position = Vector3(x, float(entry.get("y", gy)), z)
			return ws
		_:
			# Unknown / legacy object kinds — render a grey stub so older maps still load.
			return _missing_asset_stub(entry, x, gy, z)
	return null

func _spawn_start_marker(x: float, gy: float, z: float) -> Node3D:
	var holder := Node3D.new(); add_child(holder); holder.position = Vector3(x, gy, z)
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.3, 0.9, 1.0)
	mat.emission_enabled = true; mat.emission = Color(0.3, 0.9, 1.0); mat.emission_energy_multiplier = 2.0
	var pole := MeshInstance3D.new()
	var cyl := CylinderMesh.new(); cyl.top_radius = 0.12; cyl.bottom_radius = 0.12; cyl.height = 4.0
	pole.mesh = cyl; pole.position = Vector3(0, 2.0, 0); pole.material_override = mat; holder.add_child(pole)
	var ball := MeshInstance3D.new()
	var sp := SphereMesh.new(); sp.radius = 0.5; sp.height = 1.0
	ball.mesh = sp; ball.position = Vector3(0, 4.3, 0); ball.material_override = mat; holder.add_child(ball)
	return holder

func _delete_nearest(p: Vector3) -> void:
	var best := -1; var bd := 9.0
	for i in _spawned.size():
		var n: Node3D = _spawned[i]
		if not is_instance_valid(n): continue
		var d := Vector2(n.position.x - p.x, n.position.z - p.z).length_squared()
		if d < bd: bd = d; best = i
	if best >= 0:
		_undo_push({"op": "remove", "entry": (_objects[best] as Dictionary).duplicate(true)})
		_remove_uid(int(_objects[best].get("uid", -1)))
		_refresh_status()

func _remove_at(i: int) -> void:
	if is_instance_valid(_spawned[i]): _spawned[i].queue_free()
	for t in _obj_tiles[i]: _occupied.erase(t)
	match str(_objects[i].get("kind", "")):
		"water_src":
			if _water_sim != null:
				_water_sim.remove_source(WaterSim.cell_of(Vector3(
					float(_objects[i]["x"]), float(_objects[i].get("y", 0.0)), float(_objects[i]["z"]))))
	_spawned.remove_at(i); _objects.remove_at(i); _obj_tiles.remove_at(i)
	var fixed: Array = []
	for s in _sel:
		if int(s) == i: continue
		fixed.append(int(s) - 1 if int(s) > i else int(s))
	_sel = fixed
	if _sel_idx == i: _sel_idx = _sel[0] if not _sel.is_empty() else -1
	elif _sel_idx > i: _sel_idx -= 1

## Clear brush: remove every object within the brush.
func _erase_area(p: Vector3, rad: float = -1.0) -> void:
	if rad < 0.0: rad = brush_radius
	var r2 := rad * rad
	var removed := false
	for i in range(_spawned.size() - 1, -1, -1):
		var n: Node3D = _spawned[i]
		if not is_instance_valid(n): continue
		if Vector2(n.position.x - p.x, n.position.z - p.z).length_squared() <= r2:
			_remove_at(i); removed = true
	if removed:
		_refresh_status()
		# A knock per sweep, not per frame — skip if the last one is still sounding.
		if _sfx_remove != null and not _sfx_remove.playing:
			_pop_sound(true)

## Round material chip from a texture PNG: centre crop, Lanczos downscale, anti-aliased circular mask.
func _mat_icon(path: String, size: int) -> ImageTexture:
	if not ResourceLoader.exists(path):
		return null
	var im: Image = (load(path) as Texture2D).get_image()
	if im == null:
		return null
	if im.is_compressed(): im.decompress()
	var w := im.get_width(); var h := im.get_height()
	var cs := clampi(int(round(minf(w, h) * 0.25)), 64, mini(w, h))
	var ox := (w - cs) / 2; var oy := (h - cs) / 2
	var ss := size * 2
	var patch := Image.create(cs, cs, false, im.get_format())
	patch.blit_rect(im, Rect2i(ox, oy, cs, cs), Vector2i.ZERO)
	patch.resize(ss, ss, Image.INTERPOLATE_LANCZOS)
	patch.convert(Image.FORMAT_RGBA8)
	var c := (ss - 1) * 0.5
	var r := ss * 0.5
	for y in ss:
		for x in ss:
			var dx := x - c; var dy := y - c
			var dist := sqrt(dx * dx + dy * dy)
			var px := patch.get_pixel(x, y)
			if dist > r - r * 0.10 and dist <= r - 1.0:
				px = px.darkened(0.45)
			px.a = clampf(r - dist, 0.0, 2.0) / 2.0
			patch.set_pixel(x, y, px)
	patch.resize(size, size, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(patch)

# --- save / load ------------------------------------------------------------

func _save() -> void:
	# Automated runs (--shot/--test*/--mergecheck) must NEVER touch the real world files.
	for a in OS.get_cmdline_args():
		if a == "--shot" or str(a).begins_with("--test") or str(a).begins_with("--mergecheck"):
			return
	var hm_out := hm_img.duplicate() as Image
	hm_out.convert(Image.FORMAT_RGB8)
	hm_out.save_png(_mp(MapStore.F_HM))
	WorldFile.mark_heightmap_current()
	bm_img.save_png(_mp(MapStore.F_BM))
	wm_img.save_png(_mp(MapStore.F_WM))
	sid_img.save_png(_mp(MapStore.F_SM))
	SmartMaterial.save_all(_mp(MapStore.F_SMART), smart_mats)
	_write_entries(_mp(MapStore.F_OBJ), _objects)
	print("SAVED terrain+biome+", _objects.size(), " objects -> ", ProjectSettings.globalize_path(_mp(MapStore.F_OBJ)))
	_refresh_status("SAVED ✔ (%d objects)" % _objects.size())

func _load_objects() -> void:
	var data := _read_entries(_mp(MapStore.F_OBJ))
	for e in data:
		if not (e is Dictionary) or not e.has("kind"): continue
		if not e.has("uid"):
			# Legacy entries get NEGATIVE uids — can't collide with live (positive) placements.
			e["uid"] = -(_objects.size() + 1)
		var node := _spawn(e)
		if node != null:
			var tiles := _tiles_for(e)
			for t in tiles: _occupied[t] = true
			_objects.append(e); _spawned.append(node); _obj_tiles.append(tiles)

# --- input / loop -----------------------------------------------------------

## True when the mouse is over ANY dock, so clicks/wheel never leak into the world.
func _over_ui() -> bool:
	if not _dock_drag.is_empty():
		return true
	var mp := get_viewport().get_mouse_position()
	for id in _docks:
		var p: PanelContainer = _docks[id]["panel"]
		if p != null and p.visible and p.get_global_rect().has_point(mp):
			return true
	return false

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if _over_ui(): return
		if filter != null and e.pressed: filter.release_focus()
		if mode == MODE_SELECT and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] \
				and (e.ctrl_pressed or e.alt_pressed):
			if e.pressed and _sel_idx >= 0:
				var sdir := 1.0 if e.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
				if e.ctrl_pressed: _rotate_sel(sdir * deg_to_rad(15.0))
				else: _elevate_sel(sdir * 0.5)
			return
		match e.button_index:
			MOUSE_BUTTON_LEFT:  _paint = 1 if e.pressed else 0
			MOUSE_BUTTON_RIGHT: _paint = -1 if e.pressed else 0
			MOUSE_BUTTON_MIDDLE: _orbit = e.pressed
			MOUSE_BUTTON_WHEEL_UP:
				if mode == MODE_PLACE and e.ctrl_pressed:
					_place_rot = fmod(_place_rot + deg_to_rad(15.0), TAU)
					_place_rot_explicit = true
				elif e.alt_pressed: brush_radius = minf(40.0, brush_radius + 1.0); _flash("size %.0f" % brush_radius); _refresh_status()
				elif e.ctrl_pressed: brush_strength = mini(100, brush_strength + 1); _flash("str %d" % brush_strength); _refresh_status()
				elif mode == MODE_CHAR:
					cam_dist = ChaseCamControl.zoom(cam_dist, -1.0); _update_cam()
				else:
					_zoom_step(true, e.shift_pressed)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mode == MODE_PLACE and e.ctrl_pressed:
					_place_rot = fmod(_place_rot - deg_to_rad(15.0) + TAU, TAU)
					_place_rot_explicit = true
				elif e.alt_pressed: brush_radius = maxf(1.0, brush_radius - 1.0); _flash("size %.0f" % brush_radius); _refresh_status()
				elif e.ctrl_pressed: brush_strength = maxi(1, brush_strength - 1); _flash("str %d" % brush_strength); _refresh_status()
				elif mode == MODE_CHAR:
					cam_dist = ChaseCamControl.zoom(cam_dist, 1.0); _update_cam()
				else:
					_zoom_step(false, e.shift_pressed)
		if mode == MODE_SELECT and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and not _over_ui():
			if e.shift_pressed:
				_selbox_a = _pick()
				_selbox_screen = e.position
			elif e.ctrl_pressed:
				var psc = _pick()
				if psc != null: _select_click(psc, true)
			else:
				var psl = _pick()
				if psl != null: _select_click(psl)
		if mode == MODE_SELECT and (not e.pressed) and e.button_index == MOUSE_BUTTON_LEFT:
			_dragging_sel = false
			if _selbox_a != null:
				var b = _pick()
				if b == null: b = _selbox_b   # released off-terrain → commit with the last drawn corner
				if _area_box != null: _area_box.visible = false
				if e.position.distance_to(_selbox_screen) < 6.0:
					# barely moved → it was an additive CLICK, not a box
					if b != null: _select_click(b, true)
				elif b != null:
					_selbox_commit(_selbox_a, b)
				_selbox_a = null
				_selbox_b = null
		if mode == MODE_SELECT and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
			_deselect(); _refresh_status("deselected")
		if (mode == MODE_PLACE) and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
			var p = _pick()
			if p != null: _delete_nearest(p)
		if mode == MODE_AREA and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				_area_a = _pick()
			elif _area_a != null:
				_area_commit()
		if mode == MODE_BIOME and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT and not _over_ui():
			var pb = _pick()
			if pb != null: _pick_biome(pb)
	elif e is InputEventMouseMotion and mode == MODE_CHAR \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		cam_yaw = ChaseCamControl.look_yaw(cam_yaw, e.relative.x)
		cam_pitch = ChaseCamControl.look_pitch(cam_pitch, e.relative.y)
		_update_cam()
	elif e is InputEventMouseMotion and _orbit:
		var in_place := Input.is_key_pressed(KEY_SHIFT) and not _ortho
		var eye := cam.global_position
		cam_yaw -= e.relative.x * 0.005
		# Top-down ortho stays top-down: orbit only turns, never tilts.
		if not _ortho:
			var lo := (-1.45 if in_place else 0.15)
			cam_pitch = clampf(cam_pitch - e.relative.y * 0.005, lo, 1.5)
		if in_place:
			var udir := Vector3(sin(cam_yaw) * cos(cam_pitch), sin(cam_pitch), cos(cam_yaw) * cos(cam_pitch))
			focus = eye - udir * cam_dist
		_update_cam()
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_BRACKETLEFT:
				brush_radius = maxf(1.0, brush_radius - 1.0); _flash("size %.0f" % brush_radius)
				_refresh_status()
			KEY_BRACKETRIGHT:
				brush_radius = minf(40.0, brush_radius + 1.0); _flash("size %.0f" % brush_radius)
				_refresh_status()
			KEY_MINUS: brush_strength = maxi(1, brush_strength - 1); _flash("str %d" % brush_strength); _refresh_status()
			KEY_EQUAL: brush_strength = mini(100, brush_strength + 1); _flash("str %d" % brush_strength); _refresh_status()
			KEY_G:
				_toggle_grid()
			KEY_F3:
				_perf_detail = not _perf_detail
				_flash("perf detail " + ("ON" if _perf_detail else "off"))
			KEY_ESCAPE:
				if mode != MODE_SELECT:
					if _select_btn != null: _select_btn.set_pressed_no_signal(true)
					_set_mode(MODE_SELECT)
					_flash("Select mode")
				else:
					_deselect(); _refresh_status("deselected")
			KEY_E:
				if mode == MODE_CHAR:
					if _select_btn != null: _select_btn.set_pressed_no_signal(true)
					_set_mode(MODE_SELECT)
					_flash("Select mode")
			KEY_F5:
				_dev_reload()
			KEY_Z:
				if e.ctrl_pressed:
					_undo_last()
			KEY_D:
				if e.ctrl_pressed and mode == MODE_SELECT:
					_duplicate_sel()
			KEY_DELETE, KEY_BACKSPACE:
				if mode == MODE_SELECT:
					_delete_sel()
			KEY_R:
				if mode == MODE_SELECT:
					_rotate_sel(deg_to_rad(15.0))
				elif mode == MODE_PLACE:
					_place_rot = fmod(_place_rot + deg_to_rad(15.0), TAU)
					_place_rot_explicit = true
			KEY_F:
				_frame_selection()
			KEY_T:
				if mode == MODE_SELECT:
					_reseat_sel()
			KEY_O:
				_toggle_ortho()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0:
				var order := [MODE_SELECT, MODE_SCULPT, MODE_FLATTEN, MODE_MATCH, MODE_SETELEV,
					MODE_NOISE, MODE_BIOME, MODE_PLACE, MODE_ERASE]
				var idx: int = 9 if e.keycode == KEY_0 else int(e.keycode - KEY_1)
				_hotkey_mode(order[idx])
			KEY_F11:
				var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
				DisplayServer.window_set_mode(
					DisplayServer.WINDOW_MODE_MAXIMIZED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)
				_flash("windowed (F11 toggles)" if fs else "fullscreen (F11 toggles)")

func _process(dt: float) -> void:
	if _fps_lbl != null:
		var fps := Engine.get_frames_per_second()
		var txt := "%d FPS   %.1f ms" % [fps, 1000.0 / maxf(1.0, fps)]
		if _perf_detail:
			txt += "\ndraw %d   obj %d\nprim %d\nvram %.0f MB" % [
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0]
		_fps_lbl.text = txt
	_maybe_flush_smart_reapply()
	WindRig.view_pos = cam.global_position
	WindRig.view_set = true
	if not _over_ui():
		var foc := get_viewport().gui_get_focus_owner()
		if foc != null:
			foc.release_focus()
	var b := cam.global_transform.basis
	var fwd := -b.z; fwd.y = 0.0; fwd = fwd.normalized()
	var right := b.x; right.y = 0.0; right = right.normalized()
	var mv := Vector3.ZERO
	var fo := get_viewport().gui_get_focus_owner()
	var typing := fo is LineEdit or fo is TextEdit
	# Ctrl is a shortcut modifier (Ctrl+D duplicate, Ctrl+Z undo) — never pan.
	if not typing and not Input.is_key_pressed(KEY_CTRL) and mode != MODE_CHAR:
		if Input.is_key_pressed(KEY_W): mv += fwd
		if Input.is_key_pressed(KEY_S): mv -= fwd
		if Input.is_key_pressed(KEY_D): mv += right
		if Input.is_key_pressed(KEY_A): mv -= right
	if mv != Vector3.ZERO: focus += mv.normalized() * dt * maxf(cam_dist, 30.0) * 0.8; _update_cam()
	if not typing and mode != MODE_CHAR:
		if Input.is_key_pressed(KEY_Q): cam_yaw += dt * 1.5; _update_cam()
		if Input.is_key_pressed(KEY_E): cam_yaw -= dt * 1.5; _update_cam()
	if _flash_t > 0.0 and _toast_panel != null:
		_flash_t -= dt
		_toast_panel.modulate.a = clampf(_flash_t / 0.5, 0.0, 1.0)
		if _flash_t <= 0.0: _toast_panel.visible = false
	# Re-drape the yellow slope grid after sculpting (throttled so dragging stays smooth).
	if _grid_dirty and _grid != null and _grid.visible:
		_grid_t -= dt
		if _grid_t <= 0.0:
			_grid_t = 0.25
			_build_grid()
	if mode == MODE_SELECT:
		_ring.visible = false
		if _selbox_a != null and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var sb = _pick()
			if sb != null:
				_selbox_b = sb
				_draw_area_box(_selbox_a, sb)
		elif _dragging_sel and not _over_ui() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_sel_hold += dt
			if _sel_hold >= SEL_DRAG_DELAY:
				var psel = _pick()
				if psel != null: _move_sel_to(psel)
		_update_sel_ring()
	elif mode == MODE_PLACE:
		_ring.visible = false
		# Hold LMB to stamp objects repeatedly, spaced out so they don't pile up.
		if not _over_ui() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var pp = _pick()
			if pp != null and (_last_place_pos == null or pp.distance_to(_last_place_pos) >= PLACE_SPACING):
				_place(pp)
				_last_place_pos = pp
		else:
			_last_place_pos = null
	elif mode == MODE_AREA:
		_ring.visible = false
		_area_update()
	elif mode == MODE_CHAR:
		_ring.visible = false
	else:
		var p = _pick()
		# Poll the real mouse state (don't trust a latched flag — a release over the
		var act := 0
		if not _over_ui():
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): act = 1
			elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT): act = -1
		if p != null:
			_ring.visible = true
			_ring.position = Vector3(p.x, p.y + 0.3, p.z)
			_ring.scale = Vector3(brush_radius, 1.0, brush_radius)
			var rc := Color(0.95, 0.2, 0.15)
			if mode == MODE_FLATTEN: rc = Color(0.25, 0.6, 0.95)
			elif mode == MODE_BIOME: rc = Color(1.0, 0.9, 0.1)
			elif mode == MODE_NOISE: rc = Color(0.5, 0.95, 0.3)
			_ring.visible = brush_opacity > 0.001
			_ring_mat.albedo_color = Color(rc.r, rc.g, rc.b, clampf(brush_opacity, 0.0, 1.0) * 0.7)
			_ring_mat.emission = rc
			_ring_mat.emission_enabled = brush_opacity > 0.001
			_ring_mat.emission_energy_multiplier = brush_opacity * 0.6
			if act != 0:
				if mode == MODE_SCULPT: _brush("sculpt", p, act)
				elif mode == MODE_FLATTEN: _brush("flatten", p, act)
				elif mode == MODE_NOISE: _brush("noise", p, act)
				elif mode == MODE_MATCH: _brush("match", p, act)
				elif mode == MODE_SETELEV: _brush("setelev", p, act, (target_elev - HM_MIN) / (HM_MAX - HM_MIN))
				elif mode == MODE_ERASE:
					if _objects_visible: _brush("erase", p, act)   # can't erase what you hid
				elif mode == MODE_BIOME and act > 0:
					if smart_on and smart_mats.size() > 0:
						_brush("smart", p, act, float(smart_sel))
					else:
						_brush("biome", p, act, float(biome_index))
		else:
			_ring.visible = false
	if not _dirty_chunks.is_empty():
		for c in _dirty_chunks:
			_rebuild_chunk(c)
		_dirty_chunks.clear()
	_dock_drag_tick()
	_update_cursor_hover()
	_update_ghost()
	# Cursor readout (throttled), minimap repaint, ping countdown.
	_readout_t -= dt
	if _readout_t <= 0.0:
		_readout_t = 0.1
		if _readout_lbl != null:
			var rp = _pick() if _readout_on and not _over_ui() else null
			_readout_lbl.visible = rp != null
			if rp != null:
				_readout_lbl.text = "x %d · z %d · h %.1f" % [int(rp.x), int(rp.z), _height(rp.x, rp.z)]
	_mini_t -= dt
	if _mini_t <= 0.0:
		_mini_t = 1.5
		if _mini_dirty and _mini_rect != null:
			_mini_dirty = false
			_mini_rebuild()
	if _mini_marks != null:
		_mini_marks.queue_redraw()
	# Flowing water: lazy solid-cell rebuild when blocks changed, then one tick.
	if _water_sim != null:
		_water_sim.tick(dt)

func _pick():
	var mp := get_viewport().get_mouse_position()
	var o := cam.project_ray_origin(mp); var dir := cam.project_ray_normal(mp); var t := 0.0
	while t < 800.0:
		var p := o + dir * t
		if p.y <= _height(p.x, p.z): return p
		t += 1.0
	return null

## One proportional wheel-zoom step (scaled by the zoom-speed slider); softens near the ground, Shift zooms gently.
func _zoom_step(zoom_in: bool, shift: bool) -> void:
	var rate := 0.0825 * zoom_speed
	if zoom_in:
		var d2 := cam_dist * pow(1.0 - rate, 2.0)
		var off := Vector3(sin(cam_yaw) * cos(cam_pitch), sin(cam_pitch), cos(cam_yaw) * cos(cam_pitch))
		var p2 := focus + off * d2
		if p2.y <= _height(p2.x, p2.z) + 0.5:
			rate *= 0.3
	if shift:
		rate *= 0.3
	if zoom_in:
		cam_dist = maxf(2.0, cam_dist * (1.0 - rate))
		focus.y *= 0.85
	else:
		cam_dist = minf(1200.0, cam_dist * (1.0 + rate))
	_update_cam()

var _char_eff_dist := 0.0

func _update_cam() -> void:
	var udir := Vector3(sin(cam_yaw) * cos(cam_pitch), sin(cam_pitch), cos(cam_yaw) * cos(cam_pitch))
	cam.far = chase_draw_dist if mode == MODE_CHAR else (300.0 if _low_cost else orbit_draw_dist)
	if mode == MODE_CHAR:
		# Pitch/yaw stay LOCKED. When terrain would intrude, pull the camera IN toward the runner
		var dist := cam_dist
		while dist > 0.15:
			var probe := focus + udir * dist
			if probe.y > _height(probe.x, probe.z) + 0.3:
				break
			dist -= 0.2
		dist = maxf(dist, 0.05)
		if _char_eff_dist <= 0.0:
			_char_eff_dist = dist
		_char_eff_dist = lerpf(_char_eff_dist, dist, 0.35)   # glide, don't snap
		cam.global_position = focus + udir * _char_eff_dist
		# Hard floor: never let the chase cam sink under the terrain. Looking up swings the camera
		var gy := _height(cam.global_position.x, cam.global_position.z) + 0.35
		if cam.global_position.y < gy:
			cam.global_position.y = gy
		cam.look_at(cam.global_position - udir, Vector3.UP)
	else:
		cam.global_position = focus + udir * cam_dist
		cam.look_at(focus, Vector3.UP)
	if _ortho:
		cam.size = cam_dist

func _aabb(root: Node3D) -> AABB:
	var res := AABB(); var first := true; var stack: Array = [root]
	while stack.size() > 0:
		var n = stack.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var mi := n as MeshInstance3D
			var rel: Transform3D = root.global_transform.affine_inverse() * mi.global_transform
			var a: AABB = rel * mi.get_aabb()
			if first: res = a; first = false
			else: res = res.merge(a)
		for c in n.get_children(): stack.append(c)
	return res

func _mat_name(i: int) -> String:
	if i >= 0 and i < Config.GROUND_MATERIALS.size(): return str(Config.GROUND_MATERIALS[i]).capitalize()
	return "?"

## Lean status: the MODE plus contextual state. Keybinds live behind the
func _refresh_status(_arg = null) -> void:
	if status == null: return
	status.text = str(MODE_NAMES.get(mode, "?"))
	_update_sel_info()

## Top-of-dock readout for the current selection: id / name / world XYZ.
func _update_sel_info() -> void:
	if _sel_info == null: return
	if _sel_idx < 0 or _sel_idx >= _objects.size():
		_sel_info.text = "(nothing selected)"
		return
	var e: Dictionary = _objects[_sel_idx]
	var nm := str(e.get("model", e.get("type", e.get("kind", "—")))).get_file()
	var x := float(e.get("x", 0.0)); var z := float(e.get("z", 0.0))
	var y := float(e.get("y", _height(x, z) + float(e.get("y_off", 0.0))))
	var more := ("  (+%d more)" % (_sel.size() - 1)) if _sel.size() > 1 else ""
	_sel_info.text = "ID %s · %s%s\nX %.1f   Y %.2f   Z %.1f" % [str(e.get("uid", "?")), nm, more, x, y, z]

const _CH := "[color=#e0b54e][b]"
const _CK := "[cell][color=#8fa9c4]"
const _CV := "[/color][/cell][cell]"
const _CE := "[/cell]"
const CONTROLS_TEXT := _CH + "GENERAL / CAMERA[/b][/color]\n[table=2]" \
	+ _CK + "WASD " + _CV + "pan" + _CE \
	+ _CK + "Q / E " + _CV + "turn" + _CE \
	+ _CK + "MMB drag " + _CV + "orbit" + _CE \
	+ _CK + "Shift+MMB " + _CV + "rotate in place — eye stays put, look around incl. up at the sky" + _CE \
	+ _CK + "wheel " + _CV + "zoom  (Shift = gentle · auto-soft near the ground)" + _CE \
	+ _CK + "F / O / F11 " + _CV + "frame selection · top-down ortho · fullscreen" + _CE \
	+ _CK + "G " + _CV + "slope grid" + _CE \
	+ _CK + "Ctrl+Z " + _CV + "undo" + _CE \
	+ _CK + "Esc " + _CV + "back to Select / deselect" + _CE \
	+ _CK + "F5 / ⟳ " + _CV + "hot-reload the tools from disk" + _CE \
	+ _CK + "docks " + _CV + "TOOLS · 👁 LAYERS · 💡 WORLD LOOK · MAP  (drag the ⠿ bar to move)" + _CE \
	+ _CK + "RMB " + _CV + "brush opposite / deselect / delete (per tool) — NOT camera pan (brushes use it)" + _CE \
	+ "[/table]\n" + _CH + "BRUSHES[/b][/color]  [color=#778]Sculpt · Flatten · Noise · Match · SetElev · Drain · Material · Fog · Crayon[/color]\n[table=2]" \
	+ _CK + "LMB / RMB " + _CV + "apply / opposite (lower · refill · erase)" + _CE \
	+ _CK + "Alt+wheel " + _CV + "brush size   ([ ] too)" + _CE \
	+ _CK + "Ctrl+wheel " + _CV + "strength   (- = too; ramps hard near 100)" + _CE \
	+ _CK + "Material RMB " + _CV + "eyedrop the material under the cursor" + _CE \
	+ _CK + "Fog " + _CV + "LMB places the mist wall · RMB erases (binary)" + _CE \
	+ _CK + "Crayon " + _CV + "LMB draws the picked color · RMB erases" + _CE \
	+ "[/table]\n" + _CH + "SELECT[/b][/color]\n[table=2]" \
	+ _CK + "click " + _CV + "select · click again + hold to drag" + _CE \
	+ _CK + "Ctrl-click " + _CV + "add/remove one · Shift-drag = box-select" + _CE \
	+ _CK + "Ctrl+wheel " + _CV + "rotate      Alt+wheel raise/lower" + _CE \
	+ _CK + "R / T " + _CV + "rotate 15° / re-seat to the ground" + _CE \
	+ _CK + "Del · Ctrl+D " + _CV + "delete · duplicate" + _CE \
	+ _CK + "panel " + _CV + "Group/Ungroup · ⤓ Set ground / → type / All→ground · ☑ rotate in place" + _CE \
	+ "[/table]\n" + _CH + "PLACE[/b][/color]\n[table=2]" \
	+ _CK + "LMB " + _CV + "stamp (hold for a trail)" + _CE \
	+ _CK + "R / Ctrl+wheel " + _CV + "rotate the preview (else natural scatter)" + _CE \
	+ "[/table]\n" + _CH + "CHARACTER MODE[/b][/color]  [color=#778]the runner icon[/color]\n[table=2]" \
	+ _CK + "mouse " + _CV + "look (cursor locks — same feel as a game)" + _CE \
	+ _CK + "WASD " + _CV + "run · Shift sprint · Space jump" + _CE \
	+ _CK + "wheel " + _CV + "chase-camera distance" + _CE \
	+ _CK + "Esc / E " + _CV + "back to the tools" + _CE \
	+ "[/table]\n" + _CH + "HOTKEYS[/b][/color]\n[table=2]" \
	+ _CK + "1-0 " + _CV + "the tool row in order" + _CE \
	+ "[/table]"

var _controls_dlg: AcceptDialog = null
var _counts_dlg: AcceptDialog = null
var _counts_lbl: RichTextLabel = null

## Small-type RichTextLabel for the info dialogs — one polished look for both.
func _info_rich(min_size: Vector2) -> RichTextLabel:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.custom_minimum_size = min_size
	rt.add_theme_font_size_override("normal_font_size", 11)
	rt.add_theme_font_size_override("bold_font_size", 11)
	rt.add_theme_constant_override("table_h_separation", 14)
	rt.add_theme_constant_override("table_v_separation", 2)
	rt.add_theme_constant_override("line_separation", 1)
	return rt

func _show_controls() -> void:
	if _controls_dlg != null and _controls_dlg.visible:
		_controls_dlg.hide(); return
	if _controls_dlg == null:
		_controls_dlg = AcceptDialog.new()
		_controls_dlg.title = "Controls"
		_controls_dlg.ok_button_text = "Got it"
		var rt := _info_rich(Vector2(470, 480))
		rt.text = CONTROLS_TEXT
		_controls_dlg.add_child(rt)
		add_child(_controls_dlg)
	_controls_dlg.popup_centered()

func _show_counts() -> void:
	if _counts_dlg != null and _counts_dlg.visible:
		_counts_dlg.hide(); return
	if _counts_dlg == null:
		_counts_dlg = AcceptDialog.new()
		_counts_dlg.title = "What's in the world"
		_counts_dlg.ok_button_text = "Done"
		_counts_lbl = _info_rich(Vector2(300, 360))
		_counts_dlg.add_child(_counts_lbl)
		add_child(_counts_dlg)
	var per := {}
	for e in _objects:
		var k := str(e.get("type", e.get("kind", "?")))
		per[k] = int(per.get(k, 0)) + 1
	var keys := per.keys()
	keys.sort_custom(func(a, b): return int(per[a]) > int(per[b]))
	var txt := "[color=#e0b54e][b]%d objects · %d kinds[/b][/color]\n[table=2]" \
		% [_objects.size(), keys.size()]
	for k in keys:
		txt += "[cell][color=#e0b54e]%d[/color][/cell][cell]%s[/cell]" % [int(per[k]), str(k)]
	txt += "[/table]"
	_counts_lbl.text = txt
	_counts_dlg.popup_centered()

var _ghost: Node3D = null
var _ghost_key := ""
var _ghost_plate: MeshInstance3D = null
var _ghost_plate_mat: StandardMaterial3D = null

func _ghost_hide() -> void:
	if _ghost != null: _ghost.visible = false
	if _ghost_plate != null: _ghost_plate.visible = false

func _ghost_probe() -> Dictionary:
	if mode == MODE_PLACE:
		var p = _pick()
		if p == null: return {}
		var sel := _selected()
		if sel.is_empty(): return {}
		var entry := {"kind": sel["kind"], "rot": _place_rot}
		if sel.has("color"): entry["color"] = sel["color"]
		if sel.has("radius"): entry["radius"] = sel["radius"]
		var ax := int(floor(p.x)); var az := int(floor(p.z))
		var fp := Vector2i.ONE
		entry["x"] = ax + 0.5; entry["z"] = az + 0.5
		var valid := true
		for t in _tiles_for(entry):
			if _occupied.has(t): valid = false; break
		return {"entry": entry, "pos": Vector3(entry["x"], _height(float(entry["x"]), float(entry["z"])), entry["z"]),
			"valid": valid, "fp": fp}
	return {}

func _update_ghost() -> void:
	if mode != MODE_PLACE or _over_ui():
		_ghost_hide(); return
	var probe := _ghost_probe()
	if probe.is_empty():
		_ghost_hide(); return
	var entry: Dictionary = probe["entry"]
	var key := "%s|%s|%s|%s|%s|%s|%s|%s|%s" % [str(entry.get("kind")), str(entry.get("type", "")),
		str(entry.get("model", "")), str(entry.get("size", "")), str(entry.get("color", "")),
		str(entry.get("rot", "")), str(entry.get("text", "")),
		str(entry.get("mat", "")), str(entry.get("shape", ""))]
	if key != _ghost_key or _ghost == null or not is_instance_valid(_ghost):
		_ghost_key = key
		if _ghost != null and is_instance_valid(_ghost): _ghost.queue_free()
		_ghost = _spawn(entry)
		if _ghost == null: _ghost_hide(); return
		_ghostify(_ghost)
	_ghost.visible = true
	_ghost.position = probe["pos"]
	_ghost.rotation.y = float(entry.get("rot", 0.0))
	# Footprint plate: green = placeable, red = blocked.
	if _ghost_plate == null:
		_ghost_plate = MeshInstance3D.new()
		var pm := PlaneMesh.new(); pm.size = Vector2(1, 1)
		_ghost_plate.mesh = pm
		_ghost_plate_mat = StandardMaterial3D.new()
		_ghost_plate_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ghost_plate_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ghost_plate_mat.no_depth_test = true
		_ghost_plate_mat.render_priority = 18
		_ghost_plate.material_override = _ghost_plate_mat
		_ghost_plate.sorting_offset = 3.0
		add_child(_ghost_plate)
	var fp: Vector2i = probe["fp"]
	var side := 1.0
	_ghost_plate.visible = true
	_ghost_plate.scale = Vector3(maxf(float(fp.x), side), 1.0, maxf(float(fp.y), side))
	var base: Vector3 = probe["pos"]
	_ghost_plate.position = Vector3(base.x, _height(base.x, base.z) + 0.12, base.z)
	_ghost_plate_mat.albedo_color = Color(0.25, 1.0, 0.4, 0.3) if probe["valid"] \
		else Color(1.0, 0.2, 0.15, 0.4)
	# Snap lattice: shown for snapped block/stairs placement, at the ghost's

## Make a freshly spawned model read as a preview: see-through, lights off.
func _ghostify(n: Node3D) -> void:
	var stack: Array = [n]
	while not stack.is_empty():
		var c = stack.pop_back()
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).transparency = 0.55
		elif c is Light3D:
			(c as Light3D).visible = false   # a ghost torch must not light the scene
		for ch in c.get_children(): stack.append(ch)

func _setup_sfx() -> void:
	var path := "res://assets/audio/sfx/hit.ogg"
	if not ResourceLoader.exists(path):
		return
	_sfx_place = AudioStreamPlayer.new()
	_sfx_place.stream = load(path); _sfx_place.volume_db = -16.0
	add_child(_sfx_place)
	_sfx_remove = AudioStreamPlayer.new()
	_sfx_remove.stream = load(path); _sfx_remove.volume_db = -20.0
	add_child(_sfx_remove)

## A satisfying little knock — pitch-randomized so spam-building sounds musical.
func _pop_sound(remove := false) -> void:
	var pl := _sfx_remove if remove else _sfx_place
	if pl == null: return
	pl.pitch_scale = randf_range(0.65, 0.85) if remove else randf_range(1.05, 1.45)
	pl.play()

# --- picking against placed blocks (so towers stack like Minecraft) -----------

## Ray vs axis-aligned box; {} on miss, else {t, pos, normal}.
func _ray_aabb(o: Vector3, d: Vector3, bmin: Vector3, bmax: Vector3) -> Dictionary:
	var inv := Vector3(
		1.0 / (d.x if absf(d.x) > 1e-8 else 1e-8),
		1.0 / (d.y if absf(d.y) > 1e-8 else 1e-8),
		1.0 / (d.z if absf(d.z) > 1e-8 else 1e-8))
	var t1 := (bmin - o) * inv
	var t2 := (bmax - o) * inv
	var tmin3 := Vector3(minf(t1.x, t2.x), minf(t1.y, t2.y), minf(t1.z, t2.z))
	var tmax3 := Vector3(maxf(t1.x, t2.x), maxf(t1.y, t2.y), maxf(t1.z, t2.z))
	var tn := maxf(maxf(tmin3.x, tmin3.y), tmin3.z)
	var tf := minf(minf(tmax3.x, tmax3.y), tmax3.z)
	if tn > tf or tf < 0.0: return {}
	var n := Vector3.ZERO
	if tn == tmin3.x: n = Vector3(-signf(d.x), 0, 0)
	elif tn == tmin3.y: n = Vector3(0, -signf(d.y), 0)
	else: n = Vector3(0, 0, -signf(d.z))
	return {"t": tn, "pos": o + d * tn, "normal": n}

func _undo_push(op: Dictionary) -> void:
	_undo.append(op)
	if _undo.size() > UNDO_MAX: _undo.pop_front()

## Ctrl+Z: undo the last LOCAL place/remove (works for the kit, Place tool and
func _undo_last() -> void:
	if _undo.is_empty():
		_flash("nothing to undo")
		return
	var op: Dictionary = _undo.pop_back()
	match str(op.get("op", "")):
		"add":
			_remove_uid(int(op["uid"]))
			_pop_sound(true)
		"remove":
			var e: Dictionary = (op["entry"] as Dictionary).duplicate(true)
			if _try_place_entry(e):
				_pop_sound()
		"group_add":
			for uid in op["uids"]:
				_remove_uid(int(uid))
			_pop_sound(true)
		"group":
			for k in op["uids"].size():
				var u: Array = [op["uids"][k]]
				_apply_group(u, int(op["prev"][k]))
			_update_sel_ring()
		"remove_multi":
			for ent in op["entries"]:
				var e2: Dictionary = (ent as Dictionary).duplicate(true)
				_try_place_entry(e2)
			_pop_sound()
	_flash("undo ✔")

func _area_update() -> void:
	if _area_a == null or not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	var b = _pick()
	if b == null: return
	_draw_area_box(_area_a, b)

func _draw_area_box(a: Vector3, b: Vector3) -> void:
	var lo := Vector3(minf(a.x, b.x), minf(_height(a.x, a.z), _height(b.x, b.z)) - 0.5, minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), lo.y + 14.0, maxf(a.z, b.z))
	if _area_box == null:
		_area_box = MeshInstance3D.new()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.3, 0.9, 1.0, 0.18)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_area_box.material_override = mat
		add_child(_area_box)
	var bm := BoxMesh.new()
	bm.size = (hi - lo).abs().max(Vector3(0.1, 0.1, 0.1))
	_area_box.mesh = bm
	_area_box.position = (lo + hi) * 0.5
	_area_box.visible = true

func _area_commit() -> void:
	var b = _pick()
	var a = _area_a
	_area_a = null
	if _area_box != null: _area_box.visible = false
	if a == null or b == null: return
	_group_area(a, b)
	_set_mode(MODE_SELECT)

# DEV HOT-RELOAD (F5): re-parse this script from disk + rebuild the scene in place (autosaves first; a parse error aborts safely).

func _dev_probe() -> String:
	return "v1"

func _dev_reload() -> void:
	if not "--testreload" in OS.get_cmdline_args():
		_save()
		_save_cam()
	print("DEVRELOAD re-parsing scripts")
	var helper: Node = load("res://tools/dev_reload_helper.gd").new()
	helper.paths = _dev_script_paths()
	get_tree().root.add_child(helper)
	helper.do_reload.call_deferred()

func _dev_script_paths() -> Array:
	var out: Array = ["res://tools/godot_studio.gd"]
	var d := DirAccess.open("res://scripts")
	if d != null:
		for f in d.get_files():
			if f.ends_with(".gd"):
				out.append("res://scripts/" + f)
	return out


## Popup the saved maps; picking one opens it. A ✓ marks the map already open.
func _show_open_menu() -> void:
	var pm := PopupMenu.new()
	_open_menu_slugs.clear()
	for m in MapStore.list_maps():
		var slug := String(m["slug"])
		pm.add_item(String(m["name"]) + ("  ✓" if slug == _map_slug else ""))
		_open_menu_slugs.append(slug)
	if _open_menu_slugs.is_empty():
		pm.add_item("(no maps yet)")
		pm.set_item_disabled(0, true)
	pm.id_pressed.connect(func(idx):
		if idx >= 0 and idx < _open_menu_slugs.size():
			_open_map(_open_menu_slugs[idx]))
	pm.popup_hide.connect(func(): pm.queue_free())
	add_child(pm)
	pm.reset_size()
	pm.position = DisplayServer.mouse_get_position()
	pm.popup()

## Name-a-new-map dialog; creating it opens the blank map immediately.
func _show_new_dialog() -> void:
	var dlg := AcceptDialog.new()
	dlg.title = "New map"
	dlg.min_size = Vector2i(300, 0)
	var vb := VBoxContainer.new()
	vb.add_child(_labeled("name the new map:"))
	var le := LineEdit.new()
	le.placeholder_text = "e.g. North Village"
	le.custom_minimum_size = Vector2(240, 0)
	vb.add_child(le)
	dlg.add_child(vb)
	dlg.register_text_enter(le)
	dlg.confirmed.connect(func():
		var nm := le.text.strip_edges()
		var slug := MapStore.create(nm if not nm.is_empty() else "Map")
		dlg.queue_free()
		_open_map(slug))
	dlg.canceled.connect(func(): dlg.queue_free())
	add_child(dlg)
	dlg.popup_centered()
	le.grab_focus()

## Switch the active map: persist the one we're leaving, repoint journal + files,
func _open_map(slug: String) -> void:
	if slug.is_empty() or slug == _map_slug:
		return
	_save()                       # don't lose edits on the map we're leaving
	_set_active_map(slug)
	MapStore.set_current(slug)
	_rebuild_world()
	_refresh_status("opened map: %s" % _map_name)

func _set_active_map(slug: String) -> void:
	_map_slug = slug
	_map_name = MapStore.display_name(slug)
	if _map_lbl != null:
		_map_lbl.text = "map: " + _map_name

## Reload the active map from disk (masks + objects), then rebuild the world.
func _rebuild_world() -> void:
	for n in _spawned:
		if is_instance_valid(n): n.queue_free()
	_spawned.clear(); _objects.clear(); _obj_tiles.clear(); _occupied.clear()
	if _water_sim != null: _water_sim.clear()
	_deselect()
	_load_masks()
	_load_objects()
	_rebuild_hgrid()
	for c in _chunks: _rebuild_chunk(c)
	_update_water_region(0, 0, Config.GRID_COLS, Config.GRID_ROWS)
