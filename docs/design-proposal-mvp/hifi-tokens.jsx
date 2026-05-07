// Billbi hi-fi tokens — dark + light variants.
// Colors lifted exactly from the ehrax.dev design system screenshot.

window.BillbiTokens = {
  dark: {
    bg: '#0B0B0F',           // canvas around windows (slightly deeper than surface)
    surface: '#111113',      // primary surface
    surfaceAlt: '#16161A',   // hover/secondary
    surfaceAlt2: '#1B1B20',  // tertiary (rows on hover, etc.)
    border: '#232329',
    borderStrong: '#2E2E36',
    textPrimary: '#F7F7FA',
    textSecondary: '#A1A1AA',
    textMuted: '#6B6B75',
    accent: '#A1A1FF',
    accentHover: '#B5B5FF',
    accentMuted: '#A1A1FF22',
    success: '#7AC79A',
    successMuted: '#7AC79A1F',
    warning: '#E0B26B',
    warningMuted: '#E0B26B1F',
    danger: '#E07B7B',
    dangerMuted: '#E07B7B1F',
  },
  light: {
    bg: '#F2F2F4',
    surface: '#FFFFFF',
    surfaceAlt: '#F2F2F4',
    surfaceAlt2: '#E8E8EC',
    border: '#E5E5E7',
    borderStrong: '#D4D4D8',
    textPrimary: '#0A0A0B',
    textSecondary: '#52525B',
    textMuted: '#8E8E93',
    accent: '#4338CA',          // deeper indigo so white text passes WCAG AA
    accentHover: '#3730A3',
    accentMuted: '#4338CA14',
    success: '#2F8F5A',
    successMuted: '#2F8F5A14',
    warning: '#B57A1F',
    warningMuted: '#B57A1F14',
    danger: '#C24545',
    dangerMuted: '#C2454514',
  },
  // Type scale (px / line-height).
  type: {
    display: { size: 32, lh: 48, weight: 700 },
    heading: { size: 20, lh: 28, weight: 600 },
    subheading: { size: 16, lh: 24, weight: 500 },
    body: { size: 14, lh: 20, weight: 400 },
    small: { size: 12, lh: 16, weight: 400 },
    micro: { size: 10, lh: 14, weight: 500 },
  },
  // Spacing scale.
  space: { 1: 4, 2: 8, 3: 12, 4: 16, 5: 20, 6: 24, 8: 32, 10: 40, 12: 48, 16: 64, 20: 80 },
  radius: { sm: 4, md: 6, lg: 8, xl: 12, pill: 999 },
};

// Theme context — child components consume this to swap palettes.
window.ThemeCtx = React.createContext(window.BillbiTokens.dark);
window.useTheme = () => React.useContext(window.ThemeCtx);
