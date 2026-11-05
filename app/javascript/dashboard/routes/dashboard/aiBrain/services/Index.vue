<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import SettingsLayout from '../../settings/SettingsLayout.vue';
import BaseSettingsHeader from '../../settings/components/BaseSettingsHeader.vue';
import SectionLayout from '../../settings/account/components/SectionLayout.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import ServiceTermsEditor from 'dashboard/components-next/aiBrain/ServiceTermsEditor.vue';
import {
  fromOverrideForm,
  toOverrideForm,
} from 'dashboard/components-next/aiBrain/serviceTermsOverride';
import servicesAPI from 'dashboard/api/aiBrain/services';
import serviceTermsAPI from 'dashboard/api/aiBrain/serviceTerms';
import ServiceConnectionCard from './ServiceConnectionCard.vue';

// The calendar dropdown's choice for "create a new calendar for this person".
const NEW_CALENDAR = '__new__';
// Route slugs of the Google services the backend connects.
const GOOGLE_CALENDAR = 'google-calendar';
const GOOGLE_DRIVE = 'google-drive';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
// Query keys the backend's OAuth callback appends to this page's URL, with the service each one reports on.
const CONNECTION_QUERY_KEYS = {
  calendarConnection: () => t('AI_BRAIN.GOOGLE_CALENDAR'),
  googleDriveConnection: () => t('AI_BRAIN.GOOGLE_DRIVE'),
};
// The failure statuses the callback can report, with their explanations.
const CONNECTION_ERRORS = {
  reconnection_required: () =>
    t('AI_BRAIN.CONNECTION_ERRORS.RECONNECTION_REQUIRED'),
  authorization_failed: () =>
    t('AI_BRAIN.CONNECTION_ERRORS.AUTHORIZATION_FAILED'),
  configuration_error: () =>
    t('AI_BRAIN.CONNECTION_ERRORS.CONFIGURATION_ERROR'),
  provider_error: () => t('AI_BRAIN.CONNECTION_ERRORS.PROVIDER_ERROR'),
  persistence_error: () => t('AI_BRAIN.CONNECTION_ERRORS.PERSISTENCE_ERROR'),
};
// Service statuses keyed by the backend's service name, such as GoogleCalendar.
const statuses = ref({});
const status = computed(() => statuses.value.GoogleCalendar);
const driveStatus = computed(() => statuses.value.GoogleDrive);
const calendars = ref([]);
const professionals = ref([]);
const showCalendars = ref(false);
// The slug of the service being connected or disconnected.
const busyService = ref(null);
const editorRef = ref(null);
const editing = ref(null);
const saving = ref(false);
const form = reactive({
  displayName: '',
  email: '',
  whatsAppNumber: '',
  calendarId: '',
});
// What the professional being edited changes from the clinic's services and prices, and the backend's problems with it.
const termsForm = ref(null);
const termsErrors = ref({});

