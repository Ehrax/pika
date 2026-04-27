// Storyboard D — iPhone stacked navigation, capture-first.
// Projects → Buckets → Bucket detail → Add sheet → Done state.

function PhoneD1_Projects() {
  return (
    <PhoneFrame label="D1 · projects">
      <ScreenHeader title="Projects" right="+" />
      <div style={{ padding: '4px 14px 0' }}>
        <PhoneRow emoji="🚵" title="bikepark-thunersee" meta="3 buckets · MVP ready" tag="ready" />
        <PhoneRow emoji="⛰" title="helvetia-tools" meta="2 buckets · 1 invoice overdue" tag="overdue" />
        <PhoneRow emoji="◇" title="ehrax-internal" meta="1 bucket · idle" />
        <div style={{ height: 12 }} />
        <SectionLabel>archived</SectionLabel>
        <PhoneRow emoji="⌗" title="alpenflora-website" meta="2024 · paid" muted />
      </div>
    </PhoneFrame>
  );
}

function PhoneD2_Buckets() {
  return (
    <PhoneFrame label="D2 · buckets">
      <ScreenHeader title="🚵 bikepark" back="projects" right="+" />
      <div style={{ padding: '4px 14px 0' }}>
        <PhoneRow emoji="🛠" title="MVP" meta="11.5 h · 920 €" tag="ready" />
        <PhoneRow emoji="◐" title="Maintenance" meta="3.0 h · 240 €" />
        <PhoneRow emoji="▦" title="Customer dashboard" meta="6.5 h · 520 €" />
        <PhoneRow emoji="☷" title="Infra fixed costs" meta="2 items · 50 €" />
        <div style={{ height: 8 }} />
        <SectionLabel>invoiced</SectionLabel>
        <PhoneRow emoji="✓" title="Q1 — invoiced" meta="EHX-2026-001 · paid" tag="paid" muted />
      </div>
    </PhoneFrame>
  );
}

// D3 — bucket detail. Each entry is now a compact 2-line card:
//   line 1: time range · short title (truncated, 1 line max)
//   line 2: duration · amount (or n/b chip)
// Tapping a row pushes D3b (entry detail) where notes can run 2-3 sentences.
function PhoneD3_BucketDetail() {
  return (
    <PhoneFrame label="D3 · bucket detail">
      <ScreenHeader title="🛠 MVP" back="buckets" right="+" />
      <div style={{ padding: '4px 14px 6px', fontFamily: 'var(--hand)', fontSize: 12, color: '#7a7468', display: 'flex', justifyContent: 'space-between' }}>
        <span>rate · 80 €/h · active</span>
        <span>11.5 h · <span style={{ color: INK }}>920 €</span></span>
      </div>
      <SketchRule width="calc(100% - 28px)" style={{ margin: '0 14px' }} dashed />
      <div style={{ padding: '6px 14px 0', display: 'flex', flexDirection: 'column', gap: 4 }}>
        <div style={{ display: 'grid', gridTemplateColumns: '92px 1fr 60px', gap: 10, padding: '0 8px', margin: '0 -8px',
          fontFamily: 'var(--mono)', fontSize: 9, color: '#9b9485', textTransform: 'uppercase', letterSpacing: 0.5 }}>
          <span>time</span><span>dur</span><span style={{ textAlign: 'right' }}>amt</span>
        </div>
        <DayLabel>Today</DayLabel>
        <EntryCard time="10:00 – 12:00" dur="2.00 h" amt="160 €" tappedHint />
        <EntryCard time="14:30 – 15:00" dur="0.50 h" nb />
        <DayLabel>Yesterday</DayLabel>
        <EntryCard time="14:00 – 16:30" dur="2.50 h" amt="200 €" />
        <DayLabel>Fri 23 Apr</DayLabel>
        <EntryCard time="09:00 – 12:30" dur="3.50 h" amt="280 €" />
        <EntryCard time="13:30 – 17:00" dur="3.50 h" amt="280 €" />

        <SketchRule dashed />
        <SummaryRowMini label="Non-billable" v="0.50 h" />
        <SummaryRowMini label="Fixed costs" v="50.20 €" />
        <SummaryRowMini label="Total" v="970.20 €" bold />
      </div>
      <div style={{ position: 'absolute', bottom: 14, left: 0, right: 0, display: 'flex', justifyContent: 'center' }}>
        <SketchCircle size={48} stroke={ACCENT} strokeWidth={1.8}>
          <span style={{ fontFamily: 'var(--hand)', color: ACCENT, fontSize: 22 }}>+</span>
        </SketchCircle>
      </div>
    </PhoneFrame>
  );
}

