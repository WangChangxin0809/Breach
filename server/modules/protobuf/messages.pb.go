package protobuf

import "github.com/golang/protobuf/proto"

const PROTOCOL_VERSION uint32 = 1

type Vector2 struct {
	X float32 `protobuf:"fixed32,1,opt,name=x,proto3" json:"x,omitempty"`
	Y float32 `protobuf:"fixed32,2,opt,name=y,proto3" json:"y,omitempty"`
}

func (m *Vector2) Reset()         { *m = Vector2{} }
func (m *Vector2) String() string { return proto.CompactTextString(m) }
func (*Vector2) ProtoMessage()    {}

type MoveCommand struct {
	Version    uint32   `protobuf:"varint,1,opt,name=version,proto3" json:"version,omitempty"`
	ClientTick uint64   `protobuf:"varint,2,opt,name=client_tick,json=clientTick,proto3" json:"client_tick,omitempty"`
	Position   *Vector2 `protobuf:"bytes,3,opt,name=position,proto3" json:"position,omitempty"`
	Direction  *Vector2 `protobuf:"bytes,4,opt,name=direction,proto3" json:"direction,omitempty"`
}

func (m *MoveCommand) Reset()         { *m = MoveCommand{} }
func (m *MoveCommand) String() string { return proto.CompactTextString(m) }
func (*MoveCommand) ProtoMessage()    {}

type PlayerState struct {
	UserId      string   `protobuf:"bytes,1,opt,name=user_id,json=userId,proto3" json:"user_id,omitempty"`
	DisplayName string   `protobuf:"bytes,2,opt,name=display_name,json=displayName,proto3" json:"display_name,omitempty"`
	Faction     int32    `protobuf:"varint,3,opt,name=faction,proto3" json:"faction,omitempty"`
	Position    *Vector2 `protobuf:"bytes,4,opt,name=position,proto3" json:"position,omitempty"`
	Health      int32    `protobuf:"varint,5,opt,name=health,proto3" json:"health,omitempty"`
	Connected   bool     `protobuf:"varint,6,opt,name=connected,proto3" json:"connected,omitempty"`
}

func (m *PlayerState) Reset()         { *m = PlayerState{} }
func (m *PlayerState) String() string { return proto.CompactTextString(m) }
func (*PlayerState) ProtoMessage()    {}

type GameState struct {
	Version            uint32         `protobuf:"varint,1,opt,name=version,proto3" json:"version,omitempty"`
	Tick               uint64         `protobuf:"varint,2,opt,name=tick,proto3" json:"tick,omitempty"`
	RoundState         int32          `protobuf:"varint,3,opt,name=round_state,json=roundState,proto3" json:"round_state,omitempty"`
	RoundTimeRemaining float32        `protobuf:"fixed32,4,opt,name=round_time_remaining,json=roundTimeRemaining,proto3" json:"round_time_remaining,omitempty"`
	Players            []*PlayerState `protobuf:"bytes,5,rep,name=players,proto3" json:"players,omitempty"`
}

func (m *GameState) Reset()         { *m = GameState{} }
func (m *GameState) String() string { return proto.CompactTextString(m) }
func (*GameState) ProtoMessage()    {}
