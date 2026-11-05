<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import remindersAPI from 'dashboard/api/aiBrain/reminders';
import inboxesAPI from 'dashboard/api/aiBrain/inboxes';
import TargetPicker from './TargetPicker.vue';
import SchedulePicker from './SchedulePicker.vue';
import {
  CONTENT,
  TARGET,
  canSendDailySchedule,
  fromReminderForm,
  isEventTarget,
  isStaffTarget,
  newReminderForm,
  toReminderForm,
} from './reminderForm';

// Creates or edits one reminder. `placeholders` are the AI Brain's {{placeholders}} for each kind of reminder.
const props = defineProps({
  inboxes: { type: Array, default: () => [] },
  users: { type: Array, default: () => [] },
  teams: { type: Array, default: () => [] },
  calendars: { type: Array, default: () => [] },
  placeholders: { type: Object, default: () => ({}) },
});
const emit = defineEmits(['saved']);
const WHATSAPP = 'Channel::Whatsapp';
const SENDING_CHANNELS = [WHATSAPP, 'Channel::Instagram'];

const { t } = useI18n();
const dialogRef = ref(null);
const form = ref(newReminderForm());
const errors = ref({});
const saving = ref(false);
const templates = ref([]);

const inboxOptions = computed(() =>
  props.inboxes
    .filter(inbox => SENDING_CHANNELS.includes(inbox.channelType))
    .map(inbox => ({
      value: inbox.id,
      label: inbox.phoneNumber
        ? `${inbox.name} (${inbox.phoneNumber})`
        : inbox.name,
    }))
);
const inbox = computed(() =>
  props.inboxes.find(item => item.id === Number(form.value.channel.inboxId))
);
const isWhatsApp = computed(() => inbox.value?.channelType === WHATSAPP);
const templateOptions = computed(() => [
  { value: '', label: t('AI_BRAIN.REMINDERS.NO_TEMPLATE') },
  ...templates.value.map(template => ({
    value: `${template.name}|${template.language}`,
    label: `${template.name} (${template.language})`,
  })),
]);
const selectedTemplate = computed(() => {
  const chosen = form.value.channel.template;
  return templates.value.find(
    template =>
      template.name === chosen?.name && template.language === chosen?.language
  );
});
// The test inbox has no 24-hour window; real WhatsApp numbers do.
const needsTemplateWarning = computed(
  () =>
    isWhatsApp.value &&
    inbox.value?.provider !== 'test' &&
    !form.value.channel.template?.name
);
const staff = computed(() => isStaffTarget(form.value.target.type));
const kindOptions = computed(() =>
  [CONTENT.TEXT, CONTENT.DAILY_SCHEDULE]
    .filter(
      kind =>
        kind === CONTENT.TEXT ||
        canSendDailySchedule(form.value.target.type, form.value.schedule.preset)
    )
    .map(kind => ({
      value: kind,
      label: t(`AI_BRAIN.REMINDERS.KINDS.${kind}`),
    }))
);
const placeholderNames = computed(() => {
  if (form.value.content.kind === CONTENT.DAILY_SCHEDULE) {
    return props.placeholders.dailySchedule || [];
  }
  return isEventTarget(form.value.target.type)
    ? props.placeholders.eventRelative || []
    : props.placeholders.text || [];
});
// The starting text that fits the reminder being written, if the AI Brain has one.
const presetText = computed(() => {
  const presets = props.placeholders.presets || {};
  if (form.value.content.kind === CONTENT.DAILY_SCHEDULE) {
    return presets.dailySchedule;
  }
  if (form.value.target.type === TARGET.EVENT_CLIENT) {
    return presets.appointmentClient;
  }
  return form.value.target.type === TARGET.EVENT_PROFESSIONAL
    ? presets.appointmentStaff
    : '';
});

const loadTemplates = async inboxId => {
  templates.value = [];
  if (!inboxId || !isWhatsApp.value) return;
  try {
    templates.value = (await inboxesAPI.getTemplates(inboxId)).data;
  } catch (error) {
    templates.value = [];
  }
};
watch(() => form.value.channel.inboxId, loadTemplates);
// The day's schedule is offered only where it fits; a reminder that no longer fits goes back to text.
watch(kindOptions, options => {
  if (!options.some(option => option.value === form.value.content.kind)) {
    form.value.content.kind = CONTENT.TEXT;
  }
});

const selectTemplate = value => {
  const [name, language] = value ? value.split('|') : [];
  const template = templates.value.find(
    item => item.name === name && item.language === language
  );
  form.value.channel.template = template
    ? {
        name: template.name,
        language: template.language,
        category: template.category,
        bodyParameters: Array.from(
          { length: template.parameterCount },
          (_, index) =>
            form.value.channel.template?.bodyParameters?.[index] || ''
        ),
      }
    : null;
};
const insertPlaceholder = name => {
  const { text } = form.value.content;
  form.value.content.text = `${text}${text && !text.endsWith(' ') ? ' ' : ''}{{${name}}}`;
};

