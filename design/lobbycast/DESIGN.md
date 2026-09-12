---
name: LobbyCast
colors:
  surface: '#faf9fe'
  surface-dim: '#dad9df'
  surface-bright: '#faf9fe'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f4f3f8'
  surface-container: '#eeedf3'
  surface-container-high: '#e9e7ed'
  surface-container-highest: '#e3e2e7'
  on-surface: '#1a1b1f'
  on-surface-variant: '#414755'
  inverse-surface: '#2f3034'
  inverse-on-surface: '#f1f0f5'
  outline: '#717786'
  outline-variant: '#c1c6d7'
  surface-tint: '#005bc1'
  primary: '#0058bc'
  on-primary: '#ffffff'
  primary-container: '#0070eb'
  on-primary-container: '#fefcff'
  inverse-primary: '#adc6ff'
  secondary: '#4c4aca'
  on-secondary: '#ffffff'
  secondary-container: '#6664e4'
  on-secondary-container: '#fffbff'
  tertiary: '#006672'
  on-tertiary: '#ffffff'
  tertiary-container: '#008190'
  on-tertiary-container: '#f7feff'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d8e2ff'
  primary-fixed-dim: '#adc6ff'
  on-primary-fixed: '#001a41'
  on-primary-fixed-variant: '#004493'
  secondary-fixed: '#e2dfff'
  secondary-fixed-dim: '#c2c1ff'
  on-secondary-fixed: '#0c006a'
  on-secondary-fixed-variant: '#3631b4'
  tertiary-fixed: '#9cf0ff'
  tertiary-fixed-dim: '#00daf3'
  on-tertiary-fixed: '#001f24'
  on-tertiary-fixed-variant: '#004f58'
  background: '#faf9fe'
  on-background: '#1a1b1f'
  surface-variant: '#e3e2e7'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  title-md:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-sm:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-caps:
    fontFamily: JetBrains Mono
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.05em
  status-code:
    fontFamily: JetBrains Mono
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 4px
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
  gutter: 16px
  margin-mobile: 16px
  margin-desktop: 48px
---

## Brand & Style

The design system is engineered for **LobbyCast**, a high-performance local network utility. The brand personality is rooted in speed, technical precision, and effortless collaboration. It prioritizes a "Zero-Lag" emotional response, ensuring users feel both the security of a private network and the velocity of modern data transfer.

The design style is **Modern Minimalist with Technical Accents**. It leverages high-density information layouts paired with generous white space to prevent cognitive overload during complex file operations. The aesthetic incorporates subtle glassmorphism and soft gradients to simulate the "airiness" of wireless signals, while maintaining a structured, corporate-grade reliability.

## Colors

The palette is anchored by **Electric Blue**, used exclusively for primary actions and "active" network states. **Deep Indigo** provides structural depth, appearing in headers or background gradients to distinguish the "Lobby" environment from the OS. **Vibrant Cyan** is reserved strictly for movement: progress bars, data packets, and successful handshakes.

- **Primary (Electric Blue):** Interactive elements, primary buttons, and active connectivity toggles.
- **Secondary (Deep Indigo):** Surface depth, secondary navigation, and "Host" mode backgrounds.
- **Tertiary (Vibrant Cyan):** Transfer progress, success states, and "Join" mode accents.
- **Neutral:** A scale of cool greys (from #F2F2F7 to #1C1C1E) used for borders, secondary text, and inactive states.

## Typography

This design system utilizes **Inter** for all UI and body copy to ensure maximum legibility across different screen densities. To lean into the "utility" aspect, **JetBrains Mono** is introduced for technical metadata, file sizes, IP addresses, and transfer speeds.

Headlines should use tighter letter spacing to maintain a compact, high-tech feel. Labels and technical data points should be set in monospace to allow for easy comparison of numerical values (like file sizes or transfer percentages) during active sessions.

## Layout & Spacing

The layout follows a **4px baseline grid** for micro-adjustments and a **12-column fluid grid** for desktop environments. In mobile views, a single-column stack is used with 16px side margins.

Key layouts are centered around "The Lobby"—a central container for active users. Use **16px (md)** spacing for internal card padding and **24px (lg)** for spacing between major UI sections. Elements involved in the transfer process (like file lists) should use high-density 8px vertical spacing to maximize information visibility.

## Elevation & Depth

Depth is communicated through **Tonal Layers** and **Subtle Glassmorphism**. 

- **Level 0 (Base):** Light grey (#F2F2F7) or white background.
- **Level 1 (Cards/Containers):** Pure white surface with a soft, 12% opacity Electric Blue shadow (0px 4px 20px) to simulate "lifting" from the network plane.
- **Level 2 (Modals/Overlays):** Backdrop blur (20px) with a semi-transparent white stroke (1px, 20% opacity) to create a frosted glass effect over the lobby view.

Avoid heavy black shadows. All shadows must be tinted with the Primary or Secondary color to maintain the "high-tech" glow associated with active signals.

## Shapes

The shape language is defined by **16px (rounded-lg)** corners for primary containers and buttons. This creates a friendly yet professional silhouette. Smaller components like chips or checkboxes utilize 8px (standard) radii. 

User avatars are an exception; they must be perfectly **circular** to accommodate the "Status Ring" system that rotates during active file uploads or downloads.

## Components

### Buttons
- **Primary (Action):** Rounded-lg, Electric Blue background, white text. Use a subtle linear gradient (Electric Blue to Deep Indigo) to indicate "Host" actions.
- **Secondary (Join):** Rounded-lg, white background with a 1px Cyan border.

### Status Rings (Avatars)
Avatars must be encased in a 3px border ring. 
- **Static:** Solid Grey.
- **Transmitting:** Dashed Cyan (animating clockwise).
- **Receiving:** Dashed Blue (animating counter-clockwise).

### Progress Bars
Progress bars utilize a "Dual-Track" system. The background track is a soft grey, and the foreground is a Vibrant Cyan gradient. For multi-file transfers, include a small monospace label above the bar indicating "X of Y files" and "Speed (MB/s)".

### Input Fields
Minimalist styling with a 1px border. When focused, the border transitions to Electric Blue with a soft 4px outer glow.

### Cards
Use for file previews and peer discovery. Cards should include a prominent icon indicating file type (using the Cyan/Blue palette) and a "Quick Share" button that appears on hover/tap.