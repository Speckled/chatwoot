<script setup>
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import SettingsLayout from '../../settings/SettingsLayout.vue';
import BaseSettingsHeader from '../../settings/components/BaseSettingsHeader.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import remindersAPI from 'dashboard/api/aiBrain/reminders';
import inboxesAPI from 'dashboard/api/aiBrain/inboxes';
import servicesAPI from 'dashboard/api/aiBrain/services';
import ReminderDialog from './ReminderDialog.vue';
import DeliveriesPanel from './DeliveriesPanel.vue';
import { PRESET, fromSchedule } from './schedulePresets';

// Messages the AI Brain sends on its own: appointment reminders, notices to staff and each day's schedule.
const { t } = useI18n();
const store = useStore();
const teams = useMapGetter('teams/getTeams');
const reminders = ref([]);
const inboxes = ref([]);
const users = ref([]);
const calendars = ref([]);
const placeholders = ref({});
const loading = ref(true);
const dialogRef = ref(null);
const deliveriesRef = ref(null);
const deliveriesFor = ref(null);

// The other lists only fill in the dialog's choices, so one that fails leaves the page usable.
const loadChoices = async () => {
  const [inboxRes, userRes, calendarRes, placeholderRes] =
    await Promise.allSettled([
      inboxesAPI.get(),
      servicesAPI.getUsers(),
      servicesAPI.getCalendars(),
      remindersAPI.placeholders(),
    ]);
  inboxes.value = inboxRes.value?.data || [];
  users.value = userRes.value?.data || [];
  calendars.value = calendarRes.value?.data || [];
  placeholders.value = placeholderRes.value?.data || {};
};
const load = async () => {
  try {
    reminders.value = (await remindersAPI.get()).data;
  } catch (error) {
    useAlert(t('AI_BRAIN.ERROR'));
  } finally {
    loading.value = false;
  }
};
onMounted(() => {
  store.dispatch('teams/get');
  loadChoices();
  load();
});

const dayNames = days => days.map(day => t(`AI_BRAIN.DAYS.${day}`)).join(', ');
const scheduleSummary = reminder => {
  const form = fromSchedule(reminder.schedule);
  const time = form.time;
  switch (form.preset) {
    case PRESET.ONCE:
      return t('AI_BRAIN.REMINDERS.SUMMARY.ONCE', {
        when: new Date(reminder.schedule.at).toLocaleString(),
      });
    case PRESET.DAILY:
      return t('AI_BRAIN.REMINDERS.SUMMARY.DAILY', { time });
    case PRESET.WEEKDAYS:
      return t('AI_BRAIN.REMINDERS.SUMMARY.WEEKDAYS', { time });
    case PRESET.WEEKLY:
      return t('AI_BRAIN.REMINDERS.SUMMARY.WEEKLY', {
        days: dayNames(form.days),
        time,
      });
    case PRESET.DAYS_BEFORE:
      return t('AI_BRAIN.REMINDERS.SUMMARY.DAYS_BEFORE', {
        count: form.daysBefore,
        time,
      });
    case PRESET.MINUTES_BEFORE:
      return t('AI_BRAIN.REMINDERS.SUMMARY.MINUTES_BEFORE', {
        count: form.minutesBefore,
      });
    default:
      return t('AI_BRAIN.REMINDERS.SUMMARY.CUSTOM');
  }
};
const formatDate = value => (value ? new Date(value).toLocaleString() : '-');

const saved = reminder => {
  const index = reminders.value.findIndex(item => item.id === reminder.id);
  if (index === -1) reminders.value = [...reminders.value, reminder];
  else reminders.value.splice(index, 1, reminder);
};
const setEnabled = async (reminder, isEnabled) => {
  try {
    saved((await remindersAPI.setEnabled(reminder.id, isEnabled)).data);
  } catch (error) {
    useAlert(t('AI_BRAIN.ERROR'));
  }
};
const runNow = async reminder => {
  try {
    await remindersAPI.runNow(reminder.id);
    useAlert(t('AI_BRAIN.REMINDERS.RUN_NOW_DONE'));
  } catch (error) {
    useAlert(t('AI_BRAIN.ERROR'));
  }
};
const remove = async reminder => {
  if (!window.confirm(t('AI_BRAIN.REMINDERS.CONFIRM_DELETE'))) return;
  try {
    await remindersAPI.delete(reminder.id);
    reminders.value = reminders.value.filter(item => item.id !== reminder.id);
  } catch (error) {
    useAlert(t('AI_BRAIN.ERROR'));
  }
};
const showDeliveries = reminder => {
  deliveriesFor.value = reminder;
  deliveriesRef.value?.open();
};
</script>

