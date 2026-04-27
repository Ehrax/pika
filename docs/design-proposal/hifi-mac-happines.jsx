// Pika hi-fi Mac screens — A2, A3, B1, B3, B4.
// All accept a `theme` prop so they render in dark or light identically.

// Shared: app shell wraps sidebar + main column.
// Customizes HFSidebar with happ.ines_creations brand + commission list.
const HAPPINES_PROJECTS = [
  { name: 'mariage-lea-tom', dot: '#C9846A' },
  { name: 'boutique-la-trame', dot: '#A3C49A', activeId: 'la-trame' },
  { name: 'marche-noel-2026', dot: '#E8C875' },
];
function MacShell({ children, theme, active = 'projects' }) {
  return (
    <div style={{ display: 'flex', width: '100%', height: '100%', minHeight: 0 }}>
      <HFSidebar
        theme={theme}
        active={active}
        brand="happ.ines_creations"
        brandInitial="h"
        projects={HAPPINES_PROJECTS}
      />
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', minWidth: 0, background: theme.surface }}>
        {children}
      </div>
    </div>
  );
}

// Bucket list column — middle pane in 3-pane layouts.
function BucketList({ theme, selected = 'centerpieces' }) {
  const buckets = [
    { id: 'centerpieces', name: 'Centerpieces', meta: '12 pcs · €420', state: 'open' },
    { id: 'maint', name: 'Wedding favors', meta: '8 pcs · €105', state: 'open' },
    { id: 'dash', name: 'Bridal bouquet', meta: '24 pcs · €1260', state: 'open' },
    { id: 'fixed', name: 'Materials & shipping', meta: '6 items · €126', state: 'open', kind: 'fixed' },
    { id: 'q1', name: 'Engagement set — invoiced', meta: 'HIN-2026-001', state: 'finalized' },
  ];
  return (
    <div style={{
      width: 260, flex: '0 0 auto',
      borderRight: `1px solid ${theme.border}`,
      background: theme.surface,
      display: 'flex', flexDirection: 'column', minHeight: 0,
    }}>
      <div style={{ padding: '14px 16px 10px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <span style={{ fontSize: 11, fontWeight: 500, letterSpacing: 0.4, textTransform: 'uppercase', color: theme.textMuted }}>
          Buckets · lea-tom
        </span>
        <HFButton size="sm" ghost theme={theme} icon="+">new</HFButton>
      </div>
      <div style={{ padding: '0 8px', display: 'flex', flexDirection: 'column', gap: 1, overflow: 'auto' }}>
        {buckets.map((b) => (
          <BucketRow key={b.id} {...b} active={selected === b.id} theme={theme} />
        ))}
      </div>
    </div>
  );
}

function BucketRow({ name, meta, state, kind, active, theme }) {
  const icon = kind === 'fixed' ? '⊞' : '◇';
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 10,
      padding: '10px 12px',
      borderRadius: 6,
      background: active ? theme.surfaceAlt : 'transparent',
      cursor: 'default',
      borderLeft: active ? `2px solid ${theme.accent}` : '2px solid transparent',
      paddingLeft: active ? 10 : 12,
    }}>
      <span style={{ color: theme.textMuted, fontSize: 12, width: 12 }}>{icon}</span>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 13, fontWeight: active ? 500 : 400, color: theme.textPrimary, marginBottom: 2 }}>
          {name}
        </div>
        <div style={{ fontFamily: HF_FONT_NUM, fontSize: 11, color: theme.textMuted, fontVariantNumeric: 'tabular-nums' }}>
          {meta}
        </div>
      </div>
      {state === 'finalized' ? <HFPill tone="finalized" theme={theme}>finalized</HFPill> : null}
    </div>
  );
}

