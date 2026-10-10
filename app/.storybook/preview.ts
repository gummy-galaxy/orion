import type { Preview } from '@storybook/react-vite'
import '@xyflow/react/dist/style.css'
import '../src/index.css'

const preview: Preview = {
  parameters: { layout: 'centered' },
  globalTypes: {
    theme: {
      description: 'Color mode',
      toolbar: {
        title: 'Theme',
        icon: 'mirror',
        items: [
          { value: 'system', title: 'System' },
          { value: 'light', title: 'Light' },
          { value: 'dark', title: 'Dark' },
        ],
        dynamicTitle: true,
      },
    },
  },
  initialGlobals: { theme: 'system' },
  // Marks the root element the way the app's color mode setting does, and leaves it unmarked for System.
  decorators: [
    (Story, context) => {
      const theme = context.globals.theme

      if (theme === 'light' || theme === 'dark') document.documentElement.dataset.theme = theme
      else document.documentElement.removeAttribute('data-theme')

      return Story()
    },
  ],
}

export default preview
