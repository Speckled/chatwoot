<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import SettingsLayout from '../../settings/SettingsLayout.vue';
import BaseSettingsHeader from '../../settings/components/BaseSettingsHeader.vue';
import SectionLayout from '../../settings/account/components/SectionLayout.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
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
  <SettingsLayout :is-loading="busy && !rules">
    <template #header>
      <BaseSettingsHeader :title="t('AI_BRAIN.OVERVIEW')" />
    </template>
    <template #body>
      <div class="flex flex-col gap-6 w-full">
        <div
          class="flex items-center justify-between p-4 rounded-xl border border-n-weak bg-n-solid-1"
        >
          <div class="flex flex-col gap-0.5">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('AI_BRAIN.MASTER_SWITCH') }}
            </span>
          </div>
          <Switch
            :model-value="Boolean(rules?.isAiEnabled)"
            :disabled="!rules || busy"
            @change="toggle"
          />
        </div>

        <div class="grid gap-4 md:grid-cols-2">
          <div
            class="flex flex-col justify-between p-5 rounded-xl border border-n-weak bg-n-solid-1 gap-3"
          >
            <div class="flex flex-col gap-1">
              <h3 class="text-sm font-medium text-n-slate-12">
                {{ t('AI_BRAIN.RULES') }}
              </h3>
              <p class="text-sm text-n-slate-11">
                {{ t('AI_BRAIN.PROVIDER') }}:
                {{ rules?.aiProvider || 'OpenRouter' }} ({{
                  rules?.modelId || '-'
                }})
              </p>
              <p class="text-sm text-n-slate-11">
                {{
                  `${t('AI_BRAIN.INACTIVITY_NUDGE')}: ${rules?.inactivityNudgeMinutes ?? 5}m / ${t('AI_BRAIN.INACTIVITY_CLOSE')}: ${rules?.inactivityAutoCloseMinutes ?? 10}m`
                }}
              </p>
            </div>
            <div>
              <router-link
                class="inline-flex items-center text-sm font-medium text-n-brand hover:underline"
                :to="{ name: 'ai_brain_rules', params: { accountId } }"
              >
                {{ t('AI_BRAIN.MANAGE') }}
              </router-link>
            </div>
          </div>

          <div
            class="flex flex-col justify-between p-5 rounded-xl border border-n-weak bg-n-solid-1 gap-3"
          >
            <div class="flex flex-col gap-1">
              <h3 class="text-sm font-medium text-n-slate-12">
                {{ t('AI_BRAIN.SERVICES') }}
              </h3>
              <p class="text-sm text-n-slate-12 font-medium">
                {{ services[0]?.accountEmail || t('AI_BRAIN.DISCONNECTED') }}
              </p>
              <p
                v-if="
                  services[0]?.calendar?.summary &&
                  services[0]?.calendar?.summary !== services[0]?.accountEmail
                "
                class="text-sm text-n-slate-11"
              >
                {{ t('AI_BRAIN.PRIMARY') }}:
                {{ services[0]?.calendar?.summary }}
              </p>
            </div>
            <div>
              <router-link
                class="inline-flex items-center text-sm font-medium text-n-brand hover:underline"
                :to="{ name: 'ai_brain_services', params: { accountId } }"
              >
                {{ t('AI_BRAIN.MANAGE') }}
              </router-link>
            </div>
          </div>
        </div>

        <SectionLayout :title="t('AI_BRAIN.INBOX_ROUTING')" with-border>
          <div class="w-full">
            <table class="min-w-full table-auto divide-y divide-n-weak">
              <thead>
                <tr class="border-t border-n-weak">
                  <th
                    class="py-3 ltr:pr-4 rtl:pl-4 text-start text-sm font-medium text-n-slate-12"
                  >
                    {{ t('AI_BRAIN.INBOX') }}
                  </th>
                  <th
                    class="py-3 ltr:pr-4 rtl:pl-4 text-start text-sm font-medium text-n-slate-12"
                  >
                    {{ t('AI_BRAIN.CHANNEL') }}
                  </th>
                  <th
                    class="py-3 ltr:pr-4 rtl:pl-4 text-end text-sm font-medium text-n-slate-12"
                  >
                    {{ t('AI_BRAIN.ACTIVE') }}
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-n-weak text-n-slate-11">
                <tr v-for="inbox in inboxes" :key="inbox.id">
                  <td class="py-3 ltr:pr-4 rtl:pl-4 text-sm text-n-slate-12">
                    {{ inbox.name }} (#{{ inbox.id }})
                  </td>
                  <td class="py-3 ltr:pr-4 rtl:pl-4 text-sm text-n-slate-11">
                    {{ inbox.channelType }}
                  </td>
                  <td class="py-3 ltr:pr-4 rtl:pl-4 text-end">
                    <Switch
                      :model-value="Boolean(inbox.aiBrainInbox?.active)"
                      @change="val => toggleInbox(inbox, val)"
                    />
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </SectionLayout>
      </div>
    </template>
  </SettingsLayout>
</template>
