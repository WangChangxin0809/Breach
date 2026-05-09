package systems

import (
	"time"

	"breach3v3/server/modules/config"
	"breach3v3/server/modules/state"
)

func UpdateRound(matchState *state.MatchState, now time.Time) {
	switch matchState.Phase {
	case state.ROUND_WAITING:
		if matchState.ConnectedCount() >= config.MATCH_MIN_PLAYERS {
			matchState.Phase = state.ROUND_PLAYING
			matchState.RoundStarted = now
		}
	case state.ROUND_PLAYING:
		if now.Sub(matchState.RoundStarted) >= time.Duration(config.ROUND_DURATION_SEC)*time.Second {
			matchState.Phase = state.ROUND_ENDED
			matchState.RoundEnded = now
		}
	case state.ROUND_ENDED:
		if now.Sub(matchState.RoundEnded) >= time.Duration(config.ROUND_END_DELAY_SEC)*time.Second {
			matchState.Phase = state.ROUND_WAITING
			matchState.RoundStarted = time.Time{}
			matchState.RoundEnded = time.Time{}
		}
	}
}

func RoundTimeRemaining(matchState *state.MatchState, now time.Time) float32 {
	if matchState.Phase != state.ROUND_PLAYING || matchState.RoundStarted.IsZero() {
		return float32(config.ROUND_DURATION_SEC)
	}
	remaining := time.Duration(config.ROUND_DURATION_SEC)*time.Second - now.Sub(matchState.RoundStarted)
	if remaining < 0 {
		return 0
	}
	return float32(remaining.Seconds())
}
