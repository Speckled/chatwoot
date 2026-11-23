<script setup>
import { useI18n } from 'vue-i18n';
import NextInput from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { fromInputTime, nextInterval, toInputTime } from './workingHours';

// One day's open intervals ({ start, end }, "HH:mm:ss"). No intervals means closed.
const intervals = defineModel({ type: Array, required: true });
const { t } = useI18n();

const change = (index, field, value) => {
  intervals.value = intervals.value.map((item, i) =>
    i === index ? { ...item, [field]: fromInputTime(value) } : item
  );
};
const remove = index => {
  intervals.value = intervals.value.filter((_, i) => i !== index);
};
const add = () => {
  intervals.value = [...intervals.value, nextInterval(intervals.value)];
};
</script>

<template>
  <div class="flex flex-wrap items-center gap-2">
    <span
      v-if="!intervals.length"
      data-test="closed"
      class="text-sm text-n-slate-11"
    >
      {{ t('AI_BRAIN.CLOSED') }}
    </span>
    <div
      v-for="(interval, index) in intervals"
      :key="index"
      data-test="interval"
      class="flex items-center gap-1"
    >
      <NextInput
        :model-value="toInputTime(interval.start)"
        type="time"
        size="sm"
        :aria-label="t('AI_BRAIN.INTERVAL_START')"
        @update:model-value="change(index, 'start', $event)"
      />
      <span class="text-sm text-n-slate-11">–</span>
      <NextInput
        :model-value="toInputTime(interval.end)"
        type="time"
        size="sm"
        :aria-label="t('AI_BRAIN.INTERVAL_END')"
        @update:model-value="change(index, 'end', $event)"
      />
      <Button
        type="button"
        variant="ghost"
        color="ruby"
        size="sm"
        icon="i-lucide-x"
        :title="t('AI_BRAIN.REMOVE')"
        @click="remove(index)"
      />
    </div>
    <Button
      type="button"
      variant="faded"
      color="slate"
      size="sm"
      icon="i-lucide-plus"
      data-test="add-interval"
      :label="t('AI_BRAIN.ADD_INTERVAL')"
      @click="add"
    />
  </div>
</template>
