<script setup>
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import faqsAPI from 'dashboard/api/aiBrain/faqs';

const { t } = useI18n();
const faqs = ref([]);
const editing = ref(null);
const busy = ref(false);

const load = async () => {
  try {
    faqs.value = (await faqsAPI.get()).data;
  } catch (error) {
    useAlert(t('AI_BRAIN.ERROR'));
  }
};
onMounted(load);

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
    await load();
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
  <section class="flex flex-col gap-4 w-full">
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
                {{ t(faq.isActive ? 'AI_BRAIN.ACTIVE' : 'AI_BRAIN.INACTIVE') }}
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
