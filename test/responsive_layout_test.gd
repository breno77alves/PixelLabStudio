extends SceneTree

const ResponsiveLayout = preload("../autoload/responsive_layout.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	_test_display_scale_is_stable_and_bounded()
	_test_tiny_saved_window_is_repaired()
	_test_window_size_stays_inside_usable_screen()
	_test_minimum_shrinks_only_for_a_smaller_screen()
	_test_camera_fit_preserves_reference_framing()
	_test_camera_fit_uses_limiting_dimension()
	_test_user_zoom_composes_with_automatic_fit()
	_test_panel_bounds_never_invert()
	_test_panels_reserve_supported_center_canvas()
	_test_popup_is_clamped_inside_viewport()

	if _failures.is_empty():
		print("responsive_layout_test: all tests passed")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_display_scale_is_stable_and_bounded() -> void:
	_assert_approx(ResponsiveLayout.display_scale_from_dpi(96), 1.0, "96 DPI maps to 100%")
	_assert_approx(ResponsiveLayout.display_scale_from_dpi(144), 1.5, "144 DPI maps to 150%")
	_assert_approx(ResponsiveLayout.display_scale_from_dpi(110), 1.25, "display scale snaps to quarters")
	_assert_approx(ResponsiveLayout.display_scale_from_dpi(600), 3.0, "display scale has an upper bound")


func _test_tiny_saved_window_is_repaired() -> void:
	var repaired := ResponsiveLayout.sanitize_window_size(
		Vector2i(120, 74), 1.0, Rect2i(0, 0, 1920, 1040)
	)
	_assert_equal(repaired, Vector2i(960, 540), "repairs a corrupt tiny saved window")


func _test_window_size_stays_inside_usable_screen() -> void:
	var repaired := ResponsiveLayout.sanitize_window_size(
		Vector2i(5000, 3000), 1.5, Rect2i(0, 0, 2293, 912)
	)
	_assert_equal(repaired, Vector2i(2293, 912), "caps a saved window at the usable screen")


func _test_minimum_shrinks_only_for_a_smaller_screen() -> void:
	_assert_equal(
		ResponsiveLayout.native_minimum_size(1.5, Vector2i(2293, 912)),
		Vector2i(1440, 810),
		"scales the logical minimum for the active display"
	)
	_assert_equal(
		ResponsiveLayout.native_minimum_size(1.5, Vector2i(1280, 720)),
		Vector2i(1280, 720),
		"does not demand a native minimum larger than the screen"
	)


func _test_camera_fit_preserves_reference_framing() -> void:
	_assert_approx(ResponsiveLayout.camera_fit(Vector2(960, 540)), 0.75, "fits a smaller 16:9 viewport")
	_assert_approx(ResponsiveLayout.camera_fit(Vector2(1280, 720)), 1.0, "keeps the reference viewport at 100%")
	_assert_approx(ResponsiveLayout.camera_fit(Vector2(1920, 1080)), 1.5, "fits a larger 16:9 viewport")


func _test_camera_fit_uses_limiting_dimension() -> void:
	_assert_approx(ResponsiveLayout.camera_fit(Vector2(1600, 720)), 1.0, "height limits an ultrawide viewport")
	_assert_approx(ResponsiveLayout.camera_fit(Vector2(1280, 900)), 1.0, "width limits a tall viewport")


func _test_user_zoom_composes_with_automatic_fit() -> void:
	_assert_approx(
		ResponsiveLayout.camera_zoom(Vector2(960, 540), 150.0),
		1.125,
		"keeps user zoom independent from automatic viewport fit"
	)


func _test_panel_bounds_never_invert() -> void:
	_assert_approx(
		ResponsiveLayout.clamp_panel_width(100.0, 220.0, 0.4, 120.0, 310.0, 360.0),
		220.0,
		"returns the minimum during a tiny transient viewport"
	)


func _test_panels_reserve_supported_center_canvas() -> void:
	var left_width := ResponsiveLayout.clamp_panel_width(400.0, 220.0, 0.4, 960.0, 310.0, 360.0)
	_assert_approx(left_width, 290.0, "left panel leaves room for the right panel and canvas")
	var right_width := ResponsiveLayout.clamp_panel_width(400.0, 310.0, 0.25, 1280.0, 265.0, 360.0)
	_assert_approx(right_width, 320.0, "right panel respects its viewport ratio")


func _test_popup_is_clamped_inside_viewport() -> void:
	var bounded := ResponsiveLayout.clamp_popup_rect(
		Rect2(Vector2(900, 500), Vector2(1200, 800)), Vector2(960, 540), 16.0
	)
	_assert_equal(bounded.position, Vector2(16, 16), "moves an oversized popup into the viewport")
	_assert_equal(bounded.size, Vector2(928, 508), "shrinks an oversized popup to viewport margins")


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, expected, actual])


func _assert_approx(actual: float, expected: float, message: String) -> void:
	if not is_equal_approx(actual, expected):
		_failures.append("%s: expected %s, got %s" % [message, expected, actual])
