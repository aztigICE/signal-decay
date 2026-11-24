class_name TerminalUI
extends Control
## The UI shown on the in-world monitor: a scrolling output log and a command line.
## Lives inside a SubViewport; key events are pushed in by terminal.gd while seated.

signal exit_requested

const TEXT_COLOR := Color(0.4, 1.0, 0.5)
const DIM_COLOR := Color(0.22, 0.6, 0.3)
const WARN_HEX := "e0a040"
const FONT_SIZE := 22

@onready var output: RichTextLabel = $Margin/VBox/Output
@onready var input: LineEdit = $Margin/VBox/InputRow/Input
@onready var prompt_label: Label = $Margin/VBox/InputRow/PromptLabel

var _booted: bool = false
var _busy: bool = false
var _history: PackedStringArray = []
var _history_index: int = -1


func _ready() -> void:
	_apply_style()
	output.clear()
	input.editable = false
	input.text_submitted.connect(_on_submitted)
	input.gui_input.connect(_on_input_gui)


func activate() -> void:
	if not _booted:
		_booted = true
		await _boot()
	_set_ready()


func deactivate() -> void:
	input.release_focus()


# --- commands -------------------------------------------------------------

func _run(line: String) -> void:
	var parts: PackedStringArray = line.split(" ", false)
	var cmd: String = parts[0].to_lower()
	match cmd:
		"help":
			_print("Commands:")
			_print("  help     show this list")
			_print("  status   station status")
			_print("  scan     sweep for signals")
			_print("  clear    clear the screen")
			_print("  whoami   current operator")
			_print("  exit     log out (or press Esc)")
		"status":
			_print("STATION STATUS")
			_print("  Power ........ OK")
			_print("  Dish ......... [color=#%s]NOT CONNECTED[/color]" % WARN_HEX)
			_print("  Storage ...... 0 / 4 slots")
			_print("  Points ....... 0")
		"scan":
			await _scan()
		"clear":
			output.clear()
		"whoami":
			_print("operator")
		"exit", "logout":
			exit_requested.emit()
		_:
			_print("Unknown command: %s. Type 'help'." % _escape(cmd))


func _scan() -> void:
	_busy = true
	input.editable = false
	output.append_text("Sweeping bands")
	for i in 6:
		await get_tree().create_timer(0.3).timeout
		output.append_text(".")
	_print("")
	_print("[color=#%s]No signals. Dish is not aligned.[/color]" % WARN_HEX)
	_print("Align the dish outside to receive transmissions.")
	_set_ready()


func _boot() -> void:
	_busy = true
	var lines: Array[String] = [
		"STATION OS v0.1",
		"Remote Listening Program",
		"",
		"Memory check ............ OK",
		"Receiver ................ OK",
		"Dish controller ......... [color=#%s]NOT CONNECTED[/color]" % WARN_HEX,
		"Storage ................. 0 / 4 slots",
		"",
		"Type 'help' for commands. Esc to stand up.",
		"",
	]
	for l in lines:
		_print(l)
		await get_tree().create_timer(0.12).timeout


# --- input ----------------------------------------------------------------

func _on_submitted(text: String) -> void:
	input.clear()
	text = text.strip_edges()
	_print("[color=#%s]> %s[/color]" % [DIM_COLOR.to_html(false), _escape(text)])
	if text.is_empty():
		return
	_history.append(text)
	_history_index = -1
	_run(text)


func _on_input_gui(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed) or _history.is_empty():
		return
	if event.keycode == KEY_UP:
		_history_index = _history.size() - 1 if _history_index == -1 else max(_history_index - 1, 0)
	elif event.keycode == KEY_DOWN:
		if _history_index == -1:
			return
		_history_index += 1
		if _history_index >= _history.size():
			_history_index = -1
			input.clear()
			input.accept_event()
			return
	else:
		return
	input.text = _history[_history_index]
	input.caret_column = input.text.length()
	input.accept_event()


# --- helpers --------------------------------------------------------------

func _set_ready() -> void:
	_busy = false
	input.editable = true
	input.grab_focus()


func _print(text: String) -> void:
	output.append_text(text + "\n")


func _escape(text: String) -> String:
	return text.replace("[", "[lb]")


func _apply_style() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "Lucida Console", "Courier New", "monospace"])
	output.add_theme_font_override("normal_font", font)
	output.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	output.add_theme_color_override("default_color", TEXT_COLOR)
	for c: Control in [input, prompt_label]:
		c.add_theme_font_override("font", font)
		c.add_theme_font_size_override("font_size", FONT_SIZE)
		c.add_theme_color_override("font_color", TEXT_COLOR)
	input.add_theme_color_override("caret_color", TEXT_COLOR)
	input.add_theme_color_override("font_uneditable_color", DIM_COLOR)
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "focus", "read_only"]:
		input.add_theme_stylebox_override(s, empty)
