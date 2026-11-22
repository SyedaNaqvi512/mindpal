import { mock, mockSignIn } from './mock'
import type { SignedIn } from './types'

const BASE = (import.meta.env.VITE_API_BASE_URL as string | undefined)?.replace(/\/$/, '') ?? 'http://localhost:5141'
export const MOCK = import.meta.env.VITE_MOCK === '1'

const RT_KEY = 'mindpal_admin_rt'
let access: string | null = null

export class ApiError extends Error {
  status: number
  code?: string
  constructor(status: number, message: string, code?: string) {
    super(message)
    this.status = status
    this.code = code
  }
}

const store = {
  get: () => { try { return sessionStorage.getItem(RT_KEY) } catch { return null } },
  set: (v: string | null) => { try { v ? sessionStorage.setItem(RT_KEY, v) : sessionStorage.removeItem(RT_KEY) } catch { /* private mode */ } },
}

async function raw(path: string, method: string, body?: unknown, token?: string | null): Promise<Response> {
  return fetch(BASE + path, {
    method,
    headers: {
      ...(body !== undefined ? { 'Content-Type': 'application/json' } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  })
}

async function fail(res: Response): Promise<never> {
  let msg = `Request failed (${res.status})`
  let code: string | undefined
  try {
    const j = await res.json()
    msg = j.detail || j.title || msg
    code = j.code
  } catch { /* no body */ }
  throw new ApiError(res.status, msg, code)
}

export async function login(email: string, password: string): Promise<SignedIn> {
  if (MOCK) { access = 'mock'; store.set('mock'); return mockSignIn(email) }
  let res: Response
  try { res = await raw('/auth/login', 'POST', { email, password }) }
  catch { throw new ApiError(0, 'Cannot reach the server. Check your connection and try again.') }
  if (!res.ok) await fail(res)
  const data = (await res.json()) as SignedIn
  if (data.user.role !== 'admin') {
    // Not an admin: drop the session straight away.
    await raw('/auth/logout', 'POST', { refreshToken: data.refreshToken }).catch(() => undefined)
    throw new ApiError(403, 'This account does not have admin access.', 'forbidden')
  }
  access = data.accessToken
  store.set(data.refreshToken)
  return data
}

async function refresh(): Promise<boolean> {
  const rt = store.get()
  if (!rt) return false
  if (MOCK) { access = 'mock'; return true }
  try {
    const res = await raw('/auth/refresh', 'POST', { refreshToken: rt })
    if (!res.ok) return false
    const data = (await res.json()) as SignedIn
    if (data.user.role !== 'admin') return false
    access = data.accessToken
    store.set(data.refreshToken)
    return true
  } catch { return false }
}

export const hasSession = () => store.get() !== null

export async function restore(): Promise<boolean> {
  return (await refresh())
}

export async function logout() {
  const rt = store.get()
  access = null
  store.set(null)
  if (rt && !MOCK) await raw('/auth/logout', 'POST', { refreshToken: rt }).catch(() => undefined)
}

export async function api<T>(path: string, method = 'GET'): Promise<T> {
  if (MOCK) {
    await new Promise((r) => setTimeout(r, 120))
    return mock(path, method) as T
  }
  let res: Response
  try { res = await raw(path, method, undefined, access) }
  catch { throw new ApiError(0, 'Cannot reach the server.') }

  if (res.status === 401 && (await refresh())) res = await raw(path, method, undefined, access)

  if (res.status === 401) { await logout(); throw new ApiError(401, 'Your session has ended. Please sign in again.') }
  if (!res.ok) await fail(res)
  if (res.status === 204) return undefined as T
  return (await res.json()) as T
}
