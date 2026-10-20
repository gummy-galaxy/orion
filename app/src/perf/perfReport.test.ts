// The report generator lives with the perf script, outside src, so its tests sit here where Vitest finds them.
import { expect, test } from 'vitest'
import { buildReport, type ReportInput } from '../../scripts/perfReport.ts'

const BASE = { 'canvas of 1000 cards › parseCanvas': [10, 10, 10], 'canvas of 1000 cards › layoutGroups': [4, 4, 4] }

/** A benchmark-only comparison where each benchmark's head is its base times the given factor. */
function compare(factors: Record<string, number> = {}): string {
  const head = Object.fromEntries(Object.entries(BASE).map(([name, runs]) => [name, runs.map((value) => value * (factors[name] ?? 1))]))
  const input: ReportInput = {
    base: { ref: 'main', sha: '1111111aaaa' },
    head: { ref: 'agent/change', sha: '2222222bbbb' },
    bench: { rounds: 3, base: BASE, head },
  }

  return buildReport(input)
}

test('leads with an emoji heading and a summary of every measurement', () => {
  const report = compare({ 'canvas of 1000 cards › parseCanvas': 1.5 })

  expect(report).toMatch(
    /^## ⏱️ Performance\n\nComparing `agent\/change` \(2222222\) with `main` \(1111111\) across 2 measurements: 1 slower, 1 within noise\.\n/,
  )
  expect(report).toContain('### 🔬 All measurements')
  expect(report).toContain('<summary>🧮 <b>Data benchmarks</b> · 2 measured · 🔴 1 slower</summary>')
})

test('cautions about a large slowdown and lists it', () => {
  const report = compare({ 'canvas of 1000 cards › parseCanvas': 1.5 })

  expect(report).toContain('> [!CAUTION]\n> 🐢 **1 measurement got slower** by 25% or more.')
  expect(report).toContain('### 🐢 Slower')
  expect(report).toContain('| 🔴 | `parseCanvas` | canvas of 1,000 cards | 10 ms | 15 ms | **+50%** |')
})

test('counts how many slowdowns are large', () => {
  expect(compare({ 'canvas of 1000 cards › parseCanvas': 1.5, 'canvas of 1000 cards › layoutGroups': 1.5 })).toContain(
    '**2 measurements got slower**, all by 25% or more.',
  )
  expect(compare({ 'canvas of 1000 cards › parseCanvas': 1.5, 'canvas of 1000 cards › layoutGroups': 1.15 })).toContain(
    '**2 measurements got slower**, 1 of them by 25% or more.',
  )
})

test('warns about a small slowdown that might be noise', () => {
  const report = compare({ 'canvas of 1000 cards › parseCanvas': 1.15, 'canvas of 1000 cards › layoutGroups': 1.2 })

  expect(report).toContain('> [!WARNING]\n> 🐌 **2 measurements got a little slower**, by less than 25%.')
  expect(report).toContain('see whether they repeat on the next run.')
  expect(report).toContain('| 🟠 | `parseCanvas` |')
})

test('celebrates when something got faster and nothing got slower', () => {
  const report = compare({ 'canvas of 1000 cards › layoutGroups': 0.5 })

  expect(report).toContain('> [!TIP]\n> 🚀 **Nothing got slower, and 1 measurement got faster.** Nice!')
  expect(report).toContain('### 🚀 Faster')
  expect(report).not.toContain('### 🐢 Slower')
})

test('says all is calm when every change is within noise', () => {
  const report = compare({ 'canvas of 1000 cards › parseCanvas': 1.05 })

  expect(report).toContain('across 2 measurements: all within noise.')
  expect(report).toContain('> [!TIP]\n> 🧘 **Smooth sailing.** Every measurement is within noise of `main`.')
  expect(report).not.toContain('### 🚀 Faster')
  expect(report).toContain('2 measured · all within noise')
})
