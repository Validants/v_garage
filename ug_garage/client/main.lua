local Garages = {}
local Blips = {}
local currentGarage = nil
local nuiOpen = false
local vehicleImageCache = {}
local vehicleImageQueue = {}
local vehicleImageCapturing = false
local resolveModel
local LocalVehicleKeys = {}

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

local function notify(msg, typ, title)
    SendNUIMessage({
        action = 'notify',
        title = title or 'Garage',
        message = msg or '',
        type = typ or 'inform'
    })
end




local function sanitizePlatePrefix(prefix)
    prefix = tostring(prefix or 'JOB'):upper():gsub('%s+', ''):gsub('[^A-Z0-9]', '')
    if prefix == '' then prefix = 'JOB' end
    return prefix:sub(1, 6)
end

local function makeJobVehiclePlate(prefix)
    prefix = sanitizePlatePrefix(prefix or (Config.JobVehicles and Config.JobVehicles.platePrefix) or 'JOB')
    local maxDigits = math.max(1, 8 - #prefix)
    local min = 10 ^ (maxDigits - 1)
    local max = (10 ^ maxDigits) - 1
    return (prefix .. tostring(math.random(min, max))):sub(1, 8)
end

local function safeExport(resource, exportName, ...)
    if not resource or resource == '' or GetResourceState(resource) ~= 'started' then return false end
    local ok = pcall(function(...)
        exports[resource][exportName](exports[resource], ...)
    end, ...)
    return ok
end

local function grantLocalVehicleKey(plate)
    plate = UG.TrimPlate(plate or '')
    if plate and plate ~= '' then
        LocalVehicleKeys[plate] = true
    end
end

local function hasLocalVehicleKey(plate)
    plate = UG.TrimPlate(plate or '')
    return plate and plate ~= '' and LocalVehicleKeys[plate] == true
end

local function giveVehicleKeys(vehicle, plate, model, isJobVehicle)
    if not vehicle or vehicle == 0 then return end
    grantLocalVehicleKey(plate or GetVehicleNumberPlateText(vehicle))
    local cfg = Config.VehicleKeys or {}
    if cfg.enabled == false then return end
    if isJobVehicle and cfg.giveForJob == false then return end
    if not isJobVehicle and cfg.giveForOwned == false then return end

    plate = UG.TrimPlate(plate or GetVehicleNumberPlateText(vehicle))
    if not plate or plate == '' then return end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    local modelName = model
    if type(modelName) ~= 'string' then modelName = tostring(modelName or GetEntityModel(vehicle)) end

    if cfg.customClientEvent and cfg.customClientEvent ~= '' then
        TriggerEvent(cfg.customClientEvent, vehicle, plate, modelName, netId, isJobVehicle)
    end
    if cfg.customServerEvent and cfg.customServerEvent ~= '' then
        TriggerServerEvent(cfg.customServerEvent, plate, modelName, netId, isJobVehicle)
    end

    local system = cfg.system or 'auto'

    if system == 'auto' or system == 'qb-vehiclekeys' then
        if GetResourceState('qb-vehiclekeys') == 'started' then
            TriggerEvent('vehiclekeys:client:SetOwner', plate)
            return
        end
    end

    if system == 'auto' or system == 'qs-vehiclekeys' then
        if GetResourceState('qs-vehiclekeys') == 'started' then
            local ok = pcall(function()
                exports['qs-vehiclekeys']:GiveKeys(plate, modelName, true)
            end)
            if ok then return end
        end
    end

    if system == 'auto' or system == 'wasabi_carlock' then
        if GetResourceState('wasabi_carlock') == 'started' then
            local ok = pcall(function()
                exports.wasabi_carlock:GiveKey(plate)
            end)
            if ok then return end
        end
    end

    if system == 'auto' or system == 'cd_garage' then
        if GetResourceState('cd_garage') == 'started' then
            TriggerEvent('cd_garage:AddKeys', plate)
            return
        end
    end
end


local function getLockTargetVehicle()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh and veh ~= 0 then return veh end
    local coords = GetEntityCoords(ped)
    return lib.getClosestVehicle(coords, (Config.VehicleLock and Config.VehicleLock.distance) or 8.0, false)
end

local function flashVehicle(vehicle)
    if not vehicle or vehicle == 0 or not Config.VehicleLock or not Config.VehicleLock.flashLights then return end
    SetVehicleLights(vehicle, 2)
    Wait(140)
    SetVehicleLights(vehicle, 0)
    Wait(120)
    SetVehicleLights(vehicle, 2)
    Wait(140)
    SetVehicleLights(vehicle, 0)
end

local function playLockAnim()
    local ped = PlayerPedId()
    lib.requestAnimDict('anim@mp_player_intmenu@key_fob@')
    TaskPlayAnim(ped, 'anim@mp_player_intmenu@key_fob@', 'fob_click', 8.0, 8.0, 650, 48, 0, false, false, false)
end

local function toggleVehicleLock()
    if not Config.VehicleLock or Config.VehicleLock.enabled == false then return end
    local vehicle = getLockTargetVehicle()
    if not vehicle or vehicle == 0 then
        notify(_L('no_vehicle_nearby'), 'error', _L('vehicle_keys'))
        return
    end

    local plate = UG.TrimPlate(GetVehicleNumberPlateText(vehicle) or '')
    local hasKey = hasLocalVehicleKey(plate)

    if not hasKey and Config.VehicleLock.requireKeys ~= false then
        local ok = lib.callback.await('ug_garage:canLockVehicle', false, plate)
        hasKey = ok == true
        if hasKey then grantLocalVehicleKey(plate) end
    end

    if Config.VehicleLock.requireKeys ~= false and not hasKey then
        notify(_L('no_vehicle_key'), 'error', _L('vehicle_keys'))
        return
    end

    playLockAnim()
    local locked = GetVehicleDoorLockStatus(vehicle)
    if locked == 1 or locked == 0 then
        SetVehicleDoorsLocked(vehicle, 2)
        SetVehicleDoorsLockedForAllPlayers(vehicle, true)
        PlayVehicleDoorCloseSound(vehicle, 1)
        flashVehicle(vehicle)
        notify(_L('vehicle_locked', plate), 'success', _L('vehicle_keys'))
    else
        SetVehicleDoorsLocked(vehicle, 1)
        SetVehicleDoorsLockedForAllPlayers(vehicle, false)
        PlayVehicleDoorOpenSound(vehicle, 0)
        flashVehicle(vehicle)
        notify(_L('vehicle_unlocked', plate), 'success', _L('vehicle_keys'))
    end
end

CreateThread(function()
    Wait(1000)
    if Config.VehicleLock and Config.VehicleLock.enabled ~= false then
        RegisterCommand(Config.VehicleLock.command or 'lockvehicle', toggleVehicleLock, false)
        RegisterKeyMapping(Config.VehicleLock.command or 'lockvehicle', _L('lock_key_mapping'), 'keyboard', Config.VehicleLock.key or 'U')
    end
end)

local function vehicleImageKey(model)
    local hash = resolveModel(model)
    if not hash then return nil end
    return tostring(hash)
end

local function vehicleImageKvpKey(model)
    local key = vehicleImageKey(model)
    return key and ('ug_garage_vehicle_image_' .. key) or nil
end

local function getCachedVehicleImage(model)
    local key = vehicleImageKey(model)
    if not key then return nil end
    if vehicleImageCache[key] then return vehicleImageCache[key] end
    local kvp = vehicleImageKvpKey(model)
    local stored = kvp and GetResourceKvpString(kvp) or nil
    if stored and stored ~= '' then
        vehicleImageCache[key] = stored
        return stored
    end
    return nil
end

local function sendVehicleImageToNui(model, image)
    local key = vehicleImageKey(model)
    if not key or not image then return end
    SendNUIMessage({ action = 'setVehicleImage', modelKey = key, image = image })
end

local function cacheVehicleImage(model, image)
    local key = vehicleImageKey(model)
    local kvp = vehicleImageKvpKey(model)
    if not key or not kvp or not image or image == '' then return end
    vehicleImageCache[key] = image
    SetResourceKvp(kvp, image)
    sendVehicleImageToNui(model, image)
end

local function screenshotAvailable()
    return GetResourceState('screenshot-basic') == 'started'
end

local function captureVehicleImageNow(model, done)
    if not Config.VehicleImages or not Config.VehicleImages.enabled then if done then done(false) end return end
    if not screenshotAvailable() then if done then done(false) end return end

    local hash = resolveModel(model)
    if not hash or not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then if done then done(false) end return end

    lib.requestModel(hash, 10000)

    local cp = Config.VehicleImages.capturePoint or vec4(-75.17, -819.08, 326.18, 180.0)
    local veh = CreateVehicle(hash, cp.x, cp.y, cp.z, cp.w or 0.0, false, false)
    if not veh or veh == 0 then if done then done(false) end return end

    SetEntityAsMissionEntity(veh, true, true)
    SetEntityCollision(veh, false, false)
    FreezeEntityPosition(veh, true)
    SetVehicleOnGroundProperly(veh)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleDoorsLocked(veh, 2)
    SetEntityHeading(veh, cp.w or 0.0)

    local offset = Config.VehicleImages.cameraOffset or vec3(4.6, -6.8, 2.2)
    local camCoords = GetOffsetFromEntityInWorldCoords(veh, offset.x, offset.y, offset.z)
    local target = GetOffsetFromEntityInWorldCoords(veh, 0.0, 0.0, 0.55)
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cam, camCoords.x, camCoords.y, camCoords.z)
    PointCamAtCoord(cam, target.x, target.y, target.z)
    SetCamFov(cam, Config.VehicleImages.cameraFov or 35.0)
    RenderScriptCams(true, true, 250, true, true)

    Wait(700)

    exports['screenshot-basic']:requestScreenshot({
        encoding = (Config.VehicleImages.screenshot and Config.VehicleImages.screenshot.encoding) or 'jpg',
        quality = (Config.VehicleImages.screenshot and Config.VehicleImages.screenshot.quality) or 0.82
    }, function(data)
        RenderScriptCams(false, true, 250, true, true)
        DestroyCam(cam, false)
        DeleteEntity(veh)
        SetModelAsNoLongerNeeded(hash)

        if data and data ~= '' then
            cacheVehicleImage(hash, data)
            if done then done(true) end
        else
            if done then done(false) end
        end
    end)
