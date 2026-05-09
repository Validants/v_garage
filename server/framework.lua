FW = {}
FW.Name = nil
FW.Object = nil

CreateThread(function()
    if Config.Framework == 'auto' then
        if GetResourceState('qb-core') == 'started' then
            FW.Name = 'qbcore'
            FW.Object = exports['qb-core']:GetCoreObject()
        elseif GetResourceState('es_extended') == 'started' then
            FW.Name = 'esx'
            FW.Object = exports['es_extended']:getSharedObject()
        end
    elseif Config.Framework == 'qbcore' then
        FW.Name = 'qbcore'
        FW.Object = exports['qb-core']:GetCoreObject()
    elseif Config.Framework == 'esx' then
        FW.Name = 'esx'
        FW.Object = exports['es_extended']:getSharedObject()
    end

    print(('[ug_garage] Framework: %s'):format(FW.Name or 'not found'))
end)

function FW.GetIdentifier(src)
    if FW.Name == 'esx' then
        local xPlayer = FW.Object.GetPlayerFromId(src)
        return xPlayer and xPlayer.identifier
    elseif FW.Name == 'qbcore' then
        local Player = FW.Object.Functions.GetPlayer(src)
        return Player and Player.PlayerData.citizenid
    end
end

function FW.GetJob(src)
    if FW.Name == 'esx' then
        local xPlayer = FW.Object.GetPlayerFromId(src)
        return xPlayer and xPlayer.job and xPlayer.job.name or nil
    elseif FW.Name == 'qbcore' then
        local Player = FW.Object.Functions.GetPlayer(src)
        return Player and Player.PlayerData.job and Player.PlayerData.job.name or nil
    end
end

function FW.IsAdmin(src)
    if src == 0 then return true end

    if FW.Name == 'esx' then
        local xPlayer = FW.Object.GetPlayerFromId(src)
        if not xPlayer then return false end
        local group = xPlayer.getGroup and xPlayer.getGroup() or nil
        for _, allowed in ipairs(Config.AdminGroups.esx) do
            if group == allowed then return true end
        end
    elseif FW.Name == 'qbcore' then
        for _, perm in ipairs(Config.AdminGroups.qbcore) do
            if FW.Object.Functions.HasPermission(src, perm) then return true end
        end
    end

    return IsPlayerAceAllowed(src, 'ug_garage.admin')
end

function FW.RemoveMoney(src, amount, reason)
    amount = tonumber(amount) or 0
    if amount <= 0 then return true end
    reason = reason or 'Garage Impound'

    if FW.Name == 'esx' then
        local xPlayer = FW.Object.GetPlayerFromId(src)
        if not xPlayer then return false end
        local money = xPlayer.getMoney and xPlayer.getMoney() or 0
        if money < amount then return false end
        xPlayer.removeMoney(amount)
        return true
    elseif FW.Name == 'qbcore' then
        local Player = FW.Object.Functions.GetPlayer(src)
        if not Player then return false end
        local cash = Player.PlayerData.money and Player.PlayerData.money.cash or 0
        local bank = Player.PlayerData.money and Player.PlayerData.money.bank or 0
        if cash >= amount then
            Player.Functions.RemoveMoney('cash', amount, reason)
            return true
        elseif bank >= amount then
            Player.Functions.RemoveMoney('bank', amount, reason)
            return true
        end
        return false
    end

    return false
end
