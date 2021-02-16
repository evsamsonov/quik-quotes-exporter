# Экспортер котировок из QUIK

Скрипт на Lua позволяет экспортировать свечи и тики из терминала QUIK по группе инструментов. Отправляет данные по протоколу JSON-RPC через [jsonrpc-fsproxy](https://github.com/evsamsonov/jsonrpc-fsproxy)

## Как запустить 

- Переименовать `config.lua.dist` в `config.lua`
- Запустить jsonrpc-fsproxy с указанием корректного адреса JSON-RPC сервера и файлов обмена данными
- Открыть в терминале QUIK окно Достпупные скрипты через меню Сервисы->Lua скрипты...
- Добавить файл main.lua 
- Выделить main.lua и нажать Запустить

## Конфигурация 

```lua
local QuikQuotesExporter = require('src/quik_quotes_exporter')
return {
    rpcClient = {
        -- INPUT_FILE_PATH заданный в jsonrpc-fsproxy 
        requestFilePath = 'Z:\\dev\\rpcin',  
        
        -- OUTPUT_FILE_PATH заданный в jsonrpc-fsproxy    
        responseFilePath = 'Z:\\dev\\rpcout',   
        
        -- Префикс идентификатора RPC запроса (по умолчанию пустая строка)
        idPrefix = 'qe'                         
    },
    instruments = {
        {
            -- Рынок. (!) Сейчас доступна только московская биржа  
            market = QuikQuotesExporter.MOSCOW_EXCHANGE_MARKET,    
            
            -- Код класса 
            classCode = 'TQBR',                                    
            
            -- Инструмент
            secCode = 'SBER',     
            
            -- Интервал. Сейчас доступен только часовой                              
            interval = INTERVAL_H1,                                
        }
    },
    
    -- Часы работы скрита. Необязательный параметр. Если не задан, то время неограничено
    workingHours = {
        start = 10,
        finish = 23,
    }
}
```

## Описание сервера

JSON-RPC сервер должен реализовывать следующие методы

## Известные проблемы
Сброс данных на диск

## Задачи
Тесты
Пример сервера
Блокировка файла


