<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import IntervalsEditor from './IntervalsEditor.vue';
import {
  DAYS,
  dayIntervals,
  scheduleProblem,
  withDateAt,
  withDayIntervals,
  withNewDate,
  withoutDateAt,
} from './workingHours';

// The business rules' workingHours, edited whole: { defaultSlotDurationMinutes, weekly, dateOverrides }.
const schedule = defineModel({ type: Object, required: true });
const { t } = useI18n();

const dayName = day => t(`AI_BRAIN.DAYS.${day}`);
const problem = computed(() => {
  const found = scheduleProblem(schedule.value, dayName);
  return (
    found && t(`AI_BRAIN.WORKING_HOURS_PROBLEM.${found.key}`, found.params)
  );
});

const setDay = (day, intervals) => {
  schedule.value = withDayIntervals(schedule.value, day, intervals);
};
const setDate = (index, entry) => {
  schedule.value = withDateAt(schedule.value, index, entry);
};
const addDate = () => {
  schedule.value = withNewDate(schedule.value);
};
const removeDate = index => {
  schedule.value = withoutDateAt(schedule.value, index);
};
const setSlot = minutes => {
  schedule.value = { ...schedule.value, defaultSlotDurationMinutes: minutes };
};
</script>

<template>
  <div class="grid gap-6">
    <div class="grid gap-3">
      <p class="text-sm text-n-slate-11">
        {{ t('AI_BRAIN.WORKING_HOURS_HINT') }}
      </p>
      <div
        v-for="day in DAYS"
        :key="day"
        data-test="weekday"
        class="grid items-center gap-2 md:grid-cols-[6rem_1fr]"
      >
        <span class="text-sm font-medium text-n-slate-12">
          {{ dayName(day) }}
        </span>
        <IntervalsEditor
          :model-value="dayIntervals(schedule, day)"
          @update:model-value="setDay(day, $event)"
        />
      </div>
    </div>

    <div class="grid gap-3">
      <span class="text-sm font-medium text-n-slate-12">
        {{ t('AI_BRAIN.DATE_HOURS') }}
      </span>
      <p class="text-sm text-n-slate-11">
        {{ t('AI_BRAIN.DATE_HOURS_HINT') }}
      </p>
      <div
        v-for="(entry, index) in schedule.dateOverrides"
        :key="index"
        data-test="date"
        class="grid items-center gap-2 md:grid-cols-[10rem_1fr_auto]"
      >
        <NextInput
          :model-value="entry.date"
          type="date"
          size="sm"
          :aria-label="t('AI_BRAIN.DATE')"
          @update:model-value="setDate(index, { ...entry, date: $event })"
        />
        <IntervalsEditor
          :model-value="entry.intervals"
          @update:model-value="setDate(index, { ...entry, intervals: $event })"
        />
        <Button
          type="button"
          variant="ghost"
          color="ruby"
          size="sm"
          icon="i-woot-bin"
          :label="t('AI_BRAIN.REMOVE')"
          @click="removeDate(index)"
        />
      </div>
      <div>
        <Button
          type="button"
          variant="faded"
          color="slate"
          size="sm"
          icon="i-lucide-plus"
          data-test="add-date"
          :label="t('AI_BRAIN.ADD_DATE')"
          @click="addDate"
        />
      </div>
    </div>

    <WithLabel
      name="slot-duration"
      :label="t('AI_BRAIN.SLOT')"
      class="md:max-w-xs"
    >
      <NextInput
        :model-value="schedule.defaultSlotDurationMinutes"
        type="number"
        min="1"
        class="w-full"
        @update:model-value="setSlot"
      />
    </WithLabel>

    <p v-if="problem" data-test="problem" class="text-sm text-n-ruby-11">
      {{ problem }}
    </p>
  </div>
</template>
