<script setup>
import { useI18n } from 'vue-i18n';
import SectionLayout from '../../../settings/account/components/SectionLayout.vue';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import StringListEditor from 'dashboard/components-next/aiBrain/StringListEditor.vue';

// Days as the backend numbers them, Sunday first.
const DAYS = [0, 1, 2, 3, 4, 5, 6];

// The business rules object the Rules page loads and saves.
const rules = defineModel({ type: Object, required: true });
const { t } = useI18n();

const toggleDay = day => {
  const schedule = rules.value.workingHours;
  schedule.activeDays = schedule.activeDays.includes(day)
    ? schedule.activeDays.filter(item => item !== day)
    : [...schedule.activeDays, day];
};
</script>

<template>
  <div class="flex flex-col gap-6 w-full">
    <SectionLayout :title="t('AI_BRAIN.GLOBAL_INSTRUCTIONS')" class="!pt-0">
      <div class="grid gap-4">
        <WithLabel
          name="global-instructions"
          :label="t('AI_BRAIN.GLOBAL_INSTRUCTIONS')"
        >
          <TextArea
            v-model="rules.globalInstructions"
            :max-length="4000"
            rows="5"
            class="w-full"
          />
        </WithLabel>
        <StringListEditor
          v-model="rules.companyRules"
          :label="t('AI_BRAIN.COMPANY_RULES')"
        />
        <StringListEditor
          v-model="rules.prohibitedBehaviors"
          :label="t('AI_BRAIN.PROHIBITED')"
        />
      </div>
    </SectionLayout>

    <SectionLayout :title="t('AI_BRAIN.WORKING_HOURS')" with-border>
      <div class="grid gap-4">
        <div class="flex flex-wrap gap-4 py-1">
          <label
            v-for="day in DAYS"
            :key="day"
            class="flex items-center gap-2 cursor-pointer text-sm text-n-slate-12"
          >
            <Checkbox
              :model-value="rules.workingHours?.activeDays?.includes(day)"
              @change="toggleDay(day)"
            />
            <span>{{ t(`AI_BRAIN.DAYS.${day}`) }}</span>
          </label>
        </div>
        <div class="grid gap-4 md:grid-cols-3">
          <WithLabel name="start-time" :label="t('AI_BRAIN.START')">
            <NextInput
              v-model="rules.workingHours.startTime"
              type="time"
              class="w-full"
            />
          </WithLabel>
          <WithLabel name="end-time" :label="t('AI_BRAIN.END')">
            <NextInput
              v-model="rules.workingHours.endTime"
              type="time"
              class="w-full"
            />
          </WithLabel>
          <WithLabel name="slot-duration" :label="t('AI_BRAIN.SLOT')">
            <NextInput
              v-model.number="rules.workingHours.defaultSlotDurationMinutes"
              type="number"
              min="1"
              class="w-full"
            />
          </WithLabel>
        </div>
        <StringListEditor
          v-model="rules.workingHours.blackoutDates"
          :label="t('AI_BRAIN.BLACKOUT_DATES')"
        />
      </div>
    </SectionLayout>
  </div>
</template>
