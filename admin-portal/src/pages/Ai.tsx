import { useState } from 'react'
import { api } from '../api'
import { DayBars, Donut, HBars, pretty } from '../charts'
import type { AiUsage, FeedbackStats } from '../types'
import { Card, DaysPicker, Hero, State, Stat, useLoad } from '../ui'

export default function Ai() {
  const [days, setDays] = useState(14)
  const ai = useLoad(() => api<AiUsage>(`/admin/ai-usage?days=${days}`), [days])
  const fb = useLoad(() => api<FeedbackStats>('/admin/feedback'), [])

  return (
    <>
      <Hero title="AI & feedback" sub="How the reflection assistant is used and rated. No entry text is shown.">
        <DaysPicker value={days} onChange={setDays} />
      </Hero>

      <div className="body">
        <State loading={ai.loading && !ai.data} error={ai.error} retry={ai.reload} skeleton="stats" />
        {ai.data && (
          <>
            <div className="stats lift">
              <Stat icon="spark" tone="violet" label="AI requests" value={ai.data.requests} trend={ai.data.requestsPerDay} />
              <Stat icon="bolt" tone="teal" label="Average response" value={`${(ai.data.averageMs / 1000).toFixed(1)} s`} hint="successful requests" />
              <Stat icon="alert" tone={ai.data.errors ? 'warn' : 'good'} label="Errors and timeouts" value={ai.data.errors} hint={ai.data.errors ? 'worth watching' : 'all clear'} />
              <Stat icon="lock" tone={ai.data.rateLimited ? 'rose' : 'good'} label="Rate limited" value={ai.data.rateLimited} hint="requests turned away" />
            </div>
            <div className="grid">
              <Card icon="chart" title="AI requests per day" note={`last ${ai.data.days} days`} wide><DayBars data={ai.data.requestsPerDay} name="Requests" color="var(--c1)" /></Card>
            </div>
          </>
        )}

        <State loading={fb.loading && !fb.data} error={fb.error} retry={fb.reload} />
        {fb.data && (
          <div className="grid">
            <Card icon="heart" title="Were reflections helpful?" note={`${fb.data.total} ratings`}>
              {fb.data.total === 0 ? <p className="empty">No ratings yet. They appear when people rate a reflection.</p> : (
                <div className="donut-row">
                  <div className="donut-wrap">
                    <Donut helpful={fb.data.helpful} notHelpful={fb.data.notHelpful} />
                    <div className="donut-mid"><strong>{fb.data.helpfulPercent}%</strong><span>helpful</span></div>
                  </div>
                  <ul className="legend">
                    <li><i style={{ background: 'var(--good)' }} />Helpful <b>{fb.data.helpful}</b></li>
                    <li><i style={{ background: 'var(--c2)' }} />Not helpful <b>{fb.data.notHelpful}</b></li>
                  </ul>
                </div>
              )}
            </Card>
            <Card icon="alert" title="Why not helpful" note="reason categories">
              {fb.data.reasons.length === 0 ? <p className="empty">No reasons given yet.</p> :
                <HBars color="var(--c2)" items={fb.data.reasons.map((r) => ({ label: pretty(r.reason), count: r.count }))} />}
            </Card>
          </div>
        )}
      </div>
    </>
  )
}
