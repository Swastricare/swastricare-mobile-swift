'use client'

import { format, parseISO } from 'date-fns'

interface ErrorEvent {
  name: string
  properties: Record<string, string> | null
  created_at: string
  user_id: string | null
}

interface ErrorsTableProps {
  data: ErrorEvent[]
}

export function ErrorsTable({ data }: ErrorsTableProps) {
  return (
    <div className="rounded-xl bg-white/5 p-5">
      <h3 className="mb-4 text-sm font-medium text-neutral-400">
        Recent Errors ({data.length})
      </h3>
      {data.length === 0 ? (
        <p className="text-sm text-neutral-500">No errors in this period</p>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-white/10 text-left text-neutral-400">
                <th className="pb-2 pr-4 font-medium">Event</th>
                <th className="pb-2 pr-4 font-medium">Details</th>
                <th className="pb-2 pr-4 font-medium">User</th>
                <th className="pb-2 font-medium">Time</th>
              </tr>
            </thead>
            <tbody>
              {data.map((err, i) => (
                <tr key={i} className="border-b border-white/5">
                  <td className="py-2 pr-4">
                    <span className="rounded bg-red-500/20 px-2 py-0.5 text-xs text-red-400">
                      {err.name}
                    </span>
                  </td>
                  <td className="max-w-xs truncate py-2 pr-4 text-neutral-400">
                    {err.properties
                      ? Object.entries(err.properties)
                          .map(([k, v]) => `${k}: ${v}`)
                          .join(', ')
                      : '-'}
                  </td>
                  <td className="py-2 pr-4 font-mono text-xs text-neutral-500">
                    {err.user_id ? err.user_id.slice(0, 8) + '...' : 'anon'}
                  </td>
                  <td className="py-2 text-neutral-500">
                    {format(parseISO(err.created_at), 'MMM d, HH:mm')}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
