package config

import (
	"embed"
	"encoding/json"
	"fmt"
	"math"
	"os"
	"path/filepath"
)

const (
	MATCH_MODULE_NAME = "breach_match"

	configDirEnv = "BREACH_CONFIG_DIR"

	DefaultVisionConeHalfAngleRad = math.Pi / 6
)

//go:embed data/*.json data/maps/*.json
var embeddedData embed.FS

var activeConfig *GameConfig

func init() {
	cfg, err := LoadFromEnvironment()
	if err != nil {
		panic(fmt.Sprintf("load game config: %v", err))
	}
	activeConfig = cfg
}

type GameConfig struct {
	Version            int
	Match              MatchConfig
	Map                MapConfig
	DefaultCharacterID string
	Characters         map[string]CharacterConfig
	Weapons            map[string]WeaponConfig
}

type MatchConfig struct {
	TickRate            int `json:"tick_rate"`
	MaxPlayers          int `json:"max_players"`
	MinPlayers          int `json:"min_players"`
	RoundDurationSec    int `json:"round_duration_sec"`
	RoundEndDelaySec    int `json:"round_end_delay_sec"`
	RoundsPerHalf       int `json:"rounds_per_half"`
	PointsPerPlayerKill int `json:"points_per_player_kill"`
	PointsPerZombieKill int `json:"points_per_zombie_kill"`
}

type MapConfig struct {
	Width           float64               `json:"width"`
	Height          float64               `json:"height"`
	Obstacles       []CollisionShape      `json:"obstacles,omitempty"`
	SolidObstacles  []Rect                `json:"solid_obstacles,omitempty"`
	CollisionShapes []CollisionShape      `json:"collision_shapes,omitempty"`
	SpawnPoints     map[string][]MapPoint `json:"spawn_points,omitempty"`
}

type Rect struct {
	X float64 `json:"x"`
	Y float64 `json:"y"`
	W float64 `json:"w"`
	H float64 `json:"h"`
}

type MapPoint struct {
	X float64 `json:"x"`
	Y float64 `json:"y"`
}

type CollisionShape struct {
	ID             string     `json:"id,omitempty"`
	Name           string     `json:"name,omitempty"`
	SourcePath     string     `json:"source_path,omitempty"`
	Type           string     `json:"type"`
	X              float64    `json:"x,omitempty"`
	Y              float64    `json:"y,omitempty"`
	W              float64    `json:"w,omitempty"`
	H              float64    `json:"h,omitempty"`
	Radius         float64    `json:"radius,omitempty"`
	A              *MapPoint  `json:"a,omitempty"`
	B              *MapPoint  `json:"b,omitempty"`
	Points         []MapPoint `json:"points,omitempty"`
	BlocksMovement bool       `json:"blocks_movement,omitempty"`
	BlocksVision   bool       `json:"blocks_vision,omitempty"`
}

type CharacterConfig struct {
	ID                     string  `json:"id"`
	BaseHealth             int     `json:"base_health"`
	MaxSpeed               float64 `json:"max_speed"`
	RespawnDelaySec        int     `json:"respawn_delay_sec"`
	CollisionRadius        float64 `json:"collision_radius"`
	VisionRadius           float64 `json:"vision_radius"`
	VisionConeLength       float64 `json:"vision_cone_length"`
	VisionConeHalfAngleRad float64 `json:"vision_cone_half_angle_rad,omitempty"`
}

type WeaponConfig struct {
	ID           string  `json:"id"`
	Slot         string  `json:"slot"`
	Damage       int     `json:"damage"`
	FireRate     float64 `json:"fire_rate"`
	Range        float64 `json:"range"`
	AmmoCapacity int     `json:"ammo_capacity"`
	UnlockCost   int     `json:"unlock_cost"`
}

type matchFile struct {
	Version int         `json:"version"`
	Match   MatchConfig `json:"match"`
	Map     MapConfig   `json:"map"`
	MapFile string      `json:"map_file"`
}

type charactersFile struct {
	DefaultCharacterID string            `json:"default_character_id"`
	Characters         []CharacterConfig `json:"characters"`
}

type exportedMapFile struct {
	Version     int       `json:"version"`
	SourceScene string    `json:"source_scene"`
	Map         MapConfig `json:"map"`
}

type weaponsFile struct {
	Weapons []WeaponConfig `json:"weapons"`
}

func Active() *GameConfig {
	return activeConfig
}

func LoadFromEnvironment() (*GameConfig, error) {
	if dir := os.Getenv(configDirEnv); dir != "" {
		return LoadFromDir(dir)
	}
	return LoadEmbedded()
}

