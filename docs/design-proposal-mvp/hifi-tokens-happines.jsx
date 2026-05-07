// happ.ines_creations tokens — warm artisanal palette.
// Same structure as BillbiTokens so all atoms work unchanged. Accent is a warm
// terracotta/clay (handmade ceramics vibe), surfaces are slightly creamy in
// light, deep warm-brown in dark instead of cool slate.

window.HappinesTokens = {
  dark: {
    bg: '#100D0B',           // warm near-black
    surface: '#16120F',
    surfaceAlt: '#1C1815',
    surfaceAlt2: '#221D1A',
    border: '#2E2722',
    borderStrong: '#3D342D',
    textPrimary: '#F7F2EC',  // warm off-white
    textSecondary: '#B8AFA6',
    textMuted: '#7A6F65',
    accent: '#F08A5D',       // saturated terracotta — pops on warm-black
    accentHover: '#F79B72',
    accentMuted: '#F08A5D24',
    success: '#A3C49A',      // sage
    successMuted: '#A3C49A1F',
    warning: '#E8C875',      // honey
    warningMuted: '#E8C8751F',
    danger: '#D9897C',       // dusty rose-red
    dangerMuted: '#D9897C1F',
  },
  light: {
    bg: '#F7F1EB',           // cream
    surface: '#FFFCF8',      // ivory
    surfaceAlt: '#F2EBE3',
    surfaceAlt2: '#E8DFD4',
    border: '#E5DBCD',
    borderStrong: '#D2C4B0',
    textPrimary: '#1A1410',  // warm near-black
    textSecondary: '#5C4E42',
    textMuted: '#8E7E6E',
    accent: '#B85C3A',        // deeper terracotta so white text passes WCAG AA
    accentHover: '#9A4A2D',
    accentMuted: '#B85C3A14',
    success: '#5A8A4F',
    successMuted: '#5A8A4F14',
    warning: '#A6791D',
    warningMuted: '#A6791D14',
    danger: '#B0463A',
    dangerMuted: '#B0463A14',
  },
  // Same type/space/radius scales as Billbi.
  type: {
    display: { size: 32, lh: 48, weight: 700 },
    heading: { size: 20, lh: 28, weight: 600 },
    subheading: { size: 16, lh: 24, weight: 500 },
    body: { size: 14, lh: 20, weight: 400 },
    small: { size: 12, lh: 16, weight: 400 },
    micro: { size: 10, lh: 14, weight: 500 },
  },
  space: { 1: 4, 2: 8, 3: 12, 4: 16, 5: 20, 6: 24, 8: 32, 10: 40, 12: 48, 16: 64, 20: 80 },
  radius: { sm: 4, md: 6, lg: 8, xl: 12, pill: 999 },
};
