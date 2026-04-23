-- DeKYet: print gate. No-op unless M.DEBUG_LOG=true. Idempotent.
-- Kill-switch: set M.DEBUG_LOG = true to restore prints, or M.ENABLED = false
-- and remove the require from jmz_func.lua to fully disable.

local M = {}
M.ENABLED   = true
M.DEBUG_LOG = false

if M.ENABLED and _G.__DEKYET_DEBUG_LOG_INSTALLED ~= true then
    _G.__DEKYET_DEBUG_LOG_INSTALLED = true
    local _rawPrint = print
    M.RawPrint = _rawPrint
    _rawPrint('[DeKYet] debug_log gate installed (DEBUG_LOG=' .. tostring(M.DEBUG_LOG) .. ')')
    _G.print = function(...)
        if M.DEBUG_LOG then return _rawPrint(...) end
    end
end

return M
