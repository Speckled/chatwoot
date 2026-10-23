<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
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
    rules.value = ruleResponse.data;
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
  <main class="flex flex-col gap-6 overflow-y-auto p-6">
    <h1 class="text-2xl font-semibold">{{ t('AI_BRAIN.RULES') }}</h1>
    <TabBar
      :tabs="tabs"
      :initial-active-tab="activeTab"
      @tab-changed="tab => (activeTab = tabs.indexOf(tab))"
    />
    <form
      v-if="activeTab === 0 && rules"
      class="flex max-w-3xl flex-col gap-5"
      @submit.prevent="saveRules"
    >
      <label
        >{{ t('AI_BRAIN.BUSINESS_NAME')
        }}<input
          v-model="rules.businessName"
          class="block w-full rounded border p-2"
      /></label>
      <label
        >{{ t('AI_BRAIN.TIME_ZONE')
        }}<input
          v-model="rules.timeZone"
          class="block w-full rounded border p-2"
          required
      /></label>
      <label class="flex gap-2"
        ><input v-model="rules.enforceAllowlist" type="checkbox" />{{
          t('AI_BRAIN.ALLOWLIST')
        }}</label
      >
      <label
        >{{ t('AI_BRAIN.GLOBAL_INSTRUCTIONS')
        }}<textarea
          v-model="rules.globalInstructions"
          class="block w-full rounded border p-2"
          rows="5"
        />
      </label>
      <StringListEditor
        v-model="rules.companyRules"
        :label="t('AI_BRAIN.COMPANY_RULES')"
      />
      <StringListEditor
        v-model="rules.prohibitedBehaviors"
        :label="t('AI_BRAIN.PROHIBITED')"
      />
      <fieldset class="flex flex-col gap-3 rounded border p-4">
        <legend>{{ t('AI_BRAIN.WORKING_HOURS') }}</legend>
        <div class="flex gap-3">
          <label v-for="day in days" :key="day" class="flex gap-1">
            <input
              type="checkbox"
              :checked="rules.workingHours.activeDays.includes(day)"
              @change="toggleDay(day)"
            />{{ t(`AI_BRAIN.DAYS.${day}`) }}
          </label>
        </div>
        <label
          >{{ t('AI_BRAIN.START')
          }}<input
            v-model="rules.workingHours.startTime"
            type="time"
            class="ms-2 rounded border p-2"
        /></label>
        <label
          >{{ t('AI_BRAIN.END')
          }}<input
            v-model="rules.workingHours.endTime"
            type="time"
            class="ms-2 rounded border p-2"
        /></label>
        <label
          >{{ t('AI_BRAIN.SLOT')
          }}<input
            v-model.number="rules.workingHours.defaultSlotDurationMinutes"
            type="number"
            min="1"
            class="ms-2 rounded border p-2"
        /></label>
        <StringListEditor
          v-model="rules.workingHours.blackoutDates"
          :label="t('AI_BRAIN.BLACKOUT_DATES')"
        />
      </fieldset>
      <button
        type="submit"
        :disabled="busy"
        class="w-fit rounded bg-n-brand px-4 py-2 text-white"
      >
        {{ t('AI_BRAIN.SAVE') }}
      </button>
    </form>
    <section v-else-if="activeTab === 1" class="flex flex-col gap-4">
      <button
        type="button"
        class="w-fit rounded bg-n-brand px-4 py-2 text-white"
        @click="newFaq"
      >
        {{ t('AI_BRAIN.CREATE') }}
      </button>
      <table class="w-full">
        <thead>
          <tr>
            <th>{{ t('AI_BRAIN.CATEGORY') }}</th>
            <th>{{ t('AI_BRAIN.TITLE') }}</th>
            <th>{{ t('AI_BRAIN.TAGS') }}</th>
            <th>{{ t('AI_BRAIN.ACTIVE') }}</th>
            <th>{{ t('AI_BRAIN.ACTIONS') }}</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="faq in faqs" :key="faq.id" class="border-t">
            <td>{{ faq.category }}</td>
            <td>{{ faq.title }}</td>
            <td>{{ faq.tags?.join(', ') }}</td>
            <td>
              {{ t(faq.isActive ? 'AI_BRAIN.ACTIVE' : 'AI_BRAIN.INACTIVE') }}
            </td>
            <td class="flex gap-3">
              <button type="button" @click="editFaq(faq)">
                {{ t('AI_BRAIN.EDIT') }}</button
              ><button type="button" @click="removeFaq(faq)">
                {{ t('AI_BRAIN.REMOVE') }}
              </button>
            </td>
          </tr>
        </tbody>
      </table>
      <div
        v-if="editing"
        role="dialog"
        aria-modal="true"
        class="rounded border bg-n-solid-1 p-5 shadow-lg"
      >
        <form class="flex max-w-xl flex-col gap-3" @submit.prevent="saveFaq">
          <label
            >{{ t('AI_BRAIN.CATEGORY')
            }}<input
              v-model="editing.category"
              class="block w-full rounded border p-2"
          /></label>
          <label
            >{{ t('AI_BRAIN.TITLE')
            }}<input
              v-model="editing.title"
              required
              class="block w-full rounded border p-2"
          /></label>
          <label
            >{{ t('AI_BRAIN.CONTENT')
            }}<textarea
              v-model="editing.content"
              required
              class="block w-full rounded border p-2"
            />
          </label>
          <label
            >{{ t('AI_BRAIN.TAGS')
            }}<input
              :value="editing.tags.join(', ')"
              class="block w-full rounded border p-2"
              @input="
                editing.tags = $event.target.value
                  .split(',')
                  .map(tag => tag.trim())
                  .filter(Boolean)
              "
          /></label>
          <label class="flex gap-2"
            ><input v-model="editing.isActive" type="checkbox" />{{
              t('AI_BRAIN.ACTIVE')
            }}</label
          >
          <div class="flex gap-3">
            <button type="submit" :disabled="busy">
              {{ t('AI_BRAIN.SAVE') }}</button
            ><button type="button" @click="editing = null">
              {{ t('AI_BRAIN.CANCEL') }}
            </button>
          </div>
        </form>
      </div>
    </section>
  </main>
</template>
