<script setup>
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import SettingsLayout from '../../settings/SettingsLayout.vue';
import BaseSettingsHeader from '../../settings/components/BaseSettingsHeader.vue';
import SectionLayout from '../../settings/account/components/SectionLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import servicesAPI from 'dashboard/api/aiBrain/services';

const { t } = useI18n();
const status = ref(null);
const calendars = ref([]);
const doctors = ref([]);
const linkingUserId = ref(null);
const showCalendars = ref(false);
const busy = ref(false);

const load = async () => {
  try {
    const [serviceRes, usersRes] = await Promise.all([
      servicesAPI.get(),
      servicesAPI.getUsers({ team: 'Médicos' }),
    ]);
    status.value = serviceRes.data[0];
    doctors.value = usersRes.data || [];
    calendars.value = status.value?.availableCalendars || [];
    if (status.value?.isConnected && status.value?.isValid) {
      calendars.value = (await servicesAPI.getCalendars()).data;
    }
  } catch (error) {
    useAlert(t('AI_BRAIN.ERROR'));
  }
};

const onUserCalendarChange = async (user, event) => {
  const selectedCalendarId = event.target.value || null;
  const targetCalendarId = selectedCalendarId || user.linkedCalendarId;
  if (!targetCalendarId) return;

  linkingUserId.value = user.id;
  try {
    await servicesAPI.linkCalendarUser(
      targetCalendarId,
      selectedCalendarId ? user.id : null
    );
    useAlert(t('AI_BRAIN.CALENDAR_LINKED'));
    await load();
  } catch (error) {
    useAlert(t('AI_BRAIN.ERROR'));
  } finally {
    linkingUserId.value = null;
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
              v-if="doctors.length"
              class="min-w-full table-auto divide-y divide-n-weak"
            >
              <thead>
                <tr class="border-t border-n-weak">
                  <th
                    class="py-3 ltr:pr-4 rtl:pl-4 text-start text-sm font-medium text-n-slate-12"
                  >
                    {{ t('AI_BRAIN.NAME') }}
                  </th>
                  <th
                    class="py-3 ltr:pr-4 rtl:pl-4 text-start text-sm font-medium text-n-slate-12"
                  >
                    {{ t('AI_BRAIN.EMAIL') }}
                  </th>
                  <th
                    class="py-3 ltr:pr-4 rtl:pl-4 text-start text-sm font-medium text-n-slate-12"
                  >
                    {{ t('AI_BRAIN.LINKED_CALENDAR') }}
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-n-weak text-n-slate-11">
                <tr v-for="doc in doctors" :key="doc.id">
                  <td
                    class="py-3 ltr:pr-4 rtl:pl-4 text-sm text-n-slate-12 font-medium"
                  >
                    {{ doc.displayName || doc.name }}
                  </td>
                  <td class="py-3 ltr:pr-4 rtl:pl-4 text-sm text-n-slate-11">
                    {{ doc.email || '-' }}
                  </td>
                  <td class="py-3 ltr:pr-4 rtl:pl-4 text-sm text-n-slate-12">
                    <select
                      :disabled="linkingUserId === doc.id || !calendars.length"
                      :value="doc.linkedCalendarId || ''"
                      class="w-full max-w-md text-sm rounded-lg border border-n-weak bg-n-solid-1 text-n-slate-12 px-2.5 py-1.5 focus:border-n-brand focus:outline-none"
                      @change="onUserCalendarChange(doc, $event)"
                    >
                      <option value="">{{ t('AI_BRAIN.NO_CALENDAR') }}</option>
                      <option
                        v-for="cal in calendars"
                        :key="cal.id"
                        :value="cal.id"
                      >
                        {{ cal.summary
                        }}{{
                          cal.isPrimary ? ` (${t('AI_BRAIN.PRIMARY')})` : ''
                        }}
                      </option>
                    </select>
                  </td>
                </tr>
              </tbody>
            </table>
            <p v-else class="text-sm text-n-slate-11 py-2">
              {{ t('AI_BRAIN.NO_USERS_FOUND') }}
            </p>
          </div>
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
