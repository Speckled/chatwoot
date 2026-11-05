<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import SettingsLayout from '../../settings/SettingsLayout.vue';
import BaseSettingsHeader from '../../settings/components/BaseSettingsHeader.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import rulesAPI from 'dashboard/api/aiBrain/businessRules';
import ConfigurationTab from './tabs/ConfigurationTab.vue';
import InstructionsTab from './tabs/InstructionsTab.vue';
import KnowledgeTab from './tabs/KnowledgeTab.vue';
import ServicesPricingTab from './tabs/ServicesPricingTab.vue';
import { RULES_FORM_TABS, RULES_TABS, tabIndex } from './rulesTabs';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const tabs = computed(() =>
  RULES_TABS.map(tab => ({ label: t(tab.labelKey) }))
);
const activeTab = computed(() => tabIndex(route.query.tab));
const activeTabId = computed(() => RULES_TABS[activeTab.value].id);
const editsRules = computed(() => RULES_FORM_TABS.includes(activeTabId.value));
const selectTab = index =>
  router.replace({ query: { ...route.query, tab: RULES_TABS[index].id } });

// The Configuration and Instructions tabs edit this one object, saved whole, as the Overview page's switch does.
const rules = ref(null);
const busy = ref(false);
const load = async () => {
  try {
    const { data } = await rulesAPI.get();
    rules.value = {
      aiProvider: 'OpenRouter',
      modelId: '~deepseek/deepseek-flash-latest',
      temperature: 0.2,
      maxOutputTokens: 800,
      tone: '',
      inactivityNudgeMinutes: 5,
      inactivityAutoCloseMinutes: 10,
      otherSessionInactivityMinutes: 30,
      requiredOnboardingFields: ['Name'],
      optionalOnboardingFields: ['Email'],
      chargeTiming: 0,
      ...data,
    };
  } catch (error) {
    useAlert(t('AI_BRAIN.ERROR'));
  }
};
onMounted(load);
const saveRules = async () => {
  busy.value = true;
  try {
    const { data } = await rulesAPI.update({
      ...rules.value,
      workingHours: {
        ...rules.value.workingHours,
        blackoutDates: rules.value.workingHours.blackoutDates,
      },
    });
    rules.value = data;
    useAlert(t('AI_BRAIN.SAVED'));
  } catch (error) {
    useAlert(t('AI_BRAIN.ERROR'));
  } finally {
    busy.value = false;
  }
};
</script>

<template>
  <SettingsLayout :is-loading="busy && !rules">
    <template #header>
      <BaseSettingsHeader :title="t('AI_BRAIN.RULES')">
        <template #tabs>
          <TabBar
            :tabs="tabs"
            :initial-active-tab="activeTab"
            @tab-changed="tab => selectTab(tabs.indexOf(tab))"
          />
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <form
        v-if="editsRules && rules"
        class="flex flex-col gap-6 w-full"
        @submit.prevent="saveRules"
      >
        <ConfigurationTab
          v-if="activeTabId === 'configuration'"
          v-model="rules"
        />
        <InstructionsTab v-else v-model="rules" />
        <div class="pt-2">
          <Button
            type="submit"
            color="blue"
            :is-loading="busy"
            :label="t('AI_BRAIN.SAVE')"
          />
        </div>
      </form>
      <KnowledgeTab v-else-if="activeTabId === 'knowledge'" />
      <ServicesPricingTab v-else-if="activeTabId === 'services'" />
    </template>
  </SettingsLayout>
</template>
