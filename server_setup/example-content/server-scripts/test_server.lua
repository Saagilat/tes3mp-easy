-- test_server.lua
-- Пример серверного скрипта для проверки интеграции.
-- При подключении игрока отправляет сообщение в чат.
--
-- Удалите этот файл, если он не нужен.

local function onPlayerConnect(es, pid)
    tes3mp.SendMessage(pid, "Server scripts are working.\n", true)
    return es
end

customEventHooks.registerHandler("OnPlayerConnect", onPlayerConnect)