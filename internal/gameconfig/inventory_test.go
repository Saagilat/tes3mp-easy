package gameconfig

import "testing"

// stockConfigScalars is the scalar inventory of the TES3MP 0.8.1 config.lua.
// It is committed here on purpose: example-client/ is not in git, and the test
// must fail when a newly supported key is forgotten or marked twice.
var stockConfigScalars = []string{
	"gameMode",
	"loginTime",
	"maxClientsPerIP",
	"difficulty",
	"passTimeWhenEmpty",
	"nightStartHour",
	"nightEndHour",
	"allowConsole",
	"allowBedRest",
	"allowWildernessRest",
	"allowWait",
	"allowSuicideCommand",
	"allowFixmeCommand",
	"fixmeInterval",
	"enforceDataFiles",
	"shareJournal",
	"shareFactionRanks",
	"shareFactionExpulsion",
	"shareFactionReputation",
	"shareTopics",
	"shareBounty",
	"shareReputation",
	"shareMapExploration",
	"shareVideos",
	"maxAttributeValue",
	"maxSpeedValue",
	"maxSkillValue",
	"maxAcrobaticsValue",
	"ignoreModifierWithMaxSkill",
	"playersRespawn",
	"deathTime",
	"deathPenaltyJailDays",
	"bountyResetOnDeath",
	"bountyDeathPenalty",
	"respawnAtImperialShrine",
	"respawnAtTribunalTemple",
	"enablePlayerCollision",
	"enableActorCollision",
	"enablePlacedObjectCollision",
	"useActorCollisionForPlacedObjects",
	"pingDifferenceRequiredForAuthority",
	"physicsFramerate",
	"useInstancedSpawn",
	"allowOnContainerForUnloadedCells",
	"maximumObjectScale",
	"generatedRecordIdPrefix",
	"enforcedLogLevel",
	"ignoreScriptErrors",
	"databaseType",
}

func TestLuaSpecInventoryCoversStockScalars(t *testing.T) {
	editable := make(map[string]bool, len(luaSpecs))
	for _, spec := range luaSpecs {
		if spec.key == "" {
			t.Fatal("luaSpecs contains an empty key")
		}
		if editable[spec.key] {
			t.Fatalf("%s is listed twice in luaSpecs", spec.key)
		}
		if spec.group == "" {
			t.Fatalf("%s has no panel group", spec.key)
		}
		editable[spec.key] = true
		if _, ok := findSpec(luaSpecs, spec.key); !ok {
			t.Fatalf("%s is not writable through findSpec", spec.key)
		}
	}

	readOnly := make(map[string]string, len(luaReadOnlySpecs))
	for _, field := range luaReadOnlySpecs {
		if _, ok := editable[field.Key]; ok {
			t.Fatalf("%s is both editable and read-only", field.Key)
		}
		if readOnly[field.Key] != "" {
			t.Fatalf("%s is listed twice as read-only", field.Key)
		}
		if field.Reason != "table" && field.Reason != "expression" {
			t.Fatalf("%s has unknown read-only reason %q",
				field.Key, field.Reason)
		}
		readOnly[field.Key] = field.Reason
	}

	for _, key := range stockConfigScalars {
		if editable[key] {
			continue
		}
		if readOnly[key] != "" {
			continue
		}
		t.Errorf("stock scalar config.%s is neither editable nor read-only", key)
	}

	stock := make(map[string]bool, len(stockConfigScalars))
	for _, key := range stockConfigScalars {
		if stock[key] {
			t.Fatalf("%s is listed twice in stockConfigScalars", key)
		}
		stock[key] = true
	}
	for _, spec := range luaSpecs {
		if !stock[spec.key] {
			t.Errorf("config.%s is editable but absent from the stock inventory",
				spec.key)
		}
	}
}

func TestLuaFieldsExposeStableMetadata(t *testing.T) {
	fields := LuaFields()
	if len(fields) != len(luaSpecs) {
		t.Fatalf("LuaFields = %d, want %d", len(fields), len(luaSpecs))
	}
	seen := make(map[string]bool, len(fields))
	for _, field := range fields {
		if seen[field.Key] {
			t.Fatalf("%s appears twice in LuaFields", field.Key)
		}
		seen[field.Key] = true
		if field.Kind != "string" && field.Kind != "int" && field.Kind != "bool" {
			t.Fatalf("%s has kind %q", field.Key, field.Kind)
		}
		if field.LabelKey != "panel.config.field."+field.Key {
			t.Fatalf("%s label key = %q", field.Key, field.LabelKey)
		}
	}
	if len(fields) == 0 {
		t.Fatal("LuaFields is empty")
	}
	if fields[0].Key != "gameMode" {
		t.Fatalf("first field = %q, want gameMode", fields[0].Key)
	}
}
