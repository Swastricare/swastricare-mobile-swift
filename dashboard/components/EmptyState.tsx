'use client'

interface EmptyStateProps {
  message?: string
}

export default function EmptyState({ message = 'No data available' }: EmptyStateProps) {
  return (
    <div className="py-12 text-center">
      <p className="text-sm text-neutral-500">{message}</p>
    </div>
  )
}
