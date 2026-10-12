# lua-nxterm API reference

`local nxterm = require('nxterm')`

Every function **returns** an escape-sequence string (nothing is written) unless noted
as *writes* or *executes*. Numeric arguments default as shown; `n` is a count.
Notation: `CSI` = `ESC [`, `OSC` = `ESC ]`, `BEL` = `\7`.

## Module fields

| Field | Description |
|-------|-------------|
| `nxterm._VERSION` | `'lua-nxterm 0.3.1'` |
| `nxterm.strip` | `true` when `NO_COLOR` is set at load time. When `true`, all SGR output (colour/style) becomes `''` and `link()` returns plain text. May be changed at runtime. |

## Colours and styles (SGR)

### `nxterm.color` / `nxterm.colour`

Shared, read-only SGR builder object.

| Usage | Returns |
|-------|---------|
| `color.red.bold` | builder; `tostring()` / `..` give `CSI 31;1m` (one sequence for the whole chain) |
| `color.red.bold('text')` | `CSI 31;1m` .. text .. `CSI 0m` (any value, converted with `tostring`) |
| `color.red.bold()` | `CSI 31;1m` |
| `color['red bold']` | builder for several keys at once |
| `color(keys)` | sequence for a whitespace-separated key list, e.g. `color'red bold ul'` |
| `color(keys, text)` | sequence .. text |
| `color(keys, text, post_keys)` | sequence .. text .. sequence for `post_keys` (e.g. `'reset'`) |
| `color''`, `color()`, `color(true)` | `CSI m` (reset) |

Keys (see the README for the full table): named colours `red`, `bg_red`, bright `red_b` / `bg_red_b`, `grey`;
styles `bold b dim italic i ul underline ul_double ul_wavy ul_dot ul_dash blink blink_fast inverse hide strike
fraktur over frame encircle sup sub` and their `*_off` forms; `reset`, `default`, `bg_default`, `ul_default`;
dynamic `cN` (0–255), `gN` (greyscale 0–23), `rNgNbN` (0–255 each), `#rrggbb` / `#rgb`, each optionally prefixed
`bg_` (background) or `ul_` (underline colour). Unknown or out-of-range keys are ignored.

Aliases from ansicolors: `hidden` (8), `blackbg` … `whitebg` (40–47), `clear` (0),
`underscore` (4), `onblack` … `onwhite` (40–47).

### `nxterm(...)` — ansicolors drop-in