// D3b — entry detail (tap-through). Long notes get room to breathe.
function PhoneD3b_EntryDetail() {
  return (
    <PhoneFrame label="D3b · entry detail (tap row)">
      <ScreenHeader title="Entry" back="MVP" right="⋯" />
      <div style={{ padding: '0 14px' }}>
        <div style={{ fontFamily: 'var(--mono)', fontSize: 10, color: '#7a7468', textTransform: 'uppercase' }}>Mon 26 Apr 2026 · 🛠 MVP</div>
        <div style={{ fontFamily: 'var(--display)', fontSize: 28, lineHeight: 1.1, padding: '4px 0 2px' }}>10:00 – 12:00</div>
        <div style={{ fontFamily: 'var(--hand)', fontSize: 14 }}>2.00 h · 80 €/h · <b>160 €</b></div>

        <div style={{ height: 12 }} />
        <SketchRule dashed />

        <div style={{ fontFamily: 'var(--mono)', fontSize: 10, color: '#7a7468', textTransform: 'uppercase', padding: '8px 0 4px' }}>title</div>
        <div style={{ fontFamily: 'var(--hand)', fontSize: 15, fontWeight: 700 }}>auth + token refresh</div>

        <div style={{ fontFamily: 'var(--mono)', fontSize: 10, color: '#7a7468', textTransform: 'uppercase', padding: '12px 0 4px' }}>note</div>
        <div style={{ fontFamily: 'var(--hand)', fontSize: 13, lineHeight: 1.55, color: '#3a3530' }}>
          Pulled the Keycloak refresh-token rotation across the iOS client and the admin web. Surfaced an edge case where a stale token in the keychain blocks the silent refresh on cold start — left a TODO to wire a one-time migration on next launch. Also bumped the access-token TTL to 30 min so the test bench stops nagging.
        </div>

        <div style={{ height: 12 }} />
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, fontFamily: 'var(--hand)', fontSize: 13 }}>
          <SketchCircle size={18} stroke={ACCENT_OK}>✓</SketchCircle>
          <span style={{ flex: 1 }}>billable</span>
          <span style={{ fontFamily: 'var(--mono)', fontSize: 10, color: '#7a7468' }}>tap to switch</span>
        </div>

        <div style={{ height: 12 }} />
        <div style={{ display: 'flex', gap: 8 }}>
          <SketchButton>edit times</SketchButton>
          <span style={{ flex: 1 }} />
          <SketchButton>delete</SketchButton>
        </div>
      </div>
    </PhoneFrame>
  );
}

// Single-line tabular row. Columns: time | duration | amount.
// No description in the list — that lives on D3b detail.
function EntryCard({ time, title, dur, amt, nb, tappedHint }) {
  return (
    <div style={{
      display: 'grid',
      gridTemplateColumns: '92px 1fr 60px',
      alignItems: 'baseline', gap: 10,
      padding: '7px 8px', margin: '0 -8px',
      borderBottom: `1px dashed ${INK}1f`,
      background: tappedHint ? '#fff8d622' : 'transparent',
      borderRadius: 4, position: 'relative',
      fontFamily: 'var(--hand)', fontSize: 13,
      color: nb ? '#9b9485' : INK,
    }}>
      <span style={{ fontVariantNumeric: 'tabular-nums', color: '#7a7468' }}>{time}</span>
      <span style={{ fontVariantNumeric: 'tabular-nums' }}>{dur}</span>
      <span style={{ textAlign: 'right' }}>
        {nb ? <span style={{ fontFamily: 'var(--mono)', fontSize: 10 }}>n/b</span> : amt}
      </span>
      {tappedHint ? (
        <span style={{
          position: 'absolute', right: -2, top: -8,
          fontFamily: 'var(--hand)', fontSize: 10, color: ACCENT, transform: 'rotate(-4deg)',
        }}>tap row → detail</span>
      ) : null}
    </div>
  );
}

