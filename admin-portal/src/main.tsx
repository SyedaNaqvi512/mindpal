import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { HashRouter, Navigate, Route, Routes } from 'react-router-dom'
import './index.css'
import { AuthProvider, useAuth } from './auth'
import { ToastProvider } from './ui'
import Shell from './Shell'
import Login from './pages/Login'
import Overview from './pages/Overview'
import Users from './pages/Users'
import Ai from './pages/Ai'
import SafetyExercises from './pages/SafetyExercises'
import HealthPage from './pages/Health'

function Gate() {
  const { state } = useAuth()
  if (state.status === 'loading') return <div className="state full"><span className="spinner" /> Loading…</div>
  if (state.status === 'out') return <Login />
  return (
    <Routes>
      <Route element={<Shell />}>
        <Route index element={<Overview />} />
        <Route path="users" element={<Users />} />
        <Route path="ai" element={<Ai />} />
        <Route path="safety" element={<SafetyExercises />} />
        <Route path="health" element={<HealthPage />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Route>
    </Routes>
  )
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <HashRouter>
      <ToastProvider>
        <AuthProvider>
          <Gate />
        </AuthProvider>
      </ToastProvider>
    </HashRouter>
  </StrictMode>,
)
