class_name GameData
extends RefCounted


static func load_table(path: String, id_field: String) -> Dictionary:
	var records := {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unable to open game table: %s" % path)
		return records

	var headers := file.get_csv_line()
	var types := file.get_csv_line()
	file.get_csv_line()

	while file.get_position() < file.get_length():
		var values := file.get_csv_line()
		if values.is_empty() or (values.size() == 1 and values[0].is_empty()):
			continue

		var record := {}
		for index in min(headers.size(), values.size()):
			var type_name := "string"
			if index < types.size():
				type_name = types[index]
			record[headers[index]] = _convert_value(values[index], type_name)

		if record.has(id_field) and record[id_field] != null:
			records[int(record[id_field])] = record

	return records


static func load_cards() -> Dictionary:
	return load_table("res://data/generated/tables/cards.csv", "card_id")


static func load_qualities() -> Dictionary:
	return load_table(
		"res://data/generated/tables/card_equality.csv",
		"equality_id"
	)


static func load_decks() -> Dictionary:
	return load_table("res://data/generated/tables/decks.csv", "deck_id")


static func load_actors() -> Dictionary:
	return load_table(
		"res://data/generated/tables/player_npc.csv",
		"actor_id"
	)


static func load_enemies() -> Dictionary:
	return load_table(
		"res://data/generated/tables/enemies.csv",
		"enemy_id"
	)


static func _convert_value(raw_value: String, type_name: String) -> Variant:
	if raw_value.is_empty():
		return null

	match type_name:
		"int":
			return int(raw_value)
		"float":
			return float(raw_value)
		"int[]":
			var result: Array[int] = []
			for item in raw_value.split(";", false):
				result.append(int(item.strip_edges()))
			return result
		_:
			return raw_value.replace("\\n", "\n")
