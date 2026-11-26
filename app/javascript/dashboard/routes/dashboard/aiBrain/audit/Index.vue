<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import SettingsLayout from '../../settings/SettingsLayout.vue';
import BaseSettingsHeader from '../../settings/components/BaseSettingsHeader.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import ownerActionsAPI from 'dashboard/api/aiBrain/ownerActions';
import { defaultPeriod, toPeriodQuery } from './auditPeriod';

// Changes made through the staff assistant, read-only: who asked, the description read back to them, and how it ended.
// The change's input never reaches the browser.
const COLUMNS = ['WHEN', 'WHO', 'WHAT', 'OUTCOME', 'RESULT'];
const LIMIT = 200;

const { t } = useI18n();
const changes = ref([]);
const people = ref([]);
const loading = ref(true);
const person = ref('');
const period = ref(defaultPeriod());

const personOptions = computed(() => [
  { value: '', label: t('AI_BRAIN.AUDIT.EVERYONE') },
  ...people.value.map(({ id, name }) => ({ value: id, label: name })),
]);
const atLimit = computed(() => changes.value.length >= LIMIT);
const formatTime = value => new Date(value).toLocaleString();
// Decided at a different minute than proposed: shown under the proposal time.
const decidedLater = change =>
  change.decidedAt &&
  formatTime(change.decidedAt) !== formatTime(change.createdAt);

const load = async () => {
  loading.value = true;
  try {
    const { data } = await ownerActionsAPI.list({
      ...toPeriodQuery(period.value),
      ...(person.value ? { staff_user_id: person.value } : {}),
      limit: LIMIT,
    });
    changes.value = data.changes;
    people.value = data.people;
  } catch (error) {
    useAlert(t('AI_BRAIN.ERROR'));
  } finally {
    loading.value = false;
  }
};

onMounted(load);
watch([person, period], load, { deep: true });
</script>

<template>
  <SettingsLayout :is-loading="loading && !changes.length">
    <template #header>
      <BaseSettingsHeader
        :title="t('AI_BRAIN.AUDIT.TITLE')"
        :description="t('AI_BRAIN.AUDIT.DESCRIPTION')"
      >
        <template #actions>
          <div class="flex flex-wrap items-end gap-2">
            <div class="w-48">
              <Select
                v-model="person"
                :options="personOptions"
                :aria-label="t('AI_BRAIN.AUDIT.PERSON')"
              />
            </div>
            <NextInput
              v-model="period.from"
              type="date"
              :label="t('AI_BRAIN.AUDIT.FROM')"
              :max="period.to"
            />
            <NextInput
              v-model="period.to"
              type="date"
              :label="t('AI_BRAIN.AUDIT.TO')"
              :min="period.from"
            />
          </div>
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <div class="w-full">
        <p v-if="atLimit" class="mb-3 text-sm text-n-amber-11">
          {{ t('AI_BRAIN.AUDIT.AT_LIMIT', { limit: LIMIT }) }}
        </p>
        <table
          v-if="changes.length"
          class="min-w-full table-auto divide-y divide-n-weak"
        >
          <thead>
            <tr class="border-t border-n-weak">
              <th
                v-for="column in COLUMNS"
                :key="column"
                class="py-3 ltr:pr-4 rtl:pl-4 text-start text-sm font-medium text-n-slate-12"
              >
                {{ t(`AI_BRAIN.AUDIT.${column}`) }}
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-n-weak text-n-slate-11">
            <tr v-for="change in changes" :key="change.id">
              <td class="py-3 ltr:pr-4 rtl:pl-4 text-sm whitespace-nowrap">
                <div>{{ formatTime(change.createdAt) }}</div>
                <div v-if="decidedLater(change)" class="text-xs">
                  {{
                    t('AI_BRAIN.AUDIT.DECIDED_AT', {
                      time: formatTime(change.decidedAt),
                    })
                  }}
                </div>
              </td>
              <td class="py-3 ltr:pr-4 rtl:pl-4 text-sm text-n-slate-12">
                {{ change.staffName }}
              </td>
              <td class="py-3 ltr:pr-4 rtl:pl-4 text-sm">
                {{ change.description }}
              </td>
              <td class="py-3 ltr:pr-4 rtl:pl-4 text-sm">
                {{ t(`AI_BRAIN.AUDIT.OUTCOMES.${change.outcome}`) }}
              </td>
              <td class="py-3 ltr:pr-4 rtl:pl-4 text-sm">
                {{ change.result }}
              </td>
            </tr>
          </tbody>
        </table>
        <p v-else-if="!loading" class="text-sm text-n-slate-11">
          {{ t('AI_BRAIN.AUDIT.EMPTY') }}
        </p>
      </div>
    </template>
  </SettingsLayout>
</template>
