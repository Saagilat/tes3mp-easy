package gameconfig

import (
	"fmt"
	"strconv"
	"strings"
)

type valueKind uint8

const (
	kindString valueKind = iota
	kindInt
	kindBool
)

type valueSpec struct {
	key      string
	section  string
	iniKey   string
	kind     valueKind
	min, max int64
	minLen   int
	maxLen   int
	group    string
	allowed  []string
}

// Lua field groups keep the panel form readable as the editable key list grows.
// The order of LuaFields also defines the order of groups and fields.
const (
	LuaGroupGeneral     = "general"
	LuaGroupPermissions = "permissions"
	LuaGroupSharing     = "sharing"
	LuaGroupStats       = "stats"
	LuaGroupDeath       = "death"
	LuaGroupCollisions  = "collisions"
	LuaGroupWorld       = "world"
	LuaGroupDatabase    = "database"
)

// LuaField is the public description of an editable config.lua key. The panel
// builds its form from this list, so it cannot drift from the write whitelist.
type LuaField struct {
	Key      string
	Kind     string
	Group    string
	LabelKey string
	Min      int64
	Max      int64
	Allowed  []string
}

// LuaReadOnlyField documents a config.lua key that cannot be edited as a
// single scalar assignment. Reason is "table" or "expression".
type LuaReadOnlyField struct {
	Key    string
	Reason string
}

var serverSpecs = []valueSpec{
	{key: "hostname", section: "General", iniKey: "hostname", kind: kindString, minLen: 1, maxLen: 64},
	{key: "port", section: "General", iniKey: "port", kind: kindInt, min: 1024, max: 65535},
	{key: "maximumPlayers", section: "General", iniKey: "maximumPlayers", kind: kindInt, min: 1, max: 64},
	{key: "password", section: "General", iniKey: "password", kind: kindString},
	{key: "logLevel", section: "General", iniKey: "logLevel", kind: kindInt, min: 0, max: 4},
	{key: "masterServerEnabled", section: "MasterServer", iniKey: "enabled", kind: kindBool},
}

var luaSpecs = []valueSpec{
	// General
	{key: "gameMode", kind: kindString, group: LuaGroupGeneral},
	{key: "loginTime", kind: kindInt, min: 10, max: 600, group: LuaGroupGeneral},
	{key: "maxClientsPerIP", kind: kindInt, min: 1, max: 10, group: LuaGroupGeneral},
	{key: "difficulty", kind: kindInt, min: -100, max: 100, group: LuaGroupGeneral},
	{key: "passTimeWhenEmpty", kind: kindBool, group: LuaGroupGeneral},
	{key: "nightStartHour", kind: kindInt, min: 0, max: 23, group: LuaGroupGeneral},
	{key: "nightEndHour", kind: kindInt, min: 0, max: 23, group: LuaGroupGeneral},

	// Permissions
	{key: "allowConsole", kind: kindBool, group: LuaGroupPermissions},
	{key: "allowBedRest", kind: kindBool, group: LuaGroupPermissions},
	{key: "allowWildernessRest", kind: kindBool, group: LuaGroupPermissions},
	{key: "allowWait", kind: kindBool, group: LuaGroupPermissions},
	{key: "allowSuicideCommand", kind: kindBool, group: LuaGroupPermissions},
	{key: "allowFixmeCommand", kind: kindBool, group: LuaGroupPermissions},
	{key: "fixmeInterval", kind: kindInt, min: 0, max: 3600, group: LuaGroupPermissions},
	{key: "enforceDataFiles", kind: kindBool, group: LuaGroupPermissions},

	// Sharing
	{key: "shareJournal", kind: kindBool, group: LuaGroupSharing},
	{key: "shareFactionRanks", kind: kindBool, group: LuaGroupSharing},
	{key: "shareFactionExpulsion", kind: kindBool, group: LuaGroupSharing},
	{key: "shareFactionReputation", kind: kindBool, group: LuaGroupSharing},
	{key: "shareTopics", kind: kindBool, group: LuaGroupSharing},
	{key: "shareBounty", kind: kindBool, group: LuaGroupSharing},
	{key: "shareReputation", kind: kindBool, group: LuaGroupSharing},
	{key: "shareMapExploration", kind: kindBool, group: LuaGroupSharing},
	{key: "shareVideos", kind: kindBool, group: LuaGroupSharing},

	// Stats
	{key: "maxAttributeValue", kind: kindInt, min: 1, max: 10000, group: LuaGroupStats},
	{key: "maxSpeedValue", kind: kindInt, min: 0, max: 10000, group: LuaGroupStats},
	{key: "maxSkillValue", kind: kindInt, min: 1, max: 10000, group: LuaGroupStats},
	{key: "maxAcrobaticsValue", kind: kindInt, min: 0, max: 10000, group: LuaGroupStats},
	{key: "ignoreModifierWithMaxSkill", kind: kindBool, group: LuaGroupStats},

	// Death and respawn
	{key: "playersRespawn", kind: kindBool, group: LuaGroupDeath},
	{key: "deathTime", kind: kindInt, min: 0, max: 3600, group: LuaGroupDeath},
	{key: "deathPenaltyJailDays", kind: kindInt, min: 0, max: 365, group: LuaGroupDeath},
	{key: "bountyResetOnDeath", kind: kindBool, group: LuaGroupDeath},
	{key: "bountyDeathPenalty", kind: kindBool, group: LuaGroupDeath},
	{key: "respawnAtImperialShrine", kind: kindBool, group: LuaGroupDeath},
	{key: "respawnAtTribunalTemple", kind: kindBool, group: LuaGroupDeath},

	// Collisions and authority
	{key: "enablePlayerCollision", kind: kindBool, group: LuaGroupCollisions},
	{key: "enableActorCollision", kind: kindBool, group: LuaGroupCollisions},
	{key: "enablePlacedObjectCollision", kind: kindBool, group: LuaGroupCollisions},
	{key: "useActorCollisionForPlacedObjects", kind: kindBool, group: LuaGroupCollisions},
	{key: "pingDifferenceRequiredForAuthority", kind: kindInt, min: 0, max: 10000, group: LuaGroupCollisions},
	{key: "physicsFramerate", kind: kindInt, min: 1, max: 1000, group: LuaGroupCollisions},

	// World and objects
	{key: "useInstancedSpawn", kind: kindBool, group: LuaGroupWorld},
	{key: "allowOnContainerForUnloadedCells", kind: kindBool, group: LuaGroupWorld},
	{key: "maximumObjectScale", kind: kindInt, min: 1, max: 1000, group: LuaGroupWorld},
	{key: "generatedRecordIdPrefix", kind: kindString, maxLen: 32, group: LuaGroupWorld},
	{key: "enforcedLogLevel", kind: kindInt, min: -1, max: 4, group: LuaGroupWorld},

	// Database and diagnostics
	{key: "ignoreScriptErrors", kind: kindBool, group: LuaGroupDatabase},
	{key: "databaseType", kind: kindString, group: LuaGroupDatabase,
		allowed: []string{"json", "sqlite3"}},
}

