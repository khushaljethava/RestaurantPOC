---
name: Stallion POS Admin
colors:
  surface: '#E9EFEB'
  surface-dim: '#d7dbd7'
  surface-bright: '#f7faf6'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f1f4f1'
  surface-container: '#ebefeb'
  surface-container-high: '#e6e9e5'
  surface-container-highest: '#e0e3e0'
  on-surface: '#171D1A'
  on-surface-variant: '#3f4944'
  inverse-surface: '#2d312f'
  inverse-on-surface: '#eef2ee'
  outline: '#6f7974'
  outline-variant: '#bec9c3'
  surface-tint: '#156b54'
  primary: '#00513e'
  on-primary: '#FFFFFF'
  primary-container: '#A4F2D5'
  on-primary-container: '#9ae9cb'
  inverse-primary: '#88d6b9'
  secondary: '#56615b'
  on-secondary: '#ffffff'
  secondary-container: '#dae5de'
  on-secondary-container: '#5c6761'
  tertiary: '#73332c'
  on-tertiary: '#ffffff'
  tertiary-container: '#904a42'
  on-tertiary-container: '#ffcdc6'
  error: '#BA1A1A'
  on-error: '#ffffff'
  error-container: '#FFDAD6'
  on-error-container: '#93000a'
  primary-fixed: '#a4f2d5'
  primary-fixed-dim: '#88d6b9'
  on-primary-fixed: '#002117'
  on-primary-fixed-variant: '#00513e'
  secondary-fixed: '#dae5de'
  secondary-fixed-dim: '#bec9c2'
  on-secondary-fixed: '#141e19'
  on-secondary-fixed-variant: '#3f4944'
  tertiary-fixed: '#ffdad5'
  tertiary-fixed-dim: '#ffb4aa'
  on-tertiary-fixed: '#3b0906'
  on-tertiary-fixed-variant: '#73332c'
  background: '#F5FBF6'
  on-background: '#181c1a'
  surface-variant: '#e0e3e0'
  border: '#BFC9C3'
  success: '#1B6C3D'
  warning: '#8A5300'
  warning-container: '#FFF0D4'
typography:
  headline-lg:
    fontFamily: Roboto
    fontSize: 24px
    fontWeight: '400'
    lineHeight: 32px
  header-md:
    fontFamily: Roboto
    fontSize: 16px
    fontWeight: '500'
    lineHeight: 24px
  body-md:
    fontFamily: Roboto
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  table-cell:
    fontFamily: Roboto
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-sm:
    fontFamily: Roboto
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 16px
  currency-display:
    fontFamily: Roboto
    fontSize: 20px
    fontWeight: '500'
    lineHeight: 28px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  sidebar-width: 224px
  page-padding: 32px
  table-row-height: 44px
  gutter: 16px
  margin-mobile: 16px
  margin-desktop: 32px
---

## Brand & Style

The design system is engineered for the high-velocity environment of Indian street-food stalls. The brand personality is **utilitarian, dependable, and transparent**, prioritizing functional speed over decorative flair. It serves stall owners and food court administrators who require immediate data clarity during peak service hours.

The chosen style is **Corporate / Modern**, specifically utilizing **Google Material 3** principles. The interface emphasizes:
- **High Data Density:** Compact layouts and sticky headers for administrative efficiency.
- **Content over Chrome:** Minimal use of icons and decorative elements; information hierarchy is driven by typography and color.
- **Flat Elevation:** Depth is communicated through tonal shifts rather than drop shadows, ensuring a crisp, modern digital-first aesthetic.
- **Keyboard Optimization:** Visible focus states and logical tabbing orders for seated, high-speed desk use.

## Colors

The color system is derived from deep, botanical greens to evoke freshness and trust, contrasting with a neutral, slightly warm-grey background for reduced eye strain.

