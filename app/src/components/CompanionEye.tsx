/** One of the companion's eyes, drawn in every mood's shape; the companion's mood class shows the one that fits. */
export function CompanionEye({ side, x }: { side: 'l' | 'r'; x: number }) {
  return (
    <g className={`eye ${side}`}>
      <path className="u" d={`M${x - 11} -10 C${x - 11} 2 ${x + 11} 2 ${x + 11} -10`} />
      <path className="caret" d={`M${x - 13} 2 L${x} -12 L${x + 13} 2`} />
      <path
        className="spark"
        fill="currentColor"
        stroke="none"
        d={`M${x} -24 L${x + 5} -10 L${x + 18} -5 L${x + 5} 0 L${x} 14 L${x - 5} 0 L${x - 18} -5 L${x - 5} -10 Z`}
      />
      <circle className="o" cx={x} cy={-4} r={12} />
      <path className="line" d={`M${x - 12} 0 L${x + 12} 0`} />
      <path className="lid" fill="currentColor" strokeWidth={6} d={`M${x - 12} -10 L${x + 12} -10 C${x + 12} 6 ${x - 12} 6 ${x - 12} -10 Z`} />
      <circle className="ring" cx={x} cy={-6} r={14} strokeWidth={6} />
      <circle className="pupil" cx={x + 6} cy={-10} r={7} fill="currentColor" stroke="none" />
      <circle className="pip" cx={x} cy={-2} r={7} fill="currentColor" stroke="none" />
      <path className="brow" strokeWidth={8} d={side === 'l' ? `M${x - 13} -20 L${x + 9} -29` : `M${x - 9} -29 L${x + 13} -20`} />
    </g>
  )
}
