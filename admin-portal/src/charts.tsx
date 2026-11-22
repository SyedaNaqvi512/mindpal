import { Area, AreaChart, Bar, BarChart, CartesianGrid, Cell, Pie, PieChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'
import type { DayCount } from './types'
import { shortDate } from './ui'

const axis = { fontSize: 12, fill: 'var(--muted)' }
const tip = { contentStyle: { background: 'var(--card)', border: '1px solid var(--line)', borderRadius: 10, color: 'var(--text)' }, labelStyle: { color: 'var(--muted)' } }

export function DayArea({ data, color = 'var(--brand)', name }: { data: DayCount[]; color?: string; name: string }) {
  const d = data.map((x) => ({ ...x, label: shortDate(x.date) }))
  const id = 'g' + name.replace(/\W/g, '')
  return (
    <div className="chart" role="img" aria-label={`${name} per day`}>
      <ResponsiveContainer width="100%" height="100%">
        <AreaChart data={d} margin={{ top: 8, right: 8, left: -18, bottom: 0 }}>
          <defs>
            <linearGradient id={id} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor={color} stopOpacity={0.35} />
              <stop offset="100%" stopColor={color} stopOpacity={0.02} />
            </linearGradient>
          </defs>
          <CartesianGrid stroke="var(--line)" vertical={false} />
          <XAxis dataKey="label" tick={axis} tickLine={false} axisLine={false} minTickGap={18} />
          <YAxis tick={axis} tickLine={false} axisLine={false} allowDecimals={false} />
          <Tooltip {...tip} formatter={(v) => [v as number, name]} />
          <Area type="monotone" dataKey="count" stroke={color} strokeWidth={2.5} fill={`url(#${id})`} />
        </AreaChart>
      </ResponsiveContainer>
    </div>
  )
}

export function DayBars({ data, color = 'var(--brand)', name }: { data: DayCount[]; color?: string; name: string }) {
  const d = data.map((x) => ({ ...x, label: shortDate(x.date) }))
  return (
    <div className="chart" role="img" aria-label={`${name} per day`}>
      <ResponsiveContainer width="100%" height="100%">
        <BarChart data={d} margin={{ top: 8, right: 8, left: -18, bottom: 0 }}>
          <CartesianGrid stroke="var(--line)" vertical={false} />
          <XAxis dataKey="label" tick={axis} tickLine={false} axisLine={false} minTickGap={18} />
          <YAxis tick={axis} tickLine={false} axisLine={false} allowDecimals={false} />
          <Tooltip {...tip} cursor={{ fill: 'var(--hover)' }} formatter={(v) => [v as number, name]} />
          <Bar dataKey="count" fill={color} radius={[5, 5, 0, 0]} />
        </BarChart>
      </ResponsiveContainer>
    </div>
  )
}

export function HBars({ items, color = 'var(--brand)' }: { items: { label: string; count: number }[]; color?: string }) {
  const h = Math.max(160, items.length * 34 + 20)
  return (
    <div className="chart" style={{ height: h }} role="img" aria-label="Counts by category">
      <ResponsiveContainer width="100%" height="100%">
        <BarChart data={items} layout="vertical" margin={{ top: 0, right: 16, left: 0, bottom: 0 }}>
          <CartesianGrid stroke="var(--line)" horizontal={false} />
          <XAxis type="number" tick={axis} tickLine={false} axisLine={false} allowDecimals={false} />
          <YAxis type="category" dataKey="label" width={118} tick={axis} tickLine={false} axisLine={false} />
          <Tooltip {...tip} cursor={{ fill: 'var(--hover)' }} />
          <Bar dataKey="count" fill={color} radius={[0, 5, 5, 0]} />
        </BarChart>
      </ResponsiveContainer>
    </div>
  )
}

export function Donut({ helpful, notHelpful }: { helpful: number; notHelpful: number }) {
  const data = [{ name: 'Helpful', v: helpful, c: 'var(--good)' }, { name: 'Not helpful', v: notHelpful, c: 'var(--c2)' }]
  return (
    <div className="chart donut" role="img" aria-label="Helpful versus not helpful">
      <ResponsiveContainer width="100%" height="100%">
        <PieChart>
          <Pie data={data} dataKey="v" innerRadius="62%" outerRadius="88%" paddingAngle={3} stroke="none">
            {data.map((d) => <Cell key={d.name} fill={d.c} />)}
          </Pie>
          <Tooltip {...tip} />
        </PieChart>
      </ResponsiveContainer>
    </div>
  )
}

export const pretty = (s: string) => s.replace(/_/g, ' ').replace(/^./, (c) => c.toUpperCase())
