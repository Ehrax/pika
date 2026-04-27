// Pika hi-fi iPhone screens — D1, D2, D3, D4, D5, E1.
// Wraps everything in IOSDevice (from ios-frame.jsx) for proper bezel + status bar
// + dynamic island + home indicator. The IOSDevice itself is 402×874.

// Theme-aware screen surface that fills the IOSDevice's content area.
// IOSDevice already provides status bar (top) and home indicator (bottom),
// but its content slot is `flex:1; overflow:auto` and starts BELOW the status
// bar. The status bar overlays absolutely though — so we still need top
// padding to clear the dynamic island.
function PhoneCanvas({ children, theme }) {
  return (
    <div style={{
      minHeight: '100%',
      background: theme.surface,
      color: theme.textPrimary,
      fontFamily: HF_FONT_UI,
      paddingTop: 60,           // clear status bar + dynamic island
      paddingBottom: 40,        // home indicator
      display: 'flex', flexDirection: 'column',
    }}>
      {children}
    </div>
  );
}

// Large title row, iOS 17/26 style. Optional right action.
function PhoneLargeTitle({ children, theme, sub, right, back }) {
  return (
    <div style={{ padding: '8px 20px 12px', flex: '0 0 auto' }}>
      {back ? (
        <div style={{ display: 'flex', alignItems: 'center', gap: 4, color: theme.accent, fontSize: 15, marginBottom: 4 }}>
          <span style={{ fontSize: 20, lineHeight: '20px' }}>‹</span><span>{back}</span>
        </div>
      ) : null}
      <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', gap: 12 }}>
        <div>
          <div style={{ fontSize: 30, fontWeight: 700, letterSpacing: -0.6, lineHeight: 1.15 }}>{children}</div>
          {sub ? <div style={{ fontSize: 13, color: theme.textSecondary, marginTop: 4 }}>{sub}</div> : null}
        </div>
        {right ? <div style={{ flex: '0 0 auto', paddingBottom: 6 }}>{right}</div> : null}
      </div>
    </div>
  );
}

// Standard nav bar (centered title + back).
function PhoneNav({ title, back, theme, right }) {
  return (
    <div style={{
      padding: '4px 16px 10px',
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      flex: '0 0 auto',
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 4, color: theme.accent, fontSize: 15, minWidth: 80 }}>
        {back ? <><span style={{ fontSize: 20, lineHeight: '20px' }}>‹</span><span>{back}</span></> : null}
      </div>
      <div style={{ fontSize: 15, fontWeight: 600, letterSpacing: -0.2 }}>{title}</div>
      <div style={{ minWidth: 80, textAlign: 'right', color: theme.accent, fontSize: 15 }}>{right}</div>
    </div>
  );
}

// Floating "+" FAB.
function PhoneFAB({ theme, bottom = 100 }) {
  const fg = isDarkTheme(theme) ? '#0A0A0B' : '#FFFFFF';
  return (
    <div style={{
      position: 'absolute', right: 24, bottom,
      width: 56, height: 56, borderRadius: 28,
      background: theme.accent, color: fg,
      display: 'grid', placeItems: 'center',
      fontSize: 30, fontWeight: 300,
      boxShadow: `0 8px 24px ${theme.accent}55`,
      zIndex: 5,
    }}>+</div>
  );
}

// ── D1 · Projects ───────────────────────────────────────────────────────────
function HiFi_PhoneD1({ theme }) {
  const projects = [
    { name: 'bikepark-thunersee', dot: '#6B7BFF', meta: '4 buckets · 22 h', amt: '€1’760', state: 'ready' },
    { name: 'helvetia-tools', dot: '#7AC79A', meta: '2 buckets · 6 h', amt: '€480', state: 'overdue' },
    { name: 'ehrax-internal', dot: theme.textMuted, meta: '1 bucket · 3 h', amt: '€240', state: null },
  ];
  return (
    <PhoneCanvas theme={theme}>
      <PhoneLargeTitle theme={theme} right={<span style={{ color: theme.accent, fontSize: 15 }}>+ new</span>}>
        Projects
      </PhoneLargeTitle>
      <div style={{ padding: '0 20px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        {projects.map((p) => (
          <div key={p.name} style={{
            background: theme.surfaceAlt,
            border: `1px solid ${theme.border}`,
            borderRadius: 12,
            padding: '14px 16px',
            display: 'flex', alignItems: 'center', gap: 12,
          }}>
            <span style={{ width: 8, height: 8, borderRadius: 4, background: p.dot }} />
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 15, fontWeight: 500, marginBottom: 3 }}>{p.name}</div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <span style={{ fontFamily: HF_FONT_NUM, fontSize: 11, color: theme.textMuted }}>{p.meta}</span>
                {p.state ? <HFPill tone={p.state} theme={theme}>{p.state}</HFPill> : null}
              </div>
            </div>
            <div style={{ textAlign: 'right' }}>
              <HFNum theme={theme} size={15} weight={500}>{p.amt}</HFNum>
              <div style={{ color: theme.textMuted, fontSize: 16, marginTop: -2 }}>›</div>
            </div>
          </div>
        ))}
      </div>
    </PhoneCanvas>
  );
}

