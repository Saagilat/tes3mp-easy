# BL-022. Применить state без применения его мод-пака

**Статус:** сделано (29.10.2026). `state deploy` и `state import` получили
`--keep-mods`; панель — отдельное действие «Только состояние».

Итог: `archive.ValidateStateLayoutFileWithSize` проверяет layout и
`configs/config.lua` без `VerifyStateMods`. `state deploy --keep-mods` не меняет
`backups/mods/current.txt`, возвращает `mods_kept` и `warnings` с расхождением
пакетов; `state import --keep-mods` кладёт такой state в `backups/state` без
активного пакета. Панель: `StateDeployKeepMods`, `keep_mods=1`, кнопка «Только
состояние» доступна и при `mods_available == false`; bundle-восстановление
осталось строгим. Защита: `TestRunStateDeployKeepMods`,
`TestRunStateImportKeepModsWithoutPackage`, `TestAdminStateCreateAndDeploy`,
`TestOpsClientCommands`.

**Симптом.** Сохранение, снятое на другом наборе плагинов, нельзя применить,
оставив текущие моды. В панели строка такого состояния либо не даёт нажать
«Восстановить», либо клик сначала включает мод-пак из `current.txt`, а при
расхождении возвращается ошибка (`archive_invalid` / `422`). В CLI
`tes3mp-easy-ops state deploy --archive <name>` падает с тем же кодом. Оператору
же иногда нужен только откат мира (`players/`, `world/`, `configs/config.lua`):
после обновления пака, когда старый архив удалён или не импортирован, или когда
пак меняли осознанно и мир с ним совместим.

**Причина.**

- `archive.VerifyStateMods` (`internal/archive/current.go:136-166`) требует
  точного равенства `current.txt` состояния и `backups/mods/current.txt`
  (`:157-162`) и наличия файла с записанным sha256 (`:164-165`).
- `ValidateStateFileWithSize` (`internal/archive/state.go:56-71`) всегда вызывает
  `VerifyStateMods`, а `inspectStateDeployArchive`
  (`cmd/tes3mp-easy-ops/state_deploy.go:87-107`, вызов на `:104`) всегда идёт
  через него. Проверка layout без модов уже есть — `ValidateStateLayoutFile`
  (`internal/archive/state.go:40-51`), ею пользуются публичные скачивания, но не
  deploy.
- Флага обхода нет: `parseStateDeployArgs`
  (`cmd/tes3mp-easy-ops/state.go:100-141`) знает только `--archive`, `--latest`,
  `--no-restart`.
- Контракт уже сообщает пакет состояния (`mods_archive` в `stateDeployData`,
  `cmd/tes3mp-easy-ops/state_deploy.go:20-25`, `:82`), но не допускает решения
  «оставить активный».
- Панель закрепляет тот же порядок: `CanRestore` требует `mods_available`
  (`internal/panel/public.go:149`), строка сама отправляет `mods` и панель
  вызывает `ops mods deploy` перед `ops state deploy`
  (`internal/panel/admin.go:1180-1211`), bundle-восстановление сверяет
  `current.txt` и импортирует моды (`internal/panel/restore.go:360-372`).
- Документация фиксирует запрет: `docs/v2/04-ops.md:350-368`,
  `docs/v2/03-contracts.md:273-275`, `:519-520`,
  `docs/v2/05-panel.md:537-553`.

**Что делать.**

1. Добавить `state deploy --keep-mods`: проверять layout и `configs/config.lua`
   (`ValidateStateLayoutFile` / `ValidateStateWithSize`), но пропускать
   `VerifyStateMods`; `backups/mods/current.txt` не трогать и `mods deploy` не
   вызывать. Без флага поведение прежнее, `archive_invalid` остаётся.
2. Развести проверку: `inspectStateDeployArchive(..., checkMods bool)`. В
   `stateDeployResult` и `stateDeployData` добавить `mods_kept` и `warnings`
   (сейчас warnings уходят только в stderr) с текстом «state снят на пакете X,
   активен Y».
3. Тот же флаг для `state import`: иначе скачанный state нельзя даже положить в
   `backups/state`, хотя применить его разрешено.
4. Панель: у строки состояния отдельное действие «Применить только состояние» с
   подтверждением, доступное и при `mods_available == false`; bundle-восстановление
   оставить строгим, потому что ZIP несёт оба файла. `CanRestore` не должен
   оставаться единственным условием кнопки.
5. Контракт и доки: `03-contracts.md` §6.3 (`:257-278`) и §6.4 (`:519-520`),
   `04-ops.md:350-368`, `05-panel.md:537-560`. Явно записать риск: мир с другого
   набора плагинов может не загрузиться, а клиенты с чужим
   `requiredDataFiles.json` получат отказ сервера; это осознанный выбор
   оператора, а не автоматика.
6. Тесты: `TestParseStateDeployArgs` (новый флаг), новый
   `TestRunStateDeployKeepMods` (state с чужим `current.txt` применяется,
   `backups/mods/current.txt` и файлы модов не меняются), существующий
   `TestRunStateDeployRejectsForeignOrMissingCurrent`
   (`cmd/tes3mp-easy-ops/state_deploy_targets_test.go:90`) продолжает проверять
   режим без флага, panel-тесты `ops_test` / `restore_test`.

**Как проверять.** Снять state, обновить мод-пак, выполнить
`state deploy --archive <state> --keep-mods`: `players/`, `world/`,
`config.lua` заменены, `backups/mods/current.txt` и список модов прежние, в
результате есть предупреждение о расхождении; тот же вызов без флага —
`archive_invalid`, данные не тронуты. В панели «Применить только состояние»
работает для состояния без доступного мод-пака, «Восстановить» по-прежнему
сначала включает пакет.
