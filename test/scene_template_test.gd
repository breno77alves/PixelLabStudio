extends SceneTree

const SceneTemplate = preload("../autoload/scene_template.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	_test_normalizes_values_to_runtime_bounds()
	_test_rejects_missing_names()
	_test_overwrites_names_case_insensitively()
	_test_rejects_a_new_template_past_the_limit()
	_test_filters_corrupted_saved_entries()
	_test_deletes_only_the_selected_template()
	_test_finds_a_template_by_case_insensitive_name()

	if _failures.is_empty():
		print("scene_template_test: all tests passed")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_normalizes_values_to_runtime_bounds() -> void:
	var normalized := SceneTemplate.normalize(
		{"name": "  Vertical OBS  ", "width": 320, "height": 9000, "zoom": 999},
		Vector2i(960, 540)
	)
	_assert_equal(normalized, {
		"name": "Vertical OBS",
		"width": 960,
		"height": 4320,
		"zoom": 400,
	}, "normalizes a template to supported bounds")


func _test_rejects_missing_names() -> void:
	_assert_equal(
		SceneTemplate.normalize({"width": 1280, "height": 720, "zoom": 100}),
		{},
		"rejects a template without a name"
	)


func _test_overwrites_names_case_insensitively() -> void:
	var existing := [{"name": "Gameplay", "width": 1280, "height": 720, "zoom": 100}]
	var result := SceneTemplate.upsert(
		existing,
		{"name": "gameplay", "width": 1920, "height": 1080, "zoom": 125}
	)
	_assert_equal(result["error"], "", "accepts an overwrite")
	_assert_equal(result["index"], 0, "preserves the overwritten template position")
	_assert_equal(result["templates"][0]["width"], 1920, "overwrites the existing values")


func _test_rejects_a_new_template_past_the_limit() -> void:
	var existing: Array = []
	for index in range(SceneTemplate.MAX_TEMPLATES):
		existing.append({
			"name": "Scene %d" % index,
			"width": 1280,
			"height": 720,
			"zoom": 100,
		})
	var result := SceneTemplate.upsert(
		existing,
		{"name": "One too many", "width": 1280, "height": 720, "zoom": 100}
	)
	_assert_equal(result["error"], "limit", "reports the template limit")
	_assert_equal(result["templates"].size(), SceneTemplate.MAX_TEMPLATES, "keeps the list unchanged")


func _test_filters_corrupted_saved_entries() -> void:
	var normalized := SceneTemplate.normalize_list([
		{"name": "Valid", "width": 1280, "height": 720, "zoom": 100},
		{"width": 1280, "height": 720, "zoom": 100},
		"not a dictionary",
	], Vector2i(960, 540))
	_assert_equal(normalized.size(), 1, "filters malformed entries")
	_assert_equal(normalized[0]["name"], "Valid", "keeps a valid entry")


func _test_deletes_only_the_selected_template() -> void:
	var templates := [
		{"name": "Gameplay", "width": 1280, "height": 720, "zoom": 100},
		{"name": "Chat", "width": 960, "height": 540, "zoom": 150},
	]
	var remaining := SceneTemplate.remove_at(templates, 0)
	_assert_equal(remaining.size(), 1, "removes one template")
	_assert_equal(remaining[0]["name"], "Chat", "keeps the other template")


func _test_finds_a_template_by_case_insensitive_name() -> void:
	var templates := [
		{"name": "Gravacao", "width": 1856, "height": 1184, "zoom": 80},
		{"name": "CorpoGravacao", "width": 1856, "height": 1184, "zoom": 40},
	]
	_assert_equal(
		SceneTemplate.find_by_name(templates, "corpogravacao")["zoom"],
		40,
		"finds the saved template requested by a batch child"
	)
	_assert_equal(
		SceneTemplate.find_by_name(templates, "missing"),
		{},
		"returns an empty dictionary for a missing template"
	)


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, expected, actual])
