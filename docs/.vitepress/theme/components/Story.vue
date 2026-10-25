<script setup lang="ts">
import { computed } from 'vue'

// The Storybook that main last published to Chromatic. `npm run dev` points at a local `npm run storybook` in workspace/orion-app/
// instead, so stories you're editing show up here. Set VITE_STORYBOOK_URL to embed any other Storybook build.
const CHROMATIC_URL = 'https://main--6acd7d37ef902af0d3845e73.chromatic.com'
const LOCAL_URL = 'http://localhost:6006'

const props = withDefaults(
  defineProps<{
    // The story's id, as in Storybook's URL: `?path=/story/<id>`.
    id: string
    height?: number
    title?: string
  }>(),
  { height: 360 },
)

const baseUrl = import.meta.env.VITE_STORYBOOK_URL ?? (import.meta.env.DEV ? LOCAL_URL : CHROMATIC_URL)
const frameUrl = computed(() => `${baseUrl}/iframe.html?id=${props.id}&viewMode=story`)
const storyUrl = computed(() => `${baseUrl}/?path=/story/${props.id}`)
</script>

<template>
  <figure class="story">
    <iframe :src="frameUrl" :title="title ?? id" :height="height" loading="lazy" />
    <figcaption>
      <span v-if="title">{{ title }}</span>
      <a :href="storyUrl" target="_blank" rel="noreferrer">Open in Storybook</a>
    </figcaption>
  </figure>
</template>

<style scoped>
.story {
  margin: 16px 0;
  border: 1px solid var(--vp-c-divider);
  border-radius: 12px;
  overflow: hidden;
  background: var(--vp-c-bg-alt);
}

.story iframe {
  display: block;
  width: 100%;
  border: 0;
}

.story figcaption {
  display: flex;
  justify-content: space-between;
  gap: 16px;
  padding: 8px 12px;
  border-top: 1px solid var(--vp-c-divider);
  font-size: 14px;
  color: var(--vp-c-text-2);
}

.story figcaption a {
  margin-left: auto;
}
</style>
