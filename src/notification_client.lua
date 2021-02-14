local NotificationClient = {}
function NotificationClient:new(params)
    local this = {}

    this.requiredParams = {
        'rpcClient'
    }
    function this:checkRequiredParams(params)
        for i, key in ipairs(this.requiredParams) do
            if params[key] == nil then
                error('Required param ' .. key .. ' not set')
            end
        end
    end
    this:checkRequiredParams(params)

    this.rpcClient = params.rpcClient

    --[[
        Отправляет оповещение

        @param string message
    --]]
    function this:notify(message)
        local response = this.rpcClient:sendRequest("Notification.Notify", {
            message = message
        })
        if response.error ~= nil then
            error('failed to notify: ' .. response.error.message)
        end
    end

    setmetatable(this, self)
    self.__index = self
    return this
end

return NotificationClient