function PhoneD4_AddSheet() {
  return (
    <PhoneFrame label="D4 · add entry">
      <div style={{ position: 'absolute', inset: 0, background: '#1f1d1b88' }} />
      <div style={{ position: 'absolute', left: 8, right: 8, bottom: 8, top: 90, background: PAPER, borderRadius: 18, padding: 16, display: 'flex', flexDirection: 'column', gap: 12 }}>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 8 }}>
          <span style={{ fontFamily: 'var(--display)', fontSize: 18 }}>New entry</span>
          <span style={{ fontFamily: 'var(--mono)', fontSize: 10, color: '#7a7468', flex: 1 }}>🛠 MVP · today · 80 €/h</span>
          <span style={{ fontFamily: 'var(--hand)', fontSize: 13, color: '#7a7468' }}>cancel</span>
        </div>
        <SketchRule dashed />

        <div style={{ display: 'flex', gap: 10 }}>
          <BigField label="from" value="10:00" focus />
          <span style={{ alignSelf: 'flex-end', paddingBottom: 8, fontFamily: 'var(--hand)', color: '#7a7468' }}>—</span>
          <BigField label="to" value="12:00" />
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', fontFamily: 'var(--hand)', fontSize: 13, color: '#7a7468' }}>
          <span>duration</span><span style={{ color: INK }}>2.00 h · 160 €</span>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
          <span style={{ fontFamily: 'var(--mono)', fontSize: 10, color: '#7a7468', textTransform: 'uppercase' }}>note (optional)</span>
          <SketchFrame radius={6} padding="8px 10px">
            <span style={{ fontFamily: 'var(--hand)', fontSize: 13, color: '#9b9485' }}>auth + token refresh</span>
          </SketchFrame>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: 10, fontFamily: 'var(--hand)', fontSize: 13 }}>
          <SketchCircle size={18} stroke={ACCENT_OK}>✓</SketchCircle>
          <span style={{ flex: 1 }}>billable</span>
          <span style={{ fontFamily: 'var(--mono)', fontSize: 10, color: '#7a7468' }}>tap to switch</span>
        </div>

        <div style={{ flex: 1 }} />
        <div style={{ display: 'flex', gap: 8 }}>
          <SketchButton>more fields</SketchButton>
          <span style={{ flex: 1 }} />
          <SketchButton primary>save</SketchButton>
        </div>

        {/* fake keyboard hint */}
        <div style={{ position: 'absolute', left: 8, right: 8, bottom: -2, height: 80, opacity: 0.6 }}>
          <SketchPlaceholder height="100%" label="number pad · time picker" />
        </div>
      </div>
    </PhoneFrame>
  );
}

