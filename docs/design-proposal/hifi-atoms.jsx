// Billbi hi-fi atoms — Pill, Button, Card, Row, Field, NumDisplay, Window.
// All consume ThemeCtx; the same component renders correctly in dark or light.

const HF_FONT_UI = "'Geist', 'Inter', -apple-system, BlinkMacSystemFont, sans-serif";
const HF_FONT_NUM = "'Fira Code', 'JetBrains Mono', ui-monospace, monospace";

// Detect dark vs light theme from any token set (Billbi OR Happines OR future ones)
// by reading the surface luminance. Cheap and theme-agnostic.
function isDarkTheme(theme) {
  const hex = (theme.surface || '#000').replace('#', '');
  const n = hex.length === 3
    ? parseInt(hex.split('').map(c => c + c).join(''), 16)
    : parseInt(hex.slice(0, 6), 16);
  const r = (n >> 16) & 0xff, g = (n >> 8) & 0xff, b = n & 0xff;
  // Rec. 709 luma; <0.5 = dark.
  return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255 < 0.5;
}

// Window — replaces the generic Mac chrome. No traffic lights (user said "no chrome").
// Just a clean elevated surface with subtle border, like Linear's app frame.
function HFWindow({ children, theme, width = 1200, height = 760, style }) {
  const t = theme || useTheme();
  return (
    <div style={{
      width, height,
      background: t.surface,
      border: `1px solid ${t.border}`,
      borderRadius: 12,
      overflow: 'hidden',
      display: 'flex',
      fontFamily: HF_FONT_UI,
      color: t.textPrimary,
      fontSize: 14,
      lineHeight: '20px',
      boxShadow: isDarkTheme(t)
        ? '0 1px 0 #ffffff08 inset, 0 24px 60px #0008'
        : '0 1px 0 #ffffff inset, 0 12px 32px #0a0a0b18',
      ...style,
    }}>
      {children}
    </div>
  );
}

// Sidebar — narrow nav for Mac.
function HFSidebar({ active = 'projects', theme, brand = 'ehrax.dev', brandInitial = 'p', projects }) {
  const t = theme || useTheme();
  const items = [
    { id: 'dashboard', label: 'Dashboard', icon: '◇' },
    { id: 'projects', label: 'Projects', icon: '▣' },
    { id: 'invoices', label: 'Invoices', icon: '✕', count: 2 },
    { id: 'clients', label: 'Clients', icon: '○' },
  ];
  const projs = projects || [
    { name: 'bikepark-thunersee', dot: '#6B7BFF' },
    { name: 'helvetia-tools', dot: '#7AC79A', activeId: 'helvetia' },
    { name: 'ehrax-internal', dot: t.textMuted },
  ];
  return (
    <div style={{
      width: 220,
      background: t.surface,
      borderRight: `1px solid ${t.border}`,
      padding: '20px 12px',
      display: 'flex', flexDirection: 'column', gap: 2,
      flex: '0 0 auto',
    }}>
      <div style={{
        display: 'flex', alignItems: 'center', gap: 10,
        padding: '6px 10px 18px',
      }}>
        <div style={{
          width: 22, height: 22, borderRadius: 6,
          background: t.textPrimary, color: t.surface,
          display: 'grid', placeItems: 'center',
          fontWeight: 700, fontSize: 11, letterSpacing: -0.5,
        }}>{brandInitial}</div>
        <span style={{ fontWeight: 600, fontSize: 14, letterSpacing: -0.2 }}>{brand}</span>
      </div>
      <HFNavLabel theme={t}>Workspace</HFNavLabel>
      {items.map((it) => (
        <HFNavItem key={it.id} active={active === it.id} icon={it.icon} count={it.count} theme={t}>
          {it.label}
        </HFNavItem>
      ))}
      <div style={{ height: 18 }} />
      <HFNavLabel theme={t}>Projects</HFNavLabel>
      {projs.map((p) => (
        <HFNavItem key={p.name} theme={t} dot={p.dot} active={p.activeId && active === p.activeId}>{p.name}</HFNavItem>
      ))}
      <div style={{ flex: 1 }} />
      <HFNavItem theme={t} icon="⚙">Settings</HFNavItem>
    </div>
  );
}
function HFNavLabel({ children, theme }) {
  return (
    <div style={{
      fontSize: 10, fontWeight: 500, letterSpacing: 0.6, textTransform: 'uppercase',
      color: theme.textMuted, padding: '4px 10px 6px',
    }}>{children}</div>
  );
}
function HFNavItem({ children, active, icon, count, dot, theme }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 10,
      padding: '7px 10px',
      borderRadius: 6,
      background: active ? theme.surfaceAlt : 'transparent',
      color: active ? theme.textPrimary : theme.textSecondary,
      fontSize: 13, fontWeight: active ? 500 : 400,
      cursor: 'default',
    }}>
      {dot ? (
        <span style={{ width: 6, height: 6, borderRadius: 3, background: dot, flex: '0 0 auto' }} />
      ) : icon ? (
        <span style={{ width: 14, fontSize: 11, color: theme.textMuted, textAlign: 'center' }}>{icon}</span>
      ) : null}
      <span style={{ flex: 1, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{children}</span>
      {count != null ? (
        <span style={{ fontFamily: HF_FONT_NUM, fontSize: 10, color: theme.textMuted }}>{count}</span>
      ) : null}
    </div>
  );
}

