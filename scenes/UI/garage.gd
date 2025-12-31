extends Control
## Garage - UI for viewing, purchasing, and equipping car parts

var current_category: PartData.Category = PartData.Category.ENGINES

@onready var parts_container: VBoxContainer = $VBoxContainer/ScrollContainer/PartsContainer
@onready var currency_label: Label = $VBoxContainer/Header/StatsContainer/CurrencyLabel
@onready var wins_label: Label = $VBoxContainer/Header/StatsContainer/WinsLabel

@onready var tab_buttons: Array[Button] = [
	$VBoxContainer/TabsContainer/EnginesTab,
	$VBoxContainer/TabsContainer/TiresTab,
	$VBoxContainer/TabsContainer/SpoilersTab,
	$VBoxContainer/TabsContainer/BrakesTab,
	$VBoxContainer/TabsContainer/SuspensionsTab
]

const PartItemScene := preload("res://scenes/UI/part_item.tscn")

const TAB_COLOR_ACTIVE := Color(1, 1, 0.6, 1)
const TAB_COLOR_INACTIVE := Color(0.7, 0.7, 0.7, 1)

func _ready() -> void:
	_connect_signals()
	_update_header()
	_select_tab(PartData.Category.ENGINES)

## Connect to PlayerProgress signals
func _connect_signals() -> void:
	if PlayerProgress:
		PlayerProgress.currency_changed.connect(_on_currency_changed)
		PlayerProgress.part_purchased.connect(_on_part_changed)
		PlayerProgress.part_equipped.connect(_on_part_changed)

## Update header with current currency and wins
func _update_header() -> void:
	if PlayerProgress:
		currency_label.text = "%d" % PlayerProgress.currency
		wins_label.text = "%d Wins" % PlayerProgress.wins

## Select a category tab
func _select_tab(category: PartData.Category) -> void:
	current_category = category
	_update_tab_visuals()
	_refresh_parts_list()

## Update tab button visuals
func _update_tab_visuals() -> void:
	var categories := PartData.get_all_categories()
	for i in range(tab_buttons.size()):
		var button := tab_buttons[i]
		if i < categories.size() and categories[i] == current_category:
			button.modulate = TAB_COLOR_ACTIVE
		else:
			button.modulate = TAB_COLOR_INACTIVE

## Refresh the parts list for current category
func _refresh_parts_list() -> void:
	# Clear existing items
	for child in parts_container.get_children():
		child.queue_free()

	# Get parts for current category
	var cat_str := PartData.category_to_string(current_category)
	var parts_data: Dictionary = ConfigManager.get_parts_category(cat_str)

	# Sort parts by tier
	var part_ids := parts_data.keys()
	part_ids.sort_custom(_sort_by_tier.bind(parts_data))

	# Create part items
	for part_id: String in part_ids:
		var part_data: Dictionary = parts_data[part_id]
		var part_item := PartItemScene.instantiate()
		parts_container.add_child(part_item)
		part_item.setup(current_category, part_id, part_data)
		part_item.buy_pressed.connect(_on_part_buy_pressed)
		part_item.equip_pressed.connect(_on_part_equip_pressed)

## Sort function for parts by tier
func _sort_by_tier(a: String, b: String, parts_data: Dictionary) -> bool:
	var tier_a: int = int(parts_data[a].get("tier", 0))
	var tier_b: int = int(parts_data[b].get("tier", 0))
	return tier_a < tier_b

## Handle part purchase
func _on_part_buy_pressed(category: PartData.Category, part_id: String) -> void:
	if PlayerProgress.purchase_part(category, part_id):
		_refresh_parts_list()
		_update_header()

## Handle part equip
func _on_part_equip_pressed(category: PartData.Category, part_id: String) -> void:
	if PlayerProgress.equip_part(category, part_id):
		_refresh_parts_list()

## Handle currency changed signal
func _on_currency_changed(_new_amount: int) -> void:
	_update_header()
	_refresh_parts_list()

## Handle part state changed
func _on_part_changed(_part_id: String, _category: PartData.Category) -> void:
	_refresh_parts_list()

# =============================================================================
# Button Handlers
# =============================================================================

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/UI/main_menu.tscn")

func _on_engines_tab_pressed() -> void:
	_select_tab(PartData.Category.ENGINES)

func _on_tires_tab_pressed() -> void:
	_select_tab(PartData.Category.TIRES)

func _on_spoilers_tab_pressed() -> void:
	_select_tab(PartData.Category.SPOILERS)

func _on_brakes_tab_pressed() -> void:
	_select_tab(PartData.Category.BRAKES)

func _on_suspensions_tab_pressed() -> void:
	_select_tab(PartData.Category.SUSPENSIONS)
