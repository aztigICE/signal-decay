class_name TerminalUI
extends Control
## The UI shown on the in-world monitor: a scrolling output log and a command line.
## Lives inside a SubViewport; key events are pushed in by terminal.gd while seated.

signal exit_requested

const TEXT_COLOR := Color(0.4, 1.0, 0.5)
const DIM_COLOR := Color(0.22, 0.6, 0.3)
const WARN_HEX := "e0a040"
const GOOD_HEX := "80ffa0"
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
	input.keep_editing_on_text_submit = true
	input.text_submitted.connect(_on_submitted)
	input.gui_input.connect(_on_input_gui)
	Station.target_lost.connect(_on_target_lost)


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
			_print("  scan     sweep for a signal")
			_print("  target   show the current signal")
			_print("  lock     lock on to the signal (aim the dish first)")
			_print("  drop     give up on the current signal")
			_print("  clear    clear the screen")
			_print("  whoami   current operator")
			_print("  exit     log out (or press Esc)")
		"status":
			_status()
		"scan":
			await _scan()
		"target":
			_show_target()
		"lock":
			await _lock()
		"drop":
			_drop()
		"clear":
			output.clear()
		"whoami":
			_print("operator")
		"exit", "logout":
			exit_requested.emit()
		_:
			_print("Unknown command: %s. Type 'help'." % _escape(cmd))


func _status() -> void:
	_print("STATION STATUS")
	_print("  Power ........ OK")
	if Station.has_dish():
		_print("  Dish ......... MANUAL (control panel outside)")
	else:
		_print("  Dish ......... [color=#%s]NOT CONNECTED[/color]" % WARN_HEX)
	var t: SignalTarget = Station.target
	if t != null:
		_print("  Target ....... %s  %d%%" % [t.designation, roundi(t.strength(Station.now()) * 100.0)])
	else:
		_print("  Target ....... none")
	_print("  Locked ....... %d" % Station.signals_locked)
	_print("  Points ....... %d" % Station.points)


func _scan() -> void:
	if not Station.has_dish():
		_print("[color=#%s]Dish controller not connected.[/color]" % WARN_HEX)
		return
	if Station.target != null:
		_print("Already tracking %s. Use 'target', 'lock' or 'drop'." % Station.target.designation)
		return
	await _dots("Sweeping bands", 6, 0.3)
	var t: SignalTarget = Station.scan()
	_print("[color=#%s]Signal found: %s[/color]" % [GOOD_HEX, t.designation])
	_print_target(t)
	_print("Align the dish at the control panel outside, then run 'lock'.")


func _show_target() -> void:
	var t: SignalTarget = Station.target
	if t == null:
		_print("No signal. Run 'scan'.")
		return
	_print("Tracking %s" % t.designation)
	_print_target(t)


func _print_target(t: SignalTarget) -> void:
	var now := Station.now()
	var left := roundi(t.seconds_left(now))
	_print("  Band ......... %s  (%.3f GHz)" % [t.band, t.frequency_ghz])
	_print("  Azimuth ...... %05.1f°" % t.azimuth)
	_print("  Elevation .... %05.1f°" % t.elevation)
	_print("  Strength ..... %d%%  (gone in %d:%02d)" % [roundi(t.strength(now) * 100.0), left / 60, left % 60])


func _lock() -> void:
	if Station.target == null:
		_print("No signal to lock. Run 'scan'.")
		return
	await _dots("Locking receiver", 5, 0.3)
	if Station.target == null:
		return  # faded while we waited; _on_target_lost already printed it
	var q := Station.lock_quality()
	var filled := roundi(q * 20.0)
	var col := GOOD_HEX if q >= Station.LOCK_THRESHOLD else WARN_HEX
	_print("  Lock  [lb][color=#%s]%s[/color]%s]  %d%%" % [col, "#".repeat(filled), "-".repeat(20 - filled), roundi(q * 100.0)])
	var designation: String = Station.target.designation
	var reward := Station.try_lock()
	if reward > 0:
		_print("[color=#%s]LOCK ACQUIRED: %s[/color]" % [GOOD_HEX, designation])
		_print("  +%d points  (total %d)" % [reward, Station.points])
	elif q <= 0.0:
		_print("[color=#%s]No signal at this heading.[/color] Check the dish." % WARN_HEX)
	else:
		_print("[color=#%s]Lock too weak.[/color] Need %d%%. Fine-tune the dish." % [WARN_HEX, roundi(Station.LOCK_THRESHOLD * 100.0)])


func _drop() -> void:
	if Station.target == null:
		_print("Nothing to drop.")
		return
	_print("Dropped %s." % Station.target.designation)
	Station.drop_target()


func _on_target_lost(t: SignalTarget) -> void:
	_print("[color=#%s]Signal %s faded out.[/color]" % [WARN_HEX, t.designation])


func _dots(label: String, count: int, interval: float) -> void:
	_busy = true
	input.editable = false
	output.append_text(label)
	for i in count:
		await get_tree().create_timer(interval).timeout
		output.append_text(".")
	_print("")
	_set_ready()


func _boot() -> void:
	_busy = true
	var lines: Array[String] = [
		"STATION OS v0.1",
		"Remote Listening Program",
		"",
		"Memory check ............ OK",
		"Receiver ................ OK",
		"Dish controller ......... MANUAL",
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
	input.edit()


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
