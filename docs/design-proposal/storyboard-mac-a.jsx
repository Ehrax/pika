// Mac storyboards — three distinct directions, each told as a sequence of artboards.
// Mac frames: 920×600. Original window chrome (three neutral dots), NOT Apple-branded.

// ─── Reusable Mac chrome ─────────────────────────────────────
function MacShell({ title, accent, children }) {
  return (
    <div style={{ width: '100%', height: '100%', background: PAPER, borderRadius: 8, overflow: 'hidden', display: 'flex', flexDirection: 'column', boxShadow: '0 1px 0 #1f1d1b22' }}>
      <WindowChrome title={title} accent={accent} />
      <div style={{ flex: 1, display: 'flex', minHeight: 0 }}>{children}</div>
    </div>
  );
}

// ────────────────────────────────────────────────────────────────────
// STORYBOARD A — Capture-first (3-pane, list-driven, inline add)
// "I open the app, find my bucket, type two times, done."
// ────────────────────────────────────────────────────────────────────

function MacA1_Sidebar() {
  return (
    <MacShell title="ehrax · invoicing" accent="A · capture">
      <Sidebar selected="bikepark" />
      <BucketList selected="MVP" />
      <BucketDetail mode="empty" />
    </MacShell>
  );
}
function MacA2_BucketDetail() {
  return (
    <MacShell title="ehrax · invoicing" accent="A · capture">
      <Sidebar selected="bikepark" />
      <BucketList selected="MVP" />
      <BucketDetail mode="filled" />
    </MacShell>
  );
}
function MacA3_InlineAdd() {
  return (
    <MacShell title="ehrax · invoicing" accent="A · capture">
      <Sidebar selected="bikepark" />
      <BucketList selected="MVP" />
      <BucketDetail mode="adding" />
    </MacShell>
  );
}
function MacA4_RateChange() {
  return (
    <MacShell title="ehrax · invoicing" accent="A · capture">
      <Sidebar selected="bikepark" />
      <BucketList selected="MVP" />
      <BucketDetail mode="rate-change" />
    </MacShell>
  );
}
function MacA5_ReadyToInvoice() {
  return (
    <MacShell title="ehrax · invoicing" accent="A · capture">
      <Sidebar selected="bikepark" />
      <BucketList selected="MVP" markReady />
      <BucketDetail mode="ready" />
    </MacShell>
  );
}

// Sidebar — projects.
function Sidebar({ selected }) {
  const projects = [
    { id: 'dash', emoji: '◆', label: 'Dashboard', count: '' },
    { id: 'bikepark', emoji: '🚵', label: 'bikepark-thunersee', count: '3' },
    { id: 'helvetia', emoji: '⛰', label: 'helvetia-tools', count: '2' },
    { id: 'ehrax', emoji: '◇', label: 'ehrax-internal', count: '1' },
    { id: 'archived', emoji: '⌗', label: 'archived', count: '' },
  ];
  return (
    <div style={{ width: 188, borderRight: `1px solid ${INK}22`, padding: '10px 8px', background: PAPER_2, display: 'flex', flexDirection: 'column', gap: 2 }}>
      <div style={{ fontFamily: 'var(--mono)', fontSize: 10, color: '#7a7468', textTransform: 'uppercase', padding: '2px 8px 8px' }}>projects</div>
      {projects.map((p) => (
        <div key={p.id} style={{
          display: 'flex', alignItems: 'center', gap: 8,
          padding: '5px 8px', borderRadius: 5,
          background: selected === p.id ? INK : 'transparent',
          color: selected === p.id ? PAPER : INK,
          fontFamily: 'var(--hand)', fontSize: 13,
        }}>
          <span style={{ fontSize: 13 }}>{p.emoji}</span>
          <span style={{ flex: 1 }}>{p.label}</span>
          {p.count ? <span style={{ fontFamily: 'var(--mono)', fontSize: 10, opacity: 0.6 }}>{p.count}</span> : null}
        </div>
      ))}
      <div style={{ flex: 1 }} />
      <div style={{ padding: '6px 8px', fontFamily: 'var(--hand)', fontSize: 12, color: '#7a7468', display: 'flex', alignItems: 'center', gap: 6 }}>
        <SketchCircle size={16}>+</SketchCircle> new project
      </div>
    </div>
  );
}

