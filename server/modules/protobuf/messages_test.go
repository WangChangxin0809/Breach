package protobuf

import (
	"testing"

	"github.com/golang/protobuf/proto"
)

func TestMoveCommandRoundTrip(t *testing.T) {
	original := &MoveCommand{
		Version:    PROTOCOL_VERSION,
		ClientTick: 12,
		Position:   &Vector2{X: 128, Y: 256},
		Direction:  &Vector2{X: 1, Y: 0},
	}

	data, err := proto.Marshal(original)
	if err != nil {
		t.Fatalf("marshal move command: %v", err)
	}

	decoded := &MoveCommand{}
	if err := proto.Unmarshal(data, decoded); err != nil {
		t.Fatalf("unmarshal move command: %v", err)
	}

	if decoded.Version != original.Version || decoded.ClientTick != original.ClientTick {
		t.Fatalf("decoded scalar fields mismatch: %#v", decoded)
	}
	if decoded.Position == nil || decoded.Position.X != original.Position.X || decoded.Position.Y != original.Position.Y {
		t.Fatalf("decoded position mismatch: %#v", decoded.Position)
	}
	if decoded.Direction == nil || decoded.Direction.X != original.Direction.X || decoded.Direction.Y != original.Direction.Y {
		t.Fatalf("decoded direction mismatch: %#v", decoded.Direction)
	}
}

func TestCharacterSelectStateRoundTrip(t *testing.T) {
	original := &CharacterSelectState{
		Version:   PROTOCOL_VERSION,
		AllLocked: true,
		Players: []*CharacterSelectPlayer{
			{
				UserId:      "user-a",
				DisplayName: "A",
				CharacterId: "fura",
				Locked:      true,
			},
		},
	}

	data, err := proto.Marshal(original)
	if err != nil {
		t.Fatalf("marshal character select state: %v", err)
	}

	decoded := &CharacterSelectState{}
	if err := proto.Unmarshal(data, decoded); err != nil {
		t.Fatalf("unmarshal character select state: %v", err)
	}

	if !decoded.AllLocked || len(decoded.Players) != 1 {
		t.Fatalf("decoded selection state mismatch: %#v", decoded)
	}
	if decoded.Players[0].CharacterId != "fura" || !decoded.Players[0].Locked {
		t.Fatalf("decoded player selection mismatch: %#v", decoded.Players[0])
	}
}
