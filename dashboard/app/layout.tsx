import type { Metadata } from 'next'
import './globals.css'
import { DashboardProvider } from '@/components/providers/DashboardProvider'
import DashboardLayout from '@/components/layout/DashboardLayout'
import ErrorBoundary from '@/components/ErrorBoundary'

export const metadata: Metadata = {
  title: 'SwasthiCare Analytics',
  description: 'App events overview dashboard',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className="antialiased" suppressHydrationWarning>
        <ErrorBoundary>
          <DashboardProvider>
            <DashboardLayout>{children}</DashboardLayout>
          </DashboardProvider>
        </ErrorBoundary>
      </body>
    </html>
  )
}