<template>
  <SettingsLayout :is-loading="loading">
    <template #header>
      <BaseSettingsHeader
        :title="t('AI_BRAIN.REMINDERS.TITLE')"
        :description="t('AI_BRAIN.REMINDERS.DESCRIPTION')"
      >
        <template #actions>
          <Button
            type="button"
            color="blue"
            size="sm"
            icon="i-woot-plus"
            :label="t('AI_BRAIN.REMINDERS.NEW')"
            @click="dialogRef?.open()"
          />
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <div class="w-full">
        <table
          v-if="reminders.length"
          class="min-w-full table-auto divide-y divide-n-weak"
        >
          <thead>
            <tr class="border-t border-n-weak">
              <th
                v-for="column in ['NAME', 'WHO', 'WHEN', 'NEXT_RUN', 'ENABLED']"
                :key="column"
                class="py-3 ltr:pr-4 rtl:pl-4 text-start text-sm font-medium text-n-slate-12"
              >
                {{ t(`AI_BRAIN.REMINDERS.${column}`) }}
              </th>
              <th
                class="py-3 ltr:pr-4 rtl:pl-4 text-end text-sm font-medium text-n-slate-12"
              >
                {{ t('AI_BRAIN.ACTIONS') }}
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-n-weak text-n-slate-11">
            <tr v-for="reminder in reminders" :key="reminder.id">
              <td
                class="py-3 ltr:pr-4 rtl:pl-4 text-sm text-n-slate-12 font-medium"
              >
                <div>{{ reminder.name }}</div>
                <div class="text-xs text-n-slate-11 font-normal">
                  {{ reminder.channelLabel }}
                </div>
              </td>
              <td class="py-3 ltr:pr-4 rtl:pl-4 text-sm">
                {{
                  reminder.targetLabel ||
                  t(`AI_BRAIN.REMINDERS.TARGETS.${reminder.target.type}`)
                }}
              </td>
              <td class="py-3 ltr:pr-4 rtl:pl-4 text-sm">
                {{ scheduleSummary(reminder) }}
              </td>
              <td class="py-3 ltr:pr-4 rtl:pl-4 text-sm whitespace-nowrap">
                {{ formatDate(reminder.isEnabled ? reminder.nextRunAt : null) }}
              </td>
              <td class="py-3 ltr:pr-4 rtl:pl-4 text-sm">
                <Switch
                  :model-value="reminder.isEnabled"
                  @change="value => setEnabled(reminder, value)"
                />
              </td>
              <td class="py-3 ltr:pr-4 rtl:pl-4 text-end">
                <div class="flex justify-end gap-2">
                  <Button
                    type="button"
                    variant="ghost"
                    color="slate"
                    size="sm"
                    icon="i-lucide-send"
                    :aria-label="t('AI_BRAIN.REMINDERS.RUN_NOW')"
                    @click="runNow(reminder)"
                  />
                  <Button
                    type="button"
                    variant="ghost"
                    color="slate"
                    size="sm"
                    icon="i-lucide-history"
                    :aria-label="t('AI_BRAIN.REMINDERS.DELIVERIES')"
                    @click="showDeliveries(reminder)"
                  />
                  <Button
                    type="button"
                    variant="ghost"
                    color="slate"
                    size="sm"
                    icon="i-woot-edit-pen"
                    :aria-label="t('AI_BRAIN.EDIT')"
                    @click="dialogRef?.open(reminder)"
                  />
                  <Button
                    type="button"
                    variant="ghost"
                    color="ruby"
                    size="sm"
                    icon="i-woot-bin"
                    :aria-label="t('AI_BRAIN.REMOVE')"
                    @click="remove(reminder)"
                  />
                </div>
              </td>
            </tr>
          </tbody>
        </table>
        <p v-else-if="!loading" class="text-sm text-n-slate-11 py-2">
          {{ t('AI_BRAIN.REMINDERS.EMPTY') }}
        </p>
      </div>

      <ReminderDialog
        ref="dialogRef"
        :inboxes="inboxes"
        :users="users"
        :teams="teams"
        :calendars="calendars"
        :placeholders="placeholders"
        @saved="saved"
      />
      <Dialog
        ref="deliveriesRef"
        :title="
          deliveriesFor
            ? `${t('AI_BRAIN.REMINDERS.DELIVERIES')}: ${deliveriesFor.name}`
            : t('AI_BRAIN.REMINDERS.DELIVERIES')
        "
        :show-confirm-button="false"
        :cancel-button-label="t('AI_BRAIN.CANCEL')"
        width="3xl"
        overflow-y-auto
        @close="deliveriesFor = null"
      >
        <DeliveriesPanel
          v-if="deliveriesFor"
          :key="deliveriesFor.id"
          :reminder-id="deliveriesFor.id"
        />
      </Dialog>
    </template>
  </SettingsLayout>
</template>
