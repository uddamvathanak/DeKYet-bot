-- Centralized debug-print gate.
-- Toggle DEBUG_LOG to true to re-enable all print() calls used as debug traces
-- across the bot scripts. When false (default), print() becomes a no-op so the
-- Lua VM does not pay string-formatting / IO cost in hot paths.
--
-- This file is idempotent: requiring it multiple times only installs the
-- override once. Scripts that still want to emit text regardless of the flag
-- should use io.write or the returned `RawPrint` reference below.

local M = {}

M.DEBUG_LOG = false

if _G.__JMZ_DEBUG_LOG_INSTALLED ~= true then
    _G.__JMZ_DEBUG_LOG_INSTALLED = true
    local _rawPrint = print
    M.RawPrint = _rawPrint
    _G.print = function(...)
        if M.DEBUG_LOG then
            return _rawPrint(...)
        end
    end
end

return M
