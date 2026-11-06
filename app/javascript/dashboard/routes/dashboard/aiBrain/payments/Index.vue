<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import SettingsLayout from '../../settings/SettingsLayout.vue';
import BaseSettingsHeader from '../../settings/components/BaseSettingsHeader.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import paymentsAPI from 'dashboard/api/aiBrain/payments';
import { frontendURL, conversationUrl } from 'dashboard/helper/URLHelper';

// Mercado Pago charges the AI Brain made for patients. A paid appointment the patient cancelled waits here, marked, for
// an administrator to refund; nothing is returned on its own.
const STATUSES = ['pending', 'approved', 'refunded', 'expired', 'cancelled'];
const COLUMNS = ['WHEN', 'PATIENT', 'WHAT', 'AMOUNT', 'STATUS'];

const { t } = useI18n();
const route = useRoute();
const payments = ref([]);
const loading = ref(true);
const status = ref('');
const refunding = ref(null);

const statusOptions = computed(() => [
  { value: '', label: t('AI_BRAIN.PAYMENTS.FILTER_ALL') },
  ...STATUSES.map(value => ({
    value,
    label: t(`AI_BRAIN.PAYMENTS.STATUSES.${value}`),
  })),
]);
const money = amount =>
  new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(
    amount
  );
const statusOf = payment =>
  payment.status === 'approved' && payment.refundRequested
    ? 'refund_requested'
    : payment.status;
const canRefund = payment => payment.status === 'approved';
const conversationLink = payment =>
  payment.conversationDisplayId
    ? frontendURL(
        conversationUrl({
          accountId: route.params.accountId,
          id: payment.conversationDisplayId,
        })
      )
    : null;

const load = async () => {
  loading.value = true;
  try {
    payments.value = (
      await paymentsAPI.list(status.value ? { status: status.value } : {})
    ).data;
  } catch (error) {
    useAlert(t('AI_BRAIN.ERROR'));
  } finally {
    loading.value = false;
  }
};
const refund = async payment => {
  const message = t('AI_BRAIN.PAYMENTS.CONFIRM_REFUND', {
    amount: money(payment.amount),
    patient: payment.clientName || payment.clientPhone || '',
  });
  if (!window.confirm(message)) return;
  refunding.value = payment.id;
  try {
    await paymentsAPI.refund(payment.id);
    useAlert(t('AI_BRAIN.PAYMENTS.REFUNDED'));
    await load();
  } catch (error) {
    useAlert(error?.response?.data?.error || t('AI_BRAIN.ERROR'));
  } finally {
    refunding.value = null;
  }
};

onMounted(load);
watch(status, load);
</script>

<template>
  <SettingsLayout :is-loading="loading && !payments.length">
    <template #header>
      <BaseSettingsHeader
        :title="t('AI_BRAIN.PAYMENTS.TITLE')"
        :description="t('AI_BRAIN.PAYMENTS.DESCRIPTION')"
      >
        <template #actions>
          <div class="w-48">
            <Select
              v-model="status"
              :options="statusOptions"
              :aria-label="t('AI_BRAIN.PAYMENTS.STATUS')"
            />
          </div>
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <div class="w-full">
        <table
          v-if="payments.length"
          class="min-w-full table-auto divide-y divide-n-weak"
        >
          <thead>
            <tr class="border-t border-n-weak">
              <th
                v-for="column in COLUMNS"
                :key="column"
                class="py-3 ltr:pr-4 rtl:pl-4 text-start text-sm font-medium text-n-slate-12"
              >
                {{ t(`AI_BRAIN.PAYMENTS.${column}`) }}
              </th>
              <th
                class="py-3 ltr:pr-4 rtl:pl-4 text-end text-sm font-medium text-n-slate-12"
              >
                {{ t('AI_BRAIN.ACTIONS') }}
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-n-weak text-n-slate-11">
            <tr v-for="payment in payments" :key="payment.id">
              <td class="py-3 ltr:pr-4 rtl:pl-4 text-sm whitespace-nowrap">
                {{ new Date(payment.createdAt).toLocaleString() }}
              </td>
              <td class="py-3 ltr:pr-4 rtl:pl-4 text-sm text-n-slate-12">
                <div>{{ payment.clientName }}</div>
                <div class="text-xs text-n-slate-11">
                  {{ payment.clientPhone }}
                </div>
              </td>
              <td class="py-3 ltr:pr-4 rtl:pl-4 text-sm">
                <div>{{ payment.description }}</div>
                <div class="text-xs">
                  {{ t(`AI_BRAIN.PAYMENTS.KINDS.${payment.kind}`) }}
                  <template v-if="payment.professionalName">
                    {{ `· ${payment.professionalName}` }}
                  </template>
                </div>
              </td>
              <td class="py-3 ltr:pr-4 rtl:pl-4 text-sm whitespace-nowrap">
                {{ money(payment.amount) }}
              </td>
              <td
                class="py-3 ltr:pr-4 rtl:pl-4 text-sm"
                :class="{
                  'text-n-amber-11 font-medium':
                    statusOf(payment) === 'refund_requested',
                }"
              >
                {{ t(`AI_BRAIN.PAYMENTS.STATUSES.${statusOf(payment)}`) }}
              </td>
              <td class="py-3 ltr:pr-4 rtl:pl-4 text-end">
                <div class="flex justify-end gap-2">
                  <a
                    v-if="conversationLink(payment)"
                    :href="conversationLink(payment)"
                    class="text-sm text-n-blue-11 hover:underline self-center"
                  >
                    {{ t('AI_BRAIN.PAYMENTS.OPEN_CONVERSATION') }}
                  </a>
                  <Button
                    v-if="canRefund(payment)"
                    type="button"
                    size="xs"
                    :color="payment.refundRequested ? 'amber' : 'slate'"
                    :label="t('AI_BRAIN.PAYMENTS.REFUND')"
                    :is-loading="refunding === payment.id"
                    @click="refund(payment)"
                  />
                </div>
              </td>
            </tr>
          </tbody>
        </table>
        <p v-else-if="!loading" class="text-sm text-n-slate-11">
          {{ t('AI_BRAIN.PAYMENTS.EMPTY') }}
        </p>
      </div>
    </template>
  </SettingsLayout>
</template>
