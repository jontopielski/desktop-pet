extends Node2D

signal pet_changed

enum State { IDLE, ROAM, DRAG, SLEEP, PET, WANDER, ANGRY }

const starting_deck = [ State.IDLE, State.IDLE, State.IDLE, State.ROAM, State.SLEEP, State.SLEEP, State.SLEEP, State.WANDER, State.WANDER ]

@export var speed: float = 100.0
@export var angle_speed: float = 2.0
@export var scale_multiplier: float = 1.0: set = set_scale_multiplier, get = get_scale_multiplier
@export var is_polygon_visible: bool = false: set = set_is_polygon_visible, get = get_is_polygon_visible
@export var reset_polygon: bool = false: set = set_reset_polygon, get = get_reset_polygon
@export var y_offset: float = 0.0

var state = State.IDLE
var last_state = State.IDLE
var direction = Vector2.ZERO
var wander_direction = Vector2.DOWN
var drag_last_sprite_pos = Vector2.ZERO
var drag_last_mouse_pos = Vector2.ZERO
var angle = 0.0
var delta_sum = 0.0

var state_deck = [ State.IDLE, State.IDLE, State.IDLE, State.ROAM, State.SLEEP, State.SLEEP, State.SLEEP, State.WANDER, State.WANDER ]

func set_is_polygon_visible(value):
	is_polygon_visible = value
	if has_node("Polygon2D"):
		$Polygon2D.visible = value
	pet_changed.emit()

func get_is_polygon_visible():
	return is_polygon_visible

func set_scale_multiplier(value):
	scale_multiplier = value
	scale = Vector2(value, value)
	pet_changed.emit()

func get_scale_multiplier():
	return scale_multiplier

func set_reset_polygon(_value):
	setup_polygon()

func get_reset_polygon():
	return reset_polygon

func _ready():
	randomize()
	state_deck.shuffle()
	change_state(State.IDLE)
	set_is_polygon_visible(is_polygon_visible)

func _process(delta):
	if Engine.is_editor_hint():
		return
	handle_debug_inputs()
	handle_state(delta)
	handle_y_offset()
	if $Button.button_pressed and has_dragged_sprite():
		if state != State.DRAG:
			change_state(State.DRAG)
		position = drag_last_sprite_pos + (get_global_mouse_position() - drag_last_mouse_pos)

func pop_state_deck():
	if state_deck.is_empty():
		state_deck = starting_deck.duplicate()
		state_deck.shuffle()
	var next_state = state_deck.pop_front()
	return next_state

func handle_y_offset():
	if $AnimationPlayer.current_animation == "bob_up_down":
		$StackedSprite.position.y = y_offset
	else:
		$StackedSprite.position.y = 0.0

func has_dragged_sprite():
	return get_global_mouse_position() != drag_last_mouse_pos

func handle_debug_inputs():
	if !OS.is_debug_build():
		return
	if Input.is_action_just_pressed("idle_state"):
		change_state(State.IDLE)
		$StateChangeTimer.start()
	if Input.is_action_just_pressed("roam_state"):
		change_state(State.ROAM)
		$StateChangeTimer.start()
	if Input.is_action_just_pressed("sleep_state"):
		change_state(State.SLEEP)
		$StateChangeTimer.start()
	if Input.is_action_just_pressed("wander_state"):
		change_state(State.WANDER)
		$StateChangeTimer.start()

func handle_state(delta):
	delta_sum += delta
	match state:
		State.ROAM:
			angle += delta * angle_speed
			direction = Vector2(cos(angle), sin(angle))
			position += direction * speed * delta
			$StackedSprite.set_sprite_rotation(direction.angle() + deg_to_rad(-90))
		State.WANDER:
			if is_out_of_bounds() and $WanderRotateTimer.is_stopped():
				wander_direction = wander_direction.rotated(PI)
				$WanderRotateTimer.start()
			direction = wander_direction + Vector2(sin(delta_sum), sin(delta_sum))
			position += direction * 7.5 * delta
			$StackedSprite.set_sprite_rotation(direction.angle() + deg_to_rad(-90))
	position.x = clamp(position.x, 8, get_viewport_rect().size.x - 8)
	position.y = clamp(position.y, 16, get_viewport_rect().size.y - 4)

func is_out_of_bounds():
	if position.x < 24 or position.x > get_viewport_rect().size.x - 24:
		return true
	if position.y < 36 or position.y > get_viewport_rect().size.y - 24:
		return true
	return false

func change_state(next_state):
	$StackedSprite.visible = next_state == State.ROAM or next_state == State.WANDER
	$Sprite.visible = next_state != State.ROAM and next_state != State.WANDER
	match next_state:
		State.IDLE:
			$AnimationPlayer.play("idle")
		State.ROAM:
			$AnimationPlayer.play("bob_up_down")
		State.WANDER:
			if randi() % 3 == 0:
				wander_direction = wander_direction.rotated(PI)
			$AnimationPlayer.play("bob_up_down")
		State.DRAG:
			$StateChangeTimer.paused = true
			$AnimationPlayer.play("drag")
		State.SLEEP:
			$AnimationPlayer.play("sleep")
		State.PET:
			$StateChangeTimer.paused = true
			$AnimationPlayer.play("pet")
		State.ANGRY:
			$StateChangeTimer.paused = true
			$AnimationPlayer.play("angry")
	if state != State.DRAG and state != State.PET:
		last_state = state
	state = next_state

func setup_polygon():
	var stacked_sprite = find_child("StackedSprite")
	var first_child = stacked_sprite.get_child(0)
	var last_child = stacked_sprite.get_child(stacked_sprite.get_child_count() - 1)
	var sprite_width = last_child.texture.get_width() / last_child.hframes
	var half_width = sprite_width / 2.0
	var next_polygon = PackedVector2Array([last_child.position - Vector2(half_width, sprite_width), last_child.position + Vector2(sprite_width + half_width, -sprite_width),
	first_child.position + Vector2(sprite_width + half_width, sprite_width), first_child.position + Vector2(-half_width, sprite_width)])
	for i in range(0, len(next_polygon)):
		next_polygon[i].x -= half_width
	$Polygon2D.polygon = next_polygon

func _on_button_down():
	drag_last_mouse_pos = get_global_mouse_position()
	drag_last_sprite_pos = position

func _on_button_button_up():
	if state == State.DRAG:
		$StateChangeTimer.paused = false
		if last_state == State.SLEEP:
			change_state(State.IDLE)
		else:
			change_state(last_state)
	elif !has_dragged_sprite() and !state == State.PET:
		change_state(State.PET)

func _on_state_change_timer_timeout():
	match state:
		State.IDLE:
			$StateChangeTimer.wait_time = randf_range(6, 10)
		State.ROAM:
			$StateChangeTimer.wait_time = randf_range(2, 6)
		State.SLEEP:
			$StateChangeTimer.wait_time = randf_range(6, 10)
		State.WANDER:
			$StateChangeTimer.wait_time = randf_range(2, 6)
		_:
			$StateChangeTimer.wait_time = randf_range(6, 8)
	change_state(pop_state_deck())
	$StateChangeTimer.start()

func _on_update_timer_timeout():
	pet_changed.emit()

func _on_animation_player_animation_finished(anim_name):
	if anim_name == "pet":
		$StateChangeTimer.paused = false
		if last_state == State.SLEEP:
			change_state(State.IDLE)
		else:
			change_state(last_state)