// ── A1 · Projects landing (entry point — choose a project) ─────────────────
function HiFi_MacA1({ theme }) {
  const projects = [
    {
      name: 'mariage-lea-tom',
      dot: '#6B7BFF',
      meta: '4 buckets · started Mar 18 · 38 pcs',
      total: '€1’190',
      counts: { open: 2, ready: 1, finalized: 1 },
      attention: { tone: 'ready', text: 'Centerpieces ready · €505' },
    },
    {
      name: 'boutique-la-trame',
      dot: '#7AC79A',
      meta: '2 buckets · started Feb 02 · 14 pcs',
      total: '€590',
      counts: { open: 1, ready: 0, finalized: 1 },
      attention: { tone: 'overdue', text: 'HIN-002 overdue +6 d' },
    },
    {
      name: 'marche-noel-2026',
      dot: theme.textMuted,
      meta: '1 bucket · started Jan 04 · stall sales',
      total: '€280',
      counts: { open: 1, ready: 0, finalized: 0 },
      attention: null,
    },
  ];
  return (
    <HFWindow theme={theme}>
      <MacShell theme={theme} active="projects">
        <HFTopBar theme={theme} right={
          <>
            <HFButton size="sm" theme={theme} icon="⌘K">search</HFButton>
            <HFButton size="sm" primary theme={theme} icon="+">new project</HFButton>
          </>
        }>
          <span style={{ fontSize: 13, fontWeight: 500 }}>Projects</span>
        </HFTopBar>
        <div style={{ flex: 1, padding: '24px 32px', overflow: 'auto', display: 'flex', flexDirection: 'column', gap: 20 }}>
          <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between' }}>
            <div>
              <div style={{ fontSize: 24, fontWeight: 600, letterSpacing: -0.4 }}>3 active projects</div>
              <div style={{ color: theme.textSecondary, fontSize: 13, marginTop: 4 }}>
                <HFNum theme={theme} size={13}>€2’450</HFNum> open · <HFNum theme={theme} size={13} color={theme.success}>€1’090</HFNum> ready · <HFNum theme={theme} size={13} color={theme.danger}>€590</HFNum> overdue
              </div>
            </div>
            <div style={{ display: 'flex', gap: 8 }}>
              <HFButton size="sm" theme={theme}>active</HFButton>
              <HFButton size="sm" ghost theme={theme}>archived</HFButton>
            </div>
          </div>

          {/* Projects grid — pick one to drill into its buckets */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 16 }}>
            {projects.map((p) => (
              <div key={p.name} style={{
                background: theme.surface,
                border: `1px solid ${theme.border}`,
                borderRadius: 10,
                padding: 18,
                display: 'flex', flexDirection: 'column', gap: 14,
                cursor: 'default',
                position: 'relative',
              }}>
                <div style={{ display: 'flex', alignItems: 'flex-start', gap: 10 }}>
                  <span style={{ width: 8, height: 8, borderRadius: 4, background: p.dot, marginTop: 7 }} />
                  <div style={{ flex: 1 }}>
                    <div style={{ fontSize: 15, fontWeight: 600, letterSpacing: -0.2 }}>{p.name}</div>
                    <div style={{ fontSize: 11, color: theme.textMuted, marginTop: 3, fontFamily: HF_FONT_NUM }}>{p.meta}</div>
                  </div>
                  <span style={{ color: theme.textMuted, fontSize: 14 }}>›</span>
                </div>
                <div>
                  <HFNum theme={theme} size={26} weight={600}>{p.total}</HFNum>
                  <div style={{ fontSize: 11, color: theme.textMuted, marginTop: 2, fontFamily: HF_FONT_NUM }}>total billed + open</div>
                </div>
                {/* Bucket counts strip */}
                <div style={{
                  display: 'flex', gap: 6,
                  paddingTop: 12,
                  borderTop: `1px solid ${theme.border}`,
                }}>
                  <BucketCount theme={theme} n={p.counts.open} label="open" />
                  <BucketCount theme={theme} n={p.counts.ready} label="ready" tone={theme.success} />
                  <BucketCount theme={theme} n={p.counts.finalized} label="invoiced" tone={theme.warning} />
                </div>
                {/* Attention banner */}
                {p.attention ? (
                  <div style={{
                    display: 'flex', alignItems: 'center', gap: 8,
                    padding: '8px 10px',
                    background: p.attention.tone === 'ready' ? theme.successMuted : theme.dangerMuted,
                    borderRadius: 6,
                    fontSize: 12,
                    color: p.attention.tone === 'ready' ? theme.success : theme.danger,
                  }}>
                    <HFPill tone={p.attention.tone} theme={theme}>{p.attention.tone}</HFPill>
                    <span style={{ flex: 1, color: theme.textPrimary }}>{p.attention.text}</span>
                  </div>
                ) : null}
              </div>
            ))}
            {/* + new project tile */}
            <div style={{
              border: `1.5px dashed ${theme.border}`,
              borderRadius: 10,
              minHeight: 260,
              display: 'grid', placeItems: 'center',
              color: theme.textMuted, fontSize: 13,
            }}>
              <div style={{ textAlign: 'center' }}>
                <div style={{ fontSize: 28, color: theme.textMuted, marginBottom: 4 }}>+</div>
                new project
              </div>
            </div>
          </div>

          {/* Recent activity strip */}
          <div>
            <HFSectionLabel theme={theme}>Recent activity</HFSectionLabel>
            <HFCard theme={theme} padding={0}>
              {[
                ['Today 14:30', 'lea-tom · MVP', 'studio cleanup logged'],
                ['Today 12:00', 'lea-tom · MVP', 'photo session · 2 hr block'],
                ['Yesterday',   'la-trame · Spring drop', 'invoice HIN-2026-001 marked paid'],
              ].map((r, i, a) => (
                <div key={i} style={{
                  display: 'grid', gridTemplateColumns: '120px 220px 1fr',
                  gap: 16, padding: '11px 16px',
                  borderBottom: i < a.length - 1 ? `1px solid ${theme.border}` : 'none',
                  fontSize: 12,
                }}>
                  <span style={{ color: theme.textMuted, fontFamily: HF_FONT_NUM }}>{r[0]}</span>
                  <span style={{ color: theme.textSecondary }}>{r[1]}</span>
                  <span style={{ color: theme.textPrimary }}>{r[2]}</span>
                </div>
              ))}
            </HFCard>
          </div>
        </div>
      </MacShell>
    </HFWindow>
  );
}

function BucketCount({ n, label, tone, theme }) {
  return (
    <div style={{
      flex: 1,
      padding: '6px 8px',
      background: theme.surfaceAlt,
      borderRadius: 5,
      textAlign: 'center',
    }}>
      <HFNum theme={theme} size={14} weight={600} color={tone || theme.textPrimary}>{n}</HFNum>
      <div style={{ fontSize: 10, color: theme.textMuted, textTransform: 'uppercase', letterSpacing: 0.4, fontWeight: 500, marginTop: 1 }}>{label}</div>
    </div>
  );
}

