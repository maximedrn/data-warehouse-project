---@class ConfigModule
local Config = {}

--- Mermaid CLI rendering options.
Config.mermaid = {
  render_width = 4000,
  background_color = "white",
  file_prefix = "mermaid_",
  --- Fenced code block class tag recognized by filter_CodeBlock.
  class_name = "mermaid",
  --- Filename of the mmdc JSON config, expected beside pandoc_filter.lua.
  config_filename = "config.json",
  --- Absolute path set at runtime by pandoc_filter.lua.
  config_path = "",
}

--- Diagram sizing constraints inside the LaTeX document.
Config.diagram = {
  max_width = "0.95\\textwidth",
  max_height = "0.9\\textheight",
}

--- Keywords used to detect a Table-of-Contents heading.
Config.toc = {
  keyword_1 = "table",
  keyword_2 = "mati",
}

--- Custom LaTeX macro names declared in the document template.
--- Changing a name here requires the matching change in the .tex file.
Config.latex = {
  macro_title      = "\\SessionTitle",
  macro_section    = "\\Section",
  macro_subsection = "\\SubSection",
}

return Config
