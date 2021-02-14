local QuikQuotesExporter = require('src/quik_quotes_exporter')

local config = require('config')

local quikQuotesExporter
function main()
    quikQuotesExporter = QuikQuotesExporter:new(config)
    quikQuotesExporter:run()
end

function OnStop()
    if quikQuotesExporter then
        quikQuotesExporter:stop()
    end
end