end

local function processVehicleImageQueue()
    if vehicleImageCapturing then return end
    vehicleImageCapturing = true

    CreateThread(function()
        while #vehicleImageQueue > 0 do
            local model = table.remove(vehicleImageQueue, 1)
            if model and not getCachedVehicleImage(model) then
                local finished = false
                captureVehicleImageNow(model, function() finished = true end)
                local started = GetGameTimer()
                while not finished and GetGameTimer() - started < 15000 do Wait(100) end
                Wait(250)
            end
        end
        vehicleImageCapturing = false
    end)
end

local function queueVehicleImageCapture(model)
    if not Config.VehicleImages or not Config.VehicleImages.enabled or not Config.VehicleImages.captureOnFirstOpen then return end
    if not screenshotAvailable() then return end
    local key = vehicleImageKey(model)
    if not key or getCachedVehicleImage(model) then return end
    for _, queued in ipairs(vehicleImageQueue) do
        if vehicleImageKey(queued) == key then return end
    end
    vehicleImageQueue[#vehicleImageQueue + 1] = model
    processVehicleImageQueue()
end

local VehicleClasses = {
    [0] = 'Kompakt', [1] = 'Limousine', [2] = 'SUV', [3] = 'Coupé', [4] = 'Muscle',
    [5] = 'Sport Classic', [6] = 'Sport', [7] = 'Super', [8] = 'Motorrad', [9] = 'Offroad',
    [10] = 'Industrie', [11] = 'Nutzfahrzeug', [12] = 'Van', [13] = 'Fahrrad', [14] = 'Boot',
    [15] = 'Helikopter', [16] = 'Flugzeug', [17] = 'Service', [18] = 'Einsatzfahrzeug',
    [19] = 'Militär', [20] = 'Commercial', [21] = 'Zug'
}

local function normalizeVehicleType(value)
    value = tostring(value or (Config.VehicleTypes and Config.VehicleTypes.default) or 'car'):lower()
    if value ~= 'car' and value ~= 'air' and value ~= 'boat' then value = 'car' end
    return value
end

local function vehicleTypeLabel(value)
    value = normalizeVehicleType(value)
    if value == 'air' then return _L('vehicle_type_air') end
    if value == 'boat' then return _L('vehicle_type_boat') end
    return _L('vehicle_type_car')
end

local function matchesVehicleType(classId, vehicleType)
    vehicleType = normalizeVehicleType(vehicleType)
    if classId == nil then return true end
    local vt = Config.VehicleTypes or {}
    local boat = (vt.boatClasses or {})[classId] == true
    local air = (vt.airClasses or {})[classId] == true
    if vehicleType == 'boat' then return boat end
    if vehicleType == 'air' then return air end
    return not boat and not air
end

local function round(value, decimals)
    value = tonumber(value) or 0
    local power = 10 ^ (decimals or 0)
    return math.floor(value * power + 0.5) / power
end

resolveModel = function(model)
    if not model then return nil end
    if type(model) == 'number' then return model end
    if tonumber(model) then return tonumber(model) end
    return joaat(model)
end

local function vehicleDisplayName(model)
    local hash = resolveModel(model)
    if not hash then return 'Unbekannt' end
    local display = GetDisplayNameFromVehicleModel(hash)
    if not display or display == '' or display == 'CARNOTFOUND' then return tostring(model) end
    local label = GetLabelText(display)
    if label and label ~= 'NULL' then return label end
    return display
end

local function enrichVehicles(list)
    local enriched = {}
    for i, v in ipairs(list or {}) do
        local props = v.props or {}
        local model = props.model or v.model
        local hash = resolveModel(model)
        local classId = hash and GetVehicleClassFromName(hash) or nil
        local garageType = currentGarage and Garages[currentGarage] and Garages[currentGarage].vehicleType or nil
        if not matchesVehicleType(classId, garageType) then
            goto continue_enrich_vehicle
        end
        local make = hash and GetMakeNameFromVehicleModel(hash) or nil
        local makeLabel = make and GetLabelText(make) or nil
        if makeLabel == 'NULL' then makeLabel = make end

        v.displayName = v.label or vehicleDisplayName(model)
        v.modelHash = hash
        if v.color then
            v.primaryRgb = v.color.primary
            v.secondaryRgb = v.color.secondary
        elseif props.customPrimaryColor then
            v.primaryRgb = { r = props.customPrimaryColor[1], g = props.customPrimaryColor[2], b = props.customPrimaryColor[3] }
        end
        if not v.secondaryRgb and props.customSecondaryColor then
            v.secondaryRgb = { r = props.customSecondaryColor[1], g = props.customSecondaryColor[2], b = props.customSecondaryColor[3] }
        end
        v.imageKey = hash and tostring(hash) or nil
        v.image = getCachedVehicleImage(hash or model)
        if not v.image then queueVehicleImageCapture(hash or model) end
        v.classId = classId
        v.className = classId and (VehicleClasses[classId] or ('Klasse ' .. classId)) or 'Unbekannt'
        v.make = makeLabel or 'Unbekannt'
        v.fuel = round(props.fuelLevel or props.fuel or v.fuel or 0, 1)
        v.engineHealth = round(props.engineHealth or v.engineHealth or 0, 1)
        v.bodyHealth = round(props.bodyHealth or v.bodyHealth or 0, 1)
        v.dirtLevel = round(props.dirtLevel or 0, 1)
        v.tankHealth = round(props.tankHealth or 0, 1)
        v.mileage = v.mileage and round(v.mileage, 1) or nil
        v.depotPrice = v.depotPrice
        v.paymentAmount = v.paymentAmount
        v.balance = v.balance
        v.vehicleProps = props
        v.color1 = props.color1
        v.color2 = props.color2
        v.pearlescentColor = props.pearlescentColor
        v.wheelColor = props.wheelColor
        v.windowTint = props.windowTint
        v.livery = props.modLivery or props.livery
        v.extras = props.extras or {}
        v.modsCount = 0
        for k, val in pairs(props) do
            if type(k) == 'string' and k:sub(1, 3) == 'mod' and val ~= nil and val ~= -1 then
                v.modsCount = v.modsCount + 1
            end
        end
        enriched[#enriched + 1] = v
        ::continue_enrich_vehicle::
    end
    return enriched
end

local function closeNui()
    nuiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local placingPoint = false

local function drawPlacementHelp(targetLabel)
    local lines = {
        ('~b~%s platzieren~s~'):format(targetLabel),
        'W/A/S/D: verschieben',
        'Q/E: drehen',
        'Bild hoch/runter: Höhe',
        'Shift: schneller',
        'Enter: bestätigen',
        'Backspace: abbrechen'
    }
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(table.concat(lines, '~n~'))
    EndTextCommandDisplayHelp(0, false, true, 1)
end

local function placementLabel(target)
    if target == 'coords' then return _L('open_point') end
    if target == 'store' then return _L('store_point') end
    if target == 'spawn' then return _L('spawn_point') end
    return 'Position'
end

local function startPlacementMode(target, initial)
    if placingPoint then return { ok = false, message = _L('placement_already_running') } end
    if not Config.Placement or not Config.Placement.enabled then return { ok = false, message = _L('placement_disabled') } end

    placingPoint = true
    local ped = PlayerPedId()
    local start = initial
    if not start or not start.x then
        local forward = GetEntityForwardVector(ped)
        local pc = GetEntityCoords(ped)
        local dist = Config.Placement.startDistance or 3.0
        start = { x = pc.x + forward.x * dist, y = pc.y + forward.y * dist, z = pc.z, w = GetEntityHeading(ped) }
    end

    local pos = vector3(start.x + 0.0, start.y + 0.0, start.z + 0.0)
    local heading = start.w or GetEntityHeading(ped)
    local label = placementLabel(target)
    local result = nil

    notify(_L('placement_started', label), 'inform')

    while placingPoint do
        Wait(0)
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DisableControlAction(0, 37, true)
        DisableControlAction(0, 44, true)
        DisableControlAction(0, 38, true)

        local speed = Config.Placement.moveSpeed or 0.06
        if IsControlPressed(0, 21) then speed = speed * (Config.Placement.fastMultiplier or 4.0) end
        local rotSpeed = Config.Placement.rotateSpeed or 1.5
        local camRot = GetGameplayCamRot(2)
        local yaw = math.rad(camRot.z)
        local forward = vector3(-math.sin(yaw), math.cos(yaw), 0.0)
        local right = vector3(math.cos(yaw), math.sin(yaw), 0.0)

        if IsControlPressed(0, 32) then pos = pos + forward * speed end -- W
        if IsControlPressed(0, 33) then pos = pos - forward * speed end -- S
        if IsControlPressed(0, 35) then pos = pos + right * speed end -- D
        if IsControlPressed(0, 34) then pos = pos - right * speed end -- A
        if IsDisabledControlPressed(0, 44) or IsControlPressed(0, 44) then heading = heading - rotSpeed end -- Q
        if IsDisabledControlPressed(0, 38) or IsControlPressed(0, 38) then heading = heading + rotSpeed end -- E
        if IsControlPressed(0, 10) then pos = pos + vector3(0.0, 0.0, speed) end -- PageUp
        if IsControlPressed(0, 11) then pos = pos - vector3(0.0, 0.0, speed) end -- PageDown

        if heading >= 360.0 then heading = heading - 360.0 end
        if heading < 0.0 then heading = heading + 360.0 end

        local markerCfg = target == 'spawn' and (Config.Placement.spawnMarker or Config.Placement.marker) or Config.Placement.marker
        markerCfg = markerCfg or Config.Marker
        local size = markerCfg.size or vec3(1.0, 1.0, 1.0)
        local color = markerCfg.color or { r = 56, g = 189, b = 248, a = 170 }

        DrawMarker(markerCfg.type or 1, pos.x, pos.y, pos.z + 0.05, 0.0, 0.0, 0.0, 0.0, 0.0, heading,
            size.x, size.y, size.z, color.r, color.g, color.b, color.a, false, true, 2, false, nil, nil, false)

        DrawLine(pos.x, pos.y, pos.z + 0.25, pos.x + math.sin(math.rad(heading)) * 1.8, pos.y + math.cos(math.rad(heading)) * 1.8, pos.z + 0.25, 250, 204, 21, 220)
        SetDrawOrigin(pos.x, pos.y, pos.z + 1.05, 0)
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextCentre(true)
        SetTextColour(255, 255, 255, 230)
        BeginTextCommandDisplayText('STRING')
        AddTextComponentSubstringPlayerName(('%s\n%.2f %.2f %.2f | %.1f°'):format(label, pos.x, pos.y, pos.z, heading))
        EndTextCommandDisplayText(0.0, 0.0)
        ClearDrawOrigin()

        drawPlacementHelp(label)

        if IsControlJustReleased(0, 191) then -- Enter
            result = { ok = true, x = pos.x, y = pos.y, z = pos.z, w = heading }
            break
        end
        if IsControlJustReleased(0, 177) then -- Backspace
            result = { ok = false, cancelled = true }
            break
        end
    end

    placingPoint = false
    return result or { ok = false, cancelled = true }
end

local function deleteBlips()
    for _, blip in pairs(Blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    Blips = {}
end

local function createBlips()
    deleteBlips()
    for id, g in pairs(Garages) do
        if g.blip then
            local blip = AddBlipForCoord(g.coords.x, g.coords.y, g.coords.z)
            SetBlipSprite(blip, Config.DefaultBlip.sprite)
            SetBlipScale(blip, Config.DefaultBlip.scale)
            SetBlipColour(blip, g.type == 'job' and Config.DefaultBlip.jobColor or Config.DefaultBlip.color)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(g.label)
            EndTextCommandSetBlipName(blip)
            Blips[id] = blip
        end
    end
end


local function hasGaragesLoaded()
    return Garages ~= nil and next(Garages) ~= nil
end

local function requestGaragesReliable(retries, delay)
    retries = tonumber(retries) or 12
    delay = tonumber(delay) or 2500

    CreateThread(function()
        while not NetworkIsPlayerActive(PlayerId()) do
            Wait(250)
        end

        for _ = 1, retries do
            TriggerServerEvent('ug_garage:server:requestGarages')
            Wait(delay)
            if hasGaragesLoaded() then break end
        end
    end)
end

RegisterNetEvent('ug_garage:client:setGarages', function(data)
    if data then
        Garages = data
        createBlips()
    else
        requestGaragesReliable(6, 1500)
    end
end)

local function getVehicleProps(vehicle)
    local props = lib.getVehicleProperties(vehicle)
    props.plate = UG.TrimPlate(GetVehicleNumberPlateText(vehicle))
    props.engineHealth = GetVehicleEngineHealth(vehicle)
    props.bodyHealth = GetVehicleBodyHealth(vehicle)
    props.fuelLevel = GetVehicleFuelLevel(vehicle)
    return props
end

local function applyVehicleProps(vehicle, props)
    props = props or {}
    lib.setVehicleProperties(vehicle, props)
    if props.customPrimaryColor then
        SetVehicleCustomPrimaryColour(vehicle, props.customPrimaryColor[1] or 255, props.customPrimaryColor[2] or 255, props.customPrimaryColor[3] or 255)
    end
    if props.customSecondaryColor then
        SetVehicleCustomSecondaryColour(vehicle, props.customSecondaryColor[1] or 255, props.customSecondaryColor[2] or 255, props.customSecondaryColor[3] or 255)
    end
    if props.fuelLevel then SetVehicleFuelLevel(vehicle, props.fuelLevel + 0.0) end
    if props.engineHealth then SetVehicleEngineHealth(vehicle, props.engineHealth + 0.0) end
    if props.bodyHealth then SetVehicleBodyHealth(vehicle, props.bodyHealth + 0.0) end
end

local function openGarage(garageId)
    currentGarage = garageId
    local vehicles = enrichVehicles(lib.callback.await('ug_garage:getVehicles', false, garageId))
    nuiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openGarage',
        garage = Garages[garageId],
        vehicles = vehicles,
        resource = GetCurrentResourceName(),
        locale = Config.Locale or 'de'
    })
end

local function openAdmin()
    local isAdmin = lib.callback.await('ug_garage:isAdmin', false)
    if not isAdmin then notify(_L('no_rights'), 'error') return end
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local list = lib.callback.await('ug_garage:adminListGarages', false)
    local jobVehicles = lib.callback.await('ug_garage:adminListJobVehicles', false)

    nuiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openAdmin',
        garages = list,
        jobVehicles = jobVehicles,
        position = { x = coords.x, y = coords.y, z = coords.z, w = heading },
        resource = GetCurrentResourceName(),
        locale = Config.Locale or 'de'
    })