const load = async () => {
  try {
    const [serviceRes, usersRes] = await Promise.all([
      servicesAPI.get(),
      servicesAPI.getUsers({ calendar: true }),
    ]);
    statuses.value = Object.fromEntries(
      serviceRes.data.map(service => [service.service, service])
    );
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

const openEditor = async professional => {
  editing.value = professional;
  Object.assign(form, {
    displayName: professional.displayName || professional.name,
    email: professional.email || '',
    whatsAppNumber: professional.whatsAppNumber || '',
    calendarId: professional.linkedCalendarId || '',
  });
  termsForm.value = null;
  termsErrors.value = {};
  editorRef.value?.open();
  try {
    const { clinic, professionals: terms } = (await serviceTermsAPI.get()).data;
    const own = terms.find(entry => entry.userId === professional.id)?.terms;
    termsForm.value = toOverrideForm(clinic, own || {});
  } catch (error) {
    useAlert(t('AI_BRAIN.ERROR'));
  }
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
  termsErrors.value = {};
  try {
    // Service terms go first: they are the likeliest to be rejected, and then nothing else is saved.
    if (termsForm.value) {
      await serviceTermsAPI.updateProfessional(
        professional.id,
        fromOverrideForm(termsForm.value)
      );
    }
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
    termsErrors.value = error?.response?.data?.errors || {};
    useAlert(error?.response?.data?.error || t('AI_BRAIN.ERROR'));
  } finally {
    saving.value = false;
  }
};

// Reports the result the OAuth callback put in the URL, then drops it so a reload does not repeat it.
const reportConnectionResult = () => {
  const query = { ...route.query };
  Object.entries(CONNECTION_QUERY_KEYS).forEach(([key, serviceName]) => {
    const result = query[key];
    if (!result) return;
    delete query[key];
    const service = serviceName();
    if (result === 'connected') {
      useAlert(t('AI_BRAIN.SERVICE_CONNECTED', { service }));
      return;
    }
    const reason = Object.hasOwn(CONNECTION_ERRORS, result)
      ? CONNECTION_ERRORS[result]()
      : t('AI_BRAIN.CONNECTION_ERRORS.UNKNOWN');
    useAlert(t('AI_BRAIN.CONNECTION_FAILED', { service, reason }));
  });
  if (Object.keys(query).length !== Object.keys(route.query).length) {
    router.replace({ query });
  }
};

onMounted(() => {
  reportConnectionResult();
  return load();
});

const connect = async service => {
  busyService.value = service;
  try {
    window.location.assign(
      (await servicesAPI.getGoogleAuthUrl(service)).data.authorizationUrl
    );
  } catch (error) {
    useAlert(t('AI_BRAIN.ERROR'));
    busyService.value = null;
  }
};

const disconnect = async (service, name) => {
  if (!window.confirm(t('AI_BRAIN.CONFIRM_DISCONNECT', { service: name }))) {
    return;
  }
  busyService.value = service;
  try {
    await servicesAPI.disconnectGoogle(service);
    await load();
  } catch (error) {
    useAlert(t('AI_BRAIN.ERROR'));
  } finally {
    busyService.value = null;
  }
};
</script>

<template>
  <SettingsLayout :is-loading="!!busyService && !status">
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
            width="3xl"
            overflow-y-auto
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
              <div
                v-if="termsForm"
                class="flex flex-col gap-4 pt-4 border-t border-n-weak"
              >
                <div class="flex flex-col gap-1">
                  <h3 class="text-base font-medium text-n-slate-12">
                    {{ t('AI_BRAIN.SERVICE_TERMS.TITLE') }}
                  </h3>
                  <p class="text-sm text-n-slate-11">
                    {{ t('AI_BRAIN.SERVICE_TERMS.PROFESSIONAL_HINT') }}
                  </p>
                </div>
                <ServiceTermsEditor
                  v-model="termsForm"
                  mode="override"
                  :errors="termsErrors"
                />
              </div>
            </div>
          </Dialog>
        </SectionLayout>

        <ServiceConnectionCard
          v-if="status"
          :title="t('AI_BRAIN.GOOGLE_CALENDAR')"
          :status="status"
          :busy="busyService === GOOGLE_CALENDAR"
          @connect="connect(GOOGLE_CALENDAR)"
          @disconnect="
            disconnect(GOOGLE_CALENDAR, t('AI_BRAIN.GOOGLE_CALENDAR'))
          "
        >
          <template #account>
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
          </template>
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
        </ServiceConnectionCard>

        <ServiceConnectionCard
          v-if="driveStatus"
          :title="t('AI_BRAIN.GOOGLE_DRIVE')"
          :description="t('AI_BRAIN.GOOGLE_DRIVE_DESCRIPTION')"
          :status="driveStatus"
          :busy="busyService === GOOGLE_DRIVE"
          @connect="connect(GOOGLE_DRIVE)"
          @disconnect="disconnect(GOOGLE_DRIVE, t('AI_BRAIN.GOOGLE_DRIVE'))"
        />
      </div>
    </template>
  </SettingsLayout>
</template>
