-- Luacheck configuration for the pandoc Lua filter project.

std = "lua54"

-- Pandoc injects these globals at runtime.
globals = { "pandoc", "PANDOC_SCRIPT_FILE" }

max_line_length = 79

-- 212: unused argument — expected for _list, _* convention.
ignore = { "212" }

-- Per-file overrides: only pandoc_filter.lua sees PANDOC_SCRIPT_FILE.
files = {
  ["filters/pandoc_filter.lua"] = {
    globals = { "pandoc", "PANDOC_SCRIPT_FILE" },
  },
  ["filters/config.lua"] = { globals = {} },
  ["filters/logger.lua"] = { globals = {} },
  ["filters/state.lua"] = { globals = {} },
  ["filters/latex.lua"] = { globals = { "pandoc" } },
  ["filters/mermaid.lua"] = { globals = {} },
}