end

RegisterCommand(Config.AdminCommand, function()
    openAdmin()
end, false)

RegisterNUICallback('close', function(_, cb)
    closeNui()
    cb({ ok = true })
end)

RegisterNUICallback('refreshVehicles', function(_, cb)
    if not currentGarage then cb({ vehicles = {} }) return end
    cb({ vehicles = enrichVehicles(lib.callback.await('ug_garage:getVehicles', false, currentGarage)) })
end)

RegisterNUICallback('refreshImpoundVehicles', function(_, cb)
    if not currentGarage then cb({ vehicles = {} }) return end
    cb({ vehicles = enrichVehicles(lib.callback.await('ug_garage:getImpoundVehicles', false, currentGarage)) })
end)

RegisterNUICallback('spawnVehicle', function(data, cb)
    if not currentGarage then cb({ ok = false }) return end

    local result
    if data.jobVehicleId then
        result = lib.callback.await('ug_garage:prepareJobVehicleSpawn', false, currentGarage, data.jobVehicleId)
    elseif data.impound then
        if not data.plate then cb({ ok = false }) return end
        result = lib.callback.await('ug_garage:prepareImpoundSpawn', false, currentGarage, data.plate)
    else
        if not data.plate then cb({ ok = false }) return end
        result = lib.callback.await('ug_garage:prepareSpawn', false, currentGarage, data.plate)
    end

    if not result.ok then notify(result.message or _L('error'), 'error') cb(result) return end

    local spawn = result.spawn
    if IsAnyVehicleNearPoint(spawn.x, spawn.y, spawn.z, 3.0) then
        notify(_L('spawn_blocked'), 'error')
        cb({ ok = false })
        return
    end

    local props = result.props or {}
    local model = props.model or result.model or data.model
    if type(model) == 'string' then model = joaat(model) end

    lib.requestModel(model, 10000)
    local vehicle = CreateVehicle(model, spawn.x, spawn.y, spawn.z, spawn.w or 0.0, true, false)
    SetEntityAsMissionEntity(vehicle, true, true)

    local plate = data.plate
    if data.jobVehicleId then
        plate = makeJobVehiclePlate(result.platePrefix)
    end

    if plate and plate ~= '' then
        SetVehicleNumberPlateText(vehicle, plate)
        props.plate = plate
    end

    applyVehicleProps(vehicle, props)

    if plate and plate ~= '' then
        SetVehicleNumberPlateText(vehicle, plate)
    end

    if data.jobVehicleId then
        local state = Entity(vehicle).state
        state:set('ug_jobVehicle', true, true)
        state:set('ug_garageId', currentGarage, true)
        state:set('ug_jobVehicleId', tonumber(data.jobVehicleId), true)
        state:set('ug_job', result.job, true)
        state:set('ug_plate', plate, true)
    end

    SetVehicleDoorsLocked(vehicle, 1)
    SetVehicleDoorsLockedForAllPlayers(vehicle, false)
    giveVehicleKeys(vehicle, plate, result.model or data.model or props.model, data.jobVehicleId ~= nil)

    TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
    SetModelAsNoLongerNeeded(model)

    if data.jobVehicleId then
        TriggerServerEvent('ug_garage:server:registerJobVehicleSpawn', {
            garageId = currentGarage,
            jobVehicleId = data.jobVehicleId,
            plate = plate,
            netId = NetworkGetNetworkIdFromEntity(vehicle)
        })
    elseif not data.impound then
        TriggerServerEvent('ug_garage:server:markSpawned', data.plate, NetworkGetNetworkIdFromEntity(vehicle))
    end
    notify(data.jobVehicleId and _L('job_vehicle_spawned') or (data.impound and _L('impound_spawned') or _L('vehicle_spawned')), 'success')
    closeNui()
    cb({ ok = true })
end)

