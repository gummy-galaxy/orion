import type { Preview } from '@storybook/react-vite'
import '@xyflow/react/dist/style.css'
import '../src/index.css'
import { COLOR_MODES, STATUS_COLORS, THEMES, applyAppearance, type ColorMode, type StatusColors } from '../src/appearance'

const preview: Preview = {
  parameters: { layout: 'centered' },
  globalTypes: {
    theme: {
      description: 'Theme',
      toolbar: { title: 'Theme', icon: 'paintbrush', items: THEMES.map((theme) => ({ value: theme.id, title: theme.label })), dynamicTitle: true },
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
      description: 'Status colors',
      toolbar: {
        title: 'Status colors',
        icon: 'eye',
        items: STATUS_COLORS.map((option) => ({ value: option.id, title: option.label })),
        dynamicTitle: true,
      },
    },
  },
  initialGlobals: { theme: THEMES[0].id, colorMode: 'system', statusColors: 'theme' },
  decorators: [
    (Story, { globals }) => {
      applyAppearance({
        theme: globals.theme as string,
        colorMode: globals.colorMode as ColorMode,
        statusColors: globals.statusColors as StatusColors,
      })

      return Story()
    },
  ],
}

export default preview