// Pill — small status indicator.
function HFPill({ tone = 'neutral', children, theme }) {
  const t = theme || useTheme();
  const map = {
    ready:     { fg: t.success, bg: t.successMuted },
    finalized: { fg: t.warning, bg: t.warningMuted },
    sent:      { fg: t.warning, bg: t.warningMuted },
    overdue:   { fg: t.danger,  bg: t.dangerMuted },
    paid:      { fg: t.success, bg: t.successMuted },
    accent:    { fg: t.accent,  bg: t.accentMuted },
    neutral:   { fg: t.textSecondary, bg: t.surfaceAlt },
  };
  const c = map[tone] || map.neutral;
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 6,
      padding: '2px 8px',
      fontSize: 11, fontWeight: 500, letterSpacing: 0.1,
      color: c.fg, background: c.bg,
      borderRadius: 4,
      lineHeight: '16px',
    }}>
      <span style={{ width: 5, height: 5, borderRadius: 3, background: c.fg }} />
      {children}
    </span>
  );
}

// Button.
function HFButton({ children, primary, ghost, danger, size = 'md', icon, theme, style }) {
  const t = theme || useTheme();
  const pad = size === 'sm' ? '5px 10px' : size === 'lg' ? '10px 18px' : '7px 14px';
  const fontSize = size === 'sm' ? 12 : 14;
  let bg, fg, border;
  if (primary) {
    // Dark accent (#A1A1FF) is light enough that dark ink reads cleanly.
    // Light accent (#4D4DFF) is saturated → black text vibrates; use white.
    bg = t.accent;
    fg = isDarkTheme(t) ? '#0A0A0B' : '#FFFFFF';
    border = t.accent;
  } else if (danger) {
    bg = t.dangerMuted; fg = t.danger; border = 'transparent';
  } else if (ghost) {
    bg = 'transparent'; fg = t.textSecondary; border = 'transparent';
  } else {
    bg = t.surfaceAlt; fg = t.textPrimary; border = t.border;
  }
  return (
    <button style={{
      fontFamily: HF_FONT_UI,
      fontSize, fontWeight: 500, letterSpacing: -0.1,
      padding: pad,
      background: bg, color: fg,
      border: `1px solid ${border}`,
      borderRadius: 6,
      cursor: 'pointer',
      display: 'inline-flex', alignItems: 'center', gap: 6,
      whiteSpace: 'nowrap',
      ...style,
    }}>
      {icon ? <span style={{ fontSize: 12, opacity: 0.85 }}>{icon}</span> : null}
      {children}
    </button>
  );
}

// Card / surface block.
function HFCard({ children, theme, style, padding = 20 }) {
  const t = theme || useTheme();
  return (
    <div style={{
      background: t.surface,
      border: `1px solid ${t.border}`,
      borderRadius: 8,
      padding,
      ...style,
    }}>{children}</div>
  );
}

