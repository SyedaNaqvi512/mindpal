import { createContext, useCallback, useContext, useEffect, useRef, useState, type ReactNode } from 'react'
import { Area, AreaChart, ResponsiveContainer } from 'recharts'
import { Icon } from './icons'
import type { DayCount } from './types'

// ---------- toasts ----------
type Toast = { id: number; text: string; kind: 'ok' | 'error' }
const ToastCtx = createContext<(text: string, kind?: Toast['kind']) => void>(() => undefined)
export const useToast = () => useContext(ToastCtx)

export function ToastProvider({ children }: { children: ReactNode }) {
  const [items, setItems] = useState<Toast[]>([])
  const next = useRef(1)

  const push = useCallback((text: string, kind: Toast['kind'] = 'ok') => {
    const id = next.current++
    setItems((l) => [...l, { id, text, kind }])
    setTimeout(() => setItems((l) => l.filter((t) => t.id !== id)), 4000)
  }, [])

  return (
    <ToastCtx.Provider value={push}>
      {children}
      <div className="toasts" role="status" aria-live="polite">
        {items.map((t) => (
          <div key={t.id} className={`toast ${t.kind}`}>
            <span className="toast-ico"><Icon name={t.kind === 'ok' ? 'check' : 'alert'} size={16} /></span>
            {t.text}
          </div>
        ))}
      </div>
    </ToastCtx.Provider>
  )
}

// ---------- data loading ----------
export function useLoad<T>(load: () => Promise<T>, deps: unknown[]) {
  const [data, setData] = useState<T | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)
  const [tick, setTick] = useState(0)

  useEffect(() => {
    let live = true
    setLoading(true)
    load()
      .then((d) => { if (live) { setData(d); setError(null) } })
      .catch((e: Error) => { if (live) setError(e.message) })
      .finally(() => { if (live) setLoading(false) })
    return () => { live = false }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [...deps, tick])

  return { data, error, loading, reload: () => setTick((t) => t + 1) }
}

// ---------- page frame ----------
// A brand header like the one in the phone app; the content below overlaps it.
export function Hero({ title, sub, children, extra }: { title: string; sub: string; children?: ReactNode; extra?: ReactNode }) {
  return (
    <div className="hero">
      <i className="c1" /><i className="c2" /><i className="c3" />
      <div className="hero-in">
        <div className="hero-text">
          <h1>{title}</h1>
          <p>{sub}</p>
          {extra}
        </div>
        {children && <div className="hero-tools">{children}</div>}
      </div>
    </div>
  )
}

export function Card({ title, note, children, wide, icon }: { title: string; note?: string; children: ReactNode; wide?: boolean; icon?: string }) {
  return (
    <section className={`card${wide ? ' wide' : ''}`}>
      <header>
        <h3>{icon && <span className="h-ico"><Icon name={icon} size={16} /></span>}{title}</h3>
        {note && <span className="note">{note}</span>}
      </header>
      {children}
    </section>
  )
}

type Tone = 'violet' | 'ember' | 'teal' | 'rose' | 'good' | 'warn'

export function Stat({ label, value, hint, icon, tone = 'violet', trend }: {
  label: string; value: string | number; hint?: string; icon: string; tone?: Tone; trend?: DayCount[]
}) {
  return (
    <div className={`stat t-${tone}`}>
      <div className="stat-top">
        <span className="badge"><Icon name={icon} size={20} /></span>
        {trend && trend.length > 1 && (
          <div className="spark" aria-hidden="true">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={trend} margin={{ top: 2, right: 0, left: 0, bottom: 2 }}>
                <Area type="monotone" dataKey="count" stroke="var(--tone)" strokeWidth={2} fill="var(--tone)" fillOpacity={0.14} isAnimationActive={false} />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        )}
      </div>
      <strong>{value}</strong>
      <span className="label">{label}</span>
      {hint && <span className="hint">{hint}</span>}
    </div>
  )
}

export function State({ loading, error, retry, skeleton }: { loading: boolean; error: string | null; retry: () => void; skeleton?: 'stats' }) {
  if (loading) {
    return skeleton === 'stats'
      ? <div className="stats lift" aria-busy="true">{Array.from({ length: 6 }, (_, i) => <div key={i} className="stat skel" />)}</div>
      : <div className="state" aria-busy="true"><span className="spinner" /> Loading</div>
  }
  if (error) return (
    <div className="state error">
      <span className="state-ico"><Icon name="alert" size={26} /></span>
      <p>{error}</p>
      <button className="btn" onClick={retry}>Try again</button>
    </div>
  )
  return null
}

export function DaysPicker({ value, onChange }: { value: number; onChange: (n: number) => void }) {
  return (
    <div className="seg" role="group" aria-label="Time range">
      {[7, 14, 30, 90].map((n) => (
        <button key={n} className={n === value ? 'on' : ''} aria-pressed={n === value} onClick={() => onChange(n)}>{n} days</button>
      ))}
    </div>
  )
}

export const shortDate = (iso: string) => {
  const [, m, d] = iso.split('-')
  return `${Number(d)}/${Number(m)}`
}

export function greeting() {
  const h = new Date(Date.now() + 5 * 3600_000).getUTCHours()
  return h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening'
}

export function todayLabel() {
  return new Date().toLocaleDateString('en-GB', { weekday: 'long', day: 'numeric', month: 'long', timeZone: 'Asia/Karachi' })
}
