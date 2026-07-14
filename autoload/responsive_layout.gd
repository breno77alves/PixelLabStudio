class_name ResponsiveLayout
extends RefCounted

const REFERENCE_VIEWPORT := Vector2(1280.0, 720.0)
const MIN_LOGICAL_WINDOW := Vector2i(960, 540)
const MIN_CENTER_CANVAS_WIDTH := 360.0
const DEFAULT_POPUP_MARGIN := 16.0


static func display_scale_from_dpi(dpi: int) -> float:
	if dpi <= 0:
		return 1.0
	return clampf(snappedf(float(dpi) / 96.0, 0.25), 1.0, 3.0)


static func native_minimum_size(ui_scale: float, usable_size: Vector2i) -> Vector2i:
	var safe_scale := maxf(ui_scale, 0.1)
	var desired := Vector2i(
		roundi(float(MIN_LOGICAL_WINDOW.x) * safe_scale),
		roundi(float(MIN_LOGICAL_WINDOW.y) * safe_scale)
	)
	return Vector2i(
		mini(desired.x, maxi(usable_size.x, 1)),
		mini(desired.y, maxi(usable_size.y, 1))
	)


static func sanitize_window_size(saved_size: Variant, ui_scale: float, usable_rect: Rect2i) -> Vector2i:
	var requested := native_minimum_size(ui_scale, usable_rect.size)
	if saved_size is Vector2i:
		requested = saved_size
	elif saved_size is Vector2:
		requested = Vector2i(roundi(saved_size.x), roundi(saved_size.y))

	var minimum := native_minimum_size(ui_scale, usable_rect.size)
	var maximum := Vector2i(maxi(usable_rect.size.x, 1), maxi(usable_rect.size.y, 1))
	return Vector2i(
		clampi(requested.x, minimum.x, maximum.x),
		clampi(requested.y, minimum.y, maximum.y)
	)


static func camera_fit(viewport_size: Vector2) -> float:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return 1.0
	return minf(
		viewport_size.x / REFERENCE_VIEWPORT.x,
		viewport_size.y / REFERENCE_VIEWPORT.y
	)


static func camera_zoom(viewport_size: Vector2, user_zoom_percent: float) -> float:
	return camera_fit(viewport_size) * maxf(user_zoom_percent, 1.0) / 100.0


static func clamp_panel_width(
	requested_width: float,
	minimum_width: float,
	maximum_viewport_ratio: float,
	viewport_width: float,
	opposite_panel_width: float,
	minimum_canvas_width: float
) -> float:
	var ratio_limit := viewport_width * maximum_viewport_ratio
	var canvas_limit := viewport_width - opposite_panel_width - minimum_canvas_width
	var maximum_width := maxf(minimum_width, minf(ratio_limit, canvas_limit))
	return clampf(requested_width, minimum_width, maximum_width)


static func clamp_popup_rect(
	preferred_rect: Rect2,
	viewport_size: Vector2,
	margin: float = DEFAULT_POPUP_MARGIN
) -> Rect2:
	var safe_margin := maxf(margin, 0.0)
	var maximum_size := Vector2(
		maxf(viewport_size.x - safe_margin * 2.0, 1.0),
		maxf(viewport_size.y - safe_margin * 2.0, 1.0)
	)
	var bounded_size := Vector2(
		minf(preferred_rect.size.x, maximum_size.x),
		minf(preferred_rect.size.y, maximum_size.y)
	)
	var maximum_position := viewport_size - bounded_size - Vector2.ONE * safe_margin
	var bounded_position := Vector2(
		clampf(preferred_rect.position.x, safe_margin, maxf(safe_margin, maximum_position.x)),
		clampf(preferred_rect.position.y, safe_margin, maxf(safe_margin, maximum_position.y))
	)
	return Rect2(bounded_position, bounded_size)


static func vertical_panel_bounds(
	viewport_height: float,
	parent_global_y: float,
	content_top: float,
	content_height: float,
	top_margin: float,
	bottom_margin: float
) -> Vector2:
	var top_aligned := maxf(top_margin, 0.0) - parent_global_y - content_top
	var bottom_aligned := (
		viewport_height
		- maxf(bottom_margin, 0.0)
		- parent_global_y
		- content_top
		- maxf(content_height, 0.0)
	)
	return Vector2(minf(top_aligned, bottom_aligned), maxf(top_aligned, bottom_aligned))


static func panel_fits_vertical_space(
	content_height: float,
	viewport_height: float,
	top_margin: float,
	bottom_margin: float
) -> bool:
	var available_height := maxf(viewport_height - maxf(top_margin, 0.0) - maxf(bottom_margin, 0.0), 0.0)
	return content_height <= available_height


static func scrollbar_metrics(position_range: float, visible_height: float, content_height: float) -> Vector2:
	var safe_range := maxf(position_range, 0.0)
	var visible_fraction := clampf(visible_height / maxf(content_height, 1.0), 0.0, 1.0)
	var page_size := safe_range * visible_fraction
	return Vector2(safe_range + page_size, page_size)


static func world_modal_scale(camera_zoom: Vector2) -> Vector2:
	if is_zero_approx(camera_zoom.x) or is_zero_approx(camera_zoom.y):
		return Vector2.ONE
	return Vector2(1.0 / camera_zoom.x, 1.0 / camera_zoom.y)