// Bucket list — middle pane.
function BucketList({ selected, markReady }) {
  const buckets = [
    { id: 'MVP', emoji: '🛠', title: 'MVP', meta: '12.5 h · 1 000 €', state: markReady ? 'ready' : 'active' },
    { id: 'maint', emoji: '◐', title: 'Maintenance', meta: '3.0 h · 240 €', state: 'active' },
    { id: 'dash', emoji: '▦', title: 'Customer dashboard', meta: '6.5 h · 520 €', state: 'active' },
    { id: 'infra', emoji: '☷', title: 'Infra fixed costs', meta: '2 items · 84 €', state: 'active' },
    { id: 'invQ1', emoji: '✓', title: 'Q1 — invoiced', meta: 'EHX-2026-001', state: 'finalized' },
  ];
  return (
    <div style={{ width: 232, borderRight: `1px solid ${INK}22`, padding: '10px 0', display: 'flex', flexDirection: 'column' }}>
      <div style={{ padding: '0 12px 6px', fontFamily: 'var(--mono)', fontSize: 10, color: '#7a7468', textTransform: 'uppercase', display: 'flex', justifyContent: 'space-between' }}>
        <span>buckets · bikepark-thunersee</span>
        <span>+</span>
      </div>
      <SketchRule width="calc(100% - 20px)" style={{ margin: '0 10px' }} dashed />
      {buckets.map((b) => (
        <div key={b.id} style={{
          padding: '8px 12px',
          background: selected === b.id ? '#1f1d1b' : 'transparent',
          color: selected === b.id ? PAPER : INK,
          display: 'flex', flexDirection: 'column', gap: 3,
          borderBottom: `1px dashed ${INK}1f`,
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontFamily: 'var(--hand)', fontSize: 14 }}>
            <span>{b.emoji}</span><span style={{ flex: 1 }}>{b.title}</span>
            {b.state !== 'active' ? <StatePill state={b.state} /> : null}
          </div>
          <div style={{ fontFamily: 'var(--mono)', fontSize: 10, opacity: selected === b.id ? 0.7 : 0.55, paddingLeft: 22 }}>{b.meta}</div>
        </div>
      ))}
    </div>
  );
}

// Bucket detail — right pane, several modes.
function BucketDetail({ mode }) {
  return (
    <div style={{ flex: 1, padding: '20px 26px', display: 'flex', flexDirection: 'column', gap: 14, overflow: 'hidden' }}>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 10 }}>
        <span style={{ fontFamily: 'var(--display)', fontSize: 28, lineHeight: 1 }}>🛠 MVP</span>
        <span style={{ fontFamily: 'var(--mono)', fontSize: 10, color: '#7a7468' }}>bikepark-thunersee</span>
        <span style={{ flex: 1 }} />
        <span style={{ fontFamily: 'var(--hand)', fontSize: 13, color: '#7a7468' }}>
          rate <u style={{ textDecorationStyle: 'wavy', textDecorationColor: mode === 'rate-change' ? ACCENT : INK + '55' }}>
            {mode === 'rate-change' ? '90' : '80'} €/h
          </u>
        </span>
        <SketchCircle size={22}>+</SketchCircle>
      </div>
      <SketchRule />

      {mode === 'empty' && <EmptyDay />}
      {mode === 'filled' && <FilledDays rate={80} />}
      {mode === 'adding' && <AddingInline rate={80} />}
      {mode === 'rate-change' && <FilledDays rate={90} highlightChange />}
      {mode === 'ready' && <FilledDays rate={80} ready />}
    </div>
  );
}

function EmptyDay() {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 12, color: '#9b9485', fontFamily: 'var(--hand)' }}>
      <div style={{ fontSize: 14 }}>Today · Mon 26 Apr</div>
      <SketchPlaceholder height={42} label="press + or just type a time range, e.g. 10:00–12:00" />
      <div style={{ fontSize: 11, fontFamily: 'var(--mono)' }}>no entries yet</div>
    </div>
  );
}