local function storeVehicleAtGarage(garageId)
    local g = Garages[garageId]
    if not g then return { ok = false } end

    local ped = PlayerPedId()
    local store = g.store or g.coords
    local storeCoords = vec3(store.x, store.y, store.z)
    local pedCoords = GetEntityCoords(ped)

    if #(pedCoords - storeCoords) > (Config.StoreDistance or 8.0) then
        notify(_L('must_be_at_store'), 'error')
        return { ok = false }
    end

    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then
        notify(_L('must_be_in_vehicle'), 'error')
        return { ok = false }
    end

    local classId = GetVehicleClass(vehicle)
    if not matchesVehicleType(classId, g.vehicleType) then
        notify(_L('wrong_vehicle_type'), 'error')
        return { ok = false }
    end

    local props = getVehicleProps(vehicle)
    local result = lib.callback.await('ug_garage:storeVehicle', false, {
        garageId = garageId,
        plate = props.plate,
        props = props,
        netId = NetworkGetNetworkIdFromEntity(vehicle)
    })

    if result.ok then
        DeleteEntity(vehicle)
        notify(result.message, 'success')
        return { ok = true }
    else
        notify(result.message or _L('error'), 'error')
        return { ok = false }
    end
end

RegisterNUICallback('storeCurrentVehicle', function(_, cb)
    if not currentGarage then cb({ ok = false }) return end
    cb(storeVehicleAtGarage(currentGarage))
end)