The module table is callable: `nxterm(...)` is `nxterm.escape_codes(...)`. With
`nxterm.noReset` this makes `local colors = require('nxterm')` a drop-in
replacement for [kikito/ansicolors.lua](https://github.com/kikito/ansicolors.lua) 1.0.2
(`colors('%{red}x')`, `colors.noReset('%{red}x')`). Output renders the same as
ansicolors; bytes differ only where nxterm merges several keys into one sequence
or expands `%{}` to `ESC[m`. Unknown keys are ignored (ansicolors raises).

### `nxterm.noReset(str)`
`str` (string or number) with `%{keys}` markup expanded, without the resets
`escape_codes` adds. Other types raise an error. Respects `nxterm.strip`.

### `nxterm.sgr()`
Returns the base builder (same object as `nxterm.color`).

### `nxterm.escape_codes(...)`
Concatenates its arguments (non-strings converted with `tostring`; `nil` and `false` become `''`), replacing each `%{keys}` marker with the SGR
sequence for `keys` (`%{}` = reset). The result is wrapped in `CSI 0m` … `CSI 0m`.

```lua
nxterm.escape_codes('[%{red bold}ERR%{}] disk full')
```

### `nxterm.escape_strip(...)`
Concatenates its string arguments with all `%{...}` markers removed.

### `nxterm.format(fmt, ...)`
`string.format` with marker support: `fmt` is processed like `escape_codes` (reset-wrapped); `%{}` markers in
string arguments are expanded too, without extra resets.

### `nxterm.writef(fmt, ...)` — *writes*
`io.write(nxterm.format(fmt, ...))`.

### `nxterm.printf(fmt, ...)` — *writes*
Writes `nxterm.format(fmt, ...) .. '\r\n'` and flushes.

### `nxterm.print(...)` — *writes*
Writes `nxterm.escape_codes(...) .. '\r\n'` and flushes.

## Cursor — `nxterm.cursor`

| Function | Sequence | Notes |
|----------|----------|-------|
| `up(n=1)` | `CSI n A` | |
| `down(n=1)` | `CSI n B` | |
| `forward(n=1)` / `right` | `CSI n C` | |
| `back(n=1)` / `left` | `CSI n D` | |
| `nl(n=1)` / `next_line` | `CSI n E` | start of n-th next line |
| `pl(n=1)` / `prev_line` | `CSI n F` | start of n-th previous line |
| `setx(n=1, absolute)` | `CSI n G` / `CSI n a` | absolute column (CHA) / relative (HPR) |
| `sety(n=1, absolute)` | `CSI n d` / `CSI n e` | absolute row (VPA) / relative (VPR) |
| `set(x=1, y=1)` | `CSI y;x H` | **column first** |
| `setlc(line=1, col=1)` | `CSI line;col H` | row first |
| `save()` / `restore()` | `CSI s` / `CSI u` | SCO |
| `dec_save()` / `dec_restore()` | `ESC 7` / `ESC 8` | DEC, more widely supported |
| `hide()` / `show()` | `CSI ?25l` / `CSI ?25h` | |
| `style(n=0)` | `CSI n q` | DECSCUSR: 0/1 blinking block, 2 block, 3/4 underline, 5/6 bar |
| `get()` — *writes/reads* | sends `CSI 6n` | returns `{col, row}` or `nil`. Reads the reply from `io.stdin`; put the TTY in raw mode first (`nxterm.tty.raw()`) or the reply waits for Enter. May block if the terminal does not answer. |
| `getlc()` | | like `get()` but returns `{row, col}` |

## Screen, lines, characters

| Function | Sequence | Notes |
|----------|----------|-------|
| `nxterm.reset()` | `ESC c` | full terminal reset (RIS) |
| `nxterm.erase(n=2)` / `clear` | `CSI n J` | 0 = to end, 1 = to start, 2 = whole screen, 3 = + scrollback |
| `nxterm.line.erase(n=2)` | `CSI n K` | 0 = to end, 1 = to start, 2 = whole line |
| `nxterm.line.insert(n=1)` | `CSI n L` | |
| `nxterm.line.delete(n=1)` | `CSI n M` | |
| `nxterm.scroll.up(n=1)` | `CSI n S` | |
| `nxterm.scroll.down(n=1)` | `CSI n T` | |
| `nxterm.scroll.region(top=1, bottom)` | `CSI top;bottom r` | omit both to reset the region |
| `nxterm.shift.right(n=1)` | `CSI n SP @` | shift columns right (SR) |
| `nxterm.shift.left(n=1)` | `CSI n SP A` | shift columns left (SL) |
| `nxterm.tab(n=1)` | `CSI n I` | forward tab stops |
| `nxterm.backtab(n=1)` | `CSI n Z` | backward tab stops |
| `nxterm.char.insert(n=1)` | `CSI n @` | |
| `nxterm.char.delete(n=1)` | `CSI n P` | |
| `nxterm.char.erase(n=1)` | `CSI n X` | |
| `nxterm.char.rep(n=1)` | `CSI n b` | repeat previous character |

## Modes — `nxterm.mode`

| Function | Sequence |
|----------|----------|
| `set(m, private)` | `CSI [?]m h`; `m` is a number, string or list (`{1049, 2004}` → `1049;2004`). Returns `nil` if `m` is `nil`. |
| `reset(m, private)` | `CSI [?]m l` |
| `alt_screen(on)` | `CSI ?1049 h/l` |
| `bracketed_paste(on)` | `CSI ?2004 h/l` |
| `sync(on)` | `CSI ?2026 h/l` (synchronized output) |
| `focus(on)` | `CSI ?1004 h/l` (focus in/out reports) |
| `wrap(on)` | `CSI ?7 h/l` (auto-wrap) |
| `ansi()` | `ESC <` (VT52 → ANSI mode) |
| `gpu(on)` | `ESC ( 0` / `ESC ( B` (DEC line-drawing charset on / US-ASCII) |
| `size` | alias of `nxterm.size` |

## Mouse — `nxterm.mouse`

| Function | Sequence |
|----------|----------|
| `on()` | `CSI ?1000h CSI ?1006h` (button tracking + SGR reports) |
| `off()` | `CSI ?1000l CSI ?1006l` |

## TTY — `nxterm.tty` (*executes* `stty`, POSIX only)

| Function | Effect |
|----------|--------|
| `raw()` | `stty raw onlcr -echo` (character-at-a-time input, no echo) |
| `sane()` | `stty sane` (restore) |
| `set()`, `get()` | reserved, no-op |

## OSC and misc

| Function | Sequence / result |
|----------|-------------------|
| `nxterm.title(s)` | `OSC 0;s BEL` (window/icon title) |
| `nxterm.cwd(path)` | `OSC 7;file://path BEL` |
| `nxterm.link(url, text=url)` | `OSC 8;;url BEL text OSC 8;; BEL`; plain `text` when `nxterm.strip` |
| `nxterm.progress(state, pct=0)` | `OSC 9;4;state;pct BEL`; state 0 hide, 1 normal, 2 error, 3 indeterminate, 4 paused (0 and 3 omit `pct`) |
| `nxterm.bell()` | `BEL` |

## Terminal size

### `nxterm.size()` — *executes / may write*
Returns `{width, height}` or `nil`. Uses `stty size`; if unavailable, falls back to moving the cursor to
the bottom-right corner, querying it with `cursor.get()`, and restoring the original position.
