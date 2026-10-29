# BL-024. Настройки сервера на панели не покрывают `config.lua` v1

**Статус:** сделано (29.10.2026). Панель покрывает все 49 простых скаляров
`config.lua` 0.8.1, включая блок смерти/respawn, и группирует поля.

Итог: `gameconfig.LuaFields()` — один источник правды (ключ, тип, диапазон,
группа, i18n-подпись); из него собираются `luaSpecs` и `adminConfigFields`.
Добавлены `deathPenaltyJailDays` (0..365), `playersRespawn`, `deathTime`
(0..3600), bounty/respawn-ключи, stats/collision/world/database и
`databaseType` с проверкой `json|sqlite3`. `LuaReadOnlyFields()` перечисляет
таблицы и строки-выражения с причиной. Форма сгруппирована (General,
Permissions, Sharing, Stats, Death, Collisions, World, Database), подписи
переведены RU/EN, под полем виден сырой ключ и диапазон. Фикстура содержит все
ключи; инвентарь-тест `TestLuaSpecInventoryCoversStockScalars` падает при
пропуске или двойной пометке. Документация: `docs/reference/tes3mp-settings.md`,
`docs/v2/03-contracts.md`, `docs/v2/04-ops.md`, `docs/v2/05-panel.md`.

**Симптом.** На `/admin/config` нельзя выставить «дни смерти»: поля
`deathPenaltyJailDays` нет, как и `playersRespawn`, `deathTime`,
`bountyResetOnDeath`, `bountyDeathPenalty`, `respawnAtImperialShrine`,
`respawnAtTribunalTemple`. Оператор правит `configs/config.lua` по SSH и
перезапускает сервер вручную. Так же недоступны `fixmeInterval`,
`shareFactionExpulsion`/`shareFactionReputation`/`shareMapExploration`/
`shareVideos`, лимиты статов (`maxAttributeValue`, `maxSkillValue`,
`maxSpeedValue`, `maxAcrobaticsValue`), коллизии и лимиты объектов. Обход через
`ops config set` не работает: ключ вне белого списка даёт `config_invalid`
(`key is not in the editable whitelist`), хотя `docs/reference/tes3mp-settings.md:9`
обещает править «все остальные ключи» именно так.

**Причина.**

- Белый список `luaSpecs` (`internal/gameconfig/values.go:36-56`) содержит 19
  ключей и заканчивается на `enforceDataFiles`. В стоковом
  `configs/config.lua` 93 присваивания `config.*`, из них 49 простых скаляров
  (string/number/boolean); 30 из них не входят в список, включая весь блок
  смерти (`playersRespawn`, `deathTime`, `deathPenaltyJailDays`,
  `bountyResetOnDeath`, `bountyDeathPenalty`, `respawnAtImperialShrine`,
  `respawnAtTribunalTemple`).
- `Read` (`internal/gameconfig/lua.go:193-200`) перебирает только известные
  спеки: неизвестный скалярный ключ не попадает ни в `values`, ни в `read_only`.
  Поэтому панель и CLI не показывают даже, что настройка существует.
- `setLua` (`internal/gameconfig/lua.go:283-287`) отвергает любой ключ вне
  белого списка, так что CLI — не обход. Таблицы и списки read-only by design
  (`:293-296`), но панель их тоже не выводит.
- Панель держит вторую копию списка: `adminConfigFields`
  (`internal/panel/admin.go:1296-1325`). Поля, которых нет в снимке, молча
  пропускаются (`:1382-1385`), поэтому добавление спека в `gameconfig` без
  правки `admin.go` ничего не показывает на странице.
- Форма плоская: `adminConfigSection` — это один файл и один `grid` без
  подгрупп (`internal/panel/admin.go:182-196`,
  `internal/panel/templates/admin_config.html`). Подписи config-ключей
  захардкожены по-английски (`admin.go:1306-1325`), i18n-ключей для них нет;
  при добавлении 30 полей страница станет нечитаемой.
- Документация расходится с кодом: `docs/reference/tes3mp-settings.md:9`
  отправляет за остальными ключами в `ops config set`, но `docs/v2/04-ops.md:499-516`
  и `docs/v2/03-contracts.md:378-410` описывают белый список. Там же в
  `tes3mp-settings.md:15-16` указаны `config.serverName`/`config.serverPassword`,
  которых в стоковом `config.lua` 0.8.1 нет: имя и пароль живут в
  `tes3mp-server-default.cfg` как `hostname`/`password`.