// luaReadOnlySpecs lists stock config.lua keys that are deliberately outside
// the scalar whitelist. Exposed for inventory tests and documentation.
var luaReadOnlySpecs = []LuaReadOnlyField{
	{Key: "dataPath", Reason: "expression"},
	{Key: "chatWindowInstructions", Reason: "expression"},
	{Key: "startupScriptsInstructions", Reason: "expression"},
	{Key: "databasePath", Reason: "expression"},
	{Key: "gameSettings", Reason: "table"},
	{Key: "vrSettings", Reason: "table"},
	{Key: "defaultTimeTable", Reason: "table"},
	{Key: "worldStartupScripts", Reason: "table"},
	{Key: "playerStartupScripts", Reason: "table"},
	{Key: "disabledClientScriptIds", Reason: "table"},
	{Key: "synchronizedClientScriptIds", Reason: "table"},
	{Key: "instancedSpawn", Reason: "table"},
	{Key: "noninstancedSpawn", Reason: "table"},
	{Key: "defaultRespawn", Reason: "table"},
	{Key: "forbiddenCells", Reason: "table"},
	{Key: "bannedEquipmentItems", Reason: "table"},
	{Key: "rankColors", Reason: "table"},
	{Key: "customMenuIds", Reason: "table"},
	{Key: "menuHelperFiles", Reason: "table"},
	{Key: "enforcedCollisionRefIds", Reason: "table"},
	{Key: "disallowedActivateRefIds", Reason: "table"},
	{Key: "disallowedDeleteRefIds", Reason: "table"},
	{Key: "disallowedCreateRefIds", Reason: "table"},
	{Key: "disallowedLockRefIds", Reason: "table"},
	{Key: "disallowedTrapRefIds", Reason: "table"},
	{Key: "disallowedStateRefIds", Reason: "table"},
	{Key: "disallowedDoorStateRefIds", Reason: "table"},
	{Key: "recordStoreLoadOrder", Reason: "table"},
	{Key: "enchantableRecordTypes", Reason: "table"},
	{Key: "carriableRecordTypes", Reason: "table"},
	{Key: "unplaceableRecordTypes", Reason: "table"},
	{Key: "validRecordSettings", Reason: "table"},
	{Key: "requiredRecordSettings", Reason: "table"},
	{Key: "mutuallyExclusiveRecordSettings", Reason: "table"},
	{Key: "numericalRecordSettings", Reason: "table"},
	{Key: "booleanRecordSettings", Reason: "table"},
	{Key: "minMaxRecordSettings", Reason: "table"},
	{Key: "rgbRecordSettings", Reason: "table"},
	{Key: "cellPacketTypes", Reason: "table"},
	{Key: "disallowedNameStrings", Reason: "table"},
	{Key: "playerKeyOrder", Reason: "table"},
	{Key: "cellKeyOrder", Reason: "table"},
	{Key: "recordstoreKeyOrder", Reason: "table"},
	{Key: "worldKeyOrder", Reason: "table"},
}

