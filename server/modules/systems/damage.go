package systems

import "breach3v3/server/modules/state"

func ApplyDamage(target *state.Player, amount int) {
	if amount <= 0 || target.Health <= 0 {
		return
	}
	target.Health -= amount
	if target.Health < 0 {
		target.Health = 0
	}
}
