import { api } from '../api'
import type { Health } from '../types'
import { Card, Hero, State, Stat, useLoad } from '../ui'
import { Icon } from '../icons'

export default function HealthPage() {
  const { data, error, loading, reload } = useLoad(() => api<Health>('/admin/health'), [])
  const ok = data ? data.api === 'ok' && data.database === 'ok' : true
  const calm = data ? data.serverErrors24h === 0 : true

  return (
    <>
      <Hero title="System health" sub="Checked when you open or refresh this page.">
        <button className="btn glass" onClick={reload}>Refresh</button>
      </Hero>

      <div className="body">
        <State loading={loading && !data} error={error} retry={reload} skeleton="stats" />
        {data && (
          <>
            <div className={`banner lift ${ok ? 'good' : 'bad'}`}>
              <span className="banner-ico"><Icon name={ok ? 'check' : 'alert'} size={26} /></span>
              <div>
                <b>{ok ? 'Everything is running' : 'Something needs attention'}</b>
                <span>{ok ? (calm ? 'The API and database are healthy, with no server errors in the last 24 hours.' : 'The API and database are healthy, but some server errors were recorded.') : 'The API or the database is not responding as expected.'}</span>
              </div>
            </div>
            <div className="stats five">
              <Stat icon="pulse" tone={data.api === 'ok' ? 'good' : 'rose'} label="API" value={data.api === 'ok' ? 'Running' : 'Problem'} />
              <Stat icon="grid" tone={data.database === 'ok' ? 'good' : 'rose'} label="Database" value={data.database === 'ok' ? 'Connected' : 'Down'} />
              <Stat icon="alert" tone={data.serverErrors24h ? 'warn' : 'good'} label="Server errors" value={data.serverErrors24h} hint="last 24 hours" />
              <Stat icon="spark" tone={data.aiErrors24h ? 'warn' : 'good'} label="AI errors" value={data.aiErrors24h} hint="errors and timeouts, 24 hours" />
              <Stat icon="lock" tone={data.aiRateLimited24h ? 'rose' : 'good'} label="AI rate limited" value={data.aiRateLimited24h} hint="last 24 hours" />
            </div>
            <div className="grid">
              <Card icon="pulse" title="Good to know" wide>
                <p className="muted">Server errors are counted since the server last started. AI errors and rate limits come from the usage log, so they survive a restart.</p>
              </Card>
            </div>
          </>
        )}
      </div>
    </>
  )
}
