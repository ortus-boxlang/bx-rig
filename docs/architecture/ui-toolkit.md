---
title: The terminal UI toolkit
---

# The terminal UI toolkit (`bxrig.ui`)

Commands that print (not the full-screen TUI) build their output with `bxrig.ui`. One call gives tables, panels, badges, key-value lists, trees, columns, status lines, progress bars, sparklines, bar charts, step checklists, gradients and hyperlinks. Every helper returns text or an array of lines; nothing prints until you call `print`.

```boxlang
ui = new bxrig.ui.Ui();
ui.print( ui.table(
    [ { key: "id", title: "Major", align: "right" }, { key: "name", title: "Name" }, "vendor" ],
    rows, { title: "Java" } ) );
ui.print( ui.panel( "Saved the keys.", { title: "Done", border: "ok" } ) );
```

## Terminal rules

`Term` decides once: colour only on a terminal, never with `NO_COLOR`, `TERM=dumb` or `plain`; truecolor from `COLORTERM`, else the nearest of 256 colours; unicode from the locale (ASCII borders and glyphs otherwise); width from `COLUMNS` or `stty`, else 80, never below 20. With colour off every style call returns the plain text, so piped output is clean. Tests force all of it: `new bxrig.ui.Ui( { color: true, truecolor: true, width: 60, unicode: true } )`.

Widths are measured as the screen shows them: escapes take no room, wide characters (日本語, 😀) two columns, combining marks none.

## Colours

A colour is a role (`accent accent2 ok warn err info text dim border header zebra`), a basic name (`red cyan gray ...`) or a hex like `#00c8ff`. A style is words: `bold dim italic underline inverse strike`, a colour, `bg:COLOUR`.

```boxlang
ui.style( "installed", "bold ok" )
ui.style( " LTS ", "bold black bg:warn" )
ui.colors( { accent: "#ff8800" } )   // change a role, for example to the theme that is on
```

## The helpers

| Call | Result |
|---|---|
| `ui.table( columns, rows, opts )` | A table. Columns: `key title align width min max grow wrap format style`. Options: `border` (`rounded plain heavy double ascii none`), `title`, `footer`, `zebra`, `rowLines`, `width`, `padding`, `empty`, `fill`. A table wider than the terminal shrinks its widest columns first and cuts text with an ellipsis, or wraps a `wrap: true` column. |
| `ui.panel( content, opts )` | A box with `title`, `subtitle`, `border`, `color`, `padding`, `width`, `fill`. |
| `ui.callout( kind, text, opts )` | A coloured bar with wrapped text (`ok warn err info`). |
| `ui.section( title, blurb )`, `ui.rule( title )` | An UPPERCASE heading; a rule with a title in it. |
| `ui.kv( pairs, opts )` | Aligned label and value lines, values wrapped with a hanging indent. |
| `ui.list( items, opts )`, `ui.tree( nodes )` | Bullets or numbers with children; a tree with `├─ └─ │`. |
| `ui.columns( blocks, opts )` | Blocks (arrays of lines) side by side. |
| `ui.badge( text, role )`, `ui.pill( text, role )`, `ui.status( kind, text )` | Small marks: `[LTS]`, `✓ installed`. |
| `ui.bar( ratio, width, opts )`, `ui.spark( values )`, `ui.barChart( rows, opts )` | Progress bar, sparkline, horizontal bar chart. |
| `ui.steps( items, opts )`, `ui.spinner().frame( tick )` | A step checklist; a spinner frame. |
| `ui.live()` | A block that redraws itself in place (`update( lines )`, `finish()`). |
| `ui.gradient( text )`, `ui.link( text, url )` | A gradient across the text; an OSC 8 hyperlink. |
| `ui.truncate`, `ui.align`, `ui.wrap`, `ui.textWidth`, `ui.strip` | Text helpers that know about escapes and wide characters. |

## One call, two outputs

Commands built on `Out` get a styled block for people and data for `--json` from one call:

```boxlang
out.table( "Java", columns, rows, asJson, { total: rows.len() } )   // text: the table; --json: { rows: [...], total }
out.kv( "Status", { jenv: "ready", global: "21" }, asJson )
out.blocks( data, asJson, ui.panel( "Done" ) )
```

Tests: `tests/ui_test.bxs` (golden output, widths 40, 80 and 120, plain and colour).
