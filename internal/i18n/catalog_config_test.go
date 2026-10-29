package i18n

import (
	"testing"

	"github.com/Saagilat/tes3mp-easy/internal/gameconfig"
)

func TestConfigFieldLabelsHaveBothLanguages(t *testing.T) {
	for _, field := range gameconfig.LuaFields() {
		for _, language := range Supported() {
			if catalogs[language][field.LabelKey] == "" {
				t.Errorf("%s is missing %q", language, field.LabelKey)
			}
		}
	}
	for _, key := range []string{
		KeyPanelConfigGroupGeneral,
		KeyPanelConfigGroupPermissions,
		KeyPanelConfigGroupSharing,
		KeyPanelConfigGroupStats,
		KeyPanelConfigGroupDeath,
		KeyPanelConfigGroupCollisions,
		KeyPanelConfigGroupWorld,
		KeyPanelConfigGroupDatabase,
	} {
		for _, language := range Supported() {
			if catalogs[language][key] == "" {
				t.Errorf("%s is missing %q", language, key)
			}
		}
	}
}