// ── A2 · Bucket detail (filled) ─────────────────────────────────────────────
function HiFi_MacA2({ theme }) {
  const entries = [
    { date: 'Apr 23', range: '09:00–12:30', dur: 3.5, desc: 'porcelain vase · 3 pcs · ivory glaze' },
    { date: 'Apr 23', range: '13:30–17:00', dur: 3.5, desc: 'routes · bookings list endpoint' },
    { date: 'Apr 24', range: '10:00–12:00', dur: 2.0, desc: 'review session w/ Adi' },
    { date: 'Apr 24', range: '14:00–16:30', dur: 2.5, desc: 'centerpiece · arrangement #4' },
    { date: 'Apr 26', range: '14:30–15:00', dur: 0.5, desc: 'standup · n/b', nb: true },
  ];
  const billable = entries.filter((e) => !e.nb);
  const totalH = billable.reduce((s, e) => s + e.dur, 0);
  const total = totalH * 80;
  return (
    <HFWindow theme={theme}>
      <MacShell theme={theme} active="projects">
        <HFTopBar theme={theme} right={
          <>
            <HFButton size="sm" theme={theme} icon="⌘K">search</HFButton>
            <HFButton size="sm" primary theme={theme}>mark ready</HFButton>
          </>
        }>
          <span style={{ color: theme.textMuted, fontSize: 13 }}>mariage-lea-tom</span>
          <span style={{ color: theme.textMuted }}>/</span>
          <span style={{ fontSize: 13, fontWeight: 500 }}>Centerpieces</span>
        </HFTopBar>
        <div style={{ display: 'flex', flex: 1, minHeight: 0 }}>
          <BucketList theme={theme} />
          <div style={{ flex: 1, padding: '24px 32px', overflow: 'auto', display: 'flex', flexDirection: 'column', gap: 20 }}>
            {/* Bucket header card */}
            <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 24 }}>
              <div>
                <div style={{ fontSize: 24, fontWeight: 600, letterSpacing: -0.4, marginBottom: 6 }}>Centerpieces</div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 12, color: theme.textSecondary, fontSize: 13 }}>
                  <span>mariage-lea-tom</span>
                  <span style={{ width: 3, height: 3, borderRadius: 2, background: theme.textMuted }} />
                  <span>started Mar 18</span>
                  <span style={{ width: 3, height: 3, borderRadius: 2, background: theme.textMuted }} />
                  <span>rate <HFNum theme={theme} size={13}>€35/pc</HFNum></span>
                </div>
              </div>
              <div style={{ textAlign: 'right' }}>
                <HFNum theme={theme} size={28} weight={600}>€{total.toFixed(0)}</HFNum>
                <div style={{ fontSize: 11, color: theme.textMuted, marginTop: 2, fontFamily: HF_FONT_NUM }}>
                  {totalH.toFixed(1)} h billable · 0.5 h n/b
                </div>
              </div>
            </div>

            {/* Entries */}
            <div>
              <HFSectionLabel theme={theme} action={
                <span style={{ display: 'flex', gap: 4, color: theme.textMuted, fontSize: 11 }}>
                  <span style={{ padding: '2px 6px', background: theme.surfaceAlt, borderRadius: 3, fontFamily: HF_FONT_NUM }}>+</span>
                  to add
                </span>
              }>Entries · {entries.length}</HFSectionLabel>
              <HFCard theme={theme} padding={0}>
                <div style={{
                  display: 'grid', gridTemplateColumns: '64px 110px 1fr 60px 80px',
                  gap: 16, padding: '10px 16px',
                  fontSize: 10, fontWeight: 500, letterSpacing: 0.5, textTransform: 'uppercase',
                  color: theme.textMuted, borderBottom: `1px solid ${theme.border}`,
                }}>
                  <span>Date</span><span>Time</span><span>Description</span><span style={{ textAlign: 'right' }}>Hrs</span><span style={{ textAlign: 'right' }}>Amount</span>
                </div>
                {entries.map((e, i) => (
                  <div key={i} style={{
                    display: 'grid', gridTemplateColumns: '64px 110px 1fr 60px 80px',
                    gap: 16, padding: '12px 16px',
                    alignItems: 'center',
                    borderBottom: i < entries.length - 1 ? `1px solid ${theme.border}` : 'none',
                    color: e.nb ? theme.textMuted : theme.textPrimary,
                  }}>
                    <span style={{ fontFamily: HF_FONT_NUM, fontSize: 12, color: theme.textSecondary }}>{e.date}</span>
                    <span style={{ fontFamily: HF_FONT_NUM, fontSize: 12 }}>{e.range}</span>
                    <span style={{ fontSize: 13 }}>{e.desc}</span>
                    <HFNum theme={theme} size={12}>{e.dur.toFixed(2)}</HFNum>
                    <span style={{ textAlign: 'right' }}>
                      {e.nb
                        ? <span style={{ fontFamily: HF_FONT_NUM, fontSize: 11, color: theme.textMuted }}>n/b</span>
                        : <HFNum theme={theme} size={13} weight={500}>€{(e.dur * 80).toFixed(0)}</HFNum>}
                    </span>
                  </div>
                ))}
              </HFCard>
            </div>
          </div>
        </div>
      </MacShell>
    </HFWindow>
  );
}

