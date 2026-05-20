--- Pandoc Lua filter entry point. Requires all modules and defines filter functions.

---@type string
local SCRIPT_DIR = PANDOC_SCRIPT_FILE:match("(.*/)")
package.path = SCRIPT_DIR .. "?.lua;" .. package.path

---@type ConfigModule
local Config = require("config")
---@type LoggerModule
local Logger = require("logger")
---@type StateModule
local State = require("state")
---@type LatexModule
local Latex = require("latex")
---@type MermaidModule
local Mermaid = require("mermaid")

-- Set the runtime config path now that SCRIPT_DIR is known.
Config.mermaid.config_path = SCRIPT_DIR .. Config.mermaid.config_filename

Mermaid.init(Config, Logger, State)

-- ---------------------------------------------------------------------------
-- filter_Table
-- ---------------------------------------------------------------------------

--- Converts a Pandoc Table element to a LaTeX tabularx environment.
---
--- @param  tbl  pandoc.Table  The Pandoc table element.
--- @return pandoc.RawBlock    A raw LaTeX block.
local function filter_Table(tbl)
  return pandoc.RawBlock("latex", Latex.raw(tbl))
end

-- ---------------------------------------------------------------------------
-- filter_CodeBlock
-- ---------------------------------------------------------------------------

--- Renders a `mermaid` fenced code block as an embedded LaTeX figure.
---
--- Non-mermaid blocks are left unchanged (returns nil).
--- On rendering failure the original code block is returned as a fallback.
---
--- @param  block  pandoc.CodeBlock  The Pandoc code block element.
--- @return pandoc.RawBlock|pandoc.CodeBlock|nil
local function filter_CodeBlock(block)
  if block.attr.classes[1] ~= Config.mermaid.class_name then
    return nil
  end

  ---@type string
  local diagram_filename = Mermaid.next_filename()
  ---@type string|nil
  local pdf_path = Mermaid.render(block.text, diagram_filename)

  if not pdf_path then
    return block
  end

  ---@type string
  local latex_figure = table.concat({
    "\\begin{center}",
    "\\adjustbox{max width=" .. Config.diagram.max_width
      .. ", max totalheight=" .. Config.diagram.max_height .. "}"
      .. "{\\includegraphics{" .. pdf_path .. "}}",
    "\\end{center}",
    "",
  }, "\n")

  return pandoc.RawBlock("latex", latex_figure)
end

-- ---------------------------------------------------------------------------
-- filter_Header
-- ---------------------------------------------------------------------------

--- Maps Pandoc heading levels to custom LaTeX macros.
---
--- Level 1  →  \SessionTitle{…}   (Config.latex.macro_title)
--- Level 2  →  \tableofcontents + \newpage  (when text matches TOC keywords)
---          →  \Section{…}                  (Config.latex.macro_section)
--- Level 3  →  \SubSection{…}              (Config.latex.macro_subsection)
--- Level 4+ →  \textbf{…}\par
---
--- @param  heading  pandoc.Header  The Pandoc header element.
--- @return pandoc.RawBlock         A raw LaTeX block.
local function filter_Header(heading)
  ---@type string
  local heading_text = Latex.escape(pandoc.utils.stringify(heading.content))
  ---@type string
  local heading_text_lower = heading_text:lower()

  State.is_after_toc_heading = false

  if heading.level == 1 then
    return pandoc.RawBlock("latex", Config.latex.macro_title .. "{" .. heading_text .. "}\n")

  elseif heading.level == 2 then
    local is_toc_heading = heading_text_lower:find(Config.toc.keyword_1)
      and heading_text_lower:find(Config.toc.keyword_2)

    if is_toc_heading then
      State.is_after_toc_heading = true
      return pandoc.RawBlock("latex", "\\tableofcontents\n\\newpage\n")
    end

    return pandoc.RawBlock("latex", Config.latex.macro_section .. "{" .. heading_text .. "}\n")

  elseif heading.level == 3 then
    return pandoc.RawBlock(
      "latex",
      Config.latex.macro_subsection .. "{" .. heading_text .. "}\n"
    )

  else
    return pandoc.RawBlock("latex", "\\textbf{" .. heading_text .. "}\\par\n")
  end
end

-- ---------------------------------------------------------------------------
-- filter_BulletList / filter_OrderedList
-- ---------------------------------------------------------------------------

--- Suppresses the bullet list that immediately follows a TOC heading.
---
--- @param  _list  pandoc.BulletList  The list element (unused).
--- @return table|nil                 Empty block to suppress, or nil to pass through.
local function filter_BulletList(_list)
  if State.is_after_toc_heading then
    State.is_after_toc_heading = false
    return {}
  end
  return nil
end

--- Suppresses the ordered list that immediately follows a TOC heading.
---
--- @param  _list  pandoc.OrderedList  The list element (unused).
--- @return table|nil                  Empty block to suppress, or nil to pass through.
local function filter_OrderedList(_list)
  if State.is_after_toc_heading then
    State.is_after_toc_heading = false
    return {}
  end
  return nil
end

-- ---------------------------------------------------------------------------
-- Pipeline
-- ---------------------------------------------------------------------------

-- Each sub-table is a separate pandoc traversal pass; order matters for
-- state propagation (Header must run before BulletList/OrderedList).
return {
  { Table = filter_Table },
  { CodeBlock = filter_CodeBlock },
  { Header = filter_Header },
  { BulletList = filter_BulletList },
  { OrderedList = filter_OrderedList },
}
