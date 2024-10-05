local onDutyPlayers = {}
local dutyStartTime = {}
local onDutyBlips = {}

local WEBHOOK_URL = Config.WEBHOOK_URL

function GetPlayerDiscordID(player)
    for _, identifier in ipairs(GetPlayerIdentifiers(player)) do
        if identifier:match("discord") then
            return identifier:gsub("discord:", "")
        end
    end
    return nil
end

RegisterCommand('clockin', function(source, args)
    local player = tonumber(source)
    local department = args[1] and args[1]:lower()
    local callsign = args[2]

    if not department or not callsign then
        Config.Notify(source, 'Usage: /clockin [department] [callsign]', 'error')
        return
    end

    if not Config.AllowedDepartments then
        print("Error: AllowedDepartments is nil")
        return
    end

    local departmentConfig = nil
    for _, dept in ipairs(Config.AllowedDepartments) do
        if dept.name:lower() == department then
            departmentConfig = dept
            break
        end
    end

    if not departmentConfig then
        Config.Notify(source, 'Invalid department. Allowed departments: ' .. table.concat(Config.AllowedDepartments, ', '), 'error')
        return
    end

    if IsPlayerAceAllowed(player, departmentConfig.permissions.ClockIn) then
        if onDutyPlayers[player] then
            Config.Notify(source, 'You are already on duty.', 'error')
            return
        end

        onDutyPlayers[player] = { department = department, callsign = callsign }
        dutyStartTime[player] = os.time()
        TriggerClientEvent('createDutyBlip', player, department, callsign)
        onDutyBlips[player] = true

        local playerName = GetPlayerName(player)
        local discordID = GetPlayerDiscordID(player)
        local embed = {
            title = ':green_circle: Clock-In Notification',
            description = string.format('**%s** (Callsign: %s) has clocked in.\n\n**Player ID:** %d\n**Discord:** <@%s>', playerName, callsign, player, discordID),
            color = 65280,
            fields = {
                { name = 'Department', value = departmentConfig.displayName, inline = true },
                { name = 'Callsign', value = callsign, inline = true },
                { name = 'Clock-In Time', value = string.format('<t:%d:t>', os.time()), inline = true }
            },
            footer = { text = 'Duty System' }
        }

        PerformHttpRequest(WEBHOOK_URL, function() end, 'POST', json.encode({ embeds = { embed } }), { ['Content-Type'] = 'application/json' })
        Config.Notify(source, 'You have clocked in as ' .. departmentConfig.displayName .. ' (Callsign: ' .. callsign .. ').', 'success')
    else
        Config.Notify(source, 'You do not have permission to use this command.', 'error')
    end
end, false)

RegisterCommand('911', function(source, args)
    local player = tonumber(source)
    local reason = table.concat(args, ' ')
    local coords = GetEntityCoords(GetPlayerPed(player))
    local nearestPostal = getNearestPostal(coords)

    if reason == '' then
        Config.Notify(source, 'Usage: /911 [reason]', 'error')
        return
    end

    for clockedInPlayer in pairs(onDutyPlayers) do
        Config.Notify(clockedInPlayer, '911 Call: ' .. reason .. ' | Postal: ' .. nearestPostal, 'info')

        local playerName = GetPlayerName(player)
        local timestamp = os.date('%Y-%m-%d %H:%M:%S')

        local embed = {
            title = ':rotating_light: 911 Call Notification',
            description = string.format(
                '**%s** has reported an emergency.\n\n**Reason:** %s\n**Nearest Postal:** %s',
                playerName,
                reason,
                nearestPostal
            ),
            color = 16711680,
            fields = {
                { name = 'Reported By', value = playerName, inline = true },
                { name = 'Time', value = timestamp, inline = true },
            },
            footer = { text = 'Your Server Name - Logged by FiveM Server' }
        }
        PerformHttpRequest(WEBHOOK_URL, function() end, 'POST', json.encode({ embeds = { embed } }), { ['Content-Type'] = 'application/json' })
    end
end, false)

RegisterCommand('dutytime', function(source)
    local player = tonumber(source)

    if onDutyPlayers[player] then
        local startTime = dutyStartTime[player]
        local currentTime = os.time()
        local elapsedTime = currentTime - startTime

        local timeString = FormatDuration(elapsedTime)
        Config.Notify(source, 'You have been on duty for ' .. timeString .. '.', 'info')
    else
        Config.Notify(source, 'You are not on duty.', 'error')
    end
end, false)

