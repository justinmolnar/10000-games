# HTML/CSS Rendering System - Rules and Implementation Guide

This document details the critical rules and patterns discovered while implementing the HTML/CSS rendering system for the web browser. These rules were learned through extensive debugging and must be followed to avoid breaking the layout engine.

---

## 1. HTML Parser (`src/utils/html_parser.lua`)

### Purpose
Parse HTML 3.2-era markup into a DOM tree structure.

### Key Rules

#### 1.1 Void Elements
The following elements are self-closing and never have children:
```lua
br, hr, img, input, meta, link, area, base, col, param
```

#### 1.2 Tag Name Parsing
- Tag names are **case-insensitive** (converted to lowercase)
- Attribute names are **case-insensitive** (converted to lowercase)
- Attribute values **preserve case**

#### 1.3 Attribute Parsing Formats
Supports multiple attribute formats:
```html
<input disabled>           <!-- Boolean attribute: disabled = true -->
<img src="image.png">      <!-- Quoted value -->
<img src='image.png'>      <!-- Single-quoted value -->
<input type=text>          <!-- Unquoted value -->
```

#### 1.4 Special Content Handling
`<script>` and `<style>` tags capture **raw content** (no parsing of inner HTML):
- Content is captured as-is until closing tag
- No entity decoding or HTML parsing inside these tags
- If closing tag is missing, captures rest of document

#### 1.5 HTML Entity Decoding
Supported entities (decoded in text nodes):
```
&lt;     → <
&gt;     → >
&amp;    → &
&quot;   → "
&apos;   → '
&nbsp;   → (space)
&#39;    → '
&#34;    → "
&copy;   → ©
```

#### 1.6 DOM Structure
Each element node has:
```lua
{
    tag = "tagname",           -- lowercase tag name
    attributes = {             -- key-value pairs
        href = "url",
        class = "classname"
    },
    children = {}              -- array of child nodes
}
```

Text nodes have:
```lua
{
    type = "text",
    content = "text content"
}
```

Comment nodes have:
```lua
{
    type = "comment",
    content = "comment text"
}
```

---

## 2. CSS Parser (`src/utils/css_parser.lua`)

### Purpose
Parse basic CSS (colors, fonts, box model) into property objects.

### Key Rules

#### 2.1 Color Parsing
Supports three formats:

**Named Colors:**
```css
color: red;
background-color: blue;
```
Supported names: black, white, red, green, blue, yellow, cyan, magenta, gray, grey, silver, maroon, olive, lime, aqua, teal, navy, fuchsia, purple, orange

**Hex Colors:**
```css
color: #FF0000;        /* 6-digit hex */
color: #F00;           /* 3-digit shorthand (expanded to #FF0000) */
```

**RGB Colors:**
```css
color: rgb(255, 0, 0);
```

