UG = UG or {}

function UG.Debug(...)
    if Config.Debug then
        print('[ug_garage]', ...)
    end
end

function UG.TrimPlate(plate)
    if not plate then return nil end
    return (plate:gsub('^%s*(.-)%s*$', '%1'))
end

function UG.Round(num, decimals)
    local mult = 10 ^ (decimals or 2)
    return math.floor(num * mult + 0.5) / mult
end

function UG.ToVec3(data)
    if type(data) == 'vector3' then return data end
    return vec3(data.x + 0.0, data.y + 0.0, data.z + 0.0)
end

function UG.ToVec4(data)
    if type(data) == 'vector4' then return data end
    return vec4(data.x + 0.0, data.y + 0.0, data.z + 0.0, (data.w or data.h or data.heading or 0.0) + 0.0)
end
