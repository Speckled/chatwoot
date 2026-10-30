<script setup>
import { shallowRef, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import WithLabel from 'v3/components/Form/WithLabel.vue';

const props = defineProps({
  inboxes: {
    type: Array,
    required: true,
  },
  selectedInboxId: {
    type: [Number, String],
    default: null,
  },
  currentInbox: {
    type: Object,
    default: null,
  },
  creatingInbox: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits([
  'selectInbox',
  'createTestInbox',
  'toggleInboxRouting',
]);

const { t } = useI18n();
const showCreateForm = shallowRef(false);
const newInboxName = shallowRef('');
const newInboxPhone = shallowRef('');

const testInboxes = computed(() =>
  props.inboxes.filter(
    inbox =>
      inbox.channelType === 'Channel::Whatsapp' && inbox.provider === 'test'
  )
);

const onInboxChange = event => {
  const value = event.target.value ? Number(event.target.value) : null;
  emit('selectInbox', value);
};

const openCreateForm = () => {
  newInboxName.value = 'WhatsApp Test';
  newInboxPhone.value = '+5511999990000';
  showCreateForm.value = true;
};

const cancelCreate = () => {
  showCreateForm.value = false;
};

const submitCreate = async () => {
  if (!newInboxPhone.value.trim()) return;
  try {
    await emit('createTestInbox', {
      name: newInboxName.value.trim(),
      phoneNumber: newInboxPhone.value.trim(),
    });
    showCreateForm.value = false;
  } catch (err) {
    // handled by composable alert
  }
};
</script>

<template>
  <div
    class="flex flex-col gap-4 w-full p-4 rounded-xl border border-n-weak bg-n-solid-1"
  >
    <div
      class="flex flex-col gap-3 md:flex-row md:items-center md:justify-between"
    >
      <div class="flex flex-col gap-1 min-w-0">
        <h2 class="text-base font-semibold text-n-slate-12">
          {{ t('AI_BRAIN.TEST') }}
        </h2>
        <p class="text-xs text-n-slate-11">
          {{ t('AI_BRAIN.TEST_LAB_SUBTITLE') }}
        </p>
      </div>

      <div class="flex flex-wrap items-center gap-3">
        <div class="flex items-center gap-2">
          <label
            for="ai-brain-inbox-select"
            class="text-xs font-medium text-n-slate-11 whitespace-nowrap"
          >
            {{ t('AI_BRAIN.INBOX') }}:
          </label>
          <select
            id="ai-brain-inbox-select"
            :value="selectedInboxId || ''"
            class="text-sm rounded-lg border border-n-weak bg-n-solid-2 text-n-slate-12 px-3 py-1.5 focus:border-n-brand focus:outline-none"
            @change="onInboxChange"
          >
            <option v-if="!testInboxes.length" value="" disabled>
              {{ t('AI_BRAIN.NO_TEST_INBOX') }}
            </option>
            <option
              v-for="inbox in testInboxes"
              :key="inbox.id"
              :value="inbox.id"
            >
              {{ inbox.name }} ({{ inbox.phoneNumber || `#${inbox.id}` }})
            </option>
          </select>
        </div>

        <div
          v-if="currentInbox"
          class="flex items-center gap-2 px-3 py-1.5 rounded-lg border border-n-weak bg-n-solid-2"
        >
          <span class="text-xs font-medium text-n-slate-12 whitespace-nowrap">
            {{ t('AI_BRAIN.ACTIVE') }}
          </span>
          <Switch
            :model-value="Boolean(currentInbox.aiBrainInbox?.active)"
            @change="val => emit('toggleInboxRouting', currentInbox, val)"
          />
        </div>

        <Button
          type="button"
          color="blue"
          size="sm"
          icon="i-woot-plus"
          :label="t('AI_BRAIN.CREATE_TEST_INBOX')"
          @click="openCreateForm"
        />
      </div>
    </div>

    <!-- Inline creation form -->
    <div
      v-if="showCreateForm"
      class="mt-2 p-4 rounded-lg border border-n-weak bg-n-solid-2"
    >
      <form class="flex flex-col gap-3" @submit.prevent="submitCreate">
        <h3 class="text-sm font-semibold text-n-slate-12">
          {{ t('AI_BRAIN.CREATE_TEST_INBOX') }}
        </h3>
        <div class="grid gap-3 md:grid-cols-2">
          <WithLabel
            name="test-inbox-name"
            :label="t('AI_BRAIN.TEST_INBOX_NAME')"
          >
            <NextInput
              v-model="newInboxName"
              class="w-full"
              placeholder="WhatsApp Test"
              required
            />
          </WithLabel>
          <WithLabel
            name="test-inbox-phone"
            :label="t('AI_BRAIN.TEST_INBOX_PHONE')"
          >
            <NextInput
              v-model="newInboxPhone"
              class="w-full"
              placeholder="+5511999990000"
              required
            />
          </WithLabel>
        </div>
        <div class="flex justify-end gap-2 pt-1">
          <Button
            type="button"
            variant="faded"
            color="slate"
            size="sm"
            :label="t('AI_BRAIN.CANCEL')"
            @click="cancelCreate"
          />
          <Button
            type="submit"
            color="blue"
            size="sm"
            :is-loading="creatingInbox"
            :label="t('AI_BRAIN.CREATE')"
          />
        </div>
      </form>
    </div>
  </div>
</template>
