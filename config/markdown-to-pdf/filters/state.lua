--- Mutable runtime state. No business logic.
-- @module state

---@class StateModule
local State = {}

--- True when the last heading processed was identified as a TOC heading.
--- Used to suppress the list that Pandoc generates from a Markdown TOC.
---@type boolean
State.is_after_toc_heading = false

--- Counter incremented for each mermaid diagram, used to build unique
--- filenames.
---@type integer
State.mermaid_diagram_count = 0

--- Resets all state fields to their initial values.
---
--- @return nil
function State.reset()
  State.is_after_toc_heading = false
  State.mermaid_diagram_count = 0
end

return State
