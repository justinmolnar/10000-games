# Offline Tutorial: Fix Browser Content Rendering

## Goal
Debug and fix the web browser that shows backgrounds/graphics but not text content.

## Difficulty: Hard (Investigation required, 3-5 hours)

## Files to Study First
- `src/states/web_browser_state.lua` - Browser state logic
- `src/views/web_browser_view.lua` - Browser rendering
- `src/utils/html_renderer.lua` - HTML to graphics
- `src/utils/html_layout.lua` - Layout calculation
- `src/utils/html_parser.lua` - HTML parsing

## The Problem

The browser shows:
- Window chrome (address bar, buttons) ✓
- Background colors ✓
- Images/graphics (maybe) ✓
- **Text content** ✗

This suggests the layout and rendering pipeline works, but text specifically isn't rendering.

---

## Debugging Strategy

### Step 1: Add Diagnostic Prints

Start in `html_renderer.lua`. Find where text is drawn and add prints:

```lua
function HTMLRenderer:drawText(node, x, y, width)
    print("[HTMLRenderer] drawText called:")
    print("  text:", node.text or node.content or "nil")
    print("  position:", x, y)
    print("  width:", width)

    -- ... existing draw code ...
end
```

### Step 2: Check if Text Nodes Exist

In the parser or layout phase, verify text nodes are created:

```lua
-- In html_parser.lua or wherever nodes are created
function HTMLParser:createTextNode(text)
    print("[HTMLParser] Creating text node:", text:sub(1, 50))
    return {
        type = "text",
        content = text
    }
end
```

### Step 3: Run and Check Output

1. Run the game: `love .`
2. Open the browser
3. Navigate to any page
4. Check console output

**What to look for:**
- "Creating text node" messages → Parser working
- "drawText called" messages → Renderer trying to draw
- No messages → Text nodes not reaching renderer

---

## Common Causes and Fixes

### Cause 1: Font Not Loaded

Text draws nothing if font is nil or failed to load.

**Check:**
```lua
-- In html_renderer.lua or wherever font is set
print("Font:", self.font)
if not self.font then
    print("ERROR: Font is nil!")
end
```

**Fix:**
```lua
-- Ensure font is loaded with fallback
self.font = love.graphics.newFont(font_path, size)
if not self.font then
    print("Font load failed, using default")
    self.font = love.graphics.getFont()
end
```

### Cause 2: Text Color Same as Background

If text color is white on white, or black on black.

**Check:**
```lua
function HTMLRenderer:drawText(node, x, y, width)
    local r, g, b, a = love.graphics.getColor()
    print("Text color:", r, g, b, a)
    -- ...
end
```

**Fix:**
```lua
-- Ensure text color is set before drawing
love.graphics.setColor(0, 0, 0, 1)  -- Black text
love.graphics.print(text, x, y)
```

### Cause 3: Text Position Off-Screen

Layout might calculate wrong positions.

**Check:**
```lua
function HTMLRenderer:drawText(node, x, y, width)
    print("Drawing at:", x, y)
    if x < 0 or y < 0 or x > 2000 or y > 2000 then
        print("WARNING: Text position seems wrong!")
    end
    -- ...
end
```

**Fix:** Trace back through layout calculation to find where positions go wrong.

### Cause 4: Text Width is Zero

If layout calculates zero width, text might be clipped.

**Check:**
```lua
if width <= 0 then
    print("WARNING: Text width is zero or negative:", width)
end
```

### Cause 5: Scissor Clipping

Text might be drawn outside the scissor region.

**Check:**
```lua
local sx, sy, sw, sh = love.graphics.getScissor()
print("Scissor:", sx, sy, sw, sh)
print("Drawing text at:", x, y)
if x < sx or y < sy or x > sx + sw or y > sy + sh then
    print("WARNING: Text outside scissor!")
end
```

### Cause 6: Text Nodes Filtered Out

The rendering loop might skip text nodes.

**Check:**
```lua
-- In the main render loop
for i, node in ipairs(nodes) do
    print("Rendering node type:", node.type or "unknown")
    if node.type == "text" then
        print("  -> Text content:", node.content)
    end
end
```

### Cause 7: Empty Text Content

Text nodes might have empty strings.

**Check:**
```lua
if not node.content or node.content == "" or node.content:match("^%s*$") then
    print("WARNING: Empty text node")
    return
end
```

---

## Systematic Debug Approach

### Phase 1: Verify Parsing

