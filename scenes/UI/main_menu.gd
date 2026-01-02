extends Control
## Main Menu - Home screen with Start, Garage, Statistics, Achievements, Options, Quit buttons

const StatisticsScreenScript = preload("res://scenes/UI/statistics_screen.gd")
const AchievementsScreenScript = preload("res://scenes/UI/achievements_screen.gd")
const ChallengesPanelScript = preload("res://scenes/UI/challenges_panel.gd")
const ChampionshipMenuScript = preload("res://scenes/UI/championship_menu.gd")

var statistics_screen: StatisticsScreen = null
var achievements_screen: AchievementsScreen = null
var challenges_panel: ChallengesPanel = null
var championship_menu: ChampionshipMenu = null

func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/UI/race_setup.tscn")

func _on_garage_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/UI/garage.tscn")

func _on_stats_button_pressed() -> void:
	if statistics_screen:
		return  # Already showing
	statistics_screen = StatisticsScreen.new()
	statistics_screen.back_requested.connect(_on_stats_back)
	add_child(statistics_screen)

func _on_stats_back() -> void:
	statistics_screen = null

func _on_achievements_button_pressed() -> void:
	if achievements_screen:
		return  # Already showing
	achievements_screen = AchievementsScreen.new()
	achievements_screen.back_requested.connect(_on_achievements_back)
	add_child(achievements_screen)

func _on_achievements_back() -> void:
	achievements_screen = null

func _on_challenges_button_pressed() -> void:
	if challenges_panel:
		return  # Already showing
	challenges_panel = ChallengesPanel.new()
	challenges_panel.back_requested.connect(_on_challenges_back)
	add_child(challenges_panel)

func _on_challenges_back() -> void:
	challenges_panel = null

func _on_championship_button_pressed() -> void:
	if championship_menu:
		return  # Already showing
	championship_menu = ChampionshipMenu.new()
	championship_menu.back_requested.connect(_on_championship_back)
	championship_menu.start_race_requested.connect(_on_championship_race_start)
	add_child(championship_menu)

func _on_championship_back() -> void:
	championship_menu = null

func _on_championship_race_start(_track_id: String, _ai_difficulty: String) -> void:
	# Settings are configured by championship menu
	# Load the race scene
	var track_data = ConfigManager.get_track(GameSettings.selected_track)
	var scene_path = track_data.get("scene", "")
	if scene_path != "":
		get_tree().change_scene_to_file(scene_path)

func _on_options_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/UI/options_menu.tscn")

func _on_quit_button_pressed() -> void:
	get_tree().quit()
