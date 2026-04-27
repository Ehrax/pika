// Storyboard B — Dashboard-first (Mac). Revenue surface → ready bucket → invoice draft → finalize.
// Same MacShell/Sidebar/etc come from storyboard-mac-a.jsx.

function MacB1_Dashboard() {
  return (
    <MacShell title="ehrax · invoicing" accent="B · dashboard">
      <Sidebar selected="dash" />
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
        <DashHeader />
        <div style={{ flex: 1, padding: '14px 26px 18px', display: 'grid', gridTemplateColumns: '1.1fr 1fr', gap: 18, overflow: 'auto' }}>
          <DashKPIs />
          <DashAttention />
          <DashChart />
          <DashRecent />
        </div>
      </div>
    </MacShell>
  );
}

function DashHeader() {
  return (
    <div style={{ display: 'flex', alignItems: 'baseline', gap: 14, padding: '16px 26px 6px' }}>
      <span style={{ fontFamily: 'var(--display)', fontSize: 30 }}>April 2026</span>
      <span style={{ fontFamily: 'var(--mono)', fontSize: 11, color: '#7a7468' }}>ehrax.dev · all projects</span>
      <span style={{ flex: 1 }} />
      <span style={{ fontFamily: 'var(--hand)', fontSize: 12, color: '#7a7468' }}>this month / this year / outstanding</span>
    </div>
  );
}

function KPI({ label, value, sub, color = INK }) {
  return (
    <SketchFrame radius={6} padding="14px 16px" fill={PAPER}>
      <div style={{ fontFamily: 'var(--mono)', fontSize: 10, color: '#7a7468', textTransform: 'uppercase' }}>{label}</div>
      <div style={{ fontFamily: 'var(--display)', fontSize: 26, color, lineHeight: 1.2, paddingTop: 4 }}>{value}</div>
      {sub ? <div style={{ fontFamily: 'var(--hand)', fontSize: 11, color: '#7a7468', paddingTop: 2 }}>{sub}</div> : null}
    </SketchFrame>
  );
}

function DashKPIs() {
  return (
    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
      <KPI label="paid · this month" value="2 480 €" sub="2 invoices" color={ACCENT_OK} />
      <KPI label="paid · this year" value="11 920 €" sub="ytd" />
      <KPI label="outstanding" value="3 600 €" sub="2 sent · awaiting" color={ACCENT_WARN} />
      <KPI label="overdue" value="1 100 €" sub="EHX-2026-002 · +6 d" color={ACCENT} />
      <KPI label="expected" value="970 €" sub="MVP · ready" />
      <KPI label="this month tracked" value="34.5 h" sub="≈ 2 760 €" />
    </div>
  );
}

function DashAttention() {
  const items = [
    { state: 'ready', primary: 'MVP · bikepark-thunersee', meta: '11.5 h + fixed · 970 €', cta: 'create invoice' },
    { state: 'ready', primary: 'helvetia-tools Q1', meta: '6.0 h · 480 €', cta: 'create invoice' },
    { state: 'finalized', primary: 'EHX-2026-003 · ehrax-internal', meta: 'finalized · not sent', cta: 'mark sent' },
    { state: 'sent', primary: 'EHX-2026-001 · bikepark', meta: 'due in 3 d · 1 600 €', cta: 'mark paid' },
    { state: 'overdue', primary: 'EHX-2026-002 · helvetia', meta: '+6 d · 1 100 €', cta: 'remind' },
  ];
  return (
    <SketchFrame radius={6} padding="12px 14px" fill={PAPER}>
      <div style={{ fontFamily: 'var(--mono)', fontSize: 10, color: '#7a7468', textTransform: 'uppercase', paddingBottom: 8 }}>needs attention</div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
        {items.map((it, i) => (
          <div key={i} style={{ display: 'grid', gridTemplateColumns: '70px 1fr auto', gap: 10, alignItems: 'center', padding: '4px 0', borderBottom: `1px dashed ${INK}1f` }}>
            <StatePill state={it.state} />
            <div style={{ display: 'flex', flexDirection: 'column' }}>
              <span style={{ fontFamily: 'var(--hand)', fontSize: 13 }}>{it.primary}</span>
              <span style={{ fontFamily: 'var(--mono)', fontSize: 10, color: '#7a7468' }}>{it.meta}</span>
            </div>
            <span style={{ fontFamily: 'var(--hand)', fontSize: 12, color: ACCENT }}>{it.cta} →</span>
          </div>
        ))}
      </div>
    </SketchFrame>
  );
}

