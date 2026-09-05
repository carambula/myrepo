import React, { useState, useRef, useEffect, useCallback } from 'react';
import { colors } from '../../design-system/src/tokens/colors.js';
import { spacing } from '../../design-system/src/tokens/spacing.js';
import { typography } from '../../design-system/src/tokens/typography.js';
import { shadows } from '../../design-system/src/tokens/shadows.js';
import { borders } from '../../design-system/src/tokens/borders.js';
import { lightTheme } from '../../design-system/src/themes/lightTheme.js';
import { darkTheme } from '../../design-system/src/themes/darkTheme.js';
import './studio.css';
import './swiftui-primitives.css';

const APPS = [
  { id: 'watchedit', name: 'WatchedIt', label: 'mov min', color: colors.primary[500], content: 'Movies', detail: 'Movie Detail', listItem: 'The Shawshank Redemption', subtitle: '1994   Drama' },
  { id: 'podlink', name: 'podlink', label: 'pod min', color: colors.secondary[500], content: 'Podcasts', detail: 'Show Detail', listItem: 'The Daily', subtitle: 'The New York Times   News' },
  { id: 'yourtube', name: 'yourtube', label: 'vid min', color: colors.error[500], content: 'Videos', detail: 'Channel Detail', listItem: 'How Things Work', subtitle: '2.3M views   3 days ago' },
  { id: 'cyclismo', name: 'Cyclismo guide', label: 'cyc min', color: colors.success[500], content: 'Races', detail: 'Race Detail', listItem: 'Tour de France 2026', subtitle: 'Jul 4 – Jul 26   Grand Tour' },
];

const TABS = ['Inspector', 'Colors', 'Spacing', 'Typography', 'Shadows', 'Components', 'Layouts', 'Themes', 'Patterns', 'Apps'];

// ── Utility: render descriptor components as React elements ──
function Descriptor({ desc, theme = 'dark' }) {
  if (!desc) return null;
  if (typeof desc === 'string') return desc;
  if (Array.isArray(desc)) return desc.map((d, i) => <Descriptor key={i} desc={d} theme={theme} />);
  const { element: El = 'div', style, children, className, innerHTML, ...rest } = desc;
  const clean = style
    ? Object.fromEntries(
        style.split(';')
          .map(s => s.trim())
          .filter(s => s && !s.startsWith('&') && !s.startsWith('//'))
          .map(s => {
            const [prop, ...vals] = s.split(':');
            const camel = prop.trim().replace(/-([a-z])/g, (_, c) => c.toUpperCase());
            return [camel, vals.join(':').trim()];
          })
          .filter(([k, v]) => k && v)
      )
    : {};
  if (innerHTML) return <El className={className} style={clean} dangerouslySetInnerHTML={{ __html: innerHTML }} {...rest} />;
  return <El className={className} style={clean} {...rest}>{children && <Descriptor desc={children} theme={theme} />}</El>;
}

// ── Colors Panel ──
function ColorSwatch({ name, value }) {
  if (typeof value === 'object') {
    return (
      <div className="swatch-group">
        <h4 className="swatch-group-title">{name}</h4>
        <div className="swatch-row">
          {Object.entries(value).map(([k, v]) => <ColorSwatch key={k} name={k} value={v} />)}
        </div>
      </div>
    );
  }
  return (
    <div className="swatch" title={`${name}: ${value}`}>
      <div className="swatch-color" style={{ background: value }} />
      <span className="swatch-label">{name}</span>
      <span className="swatch-value">{value}</span>
    </div>
  );
}

function ColorsPanel() {
  return (
    <div className="panel">
      <h2 className="panel-title">Color Tokens</h2>
      <p className="panel-desc">Base palette shared across all min apps and themes.</p>
      {Object.entries(colors).map(([name, value]) => <ColorSwatch key={name} name={name} value={value} />)}
    </div>
  );
}

// ── Spacing Panel ──
function SpacingPanel() {
  const scale = Object.entries(spacing).filter(([k]) => !isNaN(k));
  const semantic = Object.entries(spacing).filter(([k]) => isNaN(k) && k !== 'unit');
  return (
    <div className="panel">
      <h2 className="panel-title">Spacing Tokens</h2>
      <p className="panel-desc">Base unit: {spacing.unit}px</p>
      <h3 className="section-title">Scale</h3>
      <div className="spacing-scale">
        {scale.map(([k, v]) => (
          <div key={k} className="spacing-item">
            <span className="spacing-key">{k}</span>
            <div className="spacing-bar" style={{ width: v === '0' ? 2 : parseInt(v), minWidth: 2 }} />
            <span className="spacing-value">{v}</span>
          </div>
        ))}
      </div>
      {semantic.map(([group, values]) => (
        <div key={group}>
          <h3 className="section-title">{group}</h3>
          <table className="token-table"><thead><tr><th>Token</th><th>Value</th><th></th></tr></thead><tbody>
            {Object.entries(values).map(([k, v]) => (
              <tr key={k}><td><code>spacing.{group}.{k}</code></td><td className="mono">{v}</td><td><div className="spacing-bar-sm" style={{ width: parseInt(v) || 0 }} /></td></tr>
            ))}
          </tbody></table>
        </div>
      ))}
    </div>
  );
}

