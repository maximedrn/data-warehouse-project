--- Logging helpers. No state, no config values.
-- @module logger

---@class LoggerModule
local Logger = {}

--- Writes an error message to stderr.
---
--- @param message string Message to log.
--- @return nil
function Logger.error(message)
  io.stderr:write("pandoc_filter [ERROR]: " .. message .. "\n")
end

--- Writes a warning message to stderr.
---
--- @param message string  Message to log.
--- @return nil
function Logger.warn(message)
  io.stderr:write("pandoc_filter [WARN]: " .. message .. "\n")
end

--- Writes an informational message to stderr.
---
--- @param message string  Message to log.
--- @return nil
function Logger.info(message)
  io.stderr:write("pandoc_filter [INFO]: " .. message .. "\n")
end

return Logger