// ── A3 · Inline add (cursor-active, draft row) ──────────────────────────────
function HiFi_MacA3({ theme }) {
  return (
    <HFWindow theme={theme}>
      <MacShell theme={theme} active="projects">
        <HFTopBar theme={theme} right={
          <>
            <HFButton size="sm" theme={theme} icon="⌘K">search</HFButton>
            <HFButton size="sm" theme={theme} disabled>mark ready</HFButton>
          </>
        }>
          <span style={{ color: theme.textMuted, fontSize: 13 }}>mariage-lea-tom</span>
          <span style={{ color: theme.textMuted }}>/</span>
          <span style={{ fontSize: 13, fontWeight: 500 }}>Centerpieces</span>
        </HFTopBar>
        <div style={{ display: 'flex', flex: 1, minHeight: 0 }}>
          <BucketList theme={theme} />
          <div style={{ flex: 1, padding: '24px 32px', overflow: 'hidden', display: 'flex', flexDirection: 'column', gap: 20 }}>
            <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 24 }}>
              <div>
                <div style={{ fontSize: 24, fontWeight: 600, letterSpacing: -0.4, marginBottom: 6 }}>Centerpieces</div>
                <div style={{ color: theme.textSecondary, fontSize: 13 }}>mariage-lea-tom · rate <HFNum theme={theme} size={13}>€35/pc</HFNum></div>
              </div>
              <div style={{ textAlign: 'right' }}>
                <HFNum theme={theme} size={28} weight={600}>€420</HFNum>
                <div style={{ fontSize: 11, color: theme.textMuted, marginTop: 2, fontFamily: HF_FONT_NUM }}>11 pcs · adding…</div>
              </div>
            </div>

            <div>
              <HFSectionLabel theme={theme}>Entries · 4 + 1 draft</HFSectionLabel>
              <HFCard theme={theme} padding={0}>
                {/* Header */}
                <div style={{
                  display: 'grid', gridTemplateColumns: '64px 110px 1fr 60px 80px',
                  gap: 16, padding: '10px 16px',
                  fontSize: 10, fontWeight: 500, letterSpacing: 0.5, textTransform: 'uppercase',
                  color: theme.textMuted, borderBottom: `1px solid ${theme.border}`,
                }}>
                  <span>Date</span><span>Time</span><span>Description</span><span style={{ textAlign: 'right' }}>Hrs</span><span style={{ textAlign: 'right' }}>Amount</span>
                </div>
                {/* Existing entries (compact) */}
                {[
                  ['Apr 23', '09:00–12:30', 'porcelain vase · 3 pcs · ivory glaze', 3.5],
                  ['Apr 23', '13:30–17:00', 'routes · bookings list endpoint', 3.5],
                  ['Apr 24', '14:00–16:30', 'centerpiece · arrangement #4', 2.5],
                ].map((e, i) => (
                  <div key={i} style={{
                    display: 'grid', gridTemplateColumns: '64px 110px 1fr 60px 80px',
                    gap: 16, padding: '12px 16px', alignItems: 'center',
                    borderBottom: `1px solid ${theme.border}`,
                  }}>
                    <span style={{ fontFamily: HF_FONT_NUM, fontSize: 12, color: theme.textSecondary }}>{e[0]}</span>
                    <span style={{ fontFamily: HF_FONT_NUM, fontSize: 12 }}>{e[1]}</span>
                    <span style={{ fontSize: 13 }}>{e[2]}</span>
                    <HFNum theme={theme} size={12}>{e[3].toFixed(2)}</HFNum>
                    <HFNum theme={theme} size={13} weight={500} style={{ textAlign: 'right' }}>€{e[3] * 80}</HFNum>
                  </div>
                ))}
                {/* Active draft row — focused, with caret in time field */}
                <div style={{
                  display: 'grid', gridTemplateColumns: '64px 110px 1fr 60px 80px',
                  gap: 16, padding: '10px 12px',
                  alignItems: 'center',
                  background: theme.accentMuted,
                  borderTop: `1px solid ${theme.accent}`,
                  borderBottom: `1px solid ${theme.accent}`,
                  position: 'relative',
                }}>
                  <span style={{ fontFamily: HF_FONT_NUM, fontSize: 12, color: theme.textPrimary }}>Apr 26</span>
                  {/* Focused field with caret */}
                  <div style={{
                    height: 28, padding: '0 8px',
                    background: theme.surface,
                    border: `1px solid ${theme.accent}`,
                    borderRadius: 5,
                    display: 'flex', alignItems: 'center', gap: 0,
                    boxShadow: `0 0 0 3px ${theme.accentMuted}`,
                  }}>
                    <span style={{ fontFamily: HF_FONT_NUM, fontSize: 12 }}>10:00–12:00</span>
                    <span style={{
                      width: 1.5, height: 14, background: theme.accent,
                      animation: 'hf-blink 1s steps(2) infinite',
                      marginLeft: 1,
                    }} />
                  </div>
                  <input placeholder="what did you work on?" style={{
                    background: theme.surface, color: theme.textPrimary,
                    border: `1px solid ${theme.border}`, borderRadius: 5,
                    padding: '6px 8px', fontFamily: HF_FONT_UI, fontSize: 13,
                    outline: 'none',
                  }} />
                  <HFNum theme={theme} size={12} color={theme.textMuted}>2.00</HFNum>
                  <HFNum theme={theme} size={13} weight={500} color={theme.textMuted}>€70</HFNum>
                </div>
                {/* Helper line below draft */}
                <div style={{
                  padding: '8px 16px',
                  background: theme.surfaceAlt,
                  display: 'flex', alignItems: 'center', gap: 16,
                  fontSize: 11, color: theme.textMuted,
                }}>
                  <span style={{ fontFamily: HF_FONT_NUM }}>tab</span>
                  <span>next field</span>
                  <span style={{ width: 1, height: 10, background: theme.border }} />
                  <span style={{ fontFamily: HF_FONT_NUM }}>↵</span>
                  <span>save · add another</span>
                  <span style={{ width: 1, height: 10, background: theme.border }} />
                  <span style={{ fontFamily: HF_FONT_NUM }}>esc</span>
                  <span>cancel</span>
                  <span style={{ flex: 1 }} />
                  <span style={{ color: theme.textSecondary }}>type ranges like <code style={{ fontFamily: HF_FONT_NUM, color: theme.textPrimary, padding: '1px 5px', background: theme.surface, borderRadius: 3 }}>10–12</code> or <code style={{ fontFamily: HF_FONT_NUM, color: theme.textPrimary, padding: '1px 5px', background: theme.surface, borderRadius: 3 }}>2h</code></span>
                </div>
              </HFCard>
            </div>
          </div>
        </div>
      </MacShell>
    </HFWindow>
  );
}