// ── Typography Panel ──
function TypographyPanel() {
  return (
    <div className="panel">
      <h2 className="panel-title">Typography Tokens</h2>
      <h3 className="section-title">Font Sizes</h3>
      <div className="type-sizes">
        {Object.entries(typography.sizes).map(([name, size]) => (
          <div key={name} className="type-size-row">
            <span className="type-size-label">{name} <span className="mono dim">{size}</span></span>
            <span style={{ fontSize: size, lineHeight: 1.2 }}>Design System</span>
          </div>
        ))}
      </div>
      <h3 className="section-title">Font Weights</h3>
      <div className="type-weights">
        {Object.entries(typography.weights).map(([name, weight]) => (
          <div key={name} className="type-weight-row">
            <span className="type-label">{name} ({weight})</span>
            <span style={{ fontWeight: weight, fontSize: 18 }}>Min Apps Design System</span>
          </div>
        ))}
      </div>
      <h3 className="section-title">Text Styles</h3>
      <div className="type-styles">
        {Object.entries(typography.styles).map(([name, style]) => (
          <div key={name} className="type-style-row">
            <div className="type-style-meta">
              <span className="type-label">{name}</span>
              <span className="mono dim">{style.fontSize} / {style.fontWeight} / {style.lineHeight}</span>
            </div>
            <span style={{ fontSize: style.fontSize, fontWeight: style.fontWeight, lineHeight: style.lineHeight, letterSpacing: style.letterSpacing || 'normal', textTransform: style.textTransform || 'none' }}>
              {name === 'mainContentTitle' ? 'Movies' : 'The quick brown fox'}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}

// ── Shadows Panel ──
function ShadowsPanel() {
  return (
    <div className="panel">
      <h2 className="panel-title">Shadows & Borders</h2>
      <h3 className="section-title">Shadows</h3>
      <div className="shadow-grid">
        {Object.entries(shadows).map(([name, value]) => (
          <div key={name} className="shadow-card" style={{ boxShadow: value }}><span className="shadow-name">{name}</span></div>
        ))}
      </div>
      <h3 className="section-title">Border Radii</h3>
      <div className="radii-grid">
        {Object.entries(borders.radii).map(([name, value]) => (
          <div key={name} className="radius-card">
            <div className="radius-preview" style={{ borderRadius: value }} />
            <span className="radius-name">{name}</span><span className="mono dim">{value}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

// ── Components Panel ──
function ComponentPreview({ title, desc, children }) {
  return (
    <div className="comp-preview">
      <div className="comp-preview-header"><h4>{title}</h4><span className="mono dim">{desc}</span></div>
      <div className="comp-preview-body">{children}</div>
    </div>
  );
}

function ComponentsPanel() {
  return (
    <div className="panel">
      <h2 className="panel-title">Components</h2>
      <p className="panel-desc">Shared UI components used across all 4 min apps. Descriptor-style components return style objects; React components render JSX.</p>

      <ComponentPreview title="Button" desc="5 variants × 3 sizes">
        <div className="comp-row">
          {['primary', 'secondary', 'outline', 'ghost', 'text'].map(v => (
            <button key={v} className={`ds-btn ds-btn--${v}`}>{v}</button>
          ))}
        </div>
        <div className="comp-row" style={{ marginTop: 12 }}>
          {['small', 'medium', 'large'].map(s => (
            <button key={s} className={`ds-btn ds-btn--primary ds-btn--${s}`}>{s}</button>
          ))}
        </div>
      </ComponentPreview>

      <ComponentPreview title="Card" desc="Elevation: none → small → medium → large">
        <div className="comp-row">
          {['none', 'small', 'medium', 'large'].map(e => (
            <div key={e} className="ds-card" style={{ boxShadow: { none: 'none', small: shadows.sm, medium: shadows.card, large: shadows.lg }[e] }}>
              <span style={{ fontWeight: 600 }}>{e}</span>
              <span className="dim" style={{ fontSize: 13 }}>Card content here</span>
            </div>
          ))}
        </div>
      </ComponentPreview>

      <ComponentPreview title="ListItem" desc="Used in all 4 apps for feed/list views">
        <div className="ds-list">
          {APPS.map(app => (
            <div key={app.id} className="ds-list-item">
              <div className="ds-list-item__art" style={{ background: app.color }} />
              <div className="ds-list-item__content">
                <span className="ds-list-item__title">{app.listItem}</span>
                <span className="ds-list-item__subtitle">{app.subtitle}</span>
              </div>
              <span className="ds-list-item__action">›</span>
            </div>
          ))}
        </div>
      </ComponentPreview>

      <ComponentPreview title="AppHeader" desc="Consistent header across all min apps">
        <div className="ds-header">
          <div className="ds-header__logo" />
          <span className="ds-header__title">WatchedIt</span>
          <div className="ds-header__actions">
            <button className="ds-btn ds-btn--ghost ds-btn--small">⚙</button>
          </div>
        </div>
      </ComponentPreview>

      <ComponentPreview title="MainContentTitle" desc="Primary page title — same size in all apps">
        <div style={{ padding: '16px 0' }}>
          {APPS.map(app => (
            <div key={app.id} style={{ fontSize: typography.styles.mainContentTitle.fontSize, fontWeight: typography.styles.mainContentTitle.fontWeight, lineHeight: typography.styles.mainContentTitle.lineHeight, letterSpacing: typography.styles.mainContentTitle.letterSpacing, color: '#fff', marginBottom: 8 }}>
              {app.content}
            </div>
          ))}
        </div>
      </ComponentPreview>

      <ComponentPreview title="DismissButton" desc="Fixed floating dismiss — scroll-linked visibility">
        <div style={{ position: 'relative', height: 80, background: '#1a1a1a', borderRadius: 8 }}>
          <div className="ds-dismiss-btn"><span>✕</span> Dismiss</div>
        </div>
      </ComponentPreview>

      <ComponentPreview title="BottomSheet" desc="3 detents: small → medium → large, with backdrop blur">
        <div className="ds-bottomsheet-demo">
          <div className="ds-bottomsheet-backdrop" />
          <div className="ds-bottomsheet">
            <div className="ds-bottomsheet__handle" />
            <div style={{ padding: '0 16px' }}>
              <h4 style={{ marginBottom: 8 }}>Sheet Content</h4>
              <p className="dim" style={{ fontSize: 14 }}>Backdrop blur + darkening intensifies by detent.</p>
            </div>
          </div>
        </div>
      </ComponentPreview>

      <ComponentPreview title="LoadingState / MainAppLoading" desc="Consistent loading across all apps">
        <div className="ds-loading">
          <div className="ds-spinner" />
          <span>Loading…</span>
        </div>
      </ComponentPreview>

      <h3 className="section-title" style={{ marginTop: 32 }}>MinAppKit Shared Components (Swift)</h3>
      <p className="panel-desc">Native SwiftUI components in MinAppKit consumed by all 4 apps via local SPM package.</p>

      <ComponentPreview title="OnboardingPagerView" desc="Shared paged TabView shell">
        <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
          <div style={{ display: 'flex', gap: 6 }}>
            {[0, 1, 2, 3].map(i => (
              <div key={i} style={{ width: i === 0 ? 10 : 8, height: i === 0 ? 10 : 8, borderRadius: '50%', background: i === 0 ? '#2563eb' : '#555' }} />
            ))}
          </div>
          <span className="dim" style={{ fontSize: 13 }}>Page dots + advance/complete callbacks. Used by PodLink, YourTube, Cyclismo.</span>
        </div>
      </ComponentPreview>

      <ComponentPreview title="SettingsSheet" desc="Grouped list + Done toolbar chrome">
        <div style={{ background: '#1a1a1a', borderRadius: 8, padding: 12 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
            <span style={{ fontWeight: 600, fontSize: 15 }}>Notifications</span>
            <span style={{ color: '#2563eb', fontSize: 13, fontWeight: 600 }}>✓ Done</span>
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 0', borderBottom: '1px solid #333' }}>
            <span style={{ fontSize: 13 }}>Morning Summary</span>
            <div style={{ width: 36, height: 20, borderRadius: 10, background: '#2563eb' }} />
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 0' }}>
            <span style={{ fontSize: 13 }}>Priority Alerts</span>
            <div style={{ width: 36, height: 20, borderRadius: 10, background: '#444' }} />
          </div>
        </div>
      </ComponentPreview>

      <ComponentPreview title="PullToDismissEngine" desc="Scroll introspection + overscroll state machine">
        <div style={{ background: '#1a1a1a', borderRadius: 8, padding: 12, position: 'relative', minHeight: 60 }}>
          <span className="dim" style={{ fontSize: 13 }}>ScrollObserver (KVO) → Introspector (BFS) → Engine (thresholds + haptics) → per-app close button</span>
          <div style={{ position: 'absolute', bottom: 8, left: 12 }}>
            <div style={{ width: 40, height: 40, borderRadius: '50%', background: 'rgba(255,255,255,0.1)', border: '1px solid rgba(255,255,255,0.2)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 16 }}>✕</div>
          </div>
        </div>
      </ComponentPreview>

      <ComponentPreview title="CodablePreference" desc="Protocol for JSON-in-UserDefaults persistence">
        <div style={{ fontFamily: 'monospace', fontSize: 12, color: '#a5b4fc', lineHeight: 1.6 }}>
          <div><span style={{ color: '#c084fc' }}>protocol</span> CodablePreference: Codable {'{'}</div>
          <div style={{ paddingLeft: 16 }}><span style={{ color: '#86efac' }}>static var</span> storageKey: String {'{ get }'}</div>
          <div style={{ paddingLeft: 16 }}><span style={{ color: '#86efac' }}>func</span> load() → Self</div>
          <div style={{ paddingLeft: 16 }}><span style={{ color: '#86efac' }}>func</span> save()</div>
          <div>{'}'}</div>
        </div>
      </ComponentPreview>

      <ComponentPreview title="NavigationSearchPlacement" desc="Shared search bar position enum">
        <div style={{ display: 'flex', gap: 12 }}>
          {['topLeading', 'bottomTrailing'].map(v => (
            <div key={v} style={{ padding: '6px 12px', borderRadius: 6, background: v === 'topLeading' ? '#2563eb' : '#333', fontSize: 13 }}>{v}</div>
          ))}
          <span className="dim" style={{ fontSize: 12, alignSelf: 'center' }}>PodLink + YourTube</span>
        </div>
      </ComponentPreview>

      <ComponentPreview title="MinTheme Protocol" desc="Shared theme base for WatchedIt + Cyclismo">
        <div style={{ fontFamily: 'monospace', fontSize: 12, color: '#a5b4fc', lineHeight: 1.6 }}>
          <div><span style={{ color: '#c084fc' }}>protocol</span> MinTheme {'{'} name, accent, headlineFont, bodyFont, backgrounds, headlineColors… {'}'}</div>
          <div style={{ color: '#86efac', marginTop: 4 }}>+ ThemeColorData, ThemeFontStyle, CustomThemeDefinition, ThemeAdaptedPalette (.from(highlight:)), UIColor extensions</div>
        </div>
      </ComponentPreview>
    </div>
  );
}

// ── Layouts Panel ──
function LayoutsPanel() {
  return (
    <div className="panel">
      <h2 className="panel-title">Layouts & Templates</h2>
      <p className="panel-desc">Standardized page structures. Every min app uses these patterns for consistency.</p>

      <ComponentPreview title="AppLayout" desc="Main app shell — header + scrollable main + footer">
        <div className="ds-layout-demo">
          <div className="ds-layout-header">AppHeader</div>
          <div className="ds-layout-main">
            <div className="ds-layout-margin-indicator">
              <span>←{spacing.page.marginLeft}→</span>
              <div className="ds-layout-content">
                <div style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Movies</div>
                <div className="ds-layout-placeholder" />
                <div className="ds-layout-placeholder short" />
              </div>
              <span>←{spacing.page.marginLeft}→</span>
            </div>
          </div>
        </div>
      </ComponentPreview>

      <ComponentPreview title="HomeLayout" desc="Centered home screen with logo + title">
        <div className="ds-home-demo">
          <div className="ds-home-logo" />
          <div style={{ fontSize: 24, fontWeight: 700, textAlign: 'center' }}>WatchedIt</div>
          <div style={{ fontSize: 14, color: '#888', textAlign: 'center', marginBottom: 16 }}>Your movie collection</div>
          <button className="ds-btn ds-btn--primary">Get Started</button>
        </div>
      </ComponentPreview>

      <ComponentPreview title="List → Detail" desc="Universal navigation pattern across all 4 apps">
        <div className="ds-flow-demo">
          <div className="ds-flow-screen">
            <div style={{ fontSize: 14, fontWeight: 700, marginBottom: 8, color: '#fff' }}>List View</div>
            {APPS.slice(0, 3).map(app => (
              <div key={app.id} className="ds-flow-row"><div className="ds-flow-art" style={{ background: app.color }} /><div><div style={{ fontSize: 11, fontWeight: 600 }}>{app.listItem}</div><div className="dim" style={{ fontSize: 10 }}>{app.subtitle}</div></div></div>
            ))}
          </div>
          <span style={{ fontSize: 24, color: '#555' }}>→</span>
          <div className="ds-flow-screen">
            <div style={{ fontSize: 14, fontWeight: 700, marginBottom: 8, color: '#fff' }}>Detail View</div>
            <div className="ds-flow-hero" style={{ background: APPS[0].color }} />
            <div style={{ fontSize: 16, fontWeight: 700 }}>{APPS[0].listItem}</div>
            <div className="dim" style={{ fontSize: 11 }}>{APPS[0].subtitle}</div>
          </div>
        </div>
      </ComponentPreview>

      <ComponentPreview title="ContentContainer" desc="Centered max-width: small (640) → default (960) → large (1400)">
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {[['small', 640], ['default', 960], ['large', 1400]].map(([name, w]) => (
            <div key={name} style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
              <span className="mono dim" style={{ width: 60, fontSize: 12 }}>{name}</span>
              <div style={{ height: 16, width: `${(w / 1400) * 100}%`, background: '#2563eb', borderRadius: 4, minWidth: 20 }} />
              <span className="mono dim" style={{ fontSize: 11 }}>{w}px</span>
            </div>
          ))}
        </div>
      </ComponentPreview>

      <ComponentPreview title="Grid / Stack / List" desc="Flexible layout primitives">
        <div style={{ display: 'flex', gap: 16 }}>
          <div>
            <span className="mono dim" style={{ fontSize: 11 }}>Grid (3 cols)</span>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 6, marginTop: 6 }}>
              {Array.from({ length: 6 }).map((_, i) => <div key={i} style={{ height: 32, background: '#1e293b', borderRadius: 4 }} />)}
            </div>
          </div>
          <div>
            <span className="mono dim" style={{ fontSize: 11 }}>Stack (vertical)</span>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 6, marginTop: 6 }}>
              {Array.from({ length: 3 }).map((_, i) => <div key={i} style={{ height: 24, width: 80, background: '#1e293b', borderRadius: 4 }} />)}
            </div>
          </div>
          <div>
            <span className="mono dim" style={{ fontSize: 11 }}>Stack (horizontal)</span>
            <div style={{ display: 'flex', gap: 6, marginTop: 6 }}>
              {Array.from({ length: 3 }).map((_, i) => <div key={i} style={{ height: 40, width: 40, background: '#1e293b', borderRadius: 4 }} />)}
            </div>
          </div>
        </div>
      </ComponentPreview>
    </div>
  );
}

// ── Themes Panel ──
function ThemeCard({ theme }) {
  const c = theme.colors;
  return (
    <div className="theme-card" style={{ background: c.background.primary, color: c.text.primary, borderColor: c.border.primary }}>
      <h4 style={{ color: c.text.primary, marginBottom: 12 }}>{theme.name} theme</h4>
      {['background', 'surface'].map(group => (
        <div key={group} className="theme-section">
          <span className="theme-section-label" style={{ color: c.text.secondary }}>{group}</span>
          <div className="theme-swatches">{Object.entries(c[group]).map(([k, v]) => <div key={k} className="theme-swatch" style={{ background: v }} title={`${group}.${k}: ${v}`}><span style={{ color: c.text.primary, fontSize: 10 }}>{k}</span></div>)}</div>
        </div>
      ))}
      <div className="theme-section">
        <span className="theme-section-label" style={{ color: c.text.secondary }}>Text</span>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>{Object.entries(c.text).map(([k, v]) => <span key={k} style={{ color: v, fontSize: 13 }}>text.{k}</span>)}</div>
      </div>
      <div className="theme-section">
        <span className="theme-section-label" style={{ color: c.text.secondary }}>Brand + Semantic</span>
        <div className="theme-swatches">{['primary', 'secondary', 'accent', 'success', 'error', 'warning', 'info'].map(s => <div key={s} className="theme-swatch" style={{ background: c[s].main }} title={`${s}.main`}><span style={{ color: c[s].contrast, fontSize: 9 }}>{s}</span></div>)}</div>
      </div>
    </div>
  );
}

function ThemesPanel() {
  return (
    <div className="panel">
      <h2 className="panel-title">Themes</h2>
      <p className="panel-desc">Interchangeable across all 4 apps. Edit once, applies everywhere.</p>
      <div className="themes-grid"><ThemeCard theme={lightTheme} /><ThemeCard theme={darkTheme} /></div>
    </div>
  );
}

// ── Patterns Panel (cross-app) ──
function PatternsPanel() {
  const patterns = [
    { name: 'Scroll-Dismiss Button', where: 'All 4 apps', desc: 'Floating button that appears/hides based on scroll position, with configurable material and border. Single implementation in MinAppKit.', dsFile: 'DismissButton + useScrollDismiss', swift: 'MinAppKit/ScrollDismissButton.swift (shared)', status: 'unified' },
    { name: 'Scroll Offset Tracking', where: 'All 4 apps', desc: 'PreferenceKey + View extension for tracking scroll position in ScrollViews. Single implementation in MinAppKit.', dsFile: '—', swift: 'MinAppKit/ScrollOffset.swift (shared)', status: 'unified' },
    { name: 'Bottom Sheet / Pull-to-Dismiss', where: 'WatchedIt, PodLink, Cyclismo', desc: 'Shared pull-to-dismiss engine (ScrollObserver + Introspector + state machine + haptics) in MinAppKit. Each app provides its own close button styling. YourTube keeps its SwiftUI DragGesture implementation.', dsFile: 'BottomSheet.js + BottomSheet.css', swift: 'MinAppKit/PullToDismiss/ (shared engine) → per-app close button', status: 'unified' },
    { name: 'Cached Async Image', where: 'All 4 apps', desc: 'Remote image loading with memory + disk cache, blur-up animation, and sync cache hits. Shared implementation in MinAppKit with configurable fade/blur.', dsFile: '—', swift: 'MinAppKit/CachedAsyncImage.swift + ImageCache.swift (shared)', status: 'unified' },
    { name: 'MainContentTitle', where: 'All 4 apps', desc: `Primary page heading: ${typography.styles.mainContentTitle.fontSize} / weight ${typography.styles.mainContentTitle.fontWeight}. Must be identical everywhere.`, dsFile: 'MainContentTitle.js + .native.js', swift: 'MinMainContentTitleView (generated)', status: 'unified' },
    { name: 'Page Margins / Grid', where: 'All 4 apps', desc: `Desktop: ${spacing.page.marginLeft}/${spacing.page.marginRight}. Mobile: ${spacing.page.marginLeftMobile}/${spacing.page.marginRightMobile}. Generated native constants.`, dsFile: 'spacing.js → build-native-tokens', swift: 'MinPageMargins.swift (generated)', status: 'unified' },
    { name: 'MainAppLoading', where: 'All 4 apps', desc: 'Initial loading state shown while data bootstraps. Spinner + label, same appearance everywhere.', dsFile: 'MainAppLoading.js + .native.js', swift: 'MinMainAppLoadingView (generated)', status: 'unified' },
    { name: 'Design Tokens (Spacing, CornerRadius, Opacity)', where: 'All 4 apps', desc: 'Shared token values via MinAppKit (MinSpacing, MinCornerRadius, MinOpacity, MinShadow, MinAnimation, MinIcon). Each app delegates to MinAppKit as single source of truth.', dsFile: 'tokens/ (spacing, shadows, borders)', swift: 'MinAppKit/Tokens/ (shared) → DesignSystem.swift delegates', status: 'unified' },
    { name: 'Frosted Surface + Card Modifiers', where: 'All 4 apps', desc: 'Shared View modifiers for glass surfaces and card elevation. Single implementation in MinAppKit.', dsFile: '—', swift: 'MinAppKit/ViewSurface.swift (shared)', status: 'unified' },
    { name: 'ThemeManager', where: 'All 4 apps', desc: 'All 4 apps conform to MinTheme. WatchedIt uses typealias, Cyclismo extends with duotone, PodLink and YourTube bridge via AppTheme. Shared: MinTheme protocol, ThemeColorData, ThemeFontStyle, CustomThemeDefinition, CustomTheme, ThemeAdaptedPalette (with shared palette generator), ThemeFontResolver, UIColor extensions.', dsFile: 'themes/ (light + dark)', swift: 'MinAppKit/Theme/ (shared base) → ThemeManager.swift (per-app managers)', status: 'unified' },
    { name: 'Onboarding Flow', where: 'PodLink, YourTube, Cyclismo', desc: 'Shared OnboardingPagerView (paged TabView + page dots + completion binding) in MinAppKit. Each app provides its own step content. WatchedIt uses a different model.', dsFile: 'OnboardingContainer + per-app configs', swift: 'MinAppKit/OnboardingPagerView.swift (shared) → per-app content', status: 'unified' },
    { name: 'Notification Preferences', where: 'All 4 apps', desc: 'Shared CodablePreference protocol (load/save) and SettingsSheet chrome (grouped list + Done toolbar) in MinAppKit. Each app defines its own preference fields and sections.', dsFile: 'NotificationSettingsPage + per-app settings', swift: 'MinAppKit/CodablePreference.swift + SettingsSheet.swift (shared) → per-app fields', status: 'unified' },
    { name: 'Search Placement', where: 'PodLink, YourTube', desc: 'Shared NavigationSearchPlacement enum in MinAppKit. Each app provides its own display labels and persistence.', dsFile: '—', swift: 'MinAppKit/NavigationSearchPlacement.swift (shared)', status: 'unified' },
    { name: 'Art Tile Radius', where: 'All 4 apps', desc: `Poster/artwork corner radius: ${borders.radii.artTile}. Single source of truth via MinCornerRadius.artTile.`, dsFile: 'borders.radii.artTile', swift: 'MinAppKit/MinCornerRadius.artTile (shared)', status: 'unified' },
    { name: 'Deep Linking', where: 'All 4 apps', desc: 'Shared URL.queryValue(for:) extension in MinAppKit. Each app keeps its own scheme/route parsing since routes are app-specific.', dsFile: 'deepLinking/ (components + logic)', swift: 'MinAppKit/URLDeepLink.swift (shared helper) → per-app DeepLinkHandler', status: 'unified' },
  ];

  return (
    <div className="panel">
      <h2 className="panel-title">Cross-App Patterns</h2>
      <p className="panel-desc">Patterns shared across the 4 min apps. Green = unified in the design system. Yellow = partially shared. Red = duplicated across apps.</p>

      <div className="pattern-grid">
        {patterns.map(p => (
          <div key={p.name} className="pattern-card">
            <div className="pattern-card-top">
              <span className={`pattern-status pattern-status--${p.status.replace(' ', '-')}`}>
                {p.status === 'unified' ? '●' : p.status === 'duplicated' ? '●' : '◐'} {p.status}
              </span>
            </div>
            <h4 className="pattern-name">{p.name}</h4>
            <p className="pattern-desc">{p.desc}</p>
            <div className="pattern-meta">
              <div><span className="pattern-meta-label">Apps:</span> {p.where}</div>
              <div><span className="pattern-meta-label">DS:</span> <code>{p.dsFile}</code></div>
              <div><span className="pattern-meta-label">Swift:</span> {p.swift}</div>
            </div>
          </div>
        ))}
      </div>

      <h3 className="section-title" style={{ marginTop: 32 }}>Templates (integration-tools)</h3>
      <p className="panel-desc">Pre-built page compositions that each app should follow:</p>
      <div className="template-grid">
        {[
          { name: 'app-init', desc: 'Boot sequence: initTheme → global CSS → MainAppLoading → lazy App', maps: 'App entry point in all 4 apps' },
          { name: 'home-layout', desc: 'HomeLayout + logo + title + theme toggle + Get Started', maps: 'Onboarding / landing in each app' },
          { name: 'list-view', desc: 'AppLayout + AppHeader + sticky search + List/ListItem + loading gate', maps: 'CollectionsHomeView, RaceListView, PodcastListView, SubscriptionsFeedView' },
          { name: 'detail-view', desc: 'Hero image + metadata + actions + AppHeader + MainAppLoading', maps: 'MovieDetailView, RaceDetailView, PodcastDetailView, VideoDetailView' },
          { name: 'podcast-show-view', desc: 'Show artwork + episode list + DismissButton + useScrollDismiss', maps: 'PodcastDetailView, ChannelDetailView' },
          { name: 'episode-list-view', desc: 'Episode rows: tap row = navigate, tap play = toggle playback', maps: 'Episode lists in PodLink and YourTube' },
        ].map(t => (
          <div key={t.name} className="template-card">
            <h4><code>{t.name}</code></h4>
            <p>{t.desc}</p>
            <span className="dim" style={{ fontSize: 12 }}>↳ {t.maps}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

// ── Apps Panel ──
function AppsPanel() {
  return (
    <div className="panel">
      <h2 className="panel-title">App Family</h2>
      <p className="panel-desc">All 4 min apps consume this design system. Changes here propagate everywhere.</p>
      <div className="apps-grid">
        {APPS.map(app => (
          <div key={app.id} className="app-card">
            <div className="app-card-accent" style={{ background: app.color }} />
            <div className="app-card-body">
              <h3 className="app-card-name">{app.name}</h3>
              <span className="app-card-label">{app.label}</span>
              <div className="app-card-stack">
                <div className="app-card-chip">Swift / Xcode</div>
                <div className="app-card-chip">SwiftUI</div>
                <div className="app-card-chip">Native tokens</div>
              </div>
            </div>
          </div>
        ))}
      </div>

      <h3 className="section-title" style={{ marginTop: 32 }}>Shared Token Impact</h3>
      <table className="token-table"><thead><tr><th>Token</th><th>Current</th><th>Affects</th></tr></thead><tbody>
        <tr><td><code>spacing.page.marginLeft</code></td><td className="mono">{spacing.page.marginLeft}</td><td>All app page margins (web + native via build)</td></tr>
        <tr><td><code>spacing.page.marginLeftMobile</code></td><td className="mono">{spacing.page.marginLeftMobile}</td><td>Mobile page margins (12pt on phones)</td></tr>
        <tr><td><code>colors.primary.500</code></td><td className="mono">{colors.primary[500]}</td><td>Primary accent in light theme</td></tr>
        <tr><td><code>typography.styles.mainContentTitle</code></td><td className="mono">{typography.styles.mainContentTitle.fontSize} / {typography.styles.mainContentTitle.fontWeight}</td><td>Main screen title in all apps</td></tr>
        <tr><td><code>borders.radii.artTile</code></td><td className="mono">{borders.radii.artTile}</td><td>Poster/artwork corner radius everywhere</td></tr>
        <tr><td><code>shadows.card</code></td><td className="mono">{shadows.card}</td><td>Card elevation in list views</td></tr>
      </tbody></table>

      <h3 className="section-title" style={{ marginTop: 32 }}>Native Build Pipeline</h3>
      <p className="panel-desc">
        <code>npm run build</code> runs <code>build-native-tokens.js</code> which reads token JS files and generates:
      </p>
      <div className="native-grid">
        {[
          { file: 'MinPageMargins.swift', from: 'spacing.page' },
          { file: 'MinPageInsets.swift', from: 'spacing.page (+ size classes)' },
          { file: 'MinMainAppLoading.swift', from: 'mainLoading tokens' },
          { file: 'MinTitleTypography.swift', from: 'minTitles tokens' },
          { file: 'MinAppLayout.swift', from: 'spacing.page + layout patterns' },
          { file: 'MinAppHeader.swift', from: 'typography + spacing' },
          { file: 'MinDismissButton.swift', from: 'spacing + transitions' },
          { file: 'spacing.json', from: 'full spacing scale' },
          { file: 'android/values/*.xml', from: 'dimens for all tokens' },
        ].map(n => (
          <div key={n.file} className="native-card">
            <code>{n.file}</code>
            <span className="dim" style={{ fontSize: 11 }}>← {n.from}</span>
          </div>
        ))}
      </div>

      <h3 className="section-title" style={{ marginTop: 32 }}>MinAppKit Shared Swift Package</h3>
      <p className="panel-desc">
        Local SPM package at <code>packages/design-system/swift/</code> imported by all 4 Xcode projects. Hand-authored shared components and protocols.
      </p>
      <div className="native-grid">
        {[
          { file: 'Tokens/', from: 'MinSpacing, MinCornerRadius, MinOpacity, MinShadow, MinAnimation, MinIcon' },
          { file: 'Components/ScrollDismissButton.swift', from: 'Floating scroll-dismiss with configurable material' },
          { file: 'Components/OnboardingPagerView.swift', from: 'Paged TabView shell + page dots + completion' },
          { file: 'Components/SettingsSheet.swift', from: 'Grouped List + Done toolbar chrome' },
          { file: 'Components/NavigationSearchPlacement.swift', from: 'Search bar position enum (PodLink + YourTube)' },
          { file: 'Components/PullToDismiss/', from: 'ScrollObserver + Introspector + Engine (3 files)' },
          { file: 'Components/CachedAsyncImage.swift', from: 'Remote image loading + memory/disk cache' },
          { file: 'Components/ImageCache.swift', from: 'Configurable cache directory + downscaling' },
          { file: 'Extensions/CodablePreference.swift', from: 'Protocol for JSON-in-UserDefaults load/save' },
          { file: 'Extensions/URLDeepLink.swift', from: 'URL.queryValue(for:) shared helper' },
          { file: 'Extensions/ScrollOffset.swift', from: 'PreferenceKey + View extension for scroll tracking' },
          { file: 'Extensions/ViewSurface.swift', from: '.minCard() and .frostedSurface() modifiers' },
          { file: 'Theme/MinTheme.swift', from: 'Shared theme protocol (12 properties + computed defaults)' },
          { file: 'Theme/ThemeColorData.swift', from: 'Codable RGBA color for theme persistence' },
          { file: 'Theme/ThemeFontStyle.swift', from: 'Font style enum (system, rounded, serif, mono, condensed)' },
          { file: 'Theme/CustomThemeDefinition.swift', from: 'User-created theme model + CustomTheme wrapper' },
          { file: 'Theme/ThemeAdaptedPalette.swift', from: 'Auto-generated color palette + .from(highlight:) generator' },
          { file: 'Theme/ThemeFontResolver.swift', from: 'Bundled preset font style string → Font resolver' },
          { file: 'Theme/UIColorThemeExtensions.swift', from: 'lightened, darkened, mix, contrast, luminance' },
        ].map(n => (
          <div key={n.file} className="native-card">
            <code>{n.file}</code>
            <span className="dim" style={{ fontSize: 11 }}>← {n.from}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

// ── App Inspector Panel (Figma-grade canvas) ──

const S = {
  xs: 4, sm: 8, md: 12, lg: 16, xl: 24, xxl: 32, xxxl: 40,
  screenHorizontalPadding: 24, screenBottomPadding: 24, bottomSafeArea: 120,
  page: { marginTop: 24, marginBottom: 24, marginLeft: 24, marginRight: 24 },
  logo: { marginTop: 32, marginBottom: 24 },
  button: { paddingX: 24, paddingY: 12, gap: 8 },
  list: { itemPaddingY: 16, itemPaddingX: 16, itemGap: 12, betweenItems: 8 },
  titleType: { maxWidth: 220, maxHeight: 38, horizontalPadding: 24, contentTopSpacing: 12 },
  topControls: { buttonSize: 56, horizontalPadding: 8, verticalPadding: 4 },
};
const CR = { artTile: 4, xs: 4, sm: 6, md: 8, lg: 12, xl: 16, round: 9999 };

const TOKEN_MAP = { size: 'Size', radius: 'Corner Radius', bg: 'Background', border: 'Border', type: 'Typography', color: 'Color', icon: 'Icon', spacing: 'Spacing', style: 'Style', layout: 'Layout', effect: 'Effect', shadow: 'Shadow', opacity: 'Opacity', glass: 'Glass', anim: 'Animation' };

function useLucide(deps) {
  useEffect(() => { if (window.lucide) window.lucide.createIcons(); }, deps);
}

function Ico({ name, size = 16, className = '' }) {
  return <i data-lucide={name} style={{ width: size, height: size }} className={className} />;
}

function ds(obj) { return { 'data-ds': JSON.stringify(obj) }; }

const THEMES = [
  { name: 'Midnight', swatch: '#3870f2', vars: { '--phone-accent': 'rgba(56,112,242,0.9)', '--phone-accent-15': 'rgba(56,112,242,0.15)', '--phone-accent-30': 'rgba(56,112,242,0.3)', '--phone-bg': '#0b1220', '--phone-bg-tint': 'rgba(255,255,255,0.035)', '--phone-headline': '#ffffff', '--phone-text-primary': '#f2f4f8', '--phone-text-secondary': 'rgba(179,186,199,0.65)', '--phone-secondary-accent': 'rgba(92,127,207,0.9)', '--phone-border-rule': 'rgba(141,155,186,0.08)' } },
  { name: 'Ember', swatch: '#e6783c', vars: { '--phone-accent': 'rgba(230,120,60,0.9)', '--phone-accent-15': 'rgba(230,120,60,0.15)', '--phone-accent-30': 'rgba(230,120,60,0.3)', '--phone-bg': '#1a110b', '--phone-bg-tint': 'rgba(255,200,150,0.035)', '--phone-headline': '#fff8f0', '--phone-text-primary': '#f8f2e8', '--phone-text-secondary': 'rgba(199,180,160,0.65)', '--phone-secondary-accent': 'rgba(207,145,92,0.9)', '--phone-border-rule': 'rgba(186,155,141,0.08)' } },
  { name: 'Emerald', swatch: '#34d399', vars: { '--phone-accent': 'rgba(52,211,153,0.9)', '--phone-accent-15': 'rgba(52,211,153,0.15)', '--phone-accent-30': 'rgba(52,211,153,0.3)', '--phone-bg': '#0b1a14', '--phone-bg-tint': 'rgba(150,255,200,0.035)', '--phone-headline': '#f0fff8', '--phone-text-primary': '#e8f8f2', '--phone-text-secondary': 'rgba(160,199,180,0.65)', '--phone-secondary-accent': 'rgba(92,207,155,0.9)', '--phone-border-rule': 'rgba(141,186,165,0.08)' } },
  { name: 'Violet', swatch: '#a855f7', vars: { '--phone-accent': 'rgba(168,85,247,0.9)', '--phone-accent-15': 'rgba(168,85,247,0.15)', '--phone-accent-30': 'rgba(168,85,247,0.3)', '--phone-bg': '#14101a', '--phone-bg-tint': 'rgba(200,150,255,0.035)', '--phone-headline': '#f8f0ff', '--phone-text-primary': '#f2e8f8', '--phone-text-secondary': 'rgba(180,160,199,0.65)', '--phone-secondary-accent': 'rgba(155,92,207,0.9)', '--phone-border-rule': 'rgba(165,141,186,0.08)' } },
  { name: 'Rose', swatch: '#f43f5e', vars: { '--phone-accent': 'rgba(244,63,94,0.9)', '--phone-accent-15': 'rgba(244,63,94,0.15)', '--phone-accent-30': 'rgba(244,63,94,0.3)', '--phone-bg': '#1a0b10', '--phone-bg-tint': 'rgba(255,150,180,0.035)', '--phone-headline': '#fff0f4', '--phone-text-primary': '#f8e8ee', '--phone-text-secondary': 'rgba(199,160,175,0.65)', '--phone-secondary-accent': 'rgba(207,92,130,0.9)', '--phone-border-rule': 'rgba(186,141,160,0.08)' } },
  { name: 'Mono', swatch: '#999', vars: { '--phone-accent': 'rgba(180,180,180,0.9)', '--phone-accent-15': 'rgba(180,180,180,0.15)', '--phone-accent-30': 'rgba(180,180,180,0.3)', '--phone-bg': '#111111', '--phone-bg-tint': 'rgba(255,255,255,0.035)', '--phone-headline': '#ffffff', '--phone-text-primary': '#e5e5e5', '--phone-text-secondary': 'rgba(170,170,170,0.65)', '--phone-secondary-accent': 'rgba(140,140,140,0.9)', '--phone-border-rule': 'rgba(155,155,155,0.08)' } },
];

const INSPECTOR_APPS = APPS.map(a => ({
  ...a,
  screens: {
    watchedit: [
      { id: 'home', name: 'Collections Home', desc: 'Horizontal poster rows, floating toolbar, title type mark' },
      { id: 'search', name: 'Search', desc: 'Full-text search with result rows and floating controls' },
      { id: 'detail', name: 'Movie Detail', desc: 'Hero backdrop, liquid-glass actions, cast scroll, source cards' },
      { id: 'account', name: 'Account', desc: 'Grouped settings list with theme picker' },
      { id: 'onboarding', name: 'Onboarding', desc: 'Welcome flow with pager dots' },
    ],
    podlink: [
      { id: 'home', name: 'Podcast List', desc: '2-column grid with search placement toggle' },
      { id: 'detail', name: 'Show Detail', desc: 'Artwork, episode list, pull-to-dismiss' },
      { id: 'account', name: 'Settings', desc: 'Notification preferences, appearance' },
      { id: 'onboarding', name: 'Onboarding', desc: 'OnboardingPagerView — 4 steps' },
    ],
    yourtube: [
      { id: 'home', name: 'Video Feed', desc: '2-column grid with subscriptions' },
      { id: 'detail', name: 'Channel Detail', desc: 'Banner, video list, subscribe button' },
      { id: 'account', name: 'Settings', desc: 'Playback and notification preferences' },
      { id: 'onboarding', name: 'Onboarding', desc: 'OnboardingPagerView — 3 steps' },
    ],
    cyclismo: [
      { id: 'home', name: 'Race List', desc: 'Vertical list with race cards, stages preview' },
      { id: 'detail', name: 'Race Detail', desc: 'Hero, stage profiles, classification tables' },
      { id: 'account', name: 'Settings', desc: 'Notification preferences, appearance' },
      { id: 'onboarding', name: 'Onboarding', desc: 'OnboardingPagerView — 4 steps' },
    ],
  }[a.id],
}));

/* ── Phone screen components ── */

function PhoneHomeScreen({ app }) {
  const content = {
    watchedit: { sections: ['The Rewatchables', 'Rotten Tomatoes Best', 'IMDb Top 250'], hasPosters: true },
    podlink: { sections: ['Subscribed', 'Trending', 'New Episodes'], hasGrid: true },
    yourtube: { sections: ['Subscriptions', 'Trending', 'Watch Later'], hasGrid: true },
    cyclismo: { sections: ['Grand Tours', 'Monuments', 'Stage Races'], hasList: true },
  }[app.id];

  return (
    <div className="app-phone-screen" style={{ background: 'var(--phone-bg)' }}>
      <div className="app-phone-status-bar" {...ds({ el: 'Status Bar', size: '393 × 54pt', layout: 'HStack, space-between', spacing: 'padding: 14pt top, 24pt horizontal' })}>
        <span className="app-phone-time">9:41</span>
        <span className="app-phone-account-btn" {...ds({ el: 'Account Button', size: `${S.topControls.buttonSize} × ${S.topControls.buttonSize}pt`, radius: 'CornerRadius.round', bg: '.thinMaterial', border: '0.8pt rgba(255,255,255,0.28)', icon: 'IconSize.md (20pt) person.crop.circle', effect: 'backdrop-filter: blur(16pt)' })}><Ico name="circle-user-round" size={20} /></span>
      </div>
      <div className="app-home-content" {...ds({ el: 'Content', layout: 'ScrollView > LazyVStack', spacing: `bottom inset: ${S.bottomSafeArea}pt` })}>
        <div className="app-home-typemark" {...ds({ el: 'App Typemark', type: 'displayMedium (28pt) bold', color: 'headline', spacing: `padding-h: ${S.xl}pt (screenHorizontalPadding)` })}>{app.name}</div>
        {content.sections.map((section, si) => (
          <div key={si} className="app-home-section" {...ds({ el: 'Source Section', spacing: `margin-top: Spacing.xl (${S.xl}pt)` })}>
            <div className="app-home-section-title" {...ds({ el: 'Section Title', type: 'headlineSmall (18pt) bold', color: 'textPrimary' })}>{section}</div>
            {content.hasPosters && (
              <div className="app-home-poster-row" {...ds({ el: 'Poster Row', layout: 'ScrollView(.horizontal) > LazyHStack', spacing: `gap: Spacing.md (${S.md}pt), padding-h: ${S.xl}pt` })}>
                {Array.from({ length: 4 }).map((_, i) => (
                  <div key={i} className="app-poster-card" {...ds({ el: 'Poster Card', size: '160 × 240pt (+60%)', radius: `CornerRadius.artTile (${CR.artTile}pt)` })} style={{ background: `color-mix(in srgb, ${app.color} ${40 + i * 15}%, #151a24)` }} />
                ))}
              </div>
            )}
            {(content.hasGrid) && (
              <div className="app-home-grid" {...ds({ el: '2-Column Grid', layout: 'LazyVGrid(columns: 2)', spacing: `gap: Spacing.lg (${S.lg}pt), padding-h: ${S.xl}pt` })}>
                {Array.from({ length: 4 }).map((_, i) => (
                  <div key={i} className="app-grid-tile" {...ds({ el: 'Grid Tile', radius: `CornerRadius.artTile (${CR.artTile}pt)` })} style={{ background: `color-mix(in srgb, ${app.color} ${35 + i * 15}%, #151a24)` }}>
                    <div className="app-grid-tile-label">{app.id === 'podlink' ? ['Tech Meme', 'ATP', 'Accidental Tech', 'Overcast'][i] : ['Sub 1', 'Sub 2', 'Sub 3', 'Sub 4'][i]}</div>
                  </div>
                ))}
              </div>
            )}
            {content.hasList && (
              <div className="app-home-list" {...ds({ el: 'Race List', layout: 'List', spacing: `padding-h: ${S.xl}pt` })}>
                {['Tour de France 2026', 'Giro d\'Italia 2026', 'Vuelta a España'][si] && (
                  <div className="app-list-row" {...ds({ el: 'List Row', spacing: `padding: ${S.list.itemPaddingY}pt ${S.list.itemPaddingX}pt, gap: ${S.list.itemGap}pt` })}>
                    <div className="app-list-row-art" style={{ background: `color-mix(in srgb, ${app.color} ${60 + si * 12}%, #222)`, borderRadius: CR.artTile }} />
                    <div className="app-list-row-text">
                      <div className="app-list-row-title">{['Tour de France', 'Giro d\'Italia', 'Vuelta a España'][si]}</div>
                      <div className="app-list-row-sub">{['Jul 4 – Jul 26   Grand Tour', 'May 9 – Jun 1   Grand Tour', 'Aug 14 – Sep 5   Grand Tour'][si]}</div>
                    </div>
                    <Ico name="chevron-right" size={14} className="app-list-row-chevron" />
                  </div>
                )}
              </div>
            )}
          </div>
        ))}
      </div>
      <div className="app-floating-toolbar" {...ds({ el: 'Floating Toolbar', layout: 'HStack, safeAreaInset(bottom)', spacing: `bottom: Spacing.sm (${S.sm}pt), horizontal: Spacing.lg (${S.lg}pt), gap: Spacing.sm (${S.sm}pt)` })}>
        <div className="app-toolbar-filters" {...ds({ el: 'Filter Capsule', size: `auto × ${S.topControls.buttonSize}pt`, radius: 'CornerRadius.round (capsule)', bg: '.thinMaterial', border: '0.8pt rgba(255,255,255,0.28)', spacing: `padding-h: ${S.lg}pt, icon gap: ${S.xl}pt`, effect: 'backdrop-filter: blur(16pt)' })}>
          <span className="app-toolbar-filter-icon"><Ico name="sliders-horizontal" size={20} /></span>
          <span className="app-toolbar-filter-icon"><Ico name={app.id === 'watchedit' ? 'play' : app.id === 'podlink' ? 'radio' : app.id === 'yourtube' ? 'tv' : 'mountain'} size={20} /></span>
          <span className="app-toolbar-filter-icon"><Ico name={app.id === 'watchedit' ? 'drama' : 'tag'} size={20} /></span>
        </div>
        <div className="app-toolbar-search-btn" {...ds({ el: 'Search Button', size: `${S.topControls.buttonSize} × ${S.topControls.buttonSize}pt`, radius: 'CornerRadius.round', bg: '.thinMaterial', icon: 'IconSize.md (20pt) magnifyingglass', effect: 'backdrop-filter: blur(16pt)' })}><Ico name="search" size={20} /></div>
      </div>
      <div className="app-system-tabbar" {...ds({ el: 'System Tab Bar', size: '393 × 49pt', layout: 'HStack, space-around', bg: 'rgba(30,36,50,0.92)', border: '0.5pt top' })}>
        <div className="app-tabbar-item"><Ico name="house" size={22} /></div>
        <div className="app-tabbar-item"><Ico name="search" size={22} /></div>
        <div className="app-tabbar-item"><Ico name="bookmark" size={22} /></div>
        <div className="app-tabbar-item"><Ico name="circle-user-round" size={22} /></div>
      </div>
    </div>
  );
}

function PhoneDetailScreen({ app }) {
  const detailContent = {
    watchedit: { title: 'The Dark Knight', sub: 'PG-13  2008', director: 'Christopher Nolan', cast: ['Christian Bale', 'Heath Ledger', 'Aaron Eckhart'] },
    podlink: { title: 'The Daily', sub: 'The New York Times  News', director: 'Host', cast: ['Michael Barbaro', 'Sabrina Tavernise', 'Natasha Frost'] },
    yourtube: { title: 'Marques Brownlee', sub: '19.2M subscribers  Tech', director: 'Creator', cast: [] },
    cyclismo: { title: 'Tour de France 2026', sub: 'Jul 4 – Jul 26  Grand Tour', director: 'Organizer', cast: ['Tadej Pogačar', 'Jonas Vingegaard', 'Remco Evenepoel'] },
  }[app.id];

  return (
    <div className="app-phone-screen app-detail-screen" style={{ background: 'var(--phone-bg)' }}>
      <div className="app-detail-poster-focus-hero" {...ds({ el: 'Poster Focus Hero', layout: 'Full-bleed poster image', size: '393pt wide, 2:3 aspect' })}>
        <div style={{ width: '100%', aspectRatio: '2/3', background: `linear-gradient(135deg, ${app.color}, color-mix(in srgb, ${app.color} 40%, #000))` }} />
        <div className="poster-focus-fade" />
      </div>
      <div className="app-detail-backdrop" {...ds({ el: 'Backdrop Image', size: '393 × 250pt', style: 'classicBackdropHeight (250pt)', effect: 'bottom gradient overlay 60%' })}>
        <div style={{ width: '100%', height: '100%', background: `linear-gradient(135deg, ${app.color}, color-mix(in srgb, ${app.color} 40%, #000))` }} />
      </div>
      <div className="app-detail-body" {...ds({ el: 'Detail Body', layout: `VStack(spacing: Spacing.xl)`, spacing: `padding: 0 ${S.xl}pt ${S.xl}pt` })}>
        <div className="app-detail-title" {...ds({ el: 'Title', type: 'displayLarge (34pt) bold', color: 'headline' })}>{detailContent.title}</div>
        <div className="app-detail-subtitle" {...ds({ el: 'Subtitle', layout: 'HStack', spacing: `gap: Spacing.md (${S.md}pt), margin-top: Spacing.sm (${S.sm}pt)` })}>
          <span className="app-mpaa-pill" {...ds({ el: 'Rating Pill', type: 'labelMedium (14pt) bold', radius: `CornerRadius.sm (${CR.sm}pt)`, bg: 'accent α0.15', spacing: 'padding: 4pt 8pt' })}>{app.id === 'watchedit' ? 'PG-13' : app.id === 'cyclismo' ? 'WT' : ''}</span>
          <span className="app-detail-year" {...ds({ el: 'Year', type: 'titleMedium (18pt)', color: 'textSecondary α0.65' })}>{detailContent.sub}</span>
        </div>
        <div className="app-detail-pf-meta" {...ds({ el: 'Poster Focus Meta', type: 'bodyMedium (16pt)', color: 'textSecondary' })}>
          <span>{detailContent.sub}</span>
        </div>
        <div className="app-detail-actions" {...ds({ el: 'Action Row', layout: 'HStack', spacing: `gap: Spacing.lg (${S.lg}pt), margin-top: Spacing.xl (${S.xl}pt)` })}>
          <div className="app-action-btn" {...ds({ el: 'Play Button', size: '60 × 60pt', radius: 'CornerRadius.round', style: 'LiquidGlassButtonStyle (compact)', icon: 'IconSize.lg (24pt) play.fill' })}><Ico name="play" size={24} /></div>
          <div className="app-action-btn active" {...ds({ el: 'Action Button (active)', size: '60 × 60pt', radius: 'CornerRadius.round', style: 'LiquidGlassButtonStyle (compact)' })}><Ico name={app.id === 'watchedit' ? 'popcorn' : app.id === 'podlink' ? 'headphones' : app.id === 'yourtube' ? 'bell' : 'flag'} size={24} /></div>
          <div className="app-action-btn" {...ds({ el: 'Save Button', size: '60 × 60pt', radius: 'CornerRadius.round', style: 'LiquidGlassButtonStyle (compact)', icon: 'IconSize.lg (24pt) bookmark' })}><Ico name="bookmark" size={24} /></div>
        </div>
        <div className="app-detail-overview" {...ds({ el: 'Overview', type: 'bodyMedium (16pt)', color: 'textSecondary', spacing: `lineSpacing: Spacing.xs (${S.xs}pt), margin-top: Spacing.xl (${S.xl}pt)` })}>
          <div className="app-placeholder-line" /><div className="app-placeholder-line w85" /><div className="app-placeholder-line w70" />
        </div>
        {detailContent.cast.length > 0 && (
          <div className="app-detail-cast-section" {...ds({ el: 'Cast Section', spacing: `margin-top: Spacing.lg (${S.lg}pt)` })}>
            <div className="app-detail-credit-label" {...ds({ el: 'Section Label', type: 'labelMedium (14pt) semibold', color: 'textSecondary' })}>{app.id === 'cyclismo' ? 'GC Favorites' : app.id === 'podlink' ? 'Hosts' : 'Cast'}</div>
            <div className="app-detail-cast-row" {...ds({ el: 'Cast Scroll', layout: 'ScrollView(.horizontal) > HStack', spacing: `gap: Spacing.lg (${S.lg}pt)` })}>
              {detailContent.cast.map((name, i) => (
                <div key={i} className="app-cast-card" {...ds({ el: 'Cast Card', size: '100pt wide', layout: 'VStack, center', spacing: `spacing: Spacing.sm (${S.sm}pt)` })}>
                  <div className="app-cast-photo" style={{ background: `color-mix(in srgb, ${app.color} ${50 + i * 15}%, #333)` }} {...ds({ el: 'Photo', size: '96 × 96pt', radius: 'CornerRadius.round (circle)' })} />
                  <div className="app-cast-name" {...ds({ el: 'Name', type: 'captionMedium (12pt) medium', color: 'textPrimary' })}>{name}</div>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

function PhoneAccountScreen({ app }) {
  return (
    <div className="app-phone-screen" style={{ background: 'var(--phone-bg)' }}>
      <div className="ios-nav-bar" {...ds({ el: 'Navigation Bar', size: `393 × 44pt`, spacing: `padding-h: Spacing.lg (${S.lg}pt)` })}>
        <div className="ios-nav-bar-trailing"><span style={{ color: 'var(--phone-accent)', fontSize: 15, fontWeight: 600 }}>Done</span></div>
        Settings
      </div>
      <div className="app-settings-body" {...ds({ el: 'Settings Body', layout: 'List(.insetGrouped)', spacing: `padding-h: ${S.xl}pt` })}>
        <div className="app-settings-group" {...ds({ el: 'Section', spacing: `margin-top: Spacing.xl (${S.xl}pt)` })}>
          <div className="app-settings-group-label">Notifications</div>
          <div className="app-settings-card" {...ds({ el: 'Grouped Card', radius: `ios-grouped-card-radius (10pt)`, bg: 'groupedListCardBackground' })}>
            {['Morning Summary', 'New Releases', 'Priority Alerts'].map((label, i) => (
              <div key={i} className="app-settings-row" {...ds({ el: 'Setting Row', layout: 'HStack', spacing: `padding: ${S.list.itemPaddingY}pt ${S.list.itemPaddingX}pt` })}>
                <span>{label}</span>
                <div className={`app-ios-toggle ${i === 0 ? 'on' : ''}`} />
              </div>
            ))}
          </div>
        </div>
        <div className="app-settings-group" {...ds({ el: 'Section', spacing: `margin-top: Spacing.xl (${S.xl}pt)` })}>
          <div className="app-settings-group-label">Appearance</div>
          <div className="app-settings-card">
            {['Theme', 'App Icon', 'Font'].map((label, i) => (
              <div key={i} className="app-settings-row">
                <span>{label}</span>
                <Ico name="chevron-right" size={14} className="app-settings-chevron" />
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

function PhoneOnboardingScreen({ app }) {
  return (
    <div className="app-phone-screen app-onboarding-screen" style={{ background: 'var(--phone-bg)' }}>
      <div className="app-onboard-center" {...ds({ el: 'Onboarding Content', layout: 'VStack, center', spacing: `padding-h: ${S.xl}pt` })}>
        <div className="app-onboard-icon" style={{ background: `linear-gradient(135deg, ${app.color}, color-mix(in srgb, ${app.color} 60%, #000))` }} {...ds({ el: 'App Icon', size: '80 × 80pt', radius: '20pt' })} />
        <div className="app-onboard-title" {...ds({ el: 'App Name', type: 'displaySmall (24pt) bold', color: 'headline' })}>{app.name}</div>
        <div className="app-onboard-subtitle" {...ds({ el: 'Tagline', type: 'bodyMedium (16pt)', color: 'textSecondary' })}>
          {{ watchedit: 'Your movie collection', podlink: 'Podcasts, simplified', yourtube: 'Your subscriptions', cyclismo: 'Your cycling guide' }[app.id]}
        </div>
        <div className="app-onboard-dots" {...ds({ el: 'Page Dots', layout: 'HStack', spacing: `gap: Spacing.sm (${S.sm}pt), margin-top: Spacing.xl (${S.xl}pt)` })}>
          {[0, 1, 2, 3].map(i => <div key={i} className={`app-onboard-dot ${i === 0 ? 'active' : ''}`} />)}
        </div>
        <button className="app-onboard-btn" {...ds({ el: 'CTA Button', spacing: `padding: ${S.button.paddingY}pt ${S.button.paddingX}pt, margin-top: Spacing.xxl (${S.xxl}pt)` })}>Get Started</button>
      </div>
    </div>
  );
}

function PhoneSearchScreen({ app }) {
  const items = {
    watchedit: [{ title: 'The Dark Knight', meta: 'PG-13  2008' }, { title: 'Goodfellas', meta: 'R  1990' }, { title: 'No Country for Old Men', meta: 'R  2007' }],
    podlink: [{ title: 'Accidental Tech Podcast', meta: 'Technology  Weekly' }, { title: 'The Talk Show', meta: 'Apple  Weekly' }],
    yourtube: [{ title: 'Marques Brownlee', meta: '19.2M subs  Tech' }, { title: 'Linus Tech Tips', meta: '16.1M subs  Tech' }],
    cyclismo: [{ title: 'Tour de France', meta: 'Grand Tour  Jul 2026' }, { title: 'Paris-Roubaix', meta: 'Monument  Apr 2026' }],
  }[app.id];

  return (
    <div className="app-phone-screen" style={{ background: 'var(--phone-bg)' }}>
      <div className="app-search-handle" {...ds({ el: 'Sheet Drag Handle', size: '36 × 5pt', radius: 'CornerRadius.round', bg: 'rgba(179,186,199,0.35)' })} />
      <div className="app-search-tokens" {...ds({ el: 'Filter Tokens Row', layout: 'ScrollView(.horizontal)', spacing: `padding: ${S.sm}pt ${S.lg}pt ${S.md}pt ${S.xl}pt` })}>
        <span className="app-search-token" {...ds({ el: 'Active Filter', type: 'headlineSmall (18pt) bold', color: 'accent α0.9' })}>Drama</span>
        <span className="app-search-token">2024</span>
      </div>
      <div className="app-search-results" {...ds({ el: 'Search Results', layout: 'List', spacing: `padding-h: Spacing.xl (${S.xl}pt)` })}>
        {items.map((item, i) => (
          <div key={i} className="app-search-row" {...ds({ el: 'Result Row', layout: 'HStack', spacing: `padding: Spacing.sm (${S.sm}pt), gap: Spacing.md (${S.md}pt)`, radius: `CornerRadius.md (${CR.md}pt)` })}>
            <div className="app-search-thumb" style={{ background: `color-mix(in srgb, ${app.color} ${50 + i * 18}%, #151a24)` }} {...ds({ el: 'Poster', size: '50 × 74pt', radius: `CornerRadius.sm (${CR.sm}pt)` })} />
            <div className="app-search-row-text">
              <div className="app-search-row-title" {...ds({ el: 'Title', type: 'headlineSmall (18pt) bold', color: 'textPrimary' })}>{item.title}</div>
              <div className="app-search-row-meta" {...ds({ el: 'Meta', type: 'bodySmall (15pt)', color: 'textSecondary α0.65' })}>{item.meta}</div>
            </div>
            <div className="app-search-row-icons">
              {i === 0 && <span className="app-status-icon listened" {...ds({ el: 'Status Icon', size: '24 × 24pt', radius: 'CornerRadius.round', bg: 'accent α0.9' })}><Ico name="mic" size={12} /></span>}
            </div>
          </div>
        ))}
      </div>
      <div className="app-search-floating-bar" {...ds({ el: 'Floating Search', layout: 'HStack, safeAreaInset(bottom)', spacing: `bottom: ${S.sm}pt, horizontal: ${S.xl}pt, gap: ${S.sm}pt` })}>
        <div className="app-search-bar-filters glass-material" {...ds({ el: 'Filter Capsule', size: `auto × ${S.topControls.buttonSize}pt`, radius: 'CornerRadius.round', bg: '.thinMaterial' })}>
          <span className="app-toolbar-filter-icon"><Ico name="sliders-horizontal" size={20} /></span>
        </div>
        <div className="app-search-bar-input glass-material" {...ds({ el: 'Search Input', size: `flex × ${S.topControls.buttonSize}pt`, radius: 'CornerRadius.round', type: 'bodyMedium (16pt)' })}>Search {app.content.toLowerCase()}…</div>
        <div className="app-search-bar-close glass-material" {...ds({ el: 'Close Button', size: `${S.topControls.buttonSize} × ${S.topControls.buttonSize}pt`, radius: 'CornerRadius.round', icon: 'xmark.circle.fill' })}><Ico name="x" size={16} /></div>
      </div>
    </div>
  );
}

const PHONE_SCREENS = { home: PhoneHomeScreen, search: PhoneSearchScreen, detail: PhoneDetailScreen, account: PhoneAccountScreen, onboarding: PhoneOnboardingScreen };

function InspectorPanel() {
  const [selectedApp, setSelectedApp] = useState(0);
  const [chromeOn, setChromeOn] = useState(true);
  const [inspected, setInspected] = useState(null);
  const [panelTab, setPanelTab] = useState('inspect');
  const [toolbarStyle, setToolbarStyle] = useState('floating');
  const [detailLayout, setDetailLayout] = useState('poster-focus');
  const [searchBarStyle, setSearchBarStyle] = useState('glass');
  const [actionBarAlign, setActionBarAlign] = useState('leftAligned');
  const [selectedTheme, setSelectedTheme] = useState(0);
  const viewportRef = useRef(null);
  const surfaceRef = useRef(null);
  const canvasRef = useRef({ zoom: 0.55, panX: 80, panY: 40, isPanning: false, startX: 0, startY: 0, startPanX: 0, startPanY: 0 });

  const app = INSPECTOR_APPS[selectedApp];
  const theme = THEMES[selectedTheme];
  const themeStyle = { ...theme.vars, '--action-bar-align': actionBarAlign === 'centered' ? 'center' : 'flex-start' };
  const artboardClasses = ['canvas-artboards', !chromeOn && 'chrome-off', `toolbar-${toolbarStyle}`, `detail-${detailLayout}`, `searchbar-${searchBarStyle}`].filter(Boolean).join(' ');

  const applyTransform = useCallback(() => {
    const c = canvasRef.current;
    if (surfaceRef.current) surfaceRef.current.style.transform = `translate(${c.panX}px, ${c.panY}px) scale(${c.zoom})`;
  }, []);

  const zoomTo = useCallback((newZoom, cx, cy) => {
    const c = canvasRef.current;
    const vp = viewportRef.current;
    if (!vp) return;
    const clamped = Math.min(3, Math.max(0.1, newZoom));
    if (!cx) { const r = vp.getBoundingClientRect(); cx = r.width / 2; cy = r.height / 2; }
    c.panX = cx - ((cx - c.panX) / c.zoom) * clamped;
    c.panY = cy - ((cy - c.panY) / c.zoom) * clamped;
    c.zoom = clamped;
    applyTransform();
  }, [applyTransform]);

  const zoomToFit = useCallback(() => {
    const vp = viewportRef.current;
    const sf = surfaceRef.current;
    if (!vp || !sf) return;
    const c = canvasRef.current;
    const vr = vp.getBoundingClientRect();
    const content = sf.firstElementChild;
    if (!content) return;
    const sw = content.scrollWidth;
    const sh = content.scrollHeight;
    const fitZoom = Math.min((vr.width - 80) / sw, (vr.height - 80) / sh, 1.5);
    c.zoom = Math.max(0.1, fitZoom);
    c.panX = (vr.width - sw * c.zoom) / 2;
    c.panY = 40;
    applyTransform();
  }, [applyTransform]);

  useEffect(() => {
    const vp = viewportRef.current;
    if (!vp) return;
    const c = canvasRef.current;

    const onWheel = (e) => {
      e.preventDefault();
      if (e.ctrlKey || e.metaKey) {
        const r = vp.getBoundingClientRect();
        zoomTo(c.zoom * (1 - e.deltaY * 0.003), e.clientX - r.left, e.clientY - r.top);
      } else {
        c.panX -= e.deltaX;
        c.panY -= e.deltaY;
        applyTransform();
      }
    };
    const onDown = (e) => {
      if (e.button !== 0) return;
      c.isPanning = true; c.startX = e.clientX; c.startY = e.clientY; c.startPanX = c.panX; c.startPanY = c.panY;
      vp.style.cursor = 'grabbing';
    };
    const onMove = (e) => {
      if (!c.isPanning) return;
      c.panX = c.startPanX + (e.clientX - c.startX);
      c.panY = c.startPanY + (e.clientY - c.startY);
      applyTransform();
    };
    const onUp = () => { c.isPanning = false; vp.style.cursor = 'grab'; };

    vp.addEventListener('wheel', onWheel, { passive: false });
    vp.addEventListener('mousedown', onDown);
    window.addEventListener('mousemove', onMove);
    window.addEventListener('mouseup', onUp);
    applyTransform();
    return () => {
      vp.removeEventListener('wheel', onWheel);
      vp.removeEventListener('mousedown', onDown);
      window.removeEventListener('mousemove', onMove);
      window.removeEventListener('mouseup', onUp);
    };
  }, [applyTransform, zoomTo]);

  useEffect(() => { zoomToFit(); }, [selectedApp, zoomToFit]);

  useLucide([selectedApp, panelTab, toolbarStyle]);

  const handleInspect = useCallback((e) => {
    const target = e.target.closest('[data-ds]');
    if (!target || e.target.closest('.canvas-bottombar') || e.target.closest('.crp-panel')) return;
    e.stopPropagation();
    try {
      const data = JSON.parse(target.dataset.ds);
      const rect = target.getBoundingClientRect();
      const cs = getComputedStyle(target);
      setInspected({ data, computed: { width: Math.round(rect.width), height: Math.round(rect.height), fontSize: cs.fontSize, fontWeight: cs.fontWeight, borderRadius: cs.borderRadius }, className: target.className });
      setPanelTab('inspect');
    } catch (_) {}
  }, []);

  return (
    <div className="canvas-shell">
      <div className="canvas-viewport" ref={viewportRef} onClick={handleInspect} style={{ cursor: 'grab' }}>
        <div className="canvas-surface" ref={surfaceRef}>
            <div className={artboardClasses} style={themeStyle}>
            {/* Overview artboard */}
            <section className="canvas-artboard">
              <div className="artboard-header">
                <span className="artboard-title">{app.label} — Overview</span>
              </div>
              <div className="app-flow-diagram">
                <div className="app-flow-node app-flow-root">
                  <div className="app-flow-node-title">App Launch</div>
                  <div className="app-flow-node-desc">{app.name}App → {app.screens[0].name}</div>
                </div>
                <div className="app-flow-arrow"><Ico name="arrow-right" size={20} /></div>
                <div className="app-flow-branch">
                  {app.screens.map(s => (
                    <div key={s.id} className="app-flow-node app-flow-leaf">
                      <div className="app-flow-node-title">{s.name}</div>
                    </div>
                  ))}
                </div>
              </div>
              <div className="app-screen-grid-overview">
                {app.screens.map(s => (
                  <div key={s.id} className="app-thumb">
                    <div className="app-thumb-phone">
                      <div className="app-thumb-notch" />
                      <div className="app-thumb-screen" style={{ background: 'var(--phone-bg, #0b1220)' }}>
                        {s.id === 'home' && <><div className="app-thumb-bar" /><div className="app-thumb-row" /><div className="app-thumb-row" /><div className="app-thumb-row" /></>}
                        {s.id === 'search' && <><div className="app-thumb-bar" /><div className="app-thumb-line" /><div className="app-thumb-line" /><div className="app-thumb-line" /></>}
                        {s.id === 'detail' && <><div className="app-thumb-backdrop-mini" /><div className="app-thumb-title-block" /><div className="app-thumb-actions-mini" /></>}
                        {s.id === 'account' && <><div className="app-thumb-bar" /><div className="app-thumb-list-item" /><div className="app-thumb-list-item" /><div className="app-thumb-list-item" /></>}
                        {s.id === 'onboarding' && <><div className="app-thumb-onboard-icon" /><div className="app-thumb-line wide" /><div className="app-thumb-cta" /></>}
                      </div>
                    </div>
                    <div className="app-thumb-label">{s.name}</div>
                  </div>
                ))}
              </div>
            </section>

            {/* Screen artboards */}
            {app.screens.map(screen => {
              const Screen = PHONE_SCREENS[screen.id];
              if (!Screen) return null;
              return (
                <section key={screen.id} className="canvas-artboard">
                  <div className="artboard-header">
                    <span className="artboard-title">{screen.name}</span>
                  </div>
                  <div className="artboard-phone-wrap">
                    <div className="app-phone-showcase">
                      <div className="app-phone">
                        <div className="app-phone-notch" />
                        <Screen app={app} />
                      </div>
                    </div>
                  </div>
                </section>
              );
            })}
          </div>
        </div>
      </div>

      {/* Canvas bottom bar */}
      <div className="canvas-bottombar">
        <div className="cbb-group">
          {INSPECTOR_APPS.map((a, i) => (
            <button key={a.id} className={`cbb-btn ${i === selectedApp ? 'is-active' : ''}`} onClick={() => setSelectedApp(i)} title={a.name} style={i === selectedApp ? { color: a.color } : {}}>
              <Ico name={{ watchedit: 'film', podlink: 'radio', yourtube: 'tv', cyclismo: 'mountain' }[a.id]} size={16} />
            </button>
          ))}
        </div>
        <div className="cbb-divider" />
        <div className="cbb-group">
          <button className="cbb-btn" onClick={() => zoomTo(canvasRef.current.zoom - 0.1)} title="Zoom out"><Ico name="minus" size={16} /></button>
          <button className="cbb-zoom-display" onClick={() => zoomTo(1)} title="Reset zoom">{Math.round(canvasRef.current.zoom * 100)}%</button>
          <button className="cbb-btn" onClick={() => zoomTo(canvasRef.current.zoom + 0.1)} title="Zoom in"><Ico name="plus" size={16} /></button>
          <button className="cbb-btn" onClick={zoomToFit} title="Zoom to fit"><Ico name="maximize" size={16} /></button>
        </div>
        <div className="cbb-divider" />
        <div className="cbb-group">
          <button className={`cbb-btn ${chromeOn ? 'is-active' : ''}`} onClick={() => setChromeOn(!chromeOn)} title="Toggle device chrome"><Ico name="smartphone" size={16} /></button>
        </div>
      </div>

      {/* Right panel */}
      <div className="crp-panel">
        <div className="crp-tabs">
          <button className={`crp-tab ${panelTab === 'inspect' ? 'is-active' : ''}`} onClick={() => setPanelTab('inspect')}>Inspect</button>
          <button className={`crp-tab ${panelTab === 'design' ? 'is-active' : ''}`} onClick={() => setPanelTab('design')}>Design</button>
          <button className={`crp-tab ${panelTab === 'tokens' ? 'is-active' : ''}`} onClick={() => setPanelTab('tokens')}>Tokens</button>
        </div>
        <div className="crp-body">
          {panelTab === 'inspect' && (
            <div className="crp-tab-content is-active">
              {inspected ? (
                <>
                  <div className="insp-header">{inspected.data.el || 'Element'}</div>
                  <div className="insp-section">
                    <div className="insp-section-title">Computed</div>
                    <div className="insp-row"><span className="insp-label">Width</span><span className="insp-value">{inspected.computed.width}px</span></div>
                    <div className="insp-row"><span className="insp-label">Height</span><span className="insp-value">{inspected.computed.height}px</span></div>
                    <div className="insp-row"><span className="insp-label">Font Size</span><span className="insp-value">{inspected.computed.fontSize}</span></div>
                    <div className="insp-row"><span className="insp-label">Font Weight</span><span className="insp-value">{inspected.computed.fontWeight}</span></div>
                    {inspected.computed.borderRadius !== '0px' && <div className="insp-row"><span className="insp-label">Border Radius</span><span className="insp-value">{inspected.computed.borderRadius}</span></div>}
                  </div>
                  <div className="insp-section">
                    <div className="insp-section-title">Design Tokens</div>
                    {Object.entries(inspected.data).filter(([k]) => k !== 'el').map(([k, v]) => (
                      <div key={k} className="insp-row"><span className="insp-label">{TOKEN_MAP[k] || k}</span><span className="insp-value insp-val-token">{v}</span></div>
                    ))}
                  </div>
                  <div className="insp-section">
                    <div className="insp-section-title">CSS Class</div>
                    <div className="insp-classname">{inspected.className}</div>
                  </div>
                </>
              ) : (
                <div className="crp-empty">
                  <Ico name="mouse-pointer-click" size={32} />
                  <p>Click any element with a <code>data-ds</code> annotation to inspect its design tokens, spacing, and computed styles.</p>
                </div>
              )}
            </div>
          )}
          {panelTab === 'design' && (
            <div className="crp-tab-content is-active">
              <div className="crp-section">
                <div className="crp-section-title">Theme</div>
                <div className="crp-theme-chips">
                  {THEMES.map((t, i) => (
                    <button key={t.name} className={`crp-theme-chip ${i === selectedTheme ? 'is-active' : ''}`} onClick={() => setSelectedTheme(i)}>
                      <span className="crp-theme-swatch" style={{ background: t.swatch }} />
                      {t.name}
                    </button>
                  ))}
                </div>
              </div>
              <div className="crp-section">
                <div className="crp-section-title">Toolbar Style</div>
                <select className="crp-select" value={toolbarStyle} onChange={e => setToolbarStyle(e.target.value)}>
                  <option value="floating">Custom Floating Toolbar</option>
                  <option value="system">System Toolbar</option>
                </select>
              </div>
              <div className="crp-section">
                <div className="crp-section-title">Detail Layout</div>
                <select className="crp-select" value={detailLayout} onChange={e => setDetailLayout(e.target.value)}>
                  <option value="poster-focus">Poster Focus</option>
                  <option value="classic">Classic</option>
                  <option value="cinematic">Cinematic</option>
                  <option value="compact">Compact</option>
                  <option value="split">Split</option>
                </select>
              </div>
              <div className="crp-section">
                <div className="crp-section-title">Search Bar</div>
                <select className="crp-select" value={searchBarStyle} onChange={e => setSearchBarStyle(e.target.value)}>
                  <option value="glass">Glass</option>
                  <option value="classic">Classic</option>
                  <option value="solid">Solid</option>
                  <option value="elevated">Elevated</option>
                </select>
              </div>
              <div className="crp-section">
                <div className="crp-section-title">Action Bar</div>
                <select className="crp-select" value={actionBarAlign} onChange={e => setActionBarAlign(e.target.value)}>
                  <option value="leftAligned">Left Aligned</option>
                  <option value="centered">Centered</option>
                </select>
              </div>
            </div>
          )}
          {panelTab === 'tokens' && (
            <div className="crp-tab-content is-active">
              <div className="insp-section">
                <div className="insp-section-title">Spacing Scale (MinSpacing)</div>
                {Object.entries({ xs: S.xs, sm: S.sm, md: S.md, lg: S.lg, xl: S.xl, xxl: S.xxl, xxxl: S.xxxl }).map(([k, v]) => (
                  <div key={k} className="insp-row"><span className="insp-label">{k}</span><span className="insp-value insp-val-token">{v}pt</span></div>
                ))}
              </div>
              <div className="insp-section">
                <div className="insp-section-title">Corner Radius (MinCornerRadius)</div>
                {Object.entries(CR).map(([k, v]) => (
                  <div key={k} className="insp-row"><span className="insp-label">{k}</span><span className="insp-value insp-val-token">{v}pt</span></div>
                ))}
              </div>
              <div className="insp-section">
                <div className="insp-section-title">Layout Rules</div>
                <div className="insp-row"><span className="insp-label">Screen content margins</span><span className="insp-value insp-val-token">xl ({S.xl}pt)</span></div>
                <div className="insp-row"><span className="insp-label">Floating control insets</span><span className="insp-value insp-val-token">lg ({S.lg}pt)</span></div>
                <div className="insp-row"><span className="insp-label">Grid gutters</span><span className="insp-value insp-val-token">lg ({S.lg}pt)</span></div>
                <div className="insp-row"><span className="insp-label">Account button</span><span className="insp-value insp-val-token">{S.topControls.buttonSize}pt</span></div>
                <div className="insp-row"><span className="insp-label">Bottom safe area</span><span className="insp-value insp-val-token">{S.bottomSafeArea}pt</span></div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

// ── Main App ──
const PANELS = { Inspector: InspectorPanel, Colors: ColorsPanel, Spacing: SpacingPanel, Typography: TypographyPanel, Shadows: ShadowsPanel, Components: ComponentsPanel, Layouts: LayoutsPanel, Themes: ThemesPanel, Patterns: PatternsPanel, Apps: AppsPanel };

export default function App() {
  const [tab, setTab] = useState('Inspector');
  const Panel = PANELS[tab];
  const isInspector = tab === 'Inspector';
  return (
    <div className={`studio ${isInspector ? 'studio--canvas' : ''}`}>
      <header className="studio-header">
        <div className="studio-brand"><h1>Min Apps</h1><span className="studio-subtitle">Design Studio</span></div>
        <div className="studio-apps-row">
          {APPS.map(app => <span key={app.id} className="studio-app-badge" style={{ '--app-color': app.color }}>{app.label}</span>)}
        </div>
      </header>
      <nav className="studio-nav">
        {TABS.map(t => <button key={t} className={`nav-tab ${t === tab ? 'active' : ''}`} onClick={() => setTab(t)}>{t}</button>)}
      </nav>
      {isInspector ? <Panel /> : <main className="studio-main"><Panel /></main>}
    </div>
  );
}
