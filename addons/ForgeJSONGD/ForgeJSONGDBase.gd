## Shared constants and utilities used by every ForgeJSONGD class. Internal, use ForgeJSONGD instead.
@abstract class_name ForgeJSONGDBase

## Key written into a JSON dictionary to record which script an object was created from.
const SCRIPT_INHERITANCE = "script_inheritance"

## String prefixes (before the opening bracket) of types that str_to_var may safely parse.
const _SAFE_PREFIXES: Array[String] = [
	"Vector2", "Vector2i", "Vector3", "Vector3i", "Vector4", "Vector4i",
	"Rect2", "Rect2i", "Plane", "Quaternion", "AABB", "Basis",
	"Transform2D", "Transform3D", "Projection", "Color"
]

## Defines the types of operations that can be performed on the data structures.
enum Operation {
	Add, # Adds values. If key exists, combines them into an array.
	AddDiffer, # Adds or merges values only if they are different.
	Replace, # Replaces values in the base structure with values from the reference.
	Remove, # Removes keys/values present in the reference structure from the base.
	RemoveValue # Removes keys/values only if their values match the reference.
}

## If true only exported values will be serialized or deserialized.
static var only_exported_values: bool = false


#region Files

## Creates the directory of the given file path if it doesn't exist.
static func _check_dir(file_path: String) -> void:
	if not DirAccess.dir_exists_absolute(file_path.get_base_dir()):
		DirAccess.make_dir_recursive_absolute(file_path.get_base_dir())


## Opens a file for reading or writing, encrypted when a security key is given. Returns null on failure.
static func _open_file(file_path: String, mode: FileAccess.ModeFlags, security_key: String = "") -> FileAccess:
	if security_key.is_empty():
		return FileAccess.open(file_path, mode)
	return FileAccess.open_encrypted_with_pass(file_path, mode, security_key)


## Writes a dictionary as tab-indented JSON to a file. Returns false on failure.
static func _write_json_file(file_path: String, data: Dictionary, security_key: String = "") -> bool:
	_check_dir(file_path)
	var file: FileAccess = _open_file(file_path, FileAccess.WRITE, security_key)
	if not file:
		printerr("Error writing to a file")
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


## Reads a JSON file into a Dictionary (or Array). Returns an empty Dictionary on any failure.
static func _read_json_file(file_path: String, security_key: String = "") -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	var file: FileAccess = _open_file(file_path, FileAccess.READ, security_key)
	if not file:
		printerr("Error opening file: ", file_path)
		return {}
	var parsed_results: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed_results is Dictionary or parsed_results is Array:
		return parsed_results
	return {}

#endregion


#region Checks and Gets

## Checks if a property should be included during serialization or deserialization.
static func _check_valid_property(property: Dictionary) -> bool:
	return property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and (not only_exported_values or property.usage & PROPERTY_USAGE_STORAGE)


## Returns true if the value's type is one of the Vector types.
static func _is_vector(value: Variant) -> bool:
	return type_string(typeof(value)).begins_with("Vector")


## Finds a Script by its global class name or resource path.
static func _get_gdscript(hint_class: String) -> Script:
	for class_info: Dictionary in ProjectSettings.get_global_class_list():
		if class_info.class == hint_class:
			return load(class_info.path)
	if ResourceLoader.exists(hint_class):
		return load(hint_class)
	return null


## Extracts the main path from a resource path (removes the sub-resource part if present).
static func _get_main_tres_path(path: String) -> String:
	return path.split("::", true, 1)[0]


## Gets a dictionary from an object, a dictionary, a JSON string or a JSON file path.
static func _get_dict_from_type(json: Variant) -> Dictionary:
	if json is Dictionary:
		return json
	if json is Object:
		return ForgeJSONGDSerializer.class_to_json(json)
	var parser: JSON = JSON.new()
	if parser.parse(json) == OK and parser.data is Dictionary:
		return parser.data
	# Not a JSON string, so treat it as a file path.
	return _read_json_file(json)


## Converts data to what it would be after being saved and loaded again: numbers become floats,
## keys are sorted and text-like values become strings. Makes data from files and classes comparable.
static func _normalize_json(data: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(data))


## Checks if two dictionaries hold the same JSON data, ignoring key order and int/float differences.
static func _jsons_equal(first: Dictionary, second: Dictionary) -> bool:
	return _normalize_json(first) == _normalize_json(second)


## Checks if a string is safe to be processed by str_to_var.
static func _is_safe_type(p_str: String) -> bool:
	if p_str.is_empty():
		return false

	var is_safe := false
	for prefix: String in _SAFE_PREFIXES:
		if p_str.begins_with(prefix + "(") and p_str.ends_with(")"):
			is_safe = true
			break
	# Also allow NodePath and StringName literals
	if not is_safe:
		is_safe = (p_str.begins_with("@\"") or p_str.begins_with("&\"")) and p_str.ends_with("\"")

	# Even a safe-looking string must not contain dangerous instantiations
	return is_safe and not ("Object(" in p_str or "Callable(" in p_str or "Signal(" in p_str)

#endregion
