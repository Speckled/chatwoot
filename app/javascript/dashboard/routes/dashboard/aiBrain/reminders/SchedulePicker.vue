<script setup>
import { computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import { EVENT_PRESETS, PRESET, TIME_PRESETS } from './schedulePresets';

// When a reminder goes out. Appointment targets follow each appointment; the others go out at a time.
const props = defineProps({
  eventTarget: { type: Boolean, default: false },
  calendars: { type: Array, default: () => [] },
});

// Days as the backend numbers them, Sunday first.
const DAYS = [0, 1, 2, 3, 4, 5, 6];

const schedule = defineModel({ type: Object, required: true });
const { t } = useI18n();

const allowed = computed(() =>
  props.eventTarget ? EVENT_PRESETS : TIME_PRESETS
);
const presetOptions = computed(() =>
  [
    ...allowed.value,
    ...(schedule.value.preset === PRESET.CUSTOM ? [PRESET.CUSTOM] : []),
  ].map(preset => ({
    value: preset,
    label: t(`AI_BRAIN.REMINDERS.PRESETS.${preset}`),
  }))
);
const showsTime = computed(
  () => ![PRESET.MINUTES_BEFORE, PRESET.CUSTOM].includes(schedule.value.preset)
);

// A target of another kind keeps only the schedules that fit it.
watch(
  allowed,
  presets => {
    if (
      schedule.value.preset !== PRESET.CUSTOM &&
      !presets.includes(schedule.value.preset)
    ) {
      [schedule.value.preset] = presets;
    }
  },
  { immediate: true }
);

const toggleDay = day => {
  const { days } = schedule.value;
  schedule.value.days = days.includes(day)
    ? days.filter(item => item !== day)
    : [...days, day];
};
const toggleCalendar = id => {
  const { calendarIds } = schedule.value;
  schedule.value.calendarIds = calendarIds.includes(id)
    ? calendarIds.filter(item => item !== id)
    : [...calendarIds, id];
};
</script>

<template>
  <div class="flex flex-col gap-4">
    <WithLabel name="schedule-preset" :label="t('AI_BRAIN.REMINDERS.WHEN')">
      <Select
        v-model="schedule.preset"
        :options="presetOptions"
        :aria-label="t('AI_BRAIN.REMINDERS.WHEN')"
      />
    </WithLabel>

    <div class="grid gap-4 md:grid-cols-3">
      <WithLabel
        v-if="schedule.preset === PRESET.ONCE"
        name="schedule-date"
        :label="t('AI_BRAIN.REMINDERS.DATE')"
      >
        <NextInput v-model="schedule.date" type="date" class="w-full" />
      </WithLabel>
      <WithLabel
        v-if="schedule.preset === PRESET.DAYS_BEFORE"
        name="schedule-days-before"
        :label="t('AI_BRAIN.REMINDERS.DAYS_BEFORE')"
      >
        <NextInput
          v-model.number="schedule.daysBefore"
          type="number"
          min="0"
          max="30"
          class="w-full"
        />
      </WithLabel>
      <WithLabel
        v-if="schedule.preset === PRESET.MINUTES_BEFORE"
        name="schedule-minutes-before"
        :label="t('AI_BRAIN.REMINDERS.MINUTES_BEFORE')"
      >
        <NextInput
          v-model.number="schedule.minutesBefore"
          type="number"
          min="5"
          step="5"
          class="w-full"
        />
      </WithLabel>
      <WithLabel
        v-if="showsTime"
        name="schedule-time"
        :label="t('AI_BRAIN.REMINDERS.TIME')"
      >
        <NextInput v-model="schedule.time" type="time" class="w-full" />
      </WithLabel>
    </div>

    <div
      v-if="schedule.preset === PRESET.WEEKLY"
      class="flex flex-wrap gap-4 py-1"
    >
      <label
        v-for="day in DAYS"
        :key="day"
        class="flex items-center gap-2 cursor-pointer text-sm text-n-slate-12"
      >
        <Checkbox
          :model-value="schedule.days.includes(day)"
          @change="toggleDay(day)"
        />
        <span>{{ t(`AI_BRAIN.DAYS.${day}`) }}</span>
      </label>
    </div>

    <div v-if="eventTarget && calendars.length" class="flex flex-col gap-2">
      <span class="text-sm font-medium text-n-slate-12">
        {{ t('AI_BRAIN.REMINDERS.CALENDARS') }}
      </span>
      <label
        v-for="calendar in calendars"
        :key="calendar.id"
        class="flex items-center gap-2 cursor-pointer text-sm text-n-slate-12"
      >
        <Checkbox
          :model-value="schedule.calendarIds.includes(calendar.id)"
          @change="toggleCalendar(calendar.id)"
        />
        <span>
          {{ calendar.linkedUserName || calendar.summary }}
        </span>
      </label>
      <p class="text-xs text-n-slate-11">
        {{ t('AI_BRAIN.REMINDERS.ALL_CALENDARS') }}
      </p>
    </div>

    <p class="text-xs text-n-slate-11">
      {{ t('AI_BRAIN.REMINDERS.TIME_ZONE_HINT') }}
    </p>
  </div>
</template>