// ── B1 · Dashboard ───────────────────────────────────────────────────────────
function HiFi_MacB1({ theme }) {
  return (
    <HFWindow theme={theme}>
      <MacShell theme={theme} active="dashboard">
        <HFTopBar theme={theme} right={
          <>
            <HFButton size="sm" theme={theme} icon="⌘K">search</HFButton>
            <HFButton size="sm" primary theme={theme} icon="+">new invoice</HFButton>
          </>
        }>
          <span style={{ fontSize: 13, fontWeight: 500 }}>Dashboard</span>
        </HFTopBar>
        <div style={{ flex: 1, padding: '28px 32px', overflow: 'auto', display: 'flex', flexDirection: 'column', gap: 24 }}>
          {/* KPI strip */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16 }}>
            <HFKpi theme={theme} label="Outstanding" value="€1’850" sub="2 invoices" />
            <HFKpi theme={theme} label="Overdue" value="€590" sub="la-trame · +6 d" tone="danger" />
            <HFKpi theme={theme} label="Ready to invoice" value="€1’090" sub="2 buckets" tone="accent" />
            <HFKpi theme={theme} label="This month" value="€2’840" sub="+€480 vs March" />
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1.4fr 1fr', gap: 20, flex: 1, minHeight: 0 }}>
            {/* Needs attention */}
            <HFCard theme={theme} padding={0}>
              <div style={{ padding: '14px 18px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', borderBottom: `1px solid ${theme.border}` }}>
                <span style={{ fontSize: 13, fontWeight: 500 }}>Needs attention</span>
                <span style={{ fontSize: 11, color: theme.textMuted }}>5 items</span>
              </div>
              {[
                { tone: 'overdue', primary: 'HIN-2026-002 · boutique-la-trame', meta: 'overdue · +6 d', amt: '€590', cta: 'send reminder' },
                { tone: 'ready', primary: 'Centerpieces · mariage-lea-tom', meta: '12 pcs + €85 materials', amt: '€505', cta: 'create invoice' },
                { tone: 'ready', primary: 'boutique-la-trame · Spring drop', meta: '14 pcs', amt: '€590', cta: 'create invoice' },
                { tone: 'finalized', primary: 'HIN-2026-003 · marche-noel-2026', meta: 'finalized · not sent', amt: '€720', cta: 'mark sent' },
                { tone: 'sent', primary: 'HIN-2026-001 · lea-tom', meta: 'due in 3 d', amt: '€1’190', cta: 'mark paid' },
              ].map((r, i, a) => (
                <div key={i} style={{
                  display: 'flex', alignItems: 'center', gap: 14,
                  padding: '14px 18px',
                  borderBottom: i < a.length - 1 ? `1px solid ${theme.border}` : 'none',
                }}>
                  <HFPill tone={r.tone} theme={theme}>{r.tone}</HFPill>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontSize: 13, fontWeight: 500, marginBottom: 2 }}>{r.primary}</div>
                    <div style={{ fontSize: 11, color: theme.textMuted, fontFamily: HF_FONT_NUM }}>{r.meta}</div>
                  </div>
                  <HFNum theme={theme} size={14} weight={500}>{r.amt}</HFNum>
                  <HFButton size="sm" theme={theme}>{r.cta}</HFButton>
                </div>
              ))}
            </HFCard>

            {/* Revenue sparkline */}
            <HFCard theme={theme}>
              <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: 16 }}>
                <div>
                  <div style={{ fontSize: 11, color: theme.textMuted, fontWeight: 500, letterSpacing: 0.4, textTransform: 'uppercase' }}>Revenue · 12 mo</div>
                  <HFNum theme={theme} size={28} weight={600} style={{ display: 'block', marginTop: 6 }}>€21’360</HFNum>
                  <div style={{ fontSize: 11, color: theme.success, marginTop: 4 }}>↑ 18% vs prev</div>
                </div>
                <HFButton size="sm" ghost theme={theme}>year</HFButton>
              </div>
              <Sparkline theme={theme} />
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 10, color: theme.textMuted, marginTop: 8, fontFamily: HF_FONT_NUM }}>
                <span>May 25</span><span>Apr 26</span>
              </div>
            </HFCard>
          </div>
        </div>
      </MacShell>
    </HFWindow>
  );
}

function HFKpi({ label, value, sub, tone, theme }) {
  const accentColor = tone === 'danger' ? theme.danger : tone === 'accent' ? theme.accent : theme.textPrimary;
  return (
    <HFCard theme={theme}>
      <div style={{ fontSize: 11, color: theme.textMuted, fontWeight: 500, letterSpacing: 0.4, textTransform: 'uppercase', marginBottom: 8 }}>{label}</div>
      <HFNum theme={theme} size={26} weight={600} color={accentColor}>{value}</HFNum>
      <div style={{ fontSize: 11, color: theme.textMuted, marginTop: 4, fontFamily: HF_FONT_NUM }}>{sub}</div>
    </HFCard>
  );
}