func LoadEmbedded() (*GameConfig, error) {
	return load(func(name string, out interface{}) error {
		data, err := embeddedData.ReadFile(filepath.ToSlash(filepath.Join("data", name)))
		if err != nil {
			return err
		}
		return json.Unmarshal(data, out)
	})
}

func LoadFromDir(dir string) (*GameConfig, error) {
	return load(func(name string, out interface{}) error {
		data, err := os.ReadFile(filepath.Join(dir, name))
		if err != nil {
			return err
		}
		return json.Unmarshal(data, out)
	})
}

func (c *GameConfig) DefaultCharacter() CharacterConfig {
	return c.Characters[c.DefaultCharacterID]
}

func (c *GameConfig) Character(id string) CharacterConfig {
	if character, exists := c.Characters[id]; exists {
		return character
	}
	return c.DefaultCharacter()
}

func load(readJSON func(string, interface{}) error) (*GameConfig, error) {
	var match matchFile
	if err := readJSON("match.json", &match); err != nil {
		return nil, fmt.Errorf("read match.json: %w", err)
	}
	if match.MapFile != "" {
		var mapFile exportedMapFile
		if err := readJSON(match.MapFile, &mapFile); err != nil {
			return nil, fmt.Errorf("read %s: %w", match.MapFile, err)
		}
		match.Map = mapFile.Map
	}

	var characters charactersFile
	if err := readJSON("characters.json", &characters); err != nil {
		return nil, fmt.Errorf("read characters.json: %w", err)
	}

	var weapons weaponsFile
	if err := readJSON("weapons.json", &weapons); err != nil {
		return nil, fmt.Errorf("read weapons.json: %w", err)
	}

	cfg := &GameConfig{
		Version:            match.Version,
		Match:              match.Match,
		Map:                match.Map,
		DefaultCharacterID: characters.DefaultCharacterID,
		Characters:         make(map[string]CharacterConfig, len(characters.Characters)),
		Weapons:            make(map[string]WeaponConfig, len(weapons.Weapons)),
	}
	for _, character := range characters.Characters {
		if _, exists := cfg.Characters[character.ID]; exists {
			return nil, fmt.Errorf("duplicate character id %q", character.ID)
		}
		if character.VisionConeHalfAngleRad == 0 {
			character.VisionConeHalfAngleRad = DefaultVisionConeHalfAngleRad
		}
		cfg.Characters[character.ID] = character
	}
	for _, weapon := range weapons.Weapons {
		if _, exists := cfg.Weapons[weapon.ID]; exists {
			return nil, fmt.Errorf("duplicate weapon id %q", weapon.ID)
		}
		cfg.Weapons[weapon.ID] = weapon
	}
	if err := cfg.Validate(); err != nil {
		return nil, err
	}
	return cfg, nil
}

