import { ref, shallowRef, computed, watch, onUnmounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import inboxesAPI from 'dashboard/api/aiBrain/inboxes';
import testConversationsAPI from 'dashboard/api/aiBrain/testConversations';
import aiBrainConversationsAPI from 'dashboard/api/aiBrain/conversations';

export function useAiBrainTestLab() {
  const { t } = useI18n();

  const inboxes = ref([]);
  const selectedInboxId = shallowRef(null);

  const conversations = ref([]);
  const selectedConversationId = shallowRef(null);
  const currentConversation = ref(null);

  const contacts = ref([]);
  const contactsQuery = shallowRef('');

  const loadingInboxes = shallowRef(false);
  const loadingConversations = shallowRef(false);
  const loadingCurrentConversation = shallowRef(false);
  const sendingMessage = shallowRef(false);
  const creatingInbox = shallowRef(false);
  const startingConversation = shallowRef(false);
  const isAiThinking = shallowRef(false);

  let pollTimer = null;
  let pollAttempts = 0;
  const MAX_POLL_ATTEMPTS = 25; // ~37 seconds at 1.5s interval

  const testInboxes = computed(() =>
    inboxes.value.filter(
      inbox =>
        inbox.channelType === 'Channel::Whatsapp' && inbox.provider === 'test'
    )
  );

  const currentInbox = computed(() =>
    inboxes.value.find(inbox => inbox.id === selectedInboxId.value)
  );

  const stopPolling = () => {
    if (pollTimer) {
      clearTimeout(pollTimer);
      pollTimer = null;
    }
    pollAttempts = 0;
    isAiThinking.value = false;
  };

  onUnmounted(stopPolling);

  const fetchInboxes = async () => {
    loadingInboxes.value = true;
    try {
      const response = await inboxesAPI.get();
      inboxes.value = response.data || [];

      // Auto-select first test inbox if available
      if (
        !selectedInboxId.value ||
        !testInboxes.value.some(i => i.id === selectedInboxId.value)
      ) {
        selectedInboxId.value = testInboxes.value[0]?.id || null;
      }
    } catch (error) {
      useAlert(t('AI_BRAIN.ERROR'));
    } finally {
      loadingInboxes.value = false;
    }
  };

  const createTestInbox = async ({ name, phoneNumber }) => {
    creatingInbox.value = true;
    try {
      const response = await inboxesAPI.create({
        name,
        phone_number: phoneNumber,
      });
      const created = response.data;
      inboxes.value = [...inboxes.value, created];
      selectedInboxId.value = created.id;
      useAlert(t('AI_BRAIN.TEST_INBOX_CREATED'));
      return created;
    } catch (error) {
      const message = error.response?.data?.error || t('AI_BRAIN.ERROR');
      useAlert(message);
      throw error;
    } finally {
      creatingInbox.value = false;
    }
  };

  const toggleInboxRouting = async (inbox, active) => {
    try {
      if (active) {
        await inboxesAPI.toggle(inbox.id, true);
        inbox.aiBrainInbox = { active: true };
      } else {
        await inboxesAPI.unassign(inbox.id);
        inbox.aiBrainInbox = null;
      }
      if (
        currentConversation.value &&
        currentConversation.value.inboxId === inbox.id
      ) {
        currentConversation.value.aiBrain.aiEnabled = Boolean(active);
      }
    } catch (error) {
      useAlert(t('AI_BRAIN.ERROR'));
    }
  };

  const fetchConversations = async () => {
    if (!selectedInboxId.value) {
      conversations.value = [];
      return;
    }
    loadingConversations.value = true;
    try {
      const response = await testConversationsAPI.get({
        inbox_id: selectedInboxId.value,
      });
      conversations.value = response.data || [];
    } catch (error) {
      conversations.value = [];
    } finally {
      loadingConversations.value = false;
    }
  };

  const fetchContacts = async (query = '') => {
    try {
      const response = await testConversationsAPI.getContacts({ q: query });
      contacts.value = response.data || [];
    } catch (error) {
      contacts.value = [];
    }
  };

  const pollConversationUntilAiReplies = (
    conversationId,
    previousMessageCount
  ) => {
    stopPolling();
    isAiThinking.value = true;

    const check = async () => {
      pollAttempts += 1;
      try {
        const response = await testConversationsAPI.show(conversationId);
        const data = response.data;

        if (selectedConversationId.value === conversationId) {
          currentConversation.value = data;
          const updatedIndex = conversations.value.findIndex(
            c => c.id === conversationId
          );
          if (updatedIndex !== -1) {
            conversations.value[updatedIndex] = {
              ...conversations.value[updatedIndex],
              status: data.status,
              aiBrain: data.aiBrain,
              lastActivityAt: data.lastActivityAt,
              lastMessage: data.lastMessage,
            };
          }
        }

        const messagesCount = data.messages?.length || 0;
        const lastMessage = data.messages?.[messagesCount - 1];
        const botReplied =
          messagesCount > previousMessageCount &&
          lastMessage &&
          lastMessage.role !== 'client';
        const notWaiting = !data.awaitingAi;

        if (botReplied || notWaiting || pollAttempts >= MAX_POLL_ATTEMPTS) {
          stopPolling();
          return;
        }

        pollTimer = setTimeout(check, 1500);
      } catch (err) {
        stopPolling();
      }
    };

    pollTimer = setTimeout(check, 1500);
  };

  const selectConversation = async conversationId => {
    if (
      selectedConversationId.value === conversationId &&
      currentConversation.value
    ) {
      return;
    }
    stopPolling();
    selectedConversationId.value = conversationId;
    if (!conversationId) {
      currentConversation.value = null;
      return;
    }
    loadingCurrentConversation.value = true;
    try {
      const response = await testConversationsAPI.show(conversationId);
      currentConversation.value = response.data;
      if (currentConversation.value?.awaitingAi) {
        pollConversationUntilAiReplies(
          conversationId,
          currentConversation.value.messages?.length || 0
        );
      }
    } catch (error) {
      currentConversation.value = null;
      useAlert(t('AI_BRAIN.ERROR'));
    } finally {
      loadingCurrentConversation.value = false;
    }
  };

  const startConversation = async ({
    contactId = null,
    phoneNumber = '',
    contactName = '',
    forceNew = false,
  }) => {
    if (!selectedInboxId.value) {
      useAlert(t('AI_BRAIN.NO_TEST_INBOX'));
      return null;
    }
    startingConversation.value = true;
    try {
      const response = await testConversationsAPI.create({
        inbox_id: selectedInboxId.value,
        contact_id: contactId,
        phone_number: phoneNumber,
        contact_name: contactName,
        force_new: forceNew,
      });
      const conv = response.data;
      await fetchConversations();
      await selectConversation(conv.id);
      return conv;
    } catch (error) {
      const message = error.response?.data?.error || t('AI_BRAIN.ERROR');
      useAlert(message);
      throw error;
    } finally {
      startingConversation.value = false;
    }
  };

  const sendMessage = async ({ content, senderRole }) => {
    if (!selectedConversationId.value) return;
    sendingMessage.value = true;
    const prevCount = currentConversation.value?.messages?.length || 0;
    try {
      const response = await testConversationsAPI.sendMessage(
        selectedConversationId.value,
        {
          content,
          sender_role: senderRole,
        }
      );
      currentConversation.value = response.data;
      await fetchConversations();

      if (senderRole === 'client' && currentConversation.value?.awaitingAi) {
        pollConversationUntilAiReplies(
          selectedConversationId.value,
          prevCount + 1
        );
      }
    } catch (error) {
      const message = error.response?.data?.error || t('AI_BRAIN.ERROR');
      useAlert(message);
    } finally {
      sendingMessage.value = false;
    }
  };

  const endHumanSession = async () => {
    if (!selectedConversationId.value) return;
    try {
      await aiBrainConversationsAPI.endSession(selectedConversationId.value);
      const response = await testConversationsAPI.show(
        selectedConversationId.value
      );
      currentConversation.value = response.data;
      await fetchConversations();
    } catch (error) {
      useAlert(t('AI_BRAIN.ERROR'));
    }
  };

  const validateReview = async replyText => {
    if (!selectedConversationId.value) return;
    try {
      await aiBrainConversationsAPI.validateReview(
        selectedConversationId.value,
        replyText
      );
      const response = await testConversationsAPI.show(
        selectedConversationId.value
      );
      currentConversation.value = response.data;
      await fetchConversations();
    } catch (error) {
      useAlert(t('AI_BRAIN.ERROR'));
    }
  };

  watch(selectedInboxId, () => {
    stopPolling();
    selectedConversationId.value = null;
    currentConversation.value = null;
    fetchConversations();
  });

  return {
    inboxes,
    testInboxes,
    currentInbox,
    selectedInboxId,
    conversations,
    selectedConversationId,
    currentConversation,
    contacts,
    contactsQuery,
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
    fetchConversations,
    fetchContacts,
    selectConversation,
    startConversation,
    sendMessage,
    endHumanSession,
    validateReview,
  };
}
