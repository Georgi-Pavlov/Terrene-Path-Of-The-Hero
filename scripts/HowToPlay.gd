extends Control

const EXPLANATION_TEXT := """Welcome to Terrence: Path of the Hero

Each zone on the map, that has a green dot next to it, offers one or more heroes - browse them with the arrows, pick a skill, and press Accept. Your hero and that skills are locked in for the rest of the run - the only way to choose differently is starting a fresh "New Game".

Fight the enemies in each zone in a turn based battle. Each turn you may use only a movement, an attack, a skill or an item. The enemies are going to chace you or run away from you. You can only attack the enemies that are in your range.

The if you chose range hero or you are casting a spell/skill, you have to chose your target as well (highlighted if in range).

When you kill and enemie you will receive XP points that will help you level up and gold, that you can spend in the shop on the map.

Potions and stat-boost items in your inventory can be used any time, free of your turn's move/attack allowance.

Clear every enemy in a zone to return to the map. If your HP reaches zero, your run ends - your best XP is saved as a high score before you're sent back to the main menu."""


func _ready() -> void:
	$TextPanel/Margin/ScrollContainer/ExplanationLabel.text = EXPLANATION_TEXT
	$BackButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/PostLogin.tscn"))
