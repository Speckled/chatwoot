<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useAiBrainAgentsStore } from 'dashboard/store/aiBrain/agents';
import agentsAPI from 'dashboard/api/aiBrain/agents';
import StringListEditor from 'dashboard/components-next/aiBrain/StringListEditor.vue';
import KeyValueEditor from 'dashboard/components-next/aiBrain/KeyValueEditor.vue';

const { t } = useI18n();
const router = useRouter();
const route = useRoute();
const store = useAiBrainAgentsStore();
const editing = computed(() => !!route.params.agentId);
const agent = ref(null);
const version = ref(null);
const conflict = ref(false);
const busy = ref(false);
const load = async () => {
  try {
    const options = await store.fetchOptions();
    if (editing.value) {
      const { data } = await agentsAPI.show(route.params.agentId);
      agent.value = data;
      version.value = data.version;
    } else {
      agent.value = {
        name: '',
        description: '',
        isActive: true,
        config: {
          provider: 'OpenRouter',
          modelId: options.defaultModelId,
          temperature: 0.2,
          maxOutputTokens: 800,
          systemInstructions: '',
          tone: '',
          reviewPolicy: 1,
          capabilities: ['text.response'],
          guardrailRules: [],
          enabledTools: [],
          toolParameters: {},
        },
      };
    }
    conflict.value = false;
  } catch (error) {
    useAlert(t('AI_BRAIN.ERROR'));
  }
};
onMounted(load);
const toggleTool = key => {
  const list = agent.value.config.enabledTools;
  agent.value.config.enabledTools = list.includes(key)
    ? list.filter(item => item !== key)
    : [...list, key];
};
const save = async () => {
  busy.value = true;
  try {
    const payload = {
      name: agent.value.name,
      description: agent.value.description,
      isActive: agent.value.isActive,
      config: agent.value.config,
    };
    if (editing.value)
      await agentsAPI.update(route.params.agentId, payload, version.value);
    else await agentsAPI.create(payload);
    await store.fetch(route.params.accountId);
    router.push({
      name: 'ai_brain_agents',
      params: { accountId: route.params.accountId },
    });
  } catch (error) {
    conflict.value = error.response?.status === 409;
    useAlert(t(conflict.value ? 'AI_BRAIN.CONFLICT' : 'AI_BRAIN.ERROR'));
  } finally {
    busy.value = false;
  }
};
</script>

<template>
  <main class="flex flex-col gap-6 overflow-y-auto p-6">
    <h1 class="text-2xl font-semibold">
      {{ t(editing ? 'AI_BRAIN.EDIT_AGENT' : 'AI_BRAIN.CREATE_AGENT') }}
    </h1>
    <button
      v-if="conflict"
      type="button"
      class="w-fit rounded border p-2"
      @click="load"
    >
      {{ t('AI_BRAIN.RELOAD') }}
    </button>
    <form
      v-if="agent"
      class="flex max-w-3xl flex-col gap-4"
      @submit.prevent="save"
    >
      <label
        >{{ t('AI_BRAIN.NAME')
        }}<input
          v-model="agent.name"
          class="block w-full rounded border p-2"
          required
      /></label>
      <label
        >{{ t('AI_BRAIN.DESCRIPTION')
        }}<textarea
          v-model="agent.description"
          class="block w-full rounded border p-2"
        />
      </label>
      <label class="flex gap-2"
        ><input v-model="agent.isActive" type="checkbox" />{{
          t('AI_BRAIN.ACTIVE')
        }}</label
      >
      <label
        >{{ t('AI_BRAIN.PROVIDER')
        }}<select
          v-model="agent.config.provider"
          class="block w-full rounded border p-2"
        >
          <option
            v-for="provider in store.options?.providers"
            :key="provider"
            :value="provider"
          >
            {{ provider }}
          </option>
        </select></label
      >
      <label
        >{{ t('AI_BRAIN.MODEL')
        }}<input
          v-model="agent.config.modelId"
          required
          class="block w-full rounded border p-2"
      /></label>
      <label
        >{{ t('AI_BRAIN.TEMPERATURE')
        }}<input
          v-model.number="agent.config.temperature"
          type="number"
          min="0"
          max="2"
          step="0.01"
          class="block w-full rounded border p-2"
      /></label>
      <label
        >{{ t('AI_BRAIN.MAX_TOKENS')
        }}<input
          v-model.number="agent.config.maxOutputTokens"
          type="number"
          min="1"
          max="16384"
          class="block w-full rounded border p-2"
      /></label>
      <label
        >{{ t('AI_BRAIN.SYSTEM_INSTRUCTIONS')
        }}<textarea
          v-model="agent.config.systemInstructions"
          rows="8"
          class="block w-full rounded border p-2"
        />
      </label>
      <label
        >{{ t('AI_BRAIN.TONE')
        }}<input
          v-model="agent.config.tone"
          class="block w-full rounded border p-2"
      /></label>
      <StringListEditor
        v-model="agent.config.guardrailRules"
        :label="t('AI_BRAIN.GUARDRAILS')"
      />
      <label
        >{{ t('AI_BRAIN.REVIEW_POLICY')
        }}<select
          v-model.number="agent.config.reviewPolicy"
          class="block w-full rounded border p-2"
        >
          <option
            v-for="(policy, index) in store.options?.reviewPolicies"
            :key="policy"
            :value="index"
          >
            {{ policy }}
          </option>
        </select></label
      >
      <fieldset class="flex flex-col gap-2 rounded border p-4">
        <legend>{{ t('AI_BRAIN.TOOLS') }}</legend>
        <label
          v-for="tool in store.options?.supportedTools"
          :key="tool.key"
          class="flex gap-2"
        >
          <input
            type="checkbox"
            :checked="agent.config.enabledTools.includes(tool.key)"
            @change="toggleTool(tool.key)"
          />
          <span>{{ tool.name }} — {{ tool.description }}</span>
        </label>
      </fieldset>
      <KeyValueEditor v-model="agent.config.toolParameters" />
      <button
        type="submit"
        :disabled="busy"
        class="w-fit rounded bg-n-brand px-4 py-2 text-white"
      >
        {{ t('AI_BRAIN.SAVE') }}
      </button>
    </form>
  </main>
</template>
