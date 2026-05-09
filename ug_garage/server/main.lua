local Garages = {}
local GaragesLoaded = false
local pendingSpawns = {}
local spawnedJobVehicles = {}
local outsideVehiclePlates = {}
local lastOutsideVehicleCheck = 0

local _L = _G._L or (UG and (UG.L or UG.Translate)) or function(key, ...)
    local locale = tostring(Config and Config.Locale or 'de'):lower()
    local lang = Locales and (Locales[locale] or Locales.de) or nil
    local text = (lang and lang[key]) or (Locales and Locales.de and Locales.de[key]) or key
    local args = { ... }
    if #args > 0 then
        local unpackFn = table.unpack or unpack
        local ok, formatted = pcall(string.format, text, unpackFn(args))
        if ok then return formatted end
    end
    return text
end

local function normalizeVehicleType(value)
    value = tostring(value or (Config.VehicleTypes and Config.VehicleTypes.default) or 'car'):lower()
    if value ~= 'car' and value ~= 'air' and value ~= 'boat' then value = 'car' end
    return value
end

local function mergeConfigGarages()
    for id, g in pairs(Config.Garages or {}) do
        Garages[id] = {
            id = g.id or id,
            label = g.label or id,
            type = g.type or 'public',
            job = g.job,
            coords = { x = g.coords.x, y = g.coords.y, z = g.coords.z },
            store = g.store and { x = g.store.x, y = g.store.y, z = g.store.z, w = g.store.w } or { x = g.coords.x, y = g.coords.y, z = g.coords.z, w = g.coords.w or 0.0 },
            spawn = { x = g.spawn.x, y = g.spawn.y, z = g.spawn.z, w = g.spawn.w },
            blip = g.blip ~= false,
            vehicleType = normalizeVehicleType(g.vehicleType or g.vehicle_type)
        }
    end
end

local function loadGarages()
    GaragesLoaded = false
    Garages = {}
    mergeConfigGarages()
    local rows = MySQL.query.await('SELECT * FROM ug_garages') or {}
    for _, row in ipairs(rows) do
        Garages[row.id] = {
            id = row.id,
            label = row.label,
            type = row.type,
            job = row.job,
            coords = json.decode(row.coords),
            store = row.store and json.decode(row.store) or json.decode(row.coords),
            spawn = json.decode(row.spawn),
            blip = row.blip == 1,
            vehicleType = normalizeVehicleType(row.vehicle_type)
        }
    end
    GaragesLoaded = true
end

local function getVisibleGarages(src)
    local job = FW.GetJob(src)
    local visible = {}
    for id, g in pairs(Garages) do
        if g.type == 'public' or (g.type == 'job' and g.job == job) or (Config.AdminSeeJobGaragesInWorld and FW.IsAdmin(src)) then
            visible[id] = g
        end
    end
    return visible
end

local function vehicleCfg()
    return Config.VehicleTables[FW.Name]
end

local function resolveVehicleClass(model)
    if not model then return nil end
    if type(model) == 'string' then
        local n = tonumber(model)
        model = n or joaat(model)
    end
    if type(GetVehicleClassFromName) ~= 'function' then return nil end
    local ok, class = pcall(GetVehicleClassFromName, model)
    if ok then return class end
    return nil
end

local function matchesGarageVehicleType(model, vehicleType)
    vehicleType = normalizeVehicleType(vehicleType)
    local class = resolveVehicleClass(model)
    if not class then return true end -- Add-on/unknown models stay visible instead of disappearing incorrectly.
    local vt = Config.VehicleTypes or {}
    local boat = (vt.boatClasses or {})[class] == true
    local air = (vt.airClasses or {})[class] == true
    if vehicleType == 'boat' then return boat end
    if vehicleType == 'air' then return air end
    return not boat and not air
end


local function scanOutsideVehicles()
    local found = {}

    if type(GetAllVehicles) ~= 'function' then
        print('[ug_garage] GetAllVehicles ist serverseitig nicht verfügbar. Impound-Check nutzt Fallback ohne Live-Erkennung.')
        outsideVehiclePlates = found
        lastOutsideVehicleCheck = os.time()
        return found
    end

    local vehicles = GetAllVehicles()
    for _, vehicle in ipairs(vehicles or {}) do
        if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
            local plate = UG.TrimPlate(GetVehicleNumberPlateText(vehicle))
            if plate and plate ~= '' then
                found[plate] = true
            end
        end
    end

    outsideVehiclePlates = found
    lastOutsideVehicleCheck = os.time()
    return found
