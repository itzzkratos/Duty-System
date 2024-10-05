local dutyBlips = {}

CreateThread(function()
    TriggerEvent('chat:addSuggestion', '/clockin', 'Go on duty as your department', {{ name="department", help="The Department example: BCSO"}, { name="callsign", help="Your Assigned Callsign example: 1X-01"}})
    TriggerEvent('chat:addSuggestion', '/clockout', 'Go on duty as your department')
end)

RegisterNetEvent('createDutyBlip')
AddEventHandler('createDutyBlip', function(department, badgeNumber, callsign)
    local playerPed = PlayerPedId()
    local blip = AddBlipForEntity(playerPed)
    
    SetBlipSprite(blip, 1)
    SetBlipColour(blip, 3)
    SetBlipScale(blip, 1.0)
    SetBlipAsShortRange(blip, true)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(department .. " (" .. callsign .. ", Badge " .. badgeNumber .. ")")
    EndTextCommandSetBlipName(blip)

    dutyBlips[PlayerId()] = blip
end)

RegisterNetEvent('removeDutyBlip')
AddEventHandler('removeDutyBlip', function()
    local blip = dutyBlips[PlayerId()]
    if blip then
        RemoveBlip(blip)
        dutyBlips[PlayerId()] = nil
    end
end)
