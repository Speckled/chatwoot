<script setup>
import { computed, nextTick, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useStore } from 'vuex';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useUISettings } from 'dashboard/composables/useUISettings';
import Button from 'dashboard/components-next/button/Button.vue';
import adminAssistantAPI from 'dashboard/api/aiBrain/adminAssistant';
import { frontendURL } from 'dashboard/helper/URLHelper';

// The admin assistant on every dashboard page, in a sidebar on the right: ask it to change the clinic's setup, or how to
// do something, and it proposes the change or opens the page beside the chat. On wider screens the page shrinks to make
// room, as with Copilot; on a phone the sidebar covers it. It stays open across pages and reloads. Approving a proposal
// sends an ordinary answer, so it goes through the same review and confirmation as on WhatsApp.
const { t } = useI18n();
const router = useRouter();
const store = useStore();
const { isAdmin } = useAdmin();
const accountId = computed(() => store.getters.getCurrentAccountId);

const { uiSettings, updateUISettings } = useUISettings();
const open = computed(
  () => isAdmin.value && !!uiSettings.value?.is_admin_assistant_open
);
const loaded = ref(false);
const sending = ref(false);
const text = ref('');
const messages = ref([]);
const listRef = ref(null);

const scrollDown = async () => {
  await nextTick();
  if (listRef.value) listRef.value.scrollTop = listRef.value.scrollHeight;
};
const load = async () => {
  try {
    messages.value = (await adminAssistantAPI.history()).data.map(message => ({
      role: message.role,
      text: message.text,
      cards: [],
    }));
  } catch (error) {
    messages.value = [];
  }
  loaded.value = true;
  scrollDown();
};
const toggle = () => {
  updateUISettings({ is_admin_assistant_open: !open.value });
};
watch(
  open,
  isOpen => {
    if (isOpen && !loaded.value) load();
  },
  { immediate: true }
);
const navigate = card => {
  router.push(frontendURL(`accounts/${accountId.value}/${card.path}`));
};
// A turn can take longer than a web request may, so the reply is asked for until it is ready. The backend gives up on a
// turn after a minute; the wait leaves room for the job queue.
const REPLY_POLL_INTERVAL_MS = 1500;
const REPLY_MAX_WAIT_MS = 120000;
const waitForReply = async requestId => {
  const deadline = Date.now() + REPLY_MAX_WAIT_MS;
  while (Date.now() < deadline) {
    // eslint-disable-next-line no-await-in-loop
    await new Promise(resolve => {
      setTimeout(resolve, REPLY_POLL_INTERVAL_MS);
    });
    // eslint-disable-next-line no-await-in-loop
    const response = await adminAssistantAPI.reply(requestId);
    if (response.status !== 202) return response.data;
  }
  throw new Error('The assistant did not answer in time');
};
const send = async value => {
  const body = (value ?? text.value).trim();
  if (!body || sending.value) return;
  messages.value.push({ role: 'user', text: body, cards: [] });
  if (value === undefined) text.value = '';
  sending.value = true;
  scrollDown();
  try {
    const { requestId } = (await adminAssistantAPI.send(body)).data;
    const reply = await waitForReply(requestId);
    messages.value.push({
      role: 'assistant',
      text: reply.textToSend,
      cards: reply.cards || [],
    });
    (reply.followUps || []).forEach(followUp =>
      messages.value.push({ role: 'assistant', text: followUp, cards: [] })
    );
    const page = (reply.cards || []).find(card => card.kind === 'navigate');
    if (page) navigate(page);
  } catch (error) {
    const busy = error?.response?.status === 409;
    messages.value.push({
      role: 'error',
      text: busy
        ? t('AI_BRAIN.ADMIN_ASSISTANT.BUSY')
        : error?.response?.data?.error || t('AI_BRAIN.ERROR'),
      cards: [],
    });
  } finally {
    sending.value = false;
    scrollDown();
  }
};
const onKeydown = event => {
  if (event.key === 'Enter' && !event.shiftKey) {
    event.preventDefault();
    send();
  }
};
</script>

