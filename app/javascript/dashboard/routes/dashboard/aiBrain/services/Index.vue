<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import servicesAPI from 'dashboard/api/aiBrain/services';

const { t } = useI18n();
const status = ref(null);
const calendars = ref([]);
const busy = ref(false);
const load = async () => {
  try {
    status.value = (await servicesAPI.get()).data[0];
    calendars.value = status.value?.availableCalendars || [];
    if (status.value?.isConnected && status.value?.isValid) {
      calendars.value = (await servicesAPI.getCalendars()).data;
    }
  } catch (error) {
    useAlert(t('AI_BRAIN.ERROR'));
  }
};
const primary = computed(() => status.value?.calendar);
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
  <main class="flex flex-col gap-6 overflow-y-auto p-6">
    <h1 class="text-2xl font-semibold">{{ t('AI_BRAIN.SERVICES') }}</h1>
    <section v-if="status" class="flex flex-col gap-3 rounded-lg border p-4">
      <h2 class="font-semibold">{{ t('AI_BRAIN.GOOGLE_CALENDAR') }}</h2>
      <p>
        {{
          status.isConnected
            ? t('AI_BRAIN.CONNECTED')
            : t('AI_BRAIN.DISCONNECTED')
        }}
      </p>
      <p v-if="status.accountEmail">
        {{ status.accountEmail }} · {{ status.timeZone }} ·
        {{ status.connectedAt }}
      </p>
      <p v-if="status.validationError" class="text-n-ruby-9">
        {{ status.validationError }}
      </p>
      <p v-if="primary">
        {{ t('AI_BRAIN.PRIMARY') }}: {{ primary.summary }} ({{ primary.id }}) ·
        {{ primary.timeZone }} · {{ primary.accessRole }}
      </p>
      <div class="flex gap-3">
        <button
          type="button"
          :disabled="busy"
          class="rounded bg-n-brand px-4 py-2 text-white"
          @click="connect"
        >
          {{
            t(status.isConnected ? 'AI_BRAIN.RECONNECT' : 'AI_BRAIN.CONNECT')
          }}
        </button>
        <button
          v-if="status.isConnected"
          type="button"
          :disabled="busy"
          class="rounded border px-4 py-2"
          @click="disconnect"
        >
          {{ t('AI_BRAIN.DISCONNECT') }}
        </button>
      </div>
    </section>
    <section class="rounded-lg border p-4">
      <h2 class="mb-4 font-semibold">
        {{ t('AI_BRAIN.AVAILABLE_CALENDARS') }}
      </h2>
      <table class="w-full">
        <thead>
          <tr>
            <th>{{ t('AI_BRAIN.NAME') }}</th>
            <th>{{ t('AI_BRAIN.ID') }}</th>
            <th>{{ t('AI_BRAIN.ACCESS') }}</th>
            <th>{{ t('AI_BRAIN.TIME_ZONE') }}</th>
            <th>{{ t('AI_BRAIN.DESCRIPTION') }}</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="calendar in calendars" :key="calendar.id" class="border-t">
            <td>
              {{ calendar.summary }}
              <span v-if="calendar.isPrimary">{{ t('AI_BRAIN.PRIMARY') }}</span>
            </td>
            <td>{{ calendar.id }}</td>
            <td>{{ calendar.accessRole }}</td>
            <td>{{ calendar.timeZone }}</td>
            <td>{{ calendar.description }}</td>
          </tr>
        </tbody>
      </table>
    </section>
  </main>
</template>
