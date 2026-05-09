package systems

import (
	"testing"
	"time"

	"breach3v3/backend/modules/config"
	"breach3v3/backend/modules/state"
)

func TestUpdateRoundTransitionsWaitingToPlaying(t *testing.T) {
	matchState := state.NewMatchState()
	matchState.Players["a"] = &state.Player{Connected: true}
	matchState.Players["b"] = &state.Player{Connected: true}

	now := time.Now().UTC()
	UpdateRound(matchState, now)

	if matchState.Phase != state.ROUND_PLAYING {
		t.Fatalf("expected playing phase, got %d", matchState.Phase)
	}
	if !matchState.RoundStarted.Equal(now) {
		t.Fatalf("expected round start timestamp to be set")
	}
}

func TestUpdateRoundTransitionsPlayingToEnded(t *testing.T) {
	matchState := state.NewMatchState()
	matchState.Phase = state.ROUND_PLAYING
	matchState.RoundStarted = time.Now().UTC().Add(-(time.Duration(config.ROUND_DURATION_SEC) + 1) * time.Second)

	UpdateRound(matchState, time.Now().UTC())

	if matchState.Phase != state.ROUND_ENDED {
		t.Fatalf("expected ended phase, got %d", matchState.Phase)
	}
	if matchState.RoundEnded.IsZero() {
		t.Fatalf("expected round end timestamp to be set")
	}
}
