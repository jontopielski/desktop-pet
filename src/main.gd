extends Node2D

const Pet = preload("res://src/pet.tscn")
const DEMON_FOLDER = "demon"
const TEXT_FILE = "notes.txt"

var is_summoned = false
var pet = null

func _ready():
	get_window().position = Vector2i(1, 1)
	get_window().size = DisplayServer.screen_get_size() - Vector2i(2, 2)
	get_window().mouse_passthrough_polygon = PackedVector2Array([Vector2(0, 0), Vector2(0, 1)])

func handle_desktop_folder_check():
	var desktop_files = get_desktop_file_names()
	if DEMON_FOLDER in desktop_files:
		$FileCheckTimer.stop()
		is_summoned = true
		await get_tree().create_timer(1.5).timeout
		summon_pet()
		write_text_file()
		await get_tree().create_timer(0.01).timeout
		tween_summon_animation()

func tween_summon_animation():
	var scale_tween = get_tree().create_tween()
	pet.scale_multiplier = 5.0
	scale_tween.tween_property(pet, "scale_multiplier", 1, 1.0).set_trans(Tween.TRANS_SPRING)
	var position_tween = get_tree().create_tween()
	position_tween.tween_property(pet, "position", get_viewport_rect().size / 2.0, 1.0).set_trans(Tween.TRANS_SPRING)

func summon_pet():
	pet = Pet.instantiate()
	add_child(pet)
	pet.position = get_viewport_rect().size / 2.0 + Vector2(0, get_viewport_rect().size.y / 8)
	pet.pet_changed.connect(_on_pet_changed)
	update_passthrough_polygon()

func write_text_file():
	var file = FileAccess.open(OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP) + "/%s/%s" % [DEMON_FOLDER, TEXT_FILE], FileAccess.WRITE)
	if !file:
		return
	file.store_line("Hello!")
	file.store_line("My name is Atgtha")
	file.store_line("I'm your demon pet >:)")
	file.store_line("--------")
	file.store_line("Pet me")
	file.store_line("Love me")
	file.store_line("But most of all, love yourself!")
	file.close()

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
