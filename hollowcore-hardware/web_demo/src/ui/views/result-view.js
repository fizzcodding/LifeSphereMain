import { mapVitals } from '../../api/vitals-service.js';
import { vitalsRef } from '../../api/paths.js';
import { el, mount } from '../../lib/dom.js';
import { formatClock, formatRelative } from '../../lib/format.js';
import { observePinChanges } from '../../realtime/pin-listener.js';
import { subscribe } from '../../realtime/subscription.js';
import { emptyState, loadingState, statusDot } from '../components/controls.js';
import { icon } from '../components/icon.js';
import { pinTile } from '../components/pin-tile.js';

const MAX_EVENTS = 60;

function describeChange(change) {
  const label = change.pin.label || 'Unnamed device';
  switch (change.type) {
    case 'state':
      return {
        title: label,
        detail: `GPIO ${change.pin.pin} switched ${change.to ? 'on' : 'off'}`,
        state: change.to ? 'on' : 'off',
      };
    case 'added':
      return { title: label, detail: `Device registered on GPIO ${change.pin.pin}`, state: null };
    case 'removed':
      return { title: label, detail: 'Device removed from dashboard', state: null };
    case 'label':
      return { title: change.to, detail: `Renamed from "${change.from}"`, state: null };
    case 'gpio':
      return { title: label, detail: `Remapped GPIO ${change.from} to ${change.to}`, state: null };
    default:
      return { title: label, detail: 'Updated', state: null };
  }
}

function eventRow(change, at) {
  const described = describeChange(change);
  return el('div', { class: 'event' }, [
    el('span', { class: 'event__time', text: formatClock(at) }),
    el('div', { class: 'event__body' }, [
      el('div', { class: 'event__title', text: described.title }),
      el('div', { class: 'event__detail', text: described.detail }),
    ]),
    described.state &&
      el('span', {
        class: `event__state event__state--${described.state}`,
        text: described.state,
      }),
  ]);
}

export function resultView({ subscriptions }) {
  let eventCount = 0;
  let lastEventAt = null;
  const recentlyChanged = new Set();

  const counter = el('b', { text: '0' });
  const lastSeen = el('p', {
    text: 'Waiting for the first change from the SphereCore mobile app…',
  });
  const pinList = el('div', { class: 'pins' }, [loadingState('Attaching realtime listener…')]);
  const eventList = el('div', { class: 'eventlog__list' }, [
    el('div', {
      class: 'eventlog__empty',
      text: 'No changes observed yet. Toggle a device in the mobile app to see it land here.',
    }),
  ]);
  const vitalStrip = el('dl', { class: 'panel vitalstrip' });

  function renderPins(pins) {
    if (pins.length === 0) {
      mount(pinList, [
        emptyState({
          iconName: 'chip',
          title: 'No devices registered',
          description: 'Add a virtual pin in App Mode or the mobile app to watch it here.',
        }),
      ]);
      return;
    }

    mount(
      pinList,
      pins.map((pin) => {
        const tile = pinTile(pin, { readonly: true });
        if (recentlyChanged.has(pin.id)) {
          tile.classList.add('flash');
          tile.querySelector('.pin__body').append(
            el('span', { class: 'pin__badge', text: 'updated' }),
          );
        }
        return tile;
      }),
    );
  }

  function pushEvents(changes) {
    const at = new Date();
    eventCount += changes.length;
    lastEventAt = at;
    counter.textContent = String(eventCount);
    lastSeen.textContent = `Last change ${formatRelative(at)} at ${formatClock(at)}.`;

    if (eventList.querySelector('.eventlog__empty')) mount(eventList, []);

    changes.forEach((change) => {
      eventList.prepend(eventRow(change, at));
      recentlyChanged.add(change.pin.id);
      setTimeout(() => recentlyChanged.delete(change.pin.id), 1200);
    });

    while (eventList.childElementCount > MAX_EVENTS) {
      eventList.lastElementChild.remove();
    }
  }

  subscriptions.add(
    observePinChanges({
      onSnapshot: (pins) => renderPins(pins),
      onChanges: (changes) => {
        pushEvents(changes);
      },
      onError: () =>
        mount(pinList, [
          emptyState({
            iconName: 'shield',
            title: 'Listener rejected',
            description: 'The Realtime Database denied this subscription. Check your database rules.',
          }),
        ]),
    }),
  );

  subscriptions.add(
    subscribe(
      vitalsRef(),
      (value) => {
        const vitals = mapVitals(value);
        mount(vitalStrip, [
          el('div', { class: 'vitalstrip__cell' }, [
            el('dt', { text: 'Heart rate' }),
            el('dd', { text: `${vitals.hr}` }),
          ]),
          el('div', { class: 'vitalstrip__cell' }, [
            el('dt', { text: 'SpO2' }),
            el('dd', { text: `${vitals.spo2}%` }),
          ]),
          el('div', { class: 'vitalstrip__cell' }, [
            el('dt', { text: 'Temp' }),
            el('dd', { text: vitals.temp.toFixed(1) }),
          ]),
          el('div', { class: 'vitalstrip__cell' }, [
            el('dt', { text: 'Steps' }),
            el('dd', { text: `${vitals.steps}` }),
          ]),
          el('div', { class: 'vitalstrip__cell' }, [
            el('dt', { text: 'Hydration' }),
            el('dd', { text: `${vitals.hydration}` }),
          ]),
        ]);
      },
      () => mount(vitalStrip, []),
    ),
  );

  const ticker = setInterval(() => {
    if (lastEventAt) {
      lastSeen.textContent = `Last change ${formatRelative(lastEventAt)} at ${formatClock(lastEventAt)}.`;
    }
  }, 5000);

  subscriptions.add(() => clearInterval(ticker));

  return el('section', { class: 'view result' }, [
    el('header', { class: 'view__head' }, [
      el('div', {}, [
        el('h1', { text: 'Live results' }),
        el('p', { text: 'Read-only mirror of device state as it changes upstream.' }),
      ]),
    ]),
    el('div', { class: 'panel result__banner' }, [
      statusDot('live'),
      el('div', { class: 'result__banner-body' }, [
        el('strong', { text: 'Subscribed to users/{uid}/virtualPins' }),
        lastSeen,
      ]),
      el('div', { class: 'result__counter' }, [counter, el('span', { text: 'changes' })]),
    ]),
    vitalStrip,
    el('div', { class: 'result__layout' }, [
      el('div', {}, [
        el('div', { class: 'section__title' }, [
          icon('broadcast', 17),
          el('h3', { text: 'Device state' }),
        ]),
        pinList,
      ]),
      el('div', { class: 'panel eventlog' }, [
        el('div', { class: 'eventlog__head' }, [
          icon('pulse', 16),
          el('h3', { text: 'Change feed' }),
        ]),
        eventList,
      ]),
    ]),
  ]);
}
