<script setup>
import { useI18n } from 'vue-i18n';
import SectionLayout from '../../settings/account/components/SectionLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';

defineProps({
  title: { type: String, required: true },
  description: { type: String, default: '' },
  status: { type: Object, required: true },
  busy: { type: Boolean, default: false },
});

const emit = defineEmits(['connect', 'disconnect']);
const { t } = useI18n();
</script>

<template>
  <SectionLayout :title="title" :description="description" with-border>
    <div
      class="p-5 rounded-xl border border-n-weak bg-n-solid-1 flex flex-col gap-3"
    >
      <div class="flex items-center justify-between">
        <span
          class="text-sm font-medium"
          :class="status.isConnected ? 'text-n-teal-11' : 'text-n-slate-11'"
        >
          {{
            status.isConnected
              ? t('AI_BRAIN.CONNECTED')
              : t('AI_BRAIN.DISCONNECTED')
          }}
        </span>
      </div>
      <div
        v-if="status.accountEmail"
        class="flex flex-wrap items-center gap-1.5 text-sm text-n-slate-12"
      >
        <span>{{
          $slots.account ? `${status.accountEmail} ·` : status.accountEmail
        }}</span>
        <slot name="account" />
      </div>
      <p v-if="status.validationError" class="text-sm text-n-ruby-9">
        {{ status.validationError }}
      </p>
      <slot />
      <div class="flex gap-3 pt-2">
        <Button
          type="button"
          color="blue"
          :is-loading="busy"
          :label="
            status.isConnected ? t('AI_BRAIN.RECONNECT') : t('AI_BRAIN.CONNECT')
          "
          @click="emit('connect')"
        />
        <Button
          v-if="status.isConnected"
          type="button"
          variant="faded"
          color="ruby"
          :disabled="busy"
          :label="t('AI_BRAIN.DISCONNECT')"
          @click="emit('disconnect')"
        />
      </div>
    </div>
  </SectionLayout>
</template>
