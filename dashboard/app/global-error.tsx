'use client'

export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  return (
    <html>
      <body style={{ background: '#0a0a0a', color: '#e5e5e5', padding: 40, fontFamily: 'monospace' }}>
        <h2>Something went wrong!</h2>
        <pre style={{ color: '#EF4444', whiteSpace: 'pre-wrap', marginTop: 16 }}>
          {error.message}
        </pre>
        <pre style={{ color: '#888', whiteSpace: 'pre-wrap', marginTop: 8, fontSize: 12 }}>
          {error.stack}
        </pre>
        <button
          onClick={reset}
          style={{ marginTop: 16, padding: '8px 16px', background: '#3B82F6', color: '#fff', border: 'none', borderRadius: 8, cursor: 'pointer' }}
        >
          Try again
        </button>
      </body>
    </html>
  )
}