const open = reminder => {
  form.value = reminder ? toReminderForm(reminder) : newReminderForm();
  errors.value = {};
  loadTemplates(form.value.channel.inboxId);
  dialogRef.value?.open();
};
const save = async () => {
  saving.value = true;
  errors.value = {};
  try {
    const body = fromReminderForm(form.value);
    const { data } = form.value.id
      ? await remindersAPI.update(form.value.id, body)
      : await remindersAPI.create(body);
    emit('saved', data);
    dialogRef.value?.close();
  } catch (error) {
    errors.value = error?.response?.data?.errors || {};
    useAlert(t('AI_BRAIN.ERROR'));
  } finally {
    saving.value = false;
  }
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="
      form.id ? t('AI_BRAIN.REMINDERS.EDIT') : t('AI_BRAIN.REMINDERS.NEW')
    "
    :confirm-button-label="t('AI_BRAIN.SAVE')"
    :cancel-button-label="t('AI_BRAIN.CANCEL')"
    :is-loading="saving"
    width="3xl"
    overflow-y-auto
    @confirm="save"
  >
    <div class="flex flex-col gap-6">
      <WithLabel name="reminder-name" :label="t('AI_BRAIN.REMINDERS.NAME')">
        <NextInput v-model="form.name" class="w-full" />
      </WithLabel>

      <section class="flex flex-col gap-2">
        <TargetPicker v-model="form.target" :users="users" :teams="teams" />
        <p v-if="errors.target" class="text-sm text-n-ruby-11">
          {{ errors.target.join(' ') }}
        </p>
      </section>

      <section class="flex flex-col gap-2">
        <SchedulePicker
          v-model="form.schedule"
          :event-target="isEventTarget(form.target.type)"
          :calendars="calendars"
        />
        <p v-if="errors.schedule" class="text-sm text-n-ruby-11">
          {{ errors.schedule.join(' ') }}
        </p>
      </section>

      <section class="flex flex-col gap-4">
        <WithLabel name="reminder-inbox" :label="t('AI_BRAIN.REMINDERS.INBOX')">
          <Select
            v-model="form.channel.inboxId"
            :options="inboxOptions"
            :placeholder="t('AI_BRAIN.REMINDERS.SELECT')"
            :aria-label="t('AI_BRAIN.REMINDERS.INBOX')"
          />
        </WithLabel>
        <template v-if="isWhatsApp">
          <WithLabel
            name="reminder-template"
            :label="t('AI_BRAIN.REMINDERS.TEMPLATE')"
          >
            <Select
              :model-value="
                form.channel.template
                  ? `${form.channel.template.name}|${form.channel.template.language}`
                  : ''
              "
              :options="templateOptions"
              :aria-label="t('AI_BRAIN.REMINDERS.TEMPLATE')"
              @update:model-value="selectTemplate"
            />
          </WithLabel>
          <p
            v-if="selectedTemplate?.bodyText"
            class="text-sm text-n-slate-11 whitespace-pre-line"
          >
            {{ selectedTemplate.bodyText }}
          </p>
          <WithLabel
            v-for="(_, index) in form.channel.template?.bodyParameters || []"
            :key="index"
            :name="`template-parameter-${index}`"
            :label="
              t('AI_BRAIN.REMINDERS.TEMPLATE_PARAMETER', { number: index + 1 })
            "
          >
            <NextInput
              v-model="form.channel.template.bodyParameters[index]"
              class="w-full"
            />
          </WithLabel>
          <p v-if="needsTemplateWarning" class="text-sm text-n-amber-11">
            {{ t('AI_BRAIN.REMINDERS.TEMPLATE_WARNING') }}
          </p>
        </template>
        <div
          v-if="!staff"
          class="flex items-center justify-between p-3 rounded-lg border border-n-weak bg-n-solid-2"
        >
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('AI_BRAIN.REMINDERS.AI_REPLIES') }}
          </span>
          <Switch v-model="form.channel.aiReplies" />
        </div>
        <p v-else class="text-sm text-n-slate-11">
          {{ t('AI_BRAIN.REMINDERS.STAFF_NOTE') }}
        </p>
        <p v-if="errors.channel" class="text-sm text-n-ruby-11">
          {{ errors.channel.join(' ') }}
        </p>
      </section>

      <section class="flex flex-col gap-4">
        <WithLabel name="reminder-kind" :label="t('AI_BRAIN.REMINDERS.KIND')">
          <Select
            v-model="form.content.kind"
            :options="kindOptions"
            :aria-label="t('AI_BRAIN.REMINDERS.KIND')"
          />
        </WithLabel>
        <WithLabel name="reminder-text" :label="t('AI_BRAIN.REMINDERS.TEXT')">
          <TextArea
            v-model="form.content.text"
            :max-length="1000"
            rows="4"
            class="w-full"
          />
        </WithLabel>
        <div v-if="placeholderNames.length" class="flex flex-wrap gap-2">
          <span class="text-xs text-n-slate-11 self-center">
            {{ t('AI_BRAIN.REMINDERS.PLACEHOLDERS') }}
          </span>
          <Button
            v-for="name in placeholderNames"
            :key="name"
            type="button"
            variant="faded"
            color="slate"
            size="xs"
            :label="`{{${name}}}`"
            @click="insertPlaceholder(name)"
          />
        </div>
        <div v-if="presetText && !form.content.text">
          <Button
            type="button"
            variant="link"
            color="blue"
            size="sm"
            :label="t('AI_BRAIN.REMINDERS.USE_PRESET')"
            @click="form.content.text = presetText"
          />
        </div>
        <WithLabel
          v-if="form.content.kind === CONTENT.DAILY_SCHEDULE"
          name="reminder-empty-text"
          :label="t('AI_BRAIN.REMINDERS.EMPTY_TEXT')"
        >
          <TextArea
            v-model="form.content.emptyText"
            :max-length="1000"
            rows="2"
            class="w-full"
          />
        </WithLabel>
        <p v-if="errors.content" class="text-sm text-n-ruby-11">
          {{ errors.content.join(' ') }}
        </p>
      </section>
    </div>
  </Dialog>
</template>
