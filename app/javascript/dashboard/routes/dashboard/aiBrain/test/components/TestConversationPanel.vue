<script setup>
import { shallowRef, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';

const props = defineProps({
  conversations: {
    type: Array,
    required: true,
  },
  selectedConversationId: {
    type: [Number, String],
    default: null,
  },
  contacts: {
    type: Array,
    default: () => [],
  },
  loadingConversations: {
    type: Boolean,
    default: false,
  },
  startingConversation: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits([
  'selectConversation',
  'startConversation',
  'searchContacts',
]);

const { t } = useI18n();

const showNewModal = shallowRef(false);
const activeMode = shallowRef('existing'); // 'existing' | 'manual'
const selectedContactId = shallowRef(null);
const searchQuery = shallowRef('');
const manualPhone = shallowRef('');
const manualName = shallowRef('');
const forceNew = shallowRef(false);

const filteredContacts = computed(() => props.contacts);

let searchDebounce = null;
const onSearchInput = event => {
  searchQuery.value = event.target.value;
  clearTimeout(searchDebounce);
  searchDebounce = setTimeout(() => {
    emit('searchContacts', searchQuery.value.trim());
  }, 250);
};

const openNewConversation = () => {
  selectedContactId.value = props.contacts[0]?.id || null;
  manualPhone.value = '+5511988887777';
  manualName.value = 'Maria Silva';
  forceNew.value = false;
  showNewModal.value = true;
  emit('searchContacts', '');
};

const submitStart = async () => {
  const payload = {
    forceNew: forceNew.value,
  };
  if (activeMode.value === 'existing') {
    if (!selectedContactId.value) return;
    payload.contactId = selectedContactId.value;
  } else {
    if (!manualPhone.value.trim()) return;
    payload.phoneNumber = manualPhone.value.trim();
    payload.contactName = manualName.value.trim();
  }

  try {
    await emit('startConversation', payload);
    showNewModal.value = false;
  } catch (err) {
    // handled by composable alert
  }
};

const formatTime = timestamp => {
  if (!timestamp) return '';
  const date = new Date(timestamp * 1000);
  return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
};

const stateBadgeClass = state => {
  switch (state) {
    case 'bot':
      return 'bg-n-brand/10 text-n-brand border-n-brand/20';
    case 'human':
      return 'bg-n-amber-3 text-n-amber-11 border-n-amber-6';
    case 'review':
      return 'bg-n-ruby-3 text-n-ruby-11 border-n-ruby-6';
    default:
      return 'bg-n-slate-3 text-n-slate-11 border-n-slate-6';
  }
};
</script>

<template>
  <div
    class="flex flex-col h-full rounded-xl border border-n-weak bg-n-solid-1 overflow-hidden"
  >
    <!-- Header -->
    <div class="flex items-center justify-between p-3 border-b border-n-weak">
      <div class="flex items-center gap-2">
        <span class="text-sm font-semibold text-n-slate-12">
          {{ t('AI_BRAIN.CONVERSATIONS_TITLE') }}
        </span>
        <span class="text-xs font-mono text-n-slate-11">
          ({{ conversations.length }})
        </span>
      </div>
      <Button
        type="button"
        color="blue"
        size="sm"
        icon="i-woot-plus"
        :label="t('AI_BRAIN.NEW_CONVERSATION')"
        @click="openNewConversation"
      />
    </div>

    <!-- New conversation dialog -->
    <div v-if="showNewModal" class="p-4 border-b border-n-weak bg-n-solid-2">
      <form class="flex flex-col gap-3" @submit.prevent="submitStart">
        <div class="flex items-center justify-between">
          <h4
            class="text-xs font-semibold uppercase tracking-wider text-n-slate-11"
          >
            {{ t('AI_BRAIN.START_CONVERSATION') }}
          </h4>
          <button
            type="button"
            class="flex items-center text-xs text-n-slate-11 hover:text-n-slate-12"
            @click="showNewModal = false"
          >
            <i class="i-lucide-x size-3.5" />
          </button>
        </div>

        <!-- Mode selector tabs -->
        <div
          class="flex rounded-lg border border-n-weak bg-n-solid-1 p-0.5 text-xs"
        >
          <button
            type="button"
            class="flex-1 py-1 rounded-md text-center transition-colors"
            :class="
              activeMode === 'existing'
                ? 'bg-n-solid-3 font-semibold text-n-slate-12 shadow-sm'
                : 'text-n-slate-11 hover:text-n-slate-12'
            "
            @click="activeMode = 'existing'"
          >
            {{ t('AI_BRAIN.SELECT_EXISTING_CONTACT') }}
          </button>
          <button
            type="button"
            class="flex-1 py-1 rounded-md text-center transition-colors"
            :class="
              activeMode === 'manual'
                ? 'bg-n-solid-3 font-semibold text-n-slate-12 shadow-sm'
                : 'text-n-slate-11 hover:text-n-slate-12'
            "
            @click="activeMode = 'manual'"
          >
            {{ t('AI_BRAIN.OR_ENTER_PHONE') }}
          </button>
        </div>

        <!-- Existing contact picker -->
        <div v-if="activeMode === 'existing'" class="flex flex-col gap-2">
          <NextInput
            :model-value="searchQuery"
            size="sm"
            class="w-full"
            :placeholder="t('AI_BRAIN.SEARCH_CONTACTS')"
            @input="onSearchInput"
          />
          <div
            class="max-h-36 overflow-y-auto rounded-lg border border-n-weak bg-n-solid-1 divide-y divide-n-weak"
          >
            <label
              v-for="contact in filteredContacts"
              :key="contact.id"
              class="flex items-center gap-2 p-2 cursor-pointer hover:bg-n-solid-2 text-xs text-n-slate-12"
            >
              <input
                v-model="selectedContactId"
                type="radio"
                name="selected-contact"
                :value="contact.id"
                class="accent-n-brand"
              />
              <span class="font-medium truncate">{{ contact.name }}</span>
              <span class="text-n-slate-11 font-mono text-[11px] ms-auto">
                {{ contact.phoneNumber }}
              </span>
            </label>
            <p
              v-if="!filteredContacts.length"
              class="p-2 text-center text-xs text-n-slate-11"
            >
              {{ t('AI_BRAIN.NO_USERS_FOUND') }}
            </p>
          </div>
        </div>

        <!-- Manual phone input -->
        <div v-else class="flex flex-col gap-2">
          <WithLabel name="manual-phone" :label="t('AI_BRAIN.CLIENT_PHONE')">
            <NextInput
              v-model="manualPhone"
              size="sm"
              class="w-full"
              placeholder="+5511988887777"
              required
            />
          </WithLabel>
          <WithLabel name="manual-name" :label="t('AI_BRAIN.CLIENT_NAME')">
            <NextInput
              v-model="manualName"
              size="sm"
              class="w-full"
              placeholder="Maria Silva"
            />
          </WithLabel>
        </div>

        <label
          class="flex items-center gap-2 cursor-pointer text-xs text-n-slate-12"
        >
          <Checkbox v-model="forceNew" />
          <span>{{ t('AI_BRAIN.FORCE_NEW_CONVERSATION') }}</span>
        </label>

        <div class="flex justify-end gap-2 pt-1">
          <Button
            type="button"
            variant="faded"
            color="slate"
            size="sm"
            :label="t('AI_BRAIN.CANCEL')"
            @click="showNewModal = false"
          />
          <Button
            type="submit"
            color="blue"
            size="sm"
            :is-loading="startingConversation"
            :label="t('AI_BRAIN.START_CONVERSATION')"
          />
        </div>
      </form>
    </div>

    <!-- Conversation list -->
    <div class="flex-1 overflow-y-auto divide-y divide-n-weak">
      <div
        v-if="loadingConversations"
        class="p-6 text-center text-xs text-n-slate-11"
      >
        ...
      </div>

      <div
        v-else-if="!conversations.length"
        class="p-6 text-center text-xs text-n-slate-11"
      >
        {{ t('AI_BRAIN.NO_CONVERSATION_SELECTED') }}
      </div>

      <button
        v-for="conv in conversations"
        :key="conv.id"
        type="button"
        class="w-full text-start p-3 transition-colors flex flex-col gap-1 hover:bg-n-solid-2 focus:outline-none"
        :class="
          selectedConversationId === conv.id
            ? 'bg-n-solid-2 border-s-2 border-n-brand'
            : ''
        "
        @click="emit('selectConversation', conv.id)"
      >
        <div class="flex items-center justify-between w-full gap-2">
          <span class="text-sm font-medium text-n-slate-12 truncate">
            {{ conv.contact?.name || `Conversation #${conv.id}` }}
          </span>
          <span class="text-[11px] font-mono text-n-slate-10 flex-shrink-0">
            {{ formatTime(conv.lastActivityAt) }}
          </span>
        </div>

        <div class="flex items-center justify-between gap-2 text-xs">
          <span class="text-n-slate-11 font-mono text-[11px] truncate">
            {{ conv.contact?.phoneNumber || `#${conv.id}` }}
          </span>
          <span
            class="text-[10px] font-semibold uppercase px-1.5 py-0.5 rounded border"
            :class="stateBadgeClass(conv.aiBrain?.state)"
          >
            {{ conv.aiBrain?.state || 'bot' }}
          </span>
        </div>

        <p
          v-if="conv.lastMessage"
          class="text-xs text-n-slate-11 line-clamp-1 italic mt-0.5"
        >
          <span class="font-normal not-italic text-n-slate-10">
            {{ conv.lastMessage.role }}:
          </span>
          {{ conv.lastMessage.content }}
        </p>
      </button>
    </div>
  </div>
</template>
