/** How a field's value is entered and shown. */
export type FieldKind = 'text' | 'markdown' | 'number' | 'choice' | 'date' | 'url' | 'boolean'

/** One value a type adds to the cards that carry it, and the value a card shows before anyone sets one. */
export type Field = {
  name: string
  label: string
  kind: FieldKind
  choices?: { value: string; label: string }[]
  default?: string | number | boolean
}

/** What a state counts as when Orion works out what's done, what's waiting, and what's stuck. */
export type StateMeaning = 'todo' | 'active' | 'review' | 'blocked' | 'deferred' | 'done'

export type State = { name: string; label: string; means: StateMeaning }

/** Which of the app's faces draws the card, its size before a skin or its text adjusts it, and the fields it shows. */
export type Face = {
  layout: 'card' | 'note' | 'component' | 'image'
  size?: { width: number; height: number }
  shows: string[]
}

/** How cards of the type feed what Orion derives. The CLI's `canvas/cardTypes/types.luau` explains each flag. */
export type Meaning = { isWork: boolean; canBlock: boolean; canBeDone: boolean; doneWhen: 'state' | 'inputs' }

/**
 * A card type as `orion serve` declares it. The app draws a card from its type's declaration rather than knowing types
 * by name, so a type a source or mod adds needs no app change.
 */
export type CardType = {
  name: string
  label: string
  pack: string
  supersedes: string[]
  fields: Field[]
  face: Face
  states: State[]
  meaning: Meaning
}

/** The types attached to a card. The primary type picks its face, and `types` lists them all, primary first. */
export type ItemTypes = { primary: string; types: string[] }
