extends Node2D

var rotation_sum = 0

func _process(delta):
	rotation_sum += delta
	$StackedSprite.sprite_rotation = rotation_sum
