-- DeKYet: print gate + layer registry.
-- Print gate is a no-op unless M.DEBUG_LOG=true. Idempotent.
-- Each DeKYet module calls M.RegisterLayer(name, enabled) so we can show a
-- single chat banner at game start listing every active layer.
-- Kill-switch: set M.DEBUG_LOG = true to restore prints, or M.ENABLED = false
-- to disable the gate (layer registry still works).

local M = {}
M.ENABLED   = true
M.DEBUG_LOG = false

-- Layer registry: ordered list of {name, enabled}.
if _G.__DEKYET_LAYERS == nil then _G.__DEKYET_LAYERS = {} end
M.layers = _G.__DEKYET_LAYERS

if M.ENABLED and _G.__DEKYET_DEBUG_LOG_INSTALLED ~= true then
    _G.__DEKYET_DEBUG_LOG_INSTALLED = true
    local _rawPrint = print
    M.RawPrint = _rawPrint
    _G.__DEKYET_RAW_PRINT = _rawPrint
    _G.__DEKYET_RAWPRINT  = _rawPrint  -- alias for older module variants
    _rawPrint('[DeKYet] debug_log gate installed (DEBUG_LOG=' .. tostring(M.DEBUG_LOG) .. ')')
    _G.print = function(...)
        if M.DEBUG_LOG then return _rawPrint(...) end
    end
else
    -- gate already installed by an earlier require; reuse the saved raw print
    M.RawPrint = _G.__DEKYET_RAW_PRINT
end

-- Register a layer as loaded. Idempotent on (name).
function M.RegisterLayer(name, enabled)
    for _, l in ipairs(M.layers) do
        if l.name == name then
            l.enabled = enabled
            return
        end
    end
    table.insert(M.layers, { name = name, enabled = enabled })
    if M.RawPrint then
        M.RawPrint('[DeKYet] layer loaded: ' .. name .. ' (ENABLED=' .. tostring(enabled) .. ')')
    end
end

-- One-line summary suitable for chat.
function M.GetStatusLine()
    if #M.layers == 0 then
        return '[DeKYet] no layers registered'
    end
    local parts = {}
    for _, l in ipairs(M.layers) do
        if l.enabled then
            table.insert(parts, l.name)
        else
            table.insert(parts, l.name .. '(off)')
        end
    end
    return '[DeKYet] active layers: ' .. table.concat(parts, ', ')
end

-- Self-register the always-on patches that don't have their own module.
M.RegisterLayer('retreat_fix', true)

return M