Add to `html_parser.lua`:
```lua
function HTMLParser:parse(html)
    print("=== PARSING HTML ===")
    print("Input length:", #html)

    local result = self:_parse(html)

    print("Parsed nodes:", self:countNodes(result))
    print("Text nodes:", self:countTextNodes(result))

    return result
end

function HTMLParser:countNodes(node, count)
    count = count or 0
    count = count + 1
    for _, child in ipairs(node.children or {}) do
        count = self:countNodes(child, count)
    end
    return count
end

function HTMLParser:countTextNodes(node, count)
    count = count or 0
    if node.type == "text" then
        count = count + 1
    end
    for _, child in ipairs(node.children or {}) do
        count = self:countTextNodes(child, count)
    end
    return count
end
```

**Expected:** "Text nodes: X" where X > 0

### Phase 2: Verify Layout

Add to `html_layout.lua`:
```lua
function HTMLLayout:layout(node)
    print("=== LAYOUT PHASE ===")

    local result = self:_layout(node)

    self:debugPrintLayout(result, 0)

    return result
end

function HTMLLayout:debugPrintLayout(node, indent)
    local prefix = string.rep("  ", indent)
    print(prefix .. (node.type or "?") .. " at " ..
          (node.x or "?") .. "," .. (node.y or "?") ..
          " size " .. (node.width or "?") .. "x" .. (node.height or "?"))

    if node.type == "text" then
        print(prefix .. "  text: " .. (node.content or ""):sub(1, 30))
    end

    for _, child in ipairs(node.children or {}) do
        self:debugPrintLayout(child, indent + 1)
    end
end
```

**Expected:** Text nodes have reasonable x, y, width, height values

### Phase 3: Verify Rendering

Add to `html_renderer.lua`:
```lua
function HTMLRenderer:render(layout)
    print("=== RENDER PHASE ===")
    self.text_draws = 0

    self:_render(layout)

    print("Text draw calls:", self.text_draws)
end

-- In the actual text drawing function:
function HTMLRenderer:drawTextNode(node)
    self.text_draws = (self.text_draws or 0) + 1
    print("Drawing text #" .. self.text_draws .. ":",
          (node.content or ""):sub(1, 30))

    -- ... actual drawing ...
end
```

**Expected:** "Text draw calls: X" where X > 0, and "Drawing text" messages

---

## Once You Find the Issue

### If Parser Issue:
- Check HTML string is being passed correctly
- Check text extraction regex/logic
- Check whitespace handling

### If Layout Issue:
- Check dimension calculations
- Check parent/child coordinate transforms
- Check CSS property application

### If Render Issue:
- Check font is loaded
- Check color is set
- Check scissor region
- Check coordinate transform

---

## Test HTML

Create a simple test page to isolate the issue:

```lua
-- In browser state or a test function
local test_html = [[
<html>
<body>
<h1>Hello World</h1>
<p>This is a test paragraph.</p>
</body>
</html>
]]

self:loadHTML(test_html)
```

If this doesn't render text either, the issue is in your rendering pipeline, not in loading external pages.

---

## Quick Fixes to Try

### Force Text Color
```lua
-- Before any text draw
love.graphics.setColor(0, 0, 0, 1)
```

### Force Font
```lua
-- At start of render
love.graphics.setFont(love.graphics.getFont())
```

### Disable Scissor
```lua
-- Temporarily disable to test
love.graphics.setScissor()
```

### Draw Debug Rectangle
```lua
-- Draw where text should be
love.graphics.setColor(1, 0, 0, 0.5)
love.graphics.rectangle("fill", x, y, width, height)
love.graphics.setColor(0, 0, 0, 1)
love.graphics.print(text, x, y)
```

---

## Architecture Notes

The browser system has multiple layers:

```
URL Input
    ↓
URL Resolver (resolves relative paths)
    ↓
File/Asset Loader (loads HTML content)
    ↓
HTML Parser (HTML string → DOM tree)
    ↓
CSS Parser (extracts/applies styles)
    ↓
HTML Layout (DOM tree → positioned boxes)
    ↓
HTML Renderer (positioned boxes → graphics)
```

The bug could be at any layer. Systematic debugging means checking each layer's output.

---

## Common Issues Table

| Symptom | Likely Cause | Check |
|---------|--------------|-------|
| No text at all | Font nil | Print font object |
| Text in wrong place | Layout coords wrong | Print x, y values |
| Text clipped | Scissor too small | Print scissor rect |
| Invisible text | Color = background | Print RGBA values |
| Some text missing | Nodes filtered | Print all node types |
| Garbled text | Encoding issue | Check UTF-8 handling |

---

## Key Patterns Learned

- **Systematic debugging:** Check each pipeline stage
- **Print debugging:** When you can't use a debugger
- **Isolation testing:** Use simple test cases
- **Layer by layer:** DOM → Layout → Render
