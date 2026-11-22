// Sample data used only when VITE_MOCK=1 (for screenshots and demos
// without a server). It contains no real people.
import type { AiUsage, DayCount, ExerciseStats, FeedbackStats, Health, Overview, Safety, SignedIn, UserPage, UserRow } from './types'

const day = (back: number) => {
  const d = new Date(Date.now() + 5 * 3600_000)
  d.setUTCDate(d.getUTCDate() - back)
  return d.toISOString().slice(0, 10)
}

const series = (n: number, f: (i: number) => number): DayCount[] =>
  Array.from({ length: n }, (_, i) => ({ date: day(n - 1 - i), count: Math.max(0, Math.round(f(i))) }))

const names = ['Ayesha', 'Hamza', 'Sana', 'Bilal', 'Hira', 'Usman', 'Maryam', 'Zain', 'Noor', 'Fahad', 'Iqra', 'Talha', 'Laiba', 'Saad', 'Areeba', 'Daniyal', 'Kinza', 'Rehan', 'Mahnoor', 'Haris', 'Alina', 'Shahzaib', 'Zoya', 'Ammar', 'Esha']

const users: UserRow[] = names.map((n, i) => ({
  id: `00000000-0000-4000-8000-${String(i).padStart(12, '0')}`,
  email: `${n.toLowerCase()}${i + 10}@example.com`,
  displayName: n,
  role: 'user',
  status: i === 3 ? 'suspended' : i === 7 || i === 12 ? 'pending_deletion' : 'active',
  emailVerified: i % 6 !== 5,
  createdAt: new Date(Date.now() - i * 86400_000 * 1.7).toISOString(),
  deletionRequestedAt: i === 7 || i === 12 ? new Date(Date.now() - 3600_000 * 5).toISOString() : null,
}))

export const mockSignIn = (email: string): SignedIn => ({
  accessToken: 'mock', expiresIn: 900, refreshToken: 'mock',
  user: { id: 'a', displayName: 'Admin', email, role: 'admin' },
})

export function mock(path: string, method: string): unknown {
  const p = path.split('?')[0]
  const q = new URLSearchParams(path.split('?')[1] ?? '')
  const n = Number(q.get('days') ?? 14)

  if (p === '/admin/overview') {
    const o: Overview = {
      days: n, totalUsers: users.length * 4 + 3, activeUsers: users.length * 4 - 4, suspendedUsers: 1, pendingDeletion: 2, activeToday: 17,
      newRegistrations: series(n, (i) => 2 + 3 * Math.abs(Math.sin(i * 1.3))),
      dailyActiveUsers: series(n, (i) => 9 + i * 0.7 + 4 * Math.sin(i)),
      reflectionsPerDay: series(n, (i) => 14 + i * 1.2 + 6 * Math.cos(i * 0.8)),
    }
    return o
  }
  if (p === '/admin/users') {
    const s = (q.get('search') ?? '').toLowerCase()
    const list = users.filter((u) => u.email.includes(s))
    const page = Number(q.get('page') ?? 1), size = Number(q.get('pageSize') ?? 20)
    const r: UserPage = { total: list.length, page, pageSize: size, items: list.slice((page - 1) * size, page * size) }
    return r
  }
  if (p.startsWith('/admin/users/') && method === 'POST') {
    const [, , , id, action] = p.split('/')
    const u = users.find((x) => x.id === id)
    if (u) u.status = action === 'suspend' ? 'suspended' : action === 'reactivate' ? 'active' : u.status
    if (u && action === 'process-deletion') users.splice(users.indexOf(u), 1)
    return null
  }
  if (p === '/admin/ai-usage') {
    const r: AiUsage = { days: n, requests: 412, successes: 388, errors: 17, rateLimited: 7, averageMs: 3140, requestsPerDay: series(n, (i) => 20 + i + 8 * Math.sin(i)) }
    return r
  }
  if (p === '/admin/safety') {
    const r: Safety = { days: n, total: 9, perDay: series(n, (i) => (i % 5 === 2 ? 2 : i % 3 === 0 ? 1 : 0)) }
    return r
  }
  if (p === '/admin/health') {
    const r: Health = { api: 'ok', database: 'ok', serverErrors24h: 0, aiErrors24h: 2, aiRateLimited24h: 1, serverTime: new Date().toISOString() }
    return r
  }
  if (p === '/admin/feedback') {
    const r: FeedbackStats = {
      total: 120, helpful: 94, notHelpful: 26, helpfulPercent: 78.3,
      reasons: [{ reason: 'too_generic', count: 11 }, { reason: 'not_relevant', count: 7 }, { reason: 'too_long', count: 5 }, { reason: 'other', count: 3 }],
    }
    return r
  }
  if (p === '/admin/exercises') {
    const r: ExerciseStats = {
      total: 233,
      items: [['breathing', 61], ['grounding', 38], ['thought_record', 31], ['sort', 24], ['gratitude', 22], ['body_scan', 17], ['check_in', 14], ['belief', 9], ['scale', 8], ['stop', 5], ['self_compassion', 3], ['anchor', 1]].map(([type, count]) => ({ type: type as string, count: count as number })),
    }
    return r
  }
  return null
}
