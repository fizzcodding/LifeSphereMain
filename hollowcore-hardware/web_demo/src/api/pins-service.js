import { push, remove, set, update } from 'firebase/database';
import { pinRef, pinsRef } from './paths.js';

export function mapPins(snapshotValue) {
  if (!snapshotValue) return [];
  return Object.entries(snapshotValue)
    .map(([id, value]) => ({
      id,
      label: value?.label ?? '',
      pin: Number(value?.pin ?? 0),
      state: value?.state === true,
    }))
    .sort((a, b) => a.pin - b.pin);
}

export async function addPin(label, pin) {
  const created = push(pinsRef());
  await set(created, { id: created.key, label, pin, state: false });
  return created.key;
}

export async function togglePinState(id, nextState) {
  await update(pinRef(id), { state: nextState });
}

export async function updatePin(id, data) {
  await update(pinRef(id), data);
}

export async function deletePin(id) {
  await remove(pinRef(id));
}
