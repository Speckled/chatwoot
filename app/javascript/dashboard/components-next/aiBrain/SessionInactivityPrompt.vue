<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import SessionCloseDialog from 'dashboard/components-next/aiBrain/SessionCloseDialog.vue';
import conversationSession from 'dashboard/api/aiBrain/conversationSession';

// The prompt of a person's quiet AI Brain chat (LRB-85). 'notice' asks whether the patient's issue is solved; Yes
// ('solved') offers to close, No ('unsolved') asks to message the patient and still offers to close. 'close_required' only
// offers to close. A message from either side clears it.
const props = defineProps({
  chat: { type: Object, default: () => ({}) },
});

const CLOSE_BUTTON_COLORS = {
  solved: 'blue',
  unsolved: 'slate',
  close_required: 'ruby',
};

const { t } = useI18n();
const prompt = ref(null);
const isBusy = ref(false);
const closeDialogRef = ref(null);

const load = async () => {
  prompt.value = null;
  if (!props.chat.id) return;
  try {
    prompt.value = (
      await conversationSession.show(props.chat.id)
    ).data.inactivityPrompt;
  } catch (error) {
    prompt.value = null;
  }
};

// The backend's prompt arrives as a conversation update, which moves updated_at.
watch(() => [props.chat.id, props.chat.status, props.chat.updated_at], load, {
  immediate: true,
});

const MESSAGES = computed(() => ({
  notice: t('AI_BRAIN.INACTIVITY_PROMPT.NOTICE'),
  solved: t('AI_BRAIN.INACTIVITY_PROMPT.SOLVED'),
  unsolved: t('AI_BRAIN.INACTIVITY_PROMPT.UNSOLVED'),
  close_required: t('AI_BRAIN.INACTIVITY_PROMPT.CLOSE_REQUIRED'),
}));

const answer = async solved => {
  isBusy.value = true;
  try {
    await conversationSession.answer(props.chat.id, solved);
  } catch (error) {
    useAlert(error?.response?.data?.error || t('AI_BRAIN.ERROR'));
  } finally {
    isBusy.value = false;
    await load();
  }
};

const openClose = () => closeDialogRef.value?.open(props.chat.id);
</script>

<template>
  <div class="contents">
    <div
      v-if="prompt"
      class="flex flex-wrap items-center gap-2 rounded-lg px-3 py-2 text-sm"
      :class="
        prompt === 'close_required'
          ? 'bg-n-ruby-3 text-n-ruby-12'
          : 'bg-n-amber-3 text-n-amber-12'
      "
    >
      <span>{{ MESSAGES[prompt] }}</span>
      <template v-if="prompt === 'notice'">
        <Button
          :label="t('AI_BRAIN.INACTIVITY_PROMPT.YES')"
          size="sm"
          :disabled="isBusy"
          @click="answer(true)"
        />
        <Button
          :label="t('AI_BRAIN.INACTIVITY_PROMPT.NO')"
          size="sm"
          slate
          :disabled="isBusy"
          @click="answer(false)"
        />
      </template>
      <Button
        v-else
        :label="
          prompt === 'unsolved'
            ? t('AI_BRAIN.INACTIVITY_PROMPT.CLOSE_WITHOUT_CONTACT')
            : t('AI_BRAIN.INACTIVITY_PROMPT.CLOSE')
        "
        size="sm"
        :color="CLOSE_BUTTON_COLORS[prompt]"
        @click="openClose"
      />
      <SessionCloseDialog ref="closeDialogRef" @closed="load" />
    </div>
  </div>
</template>
