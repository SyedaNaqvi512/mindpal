import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from 'react'
import * as api from './api'

type State = { status: 'loading' | 'out' | 'in'; email?: string }
const Ctx = createContext<{
  state: State
  signIn: (email: string, password: string) => Promise<void>
  signOut: () => Promise<void>
}>(null!)

export const useAuth = () => useContext(Ctx)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<State>({ status: 'loading' })

  useEffect(() => {
    if (!api.hasSession()) { setState({ status: 'out' }); return }
    api.restore().then((ok) => setState({ status: ok ? 'in' : 'out' }))
  }, [])

  const signIn = useCallback(async (email: string, password: string) => {
    const r = await api.login(email.trim(), password)
    setState({ status: 'in', email: r.user.email })
  }, [])

  const signOut = useCallback(async () => {
    await api.logout()
    setState({ status: 'out' })
  }, [])

  return <Ctx.Provider value={{ state, signIn, signOut }}>{children}</Ctx.Provider>
}
