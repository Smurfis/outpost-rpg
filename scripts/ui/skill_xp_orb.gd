extends Control
## Compact RuneScape/Roblox-style radial currently-trained SKILL XP widget.
## The full-width strip still owns CHARACTER XP; this icon tracks the actual
## persisted 60-XP mastery segments (gathering or existing weapon familiarity).
const POINTS: int = 42
const ICONS: Dictionary = {
	"woodcutting": "axe",
	"mining": "pickaxe",
	"foraging": "satchel",
	"training_blade": "attack",
	"spear": "spear",
	"iron_blade": "iron_blade"
}
var skill_id: String = "training_blade"
var skill_xp: int = 0
var rank: int = 1
var progress: float = 0.0
var icon: TextureRect

func _ready() -> void:
	name = "TrainedSkillOrb"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon = TextureRect.new()
	icon.name = "TrainingSkillIcon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(icon)
	_update_icon()
	resized.connect(_resize_icon)
	_resize_icon()

func set_skill(id: String, total_xp: int) -> void:
	if id.is_empty():
		return
	var new_xp: int = maxi(0, total_xp)
	if id == skill_id and new_xp == skill_xp and icon != null and icon.texture != null:
		return
	skill_id = id
	skill_xp = new_xp
	rank = mini(10, 1 + skill_xp / 60)
	progress = 1.0 if rank >= 10 else float(skill_xp % 60) / 60.0
	if is_inside_tree():
		_update_icon()
	queue_redraw()

func _update_icon() -> void:
	if icon == null:
		return
	var icon_id: String = str(ICONS.get(skill_id, "attack"))
	var path: String = "res://assets/icons/" + icon_id + ".svg"
	if ResourceLoader.exists(path):
		icon.texture = load(path) as Texture2D

func _resize_icon() -> void:
	if icon == null:
		return
	var side: float = minf(size.x, size.y)
	icon.position = (size - Vector2.ONE * side) * 0.5 + Vector2.ONE * side * 0.22
	icon.size = Vector2.ONE * side * 0.56

func _draw() -> void:
	var radius: float = maxf(6.0, minf(size.x, size.y) * 0.5 - 3.0)
	var center: Vector2 = size * 0.5
	draw_circle(center, radius + 1.0, Color(0.09, 0.07, 0.10, 0.44))
	draw_circle(center, radius - 3.0, Color(0.15, 0.11, 0.16, 0.30))
	draw_arc(center, radius - 1.5, -PI / 2.0, 3.0 * PI / 2.0, POINTS, Color(0.61, 0.48, 0.35, 0.60), 3.0, true)
	if progress > 0.0:
		draw_arc(center, radius - 1.5, -PI / 2.0, -PI / 2.0 + TAU * progress,
				POINTS, Color(0.86, 0.64, 0.99, 0.92), 4.0, true)
