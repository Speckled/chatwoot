<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import rulesAPI from 'dashboard/api/aiBrain/businessRules';
import servicesAPI from 'dashboard/api/aiBrain/services';
import inboxesAPI from 'dashboard/api/aiBrain/inboxes';

const { t } = useI18n();
const route = useRoute();
const accountId = computed(() => route.params.accountId);
const rules = ref(null);
const services = ref([]);
const inboxes = ref([]);
const busy = ref(false);
const load = async () => {
  try {
    const [ruleResponse, serviceResponse, inboxResponse] = await Promise.all([
      rulesAPI.get(),
      servicesAPI.get(),
      inboxesAPI.get(),
    ]);
    rules.value = ruleResponse.data;
    services.value = serviceResponse.data;
    inboxes.value = inboxResponse.data;
  } catch (error) {
    useAlert(t('AI_BRAIN.ERROR'));
  }
};
onMounted(load);
watch(accountId, load);
const toggle = async () => {
  busy.value = true;
  try {
    const { data } = await rulesAPI.update({
      ...rules.value,
      isAiEnabled: !rules.value.isAiEnabled,
    });
    rules.value = data;
  } catch (error) {
    useAlert(t('AI_BRAIN.ERROR'));
  } finally {
    busy.value = false;
  }
};
const toggleInbox = async (inbox, active) => {
  try {
    if (active) {
      await inboxesAPI.toggle(inbox.id, true);
      inbox.aiBrainInbox = { active: true };
    } else {
      await inboxesAPI.unassign(inbox.id);
      inbox.aiBrainInbox = null;
    }
  } catch (error) {
    useAlert(t('AI_BRAIN.ERROR'));
  }
};
</script>

<template>
  <main class="flex flex-col gap-6 overflow-y-auto p-6">
    <h1 class="text-2xl font-semibold">{{ t('AI_BRAIN.OVERVIEW') }}</h1>
    <section class="rounded-lg border p-4">
      <label class="flex items-center gap-3 font-medium">
        <input
          type="checkbox"
          :checked="rules?.isAiEnabled"
          :disabled="!rules || busy"
          @change="toggle"
        />
        {{ t('AI_BRAIN.MASTER_SWITCH') }}
      </label>
    </section>
    <div class="grid gap-4 md:grid-cols-2">
      <section class="rounded-lg border p-4">
        <h2 class="font-semibold">{{ t('AI_BRAIN.RULES') }}</h2>
        <p class="mt-1 text-sm">
          {{ t('AI_BRAIN.PROVIDER') }}: {{ rules?.aiProvider || 'OpenRouter' }}
          ({{ rules?.modelId || '-' }})
        </p>
        <p class="text-sm">
          {{ t('AI_BRAIN.INACTIVITY_NUDGE') }}:
          {{ rules?.inactivityNudgeMinutes ?? 5 }}m /
          {{ t('AI_BRAIN.INACTIVITY_CLOSE') }}:
          {{ rules?.inactivityAutoCloseMinutes ?? 10 }}m
        </p>
        <router-link
          class="mt-2 inline-block text-n-brand"
          :to="{ name: 'ai_brain_rules', params: { accountId } }"
        >
          {{ t('AI_BRAIN.MANAGE') }}
        </router-link>
      </section>
      <section class="rounded-lg border p-4">
        <h2 class="font-semibold">{{ t('AI_BRAIN.SERVICES') }}</h2>
        <p>{{ services[0]?.accountEmail || t('AI_BRAIN.DISCONNECTED') }}</p>
        <p>{{ services[0]?.calendar?.summary }}</p>
        <router-link :to="{ name: 'ai_brain_services', params: { accountId } }">
          {{ t('AI_BRAIN.MANAGE') }}
        </router-link>
      </section>
    </div>
    <section class="rounded-lg border p-4">
      <h2 class="mb-4 font-semibold">{{ t('AI_BRAIN.INBOX_ROUTING') }}</h2>
      <table class="w-full text-start">
        <thead>
          <tr>
            <th>{{ t('AI_BRAIN.INBOX') }}</th>
            <th>{{ t('AI_BRAIN.CHANNEL') }}</th>
            <th>{{ t('AI_BRAIN.ACTIVE') }}</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="inbox in inboxes" :key="inbox.id" class="border-t">
            <td class="py-2">{{ inbox.name }} (#{{ inbox.id }})</td>
            <td>{{ inbox.channelType }}</td>
            <td>
              <input
                type="checkbox"
                :checked="Boolean(inbox.aiBrainInbox?.active)"
                @change="toggleInbox(inbox, $event.target.checked)"
              />
            </td>
          </tr>
        </tbody>
      </table>
    </section>
  </main>
</template>