RegisterNUICallback('adminUseCurrentPosition', function(_, cb)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    cb({ x = coords.x, y = coords.y, z = coords.z, w = GetEntityHeading(ped) })
end)

RegisterNUICallback('adminUseVehiclePosition', function(_, cb)
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    local entity = veh ~= 0 and veh or ped
    local coords = GetEntityCoords(entity)
    cb({ x = coords.x, y = coords.y, z = coords.z, w = GetEntityHeading(entity) })
end)

RegisterNUICallback('adminStartPlacement', function(data, cb)
    local target = data and data.target or 'coords'
    local initial = data and data.initial or nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hideForPlacement' })

    CreateThread(function()
        local result = startPlacementMode(target, initial)
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'showAfterPlacement' })
        if result.ok then
            notify(_L('point_set', placementLabel(target)), 'success')
        elseif result.cancelled then
            notify(_L('placement_cancelled'), 'warning')
        else
            notify(result.message or _L('placement_failed'), 'error')
        end
        cb(result)
    end)
end)

RegisterNUICallback('adminCreateGarage', function(data, cb)
    local result = lib.callback.await('ug_garage:adminCreateGarage', false, data)
    notify(result.message or _L('action_done'), result.ok and 'success' or 'error')
    cb(result)
end)

RegisterNUICallback('adminAddJobVehicle', function(data, cb)
    local result = lib.callback.await('ug_garage:adminAddJobVehicle', false, data)
    notify(result.message or _L('action_done'), result.ok and 'success' or 'error')
    cb(result)
end)

