import type { ReactNode } from 'react'
import type { CardView } from '../cardView'
import { describeRarity } from '../rarity'
import { getTradingFacts, KIND_HINT, MOTION_HINT, STICKER_HINT } from '../skins/tradingFacts'
import { TradingIdentityContext, type TradingIdentity } from '../skins/tradingIdentity'
import { TradingCard } from './TradingCard'
import { TradingKindIcon } from './TradingKindIcon'
import { TradingRaritySymbol } from './TradingRaritySymbol'

function Entry({ mark, title, children }: { mark: ReactNode; title: string; children: ReactNode }) {
  return (
    <div className="trading-details-entry">
      <span className="trading-details-mark">{mark}</span>
      <div>
        <b>{title}</b>
        <span>{children}</span>
      </div>
    </div>
  )
}

/**
 * The drill-down view of one card: the card at full size with its art running, and every mark on its face
 * explained beside it, after MTG Arena's keyword reminders. The face stays light because this view holds the rest.
 */
export function TradingDetails({ view, identity }: { view: CardView; identity: TradingIdentity }) {
  const facts = getTradingFacts(view)

  return (
    <div className="trading-details">
      <div className="card skin-trading trading-details-card">
        <TradingIdentityContext.Provider value={{ identity, sealSide: 'right', motion: 'always' }}>
          <TradingCard view={view} />
        </TradingIdentityContext.Provider>
      </div>
      <div className="trading-details-entries">
        <Entry mark={<TradingKindIcon kind={view.kind} />} title={KIND_HINT[view.kind]}>
          {view.tag}
        </Entry>
        {view.rarity && (
          <Entry mark={<TradingRaritySymbol rarity={view.rarity} upstream={view.upstream} priority={view.priority} />} title="Rarity">
            {describeRarity(view.rarity, view.upstream, view.priority)}
          </Entry>
        )}
        {facts.sticker && (
          <Entry mark="!" title={STICKER_HINT[facts.sticker]}>
            The one thing on this card that needs someone right now.
          </Entry>
        )}
        {facts.motion && (
          <Entry mark="…" title={MOTION_HINT[facts.motion]}>
            Work running without anyone. It clears once it lands.
          </Entry>
        )}
        <Entry mark={facts.blockers} title="Open blockers">
          {facts.blockers === 0 ? 'Nothing to wait on.' : `${facts.blockers} ${facts.blockers === 1 ? 'card has' : 'cards have'} to finish first.`}
        </Entry>
        <Entry mark={facts.unblocks} title="Unblocks">
          {facts.unblocks === 0
            ? 'Nothing waits on this card yet.'
            : `Finishing this frees ${facts.unblocks} ${facts.unblocks === 1 ? 'card' : 'cards'}.`}
        </Entry>
        <Entry mark={facts.priority === undefined ? '–' : `P${facts.priority}`} title="Priority">
          {facts.priority === undefined ? 'No source sets one.' : 'Set by a source.'}
        </Entry>
        <Entry mark={facts.size ?? '–'} title="Size">
          {facts.size ? 'Set by a source.' : 'No source sets one.'}
        </Entry>
      </div>
    </div>
  )
}
