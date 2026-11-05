<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import testConversationsAPI from 'dashboard/api/aiBrain/testConversations';
import { TARGET, isEventTarget } from './reminderForm';

// Who a reminder goes to: a client, a staff member, a team, or the people of each appointment.
defineProps({
  users: { type: Array, default: () => [] },
  teams: { type: Array, default: () => [] },
});
const target = defineModel({ type: Object, required: true });
const { t } = useI18n();

const typeOptions = computed(() =>
  Object.values(TARGET).map(type => ({
    value: type,
    label: t(`AI_BRAIN.REMINDERS.TARGETS.${type}`),
  }))
);
const query = ref('');
const contacts = ref([]);
const searched = ref(false);

const search = async () => {
  try {
    contacts.value = (
      await testConversationsAPI.getContacts({ q: query.value.trim() })
    ).data;
  } catch (error) {
    contacts.value = [];
  }
  searched.value = true;
};
const pickContact = contact => {
  Object.assign(target.value, {
    chatwootContactId: contact.id,
    phoneNumber: contact.phoneNumber || '',
    name: contact.name || '',
  });
  contacts.value = [];
  searched.value = false;
};
// A typed number is a new recipient rather than the contact picked before.
const typePhone = value => {
  Object.assign(target.value, { phoneNumber: value, chatwootContactId: null });
};
const changeType = type => {
  target.value.type = Number(type);
};
</script>

<template>
  <div class="flex flex-col gap-4">
    <WithLabel name="target-type" :label="t('AI_BRAIN.REMINDERS.WHO')">
      <Select
        :model-value="target.type"
        :options="typeOptions"
        :aria-label="t('AI_BRAIN.REMINDERS.WHO')"
        @update:model-value="changeType"
      />
    </WithLabel>

    <template v-if="target.type === TARGET.CLIENT">
      <div class="flex items-center gap-2">
        <NextInput
          v-model="query"
          :placeholder="t('AI_BRAIN.REMINDERS.SEARCH_CONTACTS')"
          class="flex-1"
          @enter="search"
        />
        <Button
          type="button"
          variant="faded"
          color="slate"
          :label="t('AI_BRAIN.REMINDERS.SEARCH')"
          @click="search"
        />
      </div>
      <div v-if="contacts.length" class="flex flex-col gap-1">
        <button
          v-for="contact in contacts"
          :key="contact.id"
          type="button"
          class="flex justify-between px-3 py-2 text-sm rounded-lg text-start hover:bg-n-alpha-1 text-n-slate-12"
          @click="pickContact(contact)"
        >
          <span>{{ contact.name }}</span>
          <span class="text-n-slate-11">{{ contact.phoneNumber }}</span>
        </button>
      </div>
      <p v-else-if="searched" class="text-sm text-n-slate-11">
        {{ t('AI_BRAIN.REMINDERS.NO_CONTACTS') }}
      </p>
      <div class="grid gap-4 md:grid-cols-2">
        <WithLabel name="target-phone" :label="t('AI_BRAIN.REMINDERS.PHONE')">
          <NextInput
            :model-value="target.phoneNumber"
            class="w-full"
            placeholder="+5511999990000"
            @update:model-value="typePhone"
          />
        </WithLabel>
        <WithLabel
          name="target-name"
          :label="t('AI_BRAIN.REMINDERS.CONTACT_NAME')"
        >
          <NextInput v-model="target.name" class="w-full" />
        </WithLabel>
      </div>
    </template>

    <WithLabel
      v-else-if="target.type === TARGET.USER"
      name="target-user"
      :label="t('AI_BRAIN.REMINDERS.USER')"
    >
      <Select
        v-model="target.userId"
        :options="
          users.map(user => ({
            value: user.id,
            label: user.whatsAppNumber
              ? user.displayName || user.name
              : `${user.displayName || user.name} (${t('AI_BRAIN.REMINDERS.NO_WHATSAPP')})`,
          }))
        "
        :placeholder="t('AI_BRAIN.REMINDERS.SELECT')"
        :aria-label="t('AI_BRAIN.REMINDERS.USER')"
      />
    </WithLabel>

    <WithLabel
      v-else-if="target.type === TARGET.TEAM"
      name="target-team"
      :label="t('AI_BRAIN.REMINDERS.TEAM')"
    >
      <Select
        v-model="target.teamId"
        :options="teams.map(team => ({ value: team.id, label: team.name }))"
        :placeholder="t('AI_BRAIN.REMINDERS.SELECT')"
        :aria-label="t('AI_BRAIN.REMINDERS.TEAM')"
      />
    </WithLabel>

    <p v-if="isEventTarget(target.type)" class="text-sm text-n-slate-11">
      {{ t('AI_BRAIN.REMINDERS.EVENT_HINT') }}
    </p>
  </div>
</template>
