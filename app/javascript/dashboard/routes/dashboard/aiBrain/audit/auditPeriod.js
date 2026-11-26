// The audit page's period: days picked in the administrator's own time zone, sent to the AI Brain as instants. The end day
// is included, so the period ends at the start of the day after it.
export const DEFAULT_DAYS = 30;

const pad = number => String(number).padStart(2, '0');

// A Date as the YYYY-MM-DD a date field holds, in local time.
export const toDay = date =>
  `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;

const startOfDay = day => {
  const [year, month, date] = day.split('-').map(Number);
  return new Date(year, month - 1, date);
};

// The last 30 days, today included.
export const defaultPeriod = (today = new Date()) => {
  const from = new Date(today.getFullYear(), today.getMonth(), today.getDate());
  from.setDate(from.getDate() - DEFAULT_DAYS);
  return { from: toDay(from), to: toDay(today) };
};

// The query for the AI Brain: from the start of the first day to the start of the day after the last. A day left empty
// leaves that side open.
export const toPeriodQuery = ({ from, to }) => {
  const query = {};
  if (from) query.from = startOfDay(from).toISOString();
  if (to) {
    const end = startOfDay(to);
    end.setDate(end.getDate() + 1);
    query.to = end.toISOString();
  }
  return query;
};