function Sparkline({ theme }) {
  // 12 data points ~scaled.
  const pts = [120, 180, 140, 240, 200, 280, 220, 340, 380, 300, 420, 480];
  const w = 360, h = 90, max = Math.max(...pts), pad = 4;
  const stepX = (w - pad * 2) / (pts.length - 1);
  const path = pts.map((v, i) => {
    const x = pad + i * stepX;
    const y = pad + (1 - v / max) * (h - pad * 2);
    return `${i === 0 ? 'M' : 'L'} ${x} ${y}`;
  }).join(' ');
  const fillPath = `${path} L ${pad + (pts.length - 1) * stepX} ${h - pad} L ${pad} ${h - pad} Z`;
  return (
    <svg viewBox={`0 0 ${w} ${h}`} style={{ width: '100%', height: 90, display: 'block' }}>
      <defs>
        <linearGradient id="hf-spark" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor={theme.accent} stopOpacity="0.3" />
          <stop offset="100%" stopColor={theme.accent} stopOpacity="0" />
        </linearGradient>
      </defs>
      <path d={fillPath} fill="url(#hf-spark)" />
      <path d={path} stroke={theme.accent} strokeWidth="1.5" fill="none" />
      <circle cx={pad + (pts.length - 1) * stepX} cy={pad + (1 - pts[pts.length - 1] / max) * (h - pad * 2)} r="3" fill={theme.accent} />
    </svg>
  );
}

// ── B3 · Confirm sheet (modal over the dashboard) ───────────────────────────
function HiFi_MacB3({ theme }) {
  return (
    <HFWindow theme={theme}>
      <MacShell theme={theme} active="dashboard">
        <HFTopBar theme={theme}>
          <span style={{ fontSize: 13, fontWeight: 500 }}>Dashboard</span>
        </HFTopBar>
        <div style={{ flex: 1, position: 'relative', background: theme.bg }}>
          {/* Faded dashboard backdrop */}
          <div style={{ position: 'absolute', inset: 0, padding: 32, opacity: 0.35, pointerEvents: 'none' }}>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16, marginBottom: 20 }}>
              {[1,2,3,4].map((i) => <div key={i} style={{ height: 92, background: theme.surface, border: `1px solid ${theme.border}`, borderRadius: 8 }} />)}
            </div>
            <div style={{ height: 320, background: theme.surface, border: `1px solid ${theme.border}`, borderRadius: 8 }} />
          </div>
          {/* Modal scrim */}
          <div style={{ position: 'absolute', inset: 0, background: '#0006', backdropFilter: 'blur(2px)' }} />
          {/* Sheet */}
          <div style={{
            position: 'absolute', top: '50%', left: '50%', transform: 'translate(-50%, -50%)',
            width: 560,
            background: theme.surface,
            border: `1px solid ${theme.borderStrong}`,
            borderRadius: 12,
            boxShadow: '0 24px 60px #000a',
            overflow: 'hidden',
          }}>
            <div style={{ padding: '20px 24px', borderBottom: `1px solid ${theme.border}`, display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between' }}>
              <div>
                <div style={{ fontSize: 17, fontWeight: 600, letterSpacing: -0.2 }}>Create invoice</div>
                <div style={{ fontSize: 12, color: theme.textMuted, marginTop: 2 }}>Centerpieces · mariage-lea-tom · 11.5 h + 1 fixed cost</div>
              </div>
              <span style={{ color: theme.textMuted, fontSize: 16, cursor: 'default' }}>×</span>
            </div>
            <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 16 }}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                <HFField theme={theme} label="Recipient" value="lea-tom Thunersee AG" prefix="◇" />
                <HFField theme={theme} label="Invoice number" value="HIN-2026-004" suffix="auto" monospace />
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 12 }}>
                <HFField theme={theme} label="Issue date" value="2026-04-26" monospace />
                <HFField theme={theme} label="Due date" value="2026-05-26" suffix="net 30" monospace />
                <HFField theme={theme} label="Currency" value="EUR" />
              </div>
              <HFField theme={theme} label="Note on invoice" placeholder="optional · e.g. thanks!" value="Kleinunternehmer · § 19 UStG" />

              {/* Totals strip */}
              <div style={{
                marginTop: 4, padding: '14px 16px',
                background: theme.surfaceAlt,
                border: `1px solid ${theme.border}`,
                borderRadius: 8,
              }}>
                <TotalRow theme={theme} label="12 pcs × €35" amt="€420.00" />
                <TotalRow theme={theme} label="Materials · fixed" amt="€85.00" />
                <div style={{ height: 1, background: theme.border, margin: '8px 0' }} />
                <TotalRow theme={theme} label="Total" amt="€855.00" big />
              </div>
            </div>
            <div style={{ padding: '14px 24px', borderTop: `1px solid ${theme.border}`, display: 'flex', justifyContent: 'space-between', alignItems: 'center', background: theme.surface }}>
              <HFButton theme={theme} ghost size="sm">cancel</HFButton>
              <div style={{ display: 'flex', gap: 8 }}>
                <HFButton theme={theme}>save as finalized</HFButton>
                <HFButton theme={theme} primary>finalize + open PDF</HFButton>
              </div>
            </div>
          </div>
        </div>
      </MacShell>
    </HFWindow>
  );
}

