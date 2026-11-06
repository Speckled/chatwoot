<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import inboxesAPI from 'dashboard/api/aiBrain/inboxes';

// The approved WhatsApp template that confirms a payment to a patient who last wrote more than 24 hours ago. Templates
// belong to a WhatsApp number, so they are listed from one of the AI Brain's WhatsApp inboxes.
const template = defineModel({ type: Object, default: null });
const WHATSAPP = 'Channel::Whatsapp';
const PLACEHOLDERS = [
  'business_name',
  'client_name',
  'client_first_name',
  'amount',
  'description',
];

const { t } = useI18n();
const inboxes = ref([]);
const inboxId = ref(null);
const templates = ref([]);

const inboxOptions = computed(() =>
  inboxes.value.map(inbox => ({
    value: inbox.id,
    label: inbox.phoneNumber
      ? `${inbox.name} (${inbox.phoneNumber})`
      : inbox.name,
  }))
);
const templateOptions = computed(() => {
  const options = templates.value.map(item => ({
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
    { value: '', label: t('AI_BRAIN.PAYMENT_TEMPLATE.NONE') },
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
  templates.value.find(
    item =>
      item.name === template.value?.name &&
      item.language === template.value?.language
  )
);
const placeholderHint = computed(() =>
  PLACEHOLDERS.map(name => `{{${name}}}`).join(', ')
);

const loadTemplates = async id => {
  templates.value = [];
  if (!id) return;
  try {
    templates.value = (await inboxesAPI.getTemplates(id)).data;
  } catch (error) {
    templates.value = [];
  }
};

// An empty name tells the backend to remove the template.
const selectTemplate = value => {
  if (!value) {
    template.value = { name: '', language: '', bodyParameters: [] };
    return;
  }
  const [name, language] = value.split('|');
  const item = templates.value.find(
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

onMounted(async () => {
  try {
    inboxes.value = (await inboxesAPI.get()).data.filter(
      inbox => inbox.channelType === WHATSAPP && inbox.aiBrainInbox?.active
    );
  } catch (error) {
    inboxes.value = [];
  }
  inboxId.value = inboxes.value[0]?.id ?? null;
});
watch(inboxId, loadTemplates);
</script>

<template>
  <div class="grid gap-3">
    <p class="text-sm text-n-slate-11">
      {{ t('AI_BRAIN.PAYMENT_TEMPLATE.HINT') }}
    </p>
    <div class="grid gap-4 md:grid-cols-2">
      <WithLabel
        name="payment-template-inbox"
        :label="t('AI_BRAIN.PAYMENT_TEMPLATE.INBOX')"
      >
        <Select
          v-model="inboxId"
          :options="inboxOptions"
          :aria-label="t('AI_BRAIN.PAYMENT_TEMPLATE.INBOX')"
        />
      </WithLabel>
      <WithLabel
        name="payment-template"
        :label="t('AI_BRAIN.PAYMENT_TEMPLATE.TEMPLATE')"
      >
        <Select
          :model-value="
            template?.name ? `${template.name}|${template.language}` : ''
          "
          :options="templateOptions"
          :aria-label="t('AI_BRAIN.PAYMENT_TEMPLATE.TEMPLATE')"
          @update:model-value="selectTemplate"
        />
      </WithLabel>
    </div>
    <p
      v-if="selected?.bodyText"
      class="p-3 text-sm whitespace-pre-wrap rounded-lg bg-n-alpha-2 text-n-slate-12"
    >
      {{ selected.bodyText }}
    </p>
    <WithLabel
      v-for="(_, index) in template?.bodyParameters || []"
      :key="index"
      :name="`payment-template-parameter-${index}`"
      :label="t('AI_BRAIN.PAYMENT_TEMPLATE.PARAMETER', { n: index + 1 })"
    >
      <NextInput
        v-model="template.bodyParameters[index]"
        class="w-full"
        :placeholder="placeholderHint"
      />
    </WithLabel>
  </div>
</template>
