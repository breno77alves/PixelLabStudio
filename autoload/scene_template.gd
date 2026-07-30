class_name SceneTemplate
extends RefCounted

const MAX_TEMPLATES := 20
const MAX_NAME_LENGTH := 40
const DEFAULT_MIN_SIZE := Vector2i(960, 540)
const MAX_SIZE := Vector2i(7680, 4320)
const MIN_ZOOM := 10
const MAX_ZOOM := 400


static func normalize(entry: Variant, minimum_size: Vector2i = DEFAULT_MIN_SIZE) -> Dictionary:
	if not entry is Dictionary:
		return {}

	var name := str(entry.get("name", "")).strip_edges()
	if name.is_empty():
		return {}
	name = name.substr(0, MAX_NAME_LENGTH)

	var safe_minimum := Vector2i(
		clampi(minimum_size.x, 1, MAX_SIZE.x),
		clampi(minimum_size.y, 1, MAX_SIZE.y)
	)
	return {
		"name": name,
		"width": clampi(_as_int(entry.get("width", 1280), 1280), safe_minimum.x, MAX_SIZE.x),
		"height": clampi(_as_int(entry.get("height", 720), 720), safe_minimum.y, MAX_SIZE.y),
		"zoom": clampi(_as_int(entry.get("zoom", 100), 100), MIN_ZOOM, MAX_ZOOM),
	}


static func normalize_list(entries: Variant, minimum_size: Vector2i = DEFAULT_MIN_SIZE) -> Array:
	var normalized: Array = []
	if not entries is Array:
		return normalized

	for raw_entry in entries:
		var entry := normalize(raw_entry, minimum_size)
		if entry.is_empty():
			continue
		var existing_index := _find_name(normalized, entry["name"])
		if existing_index >= 0:
			normalized[existing_index] = entry
		elif normalized.size() < MAX_TEMPLATES:
			normalized.append(entry)
	return normalized


static func upsert(
	entries: Variant,
	entry: Dictionary,
	minimum_size: Vector2i = DEFAULT_MIN_SIZE
) -> Dictionary:
	var normalized_entries := normalize_list(entries, minimum_size)
	var normalized_entry := normalize(entry, minimum_size)
	if normalized_entry.is_empty():
		return {"templates": normalized_entries, "index": -1, "error": "invalid"}

	var existing_index := _find_name(normalized_entries, normalized_entry["name"])
	if existing_index >= 0:
		normalized_entries[existing_index] = normalized_entry
		return {"templates": normalized_entries, "index": existing_index, "error": ""}
	if normalized_entries.size() >= MAX_TEMPLATES:
		return {"templates": normalized_entries, "index": -1, "error": "limit"}

	normalized_entries.append(normalized_entry)
	return {"templates": normalized_entries, "index": normalized_entries.size() - 1, "error": ""}


static func remove_at(
	entries: Variant,
	index: int,
	minimum_size: Vector2i = DEFAULT_MIN_SIZE
) -> Array:
	var normalized_entries := normalize_list(entries, minimum_size)
	if index >= 0 and index < normalized_entries.size():
		normalized_entries.remove_at(index)
	return normalized_entries


static func window_size(entry: Dictionary) -> Vector2i:
	return Vector2i(int(entry.get("width", 1280)), int(entry.get("height", 720)))


static func find_by_name(
	entries: Variant,
	name: String,
	minimum_size: Vector2i = DEFAULT_MIN_SIZE
) -> Dictionary:
	var normalized_entries := normalize_list(entries, minimum_size)
	var index := _find_name(normalized_entries, name.strip_edges())
	if index < 0:
		return {}
	return normalized_entries[index]


static func _find_name(entries: Array, name: String) -> int:
	var folded_name := name.to_lower()
	for index in range(entries.size()):
		if str(entries[index].get("name", "")).to_lower() == folded_name:
			return index
	return -1


static func _as_int(value: Variant, fallback: int) -> int:
	if value is int or value is float:
		return int(value)
	if value is String and value.is_valid_int():
		return value.to_int()
	return fallback
