<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import SettingsLayout from '../../settings/SettingsLayout.vue';
import BaseSettingsHeader from '../../settings/components/BaseSettingsHeader.vue';
import SectionLayout from '../../settings/account/components/SectionLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import servicesAPI from 'dashboard/api/aiBrain/services';

// The calendar dropdown's choice for "create a new calendar for this person".
const NEW_CALENDAR = '__new__';

const { t } = useI18n();
const status = ref(null);
const calendars = ref([]);
const professionals = ref([]);
const showCalendars = ref(false);
const busy = ref(false);
const editorRef = ref(null);
const editing = ref(null);
const saving = ref(false);
const form = reactive({
  displayName: '',
  email: '',
  whatsAppNumber: '',
  calendarId: '',
});

const load = async () => {
  try {
    const [serviceRes, usersRes] = await Promise.all([
      servicesAPI.get(),
      servicesAPI.getUsers({ calendar: true }),
    ]);
    status.value = serviceRes.data[0];
    professionals.value = usersRes.data || [];
    calendars.value = status.value?.availableCalendars || [];
    if (status.value?.isConnected && status.value?.isValid) {
      calendars.value = (await servicesAPI.getCalendars()).data;
    }
  } catch (error) {
    useAlert(t('AI_BRAIN.ERROR'));
  }
};

const calendarName = calendarId =>
  calendars.value.find(calendar => calendar.id === calendarId)?.summary ||
  calendarId ||
  t('AI_BRAIN.NO_CALENDAR');

const canCreateCalendar = computed(
  () => status.value?.isConnected && status.value?.isValid
);

const openEditor = professional => {
  editing.value = professional;
  Object.assign(form, {
    displayName: professional.displayName || professional.name,
    email: professional.email || '',
    whatsAppNumber: professional.whatsAppNumber || '',
    calendarId: professional.linkedCalendarId || '',
  });
  editorRef.value?.open();
};

const saveCalendar = async professional => {
  if (form.calendarId === NEW_CALENDAR) {
    await servicesAPI.createCalendar(
      professional.id,
      form.displayName || professional.name
    );
    return;
  }
  if (form.calendarId === (professional.linkedCalendarId || '')) return;

  // Unlinking addresses the calendar that was linked; linking moves the chosen one to this person.
  await servicesAPI.linkCalendarUser(
    form.calendarId || professional.linkedCalendarId,
    form.calendarId ? professional.id : null
  );
};

const saveEditor = async () => {
  const professional = editing.value;
  saving.value = true;
  try {
    const { data } = await servicesAPI.updateUser(
      professional.chatwootUserId,
      {
        displayName: form.displayName,
        email: form.email,
        whatsAppNumber: form.whatsAppNumber,
      }
    );
    await saveCalendar(professional);
    useAlert(
      data.unconfirmedEmail
        ? t('AI_BRAIN.EMAIL_CONFIRMATION_SENT')
        : t('AI_BRAIN.SAVED')
    );
    editorRef.value?.close();
    await load();
  } catch (error) {
    useAlert(error?.response?.data?.error || t('AI_BRAIN.ERROR'));
  } finally {
    saving.value = false;
  }
};

onMounted(load);

const connect = async () => {
  busy.value = true;
  try {
    window.location.assign(
      (await servicesAPI.getGoogleAuthUrl()).data.authorizationUrl
    );
  } catch (error) {
    useAlert(t('AI_BRAIN.ERROR'));
    busy.value = false;
  }
};

const disconnect = async () => {
  if (!window.confirm(t('AI_BRAIN.CONFIRM_DISCONNECT'))) return;
  busy.value = true;
  try {
    await servicesAPI.disconnectGoogle();
    await load();
  } catch (error) {
    useAlert(t('AI_BRAIN.ERROR'));
  } finally {
    busy.value = false;
  }
};
</script>

