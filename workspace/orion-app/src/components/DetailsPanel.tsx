import type { ReactNode } from 'react'
import type { DetailsTab } from '../detailsTabs'
import { DetailsTabs } from './DetailsTabs'

/**
 * A fixed column on the right for the details of whatever is selected, so they never float over the canvas or come and
 * go with each click. Its tabs switch it to other views of the canvas, such as a table of the cards.
 */
export function DetailsPanel({
  width,
  tab,
  chooseTab,
  hide,
  children,
}: {
  width?: number
  tab: DetailsTab
  chooseTab: (tab: DetailsTab) => void
  hide: () => void
  children: ReactNode
}) {
  return (
    <aside className="details" aria-label="Details" style={width ? { width } : undefined}>
      <div className="details-head" data-tauri-drag-region="deep">
        <DetailsTabs tab={tab} choose={chooseTab} />
        <button type="button" className="side-hide" onClick={hide} title="Hide the details panel">
          ›
        </button>
      </div>
      <div
        className="details-body"
        role="tabpanel"
        id="details-tabpanel"
        aria-labelledby={`details-tab-${tab}`}
        data-tab={tab}
      >
        {children}
      </div>
    </aside>
  )
}
