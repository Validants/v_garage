Config = {}
Config.Framework = 'auto'
Config.Locale = 'en'
Config.AdminCommand = 'garageadmin'
Config.OpenKey = 38 -- E
Config.DrawDistance = 20.0
Config.InteractDistance = 2.5
Config.StoreDistance = 8.0 -- radius for storing vehicles, should be higher than InteractDistance to allow storing even if not perfectly next to the marker
Config.StoreVehicleDistance = 6.0 -- max distance from spawn point to store a vehicle, prevents storing vehicles that are far away from the garage
Config.VehicleTypes = {
    default = 'car',
    labels = {
        car = 'Fahrzeuge',
        air = 'Flugzeuge',
        boat = 'Boote'
    },
    boatClasses = { [14] = true },
    airClasses = { [15] = true, [16] = true }
}
Config.Debug = false
Config.VehicleKeys = {
    enabled = true,
    system = 'auto',
    giveForOwned = true,
    giveForJob = true,
    customClientEvent = nil,
    customServerEvent = nil
}
Config.VehicleLock = {
    enabled = true,
    command = 'lockvehicle',
    key = 'U',
    distance = 8.0,
    requireKeys = true,
    useNativeFallback = true,
    flashLights = true
}
Config.JobVehicles = {
    platePrefix = 'JOB',
    platePrefixes = {
        police = 'LSPD',
        ambulance = 'EMS',
        mechanic = 'MECH'
    },
    garagePlatePrefixes = {}
}
Config.AdminGroups = {
    esx = { 'admin', 'superadmin' },
    qbcore = { 'admin', 'god' }
}
Config.DefaultBlip = {
    enabled = true,
    sprite = 357,
    scale = 0.75,
    color = 3,
    jobColor = 5
}
Config.Marker = {
    type = 36,
    size = vec3(0.8, 0.8, 0.8),
    color = { r = 80, g = 160, b = 255, a = 180 }
}
Config.StoreMarker = {
    type = 36,
    size = vec3(0.8, 0.8, 0.8),
    color = { r = 80, g = 255, b = 120, a = 180 }
}
Config.Placement = {
    enabled = true,
    startDistance = 3.0,
    minZOffset = -5.0,
    maxZOffset = 5.0,
    moveSpeed = 0.06,
    fastMultiplier = 4.0,
    rotateSpeed = 1.5,
    marker = {
        type = 1,
        size = vec3(1.35, 1.35, 0.18),
        color = { r = 56, g = 189, b = 248, a = 170 }
    },
    spawnMarker = {
        type = 36,
        size = vec3(1.0, 1.0, 1.0),
        color = { r = 250, g = 204, b = 21, a = 210 }
    }
}
Config.VehicleTables = {
    esx = {
        table = 'owned_vehicles',
        owner = 'owner',
        plate = 'plate',
        vehicle = 'vehicle', -- JSON props
        stored = 'stored',
        garage = 'garage'
    },
    qbcore = {
        table = 'player_vehicles',
        owner = 'citizenid',
        plate = 'plate',
        vehicle = 'mods', -- JSON props; many QBCore servers use mods
        model = 'vehicle',
        stored = 'state', -- 1 in garage, 0 out
        garage = 'garage'
    }
}
Config.State = {
    stored = 1,
    out = 0
}
Config.VehicleListing = {
    onlyCurrentGarage = false,
    showOutVehicles = true
}
Config.Impound = {
    enabled = true,
    fee = 500,
    label = 'Impound',
    allowFromEveryPublicGarage = true,
    checkIntervalMinutes = 5
}
Config.VehicleImages = {
    enabled = true,
    captureOnFirstOpen = true,
    preloadModels = {},
    capturePoint = vec4(-75.17, -819.08, 326.18, 180.0),
    cameraOffset = vec3(4.6, -6.8, 2.2),
    cameraFov = 35.0,
    screenshot = {
        encoding = 'jpg',
        quality = 0.82
    }
}
Config.AdminSeeJobGaragesInWorld = false
Config.Garages = {
    -- legion = {
    --     id = 'legion',
    --     label = 'Legion Garage',
    --     type = 'public', -- public | job
    --     vehicleType = 'car', -- car | air | boat
    --     job = nil, 
    --     coords = vec3(215.85, -810.12, 30.73), -- where players can open the garage menu
    --     store = vec4(220.00, -805.00, 30.60, 160.0), -- where players can store their vehicles
    --     spawn = vec4(229.70, -800.10, 30.57, 160.0), -- spawn point for vehicles
    --     blip = true
    -- }
}
