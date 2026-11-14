import {
  dayIntervals,
  forSave,
  fromInputTime,
  nextInterval,
  scheduleProblem,
  toInputTime,
  withDateAt,
  withDayIntervals,
  withNewDate,
  withoutDateAt,
} from '../workingHours';

const morning = { start: '08:00:00', end: '12:00:00' };
const afternoon = { start: '14:00:00', end: '18:00:00' };
const dayName = day => `day ${day}`;

// What a clinic whose hours were never set, or were cleared, reads back.
const defaultSchedule = () => ({
  defaultSlotDurationMinutes: 60,
  weekly: [1, 2, 3, 4, 5].map(day => ({
    day,
    intervals: [{ start: '08:00:00', end: '18:00:00' }],
  })),
  dateOverrides: [],
});

describe('working hours', () => {
  it('converts times to and from the time input', () => {
    expect(toInputTime('08:30:00')).toBe('08:30');
    expect(fromInputTime('08:30')).toBe('08:30:00');
    expect(fromInputTime('')).toBe('');
  });

  it('gives a weekday its intervals, and closes it with none', () => {
    const split = withDayIntervals(defaultSchedule(), 1, [morning, afternoon]);
    expect(dayIntervals(split, 1)).toEqual([morning, afternoon]);
    expect(dayIntervals(split, 2)).toEqual([
      { start: '08:00:00', end: '18:00:00' },
    ]);

    const closed = withDayIntervals(split, 1, []);
    expect(closed.weekly.map(item => item.day)).toEqual([2, 3, 4, 5]);

    const saturday = withDayIntervals(closed, 6, [morning]);
    expect(saturday.weekly.map(item => item.day)).toEqual([2, 3, 4, 5, 6]);
  });

  it('adds a closed date, gives it hours and removes it', () => {
    const added = withNewDate(defaultSchedule());
    expect(added.dateOverrides).toEqual([{ date: '', intervals: [] }]);

    const holiday = withDateAt(added, 0, {
      date: '2030-12-26',
      intervals: [{ start: '09:00:00', end: '13:00:00' }],
    });
    expect(holiday.dateOverrides[0].date).toBe('2030-12-26');
    expect(withoutDateAt(holiday, 0).dateOverrides).toEqual([]);
  });

  it('suggests the next interval after the last one', () => {
    expect(nextInterval([])).toEqual({ start: '08:00:00', end: '18:00:00' });
    expect(nextInterval([morning])).toEqual({
      start: '12:00:00',
      end: '13:00:00',
    });
    expect(nextInterval([{ start: '20:00:00', end: '23:30:00' }])).toEqual({
      start: '23:30:00',
      end: '23:59:00',
    });
  });

  it('saves intervals and dates in order', () => {
    const schedule = {
      ...defaultSchedule(),
      weekly: [{ day: 1, intervals: [afternoon, morning] }],
      dateOverrides: [
        { date: '2030-12-26', intervals: [] },
        { date: '2030-12-25', intervals: [afternoon, morning] },
      ],
    };

    const saved = forSave(schedule);

    expect(saved.weekly[0].intervals).toEqual([morning, afternoon]);
    expect(saved.dateOverrides.map(item => item.date)).toEqual([
      '2030-12-25',
      '2030-12-26',
    ]);
    expect(saved.dateOverrides[0].intervals).toEqual([morning, afternoon]);
  });

  describe('problems', () => {
    const withWeekly = intervals => ({
      ...defaultSchedule(),
      weekly: [{ day: 1, intervals }],
    });

    it('accepts the default schedule and intervals out of order', () => {
      expect(scheduleProblem(defaultSchedule(), dayName)).toBeNull();
      expect(
        scheduleProblem(withWeekly([afternoon, morning]), dayName)
      ).toBeNull();
    });

    it('refuses an interval that does not start before it ends', () => {
      const reversed = { start: '12:00:00', end: '08:00:00' };
      expect(scheduleProblem(withWeekly([reversed]), dayName)).toEqual({
        key: 'REVERSED',
        params: { where: 'day 1', interval: '12:00–08:00' },
      });
      expect(
        scheduleProblem(withWeekly([{ start: '', end: '12:00:00' }]), dayName)
          ?.key
      ).toBe('REVERSED');
    });

    it('refuses overlapping intervals', () => {
      const late = { start: '11:00:00', end: '15:00:00' };
      expect(scheduleProblem(withWeekly([late, morning]), dayName)).toEqual({
        key: 'OVERLAP',
        params: { where: 'day 1', first: '08:00–12:00', second: '11:00–15:00' },
      });
    });

    it('refuses a date left empty or listed twice', () => {
      const dates = dateOverrides => ({ ...defaultSchedule(), dateOverrides });
      expect(
        scheduleProblem(dates([{ date: '', intervals: [] }]), dayName)?.key
      ).toBe('DATE_MISSING');
      expect(
        scheduleProblem(
          dates([
            { date: '2030-12-25', intervals: [] },
            { date: '2030-12-25', intervals: [morning] },
          ]),
          dayName
        )
      ).toEqual({ key: 'DATE_TWICE', params: { date: '2030-12-25' } });
    });

    it('checks the intervals of a date', () => {
      const schedule = {
        ...defaultSchedule(),
        dateOverrides: [
          {
            date: '2030-12-26',
            intervals: [{ start: '13:00:00', end: '09:00:00' }],
          },
        ],
      };
      expect(scheduleProblem(schedule, dayName)?.params.where).toBe(
        '2030-12-26'
      );
    });

    it('refuses an appointment shorter than a minute', () => {
      const schedule = { ...defaultSchedule(), defaultSlotDurationMinutes: 0 };
      expect(scheduleProblem(schedule, dayName)?.key).toBe('SLOT');
    });
  });
});