**Что делать.**

1. Сделать один источник правды. Держать в `gameconfig` описание всех
   поддерживаемых ключей (тип, диапазон, i18n-подпись, группа) и строить из него
   и `luaSpecs`, и `adminConfigFields`, чтобы списки не расходились. Добавить
   тест-инвентарь: каждый скаляр стокового `config.lua` либо есть в списке, либо
   явно помечен read-only. Опираться на закоммиченный список, а не на
   `example-client/` — он не в git.
2. Закрыть блок смерти/respawn: `playersRespawn` (bool), `deathTime` (int,
   секунды, 0..3600), `deathPenaltyJailDays` (int, дни, 0..365),
   `bountyResetOnDeath` (bool), `bountyDeathPenalty` (bool),
   `respawnAtImperialShrine` (bool), `respawnAtTribunalTemple` (bool).
   `defaultRespawn`, `instancedSpawn`, `noninstancedSpawn` — таблицы, остаются
   read-only. В подписи `deathPenaltyJailDays` указать, что штраф складывается с
   `bountyDeathPenalty` (комментарий стокового конфига, строки 211-223), а
   `deathTime` имеет смысл только при `playersRespawn=true`.
3. Добить остальные простые скаляры: `fixmeInterval` (0..3600),
   `shareFactionExpulsion`, `shareFactionReputation`, `shareMapExploration`,
   `shareVideos`, `maxAttributeValue`, `maxSkillValue`, `maxSpeedValue`,
   `maxAcrobaticsValue`, `ignoreModifierWithMaxSkill`, `useInstancedSpawn`,
   `enablePlayerCollision`, `enableActorCollision`,
   `enablePlacedObjectCollision`, `useActorCollisionForPlacedObjects`,
   `allowOnContainerForUnloadedCells`, `pingDifferenceRequiredForAuthority`,
   `physicsFramerate`, `enforcedLogLevel`, `maximumObjectScale`,
   `generatedRecordIdPrefix`, `ignoreScriptErrors`, `databaseType`
   (`json`/`sqlite3`). Строковые выражения (`dataPath`, `databasePath`,
   `chatWindowInstructions`, `startupScriptsInstructions`) не вписываются в
   построчный `config.key = value` — оставить их read-only и назвать причину.
4. Сгруппировать поля в форме (Death & respawn, Permissions, Sharing, Stats,
   Collisions, World/Object, Database/Misc) и перевести подписи на RU/EN через
   `internal/i18n/catalog_panel.go`; сырой `config.key` оставить подсказкой.
5. Обновить фикстуры и тесты: `test/fixtures/config.go:48-74` должен содержать
   каждый ключ из `luaSpecs` (иначе `internal/gameconfig/read_test.go:53`
   сравнивает `len(values)` с `len(luaSpecs)`, а `setLua` требует присваивание);
   добавить gameconfig-тест `deathPenaltyJailDays` (чтение, запись, диапазон),
   panel-тест «поле видно и POST сохраняет только diff», i18n-тест на паритет
   подписей.
6. Поправить документацию: `docs/reference/tes3mp-settings.md:9` (не обещать
   `config set` для всех ключей) и `:15-16`; `docs/v2/05-panel.md:608-640`
   (список и группировка полей); `docs/v2/04-ops.md:499-516` (белый список);
   `docs/v2/03-contracts.md:378-410` — форма JSON не меняется, но пример
   `config get` стоит дополнить.

**Как проверять.** `/admin/config`, секция «Игровые настройки»: есть поле
«Штраф за смерть (дней тюрьмы)» со значением 5 по умолчанию. Поставить 0, затем
10, сохранить — в `configs/config.lua` меняется только строка
`config.deathPenaltyJailDays`, рядом появляется `.bak-<timestamp>`, панель
показывает «Сохранено» и баннер «нужен рестарт». `ops config get --file config
--json` возвращает `deathPenaltyJailDays` числом, `ops config set --file config
--key deathPenaltyJailDays --value -1` отвергается с `config_invalid` и
подсветкой поля. Остальные поля формы не меняются. Для инвентаря: тест
перечисляет все скаляры стокового конфига и падает, если ключ забыт или помечен
двумя способами.
