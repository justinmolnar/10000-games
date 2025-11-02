# Web Browser Implementation Plan

## Overview
Build a basic 90s-style HTML/CSS browser for the 10000 Games project. Supports simple HTML 3.2-era features, basic CSS styling, "View Source" functionality, and navigation between bundled pages. Perfect for hiding secrets in HTML comments, source code, and generation timestamps.

## Architecture
- **State**: `src/states/web_browser_state.lua` - Navigation, history, input handling
- **View**: `src/views/web_browser_view.lua` - Toolbar, address bar, content rendering
- **HTML Parser**: `src/utils/html_parser.lua` - Parse HTML strings into DOM tree
- **CSS Parser**: `src/utils/css_parser.lua` - Parse inline/style tag CSS into rule objects
- **Layout Engine**: `src/utils/html_layout.lua` - Calculate positions/sizes for elements
- **HTML Renderer**: `src/utils/html_renderer.lua` - Draw DOM to LÖVE canvas
- **Test Content**: `assets/data/web/*.html` - Bundled fake websites

## Design Constraints
- **90s HTML 3.2 Era**: No advanced CSS (flexbox, grid, etc.), no JavaScript
- **Basic Responsiveness**: Text wraps, content reflows when window resizes
- **Viewport Coordinate Safe**: NO `love.graphics.origin()` in windowed drawing (per CLAUDE.md)
- **Scrolling**: Vertical scrollbar for tall pages
- **View Source**: Button to show raw HTML in monospace text viewer

---

## Phase 1: Core HTML Parser (Foundation)
**Goal**: Parse simple HTML into a DOM tree structure

### Supported Tags (MVP):
- Structure: `<html>`, `<head>`, `<title>`, `<body>`
- Block: `<p>`, `<div>`, `<h1>`-`<h6>`, `<hr>`, `<br>`
- Inline: `<span>`, `<a>`, `<b>`, `<i>`, `<u>`
- Lists: `<ul>`, `<ol>`, `<li>`
- Comments: `<!-- comment -->`

### Parser Output:
```lua
{
  tag = "div",
  attributes = { class = "container", id = "main" },
  children = {
    { tag = "p", children = { { type = "text", content = "Hello" } } },
    { type = "comment", content = "SECRET: Generated 1999-03-15" }
  }
}
```

### Implementation:
- `src/utils/html_parser.lua`:
  - `HTMLParser:parse(html_string)` - Returns DOM tree
  - `HTMLParser:parseTag(text)` - Extract tag name and attributes
  - `HTMLParser:parseText(text)` - Handle text nodes
  - `HTMLParser:parseComment(text)` - Preserve comments for View Source
- Handle self-closing tags (`<br>`, `<hr>`, `<img>`)
- Handle nested structures (lists, divs)
- Ignore unknown tags gracefully (skip but preserve in tree)

### Test Files:
- `assets/data/web/test_basic.html` - Simple page with paragraphs, headings
- `assets/data/web/test_nested.html` - Nested divs and lists
- `assets/data/web/test_comments.html` - Hidden comments with "secrets"

### Testing:
- Parse each test file, print DOM tree structure
- Verify comments are preserved
- Verify attributes are extracted correctly

---

## Phase 2: Basic CSS Parser
**Goal**: Parse inline styles and `<style>` tags into rule objects

### Supported CSS Properties:
- Colors: `color`, `background-color`
- Typography: `font-family`, `font-size`, `font-weight`, `font-style`, `text-align`
- Box Model: `margin`, `padding`, `width`, `height`
- Display: `display` (block, inline, none)

### CSS Rule Format:
```lua
{
  selector = "p",
  properties = {
    color = "#000000",
    font_size = "14px",
    margin = "10px"
  }
}
```

### Implementation:
- `src/utils/css_parser.lua`:
  - `CSSParser:parseStylesheet(css_string)` - Parse `<style>` tag contents
  - `CSSParser:parseInlineStyle(style_attr)` - Parse `style="..."` attribute
  - `CSSParser:parseProperty(prop_string)` - Parse "color: red" → {color = "red"}
  - `CSSParser:parseSelector(selector)` - Parse "p", ".class", "#id"