<template>
  <SettingsLayout :is-loading="busy && !status">
    <template #header>
      <BaseSettingsHeader :title="t('AI_BRAIN.SERVICES')" />
    </template>
    <template #body>
      <div class="flex flex-col gap-6 w-full">
        <SectionLayout :title="t('AI_BRAIN.LINKED_USERS')" class="!pt-0">
          <div class="w-full">
            <table
              v-if="professionals.length"
              class="min-w-full table-auto divide-y divide-n-weak"
            >
              <thead>
                <tr class="border-t border-n-weak">
                  <th
                    v-for="column in [
                      'NAME',
                      'TEAMS',
                      'WHATSAPP_NUMBER',
                      'EMAIL',
                      'LINKED_CALENDAR',
                    ]"
                    :key="column"
                    class="py-3 ltr:pr-4 rtl:pl-4 text-start text-sm font-medium text-n-slate-12"
                  >
                    {{ t(`AI_BRAIN.${column}`) }}
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-n-weak text-n-slate-11">
                <tr
                  v-for="professional in professionals"
                  :key="professional.id"
                  class="cursor-pointer hover:bg-n-alpha-1"
                  @click="openEditor(professional)"
                >
                  <td
                    class="py-3 ltr:pr-4 rtl:pl-4 text-sm text-n-slate-12 font-medium"
                  >
                    {{ professional.displayName || professional.name }}
                  </td>
                  <td class="py-3 ltr:pr-4 rtl:pl-4 text-sm">
                    {{ professional.teams.join(', ') }}
                  </td>
                  <td class="py-3 ltr:pr-4 rtl:pl-4 text-sm">
                    {{ professional.whatsAppNumber || '-' }}
                  </td>
                  <td class="py-3 ltr:pr-4 rtl:pl-4 text-sm">
                    {{ professional.email || '-' }}
                  </td>
                  <td class="py-3 ltr:pr-4 rtl:pl-4 text-sm text-n-slate-12">
                    {{ calendarName(professional.linkedCalendarId) }}
                  </td>
                </tr>
              </tbody>
            </table>
            <p v-else class="text-sm text-n-slate-11 py-2">
              {{ t('AI_BRAIN.NO_USERS_FOUND') }}
            </p>
          </div>
          <Dialog
            ref="editorRef"
            :title="t('AI_BRAIN.EDIT_PROFESSIONAL')"
            :confirm-button-label="t('AI_BRAIN.SAVE')"
            :cancel-button-label="t('AI_BRAIN.CANCEL')"
            :is-loading="saving"
            @confirm="saveEditor"
          >
            <div class="flex flex-col gap-4">
              <WithLabel
                :label="t('AI_BRAIN.DISPLAY_NAME')"
                name="displayName"
              >
                <NextInput v-model="form.displayName" class="w-full" />
              </WithLabel>
              <WithLabel :label="t('AI_BRAIN.EMAIL')" name="email">
                <NextInput v-model="form.email" type="email" class="w-full" />
              </WithLabel>
              <WithLabel
                :label="t('AI_BRAIN.WHATSAPP_NUMBER')"
                name="whatsAppNumber"
              >
                <NextInput
                  v-model="form.whatsAppNumber"
                  class="w-full"
                  placeholder="+5551999990000"
                />
              </WithLabel>
              <WithLabel
                :label="t('AI_BRAIN.LINKED_CALENDAR')"
                name="calendar"
              >
                <select
                  v-model="form.calendarId"
                  class="w-full text-sm rounded-lg border border-n-weak bg-n-solid-1 text-n-slate-12 px-2.5 py-1.5 focus:border-n-brand focus:outline-none"
                >
                  <option value="">{{ t('AI_BRAIN.NO_CALENDAR') }}</option>
                  <option
                    v-for="calendar in calendars"
                    :key="calendar.id"
                    :value="calendar.id"
                  >
                    {{ calendar.summary
                    }}{{
                      calendar.isPrimary ? ` (${t('AI_BRAIN.PRIMARY')})` : ''
                    }}
                  </option>
                  <option v-if="canCreateCalendar" :value="NEW_CALENDAR">
                    {{ t('AI_BRAIN.CREATE_CALENDAR') }}
                  </option>
                </select>
              </WithLabel>
            </div>
          </Dialog>
        </SectionLayout>

        <SectionLayout
          v-if="status"
          :title="t('AI_BRAIN.GOOGLE_CALENDAR')"
          with-border
        >
          <div
            class="p-5 rounded-xl border border-n-weak bg-n-solid-1 flex flex-col gap-3"
          >
            <div class="flex items-center justify-between">
              <span
                class="text-sm font-medium"
                :class="
                  status.isConnected ? 'text-n-teal-11' : 'text-n-slate-11'
                "
              >
                {{
                  status.isConnected
                    ? t('AI_BRAIN.CONNECTED')
                    : t('AI_BRAIN.DISCONNECTED')
                }}
              </span>
            </div>
            <div
              v-if="status.accountEmail"
              class="flex flex-wrap items-center gap-1.5 text-sm text-n-slate-12"
            >
              <span>{{ `${status.accountEmail} ·` }}</span>
              <button
                type="button"
                class="inline-flex items-center gap-1 font-medium text-n-brand hover:underline focus:outline-none"
                :aria-expanded="showCalendars"
                aria-controls="available-calendars-accordion"
                @click="showCalendars = !showCalendars"
              >
                <span>{{ t('AI_BRAIN.AVAILABLE_CALENDARS') }}</span>
                <Icon
                  icon="i-lucide-chevron-down"
                  class="w-4 h-4 transition-transform duration-200"
                  :class="{ 'rotate-180': showCalendars }"
                />
              </button>
            </div>
            <p v-if="status.validationError" class="text-sm text-n-ruby-9">
              {{ status.validationError }}
            </p>
            <div
              id="available-calendars-accordion"
              :hidden="showCalendars ? undefined : 'until-found'"
              class="w-full pt-1"
              @beforematch="showCalendars = true"
            >
              <div
                class="overflow-x-auto rounded-lg border border-n-weak bg-n-solid-2 p-3"
              >
                <table
                  v-if="calendars.length"
                  class="min-w-full table-auto divide-y divide-n-weak"
                >
                  <thead>
                    <tr>
                      <th
                        class="py-2.5 ltr:pr-4 rtl:pl-4 text-start text-xs font-semibold text-n-slate-12 uppercase tracking-wider"
                      >
                        {{ t('AI_BRAIN.NAME') }}
                      </th>
                      <th
                        class="py-2.5 ltr:pr-4 rtl:pl-4 text-start text-xs font-semibold text-n-slate-12 uppercase tracking-wider"
                      >
                        {{ t('AI_BRAIN.ID') }}
                      </th>
                      <th
                        class="py-2.5 ltr:pr-4 rtl:pl-4 text-start text-xs font-semibold text-n-slate-12 uppercase tracking-wider"
                      >
                        {{ t('AI_BRAIN.ACCESS') }}
                      </th>
                      <th
                        class="py-2.5 ltr:pr-4 rtl:pl-4 text-start text-xs font-semibold text-n-slate-12 uppercase tracking-wider"
                      >
                        {{ t('AI_BRAIN.TIME_ZONE') }}
                      </th>
                      <th
                        class="py-2.5 ltr:pr-4 rtl:pl-4 text-start text-xs font-semibold text-n-slate-12 uppercase tracking-wider"
                      >
                        {{ t('AI_BRAIN.DESCRIPTION') }}
                      </th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-n-weak text-n-slate-11">
                    <tr v-for="calendar in calendars" :key="calendar.id">
                      <td
                        class="py-2.5 ltr:pr-4 rtl:pl-4 text-sm text-n-slate-12 font-medium"
                      >
                        {{ calendar.summary }}
                        <span
                          v-if="calendar.isPrimary"
                          class="ms-2 text-xs text-n-teal-11"
                        >
                          {{ `(${t('AI_BRAIN.PRIMARY')})` }}
                        </span>
                      </td>
                      <td
                        class="py-2.5 ltr:pr-4 rtl:pl-4 text-xs font-mono text-n-slate-11"
                      >
                        {{ calendar.id }}
                      </td>
                      <td
                        class="py-2.5 ltr:pr-4 rtl:pl-4 text-sm text-n-slate-11"
                      >
                        {{ calendar.accessRole }}
                      </td>
                      <td
                        class="py-2.5 ltr:pr-4 rtl:pl-4 text-sm text-n-slate-11"
                      >
                        {{ calendar.timeZone }}
                      </td>
                      <td
                        class="py-2.5 ltr:pr-4 rtl:pl-4 text-sm text-n-slate-11"
                      >
                        {{ calendar.description || '-' }}
                      </td>
                    </tr>
                  </tbody>
                </table>
                <p v-else class="text-sm text-n-slate-11 py-2">
                  {{ t('AI_BRAIN.NO_CALENDARS_AVAILABLE') }}
                </p>
              </div>
            </div>
            <div class="flex gap-3 pt-2">
              <Button
                type="button"
                color="blue"
                :is-loading="busy"
                :label="
                  status.isConnected
                    ? t('AI_BRAIN.RECONNECT')
                    : t('AI_BRAIN.CONNECT')
                "
                @click="connect"
              />
              <Button
                v-if="status.isConnected"
                type="button"
                variant="faded"
                color="ruby"
                :disabled="busy"
                :label="t('AI_BRAIN.DISCONNECT')"
                @click="disconnect"
              />
            </div>
          </div>
        </SectionLayout>
      </div>
    </template>
  </SettingsLayout>
</template>
