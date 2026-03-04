-- src/utils/message_box.lua
-- Convenience helper for launching Win98-styled message box dialogs

local MessageBox = {}

local _eventBus = nil

function MessageBox.init(di)
    _eventBus = di and di.eventBus
end

function MessageBox.show(params)
    if not _eventBus then
        print("ERROR [MessageBox]: EventBus not initialized. Call MessageBox.init(di) first.")
        return
    end
    _eventBus:publish('launch_program', 'message_box', params)
end

function MessageBox.info(title, message)
    MessageBox.show({
        title = title or "Information",
        message = message or "",
        icon_type = "info",
        buttons = {"OK"},
    })
end

function MessageBox.error(title, message)
    MessageBox.show({
        title = title or "Error",
        message = message or "",
        icon_type = "error",
        buttons = {"OK"},
    })
end

function MessageBox.warning(title, message)
    MessageBox.show({
        title = title or "Warning",
        message = message or "",
        icon_type = "warning",
        buttons = {"OK"},
    })
end

function MessageBox.confirm(title, message, buttons, on_button)
    MessageBox.show({
        title = title or "Confirm",
        message = message or "",
        icon_type = "warning",
        buttons = buttons or {"OK", "Cancel"},
        on_button = on_button,
    })
end

return MessageBox
