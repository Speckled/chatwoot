<script setup>
import { onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import SettingsLayout from '../../settings/SettingsLayout.vue';
import BaseSettingsHeader from '../../settings/components/BaseSettingsHeader.vue';
import TestInboxBar from './components/TestInboxBar.vue';
import TestConversationPanel from './components/TestConversationPanel.vue';
import TestChatPanel from './components/TestChatPanel.vue';
import { useAiBrainTestLab } from './useAiBrainTestLab';

const { t } = useI18n();

const {
  inboxes,
  currentInbox,
  selectedInboxId,
  conversations,
  selectedConversationId,
  currentConversation,
  contacts,
  loadingInboxes,
  loadingConversations,
  loadingCurrentConversation,
  sendingMessage,
  creatingInbox,
  startingConversation,
  isAiThinking,
  fetchInboxes,
  createTestInbox,
  toggleInboxRouting,
  fetchContacts,
  selectConversation,
  startConversation,
  sendMessage,
  endHumanSession,
  validateReview,
} = useAiBrainTestLab();

onMounted(async () => {
  await fetchInboxes();
  await fetchContacts();
});
</script>

<template>
  <SettingsLayout :is-loading="loadingInboxes && !inboxes.length">
    <template #header>
      <BaseSettingsHeader :title="t('AI_BRAIN.TEST')" />
    </template>
    <template #body>
      <div
        class="flex flex-col gap-4 w-full h-[calc(100vh-140px)] min-h-[600px]"
      >
        <!-- Inbox bar -->
        <TestInboxBar
          :inboxes="inboxes"
          :selected-inbox-id="selectedInboxId"
          :current-inbox="currentInbox"
          :creating-inbox="creatingInbox"
          @select-inbox="id => (selectedInboxId = id)"
          @create-test-inbox="createTestInbox"
          @toggle-inbox-routing="toggleInboxRouting"
        />

        <!-- Main split workspace -->
        <div class="grid grid-cols-1 md:grid-cols-12 gap-4 flex-1 min-h-0">
          <!-- Left side: Conversation list & contact picker (4 cols) -->
          <div class="md:col-span-4 h-full min-h-0">
            <TestConversationPanel
              :conversations="conversations"
              :selected-conversation-id="selectedConversationId"
              :contacts="contacts"
              :loading-conversations="loadingConversations"
              :starting-conversation="startingConversation"
              @select-conversation="selectConversation"
              @start-conversation="startConversation"
              @search-contacts="fetchContacts"
            />
          </div>

          <!-- Right side: Chat stream & message composer (8 cols) -->
          <div class="md:col-span-8 h-full min-h-0">
            <TestChatPanel
              :conversation="currentConversation"
              :loading="loadingCurrentConversation"
              :sending-message="sendingMessage"
              :is-ai-thinking="isAiThinking"
              @send-message="sendMessage"
              @end-human-session="endHumanSession"
              @validate-review="validateReview"
            />
          </div>
        </div>
      </div>
    </template>
  </SettingsLayout>
</template>