RegisterNUICallback('adminUpdateJobVehicle', function(data, cb)
    local result = lib.callback.await('ug_garage:adminUpdateJobVehicle', false, data)
    notify(result.message or _L('action_done'), result.ok and 'success' or 'error')
    cb(result)
end)

RegisterNUICallback('adminDeleteJobVehicle', function(data, cb)
    local result = lib.callback.await('ug_garage:adminDeleteJobVehicle', false, data.id)
    notify(result.message or _L('action_done'), result.ok and 'success' or 'error')
    cb(result)
end)

RegisterNUICallback('adminDeleteGarage', function(data, cb)
    local result = lib.callback.await('ug_garage:adminDeleteGarage', false, data.id)
    notify(result.message or _L('action_done'), result.ok and 'success' or 'error')
    cb(result)
end)



RegisterCommand('garagecaptureimages', function()
    if not Config.VehicleImages or not Config.VehicleImages.enabled then
        notify(_L('vehicle_images_disabled'), 'warning')
        return
    end
    if not screenshotAvailable() then
        notify(_L('screenshot_missing'), 'error')
        return
    end
    local count = 0
    for _, model in ipairs(Config.VehicleImages.preloadModels or {}) do
        if not getCachedVehicleImage(model) then
            queueVehicleImageCapture(model)
            count = count + 1
        end
    end
    notify(_L('capture_started', count), 'inform')
end, false)

