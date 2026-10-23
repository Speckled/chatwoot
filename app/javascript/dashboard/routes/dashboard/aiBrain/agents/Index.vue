<script setup>
import { computed, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useAiBrainAgentsStore } from 'dashboard/store/aiBrain/agents';
import agentsAPI from 'dashboard/api/aiBrain/agents';

const { t } = useI18n();
const route = useRoute();
const store = useAiBrainAgentsStore();
const accountId = computed(() => route.params.accountId);
const agents = computed(() =>
  store.accountId === accountId.value ? store.agents : []
);
onMounted(() => store.fetch(accountId.value));
const remove = async agent => {
  if (!window.confirm(t('AI_BRAIN.CONFIRM_DELETE'))) return;
  try {
    await agentsAPI.delete(agent.id);
    await store.fetch(accountId.value);
  } catch (error) {
    useAlert(t('AI_BRAIN.ERROR'));
  }
};
</script>

<template>
  <main class="flex flex-col gap-6 overflow-y-auto p-6">
    <h1 class="text-2xl font-semibold">{{ t('AI_BRAIN.AGENTS') }}</h1>
    <router-link
      class="w-fit rounded bg-n-brand px-4 py-2 text-white"
      :to="{ name: 'ai_brain_agents_new', params: { accountId } }"
    >
      {{ t('AI_BRAIN.CREATE') }}
    </router-link>
    <table class="w-full">
      <thead>
        <tr>
          <th>{{ t('AI_BRAIN.NAME') }}</th>
          <th>{{ t('AI_BRAIN.DESCRIPTION') }}</th>
          <th>{{ t('AI_BRAIN.MODEL') }}</th>
          <th>{{ t('AI_BRAIN.ACTIVE') }}</th>
          <th>{{ t('AI_BRAIN.TOOLS') }}</th>
          <th>{{ t('AI_BRAIN.VERSION') }}</th>
          <th>{{ t('AI_BRAIN.ACTIONS') }}</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="agent in agents" :key="agent.id" class="border-t">
          <td>{{ agent.name }}</td>
          <td>{{ agent.description }}</td>
          <td>{{ agent.config?.modelId }}</td>
          <td>
            {{ t(agent.isActive ? 'AI_BRAIN.ACTIVE' : 'AI_BRAIN.INACTIVE') }}
          </td>
          <td>{{ agent.config?.enabledTools?.length }}</td>
          <td>{{ agent.version }}</td>
          <td class="flex gap-3">
            <router-link
              :to="{
                name: 'ai_brain_agents_edit',
                params: { accountId, agentId: agent.id },
              }"
            >
              {{ t('AI_BRAIN.EDIT') }}
            </router-link>
            <button type="button" @click="remove(agent)">
              {{ t('AI_BRAIN.REMOVE') }}
            </button>
          </td>
        </tr>
      </tbody>
    </table>
  </main>
</template>