// Number display — Fira Code, tabular, with optional symbol.
function HFNum({ children, size = 14, color, theme, weight = 400 }) {
  const t = theme || useTheme();
  return (
    <span style={{
      fontFamily: HF_FONT_NUM,
      fontVariantNumeric: 'tabular-nums',
      fontSize: size, fontWeight: weight,
      color: color || t.textPrimary,
      letterSpacing: -0.2,
    }}>{children}</span>
  );
}

// Money — formats numbers as €1'234.56 (Swiss apostrophe separator, common in CH).
// Pass either { amount: 1234.56 } or a pre-formatted string in `children` (rare).
// Defaults to no decimals when amount is a round euro value.
function fmtMoney(amount, { decimals, currency = '€' } = {}) {
  if (amount == null) return '';
  const d = decimals == null
    ? (Math.abs(amount % 1) < 0.005 ? 0 : 2)
    : decimals;
  const s = Math.abs(amount).toFixed(d);
  const [int, frac] = s.split('.');
  // Swiss apostrophe (U+2019) for thousands. Tight, unambiguous, common in CH/DE invoicing.
  const grouped = int.replace(/\B(?=(\d{3})+(?!\d))/g, '\u2019');
  const sign = amount < 0 ? '-' : '';
  return `${sign}${currency}${grouped}${frac ? '.' + frac : ''}`;
}
function HFMoney({ amount, decimals, currency, size = 14, color, theme, weight = 400 }) {
  return <HFNum size={size} color={color} theme={theme} weight={weight}>{fmtMoney(amount, { decimals, currency })}</HFNum>;
}

// Field — text input.
function HFField({ label, value, placeholder, prefix, suffix, theme, size = 'md', focus, style, monospace }) {
  const t = theme || useTheme();
  const h = size === 'sm' ? 28 : size === 'lg' ? 40 : 32;
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 6, ...style }}>
      {label ? (
        <span style={{ fontSize: 11, color: t.textSecondary, fontWeight: 500, letterSpacing: 0.1 }}>{label}</span>
      ) : null}
      <div style={{
        display: 'flex', alignItems: 'center',
        height: h, padding: '0 10px',
        background: t.surfaceAlt,
        border: `1px solid ${focus ? t.accent : t.border}`,
        borderRadius: 6,
        boxShadow: focus ? `0 0 0 3px ${t.accentMuted}` : 'none',
        gap: 6,
      }}>
        {prefix ? <span style={{ color: t.textMuted, fontSize: 13 }}>{prefix}</span> : null}
        <span style={{
          flex: 1,
          fontFamily: monospace ? HF_FONT_NUM : HF_FONT_UI,
          fontSize: 13,
          color: value ? t.textPrimary : t.textMuted,
          fontVariantNumeric: monospace ? 'tabular-nums' : 'normal',
        }}>{value || placeholder}</span>
        {suffix ? <span style={{ color: t.textMuted, fontSize: 12 }}>{suffix}</span> : null}
      </div>
    </div>
  );
}

// Section heading inside a screen.
function HFSectionLabel({ children, theme, action }) {
  const t = theme || useTheme();
  return (
    <div style={{
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      fontSize: 11, fontWeight: 500, letterSpacing: 0.4, textTransform: 'uppercase',
      color: t.textMuted,
      padding: '0 0 8px',
    }}>
      <span>{children}</span>
      {action}
    </div>
  );
}

// Divider line.
function HFDivider({ theme, style }) {
  const t = theme || useTheme();
  return <div style={{ height: 1, background: t.border, ...style }} />;
}

// Top bar — used in Mac app shell. Title + breadcrumbs + actions.
function HFTopBar({ children, right, theme }) {
  const t = theme || useTheme();
  return (
    <div style={{
      height: 52, padding: '0 24px',
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      borderBottom: `1px solid ${t.border}`,
      flex: '0 0 auto',
      background: t.surface,
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>{children}</div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>{right}</div>
    </div>
  );
}

Object.assign(window, {
  HF_FONT_UI, HF_FONT_NUM,
  HFWindow, HFSidebar, HFNavItem, HFNavLabel,
  HFPill, HFButton, HFCard, HFNum, HFMoney, fmtMoney, HFField,
  HFSectionLabel, HFDivider, HFTopBar,
});
