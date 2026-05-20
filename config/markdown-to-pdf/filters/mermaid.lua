--- Mermaid diagram rendering via the mmdc CLI. Stateless except for injected
--- deps.
-- @module mermaid

---@class MermaidModule
local Mermaid = {}

-- Dependencies injected by pandoc_filter.lua via Mermaid.init(); never
-- require() here.
---@type ConfigModule
local _Config
---@type LoggerModule
local _Logger
---@type StateModule
local _State

--- Injects runtime dependencies. Must be called once before any other
--- function.
---
--- @param Config ConfigModule The config module (constants and paths).
--- @param Logger LoggerModule The logger module (error/warn/info).
--- @param State StateModule The state module (mutable counters and flags).
--- @return nil
function Mermaid.init(Config, Logger, State)
  _Config = Config
  _Logger = Logger
  _State = State
end

--- Increments the diagram counter and returns the next unique base filename.
---
--- @return string Base filename (no extension) for the next diagram.
function Mermaid.next_filename()
  _State.mermaid_diagram_count = _State.mermaid_diagram_count + 1
  return _Config.mermaid.file_prefix .. _State.mermaid_diagram_count
end

--- Renders a Mermaid diagram source to a PDF file via the mmdc CLI.
---
--- Writes the diagram source to a temporary .mmd file, invokes mmdc to
--- produce a PDF, then removes the temporary source file.
---
--- @param diagram_source string Raw Mermaid diagram source code.
--- @param base_filename string Base name (no extension) for temp files.
--- @return string|nil Absolute path to the produced PDF, or nil if rendering
---   failed.
function Mermaid.render(diagram_source, base_filename)
  -- TMPDIR is set on macOS/Linux; TEMP is the Windows equivalent.
  ---@type string
  local temp_directory = os.getenv("TMPDIR") or os.getenv("TEMP") or "/tmp"

  ---@type string
  local mmd_path = temp_directory .. "/" .. base_filename .. ".mmd"
  ---@type string
  local pdf_path = temp_directory .. "/" .. base_filename .. ".pdf"

  local temp_file = io.open(mmd_path, "w")
  if not temp_file then
    _Logger.error("cannot open temp file for writing: " .. mmd_path)
    return nil
  end
  temp_file:write(diagram_source)
  temp_file:close()

  -- Stderr is silenced; success or failure is determined by the exit code
  -- alone.
  ---@type string
  local mmdc_command = table.concat({
    "mmdc",
    "-i '" .. mmd_path .. "'",
    "-o '" .. pdf_path .. "'",
    "-b " .. _Config.mermaid.background_color,
    "--quiet",
    "-w " .. _Config.mermaid.render_width,
    "-c '" .. _Config.mermaid.config_path .. "'",
    "2>/dev/null",
  }, " ")

  ---@type boolean|nil
  local success = os.execute(mmdc_command)

  os.remove(mmd_path)

  if not success then
    _Logger.error("mmdc failed for diagram: " .. base_filename)
    return nil
  end

  return pdf_path
end

return Mermaid
