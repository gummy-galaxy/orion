import type { Work } from '../derive'
import type { AppNode, Link } from '../model'
import { DIRECTION_LABEL } from '../linkDirection'
import { LinkAdd } from './LinkAdd'
import { LinkSection } from './LinkSection'

/** The card's own links, not the chains derived through notes, so each one can be removed where it is listed. */
export function LinkList({
  node,
  work,
  nodeMap,
  links,
  jumpTo,
  addLink,
  removeLink,
  flipLink,
}: {
  node: AppNode
  work: Work
  nodeMap: Map<string, AppNode>
  links: Link[]
  jumpTo: (id: string) => void
  addLink: (from: string, to: string, kind: Link['kind']) => void
  removeLink: (id: string) => void
  flipLink: (id: string) => void
}) {
  const ownLinks = links.filter((link) => (link.from === node.id || link.to === node.id) && nodeMap.has(link.from) && nodeMap.has(link.to))
  const groups = {
    waits: ownLinks.filter((link) => link.kind === 'blocks' && link.to === node.id),
    unblocks: ownLinks.filter((link) => link.kind === 'blocks' && link.from === node.id),
    related: ownLinks.filter((link) => link.kind === 'related'),
  }
  const joined = new Set(ownLinks.map((link) => (link.from === node.id ? link.to : link.from)))
  const shared = { node, work, nodeMap, jumpTo, removeLink, flipLink }

  return (
    <div className="link-sections">
      <LinkSection title={DIRECTION_LABEL.waits} links={groups.waits} {...shared} />
      <LinkSection title={DIRECTION_LABEL.unblocks} links={groups.unblocks} {...shared} />
      <LinkSection title={DIRECTION_LABEL.related} links={groups.related} {...shared} />
      <LinkAdd node={node} nodeMap={nodeMap} joined={joined} addLink={addLink} />
    </div>
  )
}
