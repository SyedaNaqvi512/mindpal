import { useState } from 'react'
import { NavLink, Outlet } from 'react-router-dom'
import { useAuth } from './auth'
import { Icon } from './icons'

export function Logo({ light }: { light?: boolean }) {
  return (
    <div className={`logo${light ? ' light' : ''}`}>
      <img src="/logo.png" width="38" height="38" alt="" />
      <span>MindPal <em>Admin</em></span>
    </div>
  )
}

const links: [string, string, string][] = [
  ['/', 'Overview', 'grid'],
  ['/users', 'Users', 'users'],
  ['/ai', 'AI & feedback', 'spark'],
  ['/safety', 'Safety & exercises', 'heart'],
  ['/health', 'System health', 'pulse'],
]

export default function Shell() {
  const { state, signOut } = useAuth()
  const [open, setOpen] = useState(false)
  const initial = (state.email ?? 'A')[0].toUpperCase()

  return (
    <div className="shell">
      <header className="topbar">
        <button className="icon-btn" aria-label="Open menu" onClick={() => setOpen(true)}><Icon name="menu" size={24} /></button>
        <Logo />
      </header>

      <aside className={`side${open ? ' open' : ''}`}>
        <i className="sc1" /><i className="sc2" />
        <div className="side-logo"><Logo light /></div>
        <nav onClick={() => setOpen(false)} aria-label="Main">
          {links.map(([to, label, icon]) => (
            <NavLink key={to} to={to} end={to === '/'} className={({ isActive }) => (isActive ? 'active' : '')}>
              <Icon name={icon} size={20} />{label}
            </NavLink>
          ))}
        </nav>
        <div className="side-note"><Icon name="shield" size={18} /><span>Counts only. Journal text never reaches this site.</span></div>
        <div className="side-foot">
          <span className="avatar">{initial}</span>
          <div className="who-me"><b>Administrator</b><span title={state.email}>{state.email}</span></div>
          <button className="icon-btn light" onClick={signOut} aria-label="Sign out" title="Sign out"><Icon name="out" size={20} /></button>
        </div>
      </aside>
      {open && <div className="scrim" onClick={() => setOpen(false)} />}

      <main className="content"><Outlet /></main>
    </div>
  )
}
