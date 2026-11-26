<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';

// The approved WhatsApp template a message the system starts goes as outside the 24-hour window, with its body values
// written with the message's placeholders. Templates come from useWhatsAppTemplates.
const props = defineProps({
  name: { type: String, required: true },
  label: { type: String, required: true },
  templates: { type: Array, default: () => [] },
  placeholders: { type: Array, required: true },
});
const template = defineModel({ type: Object, default: null });

const { t } = useI18n();

const templateOptions = computed(() => {
  const options = props.templates.map(item => ({
    value: `${item.name}|${item.language}`,
    label: `${item.name} (${item.language})`,
  }));
  const chosen = template.value;
  const kept =
    chosen?.name &&
    !options.some(
      option => option.value === `${chosen.name}|${chosen.language}`
    );
  return [
    { value: '', label: t('AI_BRAIN.TEMPLATE_PICKER.NONE') },
    ...(kept
      ? [
          {
            value: `${chosen.name}|${chosen.language}`,
            label: `${chosen.name} (${chosen.language})`,
          },
        ]
      : []),
    ...options,
  ];
});
const selected = computed(() =>
  props.templates.find(
    item =>
      item.name === template.value?.name &&
      item.language === template.value?.language
  )
);
const placeholderHint = computed(() =>
  props.placeholders.map(placeholder => `{{${placeholder}}}`).join(', ')
);

// An empty name tells the backend to remove the template.
const selectTemplate = value => {
  if (!value) {
    template.value = { name: '', language: '', bodyParameters: [] };
    return;
  }
  const [name, language] = value.split('|');
  const item = props.templates.find(
    candidate => candidate.name === name && candidate.language === language
  );
  if (!item) return;
  template.value = {
    name: item.name,
    language: item.language,
    category: item.category,
    bodyParameters: Array.from(
      { length: item.parameterCount },
      (_, index) => template.value?.bodyParameters?.[index] || ''
    ),
  };
};
</script>

<template>
  <div class="grid gap-3">
    <WithLabel :name="name" :label="label">
      <Select
        :model-value="
          template?.name ? `${template.name}|${template.language}` : ''
        "
        :options="templateOptions"
        :aria-label="label"
        @update:model-value="selectTemplate"
      />
    </WithLabel>
    <p
      v-if="selected?.bodyText"
      class="p-3 text-sm whitespace-pre-wrap rounded-lg bg-n-alpha-2 text-n-slate-12"
    >
      {{ selected.bodyText }}
    </p>
    <WithLabel
      v-for="(_, index) in template?.bodyParameters || []"
      :key="index"
      :name="`${name}-parameter-${index}`"
      :label="t('AI_BRAIN.TEMPLATE_PICKER.PARAMETER', { n: index + 1 })"
    >
      <NextInput
        v-model="template.bodyParameters[index]"
        class="w-full"
        :placeholder="placeholderHint"
      />
    </WithLabel>
  </div>
</template>