// ── D2 · Buckets list (inside one project) ──────────────────────────────────
function HiFi_PhoneD2({ theme }) {
  const buckets = [
    { name: 'MVP', meta: '12.5 h · €1’000', state: 'open' },
    { name: 'Maintenance', meta: '3.0 h · €240', state: 'open' },
    { name: 'Customer dashboard', meta: '6.5 h · €520', state: 'ready' },
    { name: 'Infra fixed costs', meta: '2 items · €84', state: 'open', kind: 'fixed' },
    { name: 'Q1 — invoiced', meta: 'EHX-2026-001', state: 'finalized' },
  ];
  return (
    <PhoneCanvas theme={theme}>
      <PhoneLargeTitle theme={theme} back="projects" sub="bikepark-thunersee · €80/h"
        right={<span style={{ color: theme.accent, fontSize: 15 }}>+ new</span>}>
        Buckets
      </PhoneLargeTitle>
      <div style={{ padding: '0 20px', display: 'flex', flexDirection: 'column', gap: 8 }}>
        {buckets.map((b) => (
          <div key={b.name} style={{
            background: theme.surfaceAlt,
            border: `1px solid ${theme.border}`,
            borderRadius: 10,
            padding: '13px 14px',
            display: 'flex', alignItems: 'center', gap: 10,
          }}>
            <span style={{ color: theme.textMuted, fontSize: 13, width: 14 }}>{b.kind === 'fixed' ? '⊞' : '◇'}</span>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 14, fontWeight: 500, marginBottom: 2 }}>{b.name}</div>
              <div style={{ fontFamily: HF_FONT_NUM, fontSize: 11, color: theme.textMuted }}>{b.meta}</div>
            </div>
            {b.state === 'ready' ? <HFPill tone="ready" theme={theme}>ready</HFPill> :
             b.state === 'finalized' ? <HFPill tone="finalized" theme={theme}>finalized</HFPill> : null}
            <span style={{ color: theme.textMuted, fontSize: 16 }}>›</span>
          </div>
        ))}
      </div>
    </PhoneCanvas>
  );
}

// ── D3 · Bucket detail ──────────────────────────────────────────────────────
function HiFi_PhoneD3({ theme }) {
  const days = [
    { date: 'Apr 26 · today', items: [
      { range: '14:30–15:00', dur: '0.5 h', desc: 'standup', nb: true },
    ]},
    { date: 'Apr 24', items: [
      { range: '14:00–16:30', dur: '2.5 h', desc: 'map tiles + clustering', amt: '€200' },
      { range: '10:00–12:00', dur: '2.0 h', desc: 'review w/ Adi', amt: '€160' },
    ]},
    { date: 'Apr 23', items: [
      { range: '13:30–17:00', dur: '3.5 h', desc: 'routes endpoint', amt: '€280' },
      { range: '09:00–12:30', dur: '3.5 h', desc: 'auth + token rotation', amt: '€280' },
    ]},
  ];
  return (
    <PhoneCanvas theme={theme}>
      <PhoneNav theme={theme} title="MVP" back="buckets" right="···" />
      <div style={{ padding: '4px 20px 16px', flex: '0 0 auto' }}>
        <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
          <div>
            <HFNum theme={theme} size={32} weight={700}>€920</HFNum>
            <div style={{ fontSize: 12, color: theme.textMuted, marginTop: 2, fontFamily: HF_FONT_NUM }}>11.5 h · 0.5 h n/b · €80/h</div>
          </div>
          <HFButton size="sm" theme={theme}>mark ready</HFButton>
        </div>
      </div>
      <div style={{ flex: 1, overflow: 'auto' }}>
        {days.map((d) => (
          <div key={d.date}>
            <div style={{
              padding: '10px 20px 6px',
              fontSize: 11, fontWeight: 500, letterSpacing: 0.4, textTransform: 'uppercase',
              color: theme.textMuted,
            }}>{d.date}</div>
            {d.items.map((e, i) => (
              <div key={i} style={{
                display: 'grid', gridTemplateColumns: '92px 1fr 60px',
                gap: 12, padding: '14px 20px',
                borderBottom: `1px solid ${theme.border}`,
                alignItems: 'center',
                color: e.nb ? theme.textMuted : theme.textPrimary,
              }}>
                <span style={{ fontFamily: HF_FONT_NUM, fontSize: 12, color: theme.textSecondary }}>{e.range}</span>
                <div>
                  <div style={{ fontSize: 14 }}>{e.desc}</div>
                  <div style={{ fontFamily: HF_FONT_NUM, fontSize: 11, color: theme.textMuted, marginTop: 2 }}>{e.dur}</div>
                </div>
                <span style={{ textAlign: 'right' }}>
                  {e.nb
                    ? <span style={{ fontFamily: HF_FONT_NUM, fontSize: 11, color: theme.textMuted }}>n/b</span>
                    : <HFNum theme={theme} size={13} weight={500}>{e.amt}</HFNum>}
                </span>
              </div>
            ))}
          </div>
        ))}
      </div>
      <PhoneFAB theme={theme} />
    </PhoneCanvas>
  );
}

