import { ref } from 'firebase/database';
import { database } from '../firebase/client.js';
import { requireUid } from '../auth/session-store.js';

export function userRef(path = '') {
  const uid = requireUid();
  return ref(database, path ? `users/${uid}/${path}` : `users/${uid}`);
}

export function pinsRef() {
  return userRef('virtualPins');
}

export function pinRef(id) {
  return userRef(`virtualPins/${id}`);
}

export function vitalsRef() {
  return userRef('vital32');
}

export function remindersRef() {
  return userRef('reminders');
}

export function reminderRef(id) {
  return userRef(`reminders/${id}`);
}

export function profileRef() {
  return userRef('profile');
}
