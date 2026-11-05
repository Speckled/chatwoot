<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import NextInput from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import StringListEditor from 'dashboard/components-next/aiBrain/StringListEditor.vue';
import { SERVICE_CHOICE, newServiceRow } from './serviceTermsOverride';

// Edits a form made by serviceTermsOverride.js: the clinic's terms ("clinic"), or what one professional changes from
// them ("override"). `errors` are the backend's validation problems, by field. `mercadoPagoConnected` says whether a
// Mercado Pago account would receive this clinic's or professional's charges; without one, Mercado Pago can only be
// turned off.
const props = defineProps({
  mode: {
    type: String,
    default: 'clinic',
    validator: value => ['clinic', 'override'].includes(value),
  },
  errors: { type: Object, default: () => ({}) },
  mercadoPagoConnected: { type: Boolean, default: false },
});
const form = defineModel({ type: Object, required: true });
const { t } = useI18n();

const MONEY = new Intl.NumberFormat('pt-BR', {
  style: 'currency',
  currency: 'BRL',
});
const isClinic = computed(() => props.mode === 'clinic');
// The clinic's services in clinic mode; the services only this professional offers in override mode.
const offeredRows = computed(() =>
  isClinic.value ? form.value.services : form.value.ownServices
);
const pix = computed(() =>
  isClinic.value ? form.value.pix : form.value.payment.pix
);
// Holds the mercadoPago flag: the clinic form itself, or a professional's payment section.
const payment = computed(() =>
  isClinic.value ? form.value : form.value.payment
);
const showPayment = computed(
  () => isClinic.value || !form.value.payment.inherit
);
const choices = computed(() => [
  {
    value: SERVICE_CHOICE.INHERIT,
    label: t('AI_BRAIN.SERVICE_TERMS.INHERIT'),
  },
  { value: SERVICE_CHOICE.OWN, label: t('AI_BRAIN.SERVICE_TERMS.OWN_PRICE') },
  {
    value: SERVICE_CHOICE.NOT_OFFERED,
    label: t('AI_BRAIN.SERVICE_TERMS.NOT_OFFERED'),
  },
]);

const clinicPrice = row => {
  if (row.clinicPriceOnRequest) return t('AI_BRAIN.SERVICE_TERMS.ON_REQUEST');
  return row.clinicPrice === null ? '-' : MONEY.format(row.clinicPrice);
};
const addService = () => offeredRows.value.push(newServiceRow());
const removeService = index => offeredRows.value.splice(index, 1);
</script>

