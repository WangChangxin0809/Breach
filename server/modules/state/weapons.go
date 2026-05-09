package state

type Weapon interface {
	ID() string
	Damage() int
	FireRate() float64
	Range() float64
	AmmoCapacity() int
}

type WeaponSpec struct {
	WeaponID string
	Dmg      int
	Rate     float64
	MaxRange float64
	Ammo     int
}

func (w WeaponSpec) ID() string        { return w.WeaponID }
func (w WeaponSpec) Damage() int       { return w.Dmg }
func (w WeaponSpec) FireRate() float64 { return w.Rate }
func (w WeaponSpec) Range() float64    { return w.MaxRange }
func (w WeaponSpec) AmmoCapacity() int { return w.Ammo }