// LuaFields returns the editable config.lua keys in presentation order.
func LuaFields() []LuaField {
	fields := make([]LuaField, 0, len(luaSpecs))
	for _, spec := range luaSpecs {
		fields = append(fields, LuaField{
			Key:      spec.key,
			Kind:     spec.kind.name(),
			Group:    spec.group,
			LabelKey: "panel.config.field." + spec.key,
			Min:      spec.min,
			Max:      spec.max,
			Allowed:  append([]string(nil), spec.allowed...),
		})
	}
	return fields
}

// LuaReadOnlyFields returns non-scalar config.lua keys and the reason they are
// read-only.
func LuaReadOnlyFields() []LuaReadOnlyField {
	return append([]LuaReadOnlyField(nil), luaReadOnlySpecs...)
}

func (k valueKind) name() string {
	switch k {
	case kindString:
		return "string"
	case kindInt:
		return "int"
	case kindBool:
		return "bool"
	default:
		return ""
	}
}

func findSpec(specs []valueSpec, key string) (valueSpec, bool) {
	for _, spec := range specs {
		if spec.key == key {
			return spec, true
		}
	}
	return valueSpec{}, false
}

func valueAllowed(spec valueSpec, value string) bool {
	if len(spec.allowed) == 0 {
		return true
	}
	for _, allowed := range spec.allowed {
		if value == allowed {
			return true
		}
	}
	return false
}

func readOnlyLuaKey(key string) bool {
	_, ok := luaReadOnlySpec(key)
	return ok
}

func luaReadOnlySpec(key string) (LuaReadOnlyField, bool) {
	for _, field := range luaReadOnlySpecs {
		if field.Key == key {
			return field, true
		}
	}
	return LuaReadOnlyField{}, false
}

func parseTypedValue(spec valueSpec, raw string) (any, error) {
	switch spec.kind {
	case kindString:
		value := raw
		if strings.ContainsAny(value, "\x00\r\n") {
			return nil, fmt.Errorf("%s contains a control character", spec.key)
		}
		if spec.minLen > 0 && len(value) < spec.minLen {
			return nil, fmt.Errorf("%s must be at least %d characters", spec.key, spec.minLen)
		}
		if spec.maxLen > 0 && len(value) > spec.maxLen {
			return nil, fmt.Errorf("%s must be at most %d characters", spec.key, spec.maxLen)
		}
		if !valueAllowed(spec, value) {
			return nil, fmt.Errorf("%s must be one of %s", spec.key,
				strings.Join(spec.allowed, ", "))
		}
		return value, nil
	case kindInt:
		value, err := strconv.ParseInt(strings.TrimSpace(raw), 10, 64)
		if err != nil {
			return nil, fmt.Errorf("%s must be an integer", spec.key)
		}
		if value < spec.min || value > spec.max {
			return nil, fmt.Errorf("%s must be in %d..%d", spec.key, spec.min, spec.max)
		}
		return int(value), nil
	case kindBool:
		switch strings.ToLower(strings.TrimSpace(raw)) {
		case "true":
			return true, nil
		case "false":
			return false, nil
		default:
			return nil, fmt.Errorf("%s must be true or false", spec.key)
		}
	default:
		return nil, fmt.Errorf("%s has an unsupported type", spec.key)
	}
}

func formatValue(spec valueSpec, value any) (string, error) {
	switch spec.kind {
	case kindString:
		text, ok := value.(string)
		if !ok {
			return "", fmt.Errorf("%s must be a string", spec.key)
		}
		return text, nil
	case kindInt:
		number, ok := value.(int)
		if !ok {
			return "", fmt.Errorf("%s must be an integer", spec.key)
		}
		return strconv.Itoa(number), nil
	case kindBool:
		flag, ok := value.(bool)
		if !ok {
			return "", fmt.Errorf("%s must be a boolean", spec.key)
		}
		return strconv.FormatBool(flag), nil
	default:
		return "", fmt.Errorf("%s has an unsupported type", spec.key)
	}
}

func luaQuote(value string) string {
	var out strings.Builder
	out.WriteByte('"')
	for i := 0; i < len(value); i++ {
		switch ch := value[i]; ch {
		case '\\', '"':
			out.WriteByte('\\')
			out.WriteByte(ch)
		case '\n':
			out.WriteString(`\n`)
		case '\r':
			out.WriteString(`\r`)
		case '\t':
			out.WriteString(`\t`)
		default:
			out.WriteByte(ch)
		}
	}
	out.WriteByte('"')
	return out.String()
}

func formatLuaValue(spec valueSpec, value any) (string, error) {
	if spec.kind == kindString {
		text, ok := value.(string)
		if !ok {
			return "", fmt.Errorf("%s must be a string", spec.key)
		}
		if strings.ContainsAny(text, "\x00\r\n") {
			return "", fmt.Errorf("%s contains a control character", spec.key)
		}
		return luaQuote(text), nil
	}
	return formatValue(spec, value)
}
