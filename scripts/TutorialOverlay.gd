extends CanvasLayer
# ------------------------------------------------------------------
# TutorialOverlay
# A persistent popup, owned and instantiated by TutorialManager (so it
# survives every scene change during the tutorial) that renders on top
# of whatever scene is currently active and blocks clicks from
# reaching it underneath. TutorialManager is the only intended caller -
# scenes never touch this directly.
# ------------------------------------------------------------------

@onready var dim: ColorRect = $Dim
@onready var popup_panel: PanelContainer = $Dim/PopupPanel
@onready var message_label: Label = $Dim/PopupPanel/Margin/VBox/MessageLabel
@onready var continue_button: Button = $Dim/PopupPanel/Margin/VBox/ButtonRow/ContinueButton
@onready var exit_button: Button = $Dim/PopupPanel/Margin/VBox/ButtonRow/ExitButton
@onready var exit_corner_button: Button = $ExitCornerButton

var _on_continue: Callable = Callable()
var _on_exit: Callable = Callable()


func _ready() -> void:
	# Above every in-game UI layer, including battle popups.
	layer = 100
	dim.visible = false
	exit_corner_button.visible = false
	continue_button.pressed.connect(_on_continue_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	# A later sibling of Dim, so it draws on top and stays clickable even
	# while a forced-step popup is up - the player shouldn't have to wait
	# for a specific checkpoint just to bail out. TutorialManager is the
	# only thing that ever instantiates this scene, so calling straight
	# into it here (rather than routing through a signal) is fine.
	exit_corner_button.pressed.connect(TutorialManager.exit_tutorial)


## Shows/hides the always-available "Exit Tutorial" corner button -
## visible for the whole tutorial, independent of whatever popup (if
## any) is currently up. See TutorialManager.start_tutorial()/
## exit_tutorial().
func set_exit_button_visible(value: bool) -> void:
	exit_corner_button.visible = value


## Single-button popup: explains something and gets acknowledged.
## on_continue may be an empty Callable if nothing needs to happen
## beyond dismissing it.
func show_message(text: String, continue_label: String, on_continue: Callable) -> void:
	message_label.text = text
	continue_button.text = continue_label
	continue_button.visible = true
	exit_button.visible = false
	_on_continue = on_continue
	_on_exit = Callable()
	dim.visible = true


## Two-button popup for the "continue to the next tutorial stage, or
## stop here" checkpoints between stages.
func show_choice(text: String, continue_label: String, exit_label: String, on_continue: Callable, on_exit: Callable) -> void:
	message_label.text = text
	continue_button.text = continue_label
	continue_button.visible = true
	exit_button.text = exit_label
	exit_button.visible = true
	_on_continue = on_continue
	_on_exit = on_exit
	dim.visible = true


func hide_popup() -> void:
	dim.visible = false


func _on_continue_pressed() -> void:
	hide_popup()
	if _on_continue.is_valid():
		_on_continue.call()


func _on_exit_pressed() -> void:
	hide_popup()
	if _on_exit.is_valid():
		_on_exit.call()