func (c *GameConfig) Validate() error {
	if c.Version <= 0 {
		return fmt.Errorf("config version must be positive")
	}
	if c.Match.TickRate < 1 || c.Match.TickRate > 60 {
		return fmt.Errorf("match tick_rate must be between 1 and 60")
	}
	if c.Match.MaxPlayers <= 0 {
		return fmt.Errorf("match max_players must be positive")
	}
	if c.Match.MinPlayers <= 0 || c.Match.MinPlayers > c.Match.MaxPlayers {
		return fmt.Errorf("match min_players must be between 1 and max_players")
	}
	if c.Match.RoundDurationSec <= 0 {
		return fmt.Errorf("match round_duration_sec must be positive")
	}
	if c.Match.RoundEndDelaySec < 0 {
		return fmt.Errorf("match round_end_delay_sec cannot be negative")
	}
	if c.Match.RoundsPerHalf <= 0 {
		return fmt.Errorf("match rounds_per_half must be positive")
	}
	if c.Match.PointsPerPlayerKill < 0 || c.Match.PointsPerZombieKill < 0 {
		return fmt.Errorf("match kill point rewards cannot be negative")
	}
	if c.Map.Width <= 0 || c.Map.Height <= 0 {
		return fmt.Errorf("map width and height must be positive")
	}
	for i, obstacle := range c.Map.SolidObstacles {
		if obstacle.W <= 0 || obstacle.H <= 0 {
			return fmt.Errorf("map solid_obstacles[%d] width and height must be positive", i)
		}
		if obstacle.X < 0 || obstacle.Y < 0 || obstacle.X+obstacle.W > c.Map.Width || obstacle.Y+obstacle.H > c.Map.Height {
			return fmt.Errorf("map solid_obstacles[%d] is outside map bounds", i)
		}
	}
	for i, shape := range c.Map.CollisionShapes {
		if err := validateCollisionShape(c.Map, shape); err != nil {
			return fmt.Errorf("map collision_shapes[%d]: %w", i, err)
		}
	}
	for i, obstacle := range c.Map.Obstacles {
		if err := validateCollisionShape(c.Map, obstacle); err != nil {
			return fmt.Errorf("map obstacles[%d]: %w", i, err)
		}
		if !obstacle.BlocksMovement && !obstacle.BlocksVision {
			return fmt.Errorf("map obstacles[%d] must block movement or vision", i)
		}
	}
	for faction, points := range c.Map.SpawnPoints {
		if faction == "" {
			return fmt.Errorf("map spawn point faction cannot be empty")
		}
		for i, point := range points {
			if point.X < 0 || point.Y < 0 || point.X > c.Map.Width || point.Y > c.Map.Height {
				return fmt.Errorf("map spawn_points[%s][%d] is outside map bounds", faction, i)
			}
		}
	}
	if c.DefaultCharacterID == "" {
		return fmt.Errorf("default_character_id is required")
	}
	if len(c.Characters) == 0 {
		return fmt.Errorf("at least one character is required")
	}
	if _, exists := c.Characters[c.DefaultCharacterID]; !exists {
		return fmt.Errorf("default character %q does not exist", c.DefaultCharacterID)
	}
	for id, character := range c.Characters {
		if id == "" {
			return fmt.Errorf("character id is required")
		}
		if character.BaseHealth <= 0 {
			return fmt.Errorf("character %q base_health must be positive", id)
		}
		if character.MaxSpeed <= 0 {
			return fmt.Errorf("character %q max_speed must be positive", id)
		}
		if character.RespawnDelaySec < 0 {
			return fmt.Errorf("character %q respawn_delay_sec cannot be negative", id)
		}
		if character.CollisionRadius <= 0 {
			return fmt.Errorf("character %q collision_radius must be positive", id)
		}
		if character.VisionRadius <= 0 || character.VisionConeLength <= 0 {
			return fmt.Errorf("character %q vision ranges must be positive", id)
		}
		if character.VisionConeHalfAngleRad <= 0 || character.VisionConeHalfAngleRad >= math.Pi {
			return fmt.Errorf("character %q vision cone half angle must be between 0 and pi radians", id)
		}
	}
	if len(c.Weapons) == 0 {
		return fmt.Errorf("at least one weapon is required")
	}
	for id, weapon := range c.Weapons {
		if id == "" {
			return fmt.Errorf("weapon id is required")
		}
		if weapon.Slot == "" {
			return fmt.Errorf("weapon %q slot is required", id)
		}
		if weapon.Damage <= 0 {
			return fmt.Errorf("weapon %q damage must be positive", id)
		}
		if weapon.FireRate <= 0 {
			return fmt.Errorf("weapon %q fire_rate must be positive", id)
		}
		if weapon.Range <= 0 {
			return fmt.Errorf("weapon %q range must be positive", id)
		}
		if weapon.AmmoCapacity <= 0 {
			return fmt.Errorf("weapon %q ammo_capacity must be positive", id)
		}
		if weapon.UnlockCost < 0 {
			return fmt.Errorf("weapon %q unlock_cost cannot be negative", id)
		}
	}
	return nil
}

func validateCollisionShape(mapConfig MapConfig, shape CollisionShape) error {
	switch shape.Type {
	case "rect":
		if shape.W <= 0 || shape.H <= 0 {
			return fmt.Errorf("rect width and height must be positive")
		}
		return nil
	case "circle":
		if shape.Radius <= 0 {
			return fmt.Errorf("circle radius must be positive")
		}
		return nil
	case "capsule", "segment":
		if shape.A == nil || shape.B == nil {
			return fmt.Errorf("%s endpoints are required", shape.Type)
		}
		if shape.Type == "capsule" && shape.Radius <= 0 {
			return fmt.Errorf("capsule radius must be positive")
		}
		return nil
	case "polygon":
		if len(shape.Points) < 3 {
			return fmt.Errorf("polygon requires at least three points")
		}
		return nil
	default:
		return fmt.Errorf("unsupported type %q", shape.Type)
	}
}

func validatePointInBounds(mapConfig MapConfig, point MapPoint) error {
	if point.X < 0 || point.Y < 0 || point.X > mapConfig.Width || point.Y > mapConfig.Height {
		return fmt.Errorf("point %.2f,%.2f is outside map bounds", point.X, point.Y)
	}
	return nil
}
