class_name ItemTranslationIO
extends RefCounted
## Reads/writes single rows of a translations/*.csv by key — same
## get/set-a-row-in-place approach as Dialogue Tools' DialogueTranslationIO,
## kept as its own small copy here rather than a cross-plugin dependency,
## so Item Tools stays enable/disable-independent from Dialogue Tools.
## Rewrites the whole file on every write (these CSVs are tiny), preserving
## row order.

const ITEMS_CSV := "res://translations/items.csv"


## Returns {"en": String, "it": String} for `key`, or empty strings if the
## key isn't present yet.
static func get_row(key: String, path: String = ITEMS_CSV) -> Dictionary:
	for row in _read_rows(path):
		if row.size() > 0 and row[0] == key:
			return {"en": row[1] if row.size() > 1 else "", "it": row[2] if row.size() > 2 else ""}
	return {"en": "", "it": ""}


## Creates or updates the row for `key`. Appends a new row (after the
## header, creating one if the file is empty/missing) if it doesn't exist.
static func set_row(key: String, en: String, it: String, path: String = ITEMS_CSV) -> void:
	if key.is_empty():
		return

	var rows := _read_rows(path)
	var found := false
	for i in rows.size():
		if rows[i].size() > 0 and rows[i][0] == key:
			rows[i] = [key, en, it]
			found = true
			break

	if not found:
		if rows.is_empty():
			rows.append(["keys", "en", "it"])
		rows.append([key, en, it])

	_write_rows(path, rows)


static func _read_rows(path: String) -> Array:
	var rows: Array = []
	if not FileAccess.file_exists(path):
		return rows
	var file := FileAccess.open(path, FileAccess.READ)
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() == 0 or (row.size() == 1 and row[0].is_empty()):
			continue
		rows.append(row)
	file.close()
	return rows


static func _write_rows(path: String, rows: Array) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	for row in rows:
		file.store_csv_line(row)
	file.close()
