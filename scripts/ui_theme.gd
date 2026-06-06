class_name UITheme
extends RefCounted
## Shared visual language for every 2D UI surface (menu, garage, arena select, HUD,
## finish). Glassy rounded panels, soft shadows, a consistent palette + button styling
## so the whole game reads as one polished product instead of raw default controls.

const BG0 := Color(0.05, 0.07, 0.14)
const BG1 := Color(0.10, 0.13, 0.26)
const PANEL := Color(0.09, 0.12, 0.22, 0.82)
const PANEL_SOFT := Color(0.12, 0.16, 0.28, 0.62)
const BORDER := Color(1, 1, 1, 0.12)
const ACCENT := Color(1.0, 0.80, 0.22)   # gold
const ACCENT2 := Color(0.20, 0.86, 1.0)  # cyan
const GOOD := Color(0.32, 0.86, 0.48)
const BAD := Color(0.96, 0.38, 0.40)
const TEXT := Color(0.95, 0.97, 1.0)
const DIM := Color(0.70, 0.78, 0.92)


static func glass(bg := PANEL, radius := 18, border := BORDER, bw := 2, shadow := true) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(bw)
	s.border_color = border
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	if shadow:
		s.shadow_color = Color(0, 0, 0, 0.45)
		s.shadow_size = 10
		s.shadow_offset = Vector2(0, 5)
	return s


static func chip(bg: Color, radius := 999) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


static func style_button(b: Button, base: Color, fg := Color(1, 1, 1), fs := 30, radius := 16) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = base
	normal.set_corner_radius_all(radius)
	normal.set_border_width_all(2)
	normal.border_color = Color(1, 1, 1, 0.28)
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	normal.content_margin_top = 12
	normal.content_margin_bottom = 12
	normal.shadow_color = Color(0, 0, 0, 0.4)
	normal.shadow_size = 8
	normal.shadow_offset = Vector2(0, 4)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = base.lightened(0.12)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = base.darkened(0.18)
	pressed.shadow_size = 3
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.3, 0.32, 0.4, 0.6)
	disabled.border_color = Color(1, 1, 1, 0.08)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", normal)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.45))
	b.add_theme_font_size_override("font_size", fs)
	b.focus_mode = Control.FOCUS_NONE


static func label(text: String, fs: int, col := TEXT, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		l.add_theme_constant_override("outline_size", outline)
	return l
