extends Control
## CosmeticsPicker - UI for viewing and selecting cosmetic items

signal cosmetic_selected(cosmetic_id: String, category: String)

var current_subcategory: String = "livery"

@onready var subcategory_tabs: HBoxContainer = $VBoxContainer/SubcategoryTabs
@onready var items_container: VBoxContainer = $VBoxContainer/ScrollContainer/ItemsContainer
@onready var preview_sprite: TextureRect = $VBoxContainer/PreviewContainer/PreviewSprite
@onready var preview_label: Label = $VBoxContainer/PreviewContainer/PreviewLabel
@onready var currency_label: Label = $VBoxContainer/Header/CurrencyLabel

const TAB_COLOR_ACTIVE := Color(1, 1, 0.6, 1)
const TAB_COLOR_INACTIVE := Color(0.7, 0.7, 0.7, 1)

func _ready() -> void:
	if CosmeticsManager:
		CosmeticsManager.cosmetic_unlocked.connect(_on_cosmetic_unlocked)
	_update_currency()
	_select_subcategory("livery")

func _update_currency() -> void:
	if PlayerProgress and currency_label:
		currency_label.text = "%d" % PlayerProgress.currency

func _select_subcategory(subcategory: String) -> void:
	current_subcategory = subcategory
	_update_subcategory_tabs()
	_refresh_items_list()

func _update_subcategory_tabs() -> void:
	for child in subcategory_tabs.get_children():
		if child is Button:
			var is_active = child.name.to_lower().begins_with(current_subcategory)
			child.modulate = TAB_COLOR_ACTIVE if is_active else TAB_COLOR_INACTIVE

func _refresh_items_list() -> void:
	# Clear existing items
	for child in items_container.get_children():
		child.queue_free()

	if not CosmeticsManager:
		return

	# Get cosmetics for current subcategory
	var items = CosmeticsManager.get_cosmetics_by_category(current_subcategory)

	# Create item entries
	for item in items:
		var item_panel = _create_cosmetic_item(item)
		items_container.add_child(item_panel)

func _create_cosmetic_item(item: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 60)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	# Preview icon
	var preview = ColorRect.new()
	preview.custom_minimum_size = Vector2(50, 50)
	preview.color = _get_preview_color(item)
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
	button.custom_minimum_size = Vector2(80, 35)
	hbox.add_child(button)

	var item_id = item.get("id", "")

	if item.get("equipped", false):
		button.text = "EQUIPPED"
		button.disabled = true
	elif item.get("owned", false):
		button.text = "EQUIP"
		button.pressed.connect(_on_equip_pressed.bind(item_id))
	elif CosmeticsManager.is_purchasable(item_id):
		var price = item.get("price", 0)
		button.text = "%d" % price
		button.disabled = not PlayerProgress.can_afford(price) if PlayerProgress else true
		button.pressed.connect(_on_purchase_pressed.bind(item_id))
	else:
		button.text = "LOCKED"
		button.disabled = true

	return panel

func _get_preview_color(item: Dictionary) -> Color:
	var item_id = item.get("id", "")

	match current_subcategory:
		"livery":
			# Return a color based on livery type
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

func _on_equip_pressed(item_id: String) -> void:
	if CosmeticsManager and CosmeticsManager.equip_cosmetic(item_id):
		_refresh_items_list()
		cosmetic_selected.emit(item_id, current_subcategory)

func _on_purchase_pressed(item_id: String) -> void:
	if CosmeticsManager and CosmeticsManager.purchase_cosmetic(item_id):
		_update_currency()
		_refresh_items_list()

func _on_cosmetic_unlocked(_cosmetic_id: String, _category: String) -> void:
	_refresh_items_list()

# Tab button handlers
func _on_livery_tab_pressed() -> void:
	_select_subcategory("livery")

func _on_decal_tab_pressed() -> void:
	_select_subcategory("decal")

func _on_wheels_tab_pressed() -> void:
	_select_subcategory("wheels")

# Secondary color for two-tone liveries
func _on_secondary_color_pressed() -> void:
	# This would open a color picker for the secondary livery color
	pass
