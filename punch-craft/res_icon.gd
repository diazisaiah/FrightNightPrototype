class_name ResIcon
extends Control
## A resource token: the resource's icon on a small dark disc with a colored
## rim, the same everywhere a resource is shown (camp, HUD, costs, rewards).

## Every resource with its name, icon and color.
const INFO := {
	"coins": {"name": "Coins", "icon": "coin", "color": Color(1.0, 0.78, 0.3)},
	"silver": {"name": "Silver", "icon": "silver", "color": Color(0.8, 0.85, 0.93)},
	"xp": {"name": "XP", "icon": "xp", "color": Color(0.42, 0.95, 0.72)},
	"souls": {"name": "Souls", "icon": "ghost", "color": Color(0.55, 0.95, 0.9)},
	"skill_points": {"name": "Skill points", "icon": "skill_point", "color": Color(0.55, 0.75, 1.0)},
	"stat_points": {"name": "Stat points", "icon": "stat_point", "color": Color(1.0, 0.56, 0.42)},
	"knuckles": {"name": "Knuckle HP", "icon": "heart", "color": Color(0.95, 0.4, 0.38)},
}

var resource := "coins":
	set(value):
		resource = value
		queue_redraw()
## Brightness pulse (set by tweens for a pop).
var glow := 0.0:
	set(value):
		glow = value
		queue_redraw()


static func color_of(id: String) -> Color:
	return INFO[id].color if INFO.has(id) else UiTheme.TEXT


static func name_of(id: String) -> String:
	return INFO[id].name if INFO.has(id) else id.capitalize()


static func make(id: String, size := 22.0) -> ResIcon:
	var icon := ResIcon.new()
	icon.resource = id
	icon.custom_minimum_size = Vector2(size, size)
	icon.size = Vector2(size, size)
	return icon


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if not INFO.has(resource):
		return
	var info: Dictionary = INFO[resource]
	var color: Color = info.color
	var radius := minf(size.x, size.y) / 2.0
	var center := size / 2.0
	var disc := color.darkened(0.78)
	disc.a = 0.92
	draw_circle(center + Vector2(0, 1.5), radius, Color(0, 0, 0, 0.45))
	draw_circle(center, radius, disc.lerp(color.darkened(0.4), glow * 0.5))
	draw_arc(center, radius - 1.0, 0.0, TAU, 32, Color(color, 0.75 + glow * 0.25), maxf(1.2, radius * 0.11), true)
	draw_arc(center, radius - 2.5, PI * 1.1, PI * 1.6, 10, Color(1, 1, 1, 0.18), 1.2, true)
	Icons.draw(self, info.icon, center, radius * 1.22, color.lightened(glow * 0.4), disc)