RegisterCommand('clockout', function(source)
    local player = tonumber(source)

    if onDutyPlayers[player] then
        local playerDetails = onDutyPlayers[player]
        local startTime = dutyStartTime[player]
        local currentTime = os.time()
        local durationSeconds = currentTime - startTime
        local durationFormatted = FormatDuration(durationSeconds)

        onDutyPlayers[player] = nil
        dutyStartTime[player] = nil

        TriggerClientEvent('removeDutyBlip', player)
        onDutyBlips[player] = nil

        local playerName = GetPlayerName(player)
        local discordID = GetPlayerDiscordID(player)
        local department = playerDetails.department or "Unknown"
        local callsign = playerDetails.callsign or "Unknown"
        local timestamp = os.date('%Y-%m-%d %H:%M:%S')
        local discordTimestamp = math.floor(os.time())

        Config.Notify(source, 'You have clocked out. Duration: ' .. durationFormatted, 'success')

        local embed = {
            title = ':red_circle: Clock-Out Notification',
            description = string.format(
                '**%s** (Callsign: %s) has clocked out.\n\n**Duration:** %s\n**Player ID:** %d\n**Discord:** <@%s>',
                playerName,
                callsign,
                durationFormatted,
                player,
                discordID
            ),
            color = 16711680,
            fields = {
                { name = 'Player Name:', value = playerName, inline = true },
                { name = 'User ID:', value = discordID, inline = true },
                { name = 'Department:', value = department, inline = true },
                { name = 'Callsign:', value = callsign, inline = true },
                { name = 'Clock-Out Time:', value = string.format('<t:%d:t>', discordTimestamp), inline = true }
            },
            footer = { text = 'Your Server Name - Logged by FiveM Server' }
        }
        PerformHttpRequest(WEBHOOK_URL, function() end, 'POST', json.encode({ embeds = { embed } }), { ['Content-Type'] = 'application/json' })
    else
        Config.Notify(source, 'You are not currently on duty.', 'error')
    end
end, false)

RegisterCommand('kickoffduty', function(source, args)
    local player = tonumber(source)
    local targetPlayerID = tonumber(args[1])

    if not targetPlayerID then
        Config.Notify(source, 'Usage: /kickoffduty [targetPlayerID]', 'error')
        return
    end

    if not IsPlayerAceAllowed(player, Config.KickAce) then
        Config.Notify(source, 'You do not have permission to use this command.', 'error')
        return
    end

    if not GetPlayerName(targetPlayerID) then
        Config.Notify(source, 'The specified player (ID: ' .. targetPlayerID .. ') is not online or does not exist.', 'error')
        return
    end

    if onDutyPlayers[targetPlayerID] then
        onDutyPlayers[targetPlayerID] = nil
        dutyStartTime[targetPlayerID] = nil

        local playerName = GetPlayerName(targetPlayerID)
        local kickedByName = GetPlayerName(player)
        local discordID = GetPlayerDiscordID(targetPlayerID)
        local timestamp = os.date('%Y-%m-%d %H:%M:%S')

        Config.Notify(source, playerName .. ' has been kicked off duty.', 'info')

        local embed = {
            title = ':warning: Duty Kick Notification',
            description = string.format(
                '**%s** has kicked off **%s** from duty.\n\n**Player ID:** %d\n**Discord:** <@%s>',
                kickedByName,
                playerName,
                targetPlayerID,
                discordID
            ),
            color = 16711680,
            fields = {
                { name = 'Kicked By:', value = kickedByName, inline = true },
                { name = 'Time:', value = timestamp, inline = true }
            },
            footer = { text = 'Your Server Name - Logged by FiveM Server' }
        }
        PerformHttpRequest(WEBHOOK_URL, function() end, 'POST', json.encode({ embeds = { embed } }), { ['Content-Type'] = 'application/json' })
    else
        Config.Notify(source, 'The specified player is not currently on duty.', 'error')
    end
end, false)

RegisterCommand('onduty', function(source)
    local player = source

    if IsPlayerAceAllowed(player, Config.ViewAce) then
        local message = '^6On-duty players:\n'

        for targetPlayerID, data in pairs(onDutyPlayers) do
            local playerName = GetPlayerName(targetPlayerID)
            local department = data.department
            local callsign = data.callsign
            local formattedLine = string.format('^7%s (%s, Call Sign %s) (ID: %d)\n', playerName, department, callsign, targetPlayerID)
            message = message .. formattedLine
        end

        TriggerClientEvent('chatMessage', player, message)
    else
        TriggerClientEvent('chatMessage', player, '^3You do not have permission to use this command.')
    end
end, false)

AddEventHandler('playerDropped', function(reason)
    local player = source

    if onDutyPlayers[player] then
        local playerName = GetPlayerName(player)
        local department = onDutyPlayers[player].department
        local callsign = onDutyPlayers[player].callsign
        local discordID = GetPlayerDiscordID(player)

        local dutyTime = os.time() - (dutyStartTime[player] or os.time())

        TriggerClientEvent('removeDutyBlip', player)
        onDutyBlips[player] = nil

        onDutyPlayers[player] = nil
        dutyStartTime[player] = nil

        local embed = {
            title = ':red_circle: Automatic Clock-Out',
            description = string.format('**Officer**: %s\n\n**Department**: %s\n\n**Callsign**: %s has automatically clocked out after disconnecting.\n\n**Duty Time**: %s (HH:MM:SS)\n\n**(<@%s>)**', playerName, department, callsign, FormatDuration(dutyTime), discordID),
            color = 16711680,
            footer = { text = 'Player ID: ' .. player .. ' | ' .. os.date('%Y-%m-%d %H:%M:%S') }
        }
        PerformHttpRequest(WEBHOOK_URL, function() end, 'POST', json.encode({ embeds = { embed } }), { ['Content-Type'] = 'application/json' })
    end
end)

function FormatDuration(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local remainingSeconds = seconds % 60
    return string.format('%02d:%02d:%02d', hours, minutes, remainingSeconds)
end

function IsPlayerOnDuty(player)
    return onDutyPlayers[player] ~= nil
end

exports('IsPlayerOnDuty', IsPlayerOnDuty)
