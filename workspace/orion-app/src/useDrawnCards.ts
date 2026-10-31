import { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react'
import { useStoreApi } from '@xyflow/react'
import { CardDraw, SETTLE_MS, drawViewOf, type DrawCard } from './cardDraw'

/**
 * The ids of the cards that get their bodies now. Cards near the view are drawn first, nearest its center, a batch
 * per frame. Moving the view updates which cards are wanted at once, but the queue is only re-sorted once it settles.
 * State changes are coalesced to one update per frame, so panning past cards doesn't re-render the canvas each time.
 */
export function useDrawnCards(cards: DrawCard[]): Set<string> {
  const store = useStoreApi()
  const draw = useMemo(() => new CardDraw(), [])
  const [drawn, setDrawn] = useState<Set<string>>(() => new Set())
  const cardsRef = useRef(cards)
  const frame = useRef(0)
  const dirty = useRef(false)
  const settleTimer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined)

  const tick = useCallback(
    function tick() {
      frame.current = 0

      const batched = draw.step()

      if (batched || dirty.current) {
        dirty.current = false
        setDrawn(new Set(draw.drawn))
      }

      if (draw.pending) frame.current = requestAnimationFrame(tick)
    },
    [draw],
  )

  const schedule = useCallback(() => {
    if (!frame.current && (dirty.current || draw.pending)) frame.current = requestAnimationFrame(tick)
  }, [draw, tick])

  const plan = useCallback(() => {
    const { transform, width, height } = store.getState()

    if (draw.update(cardsRef.current, drawViewOf(transform, width, height))) dirty.current = true

    schedule()

    clearTimeout(settleTimer.current)
    settleTimer.current = setTimeout(() => draw.settle(), SETTLE_MS)
  }, [store, draw, schedule])

  useLayoutEffect(() => {
    cardsRef.current = cards
    plan()
  }, [cards, plan])

  useEffect(
    () =>
      store.subscribe((state, previous) => {
        if (
          state.transform === previous.transform &&
          state.width === previous.width &&
          state.height === previous.height
        )
          return

        plan()
      }),
    [store, plan],
  )

  useEffect(
    () => () => {
      cancelAnimationFrame(frame.current)
      clearTimeout(settleTimer.current)
    },
    [],
  )

  return drawn
}
