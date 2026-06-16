extends Area2D

signal interacted(player)

func _ready():
	collision_layer = 4
	collision_mask = 1
	add_to_group("interactable")

func interact(player):
	interacted.emit(player)
