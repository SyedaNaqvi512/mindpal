import { useState } from 'react'
import { api } from '../api'
import { DayBars, HBars, pretty } from '../charts'
import type { ExerciseStats, Safety } from '../types'
import { Card, DaysPicker, Hero, State, Stat, useLoad } from '../ui'

export default function SafetyExercises() {
  const [days, setDays] = useState(14)
  const sf = useLoad(() => api<Safety>(`/admin/safety?days=${days}`), [days])
  const ex = useLoad(() => api<ExerciseStats>('/admin/exercises'), [])

  return (
    <>
      <Hero title="Safety & exercises" sub="Anonymous counts. The server never stores who or what was involved.">
        <DaysPicker value={days} onChange={setDays} />
      </Hero>

      <div className="body">
        <State loading={sf.loading && !sf.data} error={sf.error} retry={sf.reload} skeleton="stats" />
        {sf.data && ex.data && (
          <div className="stats lift two">
            <Stat icon="heart" tone="rose" label="Safety screenings" value={sf.data.total} hint={`in the last ${sf.data.days} days`} trend={sf.data.perDay} />
            <Stat icon="check" tone="teal" label="Exercises completed" value={ex.data.total} hint="all time" />
          </div>
        )}
        {sf.data && (
          <div className="grid">
            <Card icon="heart" title="Safety screening events" note={`last ${sf.data.days} days`} wide>
              <DayBars data={sf.data.perDay} name="Events" color="var(--c4)" />
            </Card>
          </div>
        )}

        <State loading={ex.loading && !ex.data} error={ex.error} retry={ex.reload} />
        {ex.data && (
          <div className="grid">
            <Card icon="check" title="Completed per exercise" note="most used first" wide>
              {ex.data.items.length === 0 ? <p className="empty">No exercises completed yet.</p> :
                <HBars color="var(--c3)" items={ex.data.items.map((i) => ({ label: pretty(i.type), count: i.count }))} />}
            </Card>
          </div>
        )}
      </div>
    </>
  )
}