- **Primary & Containers:** Use `#156B54` for core actions. The `primary-container` (`#A4F2D5`) is used for active states or subtle grouping.
- **Neutral Surface:** The `page-background` is a very light mint-white (`#F5FBF6`), while `surface` (`#E9EFEB`) is used for cards and sheets to create tonal separation without shadows.
- **Status Indicators:** 
    - **Success (Paid/Ready):** `#1B6C3D`
    - **Warning (Pending):** `#8A5300` on a `#FFF0D4` background.
    - **Error:** `#BA1A1A`.
- **Text:** Maintain high legibility with `#171D1A` for body text and `#3F4944` for secondary or helper information.

## Typography

This design system uses **Roboto** exclusively to ensure compatibility with Material 3 standards and excellent legibility across diverse screen qualities.

- **Financial Data:** All currency amounts (INR ₹) and numeric quantities must use **Tabular Figures** (`tnum`) to ensure columns align perfectly in tables and receipts.
- **Hierarchy:** Use `headline-lg` for page titles and `header-md` for section grouping. 
- **Sentence Case:** Titles and labels must use sentence case (e.g., "Place order") to maintain an approachable, professional tone. Avoid all-caps.

## Layout & Spacing

The layout utilizes a **Fixed Grid** approach for the core navigation while allowing the content area to be fluid.

- **Desktop Shell:** Features a persistent left sidebar fixed at `224px`. The main content area uses a standard `32px` padding.
- **Vertical Rhythm:** A strict adherence to 44px for table rows and input heights ensures high data density while remaining accessible for mouse clicks.
- **Grid:** Use a 12-column system for dashboard layouts. On mobile, transition to a single-column layout with 16px side margins.
- **Alignment:** Financial values and quantities in tables are always **right-aligned** to the gutter.

## Elevation & Depth

This design system rejects the use of drop shadows in favor of **Tonal Layers**.

- **Surfaces:** Depth is achieved by placing elements on surfaces with slightly different hex values (e.g., a card using `#E9EFEB` against a page background of `#F5FBF6`).
- **Dividers:** Use `#BFC9C3` for 1px hairline dividers to separate list items or table rows.
- **State Feedback:** Hover states should utilize a subtle 4-8% opacity overlay of the primary color rather than an elevation lift.
- **Focus Rings:** Use a 2px solid primary color (`#156B54`) outline with a 2px offset for all interactive elements to support keyboard navigation.

## Shapes

The shape language follows a structured hierarchy based on the container's purpose:

- **Large Containers:** Cards and list containers use a `12px` radius.
- **Interactive Elements:** Buttons and form inputs use a tighter `8px` radius for a more precise, functional look.
- **Informational Elements:** Status pills and chips are fully rounded (pill-shaped) to distinguish them from actionable buttons.
- **Overlays:** Bottom sheets (on mobile-responsive views) use a `16px` top-only radius.

## Components

### Buttons
- **Primary:** Filled with `#156B54` and white text. Use for the main goal (e.g., "Place order").
- **Tonal:** Use `primary-container` background with primary text.
- **Outlined:** 1px border using `#BFC9C3` with primary text.

### Tables
- **Row Height:** Strictly `44px`.
- **Headers:** Sticky at the top, using the `#E9EFEB` surface color to distinguish from the scrolling body.
- **Cells:** 14px Roboto. Currency is right-aligned.

### Status Pills
- Always include text labels inside the pill; never rely on color alone.
- Use a rounded-full background with high-contrast text.

### Inputs & Selects
- **Border:** 1px solid using `#BFC9C3`.
- **Radius:** 8px.
- **Height:** 44px to match table row density.
- **Focus:** 2px primary border.

### Sidebar (Admin)
- Fixed at `224px`.
- Active link: Indicated by a bold weight and a 4px wide vertical green indicator on the left edge.

### Cards
- Radius: 12px.
- Background: `#E9EFEB`.
- No shadows; use 1px borders if further separation from background is required.