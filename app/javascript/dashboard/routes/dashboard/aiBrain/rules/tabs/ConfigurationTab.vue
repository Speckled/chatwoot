<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import SectionLayout from '../../../settings/account/components/SectionLayout.vue';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import StringListEditor from 'dashboard/components-next/aiBrain/StringListEditor.vue';
import aiModelsAPI from 'dashboard/api/aiBrain/aiModels';
import PaymentTemplatePicker from './PaymentTemplatePicker.vue';

// The backend's ChargeTiming values.
const CHARGE_ON_REQUEST = 0;
const CHARGE_AFTER_BOOKING = 1;
const MODELS_LOADING = 'loading';
const MODELS_READY = 'ready';
const MODELS_UNAVAILABLE = 'unavailable';

// The business rules object the Rules page loads and saves.
const rules = defineModel({ type: Object, required: true });
const { t } = useI18n();
const chargeTimingOptions = computed(() => [
  {
    value: CHARGE_ON_REQUEST,
    label: t('AI_BRAIN.CHARGE_TIMING.ON_REQUEST'),
  },
  {
    value: CHARGE_AFTER_BOOKING,
    label: t('AI_BRAIN.CHARGE_TIMING.AFTER_BOOKING'),
  },
]);
const providers = ref([]);
const models = ref([]);
const modelsState = ref(MODELS_LOADING);

// The stored provider stays selectable even when the list could not be loaded.
const providerOptions = computed(() => {
  const options = providers.value.map(provider => ({
    value: provider.id,
    label: provider.name,
  }));
  const current = rules.value.aiProvider;
  return current && !options.some(option => option.value === current)
    ? [{ value: current, label: current }, ...options]
    : options;
});
// The backend always lists the app's own model, even when the provider does not.
const modelOptions = computed(() =>
  models.value.map(model => ({
    value: model.id,
    label: model.name === model.id ? model.id : `${model.name} (${model.id})`,
  }))
);

const loadProviders = async () => {
  try {
    providers.value = (await aiModelsAPI.getProviders()).data;
  } catch (error) {
    providers.value = [];
  }
};
const loadModels = async provider => {
  modelsState.value = MODELS_LOADING;
  try {
    models.value = (await aiModelsAPI.getModels(provider)).data.models || [];
    modelsState.value = models.value.length ? MODELS_READY : MODELS_UNAVAILABLE;
  } catch (error) {
    models.value = [];
    modelsState.value = MODELS_UNAVAILABLE;
  }
};
// The combobox clears its value when the selected option is picked again; the model always keeps one.
const selectModel = modelId => {
  if (modelId) rules.value.modelId = modelId;
};

onMounted(() => {
  loadProviders();
  loadModels(rules.value.aiProvider);
});
watch(
  () => rules.value.aiProvider,
  (provider, previous) => {
    if (provider && provider !== previous) loadModels(provider);
  }
);
</script>

<template>
  <div class="flex flex-col gap-6 w-full">
    <SectionLayout :title="t('AI_BRAIN.TABS.CLINIC')" class="!pt-0">
      <div class="grid gap-4">
        <WithLabel name="business-name" :label="t('AI_BRAIN.BUSINESS_NAME')">
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
        <WithLabel
          name="charge-timing"
          :label="t('AI_BRAIN.CHARGE_TIMING.LABEL')"
        >
          <Select
            v-model="rules.chargeTiming"
            :options="chargeTimingOptions"
            :aria-label="t('AI_BRAIN.CHARGE_TIMING.LABEL')"
          />
          <p class="text-xs text-n-slate-11">
            {{ t('AI_BRAIN.CHARGE_TIMING.HINT') }}
          </p>
        </WithLabel>
      </div>
    </SectionLayout>

    <SectionLayout :title="t('AI_BRAIN.PAYMENT_TEMPLATE.TITLE')" with-border>
      <PaymentTemplatePicker v-model="rules.paymentConfirmationTemplate" />
    </SectionLayout>

    <SectionLayout :title="t('AI_BRAIN.MODEL_CONFIG')" with-border>
      <div class="grid gap-4">
        <div class="grid gap-4 md:grid-cols-[minmax(0,1fr)_minmax(0,2fr)]">
          <WithLabel name="ai-provider" :label="t('AI_BRAIN.PROVIDER')">
            <Select
              v-model="rules.aiProvider"
              :options="providerOptions"
              :aria-label="t('AI_BRAIN.PROVIDER')"
            />
          </WithLabel>
          <WithLabel name="model-id" :label="t('AI_BRAIN.MODEL')">
            <ComboBox
              v-if="modelsState !== MODELS_UNAVAILABLE"
              :model-value="rules.modelId"
              :options="modelOptions"
              :display-label="rules.modelId"
              :disabled="modelsState === MODELS_LOADING"
              :placeholder="
                modelsState === MODELS_LOADING
                  ? t('AI_BRAIN.MODELS.LOADING')
                  : ''
              "
              :search-placeholder="t('AI_BRAIN.MODELS.SEARCH')"
              :empty-state="t('AI_BRAIN.MODELS.EMPTY')"
              @update:model-value="selectModel"
            />
            <div v-else class="flex flex-col gap-1">
              <NextInput v-model="rules.modelId" class="w-full" required />
              <p class="text-xs text-n-slate-11">
                {{ t('AI_BRAIN.MODELS.UNAVAILABLE') }}
              </p>
            </div>
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
            name="handoff-minutes"
            :label="t('AI_BRAIN.HUMAN_TIMEOUT_MINUTES')"
          >
            <NextInput
              v-model.number="rules.otherSessionInactivityMinutes"
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
  </div>
</template>
