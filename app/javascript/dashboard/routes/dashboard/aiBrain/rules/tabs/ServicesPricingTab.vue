<script setup>
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import ServiceTermsEditor from 'dashboard/components-next/aiBrain/ServiceTermsEditor.vue';
import {
  fromClinicForm,
  toClinicForm,
} from 'dashboard/components-next/aiBrain/serviceTermsOverride';
import serviceTermsAPI from 'dashboard/api/aiBrain/serviceTerms';
import servicesAPI from 'dashboard/api/aiBrain/services';

// The clinic's services, prices, health plans and payment details: the default every professional starts from.
const { t } = useI18n();
const form = ref(null);
const errors = ref({});
const saving = ref(false);
// Whether the clinic's Mercado Pago account is connected, so Mercado Pago can be accepted.
const mercadoPagoConnected = ref(false);

const loadMercadoPago = async () => {
  try {
    const { data } = await servicesAPI.get();
    mercadoPagoConnected.value = !!data.find(
      service => service.service === 'MercadoPago'
    )?.isConnected;
  } catch (error) {
    mercadoPagoConnected.value = false;
  }
};

onMounted(async () => {
  loadMercadoPago();
  try {
    form.value = toClinicForm((await serviceTermsAPI.get()).data.clinic);
  } catch (error) {
    useAlert(t('AI_BRAIN.ERROR'));
  }
});

const save = async () => {
  saving.value = true;
  errors.value = {};
  try {
    const { data } = await serviceTermsAPI.update(fromClinicForm(form.value));
    form.value = toClinicForm(data);
    useAlert(t('AI_BRAIN.SAVED'));
  } catch (error) {
    errors.value = error?.response?.data?.errors || {};
    useAlert(t('AI_BRAIN.ERROR'));
  } finally {
    saving.value = false;
  }
};
</script>

<template>
  <div class="w-full">
    <form v-if="form" class="flex flex-col gap-6" @submit.prevent="save">
      <p class="text-sm text-n-slate-11">
        {{ t('AI_BRAIN.SERVICE_TERMS.CLINIC_HINT') }}
      </p>
      <ServiceTermsEditor
        v-model="form"
        mode="clinic"
        :errors="errors"
        :mercado-pago-connected="mercadoPagoConnected"
      />
      <div class="pt-2">
        <Button
          type="submit"
          color="blue"
          :is-loading="saving"
          :label="t('AI_BRAIN.SAVE')"
        />
      </div>
    </form>
  </div>
</template>
