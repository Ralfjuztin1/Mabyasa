@tool
class_name ScatterInstances
extends ScatterValue

var transforms: Array[Transform3D] = []
var colors: Array[Color] = []
var custom_data: Array[Color] = []


func get_value_type_id() -> StringName:
	return ScatterValueTypeRegistry.INSTANCES


func duplicate_value() -> ScatterValue:
	return duplicate_instances()


func duplicate_instances() -> ScatterInstances:
	var copy := ScatterInstances.new()
	copy.transforms = transforms.duplicate()
	copy.colors = colors.duplicate()
	copy.custom_data = custom_data.duplicate()
	return copy


func add_instance(transform: Transform3D, color := Color.WHITE, data := Color(0, 0, 0, 0)) -> void:
	transforms.append(transform)
	colors.append(color)
	custom_data.append(data)


func append_instances(other: ScatterInstances, maximum := -1) -> void:
	if other == null:
		return
	other.normalize()
	var amount := other.transforms.size()
	if maximum >= 0:
		amount = mini(amount, maxi(0, maximum - transforms.size()))
	for index in amount:
		add_instance(other.transforms[index], other.colors[index], other.custom_data[index])


func normalize() -> void:
	if colors.size() > transforms.size():
		colors.resize(transforms.size())
	if custom_data.size() > transforms.size():
		custom_data.resize(transforms.size())
	while colors.size() < transforms.size():
		colors.append(Color.WHITE)
	while custom_data.size() < transforms.size():
		custom_data.append(Color(0, 0, 0, 0))


func limit(maximum: int) -> void:
	if transforms.size() > maximum:
		transforms.resize(maximum)
	normalize()


func remove_at(index: int) -> void:
	normalize()
	transforms.remove_at(index)
	colors.remove_at(index)
	custom_data.remove_at(index)


func is_empty() -> bool:
	return transforms.is_empty()
