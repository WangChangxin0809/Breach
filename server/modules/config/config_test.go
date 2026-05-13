package config

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestLoadEmbeddedConfig(t *testing.T) {
	cfg, err := LoadEmbedded()
	if err != nil {
		t.Fatalf("expected embedded config to load, got err %v", err)
	}

	if cfg.Version != 1 {
		t.Fatalf("expected config version 1, got %d", cfg.Version)
	}
	if cfg.Match.TickRate != 20 {
		t.Fatalf("expected tick rate 20, got %d", cfg.Match.TickRate)
	}
	if cfg.DefaultCharacter().BaseHealth != 100 {
		t.Fatalf("expected default character health 100, got %d", cfg.DefaultCharacter().BaseHealth)
	}
	if _, exists := cfg.Weapons["default_sidearm"]; !exists {
		t.Fatalf("expected default_sidearm weapon to exist")
	}
}

func TestLoadFromDirRejectsInvalidConfig(t *testing.T) {
	dir := t.TempDir()

	writeJSON(t, dir, "match.json", matchFile{
		Version: 1,
		Match: MatchConfig{
			TickRate:            0,
			MaxPlayers:          6,
			MinPlayers:          2,
			RoundDurationSec:    120,
			RoundEndDelaySec:    4,
			RoundsPerHalf:       6,
			PointsPerPlayerKill: 100,
			PointsPerZombieKill: 25,
		},
		Map: MapConfig{Width: 1600, Height: 960},
	})
	writeJSON(t, dir, "characters.json", charactersFile{
		DefaultCharacterID: "recruit",
		Characters: []CharacterConfig{
			{
				ID:               "recruit",
				BaseHealth:       100,
				MaxSpeed:         220,
				RespawnDelaySec:  5,
				CollisionRadius:  16,
				VisionRadius:     180,
				VisionConeLength: 420,
			},
		},
	})
	writeJSON(t, dir, "weapons.json", weaponsFile{
		Weapons: []WeaponConfig{
			{
				ID:           "default_sidearm",
				Slot:         "sidearm",
				Damage:       20,
				FireRate:     4,
				Range:        520,
				AmmoCapacity: 12,
			},
		},
	})

	if _, err := LoadFromDir(dir); err == nil {
		t.Fatalf("expected invalid tick rate to be rejected")
	}
}

func writeJSON(t *testing.T, dir string, name string, value interface{}) {
	t.Helper()

	data, err := json.Marshal(value)
	if err != nil {
		t.Fatalf("marshal %s: %v", name, err)
	}
	if err := os.WriteFile(filepath.Join(dir, name), data, 0o644); err != nil {
		t.Fatalf("write %s: %v", name, err)
	}
}
