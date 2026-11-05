// The schedules the Reminders page offers and how each maps to the AI Brain's structured schedule: once at a moment,
// on days of the week at a time, or relative to each calendar appointment.

export const SCHEDULE_TYPE = { ONCE: 0, RECURRING: 1, EVENT_RELATIVE: 2 };

export const PRESET = {
  ONCE: 'once',
  DAILY: 'daily',
  WEEKDAYS: 'weekdays',
  WEEKLY: 'weekly',
  DAYS_BEFORE: 'daysBefore',
  MINUTES_BEFORE: 'minutesBefore',
  // A schedule the presets cannot show, kept as it is.
  CUSTOM: 'custom',
};

// Presets that send at a time, and presets that follow each appointment.
export const TIME_PRESETS = [
  PRESET.ONCE,
  PRESET.DAILY,
  PRESET.WEEKDAYS,
  PRESET.WEEKLY,
];
export const EVENT_PRESETS = [PRESET.DAYS_BEFORE, PRESET.MINUTES_BEFORE];
export const RECURRING_PRESETS = [PRESET.DAILY, PRESET.WEEKDAYS, PRESET.WEEKLY];

// Days as the backend numbers them, Sunday first.
const EVERY_DAY = [0, 1, 2, 3, 4, 5, 6];
const MONDAY_TO_FRIDAY = [1, 2, 3, 4, 5];

const isUnset = value => value === null || value === undefined;
const pad = value => String(value).padStart(2, '0');
const sortedDays = days =>
  [...new Set(days.map(Number))].sort((left, right) => left - right);
const sameDays = (left, right) =>
  left.length === right.length &&
  left.every((day, index) => day === right[index]);
// The backend writes times of day as HH:mm:ss.
const shortTime = time => (time || '').slice(0, 5);

export const newScheduleForm = (preset = PRESET.DAYS_BEFORE) => ({
  preset,
  date: '',
  time: '09:00',
  days: [...MONDAY_TO_FRIDAY],
  daysBefore: 1,
  minutesBefore: 120,
  calendarIds: [],
  original: null,
});

// A date and time picked on the page are read in the browser's time zone.
export const toSchedule = form => {
  switch (form.preset) {
    case PRESET.ONCE:
      return {
        type: SCHEDULE_TYPE.ONCE,
        at: new Date(`${form.date}T${form.time}:00`).toISOString(),
      };
    case PRESET.DAILY:
      return {
        type: SCHEDULE_TYPE.RECURRING,
        days: [...EVERY_DAY],
        timeOfDay: form.time,
      };
    case PRESET.WEEKDAYS:
      return {
        type: SCHEDULE_TYPE.RECURRING,
        days: [...MONDAY_TO_FRIDAY],
        timeOfDay: form.time,
      };
    case PRESET.WEEKLY:
      return {
        type: SCHEDULE_TYPE.RECURRING,
        days: sortedDays(form.days),
        timeOfDay: form.time,
      };
    case PRESET.DAYS_BEFORE:
      return {
        type: SCHEDULE_TYPE.EVENT_RELATIVE,
        daysBefore: Number(form.daysBefore),
        timeOfDay: form.time,
        calendarIds: [...form.calendarIds],
      };
    case PRESET.MINUTES_BEFORE:
      return {
        type: SCHEDULE_TYPE.EVENT_RELATIVE,
        minutesBefore: Number(form.minutesBefore),
        calendarIds: [...form.calendarIds],
      };
    default:
      return form.original;
  }
};

const recurringPreset = days => {
  if (sameDays(days, EVERY_DAY)) return PRESET.DAILY;
  if (sameDays(days, MONDAY_TO_FRIDAY)) return PRESET.WEEKDAYS;
  return PRESET.WEEKLY;
};

export const fromSchedule = schedule => {
  const form = { ...newScheduleForm(PRESET.CUSTOM), original: schedule };
  if (schedule?.type === SCHEDULE_TYPE.ONCE && schedule.at) {
    const at = new Date(schedule.at);
    return {
      ...form,
      preset: PRESET.ONCE,
      date: `${at.getFullYear()}-${pad(at.getMonth() + 1)}-${pad(at.getDate())}`,
      time: `${pad(at.getHours())}:${pad(at.getMinutes())}`,
    };
  }
  if (schedule?.type === SCHEDULE_TYPE.RECURRING) {
    const days = sortedDays(schedule.days || []);
    return {
      ...form,
      preset: recurringPreset(days),
      days,
      time: shortTime(schedule.timeOfDay) || form.time,
    };
  }
  if (schedule?.type === SCHEDULE_TYPE.EVENT_RELATIVE) {
    const calendarIds = [...(schedule.calendarIds || [])];
    if (!isUnset(schedule.minutesBefore)) {
      return {
        ...form,
        preset: PRESET.MINUTES_BEFORE,
        minutesBefore: schedule.minutesBefore,
        calendarIds,
      };
    }
    return {
      ...form,
      preset: PRESET.DAYS_BEFORE,
      daysBefore: schedule.daysBefore ?? 1,
      time: shortTime(schedule.timeOfDay) || form.time,
      calendarIds,
    };
  }
  return form;
};