function DashChart() {
  // hand-drawn-ish bar chart of monthly paid revenue.
  const data = [1200, 800, 1900, 1400, 2400, 1700, 2200, 2600, 1800, 2900, 2480];
  const labels = ['J','F','M','A','M','J','J','A','S','O','N'];
  const max = 3000;
  return (
    <SketchFrame radius={6} padding="12px 14px" fill={PAPER}>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 10 }}>
        <div style={{ fontFamily: 'var(--mono)', fontSize: 10, color: '#7a7468', textTransform: 'uppercase' }}>monthly revenue · paid</div>
        <span style={{ flex: 1 }} />
        <span style={{ fontFamily: 'var(--hand)', fontSize: 11, color: '#7a7468' }}>last 11 months · €</span>
      </div>
      <div style={{ height: 130, display: 'grid', gridTemplateColumns: `repeat(${data.length}, 1fr)`, alignItems: 'end', gap: 6, padding: '12px 4px 4px' }}>
        {data.map((v, i) => (
          <div key={i} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4 }}>
            <div style={{ width: '100%', height: (v / max) * 100, position: 'relative' }}>
              <SketchBox width="100%" height="100%" radius={2} fill={i === data.length - 1 ? ACCENT_OK + '22' : INK + '11'} stroke={i === data.length - 1 ? ACCENT_OK : INK} strokeWidth={1.2} />
            </div>
            <span style={{ fontFamily: 'var(--mono)', fontSize: 9, color: '#7a7468' }}>{labels[i]}</span>
          </div>
        ))}
      </div>
    </SketchFrame>
  );
}

function DashRecent() {
  const items = [
    'invoice EHX-2026-004 · marked paid · today',
    'time entry · MVP 10:00–12:00 · today',
    'rate changed · MVP 80→90 €/h · 2 d ago',
    'fixed cost · Mapbox tiles 49 € · 4 d ago',
    'invoice EHX-2026-002 · sent · 9 d ago',
  ];
  return (
    <SketchFrame radius={6} padding="12px 14px" fill={PAPER}>
      <div style={{ fontFamily: 'var(--mono)', fontSize: 10, color: '#7a7468', textTransform: 'uppercase', paddingBottom: 6 }}>recent activity</div>
      {items.map((t, i) => (
        <div key={i} style={{ display: 'flex', gap: 8, padding: '3px 0', fontFamily: 'var(--hand)', fontSize: 12, borderBottom: `1px dashed ${INK}1f` }}>
          <span style={{ color: '#7a7468', fontFamily: 'var(--mono)', fontSize: 10 }}>·</span>
          <span style={{ flex: 1 }}>{t}</span>
        </div>
      ))}
    </SketchFrame>
  );
}

// Step 2 — open the "ready" bucket from dashboard.
function MacB2_ReadyBucket() {
  return (
    <MacShell title="ehrax · invoicing" accent="B · dashboard">
      <Sidebar selected="bikepark" />
      <BucketList selected="MVP" markReady />
      <BucketDetail mode="ready" />
    </MacShell>
  );
}

// Step 3 — confirm sheet (one screen between bucket and finalized invoice).
// No "draft" surface; user just confirms recipient/note/due and presses create.
function MacB3_Confirm() {
  return (
    <MacShell title="ehrax · invoicing" accent="B · dashboard">
      <Sidebar selected="bikepark" />
      <BucketList selected="MVP" markReady />
      <BucketDetail mode="ready" />
      <ConfirmSheet />
    </MacShell>
  );
}

