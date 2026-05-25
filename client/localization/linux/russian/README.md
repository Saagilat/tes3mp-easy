# Русская локализация Morrowind для OpenMW/TES3MP (Steam + Linux/Proton)

Готовая сборка русской локализации (русификатора) Morrowind, адаптированная для установки на Linux с OpenMW или TES3MP (Proton).

Архивы локализации доступны в [GitHub Releases](https://github.com/Saagilat/tes3mp-easy-setup/releases).

## Состав

- `russifier.tar` — основные файлы локализации (текстуры, меши, шрифты, ESP, иконки) — **скачать вручную**
- `voices_russian.tar` — русская озвучка (опционально) — **скачать вручную**
- `install.sh` — скрипт установки

## Установка

1. Скачайте `russifier.tar` (и опционально `voices_russian.tar`) из [GitHub Releases](https://github.com/Saagilat/tes3mp-easy-setup/releases)
2. Поместите скачанные архивы в ту же папку, где лежит `install.sh`
3. Запустите скрипт, указав путь к папке с Morrowind:

```bash
./install.sh ~/morrowind
```

Где `~/morrowind` — папка, содержащая `Morrowind.exe` (симлинк на Steam-версию — см. руководство по установке TES3MP).

Если не указывать путь, скрипт спросит его интерактивно:

```bash
./install.sh
```

### Что делает скрипт

1. Извлекает из архива локализации **только `Data Files/`** (текстуры, меши, шрифты, ESP, иконки — без ESM/EXE/Morrowind.ini)
2. Копирует видеофайлы из `Video/` в `Data Files/Video/`
3. Создаёт заглушки для отсутствующих видео (пустые файлы)
4. Если есть `voices_russian.tar` — устанавливает русскую озвучку

### Настройка шрифтов

После установки локализации настройте шрифты по [руководству по кастомизации](../../../customization.md).

## Отличия от оригинального `install.cmd`

Оригинальный `install.cmd` из папки `russian/` предназначен для Windows и оригинального `Morrowind.exe`.  
Linux-версия:

- **Не использует IPS-патчи** (`Morrowind.ips`, `Text.ips`) — они изменяют оригинальный `Morrowind.exe`, что не нужно для OpenMW
- **Не использует MCP** (Morrowind Code Patch) — он тоже для оригинального исполняемого файла
- **Не использует `softclub_patch`** — он только для русской версии от 1С; для Steam-версии не нужен
- **Не требует Wine/Proton** — всё делается нативными Linux-утилитами (`tar`, `cp`, `touch`)
- **Извлекает только `Data Files/`** из архива — не перезаписывает ESM/BSA/EXE-файлы Steam-версии