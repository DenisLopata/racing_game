extends Control
## Garage - UI for viewing, purchasing, and equipping car parts

var current_category: PartData.Category = PartData.Category.ENGINES

@onready var parts_container: VBoxContainer = $VBoxContainer/ContentRow/ScrollContainer/PartsContainer
@onready var currency_label: Label = $VBoxContainer/Header/StatsContainer/CurrencyLabel
@onready var wins_label: Label = $VBoxContainer/Header/StatsContainer/WinsLabel
@onready var car_stats_label: Label = $VBoxContainer/ContentRow/CarPreview/VBoxContainer/StatsLabel
@onready var car_sprite: TextureRect = $VBoxContainer/ContentRow/CarPreview/VBoxContainer/CarSprite
@onready var color_popup: PanelContainer = $ColorPopup
@onready var color_grid: GridContainer = $ColorPopup/VBoxContainer/ColorGrid

@onready var tab_buttons: Array[Button] = [
	$VBoxContainer/TabsContainer/EnginesTab,
	$VBoxContainer/TabsContainer/TiresTab,
	$VBoxContainer/TabsContainer/SpoilersTab,
	$VBoxContainer/TabsContainer/BrakesTab,
	$VBoxContainer/TabsContainer/SuspensionsTab,
	$VBoxContainer/TabsContainer/CosmeticsTab
]

# Cosmetics UI references
@onready var cosmetics_container: ScrollContainer = $VBoxContainer/ContentRow/CosmeticsContainer
@onready var cosmetics_items: VBoxContainer = $VBoxContainer/ContentRow/CosmeticsContainer/CosmeticsVBox/CosmeticsItems
@onready var cosmetics_subtabs: Array[Button] = [
	$VBoxContainer/ContentRow/CosmeticsContainer/CosmeticsVBox/SubTabs/LiveryTab,
	$VBoxContainer/ContentRow/CosmeticsContainer/CosmeticsVBox/SubTabs/DecalTab,
	$VBoxContainer/ContentRow/CosmeticsContainer/CosmeticsVBox/SubTabs/WheelsTab
]

var cosmetics_mode: bool = false
var current_cosmetics_category: String = "livery"

# Damage UI references
@onready var damage_bars: Dictionary = {
	"engines": $VBoxContainer/ContentRow/CarPreview/VBoxContainer/DamageContainer/EngineRow/EngineBar,
	"tires": $VBoxContainer/ContentRow/CarPreview/VBoxContainer/DamageContainer/TiresRow/TiresBar,
	"brakes": $VBoxContainer/ContentRow/CarPreview/VBoxContainer/DamageContainer/BrakesRow/BrakesBar,
	"suspensions": $VBoxContainer/ContentRow/CarPreview/VBoxContainer/DamageContainer/SuspensionRow/SuspensionBar,
	"spoilers": $VBoxContainer/ContentRow/CarPreview/VBoxContainer/DamageContainer/SpoilerRow/SpoilerBar
}

@onready var repair_buttons: Dictionary = {
	"engines": $VBoxContainer/ContentRow/CarPreview/VBoxContainer/DamageContainer/EngineRow/EngineRepair,
	"tires": $VBoxContainer/ContentRow/CarPreview/VBoxContainer/DamageContainer/TiresRow/TiresRepair,
	"brakes": $VBoxContainer/ContentRow/CarPreview/VBoxContainer/DamageContainer/BrakesRow/BrakesRepair,
	"suspensions": $VBoxContainer/ContentRow/CarPreview/VBoxContainer/DamageContainer/SuspensionRow/SuspensionRepair,
	"spoilers": $VBoxContainer/ContentRow/CarPreview/VBoxContainer/DamageContainer/SpoilerRow/SpoilerRepair
}

@onready var repair_all_button: Button = $VBoxContainer/ContentRow/CarPreview/VBoxContainer/RepairAllButton

const PartItemScene := preload("res://scenes/UI/part_item.tscn")

const TAB_COLOR_ACTIVE := Color(1, 1, 0.6, 1)
const TAB_COLOR_INACTIVE := Color(0.7, 0.7, 0.7, 1)

func _ready() -> void:
	_connect_signals()
	_update_header()
	_update_car_stats()
	_update_damage_display()
	_setup_color_popup()
	_update_car_color()
	_select_tab(PartData.Category.ENGINES)

## Connect to PlayerProgress signals
func _connect_signals() -> void:
	if PlayerProgress:
		PlayerProgress.currency_changed.connect(_on_currency_changed)
		PlayerProgress.part_purchased.connect(_on_part_changed)
		PlayerProgress.part_equipped.connect(_on_part_changed)
		PlayerProgress.damage_changed.connect(_on_damage_changed)
		PlayerProgress.part_repaired.connect(_on_part_repaired)

## Update header with current currency and wins
func _update_header() -> void:
	if PlayerProgress:
		currency_label.text = "%d" % PlayerProgress.currency
		wins_label.text = "%d Wins" % PlayerProgress.wins

