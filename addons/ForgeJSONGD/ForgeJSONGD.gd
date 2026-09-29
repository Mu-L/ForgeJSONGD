## Public API of the ForgeJSONGD addon. Every method here is static and a thin wrapper:
## the actual work lives in ForgeJSONGDSerializer, ForgeJSONGDDeserializer and ForgeJSONGDHelper.
##
## Settings (inherited from ForgeJSONGDBase):
##   ForgeJSONGD.only_exported_values - serialize only @export variables when true.
## Types:
##   ForgeJSONGD.Operation - operations accepted by json_operation().
@abstract class_name ForgeJSONGD extends ForgeJSONGDBase


#region Class to JSON

## Converts a class instance into a JSON dictionary.
## Set specify_class to true when the instance is a subclass (stores its script for loading later).
static func class_to_json(_class: Object, specify_class: bool = false) -> Dictionary:
	return ForgeJSONGDSerializer.class_to_json(_class, specify_class)


## Converts a class instance into a JSON string.
static func class_to_json_string(_class: Object, specify_class: bool = false) -> String:
	return JSON.stringify(class_to_json(_class, specify_class))


## Stores a JSON dictionary to a file, encrypted when a security_key is given. Returns false on failure.
static func store_json_file(file_path: String, data: Dictionary, security_key: String = "") -> bool:
	return _write_json_file(file_path, data, security_key)

#endregion


#region JSON to Class

## Converts a JSON dictionary into an instance of the given script (or fills the given instance).
## Pass null as the script to use the script stored in the JSON.
static func json_to_class(gdscript_or_instance: Variant, json: Dictionary) -> Object:
	return ForgeJSONGDDeserializer.json_to_class(gdscript_or_instance, json)


## Converts a JSON string into a class instance. Returns null if the string is not valid JSON.
static func json_string_to_class(gdscript_or_instance: Variant, json_string: String) -> Object:
	var json: JSON = JSON.new()
	if json.parse(json_string) == OK:
		return json_to_class(gdscript_or_instance, json.data)
	return null


## Loads a JSON file into a class instance. If the file is missing or empty and a Script was given,
## returns a fresh instance of it.
static func json_file_to_class(gdscript_or_instance: Variant, file_path: String, security_key: String = "") -> Object:
	var parsed_results: Dictionary = json_file_to_dict(file_path, security_key)
	if parsed_results.is_empty() and gdscript_or_instance is Script:
		return gdscript_or_instance.new()
	return json_to_class(gdscript_or_instance, parsed_results)


## Loads a JSON file into a Dictionary, decrypting when a security_key is given. Returns {} on failure.
static func json_file_to_dict(file_path: String, security_key: String = "") -> Dictionary:
	return _read_json_file(file_path, security_key)

#endregion


#region JSON utilities
## The json arguments below accept a Dictionary, a JSON string, a JSON file path or an Object.

## Returns true if both JSONs are equal.
static func check_equal_jsons(first_json: Variant, second_json: Variant) -> bool:
	return _jsons_equal(_get_dict_from_type(first_json), _get_dict_from_type(second_json))


## Returns the differences as {key: {"old": ..., "new": ...}}, or {} if they are equal.
static func compare_jsons_diff(first_json: Variant, second_json: Variant) -> Dictionary:
	var first_dict: Dictionary = _get_dict_from_type(first_json)
	var second_dict: Dictionary = _get_dict_from_type(second_json)
	if _jsons_equal(first_dict, second_dict):
		return {}
	return ForgeJSONGDHelper.compare_recursive(first_dict, second_dict)


## Applies an Operation to base_json using ref_json as the reference and returns the result.
## The inputs are not modified.
static func json_operation(base_json: Variant, ref_json: Variant, operation_type: Operation) -> Dictionary:
	var base_dict: Dictionary = _get_dict_from_type(base_json).duplicate(true)
	var ref_dict: Dictionary = _get_dict_from_type(ref_json)

	# Identical inputs short-circuit.
	if _jsons_equal(base_dict, ref_dict):
		if operation_type == Operation.Replace:
			return base_dict
		if operation_type == Operation.Remove or operation_type == Operation.RemoveValue:
			return {}
	return ForgeJSONGDHelper.apply_operation_recursively(base_dict, ref_dict, operation_type)

#endregion


#region Advanced

## Recursively converts an Array into a JSON-compatible Array.
static func convert_array_to_json(array: Array) -> Array:
	return ForgeJSONGDSerializer.convert_array_to_json(array)


## Recursively converts a Dictionary into a JSON-compatible Dictionary.
static func convert_dictionary_to_json(dictionary: Dictionary) -> Dictionary:
	return ForgeJSONGDSerializer.convert_dictionary_to_json(dictionary)

#endregion
