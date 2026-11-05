// Converts a reminder between the AI Brain's shape and the Reminders page's form.
import {
  PRESET,
  RECURRING_PRESETS,
  fromSchedule,
  newScheduleForm,
  toSchedule,
} from './schedulePresets';

export const TARGET = {
  CLIENT: 0,
  USER: 1,
  TEAM: 2,
  EVENT_CLIENT: 3,
  EVENT_PROFESSIONAL: 4,
};
export const CONTENT = { TEXT: 0, DAILY_SCHEDULE: 1 };
export const DELIVERY_STATUS = {
  PENDING: 0,
  SENDING: 1,
  SENT: 2,
  FAILED: 3,
  SKIPPED: 4,
};

// Event targets come from each calendar appointment: its client, or the professional whose calendar it is in.
export const isEventTarget = type =>
  type === TARGET.EVENT_CLIENT || type === TARGET.EVENT_PROFESSIONAL;

// Conversations with staff are visible to administrators only, and the AI never answers them.
export const isStaffTarget = type =>
  [TARGET.USER, TARGET.TEAM, TARGET.EVENT_PROFESSIONAL].includes(type);

// The day's schedule goes to staff with a calendar, on days of the week.
export const canSendDailySchedule = (targetType, preset) =>
  [TARGET.USER, TARGET.TEAM].includes(targetType) &&
  RECURRING_PRESETS.includes(preset);

export const newReminderForm = () => ({
  id: null,
  name: '',
  isEnabled: true,
  target: {
    type: TARGET.EVENT_CLIENT,
    chatwootContactId: null,
    phoneNumber: '',
    name: '',
    userId: '',
    teamId: '',
  },
  channel: { inboxId: '', aiReplies: true, template: null },
  schedule: newScheduleForm(PRESET.DAYS_BEFORE),
  content: { kind: CONTENT.TEXT, text: '', emptyText: '' },
});

const templateForm = template =>
  template
    ? {
        name: template.name,
        language: template.language,
        category: template.category || null,
        bodyParameters: [...(template.bodyParameters || [])],
      }
    : null;

export const toReminderForm = reminder => {
  const blank = newReminderForm();
  const target = reminder.target || {};
  return {
    id: reminder.id,
    name: reminder.name || '',
    isEnabled: reminder.isEnabled !== false,
    target: {
      type: target.type ?? blank.target.type,
      chatwootContactId: target.chatwootContactId ?? null,
      phoneNumber: target.phoneNumber || '',
      name: target.name || '',
      userId: target.userId || '',
      teamId: target.teamId ?? '',
    },
    channel: {
      inboxId: reminder.channel?.inboxId ?? '',
      aiReplies: reminder.channel?.aiReplies !== false,
      template: templateForm(reminder.channel?.template),
    },
    schedule: fromSchedule(reminder.schedule),
    content: {
      kind: reminder.content?.kind ?? CONTENT.TEXT,
      text: reminder.content?.text || '',
      emptyText: reminder.content?.emptyText || '',
    },
  };
};

const targetFrom = target => {
  if (target.type === TARGET.CLIENT) {
    return {
      type: target.type,
      chatwootContactId: target.chatwootContactId || null,
      phoneNumber: target.phoneNumber.trim() || null,
      name: target.name.trim() || null,
    };
  }
  if (target.type === TARGET.USER) {
    return { type: target.type, userId: target.userId };
  }
  if (target.type === TARGET.TEAM) {
    return { type: target.type, teamId: Number(target.teamId) };
  }
  return { type: target.type };
};

// Sends only what applies to the chosen target, schedule and content.
export const fromReminderForm = form => {
  const { template } = form.channel;
  const dailySchedule = form.content.kind === CONTENT.DAILY_SCHEDULE;
  return {
    name: form.name.trim(),
    isEnabled: form.isEnabled,
    target: targetFrom(form.target),
    channel: {
      inboxId: Number(form.channel.inboxId),
      aiReplies: !isStaffTarget(form.target.type) && form.channel.aiReplies,
      template: template?.name ? templateForm(template) : null,
    },
    schedule: toSchedule(form.schedule),
    content: {
      kind: form.content.kind,
      text: form.content.text.trim(),
      emptyText: dailySchedule ? form.content.emptyText.trim() || null : null,
    },
  };
};
