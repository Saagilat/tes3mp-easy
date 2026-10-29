package fixtures

import (
	"path/filepath"
	"testing"
)

// ConfigFile is one synthetic TES3MP configuration file.
type ConfigFile struct {
	Name string
	Body string
}

// DefaultConfigs returns the three files from docs/v2/07-testing.md §3.
func DefaultConfigs() []ConfigFile {
	return []ConfigFile{
		DefaultServerConfig(),
		DefaultConfigLua(),
		DefaultBanlist(),
	}
}

// DefaultServerConfig returns a minimal synthetic tes3mp-server-default.cfg.
func DefaultServerConfig() ConfigFile {
	return ConfigFile{
		Name: "tes3mp-server-default.cfg",
		Body: `[General]
# Synthetic test configuration; no production values.
localAddress = 0.0.0.0
port = 25565
maximumPlayers = 8
hostname = Morrowind with friends
logLevel = 1
password =

[Plugins]
home = ./server
plugins = serverCore.lua

[MasterServer]
enabled = false
`,
	}
}

// DefaultConfigLua returns a minimal synthetic config.lua with the editable
// scalar keys used by the future config tests.
func DefaultConfigLua() ConfigFile {
	return ConfigFile{
		Name: "config.lua",
		Body: `config = {}

-- Synthetic test configuration; tables stay read-only.
config.gameMode = "Default"
config.loginTime = 60
config.maxClientsPerIP = 3
config.difficulty = 0
config.passTimeWhenEmpty = false
config.nightStartHour = 20
config.nightEndHour = 6
config.allowConsole = false
config.allowBedRest = true
config.allowWildernessRest = true
config.allowWait = true
config.allowSuicideCommand = true
config.allowFixmeCommand = true
config.fixmeInterval = 30
config.enforceDataFiles = true
config.shareJournal = true
config.shareFactionRanks = true
config.shareFactionExpulsion = false
config.shareFactionReputation = true
config.shareTopics = true
config.shareBounty = false
config.shareReputation = true
config.shareMapExploration = false
config.shareVideos = true
config.maxAttributeValue = 200
config.maxSpeedValue = 365
config.maxSkillValue = 200
config.maxAcrobaticsValue = 1200
config.ignoreModifierWithMaxSkill = false
config.playersRespawn = true
config.deathTime = 5
config.deathPenaltyJailDays = 5
config.bountyResetOnDeath = false
config.bountyDeathPenalty = false
config.respawnAtImperialShrine = true
config.respawnAtTribunalTemple = true
config.enablePlayerCollision = true
config.enableActorCollision = true
config.enablePlacedObjectCollision = false
config.useActorCollisionForPlacedObjects = false
config.pingDifferenceRequiredForAuthority = 40
config.physicsFramerate = 60
config.useInstancedSpawn = true
config.allowOnContainerForUnloadedCells = false
config.maximumObjectScale = 20
config.generatedRecordIdPrefix = "$custom"
config.enforcedLogLevel = -1
config.ignoreScriptErrors = false
config.databaseType = "json"
`,
	}
}

// DefaultBanlist returns an empty ban list in the canonical shape.
func DefaultBanlist() ConfigFile {
	return ConfigFile{
		Name: "banlist.json",
		Body: `{
  "playerNames": [],
  "ipAddresses": []
}
`,
	}
}

// Write writes the config file below dir.
func (f ConfigFile) Write(t testing.TB, dir string) {
	t.Helper()
	WriteFile(t, filepath.Join(dir, f.Name), f.Body)
}

// WriteConfigs writes all default config files below dir.
func WriteConfigs(t testing.TB, dir string) {
	t.Helper()
	for _, file := range DefaultConfigs() {
		file.Write(t, dir)
	}
}
