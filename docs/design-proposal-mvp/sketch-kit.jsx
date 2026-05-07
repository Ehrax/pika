// Shared sketchy wireframe primitives.
// Aesthetic: hand-drawn but legible. Caveat font for headings, Architects Daughter for body.
// B&W with single warm accent for state (paid / overdue / ready). Slight wobble via SVG filter.

const ACCENT = '#d94f3a';        // warm red — overdue / attention
const ACCENT_OK = '#3a7a52';     // muted green — paid / ready
const ACCENT_WARN = '#c98a2b';   // ochre — sent / draft pending
const INK = '#1f1d1b';
const PAPER = '#fbf8f1';
const PAPER_2 = '#f3eee2';
const RULE = '#1f1d1b';

// SVG filter that gives strokes a hand-drawn wobble. Inject once at top of doc.
function SketchFilters() {
  return (
    <svg width="0" height="0" style={{ position: 'absolute' }} aria-hidden>
      <defs>
        <filter id="wobble">
          <feTurbulence type="fractalNoise" baseFrequency="0.022" numOctaves="2" seed="3" />
          <feDisplacementMap in="SourceGraphic" scale="1.4" />
        </filter>
        <filter id="wobble-strong">
          <feTurbulence type="fractalNoise" baseFrequency="0.04" numOctaves="2" seed="7" />
          <feDisplacementMap in="SourceGraphic" scale="2.4" />
        </filter>
        <pattern id="paper-grid" width="22" height="22" patternUnits="userSpaceOnUse">
          <path d="M 22 0 L 0 0 0 22" fill="none" stroke="#1f1d1b" strokeWidth="0.4" opacity="0.07" />
        </pattern>
      </defs>
    </svg>
  );
}

// A rough rectangle drawn with SVG so it gets the wobble filter.
function SketchBox({ width = '100%', height = '100%', radius = 6, fill = 'none', stroke = INK, strokeWidth = 1.4, dashed = false, style }) {
  return (
    <svg width={width} height={height} style={{ display: 'block', overflow: 'visible', ...style }} aria-hidden>
      <rect x="2" y="2" width="calc(100% - 4)" height="calc(100% - 4)"
        rx={radius} ry={radius}
        fill={fill} stroke={stroke} strokeWidth={strokeWidth}
        strokeDasharray={dashed ? '5 4' : undefined}
        filter="url(#wobble)" vectorEffect="non-scaling-stroke" />
    </svg>
  );
}

// Container that paints a sketchy border around its children using an absolutely-positioned svg.
function SketchFrame({ children, radius = 8, stroke = INK, fill = PAPER, dashed = false, padding = 0, style = {} }) {
  return (
    <div style={{ position: 'relative', background: fill, borderRadius: radius, padding, ...style }}>
      <svg style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', pointerEvents: 'none' }} aria-hidden>
        <rect x="2.5" y="2.5" width="calc(100% - 5)" height="calc(100% - 5)"
          rx={radius} ry={radius}
          fill="none" stroke={stroke} strokeWidth="1.4"
          strokeDasharray={dashed ? '5 4' : undefined}
          filter="url(#wobble)" vectorEffect="non-scaling-stroke" />
      </svg>
      <div style={{ position: 'relative' }}>{children}</div>
    </div>
  );
}

// Hand-drawn underline / divider line.
function SketchRule({ width = '100%', stroke = INK, strokeWidth = 1.2, dashed = false, style }) {
  return (
    <svg width={width} height="6" style={{ display: 'block', overflow: 'visible', ...style }} aria-hidden>
      <line x1="2" y1="3" x2="calc(100% - 2)" y2="3"
        stroke={stroke} strokeWidth={strokeWidth}
        strokeDasharray={dashed ? '4 4' : undefined}
        filter="url(#wobble)" vectorEffect="non-scaling-stroke" />
    </svg>
  );
}

// Squiggly placeholder for an image / chart area.
function SketchPlaceholder({ width = '100%', height = 80, label = 'placeholder', dashed = true, style }) {
  return (
    <div style={{ position: 'relative', width, height, ...style }}>
      <SketchBox width="100%" height="100%" dashed={dashed} radius={4} />
      <div style={{
        position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center',
        fontFamily: 'var(--mono)', fontSize: 10, color: '#7a7468', letterSpacing: 0.5, textTransform: 'lowercase',
        textAlign: 'center', padding: 8,
      }}>{label}</div>
    </div>
  );
}

// Sketchy circle (for emoji circles, status dots).
function SketchCircle({ size = 22, fill = 'none', stroke = INK, strokeWidth = 1.3, children, style }) {
  return (
    <span style={{ position: 'relative', display: 'inline-flex', width: size, height: size, alignItems: 'center', justifyContent: 'center', ...style }}>
      <svg width={size} height={size} style={{ position: 'absolute', inset: 0, overflow: 'visible' }} aria-hidden>
        <circle cx={size / 2} cy={size / 2} r={size / 2 - 2}
          fill={fill} stroke={stroke} strokeWidth={strokeWidth}
          filter="url(#wobble)" vectorEffect="non-scaling-stroke" />
      </svg>
      <span style={{ position: 'relative', fontSize: size * 0.55, lineHeight: 1 }}>{children}</span>
    </span>
  );
}

