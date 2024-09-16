---@class vscoq.TaggedLines
---@field [1] string[]
---@field [2] vscoq.Tag[]
local TaggedLines = {}
TaggedLines.__index = TaggedLines

---@param lines? string[]
---@param tags? vscoq.Tag[]
---@return vscoq.TaggedLines
function TaggedLines.new(lines, tags)
  return setmetatable({ lines or {}, tags or {} }, TaggedLines)
end

---@param line string
function TaggedLines:add_line(line)
  self[1][#self[1] + 1] = line
end

---@param tl vscoq.TaggedLines
function TaggedLines:append(tl)
  local offset = #self[1]
  for _, tag in ipairs(tl[2]) do
    self[2][#self[2] + 1] = {
      offset + tag[1],
      tag[2],
      offset + tag[3],
      tag[4],
      [0] = tag[0],
    }
  end
  for _, line in ipairs(tl[1]) do
    self:add_line(line)
  end
end

return TaggedLines
