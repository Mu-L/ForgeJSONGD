## Class -> JSON conversion. Internal, use ForgeJSONGD instead.
@abstract class_name ForgeJSONGDSerializer extends ForgeJSONGDBase


## Converts an object into a JSON dictionary. specify_class stores the script so the
## object can be rebuilt without a type hint (needed under inheritance).
static func class_to_json(_class: Object, specify_class: bool = false) -> Dictionary:
	var dictionary: Dictionary = {}
	if specify_class:
		dictionary.set(SCRIPT_INHERITANCE, _class.get_script().get_global_name())

	for property: Dictionary in _class.get_property_list():
		var property_name: String = property.get("name")
		if property_name == "script":
			if specify_class and dictionary.get(SCRIPT_INHERITANCE).is_empty():
				dictionary.set(SCRIPT_INHERITANCE, _class.get_script().resource_path) # In case the class isn't global
			continue
		if not property_name.is_empty() and _check_valid_property(property):
			_store_property(dictionary, property, _class.get(property_name))
	return dictionary


## Recursively converts an Array into a JSON-compatible Array.
static func convert_array_to_json(array: Array) -> Array:
	var json_array: Array = []
	for element: Variant in array:
		json_array.append(_serialize_variant(element, array.is_typed(), array.get_typed_script()))
	return json_array


## Recursively converts a Dictionary into a JSON-compatible Dictionary.
static func convert_dictionary_to_json(dictionary: Dictionary) -> Dictionary:
	var json_dictionary: Dictionary = {}
	for key: Variant in dictionary:
		var parsed_key: Variant = _serialize_variant(key, dictionary.is_typed(), dictionary.get_typed_key_script())
		var parsed_value: Variant = _serialize_variant(dictionary.get(key), dictionary.is_typed(), dictionary.get_typed_value_script())
		if typeof(parsed_value) == TYPE_INT: # JSON parsing in Godot always yields floats
			parsed_value = float(parsed_value)
		json_dictionary.set(parsed_key, parsed_value)
	return json_dictionary


#region Internals

## Serializes one property value into the dictionary, depending on its type.
static func _store_property(dictionary: Dictionary, property: Dictionary, value: Variant) -> void:
	var property_name: String = property.get("name")
	var property_type: Variant = property.get("type")

	if value is Array:
		dictionary.set(property_name, convert_array_to_json(value))
	elif value is Dictionary:
		dictionary.set(property_name, convert_dictionary_to_json(value))
	elif property_type == TYPE_OBJECT and value != null and value.get_property_list():
		dictionary.set(property_name, _serialize_object_property(property, value))
	elif _is_vector(value):
		dictionary.set(property_name, var_to_str(value))
	elif property_type == TYPE_COLOR:
		dictionary.set(property_name, value.to_html())
	elif property_type == TYPE_INT and property.get("hint") == PROPERTY_HINT_ENUM:
		var enum_name: Variant = _enum_to_string(value, property.get("hint_string"))
		if enum_name != null:
			dictionary.set(property_name, enum_name)
	else:
		dictionary.set(property_name, value)


## Serializes an Object property: external resources by path, everything else as a nested dictionary.
static func _serialize_object_property(property: Dictionary, value: Object) -> Variant:
	if value is Resource and ResourceLoader.exists(value.resource_path):
		# Resources stored in a file that isn't a .tres are referenced by path only.
		if _get_main_tres_path(value.resource_path).get_extension() != "tres":
			return value.resource_path
		return class_to_json(value)
	return class_to_json(value, property.get("class_name") != value.get_script().get_global_name())


## Returns the enum key matching the value from a property hint string ("A:0,B:1"), or null if none matches.
static func _enum_to_string(value: int, hint_string: String) -> Variant:
	var result: Variant = null
	for entry: String in hint_string.split(","):
		entry = entry.replace(" ", "_")
		if entry.contains(":"):
			var parts: PackedStringArray = entry.split(":")
			if value == parts[1].to_int():
				result = parts[0]
		else:
			result = entry
	return result


## Converts a single Variant into a JSON-compatible Variant.
## typed_script is the script the parent container is typed with (null if untyped or a built-in type).
static func _serialize_variant(variant_value: Variant, is_parent_typed: bool = false, typed_script: Script = null) -> Variant:
	if variant_value is Object:
		# The script is only needed when the container doesn't already tell the class:
		# untyped containers, or elements that are a subclass of the container's type.
		var specify_script: bool = not is_parent_typed or (typed_script != null and variant_value.get_script() != typed_script)
		return class_to_json(variant_value, specify_script)
	if variant_value is Array:
		return convert_array_to_json(variant_value)
	if variant_value is Dictionary:
		return convert_dictionary_to_json(variant_value)
	if _is_vector(variant_value):
		return var_to_str(variant_value)
	if variant_value is int and not is_parent_typed:
		# JSON.parse_string yields floats only, so ints are cast to keep types consistent.
		return float(variant_value)
	if typeof(variant_value) == TYPE_COLOR:
		return variant_value.to_html()
	return variant_value

#endregion
