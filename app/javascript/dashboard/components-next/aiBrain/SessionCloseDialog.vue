<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import TextArea from 'next/textarea/TextArea.vue';
import conversationSession from 'dashboard/api/aiBrain/conversationSession';

// Closing a conversation that has an AI Brain session asks for a reason (LRB-85). The backend records it with who closed,
// then the conversation is resolved; the patient is sent nothing.
const emit = defineEmits(['closed']);

const MAX_NOTE_LENGTH = 500;

const { t } = useI18n();
const REASONS = computed(() => [
  {
    value: 'IssueSolved',
    label: t('AI_BRAIN.SESSION_CLOSE.REASONS.ISSUE_SOLVED'),
  },
  {
    value: 'PatientStoppedReplying',
    label: t('AI_BRAIN.SESSION_CLOSE.REASONS.PATIENT_STOPPED_REPLYING'),
  },
  {
    value: 'HandledElsewhere',
    label: t('AI_BRAIN.SESSION_CLOSE.REASONS.HANDLED_ELSEWHERE'),
  },
  { value: 'Other', label: t('AI_BRAIN.SESSION_CLOSE.REASONS.OTHER') },
]);
const dialogRef = ref(null);
const conversationId = ref(null);
const reason = ref('');
const note = ref('');
const isClosing = ref(false);

const isValid = computed(
  () =>
    REASONS.value.some(item => item.value === reason.value) &&
    (reason.value !== 'Other' || note.value.trim().length > 0) &&
    note.value.trim().length <= MAX_NOTE_LENGTH
);

const open = id => {
  conversationId.value = id;
  reason.value = '';
  note.value = '';
  dialogRef.value?.open();
};

const confirm = async () => {
  if (!isValid.value) return;
  isClosing.value = true;
  try {
    await conversationSession.close(
      conversationId.value,
      reason.value,
      reason.value === 'Other' ? note.value.trim() : ''
    );
    dialogRef.value?.close();
    useAlert(t('AI_BRAIN.SESSION_CLOSE.DONE'));
    emit('closed');
  } catch (error) {
    useAlert(error?.response?.data?.error || t('AI_BRAIN.ERROR'));
  } finally {
    isClosing.value = false;
  }
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="md"
    :title="t('AI_BRAIN.SESSION_CLOSE.TITLE')"
    :description="t('AI_BRAIN.SESSION_CLOSE.DESCRIPTION')"
    :confirm-button-label="t('AI_BRAIN.SESSION_CLOSE.CONFIRM')"
    :disable-confirm-button="!isValid"
    :is-loading="isClosing"
    @confirm="confirm"
  >
    <fieldset class="flex flex-col gap-2">
      <label
        v-for="item in REASONS"
        :key="item.value"
        class="flex items-center gap-2 text-sm text-n-slate-12"
      >
        <input
          v-model="reason"
          type="radio"
          name="close-reason"
          :value="item.value"
        />
        {{ item.label }}
      </label>
    </fieldset>
    <TextArea
      v-if="reason === 'Other'"
      v-model="note"
      class="w-full mt-3"
      :max-length="MAX_NOTE_LENGTH"
      show-character-count
      :placeholder="t('AI_BRAIN.SESSION_CLOSE.NOTE_PLACEHOLDER')"
    />
  </Dialog>
</template>