end

local function isPlateOutside(plate)
    plate = UG.TrimPlate(plate)
    if not plate or plate == '' then return false end
    return outsideVehiclePlates[plate] == true
end

local function markPlateOutside(plate)
    plate = UG.TrimPlate(plate)
    if not plate or plate == '' then return end
    outsideVehiclePlates[plate] = true
    lastOutsideVehicleCheck = os.time()
end

local function unmarkPlateOutside(plate)
    plate = UG.TrimPlate(plate)
    if not plate or plate == '' then return end
    outsideVehiclePlates[plate] = nil
end

local function getOwnedVehicles(src, garageId)
    local identifier = FW.GetIdentifier(src)
    local cfg = vehicleCfg()
    if not identifier or not cfg then return {} end

    local listing = Config.VehicleListing or {}
    local where = { ('`%s` = ?'):format(cfg.owner) }
    local params = { identifier }

    if listing.onlyCurrentGarage then
        where[#where + 1] = ('(`%s` = ? OR `%s` IS NULL OR `%s` = "")'):format(cfg.garage, cfg.garage, cfg.garage)
        params[#params + 1] = garageId
    end

    if listing.showOutVehicles == false then
        where[#where + 1] = ('`%s` = ?'):format(cfg.stored)
        params[#params + 1] = Config.State.stored
    end

    local sql = ('SELECT * FROM `%s` WHERE %s'):format(cfg.table, table.concat(where, ' AND '))
    local rows = MySQL.query.await(sql, params) or {}
    local vehicles = {}

    for _, row in ipairs(rows) do
        local props = {}
        if row[cfg.vehicle] and row[cfg.vehicle] ~= '' then
            props = json.decode(row[cfg.vehicle]) or {}
        end

        local model = props.model or row[cfg.model] or 'unknown'
        local g = Garages[garageId]
        if not matchesGarageVehicleType(model, g and g.vehicleType or nil) then
            goto continue_owned_vehicle
        end

        vehicles[#vehicles + 1] = {
            plate = UG.TrimPlate(row[cfg.plate]),
            model = model,
            props = props,
            stored = tonumber(row[cfg.stored] or Config.State.stored) == Config.State.stored,
            garage = row[cfg.garage] or garageId,
            state = row[cfg.stored],
            fuel = row.fuel or row.fuelLevel or row.fuel_level or props.fuelLevel or props.fuel,
            engineHealth = row.engine or row.engineHealth or row.engine_health or props.engineHealth,
            bodyHealth = row.body or row.bodyHealth or row.body_health or props.bodyHealth,
            mileage = row.mileage or row.drivingdistance or row.distance or row.odometer,
            depotPrice = row.depotprice or row.depotPrice,
            paymentAmount = row.paymentamount or row.paymentAmount,
            balance = row.balance
        }
        ::continue_owned_vehicle::
    end

    return vehicles
end

local function getImpoundVehicles(src, garageId)
    local identifier = FW.GetIdentifier(src)
    local cfg = vehicleCfg()
    if not identifier or not cfg then return {} end

    local g = Garages[garageId]
    local sql = ('SELECT * FROM `%s` WHERE `%s` = ? AND `%s` = ?'):format(cfg.table, cfg.owner, cfg.stored)
    local rows = MySQL.query.await(sql, { identifier, Config.State.out }) or {}
    local vehicles = {}

    for _, row in ipairs(rows) do
        local props = {}
        if row[cfg.vehicle] and row[cfg.vehicle] ~= '' then
            props = json.decode(row[cfg.vehicle]) or {}
        end

        local plate = UG.TrimPlate(row[cfg.plate])
        if isPlateOutside(plate) then
            goto continue_impound_vehicle
        end

        local model = props.model or row[cfg.model] or 'unknown'
        if not matchesGarageVehicleType(model, g and g.vehicleType or nil) then
            goto continue_impound_vehicle
        end

        vehicles[#vehicles + 1] = {
            plate = plate,
            model = model,
            props = props,
            stored = false,
            impounded = true,
            garage = row[cfg.garage] or garageId,
            state = row[cfg.stored],
            fuel = row.fuel or row.fuelLevel or row.fuel_level or props.fuelLevel or props.fuel,
            engineHealth = row.engine or row.engineHealth or row.engine_health or props.engineHealth,
            bodyHealth = row.body or row.bodyHealth or row.body_health or props.bodyHealth,
            mileage = row.mileage or row.drivingdistance or row.distance or row.odometer,
            depotPrice = row.depotprice or row.depotPrice,
            paymentAmount = row.paymentamount or row.paymentAmount,
            balance = row.balance,
            impoundFee = (Config.Impound and Config.Impound.fee) or 0
        }
        ::continue_impound_vehicle::
    end

    return vehicles
end

local function ownsVehicle(src, plate)
    local identifier = FW.GetIdentifier(src)
    local cfg = vehicleCfg()
    if not identifier or not cfg then return false, nil end

    local sql = ('SELECT * FROM `%s` WHERE `%s` = ? AND `%s` = ? LIMIT 1'):format(cfg.table, cfg.owner, cfg.plate)
    local row = MySQL.single.await(sql, { identifier, plate })
    return row ~= nil, row
end

local function sanitizePlatePrefix(prefix)
    prefix = tostring(prefix or ''):upper():gsub('%s+', ''):gsub('[^A-Z0-9]', '')
    if prefix == '' then prefix = 'JOB' end
    return prefix:sub(1, 6)
end

local function getJobPlatePrefix(job)
    local cfg = Config.JobVehicles or {}
    local prefixes = cfg.platePrefixes or {}
    return sanitizePlatePrefix(prefixes[job] or cfg.platePrefix or 'JOB')
end

local function getGaragePlatePrefix(garageId, job)
    local cfg = Config.JobVehicles or {}
    local garagePrefixes = cfg.garagePlatePrefixes or {}
    return sanitizePlatePrefix(garagePrefixes[garageId] or getJobPlatePrefix(job))
end

local function plateHasPrefix(plate, prefix)
    plate = tostring(UG.TrimPlate(plate or '') or ''):upper():gsub('%s+', '')
    prefix = sanitizePlatePrefix(prefix)
    return plate:sub(1, #prefix) == prefix
end

local function plateHasJobPrefix(plate, job)
    return plateHasPrefix(plate, getJobPlatePrefix(job))
end

local function getEntityJobState(netId)
    netId = tonumber(netId or 0) or 0
    if netId <= 0 then return nil end
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil end
    local state = Entity(entity).state
    if state and state.ug_jobVehicle then
        return {
            garageId = state.ug_garageId,
            jobVehicleId = tonumber(state.ug_jobVehicleId),
            job = state.ug_job,
            plate = UG.TrimPlate(state.ug_plate or '')
        }
    end
    return nil
end

local function isValidJobVehicleForGarage(src, garageId, plate, netId)
    local g = Garages[garageId]
    if not g or g.type ~= 'job' then return false, _L('not_job_garage') end
    if g.job ~= FW.GetJob(src) then return false, _L('no_access_garage') end

    plate = UG.TrimPlate(plate or '')

    local state = getEntityJobState(netId)
    if state then
        if state.job ~= g.job then
            return false, 'Dieses Jobfahrzeug gehört nicht zu deinem Job.'
        end
        if state.garageId == garageId then
            return true
        end
        if plate ~= '' and (plateHasPrefix(plate, getGaragePlatePrefix(garageId, g.job)) or plateHasJobPrefix(plate, g.job)) then
            return true
        end
        return false, _L('job_vehicle_wrong_garage')
    end

    if plate ~= '' and (plateHasPrefix(plate, getGaragePlatePrefix(garageId, g.job)) or plateHasJobPrefix(plate, g.job)) then
        return true
    end

    return false, _L('job_vehicle_wrong_garage')
end


local function clampColor(value)
    value = tonumber(value) or 0
    if value < 0 then value = 0 end
    if value > 255 then value = 255 end
    return math.floor(value)
end

local function jobVehicleRows(garageId)
    local garage = Garages[garageId]
    local rows = MySQL.query.await('SELECT * FROM ug_job_vehicles WHERE garage_id = ? ORDER BY label ASC, model ASC', { garageId }) or {}
    local list = {}
    for _, row in ipairs(rows) do
        if not matchesGarageVehicleType(row.model, garage and garage.vehicleType or nil) then
            goto continue_job_vehicle
        end
        list[#list + 1] = {
            id = row.id,
            garageId = row.garage_id,
            label = row.label ~= '' and row.label or row.model,
            model = row.model,
            stored = true,
            isJobVehicle = true,
            jobVehicleId = row.id,
            garage = row.garage_id,
            fuel = 100,
            engineHealth = 1000,
            bodyHealth = 1000,
            color = {
                primary = { r = tonumber(row.primary_r) or 255, g = tonumber(row.primary_g) or 255, b = tonumber(row.primary_b) or 255 },
                secondary = { r = tonumber(row.secondary_r) or tonumber(row.primary_r) or 255, g = tonumber(row.secondary_g) or tonumber(row.primary_g) or 255, b = tonumber(row.secondary_b) or tonumber(row.primary_b) or 255 }
            },
            props = {
                model = row.model,
                fuelLevel = 100,
                engineHealth = 1000,
                bodyHealth = 1000,
                customPrimaryColor = { tonumber(row.primary_r) or 255, tonumber(row.primary_g) or 255, tonumber(row.primary_b) or 255 },
                customSecondaryColor = { tonumber(row.secondary_r) or tonumber(row.primary_r) or 255, tonumber(row.secondary_g) or tonumber(row.primary_g) or 255, tonumber(row.secondary_b) or tonumber(row.primary_b) or 255 }
            }
        }
        ::continue_job_vehicle::
    end
    return list
end

local function adminJobVehicles()
    local rows = MySQL.query.await('SELECT * FROM ug_job_vehicles ORDER BY garage_id ASC, label ASC, model ASC') or {}
    local list = {}
    for _, row in ipairs(rows) do
        list[#list + 1] = {
            id = row.id,
            garageId = row.garage_id,
            label = row.label,
            model = row.model,
            primary = { r = tonumber(row.primary_r) or 255, g = tonumber(row.primary_g) or 255, b = tonumber(row.primary_b) or 255 },
            secondary = { r = tonumber(row.secondary_r) or 255, g = tonumber(row.secondary_g) or 255, b = tonumber(row.secondary_b) or 255 }
        }
    end
    return list
end

RegisterNetEvent('ug_garage:server:requestGarages', function()
    local src = source

    CreateThread(function()
        local timeout = GetGameTimer() + 10000
        while not GaragesLoaded and GetGameTimer() < timeout do
            Wait(250)
        end

        if not GaragesLoaded then
            TriggerClientEvent('ug_garage:client:setGarages', src, {})
            return
        end

        TriggerClientEvent('ug_garage:client:setGarages', src, getVisibleGarages(src))
    end)
end)


lib.callback.register('ug_garage:canLockVehicle', function(src, plate)
    plate = UG.TrimPlate(plate or '')
    if plate == '' then return false end

    local ok = ownsVehicle(src, plate)
    if ok == true then return true end

    if plateHasJobPrefix(plate, FW.GetJob(src)) then
        return true
    end

    return false
end)

lib.callback.register('ug_garage:getVehicles', function(src, garageId)
    local g = Garages[garageId]
    if not g then return {} end
    if g.type == 'job' then
        if g.job ~= FW.GetJob(src) then return {} end
        return jobVehicleRows(garageId)
    end
    return getOwnedVehicles(src, garageId)
end)


CreateThread(function()
    Wait(3000)
    scanOutsideVehicles()

    local minutes = tonumber(Config.Impound and Config.Impound.checkIntervalMinutes) or 5
    if minutes < 1 then minutes = 1 end
    local interval = minutes * 60 * 1000

    while true do
        Wait(interval)
        if Config.Impound and Config.Impound.enabled ~= false then
            scanOutsideVehicles()
        end
    end
end)

lib.callback.register('ug_garage:getImpoundVehicles', function(src, garageId)
    if not Config.Impound or Config.Impound.enabled == false then return {} end
    local g = Garages[garageId]
    if not g or g.type ~= 'public' then return {} end

    if lastOutsideVehicleCheck == 0 then
        scanOutsideVehicles()
    end

    return getImpoundVehicles(src, garageId)
end)

lib.callback.register('ug_garage:storeVehicle', function(src, data)
    local plate = UG.TrimPlate(data.plate)
    local garageId = data.garageId
    local props = data.props
    local g = Garages[garageId]

    if not g or not plate or not props then return { ok = false, message = _L('invalid_data') } end

    if g.type == 'job' then
        if g.job ~= FW.GetJob(src) then
            return { ok = false, message = _L('no_access_garage') }
        end

        local tracked = spawnedJobVehicles[src] and spawnedJobVehicles[src][plate]
        local validTracked = tracked and tracked.garageId == garageId and tracked.job == g.job

        local valid, message = isValidJobVehicleForGarage(src, garageId, plate, data.netId)

        if not validTracked and not valid then
            return { ok = false, message = message or _L('job_vehicle_wrong_garage') }
        end

        if spawnedJobVehicles[src] then spawnedJobVehicles[src][plate] = nil end
        unmarkPlateOutside(plate)
        return { ok = true, message = _L('job_vehicle_stored') }
    end

    local owned = ownsVehicle(src, plate)
    if not owned then return { ok = false, message = _L('vehicle_not_owned') } end
    if not matchesGarageVehicleType(props.model, g.vehicleType) then
        return { ok = false, message = _L('wrong_vehicle_type') }
    end

    local cfg = vehicleCfg()
    local sql = ('UPDATE `%s` SET `%s` = ?, `%s` = ?, `%s` = ? WHERE `%s` = ? AND `%s` = ?')
        :format(cfg.table, cfg.vehicle, cfg.stored, cfg.garage, cfg.owner, cfg.plate)
    MySQL.update.await(sql, { json.encode(props), Config.State.stored, garageId, FW.GetIdentifier(src), plate })

    unmarkPlateOutside(plate)
    return { ok = true, message = _L('vehicle_stored') }
end)

lib.callback.register('ug_garage:prepareImpoundSpawn', function(src, garageId, plate)
    if not Config.Impound or Config.Impound.enabled == false then
        return { ok = false, message = _L('impound_disabled') }
    end

    plate = UG.TrimPlate(plate)
    local g = Garages[garageId]
    if not g then return { ok = false, message = _L('garage_not_found') } end
    if g.type ~= 'public' then return { ok = false, message = _L('impound_public_only') } end

    local owned, row = ownsVehicle(src, plate)
    if not owned then return { ok = false, message = _L('vehicle_not_owned') } end

    local cfg = vehicleCfg()
    if tonumber(row[cfg.stored] or Config.State.stored) == Config.State.stored then
        return { ok = false, message = _L('already_stored') }
    end

    local props = json.decode(row[cfg.vehicle] or '{}') or {}
    local model = props.model or row[cfg.model]
    if not matchesGarageVehicleType(model, g.vehicleType) then
        return { ok = false, message = _L('wrong_vehicle_type') }
    end

    local fee = tonumber(Config.Impound and Config.Impound.fee) or 0
    if fee > 0 and not FW.RemoveMoney(src, fee, 'Garage Impound') then
        return { ok = false, message = _L('need_impound_money', fee) }
    end

    local sql = ('UPDATE `%s` SET `%s` = ? WHERE `%s` = ? AND `%s` = ?')
        :format(cfg.table, cfg.garage, cfg.owner, cfg.plate)
    MySQL.update.await(sql, { garageId, FW.GetIdentifier(src), plate })

    return { ok = true, props = props, spawn = g.spawn, impound = true, fee = fee }
end)

lib.callback.register('ug_garage:prepareSpawn', function(src, garageId, plate)
    plate = UG.TrimPlate(plate)
    local g = Garages[garageId]
    if not g then return { ok = false, message = _L('garage_not_found') } end
    if g.type == 'job' and g.job ~= FW.GetJob(src) then
        return { ok = false, message = _L('no_access_garage') }
    end

    local owned, row = ownsVehicle(src, plate)
    if not owned then return { ok = false, message = _L('vehicle_not_owned') } end

    local cfg = vehicleCfg()
    if tonumber(row[cfg.stored] or Config.State.stored) ~= Config.State.stored then
        return { ok = false, message = _L('already_out') }
    end

    local props = json.decode(row[cfg.vehicle] or '{}') or {}
    local model = props.model or row[cfg.model]
    if not matchesGarageVehicleType(model, g.vehicleType) then
        return { ok = false, message = _L('wrong_vehicle_type') }
    end
    pendingSpawns[src] = pendingSpawns[src] or {}
    pendingSpawns[src][plate] = true

    return { ok = true, props = props, spawn = g.spawn }
end)



RegisterNetEvent('ug_garage:server:registerJobVehicleSpawn', function(data)
    local src = source
    if type(data) ~= 'table' then return end

    local garageId = data.garageId
    local jobVehicleId = tonumber(data.jobVehicleId)
    local plate = UG.TrimPlate(data.plate or '')
    local g = Garages[garageId]

    if not g or g.type ~= 'job' or plate == '' or not jobVehicleId then return end
    if g.job ~= FW.GetJob(src) then return end

    local row = MySQL.single.await('SELECT id FROM ug_job_vehicles WHERE id = ? AND garage_id = ? LIMIT 1', { jobVehicleId, garageId })
    if not row then return end

    spawnedJobVehicles[src] = spawnedJobVehicles[src] or {}
    spawnedJobVehicles[src][plate] = {
        garageId = garageId,
        jobVehicleId = jobVehicleId,
        job = g.job,
        netId = tonumber(data.netId) or 0,
        spawnedAt = os.time()
    }

end)

AddEventHandler('playerDropped', function()
    spawnedJobVehicles[source] = nil
end)

lib.callback.register('ug_garage:prepareJobVehicleSpawn', function(src, garageId, jobVehicleId)
    local g = Garages[garageId]
    if not g then return { ok = false, message = _L('garage_not_found') } end
    if g.type ~= 'job' then return { ok = false, message = _L('not_job_garage') } end
    if g.job ~= FW.GetJob(src) then return { ok = false, message = _L('no_access_garage') } end

    local row = MySQL.single.await('SELECT * FROM ug_job_vehicles WHERE id = ? AND garage_id = ? LIMIT 1', { tonumber(jobVehicleId), garageId })
    if not row then return { ok = false, message = _L('job_vehicle_not_found') } end
    if not matchesGarageVehicleType(row.model, g.vehicleType) then
        return { ok = false, message = _L('job_vehicle_wrong_type') }
    end

    local primary = { r = tonumber(row.primary_r) or 255, g = tonumber(row.primary_g) or 255, b = tonumber(row.primary_b) or 255 }
    local secondary = { r = tonumber(row.secondary_r) or 255, g = tonumber(row.secondary_g) or 255, b = tonumber(row.secondary_b) or 255 }
    return {
        ok = true,
        model = row.model,
        label = row.label ~= '' and row.label or row.model,
        spawn = g.spawn,
        job = g.job,
        platePrefix = getGaragePlatePrefix(garageId, g.job),
        color = { primary = primary, secondary = secondary },
        props = {
            model = row.model,
            fuelLevel = 100.0,
            engineHealth = 1000.0,
            bodyHealth = 1000.0,
            customPrimaryColor = { primary.r, primary.g, primary.b },
            customSecondaryColor = { secondary.r, secondary.g, secondary.b }
        }
    }
end)

RegisterNetEvent('ug_garage:server:markSpawned', function(plate, netId)
    local src = source
    plate = UG.TrimPlate(plate)
    if not plate or not pendingSpawns[src] or not pendingSpawns[src][plate] then return end

    local cfg = vehicleCfg()
    local sql = ('UPDATE `%s` SET `%s` = ? WHERE `%s` = ? AND `%s` = ?')
        :format(cfg.table, cfg.stored, cfg.owner, cfg.plate)
    MySQL.update.await(sql, { Config.State.out, FW.GetIdentifier(src), plate })

    markPlateOutside(plate)
    if netId then
        local vehicle = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
        if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
            markPlateOutside(GetVehicleNumberPlateText(vehicle))
        end
    end

    pendingSpawns[src][plate] = nil
end)

lib.callback.register('ug_garage:isAdmin', function(src)
    return FW.IsAdmin(src)
end)

lib.callback.register('ug_garage:adminCreateGarage', function(src, data)
    if not FW.IsAdmin(src) then return { ok = false, message = _L('no_rights') } end

    local id = (data.id or ''):lower():gsub('%s+', '_'):gsub('[^%w_%-]', '')
    if id == '' then return { ok = false, message = _L('invalid_id') } end
    if data.type ~= 'public' and data.type ~= 'job' then return { ok = false, message = _L('invalid_type') } end
    if data.type == 'job' and (not data.job or data.job == '') then return { ok = false, message = _L('job_missing') } end
    local vehicleType = normalizeVehicleType(data.vehicleType or data.vehicle_type)
    if not data.coords or not data.coords.x then return { ok = false, message = _L('coords_missing') } end
    if not data.store or not data.store.x then return { ok = false, message = _L('store_missing') } end
    if not data.spawn or not data.spawn.x then return { ok = false, message = _L('spawn_missing') } end

    local garage = {
        id = id,
        label = data.label or id,
        type = data.type,
        job = data.type == 'job' and data.job or nil,
        coords = data.coords,
        store = data.store,
        spawn = data.spawn,
        blip = data.blip ~= false,
        vehicleType = vehicleType
    }

    MySQL.insert.await([[INSERT INTO ug_garages (id, label, type, job, vehicle_type, coords, store, spawn, blip, created_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE label = VALUES(label), type = VALUES(type), job = VALUES(job), vehicle_type = VALUES(vehicle_type), coords = VALUES(coords), store = VALUES(store), spawn = VALUES(spawn), blip = VALUES(blip)]], {
        garage.id, garage.label, garage.type, garage.job, garage.vehicleType, json.encode(garage.coords), json.encode(garage.store), json.encode(garage.spawn), garage.blip and 1 or 0, FW.GetIdentifier(src)
    })

    Garages[id] = garage
    TriggerClientEvent('ug_garage:client:setGarages', -1, nil)
    Wait(250)
    for _, playerId in ipairs(GetPlayers()) do
        TriggerClientEvent('ug_garage:client:setGarages', tonumber(playerId), getVisibleGarages(tonumber(playerId)))
    end

    return { ok = true, message = _L('garage_saved') }
end)


lib.callback.register('ug_garage:adminListJobVehicles', function(src)
    if not FW.IsAdmin(src) then return {} end
    return adminJobVehicles()
end)

lib.callback.register('ug_garage:adminAddJobVehicle', function(src, data)
    if not FW.IsAdmin(src) then return { ok = false, message = _L('no_rights') } end
    data = data or {}
    local garageId = data.garageId or data.garage_id or ''
    local g = Garages[garageId]
    if not g then return { ok = false, message = _L('garage_not_found') } end
    if g.type ~= 'job' then return { ok = false, message = _L('job_vehicle_add_public_only') } end

    local model = tostring(data.model or ''):lower():gsub('%s+', '')
    if model == '' then return { ok = false, message = _L('spawnname_missing') } end
    local label = tostring(data.label or model)

    local pr = data.primary or {}
    local sr = data.secondary or pr
    MySQL.insert.await([[INSERT INTO ug_job_vehicles
        (garage_id, model, label, primary_r, primary_g, primary_b, secondary_r, secondary_g, secondary_b)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)]], {
        garageId,
        model,
        label,
        clampColor(pr.r), clampColor(pr.g), clampColor(pr.b),
        clampColor(sr.r), clampColor(sr.g), clampColor(sr.b)
    })

    return { ok = true, message = _L('job_vehicle_added'), vehicles = adminJobVehicles() }
end)

lib.callback.register('ug_garage:adminUpdateJobVehicle', function(src, data)
    if not FW.IsAdmin(src) then return { ok = false, message = _L('no_rights') } end
    data = data or {}
    local id = tonumber(data.id)
    if not id then return { ok = false, message = _L('vehicle_id_missing') } end

    local garageId = data.garageId or data.garage_id or ''
    local g = Garages[garageId]
    if not g then return { ok = false, message = _L('garage_not_found') } end
    if g.type ~= 'job' then return { ok = false, message = _L('job_vehicle_edit_public_only') } end

    local model = tostring(data.model or ''):lower():gsub('%s+', '')
    if model == '' then return { ok = false, message = _L('spawnname_missing') } end
    local label = tostring(data.label or model)

    local pr = data.primary or {}
    local sr = data.secondary or pr
    MySQL.update.await([[UPDATE ug_job_vehicles
        SET garage_id = ?, model = ?, label = ?, primary_r = ?, primary_g = ?, primary_b = ?, secondary_r = ?, secondary_g = ?, secondary_b = ?
        WHERE id = ?]], {
        garageId,
        model,
        label,
        clampColor(pr.r), clampColor(pr.g), clampColor(pr.b),
        clampColor(sr.r), clampColor(sr.g), clampColor(sr.b),
        id
    })

    return { ok = true, message = _L('job_vehicle_saved'), vehicles = adminJobVehicles() }
end)

lib.callback.register('ug_garage:adminDeleteJobVehicle', function(src, id)
    if not FW.IsAdmin(src) then return { ok = false, message = _L('no_rights') } end
    MySQL.update.await('DELETE FROM ug_job_vehicles WHERE id = ?', { tonumber(id) })
    return { ok = true, message = _L('job_vehicle_deleted'), vehicles = adminJobVehicles() }
end)

lib.callback.register('ug_garage:adminDeleteGarage', function(src, id)
    if not FW.IsAdmin(src) then return { ok = false, message = _L('no_rights') } end
    if not id or Config.Garages[id] then return { ok = false, message = _L('static_garage_delete') } end
    MySQL.update.await('DELETE FROM ug_garages WHERE id = ?', { id })
    MySQL.update.await('DELETE FROM ug_job_vehicles WHERE garage_id = ?', { id })
    Garages[id] = nil
    for _, playerId in ipairs(GetPlayers()) do
        TriggerClientEvent('ug_garage:client:setGarages', tonumber(playerId), getVisibleGarages(tonumber(playerId)))
    end
    return { ok = true, message = _L('garage_deleted') }
end)

lib.callback.register('ug_garage:adminListGarages', function(src)
    if not FW.IsAdmin(src) then return {} end
    return Garages
end)

AddEventHandler('playerDropped', function()
    pendingSpawns[source] = nil
end)

CreateThread(function()
    while not FW.Name do Wait(250) end
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `ug_garages` (
        `id` varchar(64) NOT NULL,
        `label` varchar(100) NOT NULL,
        `type` enum('public','job') NOT NULL DEFAULT 'public',
        `job` varchar(64) DEFAULT NULL,
        `vehicle_type` varchar(16) NOT NULL DEFAULT 'car',
        `coords` longtext NOT NULL,
        `store` longtext NULL,
        `spawn` longtext NOT NULL,
        `blip` tinyint(1) NOT NULL DEFAULT 1,
        `created_by` varchar(80) DEFAULT NULL,
        `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]])

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `ug_job_vehicles` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `garage_id` varchar(64) NOT NULL,
        `model` varchar(80) NOT NULL,
        `label` varchar(100) NOT NULL,
        `primary_r` tinyint(3) unsigned NOT NULL DEFAULT 255,
        `primary_g` tinyint(3) unsigned NOT NULL DEFAULT 255,
        `primary_b` tinyint(3) unsigned NOT NULL DEFAULT 255,
        `secondary_r` tinyint(3) unsigned NOT NULL DEFAULT 255,
        `secondary_g` tinyint(3) unsigned NOT NULL DEFAULT 255,
        `secondary_b` tinyint(3) unsigned NOT NULL DEFAULT 255,
        `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        KEY `garage_id` (`garage_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]])
    pcall(function()
        MySQL.query.await('ALTER TABLE `ug_garages` ADD COLUMN `store` longtext NULL AFTER `coords`')
    end)
    pcall(function()
        MySQL.query.await("ALTER TABLE `ug_garages` ADD COLUMN `vehicle_type` varchar(16) NOT NULL DEFAULT 'car' AFTER `job`")
    end)
    MySQL.update.await([[UPDATE `ug_garages` SET `store` = `coords` WHERE `store` IS NULL OR `store` = '']])
    MySQL.update.await([[UPDATE `ug_garages` SET `vehicle_type` = 'car' WHERE `vehicle_type` IS NULL OR `vehicle_type` = '']])
    loadGarages()

    for _, playerId in ipairs(GetPlayers()) do
        TriggerClientEvent('ug_garage:client:setGarages', tonumber(playerId), getVisibleGarages(tonumber(playerId)))
    end
end)