function PhoneD5_Ready() {
  return (
    <PhoneFrame label="D5 · ready to invoice">
      <ScreenHeader title="🛠 MVP" back="buckets" right="⋯" />
      <div style={{ padding: '8px 14px' }}>
        <SketchFrame radius={8} padding="12px 14px" fill={PAPER_2} stroke={ACCENT_OK}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <StatePill state="ready" />
            <span style={{ flex: 1 }} />
            <span style={{ fontFamily: 'var(--mono)', fontSize: 10, color: '#7a7468' }}>11.5 h + 50.20 € fixed</span>
          </div>
          <div style={{ fontFamily: 'var(--display)', fontSize: 30, color: ACCENT_OK, lineHeight: 1.1, padding: '4px 0 8px' }}>970.20 €</div>
          <div style={{ display: 'flex', gap: 8 }}>
            <SketchButton>edit bucket</SketchButton>
            <span style={{ flex: 1 }} />
            <SketchButton primary>create invoice →</SketchButton>
          </div>
        </SketchFrame>

        <div style={{ height: 14 }} />
        <div style={{ fontFamily: 'var(--mono)', fontSize: 10, color: '#9b9485', textTransform: 'uppercase', display: 'flex', justifyContent: 'space-between' }}>
          <span>entries · still editable until finalize</span>
          <span>5</span>
        </div>
        <SketchRule dashed />
        <div style={{ display: 'grid', gridTemplateColumns: '92px 1fr 60px', gap: 10, padding: '4px 0',
          fontFamily: 'var(--mono)', fontSize: 9, color: '#9b9485', textTransform: 'uppercase', letterSpacing: 0.5 }}>
          <span>time</span><span>dur</span><span style={{ textAlign: 'right' }}>amt</span>
        </div>
        <ReadyRow time="10:00 – 12:00" dur="2.00 h" amt="160 €" />
        <ReadyRow time="14:30 – 15:00" dur="0.50 h" nb />
        <ReadyRow time="14:00 – 16:30" dur="2.50 h" amt="200 €" />
        <ReadyRow time="09:00 – 12:30" dur="3.50 h" amt="280 €" />
        <ReadyRow time="13:30 – 17:00" dur="3.50 h" amt="280 €" />
      </div>
    </PhoneFrame>
  );
}

// Same single-line tabular row as D3, no description column — just numbers.
function ReadyRow({ time, dur, amt, nb }) {
  return (
    <div style={{
      display: 'grid', gridTemplateColumns: '92px 1fr 60px', gap: 10, alignItems: 'baseline',
      padding: '6px 0', borderBottom: `1px dashed ${INK}1f`,
      fontFamily: 'var(--hand)', fontSize: 13, color: nb ? '#9b9485' : INK,
    }}>
      <span style={{ fontVariantNumeric: 'tabular-nums', color: '#7a7468' }}>{time}</span>
      <span style={{ fontVariantNumeric: 'tabular-nums' }}>{dur}</span>
      <span style={{ textAlign: 'right' }}>
        {nb ? <span style={{ fontFamily: 'var(--mono)', fontSize: 10 }}>n/b</span> : amt}
      </span>
    </div>
  );
}

// ─── Phone primitives ───────────────────────────────────────
function ScreenHeader({ title, back, right }) {
  return (
    <div style={{ padding: '4px 14px 6px', display: 'flex', alignItems: 'center', gap: 10 }}>
      {back ? <span style={{ fontFamily: 'var(--hand)', fontSize: 12, color: ACCENT }}>‹ {back}</span> : <span style={{ width: 8 }} />}
      <span style={{ fontFamily: 'var(--display)', fontSize: 22, flex: 1 }}>{title}</span>
      {right ? <SketchCircle size={22}>{right}</SketchCircle> : null}
    </div>
  );
}
function SectionLabel({ children }) {
  return <div style={{ fontFamily: 'var(--mono)', fontSize: 10, color: '#7a7468', textTransform: 'uppercase', padding: '6px 0 4px' }}>{children}</div>;
}
function PhoneRow({ emoji, title, meta, tag, muted }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '8px 0', borderBottom: `1px dashed ${INK}1f`, opacity: muted ? 0.55 : 1 }}>
      <SketchCircle size={26}>{emoji}</SketchCircle>
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column' }}>
        <span style={{ fontFamily: 'var(--hand)', fontSize: 14 }}>{title}</span>
        <span style={{ fontFamily: 'var(--mono)', fontSize: 10, color: '#7a7468' }}>{meta}</span>
      </div>
      {tag ? <StatePill state={tag} /> : <span style={{ fontFamily: 'var(--hand)', color: '#9b9485' }}>›</span>}
    </div>
  );
}
function DayLabel({ children }) {
  return <div style={{ fontFamily: 'var(--mono)', fontSize: 10, color: '#7a7468', textTransform: 'uppercase', paddingTop: 4 }}>{children}</div>;
}
function EntryLine({ t, sub, amt, muted }) {
  return (
    <div style={{ display: 'grid', gridTemplateColumns: '90px 1fr auto', gap: 8, alignItems: 'baseline', padding: '2px 0', color: muted ? '#9b9485' : INK }}>
      <span style={{ fontVariantNumeric: 'tabular-nums' }}>{t}</span>
      <span style={{ fontSize: 12 }}>{sub}</span>
      <span style={{ fontFamily: 'var(--hand)' }}>{amt}</span>
    </div>
  );
}
function SummaryRowMini({ label, v, bold }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', fontFamily: 'var(--hand)', fontSize: 12, fontWeight: bold ? 700 : 400 }}>
      <span style={{ color: '#7a7468' }}>{label}</span><span style={{ fontVariantNumeric: 'tabular-nums' }}>{v}</span>
    </div>
  );
}
function BigField({ label, value, focus }) {
  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 4 }}>
      <span style={{ fontFamily: 'var(--mono)', fontSize: 10, color: '#7a7468', textTransform: 'uppercase' }}>{label}</span>
      <span style={{ fontFamily: 'var(--display)', fontSize: 24, borderBottom: `2px solid ${focus ? ACCENT : INK + '55'}`, paddingBottom: 2 }}>{value}{focus ? <span style={{ color: ACCENT }}>|</span> : null}</span>
    </div>
  );
}

