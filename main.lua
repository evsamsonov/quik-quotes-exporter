local QuikQuotesExporter = require('src/quik_quotes_exporter')
local QuikMessage = require('src/quik_message')

local config = require('config')

local quikQuotesExporter
function main()
    local status, callError = pcall(function()
        quikQuotesExporter = QuikQuotesExporter:new(config)
        quikQuotesExporter:run()
    end)
    if status == false then
        QuikMessage.show('QuikQuotesProvider: ' .. callError, QuikMessage.QUIK_MESSAGE_ERROR)
    end
end

function OnStop()
    if quikQuotesExporter then
        quikQuotesExporter:stop()
    end
end
