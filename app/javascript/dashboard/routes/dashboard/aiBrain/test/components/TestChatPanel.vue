<script setup>
import { shallowRef, watch, nextTick } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  conversation: {
    type: Object,
    default: null,
  },
  sendingMessage: {
    type: Boolean,
    default: false,
  },
  isAiThinking: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['sendMessage', 'endHumanSession', 'validateReview']);

const { t } = useI18n();

const messageContent = shallowRef('');
const senderRole = shallowRef('client'); // 'client' | 'secretary'
const reviewDraft = shallowRef('');
const messageScrollContainer = shallowRef(null);

watch(
  () => props.conversation?.aiBrain?.review,
  review => {
    reviewDraft.value = review?.proposedReplyText || '';
  },
  { immediate: true }
);

const scrollToBottom = () => {
  if (messageScrollContainer.value) {
    messageScrollContainer.value.scrollTop =
      messageScrollContainer.value.scrollHeight;
  }
};

watch(
  () => [props.conversation?.messages?.length, props.isAiThinking],
  () => {
    nextTick(scrollToBottom);
  }
);

const submitMessage = () => {
  const text = messageContent.value.trim();
  if (!text || props.sendingMessage) return;

  emit('sendMessage', {
    content: text,
    senderRole: senderRole.value,
  });
  messageContent.value = '';
};

const onTextareaKeydown = event => {
  if (event.key === 'Enter' && !event.shiftKey) {
    event.preventDefault();
    // Modern Web Guidance: IME-safe enter-to-submit check
    if (event.isComposing || event.keyCode === 229) {
      return;
    }
    submitMessage();
  }
};

const submitReview = () => {
  const text = reviewDraft.value.trim();
  if (!text) return;
  emit('validateReview', text);
};

const formatTime = timestamp => {
  if (!timestamp) return '';
  const date = new Date(timestamp * 1000);
  return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
};
</script>

