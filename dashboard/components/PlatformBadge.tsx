'use client'

interface PlatformBadgeProps {
  platform: string
}

export default function PlatformBadge({ platform }: PlatformBadgeProps) {
  const getBadgeStyles = (platform: string) => {
    const normalized = platform.toLowerCase()

    if (normalized === 'ios') {
      return 'bg-blue-500/20 text-blue-400'
    }
    if (normalized === 'android') {
      return 'bg-green-500/20 text-green-400'
    }
    return 'bg-neutral-500/20 text-neutral-400'
  }

  return (
    <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${getBadgeStyles(platform)}`}>
      {platform}
    </span>
  )
}
