local in_toc = false
local counter = 0

local script_directory = PANDOC_SCRIPT_FILE:match("(.*/)")
local mermaid_config = script_directory .. "config.json"

local function latex_escape(text)
  text = text:gsub("\\", "\\textbackslash{}")
  text = text:gsub("&", "\\&")
  text = text:gsub("%%", "\\%%")
  text = text:gsub("%$", "\\$")
  text = text:gsub("#", "\\#")
  text = text:gsub("_", "\\textunderscore ")
  text = text:gsub("{", "\\{")
  text = text:gsub("}", "\\}")
  text = text:gsub("~", "\\textasciitilde{}")
  text = text:gsub("%^", "\\textasciicircum{}")
  return text
end

local function render_mermaid(code, filename)
  local directory = os.getenv("TMPDIR") or os.getenv("TEMP") or "/tmp"
  local mermaid = directory .. "/" .. filename .. ".mmd"
  local pdf     = directory .. "/" .. filename .. ".pdf"

  local file = io.open(mermaid, "w")
  if not file then return nil end
  file:write(code)
  file:close()

  local ok = os.execute(
    "mmdc -i '" .. mermaid .. "' -o '" .. pdf
    .. "' -b white --quiet -w 4000"
    .. " -c '" .. mermaid_config .. "'"
    .. " 2>/dev/null"
  )
  os.remove(mermaid)

  if not ok then
    io.stderr:write("mmdc failed for: " .. filename .. "\n")
    return nil
  end

  return pdf
end

function Table(element)
  local function cell_to_latex(cell)
    local string = pandoc.write(pandoc.Pandoc(cell.contents), "latex")
    return string:gsub("%s+$", "")
  end

  local columns = {}
  for i, column_spec in ipairs(element.colspecs) do
    local align = column_spec[1]
    if align == pandoc.AlignRight then
      columns[i] = ">{\\raggedleft\\arraybackslash}X"
    elseif align == pandoc.AlignCenter then
      columns[i] = ">{\\centering\\arraybackslash}X"
    else
      columns[i] = ">{\\raggedright\\arraybackslash}X"
    end
  end

  local lines = {}
  lines[#lines + 1] = "\\begin{tabularx}{\\linewidth}{" .. table.concat(columns, " ") .. "}"
  lines[#lines + 1] = "\\toprule"

  if element.head and element.head.rows and #element.head.rows > 0 then
    for _, row in ipairs(element.head.rows) do
      local cells = {}
      for _, cell in ipairs(row.cells) do
        cells[#cells + 1] = "\\textbf{" .. cell_to_latex(cell) .. "}"
      end
      lines[#lines + 1] = table.concat(cells, " & ") .. " \\\\"
    end
    lines[#lines + 1] = "\\midrule"
  end

  for _, body in ipairs(element.bodies) do
    for _, row in ipairs(body.body) do
      local cells = {}
      for _, cell in ipairs(row.cells) do
        cells[#cells + 1] = cell_to_latex(cell)
      end
      lines[#lines + 1] = table.concat(cells, " & ") .. " \\\\"
    end
  end

  lines[#lines + 1] = "\\bottomrule"
  lines[#lines + 1] = "\\end{tabularx}"

  return pandoc.RawBlock("latex", table.concat(lines, "\n"))
end

function CodeBlock(element)
  if element.attr.classes[1] ~= "mermaid" then return nil end

  counter = counter + 1
  local image = render_mermaid(element.text, "mermaid_" .. counter)
  if not image then return element end

  return pandoc.RawBlock("latex",
    "\\begin{center}\\adjustbox{max width=0.95\\textwidth, max totalheight=0.9\\textheight}{\\includegraphics{"
    .. image .. "}}\\end{center}\n")
end

function Header(element)
  local text = latex_escape(pandoc.utils.stringify(element.content))
  in_toc = false

  if element.level == 1 then
    return pandoc.RawBlock("latex",
      "\\SessionTitle{" .. text .. "}\n")
  elseif element.level == 2 then
    if text:lower():find("table") and text:lower():find("mati") then
      in_toc = true
      return pandoc.RawBlock("latex",
        "\\tableofcontents\n\\newpage\n")
    end
    return pandoc.RawBlock("latex",
      "\\Section{" .. text .. "}\n")
  elseif element.level == 3 then
    return pandoc.RawBlock("latex",
      "\\SubSection{" .. text .. "}\n")
  else
    return pandoc.RawBlock("latex",
      "\\textbf{" .. text .. "}\\par\n")
  end
end

function BulletList(element)
  if in_toc then
    in_toc = false
    return {}
  end
  return nil
end

function OrderedList(element)
  if in_toc then
    in_toc = false
    return {}
  end
  return nil
end