function TotalRow({ label, amt, big, theme }) {
  return (
    <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', padding: '4px 0' }}>
      <span style={{ fontSize: big ? 14 : 13, color: big ? theme.textPrimary : theme.textSecondary, fontWeight: big ? 500 : 400 }}>{label}</span>
      <HFNum theme={theme} size={big ? 18 : 13} weight={big ? 600 : 400}>{amt}</HFNum>
    </div>
  );
}

// ── B4 · Finalized · invoice + PDF preview side by side ─────────────────────
function HiFi_MacB4({ theme }) {
  return (
    <HFWindow theme={theme}>
      <MacShell theme={theme} active="invoices">
        <HFTopBar theme={theme} right={
          <>
            <HFButton size="sm" theme={theme} icon="↗">share</HFButton>
            <HFButton size="sm" theme={theme} icon="↓">PDF</HFButton>
            <HFButton size="sm" primary theme={theme}>mark sent</HFButton>
          </>
        }>
          <span style={{ color: theme.textMuted, fontSize: 13 }}>Invoices</span>
          <span style={{ color: theme.textMuted }}>/</span>
          <span style={{ fontFamily: HF_FONT_NUM, fontSize: 13, fontWeight: 500 }}>HIN-2026-004</span>
          <HFPill tone="finalized" theme={theme} style={{ marginLeft: 8 }}>finalized</HFPill>
        </HFTopBar>

        <div style={{ flex: 1, display: 'grid', gridTemplateColumns: '380px 1fr', minHeight: 0, background: theme.bg }}>
          {/* Left meta column */}
          <div style={{ padding: 24, overflow: 'auto', borderRight: `1px solid ${theme.border}`, background: theme.surface, display: 'flex', flexDirection: 'column', gap: 20 }}>
            <div>
              <div style={{ fontSize: 11, color: theme.textMuted, fontWeight: 500, letterSpacing: 0.4, textTransform: 'uppercase', marginBottom: 6 }}>Total</div>
              <HFNum theme={theme} size={32} weight={700}>€855.00</HFNum>
              <div style={{ fontSize: 12, color: theme.textMuted, marginTop: 4 }}>due in 30 d · 2026-05-26</div>
            </div>
            <HFDivider theme={theme} />
            <MetaList theme={theme} items={[
              ['Number', 'HIN-2026-004', true],
              ['Issue date', '2026-04-26', true],
              ['Due date', '2026-05-26', true],
              ['Currency', 'EUR', false],
              ['Status', 'finalized · not sent', false],
            ]} />
            <HFDivider theme={theme} />
            <div>
              <div style={{ fontSize: 11, color: theme.textMuted, fontWeight: 500, letterSpacing: 0.4, textTransform: 'uppercase', marginBottom: 8 }}>Recipient</div>
              <div style={{ fontSize: 13, fontWeight: 500, marginBottom: 2 }}>lea-tom Thunersee AG</div>
              <div style={{ fontSize: 12, color: theme.textSecondary, lineHeight: 1.5 }}>
                Seestrasse 12<br />3700 Spiez<br />Switzerland
              </div>
            </div>
            <HFDivider theme={theme} />
            <div>
              <div style={{ fontSize: 11, color: theme.textMuted, fontWeight: 500, letterSpacing: 0.4, textTransform: 'uppercase', marginBottom: 10 }}>Activity</div>
              <ActivityRow theme={theme} when="just now" who="you" what="finalized · PDF rendered" />
              <ActivityRow theme={theme} when="just now" who="you" what="created invoice" />
            </div>
          </div>

          {/* Right PDF preview */}
          <div style={{ padding: 24, overflow: 'auto', background: theme.bg, display: 'flex', justifyContent: 'center' }}>
            <PDFPreview theme={theme} />
          </div>
        </div>
      </MacShell>
    </HFWindow>
  );
}

function MetaList({ items, theme }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
      {items.map(([k, v, mono]) => (
        <div key={k} style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12 }}>
          <span style={{ color: theme.textMuted }}>{k}</span>
          <span style={{ color: theme.textPrimary, fontFamily: mono ? HF_FONT_NUM : HF_FONT_UI, fontVariantNumeric: 'tabular-nums' }}>{v}</span>
        </div>
      ))}
    </div>
  );
}
function ActivityRow({ when, who, what, theme }) {
  return (
    <div style={{ display: 'flex', gap: 10, padding: '6px 0' }}>
      <div style={{ width: 6, height: 6, borderRadius: 3, background: theme.accent, marginTop: 6, flex: '0 0 auto' }} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 12, color: theme.textPrimary }}>{what}</div>
        <div style={{ fontSize: 11, color: theme.textMuted, marginTop: 1 }}>{who} · {when}</div>
      </div>
    </div>
  );
}