// ── D4 · Add sheet (modal over backdrop) ────────────────────────────────────
function HiFi_PhoneD4({ theme }) {
  return (
    <div style={{
      position: 'relative',
      minHeight: '100%',
      background: theme.surface,
      color: theme.textPrimary,
      fontFamily: HF_FONT_UI,
      paddingTop: 60,
      display: 'flex', flexDirection: 'column',
    }}>
      {/* Faded D3 backdrop (no PhoneCanvas wrapper — would double-pad) */}
      <div style={{ opacity: 0.35, pointerEvents: 'none', flex: '0 0 auto' }}>
        <PhoneNav theme={theme} title="MVP" back="buckets" right="···" />
        <div style={{ padding: '4px 20px 16px' }}>
          <HFNum theme={theme} size={32} weight={700}>€920</HFNum>
          <div style={{ fontSize: 12, color: theme.textMuted, marginTop: 2, fontFamily: HF_FONT_NUM }}>11.5 h · €80/h</div>
        </div>
      </div>
      {/* Sheet — anchored to bottom of the device content area */}
      <div style={{
        position: 'absolute', left: 0, right: 0, top: 180, bottom: 0,
        background: theme.surfaceAlt,
        borderTopLeftRadius: 16, borderTopRightRadius: 16,
        padding: '12px 20px 50px',
        boxShadow: '0 -12px 40px #0008',
        display: 'flex', flexDirection: 'column',
      }}>
        <div style={{ width: 36, height: 4, borderRadius: 2, background: theme.borderStrong, margin: '0 auto 18px', flex: '0 0 auto' }} />
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 22, flex: '0 0 auto' }}>
          <span style={{ color: theme.textSecondary, fontSize: 15 }}>cancel</span>
          <span style={{ fontSize: 17, fontWeight: 600 }}>New entry</span>
          <span style={{ color: theme.accent, fontSize: 15, fontWeight: 500 }}>save</span>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 14, flex: '0 0 auto' }}>
          <HFField theme={theme} label="When" value="Today · Apr 26" prefix="◇" />
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
            <HFField theme={theme} label="From" value="10:00" focus monospace size="lg" />
            <HFField theme={theme} label="To" value="12:00" monospace size="lg" />
          </div>
          <div style={{
            padding: '12px 14px', borderRadius: 8,
            background: theme.accentMuted,
            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          }}>
            <span style={{ fontSize: 12, color: theme.accent, fontWeight: 500 }}>2.00 h × €80</span>
            <HFNum theme={theme} size={18} weight={600} color={theme.accent}>€160.00</HFNum>
          </div>
          <HFField theme={theme} label="Description" placeholder="what did you work on?" value="auth + token rotation" />
          <div style={{ display: 'flex', gap: 8, marginTop: 4 }}>
            <HFButton size="sm" theme={theme} ghost>+ link to invoice</HFButton>
            <span style={{ flex: 1 }} />
            <HFButton size="sm" theme={theme}>n/b</HFButton>
          </div>
        </div>
        <div style={{
          marginTop: 'auto', paddingTop: 16,
          fontSize: 11, color: theme.textMuted,
          display: 'flex', justifyContent: 'space-between', fontFamily: HF_FONT_NUM,
        }}>
          <span>tip · type 10–12 or 2h</span>
          <span>↵ save</span>
        </div>
      </div>
    </div>
  );
}