## Update car stats display from equipped parts
func _update_car_stats() -> void:
	if PlayerProgress and car_stats_label:
		var modifiers := CarModifiers.from_equipped(PlayerProgress.get_all_equipped())
		car_stats_label.text = "ACC: %.2fx\nSPD: %.2fx\nBRK: %.2fx\nGRP: %.2fx" % [
			modifiers.acceleration_mult,
			modifiers.max_speed_mult,
			modifiers.brake_mult,
			modifiers.grip_mult
		]

## Setup color popup with color buttons
func _setup_color_popup() -> void:
	if not PlayerProgress or not color_grid:
		return

	var colors := PlayerProgress.get_available_colors()
	for i in range(colors.size()):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(32, 32)
		btn.modulate = colors[i]
		btn.pressed.connect(_on_popup_color_pressed.bind(i))
		color_grid.add_child(btn)

## Handle color selection in popup
func _on_popup_color_pressed(index: int) -> void:
	PlayerProgress.set_car_color(index)
	_update_car_color()
	color_popup.visible = false

## Update car preview with selected color
func _update_car_color() -> void:
	if PlayerProgress and car_sprite:
		car_sprite.modulate = PlayerProgress.get_car_color()

## Select a category tab
func _select_tab(category: PartData.Category) -> void:
	current_category = category
	cosmetics_mode = false
	_update_tab_visuals()
	_update_content_visibility()
	_refresh_parts_list()

## Select cosmetics mode
func _select_cosmetics() -> void:
	cosmetics_mode = true
	_update_tab_visuals()
	_update_content_visibility()
	_refresh_cosmetics_list()

## Update content visibility based on mode
func _update_content_visibility() -> void:
	$VBoxContainer/ContentRow/ScrollContainer.visible = not cosmetics_mode
	cosmetics_container.visible = cosmetics_mode

## Update tab button visuals
func _update_tab_visuals() -> void:
	var categories := PartData.get_all_categories()
	for i in range(tab_buttons.size()):
		var button := tab_buttons[i]
		# Cosmetics tab is the last one (index 5)
		if i == 5:
			button.modulate = TAB_COLOR_ACTIVE if cosmetics_mode else TAB_COLOR_INACTIVE
		elif not cosmetics_mode and i < categories.size() and categories[i] == current_category:
			button.modulate = TAB_COLOR_ACTIVE
		else:
			button.modulate = TAB_COLOR_INACTIVE

## Update cosmetics subtab visuals
func _update_cosmetics_subtabs() -> void:
	var subtab_categories = ["livery", "decal", "wheels"]
	for i in range(cosmetics_subtabs.size()):
		if subtab_categories[i] == current_cosmetics_category:
			cosmetics_subtabs[i].modulate = TAB_COLOR_ACTIVE
		else:
			cosmetics_subtabs[i].modulate = TAB_COLOR_INACTIVE

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
		_update_car_stats()

## Handle currency changed signal
func _on_currency_changed(_new_amount: int) -> void:
	_update_header()
	_refresh_parts_list()

## Handle part state changed
func _on_part_changed(_part_id: String, _category: PartData.Category) -> void:
	_refresh_parts_list()
	_update_car_stats()

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

func _on_cosmetics_tab_pressed() -> void:
	_select_cosmetics()

func _on_change_color_button_pressed() -> void:
	color_popup.visible = true

func _on_close_popup_pressed() -> void:
	color_popup.visible = false

# =============================================================================
# Damage Display
# =============================================================================

## Update damage bars and repair buttons
func _update_damage_display() -> void:
	if not PlayerProgress:
		return

	var damage_state = PlayerProgress.get_damage_state()
	if not damage_state:
		return

	for part in damage_bars:
		var bar: ProgressBar = damage_bars[part]
		var button: Button = repair_buttons[part]
		var health = damage_state.get_part_health(part)

		# Update bar value
		bar.value = health * 100.0

		# Color code based on health
		if health > 0.7:
			bar.modulate = Color.GREEN
		elif health > 0.3:
			bar.modulate = Color.YELLOW
		elif health > 0:
			bar.modulate = Color.RED
		else:
			bar.modulate = Color.DARK_RED

		# Update repair button
		var cost = PlayerProgress.get_repair_cost(part)
		if cost > 0:
			button.text = "%d" % cost
			button.disabled = not PlayerProgress.can_afford(cost)
			button.visible = true
		else:
			button.text = "OK"
			button.disabled = true
			button.visible = true

	# Update repair all button
	var total_cost = PlayerProgress.get_total_repair_cost()
	if total_cost > 0:
		repair_all_button.text = "REPAIR ALL (%d)" % total_cost
		repair_all_button.disabled = not PlayerProgress.can_afford(total_cost)
	else:
		repair_all_button.text = "ALL REPAIRED"
		repair_all_button.disabled = true

## Handle damage changed signal
func _on_damage_changed(_part: String, _new_health: float) -> void:
	_update_damage_display()
	_update_car_stats()

## Handle part repaired signal
func _on_part_repaired(_part: String) -> void:
	_update_damage_display()
	_update_header()
	_update_car_stats()

# =============================================================================
# Repair Button Handlers
# =============================================================================

