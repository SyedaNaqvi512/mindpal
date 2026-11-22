export type Role = 'user' | 'admin'
export type Status = 'active' | 'suspended' | 'pending_deletion'

export interface DayCount { date: string; count: number }

export interface Overview {
  days: number
  totalUsers: number
  activeUsers: number
  suspendedUsers: number
  pendingDeletion: number
  activeToday: number
  newRegistrations: DayCount[]
  dailyActiveUsers: DayCount[]
  reflectionsPerDay: DayCount[]
}

export interface UserRow {
  id: string
  email: string
  displayName: string
  role: Role
  status: Status
  emailVerified: boolean
  createdAt: string
  deletionRequestedAt: string | null
}

export interface UserPage { total: number; page: number; pageSize: number; items: UserRow[] }

export interface AiUsage {
  days: number
  requests: number
  successes: number
  errors: number
  rateLimited: number
  averageMs: number
  requestsPerDay: DayCount[]
}

export interface Safety { days: number; total: number; perDay: DayCount[] }

export interface Health {
  api: string
  database: string
  serverErrors24h: number
  aiErrors24h: number
  aiRateLimited24h: number
  serverTime: string
}

export interface FeedbackStats {
  total: number
  helpful: number
  notHelpful: number
  helpfulPercent: number
  reasons: { reason: string; count: number }[]
}

export interface ExerciseStats { total: number; items: { type: string; count: number }[] }

export interface SignedIn {
  accessToken: string
  expiresIn: number
  refreshToken: string
  user: { id: string; displayName: string; email: string; role: Role }
}
