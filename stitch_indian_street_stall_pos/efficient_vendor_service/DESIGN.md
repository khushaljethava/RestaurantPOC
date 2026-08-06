---
name: Efficient Vendor Service
colors:
  surface: '#f5fbf5'
  surface-dim: '#d5dcd6'
  surface-bright: '#f5fbf5'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#eff5f0'
  surface-container: '#e9efea'
  surface-container-high: '#e4eae4'
  surface-container-highest: '#dee4df'
  on-surface: '#171d1a'
  on-surface-variant: '#3f4944'
  inverse-surface: '#2c322e'
  inverse-on-surface: '#ecf2ed'
  outline: '#6f7974'
  outline-variant: '#bec9c3'
  surface-tint: '#156b54'
  primary: '#00513e'
  on-primary: '#ffffff'
  primary-container: '#156b54'
  on-primary-container: '#9ae9cb'
  inverse-primary: '#88d6b9'
  secondary: '#1b6c3d'
  on-secondary: '#ffffff'
  secondary-container: '#a4f4b8'
  on-secondary-container: '#237242'
  tertiary: '#673d00'
  on-tertiary: '#ffffff'
  tertiary-container: '#885200'
  on-tertiary-container: '#ffd0a0'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#a4f2d5'
  primary-fixed-dim: '#88d6b9'
  on-primary-fixed: '#002117'
  on-primary-fixed-variant: '#00513e'
  secondary-fixed: '#a4f4b8'
  secondary-fixed-dim: '#89d89e'
  on-secondary-fixed: '#00210d'
  on-secondary-fixed-variant: '#00522a'
  tertiary-fixed: '#ffdcbb'
  tertiary-fixed-dim: '#ffb869'
  on-tertiary-fixed: '#2b1700'
  on-tertiary-fixed-variant: '#673d00'
  background: '#f5fbf5'
  on-background: '#171d1a'
  surface-variant: '#dee4df'
typography:
  display-title:
    fontFamily: Roboto
    fontSize: 24px
    fontWeight: '400'
    lineHeight: 32px
  section-header:
    fontFamily: Roboto
    fontSize: 16px
    fontWeight: '500'
    lineHeight: 24px
  body-main:
    fontFamily: Roboto
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-secondary:
    fontFamily: Roboto
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-caption:
    fontFamily: Roboto
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.5px
  money-display:
    fontFamily: Roboto
    fontSize: 16px
    fontWeight: '500'
    lineHeight: 24px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  touch-target-min: 48px
  gutter: 16px
  margin-page: 16px
  bottom-action-height: 56px
---

## Brand & Style
The design system focuses on high-speed operational efficiency for high-volume food environments. The personality is utilitarian, dependable, and invisible—prioritizing the transaction over the interface.

Drawing from **Corporate / Modern** and **Minimalist** influences, the system adheres to the core principles of Material 3:
- **Content over Chrome:** UI elements serve only to organize information; decorative flourishes are omitted to reduce cognitive load during a rush.
- **Strong Hierarchy:** Critical transaction data (order totals, item counts) is prioritized through scale and weight.
- **Functional Clarity:** Statuses are communicated through clear color-coding and semantic labeling, ensuring the state of an order is understood at a glance.

## Colors
The palette uses a professional green-centric theme to evoke cleanliness and growth, common in food service environments.

- **Primary:** Used for the most important actions and active states.
- **Surface & Background:** A subtle green-tinted neutral provides a softer contrast than pure white, reducing eye strain for cashiers during long shifts.
- **Status Indicators:** 
    - **Paid/Ready:** Semantic green (#1B6C3D) for successful completion.
    - **Pending/Held:** Warm amber tones (#8A5300) to signal items requiring attention.
    - **Destructive:** Bright red (#BA1A1A) for errors or order cancellations.

## Typography
The system uses Roboto across all levels to maintain a clean, systematic appearance.

- **Case Style:** Use sentence case for all UI strings, including labels and headers. Avoid all-caps.
- **Monetary Values:** All currency displays must use **tabular figures** to ensure decimal points and digits align vertically in lists and receipts.
- **Alignment:** Currency should always be right-aligned in data tables and list rows to allow for easy price comparison.
- **Copy Tone:** Action labels must be verbs (e.g., "Place order" instead of "Submit").

## Layout & Spacing
The layout is optimized for high-speed, one-handed interaction.

- **Grid Model:** A fluid grid with 16px margins and gutters. 
- **Touch Strategy:** Every interactive element must meet a minimum 48dp touch target. 
- **Bottom-Heavy Design:** The primary action (e.g., "Place order", "Collect payment") is always anchored to the bottom of the screen, spanning the full width at a height of 56px for easy thumb reach.
- **Lists:** Order lists utilize 16px vertical padding between items to prevent accidental taps.

## Elevation & Depth
This design system avoids traditional drop shadows in favor of **Tonal Layers** to represent depth.

- **Level 0 (Background):** Used for the main page canvas (#F5FBF6).
- **Level 1 (Surface):** Used for cards, list items, and containers (#E9EFEB). These surfaces should be distinguished by their background color rather than shadows.
- **Level 2 (Active/Pressed):** A subtle 8% primary color overlay indicates a pressed state on buttons and list rows.
- **Overlays:** Bottom sheets use a 16px corner radius and sit atop a 40% opacity scrim to focus user attention on the immediate task.

## Shapes
The shape language balances modern aesthetics with functional grouping.

- **Cards & Rows:** 12px radius provides a soft but structured look for primary content containers.
- **Small Components:** Inputs and secondary buttons use an 8px radius for a more precise, technical feel.
- **Bottom Sheets:** 16px top-corner radius for a distinct "sheet" metaphor.
- **Chips:** Fully rounded (pill-shaped) to represent discrete, filterable, or selectable metadata.

## Components
### Buttons
- **Primary Action:** 56px height, full-width, anchored to bottom. Uses Primary Color with White text.
- **Secondary Action:** 40px-48px height, Outlined style using the border color token.

### Input Fields
- **Style:** Outlined with 8px corner radius.
- **Active State:** Border thickens to 2px using the primary color.
- **Validation:** Errors use Error Color (#BA1A1A) for text and borders, with Error Background for the field fill.

### List Rows
- **Dimensions:** Minimum 56px height for tap-friendliness.
- **Layout:** Leading icon or quantity, followed by item name and secondary modifiers, with the price right-aligned in tabular figures.
- **Shape:** 12px corner radius when grouped in a card.

### Chips
- **Usage:** For food categories or item modifiers (e.g., "Extra Spicy").
- **Style:** Fully rounded, Primary Container background with Primary text for active states.

### Cards
- **Usage:** To group related items in an order or summarize daily totals.
- **Style:** 12px radius, no shadow, background color #E9EFEB.

### Status Indicators
- **Paid/Ready:** Solid green pill (#1B6C3D) with white text.
- **Pending/Held:** Amber background (#FFF0D4) with dark amber text (#8A5300).