function FilledDays({ rate, highlightChange, ready }) {
  const entries = [
    { day: 'Today · Mon 26 Apr', rows: [
      { t: '10:00 – 12:00', d: '2.00 h', note: 'auth + token refresh', billable: true },
      { t: '14:30 – 15:00', d: '0.50 h', note: 'review notes', billable: false },
    ]},
    { day: 'Yesterday · Sun 25 Apr', rows: [
      { t: '14:00 – 16:30', d: '2.50 h', note: 'map tile cache', billable: true },
    ]},
    { day: 'Fri 23 Apr', rows: [
      { t: '09:00 – 12:30', d: '3.50 h', note: 'API spec walkthrough', billable: true },
      { t: '13:30 – 17:00', d: '3.50 h', note: '— route persistence', billable: true },
    ]},
  ];
  const billableHrs = 11.5;
  const nonBillable = 0.5;
  const fixed = [
    { d: '24 Apr', label: 'Mapbox tiles · Apr', q: '1', unit: '49.00', total: '49.00' },
    { d: '20 Apr', label: 'Domain · ehrax.dev (yearly /12)', q: '1', unit: '1.20', total: '1.20' },
  ];
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 14, fontFamily: 'var(--hand)', fontSize: 13, overflow: 'auto' }}>
      {entries.map((g) => (
        <div key={g.day} style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
          <div style={{ fontFamily: 'var(--mono)', fontSize: 10, color: '#7a7468', textTransform: 'uppercase' }}>{g.day}</div>
          {g.rows.map((r, i) => (
            <div key={i} style={{ display: 'grid', gridTemplateColumns: '90px 1fr auto', gap: 14, alignItems: 'baseline', padding: '2px 0' }}>
              <span style={{ fontVariantNumeric: 'tabular-nums' }}>{r.t}</span>
              <span style={{ color: r.billable ? INK : '#7a7468', fontStyle: r.billable ? 'normal' : 'italic' }}>
                {r.d} <span style={{ opacity: 0.6 }}>· {r.note}</span>
              </span>
              <span style={{ color: r.billable ? INK : '#7a7468' }}>
                {r.billable ? <Money amount={(parseFloat(r.d) * rate).toFixed(0)} size={13} /> : <span style={{ fontFamily: 'var(--mono)', fontSize: 11 }}>non-billable</span>}
              </span>
            </div>
          ))}
        </div>
      ))}

      <div style={{ display: 'flex', flexDirection: 'column', gap: 4, marginTop: 4 }}>
        <div style={{ fontFamily: 'var(--mono)', fontSize: 10, color: '#7a7468', textTransform: 'uppercase' }}>Fixed costs</div>
        {fixed.map((f, i) => (
          <div key={i} style={{ display: 'grid', gridTemplateColumns: '90px 1fr 60px auto', gap: 14, alignItems: 'baseline' }}>
            <span style={{ fontVariantNumeric: 'tabular-nums' }}>{f.d}</span>
            <span>{f.label}</span>
            <span style={{ fontFamily: 'var(--mono)', fontSize: 10, opacity: 0.6 }}>{f.q} × {f.unit}</span>
            <Money amount={f.total} size={13} />
          </div>
        ))}
      </div>

      <SketchRule dashed />

      <div style={{ display: 'flex', flexDirection: 'column', gap: 2, fontSize: 13 }}>
        <SummaryRow label="Billable" value={`${billableHrs.toFixed(2)} h · ${(billableHrs * rate).toFixed(0)} €`} highlight={highlightChange} />
        <SummaryRow label="Non-billable" value={`${nonBillable.toFixed(2)} h`} />
        <SummaryRow label="Fixed costs" value="50.20 €" />
        <SummaryRow label="Total" value={`${(billableHrs * rate + 50.2).toFixed(2)} €`} bold />
      </div>

      {ready ? (
        <div style={{ marginTop: 6 }}>
          <SketchFrame radius={6} fill={PAPER_2} padding="12px 16px" stroke={ACCENT_OK}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
              <StatePill state="ready" />
              <div style={{ flex: 1, display: 'flex', flexDirection: 'column', lineHeight: 1.25 }}>
                <span style={{ fontFamily: 'var(--hand)', fontSize: 13 }}>11.5 h + 50.20 € fixed</span>
                <span style={{ fontFamily: 'var(--mono)', fontSize: 10, color: '#7a7468' }}>bikepark-thunersee · EUR</span>
              </div>
              <span style={{ fontFamily: 'var(--display)', fontSize: 22, color: ACCENT_OK, fontVariantNumeric: 'tabular-nums' }}>970.20 €</span>
              <span style={{ position: 'relative', padding: '5px 14px', fontFamily: 'var(--hand)', fontSize: 12 }}>
                <SketchBox width="100%" height="100%" radius={4} stroke={ACCENT_OK} strokeWidth={1.6} style={{ position: 'absolute', inset: 0 }} />
                <span style={{ position: 'relative', color: ACCENT_OK, whiteSpace: 'nowrap' }}>create invoice →</span>
              </span>
            </div>
          </SketchFrame>
        </div>
      ) : null}

      {highlightChange ? (
        <Annotation dir="up" style={{ alignSelf: 'flex-end', marginTop: -2 }}>rate change re-totals all unlocked entries</Annotation>
      ) : null}
    </div>
  );
}