// ─────── Storyboard E — iPhone dashboard-first ───────
function PhoneE1_Today() {
  return (
    <PhoneFrame label="E1 · today">
      <ScreenHeader title="Today" right="⋯" />
      <div style={{ padding: '4px 14px 0' }}>
        <SketchFrame radius={8} padding="12px 12px" fill={PAPER_2}>
          <div style={{ fontFamily: 'var(--mono)', fontSize: 10, color: '#7a7468', textTransform: 'uppercase' }}>this month · paid</div>
          <div style={{ fontFamily: 'var(--display)', fontSize: 30, color: ACCENT_OK }}>2 480 €</div>
          <div style={{ display: 'flex', gap: 16, marginTop: 6, fontFamily: 'var(--hand)', fontSize: 12 }}>
            <span><span style={{ color: ACCENT_WARN }}>● </span>3 600 € out</span>
            <span><span style={{ color: ACCENT }}>● </span>1 100 € overdue</span>
          </div>
        </SketchFrame>

        <SectionLabel>needs you</SectionLabel>
        <PhoneRow emoji="!" title="EHX-2026-002 · helvetia" meta="overdue · +6 d" tag="overdue" />
        <PhoneRow emoji="◇" title="MVP · bikepark" meta="ready · 970 €" tag="ready" />
        <PhoneRow emoji="◇" title="helvetia Q1" meta="ready · 480 €" tag="ready" />

        <SectionLabel>recent</SectionLabel>
        <div style={{ fontFamily: 'var(--hand)', fontSize: 12, color: '#7a7468' }}>
          ·  paid · EHX-2026-004 · today<br />
          ·  +2.0 h · MVP · today<br />
          ·  rate change · MVP 80→90 · 2 d
        </div>
      </div>

      {/* Quick add FAB */}
      <div style={{ position: 'absolute', bottom: 14, right: 18 }}>
        <SketchCircle size={48} stroke={ACCENT} strokeWidth={1.8}>
          <span style={{ fontFamily: 'var(--hand)', color: ACCENT, fontSize: 22 }}>+</span>
        </SketchCircle>
      </div>
    </PhoneFrame>
  );
}