// PDF preview — A4 portrait, white paper regardless of theme.
function PDFPreview({ theme }) {
  return (
    <div style={{
      width: '100%',
      maxWidth: 720,
      alignSelf: 'stretch',
      background: '#FFFFFF',
      color: '#0A0A0B',
      padding: '56px 64px',
      fontFamily: HF_FONT_UI,
      fontSize: 11,
      lineHeight: 1.5,
      borderRadius: 2,
      border: `1px solid ${theme.border}`,
    }}>
      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 36 }}>
        <div>
          <div style={{
            display: 'inline-flex', alignItems: 'center', gap: 8,
            fontSize: 14, fontWeight: 600, letterSpacing: -0.2,
          }}>
            <span style={{ width: 18, height: 18, borderRadius: 4, background: '#0A0A0B', color: 'white', display: 'grid', placeItems: 'center', fontSize: 9 }}>p</span>
            happ.ines_creations
          </div>
          <div style={{ marginTop: 16, fontSize: 9, color: '#52525B', lineHeight: 1.6 }}>
            Andreas Veys · happ.ines_creations<br />
            Hauptstrasse 14<br />
            3000 Bern · Switzerland
          </div>
        </div>
        <div style={{ textAlign: 'right' }}>
          <div style={{ fontSize: 22, fontWeight: 600, letterSpacing: -0.4 }}>Invoice</div>
          <div style={{ fontFamily: HF_FONT_NUM, fontSize: 10, color: '#52525B', marginTop: 4 }}>HIN-2026-004</div>
        </div>
      </div>
      {/* Bill to / dates */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 24, marginBottom: 32 }}>
        <div>
          <div style={{ fontSize: 9, color: '#8E8E93', textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 6 }}>Bill to</div>
          <div style={{ fontSize: 11, fontWeight: 500 }}>lea-tom Thunersee AG</div>
          <div style={{ fontSize: 10, color: '#52525B', marginTop: 2, lineHeight: 1.5 }}>Seestrasse 12<br />3700 Spiez · Switzerland</div>
        </div>
        <div>
          <div style={{ fontSize: 9, color: '#8E8E93', textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 6 }}>Issued</div>
          <div style={{ fontFamily: HF_FONT_NUM, fontSize: 11 }}>2026-04-26</div>
          <div style={{ fontSize: 9, color: '#8E8E93', textTransform: 'uppercase', letterSpacing: 0.5, marginTop: 12, marginBottom: 6 }}>Due</div>
          <div style={{ fontFamily: HF_FONT_NUM, fontSize: 11 }}>2026-05-26</div>
        </div>
        <div>
          <div style={{ fontSize: 9, color: '#8E8E93', textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 6 }}>Project</div>
          <div style={{ fontSize: 11 }}>Centerpieces</div>
          <div style={{ fontSize: 10, color: '#52525B', marginTop: 2 }}>mariage-lea-tom</div>
        </div>
      </div>
      {/* Line items */}
      <div style={{ borderTop: '1px solid #0a0a0b', paddingTop: 12, marginBottom: 24 }}>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 60px 80px 80px', gap: 12, fontSize: 9, color: '#8E8E93', textTransform: 'uppercase', letterSpacing: 0.5, paddingBottom: 8, borderBottom: '1px solid #E5E5E7' }}>
          <span>Description</span><span style={{ textAlign: 'right' }}>Qty</span><span style={{ textAlign: 'right' }}>Rate</span><span style={{ textAlign: 'right' }}>Amount</span>
        </div>
        <PDFRow desc="Centerpieces · 12 ceramic pcs" qty="12 pcs" rate="€35.00" amt="€420.00" />
        <PDFRow desc="Materials · clay + glazes" qty="1" rate="€85.00" amt="€85.00" />
      </div>
      {/* Totals */}
      <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: 28 }}>
        <div style={{ width: 240 }}>
          <PDFTotal label="Subtotal" amt="€855.00" />
          <PDFTotal label="VAT" amt="—" muted />
          <div style={{ borderTop: '1px solid #0a0a0b', paddingTop: 10, marginTop: 10 }} />
          <PDFTotal label="Total due" amt="€855.00" big />
        </div>
      </div>
      {/* Payment */}
      <div style={{ background: '#F2F2F4', padding: '14px 16px', borderRadius: 4, marginBottom: 16 }}>
        <div style={{ fontSize: 9, color: '#8E8E93', textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 6 }}>Payment</div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, fontSize: 10 }}>
          <div><span style={{ color: '#52525B' }}>IBAN</span><br /><span style={{ fontFamily: HF_FONT_NUM }}>CH93 0076 2011 6238 5295 7</span></div>
          <div><span style={{ color: '#52525B' }}>BIC</span><br /><span style={{ fontFamily: HF_FONT_NUM }}>POFICHBEXXX</span></div>
        </div>
      </div>
      <div style={{ fontSize: 9, color: '#8E8E93', lineHeight: 1.5 }}>
        Kleinunternehmer · § 19 UStG · Mehrwertsteuer wird nicht ausgewiesen.<br />
        Thanks for the trust — Andreas
      </div>
    </div>
  );
}
function PDFRow({ desc, qty, rate, amt }) {
  return (
    <div style={{ display: 'grid', gridTemplateColumns: '1fr 60px 80px 80px', gap: 12, padding: '10px 0', borderBottom: '1px solid #E5E5E7', fontSize: 10 }}>
      <span>{desc}</span>
      <span style={{ fontFamily: HF_FONT_NUM, textAlign: 'right' }}>{qty}</span>
      <span style={{ fontFamily: HF_FONT_NUM, textAlign: 'right' }}>{rate}</span>
      <span style={{ fontFamily: HF_FONT_NUM, textAlign: 'right' }}>{amt}</span>
    </div>
  );
}
function PDFTotal({ label, amt, big, muted }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', padding: '4px 0', fontSize: big ? 13 : 10, fontWeight: big ? 600 : 400, color: muted ? '#8E8E93' : '#0A0A0B' }}>
      <span>{label}</span>
      <span style={{ fontFamily: HF_FONT_NUM }}>{amt}</span>
    </div>
  );
}

Object.assign(window, {
  HiFi_MacA1, HiFi_MacA2, HiFi_MacA3, HiFi_MacB1, HiFi_MacB3, HiFi_MacB4,
});
