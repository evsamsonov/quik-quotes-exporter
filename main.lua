local QuikQuotesProvider = require('src/quik_quotes_provider')
local QuikMessage = require('src/quik_message')

local quikQuotesProvider
function main()
    local status, callError = pcall(function()
        quikQuotesProvider = QuikQuotesProvider:new({
            rpcClient = {
                requestFilePath = 'Z:\\dev\\rpcin',
                responseFilePath = 'Z:\\dev\\rpcout',
                prefix = 'quotes-exporter'
            },
            instruments = {
                {
                    market = QuikQuotesProvider.MOSCOW_EXCHANGE_MARKET,
                    classCode = 'TQBR',
                    secCode = 'SBER',
                    interval = INTERVAL_H1,
                }
            }

        })
        quikQuotesProvider:run()
    end)
    if status == false then
        QuikMessage.show('QuikQuotesProvider: ' .. callError, QuikMessage.QUIK_MESSAGE_ERROR)
    end
end

function OnStop()
    if quikQuotesProvider then
        quikQuotesProvider:stop()
    end
end
