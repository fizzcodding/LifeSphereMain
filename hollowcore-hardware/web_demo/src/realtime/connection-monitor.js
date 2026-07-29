import { ref } from 'firebase/database';
import { database } from '../firebase/client.js';
import { subscribe } from './subscription.js';

export function observeConnection(callback) {
  return subscribe(ref(database, '.info/connected'), (value) => callback(value === true));
}
