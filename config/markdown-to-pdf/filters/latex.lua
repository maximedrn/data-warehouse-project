---@class LatexModule
local Latex = {}

--- Escape rules for the ten LaTeX special characters.
--- Backslash is listed first: each replacement string begins with \, so
--- processing \ last would double-escape the backslashes added by other rules.
local ESCAPE_MAP = {
  { pattern = "\\", replacement = "\\textbackslash{}" },
  { pattern = "&", replacement = "\\&" },
  { pattern = "%%", replacement = "\\%%" },
  { pattern = "%$", replacement = "\\$" },
  { pattern = "#", replacement = "\\#" },
  { pattern = "_", replacement = "\\textunderscore " },
  { pattern = "{", replacement = "\\{" },
  { pattern = "}", replacement = "\\}" },
  { pattern = "~", replacement = "\\textasciitilde{}" },
  { pattern = "%^", replacement = "\\textasciicircum{}" },
}

--- tabularx column-spec strings for the three supported alignments.
--- The X column type stretches to fill available width (requires tabularx
--- package). \arraybackslash restores \\ inside the column after the
--- ragged/centering command.
local COLUMN_ALIGN = {
  LEFT = ">{\\raggedright\\arraybackslash}X",
  CENTER = ">{\\centering\\arraybackslash}X",
  RIGHT = ">{\\raggedleft\\arraybackslash}X",
}

--- LaTeX tokens used when building the tabularx environment.
--- Booktabs rules (toprule/midrule/bottomrule) replace \hline for better
--- spacing.
local TEX = {
  TABULARX_OPEN = "\\begin{tabularx}{\\linewidth}{",
  TABULARX_CLOSE = "\\end{tabularx}",
  TOPRULE = "\\toprule",
  MIDRULE = "\\midrule",
  BOTTOMRULE = "\\bottomrule",
  TEXTBF_OPEN = "\\textbf{",
  COL_SEP = " & ",
  ROW_END = " \\\\",
}

--- Escapes a plain-text string so it is safe to embed in LaTeX source.
---
--- Handles all ten special LaTeX characters: \ & % $ # _ { } ~ ^
---
--- @param raw_text string The unescaped input string.
--- @return string The escaped output string.
function Latex.escape(raw_text)
  for _, rule in ipairs(ESCAPE_MAP) do
    raw_text = raw_text:gsub(rule.pattern, rule.replacement)
  end
  return raw_text
end

--- Renders a single Pandoc table cell as a trimmed LaTeX string.
---
--- Wraps the cell's block content in a temporary Pandoc document so that
--- pandoc.write can serialize it to LaTeX, then strips trailing whitespace
--- (pandoc.write adds a trailing newline that would break the cell separator).
---
--- @param cell pandoc.Cell A Pandoc table cell.
--- @return string LaTeX string with trailing whitespace stripped.
function Latex.cell_to_string(cell)
  ---@type string
  local latex_str = pandoc.write(pandoc.Pandoc(cell.contents), "latex")
  -- Parentheses discard the second return value of gsub (substitution count).
  return (latex_str:gsub("%s+$", ""))
end

--- Converts a Pandoc Table element to a LaTeX tabularx environment string.
---
--- - Columns are flexible-width `X` columns respecting the Pandoc colspec.
--- - Header cells are wrapped in \textbf{}.
--- - Horizontal rules use booktabs: \toprule, \midrule, \bottomrule.
---
--- @param tbl pandoc.Table The Pandoc table element.
--- @return string The full LaTeX tabularx block as a string.
function Latex.raw(tbl)
  -- Build one column-spec entry per column, e.g. ">{...}X >{...}X ...".
  ---@type string[]
  local column_specs = {}
  for column_index, colspec in ipairs(tbl.colspecs) do
    -- colspec is a 2-tuple { alignment, width }; index 1 is the alignment
    -- constant.
    local alignment = colspec[1]
    if alignment == pandoc.AlignRight then
      column_specs[column_index] = COLUMN_ALIGN.RIGHT
    elseif alignment == pandoc.AlignCenter then
      column_specs[column_index] = COLUMN_ALIGN.CENTER
    else
      -- AlignLeft and AlignDefault both fall through to left-aligned.
      column_specs[column_index] = COLUMN_ALIGN.LEFT
    end
  end

  -- Accumulate LaTeX lines; joined with \n at the end to avoid repeated
  -- string allocation.
  ---@type string[]
  local latex_lines = {}

  -- Opening: \begin{tabularx}{\linewidth}{<col specs>}
  latex_lines[#latex_lines + 1] = TEX.TABULARX_OPEN
    .. table.concat(column_specs, " ")
    .. "}"
  latex_lines[#latex_lines + 1] = TEX.TOPRULE

  -- Header rows (bold cells), guarded because some tables have no header.
  if tbl.head and tbl.head.rows and #tbl.head.rows > 0 then
    for _, header_row in ipairs(tbl.head.rows) do
      ---@type string[]
      local header_cells = {}
      for _, cell in ipairs(header_row.cells) do
        header_cells[#header_cells + 1] = TEX.TEXTBF_OPEN
          .. Latex.cell_to_string(cell)
          .. "}"
      end
      latex_lines[#latex_lines + 1] = table.concat(header_cells, TEX.COL_SEP)
        .. TEX.ROW_END
    end
    latex_lines[#latex_lines + 1] = TEX.MIDRULE
  end

  -- Body rows (Pandoc may split the body into multiple sections).
  for _, body_section in ipairs(tbl.bodies) do
    for _, body_row in ipairs(body_section.body) do
      ---@type string[]
      local body_cells = {}
      for _, cell in ipairs(body_row.cells) do
        body_cells[#body_cells + 1] = Latex.cell_to_string(cell)
      end
      latex_lines[#latex_lines + 1] = table.concat(body_cells, TEX.COL_SEP)
        .. TEX.ROW_END
    end
  end

  latex_lines[#latex_lines + 1] = TEX.BOTTOMRULE
  latex_lines[#latex_lines + 1] = TEX.TABULARX_CLOSE

  return table.concat(latex_lines, "\n")
end

return Latex