function SummaryRow({ label, value, bold, highlight }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', fontFamily: 'var(--hand)',
      fontWeight: bold ? 700 : 400, color: highlight ? ACCENT : INK }}>
      <span style={{ color: '#7a7468' }}>{label}</span>
      <span style={{ fontVariantNumeric: 'tabular-nums' }}>{value}</span>
    </div>
  );
}

function AddingInline() {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 10, fontFamily: 'var(--hand)', fontSize: 13 }}>
      <div style={{ fontFamily: 'var(--mono)', fontSize: 10, color: '#7a7468', textTransform: 'uppercase' }}>Today · Mon 26 Apr</div>

      <SketchFrame radius={6} fill={PAPER} stroke={ACCENT} padding="8px 12px">
        <div style={{ display: 'grid', gridTemplateColumns: '70px 16px 70px 1fr 70px', gap: 10, alignItems: 'center' }}>
          <span style={{ borderBottom: `1.5px solid ${ACCENT}`, padding: '0 0 1px' }}>10:00</span>
          <span style={{ color: '#7a7468' }}>—</span>
          <span style={{ borderBottom: `1.5px dashed ${INK}55` }}><span style={{ color: '#7a7468' }}>12:00|</span></span>
          <span style={{ color: '#7a7468', fontSize: 12 }}>auth + token refresh<span style={{ marginLeft: 4, opacity: 0.5 }}>(opt.)</span></span>
          <span style={{ textAlign: 'right' }}>2.00 h · 160 €</span>
        </div>
        <div style={{ marginTop: 6, display: 'flex', alignItems: 'center', gap: 10, fontSize: 11, color: '#7a7468', fontFamily: 'var(--mono)' }}>
          <span>↩ save</span><span>· esc cancel</span><span>· ⌥ for non-billable</span>
        </div>
      </SketchFrame>

      <Annotation dir="up" style={{ alignSelf: 'flex-start' }}>
        defaults: today · current bucket rate · billable
      </Annotation>

      <div style={{ opacity: 0.55, paddingTop: 8 }}>
        <div style={{ display: 'grid', gridTemplateColumns: '90px 1fr auto', gap: 14 }}>
          <span>14:00 – 16:30</span><span>2.50 h · map tile cache</span><span>200 €</span>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: '90px 1fr auto', gap: 14 }}>
          <span>09:00 – 12:30</span><span>3.50 h · API spec walkthrough</span><span>280 €</span>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { MacA1_Sidebar, MacA2_BucketDetail, MacA3_InlineAdd, MacA4_RateChange, MacA5_ReadyToInvoice });