function PhoneE2_QuickAdd() {
  return (
    <PhoneFrame label="E2 · quick add (any-bucket)">
      <div style={{ position: 'absolute', inset: 0, background: '#1f1d1b88' }} />
      <div style={{ position: 'absolute', left: 8, right: 8, bottom: 8, top: 50, background: PAPER, borderRadius: 18, padding: 16, display: 'flex', flexDirection: 'column', gap: 10 }}>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 8 }}>
          <span style={{ fontFamily: 'var(--display)', fontSize: 18 }}>Quick add</span>
          <span style={{ flex: 1 }} />
          <span style={{ fontFamily: 'var(--hand)', fontSize: 13, color: '#7a7468' }}>cancel</span>
        </div>
        <SketchRule dashed />

        <span style={{ fontFamily: 'var(--mono)', fontSize: 10, color: '#7a7468', textTransform: 'uppercase' }}>bucket</span>
        <SketchFrame radius={6} padding="8px 10px">
          <span style={{ fontFamily: 'var(--hand)', fontSize: 14 }}>🛠 MVP · bikepark-thunersee</span>
        </SketchFrame>
        <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
          {['🛠 MVP', '◐ Maintenance', '▦ Dashboard', '⛰ helvetia ▾'].map((b, i) => (
            <span key={i} style={{ position: 'relative', padding: '3px 10px', fontFamily: 'var(--hand)', fontSize: 11 }}>
              <SketchBox width="100%" height="100%" radius={20} stroke={i === 0 ? ACCENT : INK + '55'} style={{ position: 'absolute', inset: 0 }} />
              <span style={{ position: 'relative', color: i === 0 ? ACCENT : INK }}>{b}</span>
            </span>
          ))}
        </div>

        <div style={{ display: 'flex', gap: 10, marginTop: 4 }}>
          <BigField label="from" value="10:00" focus />
          <span style={{ alignSelf: 'flex-end', paddingBottom: 8, color: '#7a7468' }}>—</span>
          <BigField label="to" value="12:00" />
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', fontFamily: 'var(--hand)', fontSize: 13, color: '#7a7468' }}>
          <span>2.00 h · 80 €/h</span><span style={{ color: INK }}>160 €</span>
        </div>

        <div style={{ flex: 1 }} />
        <SketchButton primary>save & add another</SketchButton>
      </div>
    </PhoneFrame>
  );
}

function PhoneE3_InvoiceTap() {
  return (
    <PhoneFrame label="E3 · overdue · tap to act">
      <ScreenHeader title="EHX-2026-002" back="today" />
      <div style={{ padding: '0 14px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '4px 0' }}>
          <StatePill state="overdue" />
          <span style={{ fontFamily: 'var(--hand)', fontSize: 12, color: ACCENT }}>+6 d · due 20 Apr</span>
        </div>
        <div style={{ fontFamily: 'var(--display)', fontSize: 30, padding: '4px 0' }}>1 100.00 €</div>
        <div style={{ fontFamily: 'var(--mono)', fontSize: 10, color: '#7a7468', textTransform: 'uppercase' }}>helvetia-tools GmbH</div>

        <div style={{ height: 10 }} />
        <SketchRule dashed />

        <SectionLabel>lines · snapshot</SectionLabel>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 60px', gap: 10, alignItems: 'baseline',
          padding: '6px 0', borderBottom: `1px dashed ${INK}1f`, fontFamily: 'var(--hand)', fontSize: 13 }}>
          <span>Maintenance · 13.75 h × 80</span>
          <span style={{ textAlign: 'right' }}>1 100 €</span>
        </div>
        <div style={{ fontFamily: 'var(--mono)', fontSize: 10, color: '#7a7468', padding: '6px 0' }}>
          note · Kleinunternehmer · § 19 UStG
        </div>

        <div style={{ height: 12 }} />
        <div style={{ display: 'flex', gap: 8, flexDirection: 'column' }}>
          <SketchButton primary>mark paid</SketchButton>
          <SketchButton>send reminder · email</SketchButton>
          <SketchButton>open PDF</SketchButton>
        </div>
      </div>
    </PhoneFrame>
  );
}

Object.assign(window, {
  PhoneD1_Projects, PhoneD2_Buckets, PhoneD3_BucketDetail, PhoneD3b_EntryDetail, PhoneD4_AddSheet, PhoneD5_Ready,
  PhoneE1_Today, PhoneE2_QuickAdd, PhoneE3_InvoiceTap,
});
