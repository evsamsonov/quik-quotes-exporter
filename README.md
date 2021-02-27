# Экспортер котировок из торгового терминала QUIK

Экспортирует часовые свечи и обезличенные сделки из терминала QUIK по группе инструментов. Отправляет данные по протоколу [JSON-RPC 2.0](https://www.jsonrpc.org/specification) через [jsonrpc-fsproxy](https://github.com/evsamsonov/jsonrpc-fsproxy). Не требует установки дополнительных Lua библиотек. Есть функционал оповещения о возникающих в работе скрипта проблемах

## Описание

### Отправка свечей 

При запуске и в начале каждого часа отправляет информацию с последней доступной свечи на сервере до текущей.

### Отправка обезличенных сделок

После запуска единоразово отправляет все сделки, которые есть на данный момент в таблице обезличенных сделок. Подписывается на обновление по обезличенным сделкам и отправляет их пачкой раз в минуту. 

### Поведение при ошибках отправки данных

При проблемах с отправкой данных делает 3 попытки, если отправить запрос не удалось оповещает о проблеме. Продолжает работу и в следующем цикле пытается отправить запросы вновь.

## Как запустить 

- Переименовать `config.lua.dist` в `config.lua` и сконфигурировать
- Запустить [jsonrpc-fsproxy](https://github.com/evsamsonov/jsonrpc-fsproxy) с указанием корректного адреса JSON-RPC сервера и файлов обмена данными
- Открыть в терминале QUIK окно "Доступные скрипты" (в главном меню перейти в "Сервисы" и выбрать "Lua скрипты...")
- Добавить файл main.lua и запустить

## Конфигурация 

```lua
local QuikQuotesExporter = require('src/quik_quotes_exporter')
return {
    rpcClient = {
        -- Файл для отправки запроса. 
        -- Переменная окружения INPUT_FILE_PATH, заданная при запуске jsonrpc-fsproxy. 
        requestFilePath = 'Z:\\dev\\rpcin',  
        
        -- Файл для получения ответа.
        -- Переменная окружения OUTPUT_FILE_PATH, заданная при запуске jsonrpc-fsproxy. 
        responseFilePath = 'Z:\\dev\\rpcout',   
        
        -- Префикс идентификатора RPC запроса (по умолчанию пустая строка). 
        -- Требуется только в случае, когда указанные выше файлы используются 
        -- для работы других скриптов, чтобы различать ответы сервера.
        idPrefix = 'qe'                         
    },
    instruments = {
        {
            -- Идентфикатор биржи. 
            -- Требуется для разделения по биржам на стороне сервера.
            market = QuikQuotesExporter.MOSCOW_EXCHANGE_MARKET,    
            
            -- Идентификатор режима торгов и код ценной бумаги.
            -- Можно найти на странице конкретного торгового инструмента 
            -- на сайте Московской биржи или в таблице котировок QUIK (параметр "Код класса").
            classCode = 'TQBR',                                    
            secCode = 'SBER',     
            
            -- Интервал. Сейчас доступен только часовой                              
            interval = INTERVAL_H1,                                
        }
    },
    -- Часы работы скрипта (включительно). 
    -- Если не задан, то время работы неограничено.
    workingHours = {
        start = 10,
        finish = 23,
    }
}
```

## Описание сервера

JSON-RPC сервер для корректной работы скрипта должен реализовывать следующие методы:

Метод  | Описание 
------------- | -------------
[Quotes.GetLastCandle](#quotesgetlastcandle) | Получение последней известной свечи 
[Quotes.AddCandle](#quotesaddcandle) | Добавление свечи
[Quotes.AddTicks](#quotesaddticks) | Добавлене обезличенных сделок 
[Notification.Notify](#notificationnotify) | Оповещение

### Quotes.GetLastCandle 

Используется для получения последней известной свечи. Если свечей по указанному инструменту нет, то должен возвращать `null`

**Параметры**

Ключ  | Описание 
------------- | -------------
market  | Рынок. Значение заданное при конфигурации инструмента `instruments.*.market`
symbol  | Код ценной бумаги. Значение заданное при конфигурации инструмента `instruments.*.secCode`
interval  | Интервал. Значение заданное при конфигурации инструмента `instruments.*.interval`

**Запрос:**
```json
{
   "jsonrpc": "2.0",
   "method": "Quotes.GetLastCandle",
   "params": {
      "market": 1,
      "symbol": "SBER",
      "interval": 7
   },
   "id":"1"
}
```

```shell script
curl -H "Content-Type: application/json" -X POST -d  '{"jsonrpc": "2.0", "method": "Quotes.GetLastCandle", "params":{"market":1, "symbol":"SBER", "period": 7}, "id": "1"}'  http://127.0.0.1:8080/rpc
```

**Ответ:**
```json
{
   "jsonrpc": "2.0",
   "id": "1",
   "result": {
      "time": 1613340425,
      "open": 270.1,
      "close": 275.01,
      "high": 276,
      "low": 269.5,
      "volume": 320750
    }
}
```

### Quotes.AddCandle

Используется для отправки данных по свечам. Данные по известным серверу свечам должны перезаписываться. 

**Параметры**

Ключ  | Описание 
------------- | -------------
market  | Рынок. Значение заданное при конфигурации инструмента `instruments.*.market`
symbol  | Код ценной бумаги. Значение заданное при конфигурации инструмента `instruments.*.secCode`
interval  | Интервал. Значение заданное при конфигурации инструмента `instruments.*.interval`
candle  | Свеча
candle.time  | Время в Unix time
candle.open  | Открытие
candle.close  | Закрытие 
candle.high  | Максимум
candle.low  | Минимум
candle.volume  | Объем в акциях??? todo!!!

**Запрос:**
```json
{
   "jsonrpc": "2.0",
   "method": "Quotes.AddCandle",
   "params": {
      "market": 1,
      "symbol": "SBER",
      "period": 7,
      "candle":{
         "time": 1613340425,
         "open": 270.1,
         "close": 275.01,
         "high": 276,
         "low": 269.5,
         "volume": 320750
      }
   },
   "id": "1"
}
```

```bash
curl -H "Content-Type: application/json" -X POST -d  '{"jsonrpc": "2.0", "method": "Quotes.AddCandle", "params":{"market":1, "symbol":"SBER", "period": 7, "candle":{"time": 1613340425, "open": 270.1, "close": 275.01, "high": 276, "low": 269.5, "volume": 320750}}, "id": "1"}'  http://127.0.0.1:8080/rpc
```

**Ответ:**
```json
{
   "jsonrpc": "2.0",
   "id": "1",
   "result": {}
}
```

### Quotes.AddTicks

Используется для отправки данных по обезличенным сделками. Данные по известным сделкам должны игнорироваться или перезаписываться.

**Параметры**

Ключ  | Описание 
------------- | -------------
market  | Рынок. Значение заданное при конфигурации инструмента `instruments.*.market`
symbol  | Код ценной бумаги. Значение заданное при конфигурации инструмента `instruments.*.secCode`
ticks  | Список с обезличенными сделками
ticks[].id  | Идентификатор сделки
ticks[].time  | Время в Unix time
ticks[].price  | Цена 
ticks[].volume  | Объем в акциях
ticks[].operation  | Тип. Одно из двух значений: 1 - покупка, 2 - продажа

**Запрос:**
```json
{
   "jsonrpc": "2.0",
   "method": "Quotes.AddTicks",
   "params": {
      "market": 1,
      "symbol": "SBER",
      "ticks":[
         {
            "id": 2683497839,
            "time": 1613340425,
            "price": 162.41,
            "volume": 10,     
            "operation": 2
         }
      ]
   },
   "id": "1"
}
```

```bash
curl -H "Content-Type: application/json" -X POST -d  '{"jsonrpc": "2.0", "method": "Quotes.AddTicks", "params":{"market":1, "symbol":"SBER", "ticks": [{"id": 2683497839, "time": 1613340425, "price": 162.41, "volume": 10, "operation":2}]}, "id": "1"}'  http://127.0.0.1:8080/rpc
```

Ответ:
```json
{
   "jsonrpc": "2.0",
   "id": "1",
   "result": {}
}
```


### Notification.Notify

Используется для оповещения о запуске и возникающих ошибках в работе скрипта

**Запрос:**
```json
{
    "jsonrpc": "2.0",
    "method": "Notification.Notify",
    "params": {
        "message": "2021-02-22 10:09:57: QuikQuotesExporter has been started successfully"
    },
    "id": "1"
}
```

```bash
curl -H "Content-Type: application/json" -X POST -d  '{"jsonrpc": "2.0", "method": "Notification.Notify", "params":{"message":"2021-02-22 10:09:57: QuikQuotesExporter has been started successfully"}, "id": "1"}'  http://127.0.0.1:8080/rpc```
```

**Ответ:**
```json
{
   "jsonrpc": "2.0",
   "id": "1",
   "result": {}
}
```

## Замечание

Для работы с обезличенными сделками требуется заказать их у брокера. По умолчанию QUIK не загружает их. Убедитесь, что обезличенные сделки подгружаются, создав таблицу обезличенных сделок и выбрав необходимые инструменты.

## Задачи
- Добавить другие интервалы
- Реализовать пример принимающего данные сервера