<template>
  <template v-if="isAdmin">
    <button
      v-if="!open"
      type="button"
      class="fixed bottom-4 end-20 z-40 flex items-center gap-2 rounded-full bg-n-brand px-4 py-2 text-sm font-medium text-white shadow-lg"
      @click="toggle"
    >
      <span class="i-lucide-sparkles size-4" />
      {{ t('AI_BRAIN.ADMIN_ASSISTANT.OPEN') }}
    </button>
    <aside
      v-else
      class="fixed inset-y-0 end-0 z-50 flex h-full w-full max-w-sm flex-col border-s border-n-weak bg-n-solid-1 shadow-xl md:static md:z-auto md:w-[22.5rem] md:min-w-[22.5rem] md:max-w-none md:shadow-none"
    >
      <header
        class="flex items-center justify-between border-b border-n-weak px-4 py-3"
      >
        <div>
          <h2 class="text-sm font-semibold text-n-slate-12">
            {{ t('AI_BRAIN.ADMIN_ASSISTANT.TITLE') }}
          </h2>
          <p class="text-xs text-n-slate-11">
            {{ t('AI_BRAIN.ADMIN_ASSISTANT.SUBTITLE') }}
          </p>
        </div>
        <Button
          type="button"
          variant="ghost"
          color="slate"
          size="sm"
          icon="i-lucide-x"
          :aria-label="t('AI_BRAIN.ADMIN_ASSISTANT.CLOSE')"
          @click="toggle"
        />
      </header>
      <div ref="listRef" class="flex flex-1 flex-col gap-3 overflow-y-auto p-4">
        <p v-if="loaded && !messages.length" class="text-sm text-n-slate-11">
          {{ t('AI_BRAIN.ADMIN_ASSISTANT.EMPTY') }}
        </p>
        <div
          v-for="(message, index) in messages"
          :key="index"
          class="flex flex-col gap-2"
          :class="message.role === 'user' ? 'items-end' : 'items-start'"
        >
          <p
            class="max-w-[85%] whitespace-pre-wrap rounded-xl px-3 py-2 text-sm"
            :class="{
              'bg-n-brand text-white': message.role === 'user',
              'bg-n-alpha-2 text-n-slate-12': message.role === 'assistant',
              'bg-n-ruby-3 text-n-ruby-11': message.role === 'error',
            }"
          >
            {{ message.text }}
          </p>
          <div
            v-for="(card, cardIndex) in message.cards"
            :key="cardIndex"
            class="w-full rounded-xl border border-n-weak p-3 text-sm"
          >
            <template v-if="card.kind === 'navigate'">
              <button
                type="button"
                class="text-n-blue-11 hover:underline"
                @click="navigate(card)"
              >
                {{ card.title }}
              </button>
            </template>
            <template v-else-if="card.kind === 'proposals'">
              <p class="mb-2 font-medium text-n-slate-12">{{ card.title }}</p>
              <ul class="mb-3 list-disc ps-4 text-n-slate-11">
                <li v-for="item in card.items" :key="item">{{ item }}</li>
              </ul>
              <div class="flex gap-2">
                <Button
                  type="button"
                  size="xs"
                  :label="t('AI_BRAIN.ADMIN_ASSISTANT.APPROVE')"
                  :disabled="sending"
                  @click="send(t('AI_BRAIN.ADMIN_ASSISTANT.APPROVE_TEXT'))"
                />
                <Button
                  type="button"
                  size="xs"
                  color="slate"
                  variant="faded"
                  :label="t('AI_BRAIN.ADMIN_ASSISTANT.DECLINE')"
                  :disabled="sending"
                  @click="send(t('AI_BRAIN.ADMIN_ASSISTANT.DECLINE_TEXT'))"
                />
              </div>
            </template>
          </div>
        </div>
        <p v-if="sending" class="text-xs text-n-slate-11">
          {{ t('AI_BRAIN.ADMIN_ASSISTANT.THINKING') }}
        </p>
      </div>
      <footer class="border-t border-n-weak p-3">
        <textarea
          v-model="text"
          rows="2"
          class="block w-full resize-none rounded-lg border border-n-weak bg-n-solid-2 p-2 text-sm"
          :placeholder="t('AI_BRAIN.ADMIN_ASSISTANT.PLACEHOLDER')"
          @keydown="onKeydown"
        />
        <div class="mt-2 flex justify-end">
          <Button
            type="button"
            size="sm"
            :label="t('AI_BRAIN.ADMIN_ASSISTANT.SEND')"
            :is-loading="sending"
            :disabled="!text.trim()"
            @click="send()"
          />
        </div>
      </footer>
    </aside>
  </template>
</template>
