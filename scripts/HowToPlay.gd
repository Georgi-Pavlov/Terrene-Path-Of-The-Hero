extends Control

const EXPLANATION_TEXT := """Welcome to Terrence: Path of the Hero

Each zone on the map, that has a green dot next to it, offers one or more heroes - browse them with the arrows, pick a skill, and press Accept. Your hero and that skills are locked in for the rest of the run - the only way to choose differently is starting a fresh "New Game".

Fight the enemies in each zone in a turn based battle. Each turn you may use only a movement, an attack, a skill or an item. The enemies are going to chace you or run away from you. You can only attack the enemies that are in your range.

The if you chose range hero or you are casting a spell/skill, you have to chose your target as well (highlighted if in range).

Killing an enemy earns XP, which helps you level up, and gold, which you can spend at the Shop on the map.

Potions and stat-boost items in your inventory can be used any time, free of your turn's move/attack allowance.

Clear every stage in a zone and you may be challenged by one of that zone's rival heroes in a duel.

Win, and you take their bounty in XP and gold. Clear your starting zone entirely and you unlock all other zones on the map.

You're not the only hero out there. Every other zone's hero is fighting their way through their own home turf in the background, leveling up and dueling their own rivals even while you're elsewhere.

Once a hero has cleared their home zone, they go looking for a new fight - picking a target anywhere on the map, fighting through that zone, and challenging its hero when they get there.

If a rival falls - to you or to another hero - you'll hear about it: check the map when you return from battle for a "While you were away..." message with the latest news.

Want the full picture? Tap World Status next to the Shop to see every zone, every hero in it, and whether they're still standing - including you.

If your HP reaches zero, your run ends - your best XP is saved as a high score before you're sent back to the main menu.
"""


func _ready() -> void:
	$TextPanel/Margin/ScrollContainer/ExplanationLabel.text = EXPLANATION_TEXT
	$BackButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/PostLogin.tscn"))
