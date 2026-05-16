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
	if len(cfg.Map.Obstacles) == 0 {
		t.Fatalf("expected embedded map to include exported semantic obstacles")
	}
	if !hasObstacleWithFlags(cfg, "ArtWorld/LowCoverCrate/CollisionShape2D", true, false) {
		t.Fatalf("expected low cover to block movement without blocking vision")
	}
	if !hasObstacleWithFlags(cfg, "ArtWorld/VisionBlockerHighCrate/CollisionShape2D", true, true) {
		t.Fatalf("expected high crate to block movement and vision")
	}
	if len(cfg.Map.SpawnPoints["attackers"]) != 3 || len(cfg.Map.SpawnPoints["defenders"]) != 3 {
		t.Fatalf("expected exported spawn points for both factions, got %#v", cfg.Map.SpawnPoints)
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

func hasObstacleWithFlags(cfg *GameConfig, sourcePath string, blocksMovement bool, blocksVision bool) bool {
	for _, obstacle := range cfg.Map.Obstacles {
		if obstacle.SourcePath == sourcePath &&
			obstacle.BlocksMovement == blocksMovement &&
			obstacle.BlocksVision == blocksVision {
			return true
		}
	}
	return false
}