// Status pill — 1 accent for state.
function StatePill({ state, children }) {
  const map = {
    paid: { fg: ACCENT_OK, label: 'paid' },
    overdue: { fg: ACCENT, label: 'overdue' },
    sent: { fg: ACCENT_WARN, label: 'sent' },
    ready: { fg: ACCENT_OK, label: 'ready' },
    finalized: { fg: ACCENT_WARN, label: 'finalized' },
    active: { fg: '#7a7468', label: 'active' },
  };
  const s = map[state] || { fg: INK, label: state };
  return (
    <span style={{ position: 'relative', display: 'inline-flex', alignItems: 'center', gap: 4,
      padding: '1px 8px 2px', borderRadius: 999, color: s.fg,
      fontFamily: 'var(--hand)', fontSize: 11, lineHeight: 1.4, whiteSpace: 'nowrap' }}>
      <SketchBox width="100%" height="100%" radius={999} stroke={s.fg} strokeWidth={1.1}
        style={{ position: 'absolute', inset: 0 }} />
      <span style={{ position: 'relative' }}>{children || s.label}</span>
    </span>
  );
}

// Small pencil/handwritten "mark" next to a number — used for monetary highlight.
function Money({ amount, currency = 'EUR', size = 13, weight = 500, color = INK, strike = false }) {
  return (
    <span style={{ fontFamily: 'var(--hand)', fontSize: size, fontWeight: weight, color, textDecoration: strike ? 'line-through' : 'none' }}>
      {amount}<span style={{ fontSize: size * 0.78, marginLeft: 2, opacity: 0.7 }}>{currency}</span>
    </span>
  );
}

// Window chrome — generic, NOT macOS specific. Three dots in a row, neutral.
function WindowChrome({ title = '', children, accent }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '8px 12px', borderBottom: `1px solid ${INK}33` }}>
      <span style={{ display: 'inline-flex', gap: 5 }}>
        <span style={dotStyle} /><span style={dotStyle} /><span style={dotStyle} />
      </span>
      <span style={{ fontFamily: 'var(--hand)', fontSize: 12, color: '#7a7468', flex: 1, textAlign: 'center' }}>{title}</span>
      {accent ? <span style={{ fontFamily: 'var(--mono)', fontSize: 10, color: accent, textTransform: 'uppercase' }}>{accent}</span> : <span style={{ width: 36 }} />}
      {children}
    </div>
  );
}
const dotStyle = { width: 9, height: 9, borderRadius: '50%', border: `1.2px solid ${INK}`, background: 'transparent' };

// Simple iPhone bezel (original, not Apple-branded shape — softer pillbox).
function PhoneFrame({ width = 300, height = 620, children, label }) {
  return (
    <div style={{ width, height, position: 'relative' }}>
      <div style={{
        position: 'absolute', inset: 0, borderRadius: 38, background: PAPER,
        boxShadow: 'inset 0 0 0 2px ' + INK, padding: 10,
      }}>
        <SketchBox width="100%" height="100%" radius={32} />
        <div style={{
          position: 'absolute', top: 18, left: 16, right: 16, bottom: 18,
          borderRadius: 28, overflow: 'hidden', background: PAPER,
          boxShadow: `inset 0 0 0 1px ${INK}55`,
        }}>
          {/* status bar */}
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '6px 16px 2px', fontFamily: 'var(--hand)', fontSize: 10, color: '#7a7468' }}>
            <span>9:41</span>
            <span style={{ width: 44, height: 6, borderRadius: 4, background: INK, opacity: 0.85 }} />
            <span>· · ·</span>
          </div>
          {children}
        </div>
      </div>
      {label ? <div style={{ position: 'absolute', bottom: -22, left: 0, right: 0, textAlign: 'center', fontFamily: 'var(--mono)', fontSize: 11, color: '#7a7468' }}>{label}</div> : null}
    </div>
  );
}

// Annotation — handwritten arrow + label, to call out a flow step on the storyboard.
function Annotation({ children, dir = 'down', style }) {
  return (
    <div style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontFamily: 'var(--hand)', fontSize: 13, color: ACCENT, ...style }}>
      <span>{children}</span>
      <span style={{ fontSize: 16 }}>{dir === 'down' ? '↓' : dir === 'right' ? '→' : dir === 'left' ? '←' : '↑'}</span>
    </div>
  );
}

// Numbered storyboard step badge.
function StepBadge({ n }) {
  return (
    <span style={{ position: 'relative', display: 'inline-flex', width: 26, height: 26, alignItems: 'center', justifyContent: 'center', fontFamily: 'var(--hand)', fontWeight: 700, fontSize: 13 }}>
      <SketchCircle size={26} stroke={ACCENT} strokeWidth={1.6} />
      <span style={{ position: 'absolute', color: ACCENT }}>{n}</span>
    </span>
  );
}

Object.assign(window, {
  ACCENT, ACCENT_OK, ACCENT_WARN, INK, PAPER, PAPER_2, RULE,
  SketchFilters, SketchBox, SketchFrame, SketchRule, SketchPlaceholder, SketchCircle,
  StatePill, Money, WindowChrome, PhoneFrame, Annotation, StepBadge,
});
