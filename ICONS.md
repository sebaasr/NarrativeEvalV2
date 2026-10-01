# Icon, Font & Visual-Asset Provenance

**App:** NCF Narrative Evaluations Dashboard (`index.html`)
**Prepared for:** SIG consulting team (pre-work asset & licensing review)
**Last updated:** 2026-09-08

This document lists every icon, glyph, font, logo, and third-party visual
asset used in the dashboard, where it comes from, and its licensing terms.

---

## 1. UI icons — Unicode characters (NOT bundled icon files)

Every "icon" in the interface is a **standard Unicode code point** written
directly into the HTML (either as a numeric character reference like
`&#127891;` or as the literal character). **The app does not ship, embed, or
distribute any icon image, SVG, or icon-font file for these.** Each glyph is
drawn at runtime by the **viewer's own operating-system font** (Segoe UI
Emoji / Segoe UI Symbol on Windows, Apple Color Emoji on macOS/iOS, Noto on
Android/Linux).

**Licensing:** Unicode code points are an open industry standard published by
the **Unicode Consortium** and are **free to use with no license or
attribution** (see the Unicode Terms of Use, https://www.unicode.org/copyright.html).
The rendered glyph is supplied by the end user's OS font, which we neither
copy nor redistribute — so **no icon license is required or transferable** for
any item below.

| Glyph | Code point | Name | Used for |
|-------|-----------|------|----------|
| 🎓 | U+1F393 (`&#127891;`) | Graduation Cap | Expected-graduate marker on roster/contract cards |
| 🖨 | U+1F5A8 (`&#128424;`) | Printer | "Print All Evaluations" button |
| 🔍 | U+1F50D (`&#128269;`) | Magnifying Glass | Browse / search affordance |
| 👁 | U+1F441 (`&#128065;`) | Eye | "Read" indicator (student opened eval) |
| ⚑ | U+2691 (`&#9873;`) | Black Flag | Flag column |
| ▸ | U+25B8 (`&#9656;`) | Right-Pointing Triangle | Collapsible-section caret |
| ● | U+25CF (`&#9679;`) | Black Circle | "Unread" dot |
| ✓ | U+2713 | Check Mark | "Official / rolled", certified, confirmations |
| ✗ | U+2717 | Ballot X | Negative/incomplete marker |
| → | U+2192 | Rightwards Arrow | "Continue / open" affordances |
| ← | U+2190 | Leftwards Arrow | "Back" buttons |
| ↗ | U+2197 | North-East Arrow | External link (opens academic calendar) |
| ⚠ | U+26A0 | Warning Sign | Data-mismatch / withdrawn warnings |
| ▤ | U+25A4 | Square w/ Horizontal Fill | List/menu affordance |
| ▦ | U+25A6 | Square w/ Orthogonal Crosshatch | "Cards" layout-toggle button |
| ☰ | U+2630 | Trigram for Heaven | "List" layout-toggle button |
| × | U+00D7 (`&times;`) | Multiplication Sign | Slide-over panel close button |

The **"Early"** marker is a **plain-text chip** ("Early") styled with CSS — it
is not an icon and has no asset or license.

---

## 2. Logos — NCF brand assets

Bitmap PNG logos in `assets/`. **Currently referenced by the app:**

| File | Where obtained | Used in | License |
|------|----------------|---------|---------|
| `ncf-horiz-white.png` | Official NCF **Branding & Logos** package (Communications & Marketing), provided by Manuel Lopez (Prof., NCF) | App header + login screen | **NCF trademark / brand asset.** Used with institutional permission for an official NCF internal tool. Not licensed for third-party or commercial redistribution. |

**Present in `assets/` but NOT currently referenced** (candidates to remove or
keep as spares — same NCF-brand license applies): `ncf-horiz-color.png`,
`NCF Logo Horiz BLACK REV copy.png`, `NCF Logo Horiz BLACK copy.jpg`,
`NCF Shield RGB_no color copy.png`, `logo4winds.png`, `logo4winds-white.png`.

> **Action for SIG:** obtain written confirmation from NCF Communications &
> Marketing that the app may use the college wordmark/shield. Governing color
> and usage rules: NCF Brand Guidelines (July 2023) — Navy `#041E42` (PMS 282 C),
> Vegas Gold `#B3A369` (PMS 4515 C).

---

## 3. Fonts

| Font | Source | Used for | License |
|------|--------|----------|---------|
| **EB Garamond** (500, 600) | Google Fonts (`fonts.googleapis.com`) | Headings / serif display | **SIL Open Font License 1.1** — free, incl. commercial & web embedding |
| **Inter** (400–700) | Google Fonts | UI / body text | **SIL Open Font License 1.1** — free, incl. commercial & web embedding |
| System UI stack (Segoe UI, etc.) | Viewer's OS | Fallbacks | Provided by the OS; not distributed by us |

> NCF's official typefaces (Vendetta, American Captain, BSN 520) are
> Adobe/foundry-licensed and are **not** used on the web app; EB Garamond +
> Inter are the open-licensed web substitutes.

---

## 4. Third-party libraries with their own icons

| Library | Source | Visual assets | License |
|---------|--------|---------------|---------|
| **Quill** rich-text editor | CDN (`cdn.quilljs.com` / cdnjs) | Toolbar icons (bold/italic/underline, lists) are Quill's built-in inline **SVG** | **BSD-3-Clause** — free, incl. commercial |
| **Supabase JS** | CDN | No icons (data/auth client only) | **MIT** |

---

## 5. Summary for SIG

- **No purchased or third-party-licensed icon set is used.** All UI icons are
  open Unicode code points rendered by the viewer's OS font — nothing to
  license or hand over.
- **Only licensed visual assets are (a) the NCF logo PNGs** (institutional
  brand asset — needs a permission letter from NCF Comms & Marketing) and
  **(b) the Quill editor's built-in SVG icons** (BSD-3-Clause, already
  permissive).
