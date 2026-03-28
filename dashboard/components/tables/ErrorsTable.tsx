'use client'

import { useState, useMemo } from 'react'
import { format, parseISO } from 'date-fns'
import PlatformBadge from '@/components/PlatformBadge'

interface ErrorLogEntry {
  name: string
  message: string
  properties: Record<string, any> | null
  created_at: string
  user_id: string | null
  platform: string
}

interface ErrorsTableProps {
  data: ErrorLogEntry[]
  total: number
  pageSize?: number
}

export default function ErrorsTable({
  data,
  total,
  pageSize = 25,
}: ErrorsTableProps) {
  const [currentPage, setCurrentPage] = useState(1)
  const [searchTerm, setSearchTerm] = useState('')

  // Filter data based on search
  const filteredData = useMemo(() => {
    if (!searchTerm) return data

    const lowerSearchTerm = searchTerm.toLowerCase()
    return data.filter((error) => {
      return (
        error.name.toLowerCase().includes(lowerSearchTerm) ||
        error.message.toLowerCase().includes(lowerSearchTerm) ||
        (error.user_id && error.user_id.toLowerCase().includes(lowerSearchTerm))
      )
    })
  }, [data, searchTerm])

  // Paginate data
  const totalPages = Math.ceil(filteredData.length / pageSize)
  const paginatedData = useMemo(() => {
    const startIndex = (currentPage - 1) * pageSize
    return filteredData.slice(startIndex, startIndex + pageSize)
  }, [filteredData, currentPage, pageSize])

  const handleSearch = (value: string) => {
    setSearchTerm(value)
    setCurrentPage(1) // Reset to first page on search
  }

  const goToPrevPage = () => {
    setCurrentPage((prev) => Math.max(1, prev - 1))
  }

  const goToNextPage = () => {
    setCurrentPage((prev) => Math.min(totalPages, prev + 1))
  }

  const formatUserId = (userId: string | null) => {
    if (!userId) return 'anon'
    if (userId.length <= 8) return userId
    return `${userId.substring(0, 8)}...`
  }

  const formatTime = (timestamp: string) => {
    try {
      const date = parseISO(timestamp)
      return format(date, 'MMM d, HH:mm')
    } catch {
      return timestamp
    }
  }

  const truncateMessage = (message: string, maxLength: number = 80) => {
    if (message.length <= maxLength) return message
    return `${message.substring(0, maxLength)}...`
  }

  return (
    <div className="rounded-xl border border-white/10 bg-white/5 p-5">
      <div className="mb-4 flex items-center justify-between">
        <h3 className="text-lg font-semibold text-neutral-200">
          Error Log ({total.toLocaleString()})
        </h3>
      </div>

      <div className="mb-4">
        <input
          type="text"
          placeholder="Search..."
          value={searchTerm}
          onChange={(e) => handleSearch(e.target.value)}
          className="w-full rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm text-neutral-200 placeholder-neutral-500 focus:border-white/20 focus:outline-none"
        />
      </div>

      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-white/10">
              <th className="pb-3 text-left font-medium text-neutral-400">Event</th>
              <th className="pb-3 text-left font-medium text-neutral-400">Message</th>
              <th className="pb-3 text-left font-medium text-neutral-400">Platform</th>
              <th className="pb-3 text-left font-medium text-neutral-400">User</th>
              <th className="pb-3 text-left font-medium text-neutral-400">Time</th>
            </tr>
          </thead>
          <tbody>
            {paginatedData.length === 0 ? (
              <tr>
                <td colSpan={5} className="py-8 text-center text-neutral-400">
                  {searchTerm ? 'No results found' : 'No errors'}
                </td>
              </tr>
            ) : (
              paginatedData.map((error, index) => (
                <tr key={index} className="border-b border-white/5">
                  <td className="py-3">
                    <span className="inline-flex rounded-full bg-red-500/20 px-2 py-1 text-xs font-medium text-red-400">
                      {error.name}
                    </span>
                  </td>
                  <td className="py-3 text-neutral-200">
                    {truncateMessage(error.message)}
                  </td>
                  <td className="py-3">
                    <PlatformBadge platform={error.platform} />
                  </td>
                  <td className="py-3 font-mono text-xs text-neutral-400">
                    {formatUserId(error.user_id)}
                  </td>
                  <td className="py-3 text-neutral-400">
                    {formatTime(error.created_at)}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {totalPages > 1 && (
        <div className="mt-4 flex items-center justify-between">
          <div className="text-sm text-neutral-400">
            Page {currentPage} of {totalPages}
          </div>
          <div className="flex gap-2">
            <button
              onClick={goToPrevPage}
              disabled={currentPage === 1}
              className="rounded-lg bg-white/5 px-3 py-1.5 text-sm text-neutral-400 hover:bg-white/10 disabled:cursor-not-allowed disabled:opacity-50"
            >
              Prev
            </button>
            <button
              onClick={goToNextPage}
              disabled={currentPage === totalPages}
              className="rounded-lg bg-white/5 px-3 py-1.5 text-sm text-neutral-400 hover:bg-white/10 disabled:cursor-not-allowed disabled:opacity-50"
            >
              Next
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
