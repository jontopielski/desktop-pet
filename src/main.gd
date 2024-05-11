extends Node2D

@export var require_folder: bool = true

enum Wall { LEFT, TOP, RIGHT, BOTTOM }

const Pet = preload("res://src/pet.tscn")
const DEMON_FOLDER = "init"
const TEXT_FILE = "Readme.txt"

var is_summoned = false
var pet = null
var walls_touched = []
var last_window_pos = Vector2.ZERO

func _ready():
	get_window().position = Vector2i(1, 1)
	get_window().size = DisplayServer.screen_get_size() - Vector2i(2, 2)
	update_instructions_passthrough()
	last_window_pos = $Instructions.position
	if !require_folder or has_demon_folder(get_desktop_file_names()):
		$Instructions.queue_free()
		$FileCheckTimer.stop()
		summon_pet()
		await get_tree().create_timer(0.01).timeout
		tween_summon_animation()

func update_instructions_passthrough():
	var mult = Vector2(get_window().size) / get_viewport_rect().size
	var pos = Vector2($Instructions.position) - Vector2(10, 30)
	var size = Vector2($Instructions.size) + Vector2(20, 40)
	get_window().mouse_passthrough_polygon = PackedVector2Array([pos * mult, (pos + Vector2(size.x, 0)) * mult,
		(pos + size) * mult, (pos + Vector2(0, size.y)) * mult])

func _process(_delta):
	if has_node("Instructions") and $Instructions.position != last_window_pos:
		last_window_pos = $Instructions.position
		update_instructions_passthrough()
	if touched_wall(Wall.TOP) and !Wall.TOP in walls_touched:
		walls_touched.push_back(Wall.TOP)
	if touched_wall(Wall.BOTTOM) and !Wall.BOTTOM in walls_touched:
		walls_touched.push_back(Wall.BOTTOM)
	if touched_wall(Wall.LEFT) and !Wall.LEFT in walls_touched:
		walls_touched.push_back(Wall.LEFT)
	if touched_wall(Wall.RIGHT) and !Wall.RIGHT in walls_touched:
		walls_touched.push_back(Wall.RIGHT)
	if !walls_touched.is_empty() and $TouchedWallsTimer.is_stopped():
		$TouchedWallsTimer.start()
	if len(walls_touched) == 4 and !$TouchedWallsTimer.is_stopped():
		walls_touched.clear()
		$TouchedWallsTimer.stop()
		if pet:
			pet.toggle_inverted()

func touched_wall(wall):
	match wall:
		Wall.TOP:
			return get_global_mouse_position().y <= 0.0
		Wall.BOTTOM:
			return get_global_mouse_position().y >= 360.0
		Wall.LEFT:
			return get_global_mouse_position().x <= 0.0
		Wall.RIGHT:
			return get_global_mouse_position().x >= 640.0
	return false

func handle_desktop_folder_check():
	var desktop_files = get_desktop_file_names()
	if has_demon_folder(desktop_files):
		$FileCheckTimer.stop()
		is_summoned = true
		await get_tree().create_timer(0.5).timeout
		if has_node("Instructions"):
			$Instructions.queue_free()
		await get_tree().create_timer(0.5).timeout
		summon_pet()
		write_text_file()
		await get_tree().create_timer(0.01).timeout
		tween_summon_animation()

func has_demon_folder(files):
	for file in files:
		if file.to_lower() == DEMON_FOLDER:
			return true
	return false

func tween_summon_animation():
	var scale_tween = get_tree().create_tween()
	pet.scale_multiplier = 2.0
	scale_tween.tween_property(pet, "scale_multiplier", 1, 0.5).set_trans(Tween.TRANS_SPRING)
	var position_tween = get_tree().create_tween()
	position_tween.tween_property(pet, "position", get_viewport_rect().size / 2.0, 0.5).set_trans(Tween.TRANS_SPRING)

func summon_pet():
	pet = Pet.instantiate()
	add_child(pet)
	pet.position = get_viewport_rect().size / 2.0 + Vector2(0, get_viewport_rect().size.y / 16)
	pet.pet_changed.connect(_on_pet_changed)
	update_passthrough_polygon()

func write_text_file():
	var file = FileAccess.open(OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP) + "/%s/%s" % [get_demon_file_name(), TEXT_FILE], FileAccess.WRITE)
	if !file:
		return
	file.store_line("Congrats on summoning your very own Desktop Daemon!")
	file.store_line("")
	file.store_line("v1.0")
	file.store_line("")
	file.store_line("How to use:")
	file.store_line("- Watch the daemon wander around")
	file.store_line("- Click on the daemon to pet it")
	file.store_line("- Click and hold to drag it around")
	file.store_line("- Right click to exit")
	file.store_line("")
	file.store_line("Credits:")
	file.store_line("- Prifurin (Art, Design)")
	file.store_line("- Jon Topielski (Programming, Design)")
	file.store_line("")
	file.store_line("Made with Godot")
	file.close()

func get_demon_file_name():
	var desktop_files = get_desktop_file_names()
	for file in desktop_files:
		if file.to_lower() == DEMON_FOLDER:
			return file
	return ""

func get_desktop_file_names():
	var files = []
	var dir = DirAccess.open(OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP))
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				files.push_back(file_name)
			file_name = dir.get_next()
	return files

func update_passthrough_polygon():
	get_window().mouse_passthrough_polygon = get_current_polygon()

func get_current_polygon():
	var screen_multiple = Vector2(get_window().size) / get_viewport_rect().size
	var pet_polygon = pet.get_node("Polygon2D").polygon
	var global_polygon = PackedVector2Array([])
	for i in range(0, len(pet_polygon)):
		global_polygon.push_back((pet_polygon[i] * pet.scale_multiplier + pet.global_position) * screen_multiple)
	return global_polygon

func _on_pet_changed():
	update_passthrough_polygon()

func _on_file_check_timer_timeout():
	if !is_summoned:
		handle_desktop_folder_check()

func _on_instructions_close_requested():
	$Instructions.queue_free()
	await get_tree().create_timer(0.05).timeout
	if !is_summoned:
		get_window().mouse_passthrough_polygon = PackedVector2Array([Vector2(0, 0), Vector2(0, 1)])

func _on_touched_walls_timer_timeout():
	walls_touched.clear()

func _on_button_pressed():
	$Instructions.queue_free()
	await get_tree().create_timer(0.05).timeout
	if !is_summoned:
		get_window().mouse_passthrough_polygon = PackedVector2Array([Vector2(0, 0), Vector2(0, 1)])
