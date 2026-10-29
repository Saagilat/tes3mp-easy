package gameconfig

import (
	"errors"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestSetReadOnlyExpressionExplainsReason(t *testing.T) {
	root := fixtureRoot(t)
	now := time.Date(2026, 10, 28, 12, 0, 0, 0, time.UTC)
	_, err := Set(root, FileConfig, "dataPath", "/tmp/data", now, true)
	if !errors.Is(err, ErrInvalid) {
		t.Fatalf("set dataPath error = %v, want ErrInvalid", err)
	}
	if !strings.Contains(err.Error(), "read-only (expression)") {
		t.Fatalf("error = %q, want a read-only reason", err)
	}
}

func TestDeathPenaltyJailDaysReadWriteRange(t *testing.T) {
	root := fixtureRoot(t)
	path := filepath.Join(root, "configs", "config.lua")
	now := time.Date(2026, 10, 28, 12, 0, 0, 0, time.UTC)

	snapshot, err := Read(root, FileConfig)
	if err != nil {
		t.Fatalf("read config: %v", err)
	}
	if got := snapshot.Values["deathPenaltyJailDays"]; got != 5 {
		t.Fatalf("deathPenaltyJailDays = %#v, want 5", got)
	}
	if got := snapshot.Values["playersRespawn"]; got != true {
		t.Fatalf("playersRespawn = %#v, want true", got)
	}

	result, err := Set(root, FileConfig, "deathPenaltyJailDays", "10", now, false)
	if err != nil {
		t.Fatalf("set deathPenaltyJailDays: %v", err)
	}
	if result.Value != 10 {
		t.Fatalf("value = %#v, want 10", result.Value)
	}
	body := stringMustRead(t, path)
	if !strings.Contains(body, "config.deathPenaltyJailDays = 10") {
		t.Fatalf("config.lua has no new deathPenaltyJailDays:\n%s", body)
	}

	for _, value := range []string{"-1", "366", "soon"} {
		if _, err := Set(root, FileConfig, "deathPenaltyJailDays", value, now,
			false); !errors.Is(err, ErrInvalid) {
			t.Fatalf("set deathPenaltyJailDays=%s error = %v, want ErrInvalid",
				value, err)
		}
	}
}

func TestDatabaseTypeRejectsUnknownValue(t *testing.T) {
	root := fixtureRoot(t)
	now := time.Date(2026, 10, 28, 12, 0, 0, 0, time.UTC)
	if _, err := Set(root, FileConfig, "databaseType", "sqlite3", now,
		false); err != nil {
		t.Fatalf("set databaseType sqlite3: %v", err)
	}
	if _, err := Set(root, FileConfig, "databaseType", "mysql", now,
		false); !errors.Is(err, ErrInvalid) {
		t.Fatalf("set databaseType mysql error = %v, want ErrInvalid", err)
	}
}