CreateThread(function()
    Wait(4500)
    if Config.VehicleImages and Config.VehicleImages.enabled and screenshotAvailable() then
        for _, model in ipairs(Config.VehicleImages.preloadModels or {}) do
            if not getCachedVehicleImage(model) then queueVehicleImageCapture(model) end
        end
    end
end)

CreateThread(function()
    Wait(2000)
    requestGaragesReliable(20, 2500)

    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local inVehicle = IsPedInAnyVehicle(ped, false)
        local textShown = false

        for id, g in pairs(Garages) do
            local openCoords = vec3(g.coords.x, g.coords.y, g.coords.z)
            local openDist = #(pos - openCoords)

            if openDist < Config.DrawDistance then
                sleep = 0
                DrawMarker(Config.Marker.type, openCoords.x, openCoords.y, openCoords.z + 0.15, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    Config.Marker.size.x, Config.Marker.size.y, Config.Marker.size.z,
                    Config.Marker.color.r, Config.Marker.color.g, Config.Marker.color.b, Config.Marker.color.a,
                    false, true, 2, false, nil, nil, false)

                if openDist < Config.InteractDistance then
                    textShown = true
                    lib.showTextUI(('[E] %s öffnen'):format(g.label))
                    if IsControlJustReleased(0, Config.OpenKey) then
                        lib.hideTextUI()
                        openGarage(id)
                    end
                end
            end

            local store = g.store or g.coords
            local storeCoords = vec3(store.x, store.y, store.z)
            local storeDist = #(pos - storeCoords)

            if inVehicle and storeDist < Config.DrawDistance then
                sleep = 0
                DrawMarker((Config.StoreMarker and Config.StoreMarker.type) or Config.Marker.type, storeCoords.x, storeCoords.y, storeCoords.z + 0.15, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    (Config.StoreMarker and Config.StoreMarker.size.x) or Config.Marker.size.x,
                    (Config.StoreMarker and Config.StoreMarker.size.y) or Config.Marker.size.y,
                    (Config.StoreMarker and Config.StoreMarker.size.z) or Config.Marker.size.z,
                    (Config.StoreMarker and Config.StoreMarker.color.r) or 80,
                    (Config.StoreMarker and Config.StoreMarker.color.g) or 255,
                    (Config.StoreMarker and Config.StoreMarker.color.b) or 120,
                    (Config.StoreMarker and Config.StoreMarker.color.a) or 180,
                    false, true, 2, false, nil, nil, false)

                if storeDist < Config.InteractDistance then
                    textShown = true
                    lib.showTextUI(('[E] Fahrzeug in %s einparken'):format(g.label))
                    if IsControlJustReleased(0, Config.OpenKey) then
                        lib.hideTextUI()
                        storeVehicleAtGarage(id)
                    end
                end
            end
        end

        if not textShown then lib.hideTextUI() end
        Wait(sleep)
    end
end)

RegisterNetEvent('esx:playerLoaded', function()
    requestGaragesReliable(10, 1500)
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    requestGaragesReliable(10, 1500)
end)

RegisterNetEvent('esx:setJob', function()
    requestGaragesReliable(10, 1500)
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function()
    requestGaragesReliable(10, 1500)
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    Wait(1000)
    requestGaragesReliable(20, 2500)
end)

RegisterKeyMapping(Config.AdminCommand, 'Garage Admin öffnen', 'keyboard', 'F7')
