class_name ItemScaffolder
extends RefCounted
## Creates everything a new pickupable item needs in one step: an
## ItemData .tres (plus a MeleeWeaponBehavior/RangedWeaponBehavior
## sub-resource .tres with sensible defaults, when the chosen kind needs
## one), and placeholder rows in translations/items.csv for the generated
## name/description keys. Used by the "Nuovo oggetto..." wizard — kept
## separate from it so the file-creation logic isn't tangled up with
## dialog-box UI code, same split as Dialogue Tools' DialogueScaffolder.

enum WeaponKind { NONE, MELEE, RANGED }

const ITEMS_DIR := "res://resources/items"
const BEHAVIORS_DIR := "res://resources/items/behaviors"
const ITEMS_CSV := "res://translations/items.csv"


## Returns {"ok": bool, "message": String, "item_path": String, "item": ItemData}.
static func create(slug: String, display_name: String, description: String,
		icon: Texture2D, weapon_kind: WeaponKind) -> Dictionary:
	var clean_slug := slugify(slug)
	if clean_slug.is_empty():
		return _fail("Nome oggetto non valido (usa lettere, numeri, underscore).")

	var item_path := "%s/%s.tres" % [ITEMS_DIR, clean_slug]
	if FileAccess.file_exists(item_path):
		return _fail("Esiste già un oggetto '%s.tres'." % clean_slug)

	var slug_upper := clean_slug.to_upper()
	var name_key := "ITEM_%s_NAME" % slug_upper
	var desc_key := "ITEM_%s_DESC" % slug_upper

	var item := ItemData.new()
	item.id = clean_slug
	item.display_name_key = name_key
	item.description_key = desc_key
	item.icon = icon

	if weapon_kind != WeaponKind.NONE:
		item.item_type = ItemData.ItemType.EQUIPPABLE
		item.stackable = false
		item.max_stack = 1

		var behavior_path := "%s/%s_behavior.tres" % [BEHAVIORS_DIR, clean_slug]
		_ensure_dir(BEHAVIORS_DIR)
		var behavior: EquippableBehavior
		if weapon_kind == WeaponKind.MELEE:
			var melee := MeleeWeaponBehavior.new()
			melee.damage = 15.0
			melee.range = 1.6
			melee.attack_cooldown = 0.4
			behavior = melee
		else:
			var ranged := RangedWeaponBehavior.new()
			ranged.damage = 25.0
			ranged.range = 30.0
			ranged.attack_cooldown = 0.35
			behavior = ranged
			# ammo_item is left unset — there's usually no ammo ItemData
			# yet the first time a firearm is created. Assign one via the
			# Inspector afterward (resources/items/behaviors/*.tres).

		var behavior_err := ResourceSaver.save(behavior, behavior_path)
		if behavior_err != OK:
			return _fail("Impossibile salvare '%s' (errore %d)." % [behavior_path, behavior_err])
		item.equip_behavior = load(behavior_path)

	_ensure_dir(ITEMS_DIR)
	var save_err := ResourceSaver.save(item, item_path)
	if save_err != OK:
		return _fail("Impossibile salvare '%s' (errore %d)." % [item_path, save_err])

	# Reload from disk so equip_behavior (and, from the caller, anything
	# assigning this to a WorldItem) references the saved file by path,
	# not the in-memory instance — same ext_resource pattern every other
	# hand-authored resource in this project uses.
	item = load(item_path)

	var final_name := display_name if not display_name.is_empty() else clean_slug.capitalize()
	var final_desc := description if not description.is_empty() else "TODO: descrizione di %s" % clean_slug
	ItemTranslationIO.set_row(name_key, final_name, final_name, ITEMS_CSV)
	ItemTranslationIO.set_row(desc_key, final_desc, final_desc, ITEMS_CSV)

	return {"ok": true, "message": "Oggetto '%s' creato." % clean_slug, "item_path": item_path, "item": item}


## Lowercase, [a-z0-9_] only, single underscores as separators, no
## leading/trailing underscore. Same rule as DialogueScaffolder.slugify.
static func slugify(text: String) -> String:
	var lowered := text.strip_edges().to_lower()
	var result := ""
	for c in lowered:
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			result += c
		elif (c == "_" or c == "-" or c == " ") and not result.ends_with("_"):
			result += "_"
	while result.ends_with("_"):
		result = result.substr(0, result.length() - 1)
	return result


static func _ensure_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_recursive_absolute(path)


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "message": message, "item_path": "", "item": null}