// ── D5 · Ready to invoice ───────────────────────────────────────────────────
function HiFi_PhoneD5({ theme }) {
  return (
    <PhoneCanvas theme={theme}>
      <PhoneNav theme={theme} title="MVP" back="buckets" right="···" />
      <div style={{ padding: '8px 20px 24px', flex: 1, overflow: 'auto' }}>
        <div style={{
          padding: '20px 20px 18px',
          borderRadius: 12,
          background: theme.successMuted,
          border: `1px solid ${theme.success}33`,
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 12 }}>
            <HFPill tone="ready" theme={theme}>ready</HFPill>
            <span style={{ flex: 1 }} />
            <span style={{ fontFamily: HF_FONT_NUM, fontSize: 11, color: theme.textMuted }}>11.5 h + €50 fixed</span>
          </div>
          <HFNum theme={theme} size={36} weight={700} color={theme.success}>€970.20</HFNum>
          <div style={{ marginTop: 16, display: 'flex', gap: 8 }}>
            <HFButton theme={theme} size="sm">edit</HFButton>
            <span style={{ flex: 1 }} />
            <HFButton theme={theme} size="sm" primary>create invoice →</HFButton>
          </div>
        </div>

        <div style={{
          padding: '20px 4px 8px',
          fontSize: 11, fontWeight: 500, letterSpacing: 0.4, textTransform: 'uppercase',
          color: theme.textMuted,
          display: 'flex', justifyContent: 'space-between',
        }}>
          <span>entries · still editable</span>
          <span style={{ fontFamily: HF_FONT_NUM }}>5</span>
        </div>

        <div style={{
          background: theme.surfaceAlt, borderRadius: 10,
          border: `1px solid ${theme.border}`,
          overflow: 'hidden',
        }}>
          {[
            ['10:00–12:00', '2.00 h', '€160'],
            ['14:30–15:00', '0.50 h', 'n/b'],
            ['14:00–16:30', '2.50 h', '€200'],
            ['09:00–12:30', '3.50 h', '€280'],
            ['13:30–17:00', '3.50 h', '€280'],
          ].map((r, i, a) => (
            <div key={i} style={{
              display: 'grid', gridTemplateColumns: '92px 1fr 60px',
              gap: 10, padding: '12px 14px', alignItems: 'center',
              borderBottom: i < a.length - 1 ? `1px solid ${theme.border}` : 'none',
              color: r[2] === 'n/b' ? theme.textMuted : theme.textPrimary,
            }}>
              <span style={{ fontFamily: HF_FONT_NUM, fontSize: 12, color: theme.textSecondary }}>{r[0]}</span>
              <span style={{ fontFamily: HF_FONT_NUM, fontSize: 12 }}>{r[1]}</span>
              <span style={{ textAlign: 'right' }}>
                {r[2] === 'n/b'
                  ? <span style={{ fontFamily: HF_FONT_NUM, fontSize: 11, color: theme.textMuted }}>n/b</span>
                  : <HFNum theme={theme} size={13} weight={500}>{r[2]}</HFNum>}
              </span>
            </div>
          ))}
        </div>
      </div>
    </PhoneCanvas>
  );
}

