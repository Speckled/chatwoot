// The clinic's working hours as the backend saves them: intervals for each weekday ({ day, intervals }, days numbered
// from 0 for Sunday, a weekday with no entry is closed) and dates with intervals of their own ({ date, intervals }, no
// intervals closes the date). Times are "HH:mm:ss" in the clinic's time zone. These helpers return new objects, so the
// editor can emit them whole.

// Sunday first, as the backend numbers them.
export const DAYS = [0, 1, 2, 3, 4, 5, 6];

const FIRST_INTERVAL = { start: '08:00:00', end: '18:00:00' };
const LAST_MINUTE = '23:59:00';

// <input type="time"> shows and returns "HH:mm".
export const toInputTime = value => (value || '').slice(0, 5);
export const fromInputTime = value => (value ? `${value.slice(0, 5)}:00` : '');

export const dayIntervals = (schedule, day) =>
  schedule.weekly.find(item => item.day === day)?.intervals ?? [];

// No intervals closes the weekday, which the backend saves as no entry.
export const withDayIntervals = (schedule, day, intervals) => ({
  ...schedule,
  weekly: [
    ...schedule.weekly.filter(item => item.day !== day),
    ...(intervals.length ? [{ day, intervals }] : []),
  ].sort((a, b) => a.day - b.day),
});

export const withDateAt = (schedule, index, entry) => ({
  ...schedule,
  dateOverrides: schedule.dateOverrides.map((item, i) =>
    i === index ? entry : item
  ),
});

// A new date starts closed, the usual case (a holiday); the owner can give it intervals.
export const withNewDate = schedule => ({
  ...schedule,
  dateOverrides: [...schedule.dateOverrides, { date: '', intervals: [] }],
});

export const withoutDateAt = (schedule, index) => ({
  ...schedule,
  dateOverrides: schedule.dateOverrides.filter((_, i) => i !== index),
});

const addHour = time => {
  const [hours, minutes] = time.split(':').map(Number);
  const next = hours + 1;
  return next > 23
    ? LAST_MINUTE
    : `${String(next).padStart(2, '0')}:${String(minutes).padStart(2, '0')}:00`;
};

// The interval the Add button appends: the usual day for the first one, else an hour after the last one ends.
export const nextInterval = intervals => {
  if (!intervals.length) return { ...FIRST_INTERVAL };
  const { end } = intervals[intervals.length - 1];
  return { start: end, end: addHour(end) };
};

const byStart = intervals =>
  [...intervals].sort((a, b) => a.start.localeCompare(b.start));

// What the backend saves: each list of intervals in order, the dates in order.
export const forSave = schedule => ({
  ...schedule,
  weekly: schedule.weekly.map(item => ({
    ...item,
    intervals: byStart(item.intervals),
  })),
  dateOverrides: schedule.dateOverrides
    .map(item => ({ ...item, intervals: byStart(item.intervals) }))
    .sort((a, b) => a.date.localeCompare(b.date)),
});

const intervalText = ({ start, end }) =>
  `${toInputTime(start)}–${toInputTime(end)}`;

const intervalsProblem = (intervals, where) => {
  const sorted = byStart(intervals);
  const reversed = sorted.find(
    item => !item.start || !item.end || item.start >= item.end
  );
  if (reversed) {
    return {
      key: 'REVERSED',
      params: { where, interval: intervalText(reversed) },
    };
  }
  const overlap = sorted.findIndex(
    (item, i) => i > 0 && item.start < sorted[i - 1].end
  );
  if (overlap > 0) {
    return {
      key: 'OVERLAP',
      params: {
        where,
        first: intervalText(sorted[overlap - 1]),
        second: intervalText(sorted[overlap]),
      },
    };
  }
  return null;
};

// Why the schedule can't be saved, as a key under AI_BRAIN.WORKING_HOURS_PROBLEM and its parameters; null when it can.
// The backend checks the same, so this only says it before the request. dayName turns a day number into its name.
export const scheduleProblem = (schedule, dayName) => {
  if (!(schedule.defaultSlotDurationMinutes >= 1))
    return { key: 'SLOT', params: {} };
  const days = schedule.weekly
    .map(item => intervalsProblem(item.intervals, dayName(item.day)))
    .find(Boolean);
  if (days) return days;
  const dates = schedule.dateOverrides;
  if (dates.some(item => !item.date))
    return { key: 'DATE_MISSING', params: {} };
  const twice = dates.find(
    (item, i) => dates.findIndex(other => other.date === item.date) !== i
  );
  if (twice) return { key: 'DATE_TWICE', params: { date: twice.date } };
  return (
    dates
      .map(item => intervalsProblem(item.intervals, item.date))
      .find(Boolean) ?? null
  );
};
