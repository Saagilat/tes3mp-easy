# BL-025. Установщик клиента для Linux

**Статус:** сделано (29.10.2026), из PR #1 (OdinAwaits).

**Симптом.** Linux-игрок получал клиент только вручную: скачать архив из
`client-latest`, распаковать, положить бинарь в `PATH`, самому сделать
`.desktop` и иконку. Первый же вопрос новичка — «а куда распаковать и почему
нет пункта в меню».

**Что сделано.** `tes3mp-easy-client-installer.sh` (корень репозитория, как
`install.sh` для сервера): сканирует список релизов, берёт клиентский архив с
наибольшей версией (`client-latest` и серверные архивы отсекаются шаблоном
`tes3mp-easy-client-[0-9]…-linux-amd64.tar.gz`), проверяет `.sha256`, кладёт
бинарь в `~/.local/bin` через staged + `mv` (атомарная замена, без `ETXTBSY`),
иконку и `.desktop` — в `$XDG_DATA_HOME` (по умолчанию `~/.local/share`).
Иконка и меню берутся из `assets/` того же тега (`refs/tags/<tag>`), поэтому
установленный клиент всегда из одного релиза. Root не нужен и запрещён явно;
`TES3MP_EASY_CLIENT_VERSION` прибивает версию; `TES3MP_EASY_RELEASES_API`
подменяет источник метаданных — на нём работает тест.

**Поставка.** `release.yml` кладёт установщик в `dist/` (`install -m 0755`) и
публикует как клиентский ассет в версионном релизе и в `client-latest` (имя без
версии копируется в алиас как есть); рядом `.sha256`. `ci.yml` проверяет
`bash -n` и гоняет `test/client-install-smoke.sh`.

**Проверка.** `test/client-install-smoke.sh` — фейковый `curl`, поддельный
архив и временный `HOME`: последняя версия, пиннинг версии через тег, битый
`.sha256` (установка падает и бинаря не остаётся), повторный запуск поверх
установленного. Инварианты (ассет в обоих релизах, `[0-9]` в `CLIENT_ASSET`,
`bash -n` и тест в CI, наличие `assets/`) закреплены `TestClientInstaller`
(`test/docs/release_test.go`).

**Документация.** `README.md` (§игрок — команда установки и
`TES3MP_EASY_CLIENT_VERSION`), `docs/v2/06-client.md` §2 (вместо «без
установщика»), `docs/v2/08-runbook.md` §17 (артефакты и проверка алиаса).

**Как проверять.** На чистой Debian/Ubuntu без root:
`curl -fsSL https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master/tes3mp-easy-client-installer.sh | bash`
— бинарь в `~/.local/bin`, пункт меню в `~/.local/share/applications`,
`tes3mp-easy-client --version` печатает версию из последнего `client-v*`.
С Windows установщика нет: там по-прежнему zip.

**Правки после `client-v0.3.0` (→ `client-v0.3.1`).** Проверка на живом Xfce
вскрыла две вещи. Первая: one-liner `bash <(curl …)` не работает в fish
(process substitution есть только в bash/zsh) — в README, шапке скрипта и здесь
команда переписана на `curl -fsSL … | bash`, это держит `TestClientInstaller`.
Вторая: панель DE запускает `Exec` без login-шелла, а её `PATH`
(`/proc/<panel>/environ`) не содержит `~/.local/bin`, поэтому относительный
`Exec=tes3mp-easy-client` по клику не находился; установщик теперь подставляет
абсолютный путь через `sed` и проверяет результат. Заодно в ассете
`Categories=Game;` (две main-категории давали hint валидатора и дубль в меню),
`Comment=` и `Keywords=tes3mp;morrowind;` — поиск в меню находит по
«морровинд». Свежая установка печатает подсказку про перезапуск панели
(`xfce4-panel -r`): Whisker держит список приложений в памяти и без этого
новый пункт не ищется. Правки в `assets/` требуют нового тега — установщик
берёт `.desktop` из тега.
