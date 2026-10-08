import { useState } from 'react'

export function Favicon({ domain }: { domain: string }) {
  const [failed, setFailed] = useState(false)

  return (
    <span className="source-favicon">
      <svg viewBox="0 0 20 20" aria-hidden="true">
        <circle cx="10" cy="10" r="7" fill="none" stroke="currentColor" strokeWidth="1.5" />
        <path d="M3 10h14M10 3c-4 4-4 10 0 14 4-4 4-10 0-14Z" fill="none" stroke="currentColor" strokeWidth="1.2" />
      </svg>
      {!failed && domain.includes('.') && <img src={`https://${domain}/favicon.ico`} alt="" onError={() => setFailed(true)} />}
    </span>
  )
}
