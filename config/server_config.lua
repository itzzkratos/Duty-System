Config = {}

Config.AllowedDepartments = {
    {
        name = "Test",
        displayName = "Test",
        permissions = {
            View = "test.duty",
            Kick = "test.duty",
            ClockIn = "test.duty"
        }
    }
}

Config.WEBHOOK_URL = ""  -- Add your webhook URL here

Config.Notify = function(source, message, type)
    -- you can edit this to whatever you want, by default it uses ox_lib notifications
    TriggerClientEvent("ox_lib:notify", source, {
        description = message,
        title = 'Duty System',
        type = type,
        position = 'center-right',
    })
end

return Config