<template>
  <div
    class="flex flex-col h-full rounded-xl border border-n-weak bg-n-solid-1 overflow-hidden"
  >
    <!-- Empty state -->
    <div
      v-if="!conversation"
      class="flex-1 flex flex-col items-center justify-center p-8 text-center text-n-slate-11 gap-2"
    >
      <span class="text-3xl">💬</span>
      <p class="text-sm">
        {{ t('AI_BRAIN.NO_CONVERSATION_SELECTED') }}
      </p>
    </div>

    <!-- Active Conversation -->
    <template v-else>
      <!-- Conversation Header -->
      <div
        class="flex flex-wrap items-center justify-between gap-3 p-3.5 border-b border-n-weak bg-n-solid-2"
      >
        <div class="flex items-center gap-3 min-w-0">
          <div
            class="flex items-center justify-center size-9 rounded-full bg-n-brand/10 text-n-brand font-semibold text-sm"
          >
            {{ conversation.contact?.name?.[0] || 'C' }}
          </div>
          <div class="flex flex-col min-w-0">
            <div class="flex items-center gap-2">
              <span class="text-sm font-semibold text-n-slate-12 truncate">
                {{ conversation.contact?.name }}
              </span>
              <span class="text-xs font-mono text-n-slate-10">
                #{{ conversation.id }}
              </span>
            </div>
            <span class="text-xs font-mono text-n-slate-11">
              {{ conversation.contact?.phoneNumber }}
            </span>
          </div>
        </div>

        <!-- AI metadata chips -->
        <div class="flex flex-wrap items-center gap-2 text-xs">
          <div
            class="flex items-center gap-1.5 px-2 py-1 rounded-md border border-n-weak bg-n-solid-1"
          >
            <span class="text-n-slate-10 font-medium">
              {{ t('AI_BRAIN.AI_STATE') }}:
            </span>
            <span
              class="font-semibold uppercase tracking-wider"
              :class="{
                'text-n-brand': conversation.aiBrain?.state === 'bot',
                'text-n-amber-11': conversation.aiBrain?.state === 'human',
                'text-n-ruby-11': conversation.aiBrain?.state === 'review',
              }"
            >
              {{ conversation.aiBrain?.state || 'bot' }}
            </span>
          </div>

          <div
            v-if="conversation.aiBrain?.activeWorkflow"
            class="flex items-center gap-1.5 px-2 py-1 rounded-md border border-n-weak bg-n-solid-1"
          >
            <span class="text-n-slate-10 font-medium">
              {{ t('AI_BRAIN.WORKFLOW') }}:
            </span>
            <span class="font-medium text-n-teal-11">
              {{ conversation.aiBrain.activeWorkflow }}
            </span>
          </div>

          <div
            v-if="conversation.aiBrain?.sessionId"
            class="hidden md:flex items-center gap-1.5 px-2 py-1 rounded-md border border-n-weak bg-n-solid-1"
          >
            <span class="text-n-slate-10 font-medium">
              {{ t('AI_BRAIN.SESSION') }}:
            </span>
            <span class="font-mono text-[11px] text-n-slate-11">
              {{ String(conversation.aiBrain.sessionId).slice(0, 8) }}...
            </span>
          </div>

          <!-- Human Session End action -->
          <Button
            v-if="conversation.aiBrain?.state === 'human'"
            type="button"
            color="amber"
            size="sm"
            :label="t('AI_BRAIN.END_SESSION')"
            @click="emit('endHumanSession')"
          />
        </div>
      </div>

      <!-- Pending Review Banner -->
      <div
        v-if="conversation.aiBrain?.state === 'review'"
        class="p-4 border-b border-n-ruby-6 bg-n-ruby-2 flex flex-col gap-2"
      >
        <div class="flex items-center justify-between">
          <span class="text-xs font-semibold text-n-ruby-12">
            {{ t('AI_BRAIN.REVIEW_PROPOSAL') }}
          </span>
          <span
            v-if="conversation.aiBrain?.review?.reason"
            class="text-xs text-n-ruby-11 italic"
          >
            {{ t('AI_BRAIN.REVIEW_REASON') }}:
            {{ conversation.aiBrain.review.reason }}
          </span>
        </div>
        <textarea
          v-model="reviewDraft"
          rows="2"
          class="w-full text-xs rounded-lg border border-n-ruby-6 bg-n-solid-1 p-2 text-n-slate-12 focus:outline-none"
        />
        <div class="flex justify-end">
          <Button
            type="button"
            color="ruby"
            size="sm"
            :disabled="!reviewDraft.trim()"
            :label="t('AI_BRAIN.VALIDATE_SEND')"
            @click="submitReview"
          />
        </div>
      </div>

      <!-- Messages stream -->
      <div
        ref="messageScrollContainer"
        class="flex-1 p-4 overflow-y-auto flex flex-col gap-3 bg-n-solid-2/40"
      >
        <div
          v-if="!conversation.messages?.length"
          class="m-auto text-xs text-n-slate-10 text-center"
        >
          {{ t('AI_BRAIN.NO_MESSAGES') }}
        </div>

        <div
          v-for="msg in conversation.messages"
          :key="msg.id"
          class="flex flex-col"
          :class="{
            'items-start': msg.role === 'client',
            'items-end': msg.role === 'bot' || msg.role === 'secretary',
            'items-center':
              msg.role === 'note' ||
              msg.role === 'activity' ||
              msg.role === 'system',
          }"
        >
          <!-- Internal Note or System Announcement -->
          <div
            v-if="msg.private || msg.role === 'note'"
            class="max-w-md p-2.5 my-1 rounded-lg border border-n-amber-6 bg-n-amber-2 text-xs text-n-amber-12"
          >
            <div
              class="flex items-center gap-1 font-semibold text-[11px] uppercase tracking-wider mb-0.5"
            >
              <i class="i-lucide-alert-triangle size-3" />
              <span>{{ t('AI_BRAIN.SYSTEM_NOTE') }}</span>
              <span class="ms-auto font-mono text-[10px] text-n-amber-11">
                {{ formatTime(msg.createdAt) }}
              </span>
            </div>
            <p class="whitespace-pre-wrap">{{ msg.content }}</p>
          </div>

          <!-- Client Message (Incoming) -->
          <div
            v-else-if="msg.role === 'client'"
            class="max-w-md flex flex-col gap-1 items-start"
          >
            <span class="text-[11px] font-medium text-n-slate-10 ps-1">
              {{ conversation.contact?.name || 'Client' }}
            </span>
            <div
              class="p-3 rounded-2xl rounded-tl-sm bg-n-solid-1 border border-n-weak text-sm text-n-slate-12 shadow-sm whitespace-pre-wrap"
            >
              {{ msg.content }}
            </div>
            <span class="text-[10px] font-mono text-n-slate-10 ps-1">
              {{ formatTime(msg.createdAt) }}
            </span>
          </div>

          <!-- AI Brain Bot Message (Outgoing) -->
          <div
            v-else-if="msg.role === 'bot'"
            class="max-w-md flex flex-col gap-1 items-end"
          >
            <div
              class="flex items-center gap-1 text-[11px] font-semibold text-n-brand pe-1"
            >
              <i class="i-lucide-bot size-3" />
              <span>{{ t('AI_BRAIN.ROLE_BOT') }}</span>
            </div>
            <div
              class="p-3 rounded-2xl rounded-tr-sm bg-n-brand text-white text-sm shadow-sm whitespace-pre-wrap"
            >
              {{ msg.content }}
            </div>
            <span class="text-[10px] font-mono text-n-slate-10 pe-1">
              {{ formatTime(msg.createdAt) }}
            </span>
          </div>

          <!-- Secretary / User Message (Outgoing) -->
          <div
            v-else-if="msg.role === 'secretary'"
            class="max-w-md flex flex-col gap-1 items-end"
          >
            <div
              class="flex items-center gap-1 text-[11px] font-semibold text-n-teal-11 pe-1"
            >
              <i class="i-lucide-user size-3" />
              <span>{{ msg.senderName || t('AI_BRAIN.ROLE_SECRETARY') }}</span>
            </div>
            <div
              class="p-3 rounded-2xl rounded-tr-sm bg-n-teal-9 text-white text-sm shadow-sm whitespace-pre-wrap"
            >
              {{ msg.content }}
            </div>
            <span class="text-[10px] font-mono text-n-slate-10 pe-1">
              {{ formatTime(msg.createdAt) }}
            </span>
          </div>

          <!-- Other generic messages -->
          <div
            v-else
            class="p-2 rounded-lg bg-n-solid-3 text-xs text-n-slate-11 my-1"
          >
            {{ msg.content }}
          </div>
        </div>

        <!-- AI Generating reply indicator -->
        <div
          v-if="isAiThinking"
          class="flex items-center gap-2 p-2 rounded-lg bg-n-brand/10 text-n-brand text-xs font-medium self-end animate-pulse"
        >
          <i class="i-lucide-bot size-3.5" />
          <span>{{ t('AI_BRAIN.AI_THINKING') }}</span>
        </div>
      </div>

      <!-- Message Composer -->
      <div
        class="p-3.5 border-t border-n-weak bg-n-solid-1 flex flex-col gap-2.5"
      >
        <!-- Sender role selector -->
        <div class="flex items-center gap-4 text-xs">
          <span class="font-medium text-n-slate-11">
            {{ t('AI_BRAIN.SENDER_ROLE') }}:
          </span>
          <label
            class="flex items-center gap-1.5 cursor-pointer font-medium text-n-slate-12"
          >
            <input
              v-model="senderRole"
              type="radio"
              name="test-sender-role"
              value="client"
              class="accent-n-brand"
            />
            <span>{{ t('AI_BRAIN.ROLE_CLIENT') }}</span>
          </label>
          <label
            class="flex items-center gap-1.5 cursor-pointer font-medium text-n-slate-12"
          >
            <input
              v-model="senderRole"
              type="radio"
              name="test-sender-role"
              value="secretary"
              class="accent-n-brand"
            />
            <span>{{ t('AI_BRAIN.ROLE_SECRETARY') }}</span>
          </label>
        </div>

        <!-- Input field and send button -->
        <div class="flex items-end gap-2">
          <label for="ai-test-message-input" class="sr-only">
            {{ t('AI_BRAIN.MESSAGE_PLACEHOLDER') }}
          </label>
          <textarea
            id="ai-test-message-input"
            v-model="messageContent"
            rows="2"
            class="flex-1 text-sm rounded-xl border border-n-weak bg-n-solid-2 text-n-slate-12 p-2.5 resize-none focus:border-n-brand focus:outline-none"
            :placeholder="t('AI_BRAIN.MESSAGE_PLACEHOLDER')"
            @keydown="onTextareaKeydown"
          />
          <Button
            type="button"
            color="blue"
            size="md"
            icon="i-lucide-send"
            :is-loading="sendingMessage"
            :disabled="!messageContent.trim()"
            :label="t('AI_BRAIN.SEND')"
            @click="submitMessage"
          />
        </div>
      </div>
    </template>
  </div>
</template>
