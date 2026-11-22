import { useEffect, useState } from 'react'
import { ApiError, api } from '../api'
import { Icon } from '../icons'
import type { UserPage, UserRow } from '../types'
import { Hero, State, useLoad, useToast } from '../ui'

const label: Record<string, string> = { active: 'Active', suspended: 'Suspended', pending_deletion: 'Deletion requested' }
const fmt = (iso: string) => new Date(iso).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric', timeZone: 'Asia/Karachi' })
const tints = ['#7B49A3', '#F2853B', '#4F9D8F', '#D8567A', '#5B3880', '#9A6FD0']
const tint = (s: string) => tints[[...s].reduce((a, c) => a + c.charCodeAt(0), 0) % tints.length]

type Pending = { user: UserRow; action: 'suspend' | 'reactivate' | 'process-deletion' }

const copy = {
  suspend: { title: 'Suspend this account?', body: 'They will be signed out and cannot sign in until you reactivate them.', btn: 'Suspend', done: 'Account suspended', danger: true, icon: 'lock' },
  reactivate: { title: 'Reactivate this account?', body: 'They will be able to sign in again.', btn: 'Reactivate', done: 'Account reactivated', danger: false, icon: 'check' },
  'process-deletion': { title: 'Delete this account now?', body: 'All of their server data is removed permanently. This cannot be undone.', btn: 'Delete permanently', done: 'Account deleted', danger: true, icon: 'trash' },
}

export default function Users() {
  const toast = useToast()
  const [input, setInput] = useState('')
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(1)
  const [pending, setPending] = useState<Pending | null>(null)
  const [busy, setBusy] = useState(false)

  // wait a moment after typing before searching
  useEffect(() => {
    const t = setTimeout(() => { setSearch(input.trim()); setPage(1) }, 300)
    return () => clearTimeout(t)
  }, [input])

  const { data, error, loading, reload } = useLoad(
    () => api<UserPage>(`/admin/users?search=${encodeURIComponent(search)}&page=${page}&pageSize=15`),
    [search, page],
  )

  async function confirm() {
    if (!pending) return
    setBusy(true)
    try {
      await api(`/admin/users/${pending.user.id}/${pending.action}`, 'POST')
      toast(copy[pending.action].done)
      setPending(null)
      reload()
    } catch (e) {
      toast(e instanceof ApiError ? e.message : 'Something went wrong. Try again.', 'error')
    } finally { setBusy(false) }
  }

  const pages = data ? Math.max(1, Math.ceil(data.total / data.pageSize)) : 1

  return (
    <>
      <Hero title="Users" sub="Account details only. Journal entries are never stored on the server.">
        <label className="hero-search"><Icon name="search" size={18} />
          <input type="search" placeholder="Search by email" aria-label="Search by email" value={input} onChange={(e) => setInput(e.target.value)} />
        </label>
      </Hero>

      <div className="body">
        <State loading={loading && !data} error={error} retry={reload} />
        {data && (
          <section className="card flush lift">
            <div className="card-bar">
              <h3>{search ? `Results for “${search}”` : 'All accounts'}</h3>
              <span className="note">{data.total} user{data.total === 1 ? '' : 's'}</span>
            </div>
            {data.items.length === 0 ? (
              <div className="empty pad"><Icon name="search" size={28} /><p>No one matches “{search}”.</p><span className="muted small">Check the spelling or try a shorter part of the email.</span></div>
            ) : (
              <div className="table-wrap">
                <table>
                  <thead><tr><th>User</th><th>Status</th><th>Joined</th><th aria-label="Actions" /></tr></thead>
                  <tbody>
                    {data.items.map((u) => (
                      <tr key={u.id}>
                        <td>
                          <div className="user-cell">
                            <span className="avatar" style={{ background: tint(u.email) }}>{(u.displayName || u.email)[0].toUpperCase()}</span>
                            <div>
                              <div className="who"><b>{u.displayName}</b>{u.role === 'admin' && <span className="pill admin">Admin</span>}</div>
                              <span className="muted small">{u.email}{!u.emailVerified && <em className="unv">Not verified</em>}</span>
                            </div>
                          </div>
                        </td>
                        <td>
                          <span className={`pill ${u.status}`}>{label[u.status]}</span>
                          {u.deletionRequestedAt && <div className="muted small">asked {fmt(u.deletionRequestedAt)}</div>}
                        </td>
                        <td className="nowrap muted">{fmt(u.createdAt)}</td>
                        <td className="actions">
                          {u.role !== 'admin' && u.status === 'active' && <button className="btn sm" onClick={() => setPending({ user: u, action: 'suspend' })}>Suspend</button>}
                          {u.status === 'suspended' && <button className="btn sm" onClick={() => setPending({ user: u, action: 'reactivate' })}>Reactivate</button>}
                          {u.role !== 'admin' && u.status === 'pending_deletion' && <button className="btn sm danger" onClick={() => setPending({ user: u, action: 'process-deletion' })}>Process deletion</button>}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
            <footer className="pager">
              <span className="muted small">Page {page} of {pages}</span>
              <div>
                <button className="btn sm" disabled={page <= 1} onClick={() => setPage(page - 1)}>Previous</button>
                <button className="btn sm" disabled={page >= pages} onClick={() => setPage(page + 1)}>Next</button>
              </div>
            </footer>
          </section>
        )}
      </div>

      {pending && (
        <div className="modal-back" onClick={() => !busy && setPending(null)}>
          <div className="modal" role="dialog" aria-modal="true" aria-label={copy[pending.action].title} onClick={(e) => e.stopPropagation()}>
            <span className={`modal-ico ${copy[pending.action].danger ? 'danger' : ''}`}><Icon name={copy[pending.action].icon} size={24} /></span>
            <h3>{copy[pending.action].title}</h3>
            <p className="modal-user">{pending.user.email}</p>
            <p className="muted">{copy[pending.action].body}</p>
            <div className="modal-actions">
              <button className="btn" disabled={busy} onClick={() => setPending(null)}>Cancel</button>
              <button className={`btn ${copy[pending.action].danger ? 'danger solid' : 'primary'}`} disabled={busy} onClick={confirm}>{busy ? 'Working' : copy[pending.action].btn}</button>
            </div>
          </div>
        </div>
      )}
    </>
  )
}
