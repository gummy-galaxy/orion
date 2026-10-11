import type { Preview } from '@storybook/react-vite'
import '@xyflow/react/dist/style.css'
import '../src/index.css'
import { COLOR_MODES, STATUS_COLORS, THEMES, applyAppearance, type ColorMode, type StatusColors } from '../src/appearance'
import { SKINS, skinOf } from '../src/skins'
import { skinAtom, skinStore } from '../src/state'

const preview: Preview = {
  parameters: { layout: 'centered' },
  globalTypes: {
    theme: {
      description: 'Theme',
      toolbar: { title: 'Theme', icon: 'paintbrush', items: THEMES.map((theme) => ({ value: theme.id, title: theme.label })), dynamicTitle: true },
    },
    skin: {
      description: 'Cards',
      toolbar: { title: 'Cards', icon: 'box', items: SKINS.map((skin) => ({ value: skin.id, title: skin.label })), dynamicTitle: true },
    },
    colorMode: {
      description: 'Color mode',
      toolbar: {
        title: 'Color mode',
        icon: 'mirror',
        items: COLOR_MODES.map((mode) => ({ value: mode, title: mode[0].toUpperCase() + mode.slice(1) })),
        dynamicTitle: true,
      },
    },
    statusColors: {
      description: 'Colorblind colors',
      toolbar: {
        title: 'Colorblind colors',
        icon: 'eye',
        items: STATUS_COLORS.map((option) => ({ value: option.id, title: option.label })),
        dynamicTitle: true,
      },
    },
  },
  initialGlobals: { theme: THEMES[0].id, skin: SKINS[0].id, colorMode: 'system', statusColors: 'theme' },
  decorators: [
    (Story, { globals }) => {
      const skin = skinOf(globals.skin as string).id

      applyAppearance({
        theme: globals.theme as string,
        skin,
        colorMode: globals.colorMode as ColorMode,
        statusColors: globals.statusColors as StatusColors,
        animations: 'system',
      })
      skinStore.set(skinAtom, skin)

      return Story()
    },
  ],
}

export default preview
