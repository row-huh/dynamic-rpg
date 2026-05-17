class_name JrpgUiTheme

const BG := Color(0.1, 0.08, 0.125, 0.88)
const BORDER := Color(0.91, 0.84, 0.72, 1.0)
const BORDER_DARK := Color(0.45, 0.38, 0.32, 1.0)
const TEXT := Color(0.96, 0.94, 0.9, 1.0)
const NAMEPLATE := Color(0.14, 0.11, 0.18, 0.95)


static func make_panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = BG
	s.border_width_left = 4
	s.border_width_top = 4
	s.border_width_right = 4
	s.border_width_bottom = 4
	s.border_color = BORDER
	s.border_blend = true
	s.corner_radius_top_left = 2
	s.corner_radius_top_right = 2
	s.corner_radius_bottom_right = 2
	s.corner_radius_bottom_left = 2
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 6
	s.content_margin_left = 14
	s.content_margin_top = 12
	s.content_margin_right = 14
	s.content_margin_bottom = 12
	return s


static func make_nameplate_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = NAMEPLATE
	s.border_width_left = 3
	s.border_width_top = 3
	s.border_width_right = 3
	s.border_width_bottom = 3
	s.border_color = BORDER
	s.content_margin_left = 10
	s.content_margin_top = 4
	s.content_margin_right = 10
	s.content_margin_bottom = 4
	return s


static func make_button_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.22, 0.18, 0.28, 0.95)
	s.border_width_left = 2
	s.border_width_top = 2
	s.border_width_right = 2
	s.border_width_bottom = 2
	s.border_color = BORDER
	s.content_margin_left = 12
	s.content_margin_top = 6
	s.content_margin_right = 12
	s.content_margin_bottom = 6
	return s