function ConfirmSheet() {
  return (
    <div style={{ position: 'absolute', inset: 0, background: '#1f1d1b66', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <div style={{ width: 460, background: PAPER, borderRadius: 8, padding: '20px 22px', boxShadow: '0 12px 40px #1f1d1b44', position: 'relative' }}>
        <SketchBox width="100%" height="100%" radius={8} stroke={INK} style={{ position: 'absolute', inset: 0 }} />
        <div style={{ position: 'relative', display: 'flex', flexDirection: 'column', gap: 10 }}>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 10 }}>
            <span style={{ fontFamily: 'var(--display)', fontSize: 22 }}>Create invoice</span>
            <span style={{ fontFamily: 'var(--mono)', fontSize: 10, color: '#7a7468', flex: 1 }}>→ EHX-2026-005 (next)</span>
            <span style={{ fontFamily: 'var(--hand)', fontSize: 12, color: '#7a7468' }}>esc</span>
          </div>
          <SketchRule dashed />
          <FieldRow label="From" value="🛠 MVP · ☷ Infra fixed costs" />
          <FieldRow label="To" value="bikepark-thunersee AG · Thun, CH" />
          <FieldRow label="Date" value="26 Apr 2026" />
          <FieldRow label="Due" value="10 May 2026 (14 d)" />
          <FieldRow label="Profile" value="ehrax · CH-client EUR" />
          <FieldRow label="Note" value="Thanks for the trust on MVP delivery." />
          <SketchRule dashed />
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 8 }}>
            <span style={{ fontFamily: 'var(--mono)', fontSize: 10, color: '#7a7468', textTransform: 'uppercase' }}>total</span>
            <span style={{ fontFamily: 'var(--display)', fontSize: 26, color: ACCENT_OK }}>970.20 €</span>
            <span style={{ flex: 1 }} />
            <SketchButton>cancel</SketchButton>
            <SketchButton primary>create · finalize →</SketchButton>
          </div>
          <Annotation dir="up" style={{ alignSelf: 'flex-end' }}>locks entries · assigns number · renders PDF</Annotation>
        </div>
      </div>
    </div>
  );
}

function FieldRow({ label, value, muted }) {
  return (
    <div style={{ display: 'grid', gridTemplateColumns: '60px 1fr', gap: 8, alignItems: 'baseline' }}>
      <span style={{ fontFamily: 'var(--mono)', fontSize: 10, color: '#7a7468', textTransform: 'uppercase' }}>{label}</span>
      <span style={{ fontFamily: 'var(--hand)', fontSize: 13, color: muted ? '#9b9485' : INK, borderBottom: `1px dashed ${INK}33`, paddingBottom: 1 }}>{value}</span>
    </div>
  );
}
function BucketCheck({ on, label, meta }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
      <span style={{ position: 'relative', width: 14, height: 14 }}>
        <SketchBox width="100%" height="100%" radius={2} />
        {on ? <span style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', color: ACCENT, fontFamily: 'var(--hand)', fontSize: 14, lineHeight: 1 }}>✓</span> : null}
      </span>
      <span style={{ flex: 1, opacity: on ? 1 : 0.5 }}>{label}</span>
      <span style={{ fontFamily: 'var(--mono)', fontSize: 10, color: '#7a7468' }}>{meta}</span>
    </div>
  );
}
function SketchButton({ primary, children }) {
  const c = primary ? ACCENT_OK : INK;
  return (
    <span style={{ position: 'relative', padding: '6px 12px', fontFamily: 'var(--hand)', fontSize: 12, color: c, cursor: 'pointer' }}>
      <SketchBox width="100%" height="100%" radius={4} stroke={c} strokeWidth={primary ? 1.6 : 1.2} style={{ position: 'absolute', inset: 0 }} />
      <span style={{ position: 'relative' }}>{children}</span>
    </span>
  );
}

