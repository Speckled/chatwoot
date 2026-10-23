<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useAiBrainAgentsStore } from 'dashboard/store/aiBrain/agents';
import rulesAPI from 'dashboard/api/aiBrain/businessRules';
import servicesAPI from 'dashboard/api/aiBrain/services';
import inboxesAPI from 'dashboard/api/aiBrain/inboxes';

const { t } = useI18n();
const route = useRoute();
const agentsStore = useAiBrainAgentsStore();
const accountId = computed(() => route.params.accountId);
const agents = computed(() =>
  agentsStore.accountId === accountId.value ? agentsStore.agents : []
);
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
      agentsStore.fetch(accountId.value),
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
const assign = async (inbox, agentId) => {
  try {
    if (agentId) await inboxesAPI.assign(inbox.id, agentId);
    else await inboxesAPI.unassign(inbox.id);
    inbox.aiBrainInbox = agentId
      ? { agentDefinitionId: agentId, active: true }
      : null;
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
        <h2 class="font-semibold">{{ t('AI_BRAIN.AGENTS') }}</h2>
        <p>
          {{ agents.length }} /
          {{ agents.filter(agent => agent.isActive).length }}
          {{ t('AI_BRAIN.ACTIVE') }}
        </p>
        <router-link
          :to="{ name: 'ai_brain_agents_new', params: { accountId } }"
        >
          {{ t('AI_BRAIN.CREATE') }}
        </router-link>
        <router-link
          class="ms-4"
          :to="{ name: 'ai_brain_agents', params: { accountId } }"
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
            <th>{{ t('AI_BRAIN.AGENT') }}</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="inbox in inboxes" :key="inbox.id" class="border-t">
            <td class="py-2">{{ inbox.name }} (#{{ inbox.id }})</td>
            <td>{{ inbox.channelType }}</td>
            <td>
              <select
                class="rounded border p-2"
                :value="inbox.aiBrainInbox?.agentDefinitionId || ''"
                @change="assign(inbox, $event.target.value)"
              >
                <option value="">{{ t('AI_BRAIN.NONE') }}</option>
                <option
                  v-for="agent in agents.filter(item => item.isActive)"
                  :key="agent.id"
                  :value="agent.id"
                >
                  {{ agent.name }}
                </option>
              </select>
            </td>
          </tr>
        </tbody>
      </table>
    </section>
  </main>
</template>
