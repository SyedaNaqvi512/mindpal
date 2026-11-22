import { useState } from 'react'
import { api } from '../api'
import { DayArea, DayBars } from '../charts'
import type { Overview as O } from '../types'
import { Card, DaysPicker, greeting, Hero, State, Stat, todayLabel, useLoad } from '../ui'

const sum = (a: { count: number }[]) => a.reduce((s, x) => s + x.count, 0)

export default function Overview() {
  const [days, setDays] = useState(14)
  const { data, error, loading, reload } = useLoad(() => api<O>(`/admin/overview?days=${days}`), [days])

  return (
    <>
      <Hero
        title={`${greeting()}, Admin`}
        sub={data ? `${data.activeToday} people used MindPal today. ${todayLabel()}.` : todayLabel()}
      >
        <DaysPicker value={days} onChange={setDays} />
      </Hero>

      <div className="body">
        <State loading={loading && !data} error={error} retry={reload} skeleton="stats" />
        {data && (
          <>
            <div className="stats three lift">
              <Stat icon="users" tone="violet" label="Total users" value={data.totalUsers} hint={`${data.activeUsers} active accounts`} />
              <Stat icon="bolt" tone="teal" label="Active today" value={data.activeToday} hint="signed in or refreshed" trend={data.dailyActiveUsers} />
              <Stat icon="plus" tone="ember" label={`New in ${data.days} days`} value={sum(data.newRegistrations)} trend={data.newRegistrations} />
              <Stat icon="spark" tone="violet" label={`Reflections in ${data.days} days`} value={sum(data.reflectionsPerDay)} trend={data.reflectionsPerDay} />
              <Stat icon="lock" tone="rose" label="Suspended" value={data.suspendedUsers} hint={data.suspendedUsers ? 'can be reactivated' : 'none right now'} />
              <Stat icon="trash" tone="warn" label="Deletion requests" value={data.pendingDeletion} hint={data.pendingDeletion ? 'waiting for you' : 'nothing waiting'} />
            </div>
            <div className="grid">
              <Card icon="bolt" title="Daily active users" note={`last ${data.days} days`}><DayArea data={data.dailyActiveUsers} name="Active users" color="var(--c1)" /></Card>
              <Card icon="plus" title="New registrations" note={`last ${data.days} days`}><DayBars data={data.newRegistrations} name="Registrations" color="var(--c2)" /></Card>
              <Card icon="spark" title="Reflections per day" note="successful AI reflections" wide><DayArea data={data.reflectionsPerDay} name="Reflections" color="var(--c3)" /></Card>
            </div>
          </>
        )}
      </div>
    </>
  )
}