function DraftPreview() {
  return (
    <SketchFrame radius={4} padding="22px 28px" fill={PAPER}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
        <div>
          <div style={{ fontFamily: 'var(--display)', fontSize: 24 }}>Invoice</div>
          <div style={{ fontFamily: 'var(--mono)', fontSize: 10, color: '#7a7468' }}>preview · A4 · template: ch-client-eur</div>
        </div>
        <div style={{ textAlign: 'right', fontFamily: 'var(--hand)', fontSize: 12, color: '#7a7468' }}>
          ehrax.dev<br />Markus E. · Berlin DE<br />billing@ehrax.dev
        </div>
      </div>
      <SketchRule style={{ margin: '10px 0' }} />
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 18, fontFamily: 'var(--hand)', fontSize: 12 }}>
        <div>
          <div style={{ color: '#7a7468', fontFamily: 'var(--mono)', fontSize: 10, textTransform: 'uppercase' }}>To</div>
          bikepark-thunersee AG<br />Seestrasse 1<br />3600 Thun · CH
        </div>
        <div style={{ textAlign: 'right' }}>
          <div style={{ color: '#7a7468', fontFamily: 'var(--mono)', fontSize: 10, textTransform: 'uppercase' }}>Meta</div>
          № — pending —<br />date · 26 Apr 2026<br />due · 10 May 2026
        </div>
      </div>

      <div style={{ marginTop: 14, fontFamily: 'var(--hand)', fontSize: 12 }}>
        <LineRow desc="MVP — development hours" qty="11.50 h" unit="80 €/h" total="920.00 €" head />
        <LineRow desc="Mapbox tiles · April 2026" qty="1" unit="49.00 €" total="49.00 €" />
        <LineRow desc="Domain · ehrax.dev (yearly /12)" qty="1" unit="1.20 €" total="1.20 €" />
        <SketchRule dashed />
        <LineRow desc="Total" qty="" unit="" total="970.20 €" bold />
      </div>

      <div style={{ marginTop: 14, fontFamily: 'var(--hand)', fontSize: 11, color: '#7a7468' }}>
        Payment: IBAN DE…0042 · BIC … · within 14 days, ref EHX-XXXX-XXX.<br />
        <span style={{ fontStyle: 'italic' }}>Note (configurable): Kleinunternehmer per § 19 UStG — keine Umsatzsteuer ausgewiesen.</span>
      </div>
    </SketchFrame>
  );
}
function LineRow({ desc, qty, unit, total, head, bold }) {
  return (
    <div style={{ display: 'grid', gridTemplateColumns: '1fr 70px 80px 90px', gap: 8, padding: '4px 0', fontWeight: bold ? 700 : 400, color: head ? '#7a7468' : INK, borderBottom: head ? `1px solid ${INK}33` : 'none' }}>
      <span>{desc}</span><span>{qty}</span><span>{unit}</span><span style={{ textAlign: 'right' }}>{total}</span>
    </div>
  );
}

function MacB4_Finalized() {
  return (
    <MacShell title="ehrax · invoicing" accent="B · dashboard">
      <Sidebar selected="bikepark" />
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
        <div style={{ padding: '14px 26px', display: 'flex', alignItems: 'baseline', gap: 12 }}>
          <span style={{ fontFamily: 'var(--display)', fontSize: 22 }}>EHX-2026-005</span>
          <StatePill state="finalized" />
          <span style={{ fontFamily: 'var(--mono)', fontSize: 10, color: '#7a7468' }}>created just now · PDF rendered</span>
          <span style={{ flex: 1 }} />
          <SketchButton>open PDF</SketchButton>
          <SketchButton primary>mark sent</SketchButton>
        </div>
        <SketchRule style={{ margin: '0 26px' }} />
        <div style={{ flex: 1, padding: '14px 26px', overflow: 'auto' }}>
          <Annotation dir="up" style={{ marginBottom: 6 }}>snapshot locked · entries no longer editable · number assigned</Annotation>
          <DraftPreview />
        </div>
      </div>
    </MacShell>
  );
}

Object.assign(window, { MacB1_Dashboard, MacB2_ReadyBucket, MacB3_Confirm, MacB4_Finalized });
