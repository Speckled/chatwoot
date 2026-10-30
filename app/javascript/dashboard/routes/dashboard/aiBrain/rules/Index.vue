<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import SettingsLayout from '../../settings/SettingsLayout.vue';
import BaseSettingsHeader from '../../settings/components/BaseSettingsHeader.vue';
import SectionLayout from '../../settings/account/components/SectionLayout.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import StringListEditor from 'dashboard/components-next/aiBrain/StringListEditor.vue';
import rulesAPI from 'dashboard/api/aiBrain/businessRules';
import faqsAPI from 'dashboard/api/aiBrain/faqs';

const { t } = useI18n();
const activeTab = ref(0);
const tabs = computed(() => [
  { label: t('AI_BRAIN.RULES') },
  { label: t('AI_BRAIN.FAQS') },
]);
const rules = ref(null);
const faqs = ref([]);
const editing = ref(null);
const busy = ref(false);
const days = [0, 1, 2, 3, 4, 5, 6];
const load = async () => {
  try {
    const [ruleResponse, faqResponse] = await Promise.all([
      rulesAPI.get(),
      faqsAPI.get(),
    ]);
    rules.value = {
      aiProvider: 'OpenRouter',
      modelId: '~deepseek/deepseek-flash-latest',
      temperature: 0.2,
      maxOutputTokens: 800,
      tone: '',
      inactivityNudgeMinutes: 5,
      inactivityAutoCloseMinutes: 10,
      otherSessionInactivityHours: 24,
      requiredOnboardingFields: ['Name'],
      optionalOnboardingFields: ['Email'],
      ...ruleResponse.data,
    };
    faqs.value = faqResponse.data;
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
const toggleDay = day => {
  const schedule = rules.value.workingHours;
  schedule.activeDays = schedule.activeDays.includes(day)
    ? schedule.activeDays.filter(item => item !== day)
    : [...schedule.activeDays, day];
};
const newFaq = () => {
  editing.value = {
    category: '',
    title: '',
    content: '',
    tags: [],
    isActive: true,
  };
};
const editFaq = faq => {
  editing.value = { ...faq, tags: [...faq.tags] };
};
const saveFaq = async () => {
  busy.value = true;
  try {
    const faq = { ...editing.value, tags: editing.value.tags };
    if (faq.id) await faqsAPI.update(faq.id, faq);
    else await faqsAPI.create(faq);
    editing.value = null;
    faqs.value = (await faqsAPI.get()).data;
  } catch (error) {
    useAlert(t('AI_BRAIN.ERROR'));
  } finally {
    busy.value = false;
  }
};
const removeFaq = async faq => {
  if (!window.confirm(t('AI_BRAIN.CONFIRM_DELETE'))) return;
  try {
    await faqsAPI.delete(faq.id);
    faqs.value = faqs.value.filter(item => item.id !== faq.id);
  } catch (error) {
    useAlert(t('AI_BRAIN.ERROR'));
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
            @tab-changed="tab => (activeTab = tabs.indexOf(tab))"
          />
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <form
        v-if="activeTab === 0 && rules"
        class="flex flex-col gap-6 w-full"
        @submit.prevent="saveRules"
      >
        <SectionLayout :title="t('AI_BRAIN.RULES')" class="!pt-0">
          <div class="grid gap-4">
            <WithLabel
              name="business-name"
              :label="t('AI_BRAIN.BUSINESS_NAME')"
            >
              <NextInput v-model="rules.businessName" class="w-full" />
            </WithLabel>
            <WithLabel name="time-zone" :label="t('AI_BRAIN.TIME_ZONE')">
              <NextInput v-model="rules.timeZone" class="w-full" required />
            </WithLabel>
            <div
              class="flex items-center justify-between p-4 rounded-xl border border-n-weak bg-n-solid-1"
            >
              <span class="text-sm font-medium text-n-slate-12">
                {{ t('AI_BRAIN.ALLOWLIST') }}
              </span>
              <Switch v-model="rules.enforceAllowlist" />
            </div>
          </div>
        </SectionLayout>

        <SectionLayout :title="t('AI_BRAIN.MODEL_CONFIG')" with-border>
          <div class="grid gap-4">
            <div class="grid gap-4 md:grid-cols-2">
              <WithLabel name="ai-provider" :label="t('AI_BRAIN.PROVIDER')">
                <NextInput v-model="rules.aiProvider" class="w-full" required />
              </WithLabel>
              <WithLabel name="model-id" :label="t('AI_BRAIN.MODEL')">
                <NextInput v-model="rules.modelId" class="w-full" required />
              </WithLabel>
            </div>
            <div class="grid gap-4 md:grid-cols-2">
              <WithLabel name="temperature" :label="t('AI_BRAIN.TEMPERATURE')">
                <NextInput
                  v-model.number="rules.temperature"
                  type="number"
                  step="0.1"
                  min="0"
                  max="2"
                  class="w-full"
                />
              </WithLabel>
              <WithLabel name="max-tokens" :label="t('AI_BRAIN.MAX_TOKENS')">
                <NextInput
                  v-model.number="rules.maxOutputTokens"
                  type="number"
                  min="1"
                  max="16384"
                  class="w-full"
                />
              </WithLabel>
            </div>
            <WithLabel name="tone" :label="t('AI_BRAIN.TONE')">
              <NextInput v-model="rules.tone" class="w-full" />
            </WithLabel>
          </div>
        </SectionLayout>

        <SectionLayout :title="t('AI_BRAIN.SESSION_SETTINGS')" with-border>
          <div class="grid gap-4">
            <div class="grid gap-4 md:grid-cols-3">
              <WithLabel
                name="nudge-minutes"
                :label="t('AI_BRAIN.INACTIVITY_NUDGE')"
              >
                <NextInput
                  v-model.number="rules.inactivityNudgeMinutes"
                  type="number"
                  min="1"
                  class="w-full"
                />
              </WithLabel>
              <WithLabel
                name="close-minutes"
                :label="t('AI_BRAIN.INACTIVITY_CLOSE')"
              >
                <NextInput
                  v-model.number="rules.inactivityAutoCloseMinutes"
                  type="number"
                  min="1"
                  class="w-full"
                />
              </WithLabel>
              <WithLabel
                name="handoff-hours"
                :label="t('AI_BRAIN.HUMAN_TIMEOUT_HOURS')"
              >
                <NextInput
                  v-model.number="rules.otherSessionInactivityHours"
                  type="number"
                  min="1"
                  class="w-full"
                />
              </WithLabel>
            </div>
            <StringListEditor
              v-model="rules.requiredOnboardingFields"
              :label="t('AI_BRAIN.REQUIRED_ONBOARDING')"
            />
            <StringListEditor
              v-model="rules.optionalOnboardingFields"
              :label="t('AI_BRAIN.OPTIONAL_ONBOARDING')"
            />
          </div>
        </SectionLayout>

        <SectionLayout :title="t('AI_BRAIN.GLOBAL_INSTRUCTIONS')" with-border>
          <div class="grid gap-4">
            <WithLabel
              name="global-instructions"
              :label="t('AI_BRAIN.GLOBAL_INSTRUCTIONS')"
            >
              <TextArea
                v-model="rules.globalInstructions"
                :max-length="4000"
                rows="5"
                class="w-full"
              />
            </WithLabel>
            <StringListEditor
              v-model="rules.companyRules"
              :label="t('AI_BRAIN.COMPANY_RULES')"
            />
            <StringListEditor
              v-model="rules.prohibitedBehaviors"
              :label="t('AI_BRAIN.PROHIBITED')"
            />
          </div>
        </SectionLayout>

        <SectionLayout :title="t('AI_BRAIN.WORKING_HOURS')" with-border>
          <div class="grid gap-4">
            <div class="flex flex-wrap gap-4 py-1">
              <label
                v-for="day in days"
                :key="day"
                class="flex items-center gap-2 cursor-pointer text-sm text-n-slate-12"
              >
                <Checkbox
                  :model-value="rules.workingHours?.activeDays?.includes(day)"
                  @change="toggleDay(day)"
                />
                <span>{{ t(`AI_BRAIN.DAYS.${day}`) }}</span>
              </label>
            </div>
            <div class="grid gap-4 md:grid-cols-3">
              <WithLabel name="start-time" :label="t('AI_BRAIN.START')">
                <NextInput
                  v-model="rules.workingHours.startTime"
                  type="time"
                  class="w-full"
                />
              </WithLabel>
              <WithLabel name="end-time" :label="t('AI_BRAIN.END')">
                <NextInput
                  v-model="rules.workingHours.endTime"
                  type="time"
                  class="w-full"
                />
              </WithLabel>
              <WithLabel name="slot-duration" :label="t('AI_BRAIN.SLOT')">
                <NextInput
                  v-model.number="rules.workingHours.defaultSlotDurationMinutes"
                  type="number"
                  min="1"
                  class="w-full"
                />
              </WithLabel>
            </div>
            <StringListEditor
              v-model="rules.workingHours.blackoutDates"
              :label="t('AI_BRAIN.BLACKOUT_DATES')"
            />
          </div>
        </SectionLayout>

        <div class="pt-2">
          <Button
            type="submit"
            color="blue"
            :is-loading="busy"
            :label="t('AI_BRAIN.SAVE')"
          />
        </div>
      </form>

      <section v-else-if="activeTab === 1" class="flex flex-col gap-4 w-full">
        <div class="flex justify-end w-full">
          <Button
            type="button"
            color="blue"
            size="sm"
            icon="i-woot-plus"
            :label="t('AI_BRAIN.CREATE')"
            @click="newFaq"
          />
        </div>

        <div class="w-full">
          <table class="min-w-full table-auto divide-y divide-n-weak">
            <thead>
              <tr class="border-t border-n-weak">
                <th
                  class="py-3 ltr:pr-4 rtl:pl-4 text-start text-sm font-medium text-n-slate-12"
                >
                  {{ t('AI_BRAIN.CATEGORY') }}
                </th>
                <th
                  class="py-3 ltr:pr-4 rtl:pl-4 text-start text-sm font-medium text-n-slate-12"
                >
                  {{ t('AI_BRAIN.TITLE') }}
                </th>
                <th
                  class="py-3 ltr:pr-4 rtl:pl-4 text-start text-sm font-medium text-n-slate-12"
                >
                  {{ t('AI_BRAIN.TAGS') }}
                </th>
                <th
                  class="py-3 ltr:pr-4 rtl:pl-4 text-start text-sm font-medium text-n-slate-12"
                >
                  {{ t('AI_BRAIN.ACTIVE') }}
                </th>
                <th
                  class="py-3 ltr:pr-4 rtl:pl-4 text-end text-sm font-medium text-n-slate-12"
                >
                  {{ t('AI_BRAIN.ACTIONS') }}
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-n-weak text-n-slate-11">
              <tr v-for="faq in faqs" :key="faq.id">
                <td class="py-3 ltr:pr-4 rtl:pl-4 text-sm text-n-slate-12">
                  {{ faq.category }}
                </td>
                <td
                  class="py-3 ltr:pr-4 rtl:pl-4 text-sm text-n-slate-12 font-medium"
                >
                  {{ faq.title }}
                </td>
                <td class="py-3 ltr:pr-4 rtl:pl-4 text-sm text-n-slate-11">
                  {{ faq.tags?.join(', ') }}
                </td>
                <td class="py-3 ltr:pr-4 rtl:pl-4 text-sm">
                  <span
                    :class="faq.isActive ? 'text-n-teal-11' : 'text-n-slate-10'"
                  >
                    {{
                      t(faq.isActive ? 'AI_BRAIN.ACTIVE' : 'AI_BRAIN.INACTIVE')
                    }}
                  </span>
                </td>
                <td class="py-3 ltr:pr-4 rtl:pl-4 text-end">
                  <div class="flex justify-end gap-2">
                    <Button
                      type="button"
                      variant="ghost"
                      color="slate"
                      size="sm"
                      icon="i-woot-edit-pen"
                      @click="editFaq(faq)"
                    />
                    <Button
                      type="button"
                      variant="ghost"
                      color="ruby"
                      size="sm"
                      icon="i-woot-bin"
                      @click="removeFaq(faq)"
                    />
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <div
          v-if="editing"
          class="rounded-xl border border-n-weak bg-n-solid-1 p-6 shadow-xl mt-4"
        >
          <form class="flex flex-col gap-4" @submit.prevent="saveFaq">
            <h3 class="text-base font-medium text-n-slate-12">
              {{ editing.id ? t('AI_BRAIN.EDIT') : t('AI_BRAIN.CREATE') }}
            </h3>
            <WithLabel name="faq-category" :label="t('AI_BRAIN.CATEGORY')">
              <NextInput v-model="editing.category" class="w-full" />
            </WithLabel>
            <WithLabel name="faq-title" :label="t('AI_BRAIN.TITLE')">
              <NextInput v-model="editing.title" class="w-full" required />
            </WithLabel>
            <WithLabel name="faq-content" :label="t('AI_BRAIN.CONTENT')">
              <TextArea
                v-model="editing.content"
                rows="4"
                class="w-full"
                required
              />
            </WithLabel>
            <WithLabel name="faq-tags" :label="t('AI_BRAIN.TAGS')">
              <NextInput
                :model-value="editing.tags.join(', ')"
                class="w-full"
                @input="
                  editing.tags = $event.target.value
                    .split(',')
                    .map(tag => tag.trim())
                    .filter(Boolean)
                "
              />
            </WithLabel>
            <div
              class="flex items-center justify-between p-3 rounded-lg border border-n-weak bg-n-solid-2"
            >
              <span class="text-sm font-medium text-n-slate-12">{{
                t('AI_BRAIN.ACTIVE')
              }}</span>
              <Switch v-model="editing.isActive" />
            </div>
            <div class="flex justify-end gap-3 pt-2">
              <Button
                type="button"
                variant="faded"
                color="slate"
                :label="t('AI_BRAIN.CANCEL')"
                @click="editing = null"
              />
              <Button
                type="submit"
                color="blue"
                :is-loading="busy"
                :label="t('AI_BRAIN.SAVE')"
              />
            </div>
          </form>
        </div>
      </section>
    </template>
  </SettingsLayout>
</template>