- **Fonts** (EB Garamond, Inter) are **SIL OFL 1.1** — free for web use.

---

## 6. Critical theming & format (for the specifications document)

SIG can inspect every element in the prototype, so this lists only the
**critical** values that must be specified rather than inferred. Everything is
defined as CSS custom properties in `:root` at the top of `index.html`.

**Core palette (from the NCF Brand Guidelines, July 2023):**

| Token | Value | Pantone | Used for |
|-------|-------|---------|----------|
| `--ncf-navy` | `#202944` | PMS 533 | **Header bar background**, headings, active nav underline, primary accents |
| `--ncf-deep` | `#041E42` | PMS 282 C | Deep-navy accents, primary-button text on gold |
| `--ncf-gold` | `#B3A369` | PMS 4515 C | Primary buttons, active/completed badges |
| `--ncf-gold-dk` | `#8a7d45` | — | Gold hover/!border |
| `--ncf-content` | `#F7F4EF` | — | App background (warm off-white) |
| `--ncf-surface` | `#ffffff` | — | Card surfaces |
| `--ncf-amber-bg` | `#f6efd8` | — | Academic-probation highlight |

**Critical named elements:**

| Element | Spec |
|---------|------|
| Header/top bar | background `--ncf-navy` (`#202944`); logo `assets/ncf-horiz-white.png` at 38px tall; product wordmark in white |
| Primary button | background `--ncf-gold`, text `--ncf-deep` |
| Active nav tab | gold underline (`--ncf-gold`) |
| Body / UI type | **Inter** (sans), 14px base |
| Headings | **EB Garamond** was replaced by Inter on-screen; serif reserved for printed documents (the print document uses Arial) |
| Printed evaluation document | Arial/Helvetica, black on white (official-record format) |

**Note:** NCF's official typefaces (Vendetta, American Captain, BSN 520) are
Adobe/foundry-licensed and are **not** used; the web app uses the open-licensed
substitutes above. On-screen typography is sans-serif by design decision
(serif reserved for printed materials).
