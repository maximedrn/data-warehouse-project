local in_toc = false
local counter = 0

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
  local image = directory .. "/" .. filename .. ".png"

  local file = io.open(mermaid, "w")
  if not file then return nil end
  file:write(code)
  file:close()

  local ok = os.execute(
    "mmdc -i '" .. mermaid .. "' -o '" .. image
    .. "' -b white --quiet 2>/dev/null"
  )
  os.remove(mermaid)

  if not ok then
    io.stderr:write("mmdc failed for: " .. filename .. "\n")
    return nil
  end
  return image
end

function CodeBlock(element)
  if element.attr.classes[1] ~= "mermaid" then return nil end

  counter = counter + 1
  local image = render_mermaid(element.text, "mermaid_" .. counter)
  if not image then return element end

  return pandoc.RawBlock("latex",
    "\\begin{center}\\includegraphics[width=0.95\\textwidth]{"
    .. image .. "}\\end{center}\n")
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