// ── E1 · Today (dashboard-first phone) ──────────────────────────────────────
function HiFi_PhoneE1({ theme }) {
  return (
    <PhoneCanvas theme={theme}>
      <PhoneLargeTitle theme={theme} sub="Sunday, April 26"
        right={<span style={{ color: theme.accent, fontSize: 22 }}>+</span>}>
        Today
      </PhoneLargeTitle>

      <div style={{ padding: '0 20px', display: 'flex', flexDirection: 'column', gap: 14, flex: 1, overflow: 'auto', paddingBottom: 20 }}>
        {/* Hero KPI — outstanding */}
        <div style={{
          background: theme.surfaceAlt, borderRadius: 14,
          border: `1px solid ${theme.border}`,
          padding: 18,
        }}>
          <div style={{ fontSize: 11, color: theme.textMuted, fontWeight: 500, letterSpacing: 0.4, textTransform: 'uppercase' }}>Outstanding</div>
          <HFNum theme={theme} size={34} weight={700}>€2’080</HFNum>
          <div style={{ fontSize: 12, color: theme.textMuted, marginTop: 4 }}>
            <span style={{ color: theme.danger }}>€480 overdue</span> · 2 invoices
          </div>
        </div>

        {/* KPI strip */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
          <div style={{ background: theme.surfaceAlt, borderRadius: 12, border: `1px solid ${theme.border}`, padding: 14 }}>
            <div style={{ fontSize: 10, color: theme.textMuted, textTransform: 'uppercase', letterSpacing: 0.4, fontWeight: 500 }}>Ready</div>
            <HFNum theme={theme} size={20} weight={600} color={theme.accent}>€1’450</HFNum>
            <div style={{ fontSize: 11, color: theme.textMuted, fontFamily: HF_FONT_NUM }}>2 buckets</div>
          </div>
          <div style={{ background: theme.surfaceAlt, borderRadius: 12, border: `1px solid ${theme.border}`, padding: 14 }}>
            <div style={{ fontSize: 10, color: theme.textMuted, textTransform: 'uppercase', letterSpacing: 0.4, fontWeight: 500 }}>Month</div>
            <HFNum theme={theme} size={20} weight={600}>€3’240</HFNum>
            <div style={{ fontSize: 11, color: theme.success, fontFamily: HF_FONT_NUM }}>+€620</div>
          </div>
        </div>

        {/* Needs attention */}
        <div>
          <div style={{
            padding: '8px 4px',
            fontSize: 11, fontWeight: 500, letterSpacing: 0.4, textTransform: 'uppercase',
            color: theme.textMuted,
            display: 'flex', justifyContent: 'space-between',
          }}>
            <span>Needs attention</span>
            <span style={{ fontFamily: HF_FONT_NUM }}>3</span>
          </div>
          <div style={{ background: theme.surfaceAlt, borderRadius: 12, border: `1px solid ${theme.border}`, overflow: 'hidden' }}>
            {[
              { tone: 'overdue', primary: 'EHX-2026-002', meta: 'helvetia · +6 d', amt: '€480' },
              { tone: 'ready',   primary: 'MVP',          meta: 'bikepark · 11.5 h', amt: '€970' },
              { tone: 'ready',   primary: 'Q1',           meta: 'helvetia · 6.0 h',  amt: '€480' },
            ].map((r, i, a) => (
              <div key={i} style={{
                display: 'flex', alignItems: 'center', gap: 10,
                padding: '13px 14px',
                borderBottom: i < a.length - 1 ? `1px solid ${theme.border}` : 'none',
              }}>
                <HFPill tone={r.tone} theme={theme}>{r.tone}</HFPill>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 14, fontWeight: 500 }}>{r.primary}</div>
                  <div style={{ fontFamily: HF_FONT_NUM, fontSize: 11, color: theme.textMuted, marginTop: 1 }}>{r.meta}</div>
                </div>
                <HFNum theme={theme} size={13} weight={500}>{r.amt}</HFNum>
                <span style={{ color: theme.textMuted, fontSize: 16 }}>›</span>
              </div>
            ))}
          </div>
        </div>

        {/* Quick log */}
        <div>
          <div style={{
            padding: '8px 4px',
            fontSize: 11, fontWeight: 500, letterSpacing: 0.4, textTransform: 'uppercase',
            color: theme.textMuted,
          }}>Quick log</div>
          <div style={{
            background: theme.surfaceAlt, borderRadius: 12, border: `1px solid ${theme.border}`,
            padding: 14,
            display: 'flex', flexDirection: 'column', gap: 10,
          }}>
            <HFField theme={theme} value="bikepark · MVP" prefix="◇" />
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8 }}>
              <HFField theme={theme} value="10:00" monospace />
              <HFField theme={theme} value="12:00" monospace />
              <HFButton theme={theme} primary>save</HFButton>
            </div>
          </div>
        </div>
      </div>
    </PhoneCanvas>
  );
}

Object.assign(window, {
  PhoneCanvas,
  HiFi_PhoneD1, HiFi_PhoneD2, HiFi_PhoneD3, HiFi_PhoneD4, HiFi_PhoneD5,
  HiFi_PhoneE1,
});