func _on_engine_repair_pressed() -> void:
	_repair_part("engines")

func _on_tires_repair_pressed() -> void:
	_repair_part("tires")

func _on_brakes_repair_pressed() -> void:
	_repair_part("brakes")

func _on_suspension_repair_pressed() -> void:
	_repair_part("suspensions")

func _on_spoiler_repair_pressed() -> void:
	_repair_part("spoilers")

func _on_repair_all_pressed() -> void:
	if PlayerProgress.repair_all():
		_update_damage_display()
		_update_header()

func _repair_part(part: String) -> void:
	if PlayerProgress.repair_part(part):
		_update_damage_display()
		_update_header()

# =============================================================================
# Cosmetics System
# =============================================================================

## Refresh cosmetics list for current subcategory
func _refresh_cosmetics_list() -> void:
	# Clear existing items
	for child in cosmetics_items.get_children():
		child.queue_free()

	if not CosmeticsManager:
		return

	_update_cosmetics_subtabs()

	# Get cosmetics for current subcategory
	var items = CosmeticsManager.get_cosmetics_by_category(current_cosmetics_category)

	# Create item entries
	for item in items:
		var item_panel = _create_cosmetic_item(item)
		cosmetics_items.add_child(item_panel)

## Create a cosmetic item panel
func _create_cosmetic_item(item: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 50)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	# Preview color rect
	var preview = ColorRect.new()
	preview.custom_minimum_size = Vector2(40, 40)
	preview.color = _get_cosmetic_preview_color(item)
	hbox.add_child(preview)

	# Info container
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	# Name label
	var name_label = Label.new()
	name_label.text = item.get("name", "Unknown")
	if item.get("equipped", false):
		name_label.text += " [EQUIPPED]"
		name_label.add_theme_color_override("font_color", Color.YELLOW)
	elif item.get("owned", false):
		name_label.add_theme_color_override("font_color", Color.WHITE)
	else:
		name_label.add_theme_color_override("font_color", Color.GRAY)
	info_vbox.add_child(name_label)

	# Description / unlock progress
	var desc_label = Label.new()
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	if item.get("owned", false):
		desc_label.text = item.get("description", "")
	else:
		desc_label.text = CosmeticsManager.get_unlock_progress(item.get("id", ""))
	info_vbox.add_child(desc_label)

	# Action button
	var button = Button.new()
	button.custom_minimum_size = Vector2(70, 30)
	hbox.add_child(button)

	var item_id = item.get("id", "")

	if item.get("equipped", false):
		button.text = "EQUIPPED"
		button.disabled = true
	elif item.get("owned", false):
		button.text = "EQUIP"
		button.pressed.connect(_on_cosmetic_equip_pressed.bind(item_id))
	elif CosmeticsManager.is_purchasable(item_id):
		var price = item.get("price", 0)
		button.text = "%d" % price
		button.disabled = not PlayerProgress.can_afford(price) if PlayerProgress else true
		button.pressed.connect(_on_cosmetic_purchase_pressed.bind(item_id))
	else:
		button.text = "LOCKED"
		button.disabled = true

	return panel

## Get preview color for cosmetic item
func _get_cosmetic_preview_color(item: Dictionary) -> Color:
	var item_id = item.get("id", "")

	match current_cosmetics_category:
		"livery":
			match item_id:
				"livery_solid": return Color(0.2, 0.6, 1.0)
				"livery_stripes": return Color(0.8, 0.2, 0.2)
				"livery_gradient": return Color(0.2, 0.8, 0.2)
				"livery_flames": return Color(1.0, 0.5, 0.0)
				"livery_carbon": return Color(0.3, 0.3, 0.3)
				"livery_camo": return Color(0.4, 0.5, 0.3)
		"decal":
			return Color(0.9, 0.9, 0.9) if item.get("owned", false) else Color(0.4, 0.4, 0.4)
		"wheels":
			match item_id:
				"wheels_standard": return Color(0.5, 0.5, 0.5)
				"wheels_sport": return Color(0.7, 0.7, 0.7)
				"wheels_gold": return Color(1.0, 0.85, 0.0)
				"wheels_chrome": return Color(0.9, 0.9, 1.0)

	return Color(0.5, 0.5, 0.5)

## Handle cosmetic equip
func _on_cosmetic_equip_pressed(item_id: String) -> void:
	if CosmeticsManager and CosmeticsManager.equip_cosmetic(item_id):
		_refresh_cosmetics_list()
		_update_car_color()

## Handle cosmetic purchase
func _on_cosmetic_purchase_pressed(item_id: String) -> void:
	if CosmeticsManager and CosmeticsManager.purchase_cosmetic(item_id):
		_update_header()
		_refresh_cosmetics_list()

# Cosmetics subtab handlers
func _on_livery_subtab_pressed() -> void:
	current_cosmetics_category = "livery"
	_refresh_cosmetics_list()

func _on_decal_subtab_pressed() -> void:
	current_cosmetics_category = "decal"
	_refresh_cosmetics_list()

func _on_wheels_subtab_pressed() -> void:
	current_cosmetics_category = "wheels"
	_refresh_cosmetics_list()
