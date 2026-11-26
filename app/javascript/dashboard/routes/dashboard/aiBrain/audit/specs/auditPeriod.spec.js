import { defaultPeriod, toDay, toPeriodQuery } from '../auditPeriod';

describe('audit period', () => {
  it('starts at the last 30 days, today included', () => {
    expect(defaultPeriod(new Date(2026, 10, 26, 15, 40))).toEqual({
      from: '2026-10-27',
      to: '2026-11-26',
    });
  });

  it('crosses months and years', () => {
    expect(defaultPeriod(new Date(2026, 0, 10))).toEqual({
      from: '2025-12-11',
      to: '2026-01-10',
    });
  });

  it('sends the start of the first day and the start of the day after the last', () => {
    expect(toPeriodQuery({ from: '2026-11-01', to: '2026-11-30' })).toEqual({
      from: new Date(2026, 10, 1).toISOString(),
      to: new Date(2026, 11, 1).toISOString(),
    });
  });

  it('leaves an empty day open', () => {
    expect(toPeriodQuery({ from: '', to: '2026-12-31' })).toEqual({
      to: new Date(2027, 0, 1).toISOString(),
    });
    expect(toPeriodQuery({ from: '2026-11-01', to: '' })).toEqual({
      from: new Date(2026, 10, 1).toISOString(),
    });
  });

  it('formats a day in local time', () => {
    expect(toDay(new Date(2026, 1, 3, 23, 59))).toBe('2026-02-03');
  });
});
