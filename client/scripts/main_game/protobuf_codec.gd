extends RefCounted
class_name ProtobufCodec

const WIRE_VARINT := 0
const WIRE_FIXED32 := 5
const WIRE_LENGTH := 2

static func encode_move_command(client_tick: int, position: Vector2, direction: Vector2) -> PackedByteArray:
	var out := PackedByteArray()
	_write_varint_field(out, 1, Config.PROTOCOL_VERSION)
	_write_varint_field(out, 2, client_tick)
	_write_message_field(out, 3, encode_vector2(position))
	_write_message_field(out, 4, encode_vector2(direction))
	return out

static func encode_character_select(character_id: String) -> PackedByteArray:
	var out := PackedByteArray()
	_write_varint_field(out, 1, Config.PROTOCOL_VERSION)
	_write_string_field(out, 2, character_id)
	return out

static func encode_vector2(value: Vector2) -> PackedByteArray:
	var out := PackedByteArray()
	_write_fixed32_field(out, 1, value.x)
	_write_fixed32_field(out, 2, value.y)
	return out

static func decode_game_state(bytes: PackedByteArray) -> Dictionary:
	var cursor := [0]
	var result := {
		"version": 0,
		"tick": 0,
		"round_state": Config.ROUND_WAITING,
		"round_time_remaining": 0.0,
		"players": [],
	}
	while cursor[0] < bytes.size():
		var tag := _read_varint(bytes, cursor)
		var field := tag >> 3
		var wire := tag & 7
		match field:
			1:
				result["version"] = _read_varint(bytes, cursor)
			2:
				result["tick"] = _read_varint(bytes, cursor)
			3:
				result["round_state"] = _read_varint(bytes, cursor)
			4:
				result["round_time_remaining"] = _read_fixed32_float(bytes, cursor)
			5:
				result["players"].append(decode_player_state(_read_length_delimited(bytes, cursor)))
			_:
				_skip_field(bytes, cursor, wire)
	return result

static func decode_character_select_state(bytes: PackedByteArray) -> Dictionary:
	var cursor := [0]
	var result := {
		"version": 0,
		"all_locked": false,
		"players": [],
	}
	while cursor[0] < bytes.size():
		var tag := _read_varint(bytes, cursor)
		var field := tag >> 3
		var wire := tag & 7
		match field:
			1:
				result["version"] = _read_varint(bytes, cursor)
			2:
				result["all_locked"] = _read_varint(bytes, cursor) != 0
			3:
				result["players"].append(decode_character_select_player(_read_length_delimited(bytes, cursor)))
			_:
				_skip_field(bytes, cursor, wire)
	return result

static func decode_character_select_player(bytes: PackedByteArray) -> Dictionary:
	var cursor := [0]
	var result := {
		"user_id": "",
		"display_name": "",
		"character_id": "",
		"locked": false,
	}
	while cursor[0] < bytes.size():
		var tag := _read_varint(bytes, cursor)
		var field := tag >> 3
		var wire := tag & 7
		match field:
			1:
				result["user_id"] = _read_length_delimited(bytes, cursor).get_string_from_utf8()
			2:
				result["display_name"] = _read_length_delimited(bytes, cursor).get_string_from_utf8()
			3:
				result["character_id"] = _read_length_delimited(bytes, cursor).get_string_from_utf8()
			4:
				result["locked"] = _read_varint(bytes, cursor) != 0
			_:
				_skip_field(bytes, cursor, wire)
	return result

static func decode_player_state(bytes: PackedByteArray) -> Dictionary:
	var cursor := [0]
	var result := {
		"user_id": "",
		"display_name": "",
		"faction": 0,
		"position": Vector2.ZERO,
		"health": 0,
		"connected": false,
	}
	while cursor[0] < bytes.size():
		var tag := _read_varint(bytes, cursor)
		var field := tag >> 3
		var wire := tag & 7
		match field:
			1:
				result["user_id"] = _read_length_delimited(bytes, cursor).get_string_from_utf8()
			2:
				result["display_name"] = _read_length_delimited(bytes, cursor).get_string_from_utf8()
			3:
				result["faction"] = _read_varint(bytes, cursor)
			4:
				result["position"] = decode_vector2(_read_length_delimited(bytes, cursor))
			5:
				result["health"] = _read_varint(bytes, cursor)
			6:
				result["connected"] = _read_varint(bytes, cursor) != 0
			_:
				_skip_field(bytes, cursor, wire)
	return result

static func decode_vector2(bytes: PackedByteArray) -> Vector2:
	var cursor := [0]
	var value := Vector2.ZERO
	while cursor[0] < bytes.size():
		var tag := _read_varint(bytes, cursor)
		var field := tag >> 3
		var wire := tag & 7
		match field:
			1:
				value.x = _read_fixed32_float(bytes, cursor)
			2:
				value.y = _read_fixed32_float(bytes, cursor)
			_:
				_skip_field(bytes, cursor, wire)
	return value

static func _write_varint_field(out: PackedByteArray, field: int, value: int) -> void:
	_write_varint(out, (field << 3) | WIRE_VARINT)
	_write_varint(out, value)

static func _write_fixed32_field(out: PackedByteArray, field: int, value: float) -> void:
	_write_varint(out, (field << 3) | WIRE_FIXED32)
	var encoded := PackedFloat32Array([value]).to_byte_array()
	for byte in encoded:
		out.append(byte)

static func _write_message_field(out: PackedByteArray, field: int, value: PackedByteArray) -> void:
	_write_varint(out, (field << 3) | WIRE_LENGTH)
	_write_varint(out, value.size())
	out.append_array(value)

static func _write_string_field(out: PackedByteArray, field: int, value: String) -> void:
	_write_varint(out, (field << 3) | WIRE_LENGTH)
	var bytes := value.to_utf8_buffer()
	_write_varint(out, bytes.size())
	out.append_array(bytes)

static func _write_varint(out: PackedByteArray, value: int) -> void:
	var current := value
	while current >= 128:
		out.append((current & 127) | 128)
		current = current >> 7
	out.append(current)

static func _read_varint(bytes: PackedByteArray, cursor: Array) -> int:
	var shift := 0
	var result := 0
	while cursor[0] < bytes.size():
		var byte := bytes[cursor[0]]
		cursor[0] += 1
		result |= (byte & 127) << shift
		if (byte & 128) == 0:
			return result
		shift += 7
	return result

static func _read_fixed32_float(bytes: PackedByteArray, cursor: Array) -> float:
	var slice := bytes.slice(cursor[0], cursor[0] + 4)
	cursor[0] += 4
	return slice.to_float32_array()[0]

static func _read_length_delimited(bytes: PackedByteArray, cursor: Array) -> PackedByteArray:
	var length := _read_varint(bytes, cursor)
	var start: int = cursor[0]
	cursor[0] += length
	return bytes.slice(start, start + length)

static func _skip_field(bytes: PackedByteArray, cursor: Array, wire: int) -> void:
	match wire:
		WIRE_VARINT:
			_read_varint(bytes, cursor)
		WIRE_FIXED32:
			cursor[0] += 4
		WIRE_LENGTH:
			var length := _read_varint(bytes, cursor)
			cursor[0] += length
		_:
			cursor[0] = bytes.size()
