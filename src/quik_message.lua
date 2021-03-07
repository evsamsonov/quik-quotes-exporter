local QuikMessage = {
    -- Типы отображаемой иконки в сообщении терминала QUIK
    -- @see http://www.luaq.ru/message.html
    QUIK_MESSAGE_INFO = 1,
    QUIK_MESSAGE_WARNING = 2,
    QUIK_MESSAGE_ERROR = 3
}

QuikMessage.show = function(text, icon)
    if icon == nil then
        icon = QuikMessage.QUIK_MESSAGE_INFO
    end
    message(text, icon)
end

return QuikMessage
