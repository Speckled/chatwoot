<script setup>
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { frontendURL } from 'dashboard/helper/URLHelper';
import remindersAPI from 'dashboard/api/aiBrain/reminders';
import { DELIVERY_STATUS } from './reminderForm';

// What a reminder sent lately, and what went wrong when something did not go out.
const props = defineProps({
  reminderId: { type: String, required: true },
});
const { t } = useI18n();
const route = useRoute();
const deliveries = ref([]);
const loaded = ref(false);

const STATUS_CLASSES = {
  [DELIVERY_STATUS.SENT]: 'text-n-teal-11',
  [DELIVERY_STATUS.FAILED]: 'text-n-ruby-11',
  [DELIVERY_STATUS.SKIPPED]: 'text-n-amber-11',
};

const when = delivery =>
  new Date(delivery.dispatchedAt || delivery.scheduledFor).toLocaleString();
const conversationLink = delivery =>
  frontendURL(
    `accounts/${route.params.accountId}/conversations/${delivery.chatwootConversationDisplayId}`
  );

onMounted(async () => {
  try {
    deliveries.value = (await remindersAPI.deliveries(props.reminderId)).data;
  } catch (error) {
    useAlert(t('AI_BRAIN.ERROR'));
  }
  loaded.value = true;
});
</script>

<template>
  <div class="w-full">
    <table
      v-if="deliveries.length"
      class="min-w-full table-auto divide-y divide-n-weak"
    >
      <thead>
        <tr>
          <th
            v-for="column in ['WHEN', 'SENT_TO', 'STATUS_LABEL', 'DETAILS']"
            :key="column"
            class="py-2 ltr:pr-4 rtl:pl-4 text-start text-xs font-semibold text-n-slate-12"
          >
            {{ t(`AI_BRAIN.REMINDERS.${column}`) }}
          </th>
        </tr>
      </thead>
      <tbody class="divide-y divide-n-weak text-n-slate-11">
        <tr v-for="delivery in deliveries" :key="delivery.id">
          <td class="py-2 ltr:pr-4 rtl:pl-4 text-sm whitespace-nowrap">
            {{ when(delivery) }}
          </td>
          <td class="py-2 ltr:pr-4 rtl:pl-4 text-sm text-n-slate-12">
            <div>{{ delivery.recipientName || '-' }}</div>
            <div class="text-xs text-n-slate-11">
              {{ delivery.recipientPhone }}
            </div>
          </td>
          <td
            class="py-2 ltr:pr-4 rtl:pl-4 text-sm"
            :class="STATUS_CLASSES[delivery.status] || 'text-n-slate-11'"
          >
            {{ t(`AI_BRAIN.REMINDERS.STATUS.${delivery.status}`) }}
          </td>
          <td class="py-2 ltr:pr-4 rtl:pl-4 text-sm">
            <p v-if="delivery.errorReason" class="text-n-ruby-11">
              {{ delivery.errorReason }}
            </p>
            <p class="line-clamp-2">{{ delivery.renderedText }}</p>
            <router-link
              v-if="delivery.chatwootConversationDisplayId"
              :to="conversationLink(delivery)"
              class="text-xs text-n-brand hover:underline"
            >
              {{ t('AI_BRAIN.REMINDERS.OPEN_CONVERSATION') }}
            </router-link>
          </td>
        </tr>
      </tbody>
    </table>
    <p v-else-if="loaded" class="text-sm text-n-slate-11 py-2">
      {{ t('AI_BRAIN.REMINDERS.NO_DELIVERIES') }}
    </p>
  </div>
</template>
