import { useState, type FormEvent } from 'react'
import { useAuth } from '../auth'
import { Icon } from '../icons'

export default function Login() {
  const { signIn } = useAuth()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [show, setShow] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  async function submit(e: FormEvent) {
    e.preventDefault()
    setBusy(true)
    setError(null)
    try { await signIn(email, password) }
    catch (err) {
      const m = (err as Error).message
      setError(/invalid|credential/i.test(m) ? 'Email or password is not correct.' : m)
    } finally { setBusy(false) }
  }

  return (
    <main className="login">
      <section className="login-art">
        <i className="c1" /><i className="c2" /><i className="c3" />
        <div className="art-in">
          <img className="art-logo" src="/logo.png" width="84" height="84" alt="MindPal" />
          <h1>MindPal Admin</h1>
          <p className="art-lead">See how MindPal is doing and look after its users, without ever seeing what they write.</p>
          <ul className="art-points">
            <li><span><Icon name="eye" size={18} /></span><div><b>No journal text</b><small>Only counts and account details are shown.</small></div></li>
            <li><span><Icon name="lock" size={18} /></span><div><b>Admin accounts only</b><small>Access is checked again on every request.</small></div></li>
            <li><span><Icon name="chart" size={18} /></span><div><b>Daily numbers, Pakistan time</b><small>Active users, reflections and exercises.</small></div></li>
          </ul>
        </div>
      </section>

      <section className="login-form-side">
        <form className="login-card" onSubmit={submit}>
          <div className="mobile-logo"><img src="/logo.png" width="64" height="64" alt="MindPal" /></div>
          <h2>Welcome back</h2>
          <p className="muted">Sign in with your administrator account.</p>

          <label>Email
            <span className="field"><Icon name="user" size={18} />
              <input type="email" autoComplete="username" required placeholder="admin@example.com" value={email} onChange={(e) => setEmail(e.target.value)} />
            </span>
          </label>
          <label>Password
            <span className="field"><Icon name="lock" size={18} />
              <input type={show ? 'text' : 'password'} autoComplete="current-password" required placeholder="Your password" value={password} onChange={(e) => setPassword(e.target.value)} />
              <button type="button" className="eye" aria-label={show ? 'Hide password' : 'Show password'} onClick={() => setShow((s) => !s)}><Icon name="eye" size={18} /></button>
            </span>
          </label>

          {error && <div className="form-error" role="alert"><Icon name="alert" size={16} />{error}</div>}

          <button className="btn primary big" disabled={busy}>{busy ? 'Signing in' : 'Sign in'}</button>
          <p className="fine">MindPal is a journaling and reflection aid. It is not therapy.</p>
        </form>
      </section>
    </main>
  )
}
