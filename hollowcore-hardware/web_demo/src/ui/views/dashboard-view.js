import { addPin, deletePin, togglePinState, updatePin } from '../../api/pins-service.js';
import { formatRelative } from '../../lib/format.js';
import { el, mount } from '../../lib/dom.js';
import { observePinChanges } from '../../realtime/pin-listener.js';
import { emptyState, loadingState } from '../components/controls.js';
import { confirmDialog, openDialog } from '../components/dialog.js';
import { field } from '../components/controls.js';
import { icon } from '../components/icon.js';
import { pinTile } from '../components/pin-tile.js';
import { showErrorToast, showSuccessToast } from '../components/toast.js';

function statCard({ label, value, foot, tone = '' }) {
  return el('div', { class: 'panel stat' }, [
    el('div', { class: 'stat__top' }, [el('span', { class: 'stat__label', text: label })]),
    el('div', { class: tone ? `stat__value stat__value--${tone}` : 'stat__value', text: value }),
    foot && el('div', { class: 'stat__foot', text: foot }),
  ]);
}

function pinFormDialog({ title, initial, submitLabel, onSave }) {
  const labelField = field({
    label: 'Device label',
    name: 'label',
    value: initial?.label ?? '',
    placeholder: 'Living room light',
  });
  const pinField = field({
    label: 'GPIO pin number',
    name: 'pin',
    type: 'number',
    value: initial != null ? String(initial.pin) : '',
    placeholder: '26',
  });

  openDialog({
    title,
    submitLabel,
    fields: [labelField.wrapper, pinField.wrapper],
    onSubmit: async () => {
      const label = labelField.input.value.trim();
      const pin = Number.parseInt(pinField.input.value.trim(), 10);
      if (!label) throw new Error('Enter a device label.');
      if (!Number.isInteger(pin) || pin < 0 || pin > 39) {
        throw new Error('Enter a valid ESP32 GPIO number between 0 and 39.');
      }
      await onSave({ label, pin });
    },
  });
}

export function dashboardView({ subscriptions }) {
  let lastChangeAt = null;

  const list = el('div', { class: 'pins' }, [loadingState('Connecting to Realtime Database…')]);
  const stats = el('div', { class: 'grid grid--stats' });

  const addButton = el(
    'button',
    {
      class: 'btn btn--sm',
      type: 'button',
      onClick: () =>
        pinFormDialog({
          title: 'Add virtual pin',
          submitLabel: 'Add device',
          onSave: async ({ label, pin }) => {
            await addPin(label, pin);
            showSuccessToast('Device added.');
          },
        }),
    },
    [icon('plus', 15), el('span', { text: 'Add device' })],
  );

  function render(pins) {
    const active = pins.filter((pin) => pin.state).length;

    mount(stats, [
      statCard({ label: 'Devices', value: String(pins.length), foot: 'Registered virtual pins' }),
      statCard({
        label: 'Active now',
        value: String(active),
        foot: active === 0 ? 'All outputs low' : `${active} relay${active > 1 ? 's' : ''} energised`,
        tone: active > 0 ? 'accent' : '',
      }),
      statCard({
        label: 'Last change',
        value: lastChangeAt ? formatRelative(lastChangeAt) : '—',
        foot: lastChangeAt ? 'Observed by this session' : 'No change seen yet',
      }),
    ]);

    if (pins.length === 0) {
      mount(list, [
        emptyState({
          iconName: 'chip',
          title: 'No devices yet',
          description: 'Add a virtual pin to control your first relay output.',
        }),
      ]);
      return;
    }

    mount(
      list,
      pins.map((pin) =>
        pinTile(pin, {
          onToggle: async (next) => {
            try {
              await togglePinState(pin.id, next);
            } catch (_) {
              showErrorToast('Could not reach the device. Check your connection.');
            }
          },
          onEdit: () =>
            pinFormDialog({
              title: 'Edit device',
              initial: pin,
              submitLabel: 'Save changes',
              onSave: async ({ label, pin: gpio }) => {
                await updatePin(pin.id, { label, pin: gpio });
                showSuccessToast('Device updated.');
              },
            }),
          onDelete: async () => {
            const confirmed = await confirmDialog({
              title: 'Delete device',
              message: `Remove "${pin.label}" from your dashboard? This does not change the relay's current state.`,
            });
            if (!confirmed) return;
            await deletePin(pin.id);
            showSuccessToast('Device deleted.');
          },
        }),
      ),
    );
  }

  subscriptions.add(
    observePinChanges({
      onSnapshot: (pins) => render(pins),
      onChanges: () => {
        lastChangeAt = new Date();
      },
      onError: () => {
        mount(list, [
          emptyState({
            iconName: 'shield',
            title: 'Cannot read devices',
            description:
              'The Realtime Database rejected this read. Verify your database rules allow the signed-in user to read users/$uid.',
          }),
        ]);
      },
    }),
  );

  return el('section', { class: 'view' }, [
    el('header', { class: 'view__head' }, [
      el('div', {}, [
        el('h1', { text: 'Devices' }),
        el('p', { text: 'Virtual pins mapped to HollowCore relay outputs.' }),
      ]),
      el('div', { class: 'view__head-actions' }, [addButton]),
    ]),
    stats,
    list,
  ]);
}
