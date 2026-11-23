import { mount } from '@vue/test-utils';
import WorkingHoursEditor from '../WorkingHoursEditor.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => (params ? `${key} ${JSON.stringify(params)}` : key),
  }),
}));

// What a clinic whose hours were never set, or were cleared, reads back.
const defaultSchedule = () => ({
  defaultSlotDurationMinutes: 60,
  weekly: [1, 2, 3, 4, 5].map(day => ({
    day,
    intervals: [{ start: '08:00:00', end: '18:00:00' }],
  })),
  dateOverrides: [],
});

const mountEditor = modelValue =>
  mount(WorkingHoursEditor, {
    props: { modelValue },
    global: { stubs: { WithLabel: { template: '<div><slot /></div>' } } },
  });

const lastSchedule = wrapper => wrapper.emitted('update:modelValue').at(-1)[0];

describe('WorkingHoursEditor', () => {
  it('shows the default week: weekdays open, the weekend closed', () => {
    const wrapper = mountEditor(defaultSchedule());
    const days = wrapper.findAll('[data-test="weekday"]');

    expect(days).toHaveLength(7);
    expect(days[0].find('[data-test="closed"]').exists()).toBe(true);
    expect(days[1].findAll('[data-test="interval"]')).toHaveLength(1);
    expect(
      days[1].findAll('input[type="time"]').map(input => input.element.value)
    ).toEqual(['08:00', '18:00']);
    expect(days[6].find('[data-test="closed"]').exists()).toBe(true);
    expect(wrapper.find('[data-test="problem"]').exists()).toBe(false);
  });

  it('splits a day into two intervals', async () => {
    const wrapper = mountEditor(defaultSchedule());
    const monday = wrapper.findAll('[data-test="weekday"]')[1];

    await monday.findAll('input[type="time"]')[1].setValue('12:00');
    let schedule = lastSchedule(wrapper);
    expect(schedule.weekly[0].intervals).toEqual([
      { start: '08:00:00', end: '12:00:00' },
    ]);

    await wrapper.setProps({ modelValue: schedule });
    await wrapper
      .findAll('[data-test="weekday"]')[1]
      .find('[data-test="add-interval"]')
      .trigger('click');
    schedule = lastSchedule(wrapper);
    expect(schedule.weekly[0].intervals).toEqual([
      { start: '08:00:00', end: '12:00:00' },
      { start: '12:00:00', end: '13:00:00' },
    ]);
  });

  it('opens a closed day', async () => {
    const wrapper = mountEditor(defaultSchedule());

    await wrapper
      .findAll('[data-test="weekday"]')[6]
      .find('[data-test="add-interval"]')
      .trigger('click');

    expect(lastSchedule(wrapper).weekly.at(-1)).toEqual({
      day: 6,
      intervals: [{ start: '08:00:00', end: '18:00:00' }],
    });
  });

  it('adds a date with its own hours, closed until given intervals', async () => {
    const wrapper = mountEditor(defaultSchedule());

    await wrapper.find('[data-test="add-date"]').trigger('click');
    const added = lastSchedule(wrapper);
    expect(added.dateOverrides).toEqual([{ date: '', intervals: [] }]);

    await wrapper.setProps({ modelValue: added });
    const date = wrapper.find('[data-test="date"]');
    expect(date.find('[data-test="closed"]').exists()).toBe(true);
    expect(wrapper.find('[data-test="problem"]').text()).toContain(
      'AI_BRAIN.WORKING_HOURS_PROBLEM.DATE_MISSING'
    );

    await date.find('input[type="date"]').setValue('2030-12-25');
    expect(lastSchedule(wrapper).dateOverrides).toEqual([
      { date: '2030-12-25', intervals: [] },
    ]);
  });

  it('says why overlapping intervals cannot be saved', () => {
    const wrapper = mountEditor({
      ...defaultSchedule(),
      weekly: [
        {
          day: 1,
          intervals: [
            { start: '08:00:00', end: '12:00:00' },
            { start: '11:00:00', end: '15:00:00' },
          ],
        },
      ],
    });

    expect(wrapper.find('[data-test="problem"]').text()).toContain(
      'AI_BRAIN.WORKING_HOURS_PROBLEM.OVERLAP'
    );
  });
});
