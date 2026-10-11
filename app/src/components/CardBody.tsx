import { useAtomValue } from 'jotai'
import type { ComponentType } from 'react'
import type { CardView } from '../cardView'
import { skinOf, type SkinId } from '../skins'
import { skinAtom, skinStore } from '../state'
import { ClassicCard } from './ClassicCard'
import { PlainCard } from './PlainCard'

const CARDS: Record<SkinId, ComponentType<{ view: CardView }>> = {
  classic: ClassicCard,
  plain: PlainCard,
}

export function CardBody({ view }: { view: CardView }) {
  const skin = useAtomValue(skinAtom, { store: skinStore })
  const Card = CARDS[skinOf(skin).id]

  return <Card view={view} />
}