- Support element, class (`.`), and ID (`#`) selectors
- Handle color formats: hex (#FF0000), rgb(255,0,0), named colors (red, blue, etc.)
- Parse units: px, pt, em (convert to px for simplicity)

### Test Files:
- `assets/data/web/test_inline_style.html` - Inline `style="..."` attributes
- `assets/data/web/test_style_tag.html` - `<style>` tag with CSS rules

### Testing:
- Parse CSS, print rule objects
- Verify selectors match correctly
- Verify property values are extracted

---

## Phase 3: Layout Engine (Most Complex)
**Goal**: Calculate positions and sizes for all DOM elements

### Layout Algorithm:
1. **Root Layout**: Start at `<body>`, position at (0, 0)
2. **Block Elements**: Stack vertically, take full width
3. **Inline Elements**: Flow left-to-right, wrap at line end
4. **Text Wrapping**: Break text into lines based on available width
5. **Box Model**: Apply margin, padding to calculate final positions

### Layout Output:
```lua
{
  element = <dom_node>,
  x = 10,
  y = 50,
  width = 600,
  height = 20,
  children = { <child_layouts> }
}
```

### Implementation:
- `src/utils/html_layout.lua`:
  - `HTMLLayout:layout(dom_tree, viewport_width)` - Returns layout tree
  - `HTMLLayout:layoutBlock(element, x, y, width)` - Layout block element
  - `HTMLLayout:layoutInline(elements, x, y, width)` - Flow inline elements
  - `HTMLLayout:wrapText(text, width, font)` - Break text into lines
  - `HTMLLayout:applyStyles(element, styles)` - Apply CSS to element
- Match CSS rules to elements (specificity: ID > class > tag)
- Calculate text dimensions using `love.graphics.getFont():getWidth()`
- Handle `<br>` as line break, `<hr>` as horizontal rule

### Default Styles (90s aesthetic):
- Font: Arial 12pt (or similar sans-serif)
- Headings: Bold, larger sizes (h1=24pt, h2=20pt, etc.)
- Links: Blue, underlined
- Paragraphs: 10px margin-bottom
- Body: 10px padding

### Test Files:
- `assets/data/web/test_layout.html` - Mixed block/inline elements
- `assets/data/web/test_wrapping.html` - Long text paragraphs

### Testing:
- Render layout boxes as colored rectangles (no text yet)
- Verify block elements stack vertically
- Verify inline elements wrap correctly

---

## Phase 4: HTML Renderer
**Goal**: Draw layout tree to LÖVE canvas

### Implementation:
- `src/utils/html_renderer.lua`:
  - `HTMLRenderer:render(layout_tree, scroll_y)` - Draw entire page
  - `HTMLRenderer:drawElement(layout_node, scroll_y)` - Draw single element
  - `HTMLRenderer:drawText(text, x, y, color, font)` - Draw text node
  - `HTMLRenderer:drawBackground(x, y, w, h, color)` - Draw bg color
  - `HTMLRenderer:drawBorder(x, y, w, h, color)` - Draw borders (if supported)
- Respect scissor for scrolling (content area only)
- Handle `display: none` (skip rendering)
- Render links with hover effect (underline + color change)

### 90s Visual Style:
- Default background: Light gray (#C0C0C0) or white
- Default text: Black
- Links: Blue (#0000FF) → Purple (#800080) when visited (track in browser state)
- Headings: Bold, black
- HR: Gray horizontal line

### Test Files:
- `assets/data/web/test_render.html` - Full page with all element types

### Testing:
- Render test pages in-game
- Verify text wraps correctly
- Verify colors/fonts apply correctly

---

## Phase 5: Browser State & View (Integration)
**Goal**: Create windowed browser application with navigation

### State Features:
- Current URL (path to HTML file)
- History stack (back/forward navigation)
- Visited links (for color change)
- Scroll position
- View Source mode toggle

### View Features:
- **Toolbar**: Back, Forward, Refresh, View Source buttons
- **Address Bar**: Display current URL (read-only for MVP)
- **Content Area**: Render HTML or show raw source
- **Scrollbar**: Vertical scrolling for tall pages
- **Status Bar**: Show link URLs on hover

### Implementation:
- `src/states/web_browser_state.lua`:
  - `WebBrowserState:init(di)` - Inject file_system, etc.
  - `WebBrowserState:navigateTo(url)` - Load HTML file, parse, layout
  - `WebBrowserState:goBack()` / `goForward()` - History navigation
  - `WebBrowserState:toggleViewSource()` - Switch to raw HTML view
  - `WebBrowserState:handleLinkClick(href)` - Navigate on link click
  - `WebBrowserState:setViewport(x, y, w, h)` - Called by WindowController
- `src/views/web_browser_view.lua`:
  - `WebBrowserView:drawWindowed(viewport_w, viewport_h)` - Render UI
  - `WebBrowserView:drawToolbar()` - Back/Forward/Refresh/View Source
  - `WebBrowserView:drawAddressBar()` - Show current URL
  - `WebBrowserView:drawContent()` - Render HTML or source text
  - `WebBrowserView:drawScrollbar()` - Vertical scrollbar
  - `WebBrowserView:update(dt)` - Handle hover states

### Input Handling:
- **Mouse Click**: Check if link clicked → navigate
- **Mouse Wheel**: Scroll content
- **Toolbar Buttons**: Click handlers for back/forward/etc.
- **Scrollbar Dragging**: UIComponents scrollbar pattern (see file_explorer_view.lua)

### Viewport Safety (CRITICAL - per CLAUDE.md):
- **NO `love.graphics.origin()` in drawWindowed()**
- Coordinates are relative to window viewport (0,0 = top-left of window)
- `love.graphics.setScissor()` requires SCREEN coordinates (viewport.x + offset_x, viewport.y + offset_y)
- Use `self.controller.viewport.x` and `.y` for scissor regions

### Test Integration:
- Add "Web Browser" to `assets/data/programs.json`
- Test opening browser from desktop
- Test navigation between bundled pages
- Test View Source toggle

---

## Phase 6: Basic Responsiveness & Polish
**Goal**: Handle window resizing, improve usability

### Responsiveness:
- Re-layout when viewport width changes (detect in `update()`)
- Cache layout tree to avoid re-parsing on every frame
- Invalidate layout cache on navigation or resize
- Text wraps to new width

### Polish Features:
- **Link Hover**: Change cursor to hand icon, show URL in status bar
- **Visited Links**: Track clicked links, change color to purple
- **Error Pages**: Show "404 Not Found" if HTML file doesn't exist
- **Loading State**: (Optional) "Loading..." text while parsing large pages
- **Smooth Scrolling**: (Optional) Lerp scroll position for smoother feel

### Performance:
- Layout caching (don't re-layout every frame)
- Render to canvas if page is static (optional optimization)
- Limit max page height (e.g., 10,000px) to prevent memory issues

### Test Files:
- `assets/data/web/test_responsive.html` - Long text paragraphs that wrap

### Testing:
- Resize browser window, verify text reflows
- Scroll large pages, verify no lag
- Click links, verify navigation works
- Toggle View Source, verify raw HTML shown correctly

---

## Phase 7: Test Website Creation
**Goal**: Build a fake 90s website with discoverable secrets

### Website Structure:
```
assets/data/web/
  cybergames/
    index.html          - Homepage with "Welcome to CYBER-GAMES.COM!"
    products.html       - List of products (generic game names)
    about.html          - About page (templated text)
    contact.html        - Contact form (non-functional, just links)
    style.css           - (Optional) External stylesheet (Phase 8)
```

### Homepage Example (`index.html`):
```html
<!-- AUTO-GENERATED: 1999-03-15 08:42:17 -->
<!-- Template: homepage_template.html -->
<!-- Background: background22.png -->
<html>
<head>
  <title>CYBER-GAMES.COM - 10,000 Games!</title>
</head>
<body bgcolor="#FFFFFF" text="#000000">
  <center>
    <h1>Welcome to CYBER-GAMES.COM!</h1>
    <p>The #1 source for digital entertainment!</p>
    <hr>
    <a href="products.html">Products</a> |
    <a href="about.html">About Us</a> |
    <a href="contact.html">Contact</a>
    <hr>
  </center>

  <h2>Featured Games</h2>
  <ul>
    <li><a href="#">Snake Classic</a> - {{GAME_NAME_1}}</li>
    <li><a href="#">Memory Master</a> - {{GAME_NAME_2}}</li>
    <li><a href="#">Space Defender</a> - {{GAME_NAME_3}}</li>
  </ul>

  <!-- TODO: Personalize product descriptions -->
  <!-- NOTE: Using template variables until AI system online -->
</body>
</html>
```

### Discoverable Secrets:
1. **Generation Timestamps**: HTML comments show 1999 dates
2. **Template References**: Comments mention template files
3. **Reused Assets**: Same background referenced as in-game files (cross-reference with file system)
4. **Placeholder Text**: "{{VARIABLE}}" syntax suggests automation
5. **TODO Comments**: Hints that content is AI-generated, not human-written

### Products Page Example (`products.html`):
```html
<!-- AUTO-GENERATED: 1999-03-15 08:43:02 -->
<!-- Template: product_list_template.html -->
<html>
<head>
  <title>Products - CYBER-GAMES.COM</title>
</head>
<body bgcolor="#E0E0E0">
  <h1>Our Products</h1>
  <p><a href="index.html">Back to Home</a></p>

  <h3>Action Games</h3>
  <ul>
    <li>Snake Classic - Guide the snake to victory!</li>
    <li>Space Defender - Protect the galaxy!</li>
    <li>Dodge Master - Avoid obstacles!</li>
  </ul>

  <h3>Puzzle Games</h3>
  <ul>
    <li>Memory Match - Test your memory!</li>
    <li>Hidden Object - Find the hidden items!</li>
  </ul>

  <!-- GENERATED: 50 products listed -->
  <!-- Source: product_database.txt -->
</body>
</html>
```

### Implementation:
- Create 5-10 simple HTML pages
- Add realistic 90s styling (bgcolor, center tags, basic fonts)
- Include discoverable secrets in comments
- Link pages together for navigation testing

---

## Phase 8: External CSS Support (Optional)
**Goal**: Load external `.css` files referenced in `<link>` tag

### Supported:
- `<link rel="stylesheet" href="style.css">`
- Load CSS from file system
- Merge with inline styles (inline overrides external)

### Implementation:
- Detect `<link>` tags in HTML parser
- Load CSS file via `love.filesystem.read()`
- Parse CSS stylesheet into rules
- Apply to DOM tree during layout

### Test Files:
- `assets/data/web/cybergames/style.css` - Shared stylesheet
- Update `index.html` to reference it: `<link rel="stylesheet" href="style.css">`

---

## Phase 9: Image Support (Optional)
**Goal**: Display images from `<img>` tags

### Supported:
- `<img src="logo.png" width="200" height="100">`
- Load image from file system
- Scale/position in layout

### Implementation:
- Parse `<img>` tags with `src`, `width`, `height` attributes
- Load image via `love.graphics.newImage()`
- Treat as inline element with fixed dimensions
- Draw image in renderer

### Test Files:
- `assets/data/web/cybergames/logo.png` - Fake logo image
- Update `index.html`: `<img src="logo.png" width="100" height="50">`

---

## Phase 10: Table Support (Optional)
**Goal**: Render basic `<table>` layouts

### Supported:
- `<table>`, `<tr>`, `<td>`, `<th>`
- Fixed-width columns (no colspan/rowspan)
- Basic borders

### Implementation:
- Parse table structure into grid
- Calculate column widths (equal distribution or fixed widths)
- Layout cells as block elements
- Draw borders between cells

### Test Files:
- `assets/data/web/test_table.html` - Simple data table

---

## Phase 11: Integration with File System
**Goal**: Browser can open `.html` files from File Explorer

### Features:
- Double-click `.html` file in File Explorer → Opens in Web Browser
- Browser can navigate to local file paths (e.g., `C:\WINDOWS\HELP\index.html`)
- Cross-reference between web pages and file system (player can find template files)

### Implementation:
- Register `.html` extension with "Web Browser" program in `programs.json`
- File Explorer opens browser with file path as URL
- Browser resolves local paths: `/WINDOWS/HELP/index.html` → `assets/data/filesystem/windows/help/index.html`

### Test:
- Create `assets/data/filesystem/windows/help/index.html` (bundled help page)
- Open from File Explorer, verify browser displays it

---

## Testing Strategy

### Unit Tests (Manual):
- Parse HTML → Print DOM tree
- Parse CSS → Print rule objects
- Layout page → Print layout coordinates
- Render page → Visual inspection

### Integration Tests:
- Open browser from desktop
- Navigate between pages
- Click links, verify navigation
- Toggle View Source, verify raw HTML shown
- Resize window, verify text reflows
- Scroll large pages, verify scrollbar works

### Secret Discovery Tests:
- View Source on homepage
- Find generation timestamp in comment
- Cross-reference template file name with file system
- Find reused asset references (e.g., background22.png)

---

## Implementation Phases Summary

| Phase | Description | Estimated Time | Dependencies |
|-------|-------------|----------------|--------------|
| **1** | HTML Parser | 2-3 days | None |
| **2** | CSS Parser | 1-2 days | Phase 1 |
| **3** | Layout Engine | 5-7 days | Phases 1-2 |
| **4** | HTML Renderer | 3-4 days | Phases 1-3 |
| **5** | Browser State & View | 2-3 days | Phases 1-4 |
| **6** | Responsiveness & Polish | 2-3 days | Phase 5 |
| **7** | Test Website Creation | 1-2 days | Phase 5 |
| **8** | External CSS (Optional) | 1 day | Phase 2 |
| **9** | Image Support (Optional) | 1-2 days | Phase 4 |
| **10** | Table Support (Optional) | 2-3 days | Phase 3 |
| **11** | File System Integration | 1 day | Phase 5 |

**Total MVP Time (Phases 1-7)**: ~14-20 days
**Total with Optional Features**: ~20-30 days

---

## File Structure

```
src/
  states/
    web_browser_state.lua       - Navigation, history, input
  views/
    web_browser_view.lua        - Toolbar, rendering
  utils/
    html_parser.lua             - Parse HTML → DOM tree
    css_parser.lua              - Parse CSS → rules
    html_layout.lua             - Calculate positions
    html_renderer.lua           - Draw DOM to canvas

assets/
  data/
    web/
      test_basic.html           - Phase 1 test
      test_nested.html          - Phase 1 test
      test_comments.html        - Phase 1 test
      test_inline_style.html    - Phase 2 test
      test_style_tag.html       - Phase 2 test
      test_layout.html          - Phase 3 test
      test_wrapping.html        - Phase 3 test
      test_render.html          - Phase 4 test
      test_responsive.html      - Phase 6 test
      test_table.html           - Phase 10 test
      cybergames/
        index.html              - Phase 7 fake website
        products.html
        about.html
        contact.html
        style.css               - Phase 8 external CSS
        logo.png                - Phase 9 image
```

---

## Key Design Decisions

1. **No JavaScript**: Keeps scope manageable, fits 90s aesthetic
2. **Limited CSS**: Focus on common properties, skip advanced layout (flexbox, etc.)
3. **Viewport Safety**: Never call `love.graphics.origin()` in windowed views
4. **View Source**: Critical for secret discovery - preserve raw HTML exactly
5. **Bundled Content**: All pages stored locally, no real network access
6. **90s Aesthetic**: Times New Roman/Arial, basic colors, simple layouts
7. **Responsiveness**: Text wraps on resize, layout recalculates
8. **Caching**: Cache layout tree to avoid re-parsing every frame

---

## Future Enhancements (Post-MVP)

- **Forms**: `<input>`, `<textarea>`, `<button>` (non-functional, just visual)
- **Frames**: `<frameset>`, `<frame>` (authentic 90s feel!)
- **Animated GIFs**: Load and animate `.gif` images
- **Marquee Tag**: `<marquee>` for that classic scrolling text
- **Background Music**: `<bgsound>` tag (MIDI files)
- **Bookmarks**: Save favorite pages
- **History Panel**: View browsing history
- **Search**: Ctrl+F to find text on page
- **Print**: "Print" page to text file (fake printer)

---

## Success Criteria

✅ Parse simple HTML 3.2 pages into DOM tree
✅ Parse basic CSS (colors, fonts, box model)
✅ Calculate layout with text wrapping
✅ Render HTML to LÖVE canvas with correct styling
✅ Browser window with toolbar, address bar, scrollbar
✅ Navigate between pages via links
✅ View Source shows raw HTML with comments
✅ Window resizing reflows text
✅ Fake website with discoverable secrets
✅ Open HTML files from File Explorer

---

## Notes

- This is a **custom HTML renderer**, not a full web browser engine
- Focus on **authenticity over completeness** (90s web feel)
- **Secrets are the goal**: Comments, templates, timestamps, reused assets
- Keep it **simple and scoped**: Don't try to support modern web standards
- **Test early and often**: Visual feedback is critical for layout debugging
