local QuikQuotesProvider = require('src/quik_quotes_provider')

local quikQuotesProvider
function main()
    quikQuotesProvider = QuikQuotesProvider:new({
        instruments = {
            {
                classCode = 'TQBR',
                secCode = 'SBER111',
                interval = INTERVAL_H1,
            }
        }

    })
    quikQuotesProvider:run()
end

-- На получение статуса транзакции
--function OnTransReply(transactionReply)
--    if quikDealer then
--        quikDealer:onTransactionReply(transactionReply)
--    end
--end
