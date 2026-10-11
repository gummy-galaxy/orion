import { describeRarity, type Rarity } from '../rarity'

export function TradingRaritySymbol({ rarity, upstream }: { rarity: Rarity; upstream: number }) {
  return (
    <svg
      className={`trading-rarity-symbol trading-rarity-symbol-${rarity}`}
      viewBox="0 0 16 16"
      role="img"
      aria-label={describeRarity(rarity, upstream)}
    >
      {rarity === 'common' && <circle cx="8" cy="8" r="5.5" />}
      {rarity === 'uncommon' && <path d="M8 1.5 14.5 8 8 14.5 1.5 8Z" />}
      {rarity === 'rare' && <path d="m8 1 1.9 4.7 5.1.3-3.9 3.2 1.3 4.9L8 11.4l-4.4 2.7 1.3-4.9L1 6l5.1-.3Z" />}
      {rarity === 'mythic' && (
        <path d="M8 0.8 9.7 5l4.1-2.8L11 6.3l4.2 1.7-4.2 1.7 2.8 4.1-4.1-2.8L8 15.2l-1.7-4.2-4.1 2.8L5 9.7.8 8 5 6.3 2.2 2.2 6.3 5Z" />
      )}
    </svg>
  )
}
