class_name SettingsManager
extends RefCounted

const SAVE_PATH = "user://settings.cfg"

static var turn_sensitivity: float = 2.8
static var camera_smoothing: float = 5.0

static func load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err == OK:
		turn_sensitivity = config.get_value("controls", "turn_sensitivity", 2.8)
		camera_smoothing = config.get_value("controls", "camera_smoothing", 5.0)

static func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("controls", "turn_sensitivity", turn_sensitivity)
	config.set_value("controls", "camera_smoothing", camera_smoothing)
	config.save(SAVE_PATH)
