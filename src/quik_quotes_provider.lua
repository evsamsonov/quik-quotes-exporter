--

local QuikQuotesProvider = {}
function QuikQuotesProvider:new(params)
    local this = {}

    --[[
        Создает источник данных

        @see https://quikluacsharp.ru/quik-qlua/poluchenie-v-qlua-lua-dannyh-iz-grafikov-i-indikatorov/
        @see https://quikluacsharp.ru/qlua-osnovy/spisok-konstant-tajm-frejmov-grafikov/

        @param string classCode     Код класса (например, SPBFUT)
        @param string instrument    Код бумаги (например, SRU0)
        @param interval             Интервал (например, INTERVAL_H1)

        @return DataSource
    --]]
    local function createDataSource(classCode, secCode, interval)
        local ds, err = CreateDataSource(classCode, secCode, interval);

        -- Ждем, пока загрузятся данные
        -- https://quikluacsharp.ru/quik-qlua/poluchenie-v-qlua-lua-dannyh-iz-grafikov-i-indikatorov/
        while (err == "" or err == nil) and ds:Size() == 0 do
            sleep(100)
        end
        if ds == nil then
            message(
                'QuikQuotesProvider: Failed to create data source for '
                .. classCode .. ", " .. secCode .. ", " .. interval .. ": " .. err
            )
            do return false end
        end
        return ds
    end

    local function init()
        -- Перебираем все переданные инструменты и создаем дата соурсы
    end


    function this:run()
        init()
        -- todo создаем график инструментов и отправляем периодически текущюю свечу и предыдущую (сколько раз???)
        -- todo подписываемся на таблицу с обезличенными сделками и сохраняем данные (на каждый тик или буферизируем??)
    end

    setmetatable(this, self)
    self.__index = self
    return this
end

return QuikQuotesProvider