import { mapPins } from '../api/pins-service.js';
import { pinsRef } from '../api/paths.js';
import { subscribe } from './subscription.js';

export function diffPins(previous, next) {
  if (previous === null) return [];

  const before = new Map(previous.map((pin) => [pin.id, pin]));
  const after = new Map(next.map((pin) => [pin.id, pin]));
  const changes = [];

  after.forEach((pin, id) => {
    const prior = before.get(id);
    if (!prior) {
      changes.push({ type: 'added', pin });
      return;
    }
    if (prior.state !== pin.state) {
      changes.push({ type: 'state', pin, from: prior.state, to: pin.state });
    }
    if (prior.label !== pin.label) {
      changes.push({ type: 'label', pin, from: prior.label, to: pin.label });
    }
    if (prior.pin !== pin.pin) {
      changes.push({ type: 'gpio', pin, from: prior.pin, to: pin.pin });
    }
  });

  before.forEach((pin, id) => {
    if (!after.has(id)) changes.push({ type: 'removed', pin });
  });

  return changes;
}

export function observePinChanges({ onSnapshot, onChanges, onError }) {
  let previous = null;

  return subscribe(
    pinsRef(),
    (value) => {
      const pins = mapPins(value);
      const isInitial = previous === null;
      const changes = diffPins(previous, pins);
      previous = pins;
      if (changes.length > 0 && onChanges) onChanges(changes);
      onSnapshot(pins, isInitial);
    },
    onError,
  );
}