<template>
  <div class="flex flex-col gap-6">
    <section class="flex flex-col gap-3">
      <h4 class="text-sm font-medium text-n-slate-12">
        {{ t('AI_BRAIN.SERVICE_TERMS.SERVICES') }}
      </h4>
      <template v-if="!isClinic">
        <div
          v-for="row in form.services"
          :key="row.id"
          class="grid items-center gap-2 md:grid-cols-[1fr_11rem_9rem_auto]"
        >
          <div class="flex flex-col min-w-0">
            <span class="text-sm font-medium text-n-slate-12 truncate">
              {{ row.name }}
            </span>
            <span class="text-xs text-n-slate-11">
              {{
                t('AI_BRAIN.SERVICE_TERMS.CLINIC_PRICE', {
                  price: clinicPrice(row),
                })
              }}
            </span>
          </div>
          <Select
            v-model="row.choice"
            :options="choices"
            :aria-label="row.name"
          />
          <template v-if="row.choice === SERVICE_CHOICE.OWN">
            <NextInput
              v-model.number="row.price"
              type="number"
              min="0"
              step="0.01"
              :disabled="row.priceOnRequest"
              :placeholder="t('AI_BRAIN.SERVICE_TERMS.PRICE')"
              class="w-full"
            />
            <label
              class="flex items-center gap-2 text-sm text-n-slate-12 cursor-pointer"
            >
              <Checkbox v-model="row.priceOnRequest" />
              <span>{{ t('AI_BRAIN.SERVICE_TERMS.PRICE_ON_REQUEST') }}</span>
            </label>
          </template>
        </div>
        <h4 class="text-sm font-medium text-n-slate-12 pt-2">
          {{ t('AI_BRAIN.SERVICE_TERMS.OWN_SERVICES') }}
        </h4>
      </template>
      <div
        v-for="(row, index) in offeredRows"
        :key="row.id"
        class="grid items-center gap-2 md:grid-cols-[1fr_9rem_auto_auto]"
      >
        <NextInput
          v-model="row.name"
          :placeholder="t('AI_BRAIN.SERVICE_TERMS.SERVICE_NAME')"
          class="w-full"
        />
        <NextInput
          v-model.number="row.price"
          type="number"
          min="0"
          step="0.01"
          :disabled="row.priceOnRequest"
          :placeholder="t('AI_BRAIN.SERVICE_TERMS.PRICE')"
          class="w-full"
        />
        <label
          class="flex items-center gap-2 text-sm text-n-slate-12 cursor-pointer"
        >
          <Checkbox v-model="row.priceOnRequest" />
          <span>{{ t('AI_BRAIN.SERVICE_TERMS.PRICE_ON_REQUEST') }}</span>
        </label>
        <Button
          type="button"
          variant="ghost"
          color="ruby"
          size="sm"
          icon="i-woot-bin"
          :aria-label="t('AI_BRAIN.REMOVE')"
          @click="removeService(index)"
        />
      </div>
      <div>
        <Button
          type="button"
          variant="faded"
          color="slate"
          size="sm"
          icon="i-woot-plus"
          :label="t('AI_BRAIN.SERVICE_TERMS.ADD_SERVICE')"
          @click="addService"
        />
      </div>
      <p v-if="errors.services" class="text-sm text-n-ruby-11">
        {{ errors.services.join(' ') }}
      </p>
    </section>

    <section class="flex flex-col gap-3">
      <div
        v-if="!isClinic"
        class="flex items-center justify-between p-3 rounded-lg border border-n-weak bg-n-solid-2"
      >
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('AI_BRAIN.SERVICE_TERMS.INHERIT_PLANS') }}
        </span>
        <Switch v-model="form.plans.inherit" />
      </div>
      <template v-if="isClinic || !form.plans.inherit">
        <StringListEditor
          v-if="isClinic"
          v-model="form.plans"
          :label="t('AI_BRAIN.SERVICE_TERMS.PLANS')"
        />
        <StringListEditor
          v-else
          v-model="form.plans.list"
          :label="t('AI_BRAIN.SERVICE_TERMS.PLANS')"
        />
        <p class="text-xs text-n-slate-11">
          {{ t('AI_BRAIN.SERVICE_TERMS.PLANS_HINT') }}
        </p>
      </template>
      <p v-if="errors.acceptedPlans" class="text-sm text-n-ruby-11">
        {{ errors.acceptedPlans.join(' ') }}
      </p>
    </section>

    <section class="flex flex-col gap-3">
      <h4 class="text-sm font-medium text-n-slate-12">
        {{ t('AI_BRAIN.SERVICE_TERMS.PAYMENT') }}
      </h4>
      <div
        v-if="!isClinic"
        class="flex items-center justify-between p-3 rounded-lg border border-n-weak bg-n-solid-2"
      >
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('AI_BRAIN.SERVICE_TERMS.INHERIT_PAYMENT') }}
        </span>
        <Switch v-model="form.payment.inherit" />
      </div>
      <template v-if="showPayment">
        <div
          class="flex items-center justify-between p-3 rounded-lg border border-n-weak bg-n-solid-2"
        >
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('AI_BRAIN.SERVICE_TERMS.PIX') }}
          </span>
          <Switch v-model="pix.enabled" />
        </div>
        <div v-if="pix.enabled" class="grid gap-4 md:grid-cols-2">
          <WithLabel
            name="pix-key"
            :label="t('AI_BRAIN.SERVICE_TERMS.PIX_KEY')"
          >
            <NextInput v-model="pix.key" class="w-full" />
          </WithLabel>
          <WithLabel
            name="pix-recipient"
            :label="t('AI_BRAIN.SERVICE_TERMS.PIX_RECIPIENT')"
          >
            <NextInput v-model="pix.recipientName" class="w-full" />
          </WithLabel>
        </div>
        <p class="text-xs text-n-slate-11">
          {{ t('AI_BRAIN.SERVICE_TERMS.PIX_HINT') }}
        </p>
        <div
          class="flex items-center justify-between gap-3 p-3 rounded-lg border border-n-weak bg-n-solid-2"
        >
          <div class="flex flex-col gap-0.5">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('AI_BRAIN.SERVICE_TERMS.MERCADO_PAGO') }}
            </span>
            <span class="text-xs text-n-slate-11">
              {{
                mercadoPagoConnected
                  ? t('AI_BRAIN.SERVICE_TERMS.MERCADO_PAGO_HINT')
                  : t('AI_BRAIN.SERVICE_TERMS.MERCADO_PAGO_NOT_CONNECTED')
              }}
            </span>
          </div>
          <Switch
            v-model="payment.mercadoPago"
            :disabled="!mercadoPagoConnected && !payment.mercadoPago"
          />
        </div>
      </template>
      <p v-if="errors.paymentMethods" class="text-sm text-n-ruby-11">
        {{ errors.paymentMethods.join(' ') }}
      </p>
    </section>

    <WithLabel name="service-notes" :label="t('AI_BRAIN.SERVICE_TERMS.NOTES')">
      <TextArea
        v-model="form.notes"
        :max-length="1000"
        rows="3"
        class="w-full"
      />
      <p v-if="!isClinic" class="text-xs text-n-slate-11">
        {{ t('AI_BRAIN.SERVICE_TERMS.PROFESSIONAL_NOTES_HINT') }}
      </p>
      <p v-if="errors.notes" class="text-sm text-n-ruby-11">
        {{ errors.notes.join(' ') }}
      </p>
    </WithLabel>
  </div>
</template>