All colors are normalized to uppercase hex (#RRGGBB) internally, then converted to LÖVE RGB tables {r, g, b} with values 0.0-1.0.

#### 2.2 Size Parsing
Supports multiple units:

```css
font-size: 16px;       /* Pixels (1:1) */
font-size: 12pt;       /* Points (1pt = 1.333px) */
font-size: 1.5em;      /* Em units (1em = 16px) */
font-size: 14;         /* Unitless (assumes pixels) */
```

All sizes are normalized to **pixels** internally.

#### 2.3 Box Model Values
Supports CSS shorthand for margin/padding:

```css
margin: 10px;                    /* All sides: {10, 10, 10, 10} */
margin: 10px 20px;               /* Vertical, Horizontal: {10, 20, 10, 20} */
margin: 10px 20px 30px 40px;    /* Top, Right, Bottom, Left: {10, 20, 30, 40} */
```

Internally stored as 4-value arrays: `{top, right, bottom, left}`

#### 2.4 Inline Styles
Parse inline `style` attributes:
```html
<p style="color: red; font-size: 14px;">Text</p>
```

Returns same property table format as stylesheet rules.

#### 2.5 CSS Comments
Supports `/* ... */` style comments (ignored during parsing).

---

## 3. HTML Layout Engine (`src/utils/html_layout.lua`)

### Purpose
Calculate positions and sizes for DOM elements using a box model layout system.

### Key Rules

#### 3.1 Block vs Inline Elements

**Block Elements** (stack vertically, take full width):
```
html, body, div, p, h1-h6, ul, ol, li, hr, table, tr, td, th, head, title
```

**Inline Elements** (flow horizontally, wrap at line end):
```
span, a, b, i, u, strong, em, img
```

#### 3.2 Non-Rendering Elements
These elements are skipped during layout:
```
head, title, style, script
```

#### 3.3 CSS Inheritance Rules

**CRITICAL: Properties that DO NOT inherit to children:**
- `border`
- `margin`
- `padding`
- `width`
- `height`
- `background-color`
- `display`

**Properties that DO inherit:**
- `color`
- `font-size`
- `font-family`
- `font-weight`
- `font-style`
- `text-align`
- `text-decoration`

**NEVER let text nodes inherit box-model properties.** Text nodes should only receive text-related styles (color, font-size, etc.).

#### 3.4 Text Node Style Filtering
When creating styles for text nodes in inline layout, explicitly filter out box model properties:

```lua
local text_styles = {}
for k, v in pairs(parent_styles) do
    if k ~= "border" and k ~= "margin" and k ~= "padding" and
       k ~= "width" and k ~= "height" and k ~= "background-color" then
        text_styles[k] = v
    end
end
```

**Why:** Text nodes in bordered containers (like `<p style="border: 1px solid">word word word</p>`) were showing borders on every word when box-model properties inherited.

#### 3.5 Block Layout Child Positioning

**CRITICAL RULE:** When positioning children in block layout, use the child's **actual Y coordinate** (which includes top margin applied inside layoutElement), not the accumulated Y position.

**CORRECT:**
```lua
child_y = child_layout.y + child_layout.height
```

**WRONG (causes overlapping):**
```lua
child_y = child_y + child_layout.height
```

**Why:** `layoutElement()` adds top margin inside the function (`layout.y = y + margin[1]`), so the child's Y coordinate already accounts for its top margin. Using `child_y + child_layout.height` ignores this margin shift, causing elements like `<hr>` and bordered sections to have following content overlap them.

#### 3.6 HR Element Layout
HR elements:
- Return early after calculating height (don't add bottom margin in layoutElement)
- Height = `(styles.height or 2) + padding[1] + padding[3]`
- Content height = `styles.height or 2` (just the line, no padding)
- Parent's block layout handles vertical spacing via margins

#### 3.7 List Item Layout
List items (`<li>`) use **inline layout** for their children, not block layout. This allows text and links to flow horizontally within the list item.

#### 3.8 Text Wrapping
Text wrapping splits text into words and measures each word to fit within available width:
- Splits on whitespace (`%S+` pattern)
- Attempts to fit words on current line
- Breaks to new line when word doesn't fit
- Empty lines are never created (skipped)

#### 3.9 Text Alignment (Center/Right)
Text alignment is a **post-layout adjustment** applied after calculating positions:
- Layout phase: Calculate X positions assuming left-aligned
- Alignment phase: Shift X coordinates based on `text-align` style
- Applied to entire layout nodes (paragraphs) and individual lines
- Centering: `x = x + (available_width - content_width) / 2`
- Right-align: `x = x + available_width - content_width`

#### 3.10 Box Model Layout Order
Each element's layout is calculated in this order:
1. Calculate styles (merge default, stylesheet, inline)
2. Extract margin and padding from styles
3. Calculate content position: `content_x = x + margin_left + padding_left`
4. Calculate available width: `width - margin_left - margin_right - padding_left - padding_right`
5. Layout children within content area
6. Calculate total height: `content_height + padding_top + padding_bottom + margin_top + margin_bottom`

---

## 4. HTML Renderer (`src/utils/html_renderer.lua`)

### Purpose
Draw layout tree to screen using LÖVE graphics.

### Key Rules

#### 4.1 Body Background Special Case

**CRITICAL:** Body background must be drawn **BEFORE** the scroll translate to keep it fixed.

**CORRECT RENDERING ORDER:**
```lua
-- 1. Set scissor
love.graphics.setScissor(viewport_x, viewport_y, viewport_width, viewport_height)

-- 2. Draw body background FIRST (before translate)
if body_element and body_background_color then
    love.graphics.setColor(body_background_color)
    love.graphics.rectangle("fill", 0, 0, viewport_width, viewport_height)
end

-- 3. THEN apply scroll translate
love.graphics.push()
love.graphics.translate(0, -scroll_y)

-- 4. Draw content (skip body background in renderNode)
renderNode(layout_tree)

love.graphics.pop()
```

**Why:** If body background is drawn inside the translated coordinate space, it scrolls with the content, leaving white gaps when scrolling or resizing.

#### 4.2 Background Rendering Rules
- Body element: Always fills entire viewport (drawn before translate)
- Other elements: Draw at `node.x, node.y, node.width, node.height` (inside translate)
- Skip body background in `renderNode()` to avoid double-drawing

#### 4.3 HR Rendering
HR elements render using `node.content_height` (2px by default), NOT `node.height` (which includes margins/padding):
```lua
local hr_height = node.content_height or styles.height or 2
love.graphics.rectangle("fill", node.content_x, node.content_y, node.content_width, hr_height)
```

#### 4.4 Link Rendering
Links apply color and underline styles to all children:
- Default color: `{0, 0, 1}` (blue)
- Visited color: `{0.5, 0, 0.5}` (purple)
- Hover effect: Multiply color by 1.2 (lighter shade)
- Always underlined (`text-decoration = "underline"`)
- Link styles are merged with child styles recursively

#### 4.5 List Item Rendering
- Unordered lists (`<ul>`): Render filled circle bullet at `content_x - 10, content_y + 8` (radius 4)
- Ordered lists (`<ol>`): Render number text at `content_x - 25, content_y`
- List index is passed through recursion to track numbering

#### 4.6 Text Rendering
Text nodes can have:
- **Multi-line layout** (wrapped text): Iterate over `node.lines` array, draw each line with proper Y offset
- **Single-line layout** (inline text): Draw `node.element.content` at `node.x, node.y`
- Underlines are drawn manually using `love.graphics.line()` at `y + font_height`

#### 4.7 Viewport Coordinates vs Screen Coordinates

**CRITICAL COORDINATE SYSTEM RULE:**

When rendering inside a windowed view (`drawWindowed()`), there are two coordinate systems:

1. **Viewport coordinates**: Relative to window content area (0, 0 = top-left of window)
2. **Screen coordinates**: Absolute screen position (includes window position offset)

**Rule for scissor regions:**
```lua
-- ALWAYS use screen coordinates for setScissor
local screen_x = viewport.x + local_x
local screen_y = viewport.y + local_y
love.graphics.setScissor(screen_x, screen_y, width, height)
```

**NEVER call `love.graphics.origin()` inside windowed views** - the window transformation matrix is already set up correctly.

#### 4.8 Font Caching
Fonts are cached by key: `size_weight_style` (e.g., "14_normal_normal")
- LÖVE doesn't support font weights/styles easily, so only size is used
- Cache prevents recreating fonts on every render
- Falls back to default font if font creation fails

#### 4.9 Document Height Calculation
Total document height is calculated recursively:
```lua
max_height = math.max(node.y + node.height, all_children_max_heights)
```
Used for scrollbar calculations.

---

## 5. Common Bugs and Fixes

### Bug 1: Every word in bordered container has a border
**Cause:** Text nodes inherited `border` property from parent `<p>` tag.

**Fix:** Filter out box-model properties when creating text node styles (see section 3.4).

---

### Bug 2: HR element appears as strikethrough on following text
**Cause:** Block layout used `child_y = child_y + child_layout.height`, which ignored the top margin already applied to `child_layout.y` inside `layoutElement()`.

**Fix:** Change to `child_y = child_layout.y + child_layout.height` (see section 3.5).

---

### Bug 3: Body background doesn't fill viewport
**Cause:** Body background was drawn at `(0, 0)` with `viewport_width` but inside the scroll translate, so it scrolled with content.

**Fix:** Draw body background **before** scroll translate (see section 4.1).

---

### Bug 4: Content not centered (unequal left/right margins)
**Cause:** Layout width calculation subtracted both scrollbar width AND arbitrary padding, giving wrong available width. Scrollbar was overlaying content.

**Fix:** Calculate layout width as `viewport_width - scrollbar_width`, let body margins be calculated normally by layout engine. Always show scrollbar to prevent layout shifts.

---

### Bug 5: Scrollbar appearing/disappearing causes layout shifts
**Cause:** Scrollbar only computed when `max_scroll > 0`, so it appeared/disappeared dynamically, changing available width.

**Fix:** Add `alwaysVisible` parameter to scrollbar component, always show scrollbar even when content doesn't scroll.

---

### Bug 6: Body background doesn't extend when resizing window
**Cause:** Body background height was set to document height only, not accounting for viewport height when content is short.

**Fix:** Use `viewport_height` for body background (drawn before translate), which always fills the visible window area.

---

## 6. Scrollbar System Integration

### Scrollbar Always Visible
To prevent layout shifts, the scrollbar is always visible:

1. **UIComponents.computeScrollbar**: Accepts `alwaysVisible` parameter
   - If `alwaysVisible = true`, returns geometry even when `max_offset <= 0`
   - Prevents division by zero when calculating thumb position

2. **ScrollbarController**: Accepts `always_visible` in constructor
   - Passes through to UIComponents

3. **WebBrowserState**: Creates scrollbar with `always_visible = true`

4. **Layout Width Calculation**: Always reserves space for scrollbar (15px)
   ```lua
   local content_width = viewport_width - scrollbar_width
   ```

---

## 7. URL Resolution

### URL Parsing Rules

**Relative File Paths** (checked FIRST):
```
about.html          → type: "relative", path: "about.html"
products/index.htm  → type: "relative", path: "products/index.htm"
```

**Domain + Path**:
```
www.cybergames.com/about.html  → domain: "www.cybergames.com", path: "/about.html"
```

**Domain Only** (adds default path):
```
www.cybergames.com  → domain: "www.cybergames.com", path: "/"
```

**CRITICAL:** Check for `.html` or `.htm` extension BEFORE checking for domain patterns, otherwise "about.html" gets treated as a domain.

### URL Building for Links
When clicking a link inside a page:
- Extract parent domain from current URL
- If link starts with `/`, treat as absolute path on same domain
- Otherwise, append to parent domain: `www.parent.com/link`

Navigation links in `<a>` tags automatically build full URLs from relative hrefs.

---

## 8. Testing Checklist

When making changes to the HTML/CSS system, test these scenarios:

### Layout Tests
- [ ] Text in bordered containers doesn't have borders on each word
- [ ] HR elements have proper spacing above and below
- [ ] Bordered sections don't overlap following headings
- [ ] List items flow horizontally (text + links on same line)

### Background Tests
- [ ] Body background fills entire viewport when content is short
- [ ] Body background stays fixed when scrolling
- [ ] Body background fills viewport when resizing window larger
- [ ] Body background doesn't show white gaps

### Scrollbar Tests
- [ ] Scrollbar always visible (even when content doesn't scroll)
- [ ] Content doesn't shift when switching between scrollable/non-scrollable
- [ ] Scrollbar appears in reserved space, not overlaying content
- [ ] Content has equal left/right margins

### Navigation Tests
- [ ] Relative links like "about.html" resolve correctly
- [ ] Links with full URLs navigate properly
- [ ] Clicking links updates address bar
- [ ] Back/forward buttons work

### Text Tests
- [ ] Multi-line paragraphs wrap correctly
- [ ] Centered text appears centered
- [ ] Links show blue/purple colors
- [ ] Link hover shows lighter color
- [ ] HTML entities display correctly (&copy; → ©)

---

## 9. File Organization

```
src/utils/
  ├── html_parser.lua      - Parse HTML → DOM tree
  ├── css_parser.lua       - Parse CSS → property tables
  ├── html_layout.lua      - DOM + styles → positioned layout tree
  └── html_renderer.lua    - Layout tree → LÖVE graphics drawing

src/states/
  └── web_browser_state.lua - Manages URL navigation, history, layout triggers

src/views/
  └── web_browser_view.lua  - Draws toolbar, address bar, content area

src/controllers/
  └── scrollbar_controller.lua - Scrollbar state and interaction

assets/data/web/
  └── cybergames/          - Example HTML pages
      ├── index.html
      ├── about.html
      ├── products.html
      └── contact.html
```

---

## 10. Performance Notes

- Font caching prevents recreating fonts every frame
- Scissor regions clip content outside viewport (no overdraw)
- Layout only recalculated when:
  - New page loaded
  - Window width changes (height changes only affect scrolling)
- DOM parsing happens once per page load (cached in state)

---

## 11. Future Improvements

Potential enhancements not yet implemented:

- **Images**: `<img>` tag support with sprite loading
- **Tables**: Proper table layout with `<table>`, `<tr>`, `<td>`
- **Forms**: Input fields, buttons, form submission
- **CSS Classes**: Class selectors (`.classname`)
- **CSS IDs**: ID selectors (`#idname`)
- **Descendant Selectors**: `div p { }` syntax
- **Pseudo-classes**: `:hover`, `:visited`, `:active`
- **Floats**: `float: left/right` for complex layouts
- **Flexbox/Grid**: Modern layout systems (probably overkill for 90s aesthetic)

---

**Document Version:** 1.0
**Last Updated:** 2025
**Tested Against:** LÖVE 11.4

This document represents the hard-won knowledge from debugging HTML/CSS rendering. Follow these rules to avoid breaking the layout engine.
