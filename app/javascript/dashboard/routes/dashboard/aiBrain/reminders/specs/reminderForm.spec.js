import {
  PRESET,
  SCHEDULE_TYPE,
  fromSchedule,
  newScheduleForm,
  toSchedule,
} from '../schedulePresets';
import {
  CONTENT,
  TARGET,
  canSendDailySchedule,
  fromReminderForm,
  newReminderForm,
  toReminderForm,
} from '../reminderForm';

describe('schedule presets', () => {
  const forms = {
    [PRESET.ONCE]: { date: '2026-11-06', time: '18:00' },
    [PRESET.DAILY]: { time: '07:00' },
    [PRESET.WEEKDAYS]: { time: '07:30' },
    [PRESET.WEEKLY]: { days: [6, 2, 2], time: '08:00' },
    [PRESET.DAYS_BEFORE]: { daysBefore: 1, time: '18:00', calendarIds: ['c1'] },
    [PRESET.MINUTES_BEFORE]: { minutesBefore: 90, calendarIds: [] },
  };

  it.each(Object.entries(forms))('round-trips %s', (preset, fields) => {
    const form = { ...newScheduleForm(preset), ...fields };

    const back = fromSchedule(toSchedule(form));

    expect(back.preset).toBe(preset);
    expect(toSchedule(back)).toEqual(toSchedule(form));
  });

  it('builds the schedules the AI Brain stores', () => {
    expect(
      toSchedule({ ...newScheduleForm(PRESET.ONCE), ...forms.once })
    ).toEqual({
      type: SCHEDULE_TYPE.ONCE,
      at: '2026-11-06T18:00:00.000Z',
    });
    expect(
      toSchedule({ ...newScheduleForm(PRESET.WEEKLY), ...forms.weekly })
    ).toEqual({
      type: SCHEDULE_TYPE.RECURRING,
      days: [2, 6],
      timeOfDay: '08:00',
    });
    expect(
      toSchedule({
        ...newScheduleForm(PRESET.DAYS_BEFORE),
        ...forms.daysBefore,
      })
    ).toEqual({
      type: SCHEDULE_TYPE.EVENT_RELATIVE,
      daysBefore: 1,
      timeOfDay: '18:00',
      calendarIds: ['c1'],
    });
  });

  it('names a stored day set by its preset and reads HH:mm:ss times', () => {
    const daily = {
      type: SCHEDULE_TYPE.RECURRING,
      days: [6, 5, 4, 3, 2, 1, 0],
      timeOfDay: '07:00:00',
    };
    const weekdays = {
      type: SCHEDULE_TYPE.RECURRING,
      days: [1, 2, 3, 4, 5],
      timeOfDay: '07:00:00',
    };

    expect(fromSchedule(daily)).toMatchObject({
      preset: PRESET.DAILY,
      time: '07:00',
    });
    expect(fromSchedule(weekdays).preset).toBe(PRESET.WEEKDAYS);
  });

  it('keeps a schedule it cannot show as it is', () => {
    const unknown = { type: 9, cron: '0 7 * * *' };

    const form = fromSchedule(unknown);

    expect(form.preset).toBe(PRESET.CUSTOM);
    expect(toSchedule(form)).toBe(unknown);
  });
});

describe('reminder form', () => {
  it('sends only what applies to a client reminder', () => {
    const form = newReminderForm();
    form.name = ' Lembrete ';
    form.target = {
      ...form.target,
      type: TARGET.CLIENT,
      chatwootContactId: 12,
      phoneNumber: '+5511988887777',
      name: 'Maria',
      userId: 'x',
    };
    form.channel = {
      inboxId: '3',
      aiReplies: true,
      template: { name: '', language: 'pt_BR' },
    };
    form.schedule = {
      ...newScheduleForm(PRESET.ONCE),
      date: '2026-11-06',
      time: '18:00',
    };
    form.content = {
      kind: CONTENT.TEXT,
      text: ' Oi {{recipient_first_name}} ',
      emptyText: 'x',
    };

    expect(fromReminderForm(form)).toEqual({
      name: 'Lembrete',
      isEnabled: true,
      target: {
        type: TARGET.CLIENT,
        chatwootContactId: 12,
        phoneNumber: '+5511988887777',
        name: 'Maria',
      },
      channel: { inboxId: 3, aiReplies: true, template: null },
      schedule: { type: SCHEDULE_TYPE.ONCE, at: '2026-11-06T18:00:00.000Z' },
      content: {
        kind: CONTENT.TEXT,
        text: 'Oi {{recipient_first_name}}',
        emptyText: null,
      },
    });
  });

  it('never asks the AI to answer staff and keeps the template parameters in order', () => {
    const reminder = {
      id: 'r1',
      name: 'Agenda do dia',
      isEnabled: false,
      target: { type: TARGET.TEAM, teamId: 7 },
      channel: {
        inboxId: 3,
        aiReplies: true,
        template: {
          name: 'agenda',
          language: 'pt_BR',
          category: 'UTILITY',
          bodyParameters: ['{{recipient_first_name}}', '{{schedule}}'],
        },
      },
      schedule: {
        type: SCHEDULE_TYPE.RECURRING,
        days: [1, 2, 3, 4, 5],
        timeOfDay: '07:00:00',
      },
      content: {
        kind: CONTENT.DAILY_SCHEDULE,
        text: 'Bom dia!',
        emptyText: 'Nada hoje.',
      },
    };

    const sent = fromReminderForm(toReminderForm(reminder));

    expect(sent.target).toEqual({ type: TARGET.TEAM, teamId: 7 });
    expect(sent.channel).toEqual({ ...reminder.channel, aiReplies: false });
    expect(sent.schedule).toEqual({ ...reminder.schedule, timeOfDay: '07:00' });
    expect(sent.content).toEqual(reminder.content);
    expect(sent.isEnabled).toBe(false);
  });

  it('offers the day schedule only to staff on days of the week', () => {
    expect(canSendDailySchedule(TARGET.USER, PRESET.WEEKDAYS)).toBe(true);
    expect(canSendDailySchedule(TARGET.TEAM, PRESET.DAILY)).toBe(true);
    expect(canSendDailySchedule(TARGET.CLIENT, PRESET.DAILY)).toBe(false);
    expect(canSendDailySchedule(TARGET.USER, PRESET.ONCE)).toBe(false);
  });
});
