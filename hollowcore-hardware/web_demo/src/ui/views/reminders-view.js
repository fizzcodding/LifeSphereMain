import {
  WEEKDAYS,
  addReminder,
  deleteReminder,
  mapReminders,
  updateReminder,
} from '../../api/reminders-service.js';
import { remindersRef } from '../../api/paths.js';
import { el, mount } from '../../lib/dom.js';
import { subscribe } from '../../realtime/subscription.js';
import { emptyState, field, loadingState } from '../components/controls.js';
import { confirmDialog, openDialog } from '../components/dialog.js';
import { icon } from '../components/icon.js';
import { showSuccessToast } from '../components/toast.js';

function reminderDialog({ title, initial, submitLabel, onSave }) {
  const nameField = field({
    label: 'Medicine name',
    name: 'name',
    value: initial?.name ?? '',
    placeholder: 'Metformin 500mg',
  });
  const timeField = field({
    label: 'Time',
    name: 'time',
    type: 'time',
    value: initial?.time ?? '08:00',
  });
  const slotField = field({
    label: 'Dispenser slot',
    name: 'slot',
    value: initial?.slot ?? '',
    placeholder: '1',
  });
  const noteField = field({
    label: 'Note (optional)',
    name: 'note',
    value: initial?.note ?? '',
    placeholder: 'After food',
  });

  const selected = new Set(initial?.days ?? WEEKDAYS);
  const dayPicker = el(
    'div',
    { class: 'daypicker' },
    WEEKDAYS.map((day) => {
      const button = el('button', {
        type: 'button',
        text: day,
        'aria-pressed': String(selected.has(day)),
      });
      button.addEventListener('click', () => {
        if (selected.has(day)) selected.delete(day);
        else selected.add(day);
        button.setAttribute('aria-pressed', String(selected.has(day)));
      });
      return button;
    }),
  );

  openDialog({
    title,
    submitLabel,
    fields: [
      nameField.wrapper,
      el('div', { class: 'form-grid' }, [timeField.wrapper, slotField.wrapper]),
      el('div', { class: 'field' }, [
        el('span', { class: 'field__label', text: 'Repeat on' }),
        dayPicker,
      ]),
      noteField.wrapper,
    ],
    onSubmit: async () => {
      const name = nameField.input.value.trim();
      const time = timeField.input.value.trim();
      const slot = slotField.input.value.trim();
      if (!name) throw new Error('Enter a medicine name.');
      if (!time) throw new Error('Choose a time.');
      if (!slot) throw new Error('Enter the dispenser slot.');
      if (selected.size === 0) throw new Error('Select at least one day.');

      await onSave({
        name,
        time,
        slot,
        days: WEEKDAYS.filter((day) => selected.has(day)),
        note: noteField.input.value.trim(),
      });
    },
  });
}

function reminderCard(reminder, { readonly }) {
  const actions = [];

  if (!readonly) {
    actions.push(
      el('button', {
        class: 'pin__menu-btn',
        type: 'button',
        'aria-label': `Edit ${reminder.name}`,
        title: 'Edit',
        onClick: () =>
          reminderDialog({
            title: 'Edit reminder',
            initial: reminder,
            submitLabel: 'Save changes',
            onSave: async (data) => {
              await updateReminder(reminder.id, data);
              showSuccessToast('Reminder updated.');
            },
          }),
      }),
    );
    actions[0].append(icon('sliders', 16));

    const removeButton = el('button', {
      class: 'pin__menu-btn',
      type: 'button',
      'aria-label': `Delete ${reminder.name}`,
      title: 'Delete',
      onClick: async () => {
        const confirmed = await confirmDialog({
          title: 'Delete reminder',
          message: `Remove the reminder for "${reminder.name}"?`,
        });
        if (!confirmed) return;
        await deleteReminder(reminder.id);
        showSuccessToast('Reminder deleted.');
      },
    });
    removeButton.append(icon('trash', 16));
    actions.push(removeButton);
  }

  return el('article', { class: 'panel reminder' }, [
    el('div', { class: 'reminder__icon' }, [icon('pill', 20)]),
    el('div', { class: 'reminder__body' }, [
      el('div', { class: 'reminder__name', text: reminder.name }),
      el('div', { class: 'reminder__pills' }, [
        el('span', { class: 'pill' }, [icon('clock', 13), el('span', { text: reminder.time })]),
        el('span', { class: 'pill' }, [
          icon('box', 13),
          el('span', { text: `Slot ${reminder.slot}` }),
        ]),
        el('span', { class: 'pill' }, [
          icon('calendar', 13),
          el('span', {
            text: reminder.days.length === 7 ? 'Every day' : reminder.days.join(', '),
          }),
        ]),
      ]),
      reminder.note && el('p', { class: 'reminder__note', text: reminder.note }),
    ]),
    el('div', { class: 'pin__actions' }, actions),
  ]);
}

export function remindersView({ subscriptions, readonly = false }) {
  const list = el('div', { class: 'list' }, [loadingState('Loading reminders…')]);

  const addButton = el(
    'button',
    {
      class: 'btn btn--sm',
      type: 'button',
      onClick: () =>
        reminderDialog({
          title: 'Add reminder',
          submitLabel: 'Add reminder',
          onSave: async (data) => {
            await addReminder(data);
            showSuccessToast('Reminder added.');
          },
        }),
    },
    [icon('plus', 15), el('span', { text: 'Add reminder' })],
  );

  subscriptions.add(
    subscribe(
      remindersRef(),
      (value) => {
        const reminders = mapReminders(value).sort((a, b) => a.time.localeCompare(b.time));
        if (reminders.length === 0) {
          mount(list, [
            emptyState({
              iconName: 'pill',
              title: 'No reminders found',
              description: 'Medicine schedules added here sync to the dispenser and the mobile app.',
            }),
          ]);
          return;
        }
        mount(
          list,
          reminders.map((reminder) => reminderCard(reminder, { readonly })),
        );
      },
      () => mount(list, [emptyState({ iconName: 'pill', title: 'Could not load reminders' })]),
    ),
  );

  return el('section', { class: 'view' }, [
    el('header', { class: 'view__head' }, [
      el('div', {}, [
        el('h1', { text: 'Reminders' }),
        el('p', { text: 'Medication schedule shared with the HollowRover dispenser.' }),
      ]),
      !readonly && el('div', { class: 'view__head-actions' }, [addButton]),
    ]),
    list,
  ]);
}
