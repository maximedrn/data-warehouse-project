---@meta pandoc
--- EmmyLua type stubs for the pandoc Lua API (subset used by this project).

---@class pandoc.Alignment Opaque alignment constant.

--- Two-element array describing one column: { alignment, width }.
---@class pandoc.ColSpec
---@field [1] pandoc.Alignment Column alignment.
---@field [2] number|string  Relative column width or "ColWidthDefault".

---@class pandoc.Inline An inline-level pandoc element.
---@class pandoc.Block A block-level pandoc element.

---@alias pandoc.Inlines pandoc.Inline[]
---@alias pandoc.Blocks pandoc.Block[]

---@class pandoc.Cell
---@field contents pandoc.Blocks Block content of the cell.

---@class pandoc.Row
---@field cells pandoc.Cell[] Cells in the row.

---@class pandoc.TableHead
---@field rows pandoc.Row[] Header rows.

---@class pandoc.TableBody
---@field body pandoc.Row[] Data rows.
---@field head pandoc.Row[] Row-head cells (optional).

---@class pandoc.Table
---@field colspecs pandoc.ColSpec[] Per-column alignment and width specs.
---@field head pandoc.TableHead Header section.
---@field bodies pandoc.TableBody[] Body sections (usually one).

---@class pandoc.Attr
---@field identifier string Element id.
---@field classes string[] CSS-like class list.
---@field attributes table<string,string> Key-value pairs.

---@class pandoc.Header
---@field level integer Heading depth (1 = top-level).
---@field content pandoc.Inlines Inline content of the heading text.
---@field attr pandoc.Attr Attributes (id, classes, key-value).

---@class pandoc.CodeBlock
---@field text string Verbatim source text.
---@field attr pandoc.Attr Attributes — classes[1] holds the language tag.

---@class pandoc.BulletList
---@class pandoc.OrderedList

---@class pandoc.RawBlock
---@field format string Target format identifier (e.g. "latex").
---@field text string Raw markup string.

---@class pandoc.PandocDoc
---@field blocks pandoc.Block[]

---@class pandoc.Utils
local PandocUtils = {}

--- Converts any pandoc element (or bare string) to a plain text string.
---@param element any
---@return string
function PandocUtils.stringify(element) end

---@class PandocModule
---@field AlignLeft pandoc.Alignment|nil
---@field AlignRight pandoc.Alignment|nil
---@field AlignCenter pandoc.Alignment|nil
---@field AlignDefault pandoc.Alignment|nil
---@field utils pandoc.Utils
local PandocModule = {}

---@param blocks pandoc.Block[]
---@return pandoc.PandocDoc
function PandocModule.Pandoc(blocks) end

---@param format string
---@param text string
---@return pandoc.RawBlock
function PandocModule.RawBlock(format, text) end

---@param document pandoc.PandocDoc
---@param format string
---@return string
function PandocModule.write(document, format) end

--- The pandoc module, injected as a global by the pandoc runtime.
---@type PandocModule
pandoc = {
  AlignLeft = nil,
  AlignRight = nil,
  AlignCenter = nil,
  AlignDefault = nil,
  utils = PandocUtils,
}
---@type string
PANDOC_SCRIPT_FILE = ""
