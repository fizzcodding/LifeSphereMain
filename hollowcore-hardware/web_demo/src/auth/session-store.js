import { observeAuth } from './auth-service.js';

const state = {
  status: 'loading',
  user: null,
};

const listeners = new Set();

function emit() {
  listeners.forEach((listener) => listener(state));
}

export function initSession() {
  observeAuth((user) => {
    state.status = user ? 'authenticated' : 'anonymous';
    state.user = user;
    emit();
  });
}

export function subscribeSession(listener) {
  listeners.add(listener);
  listener(state);
  return () => listeners.delete(listener);
}

export function getSession() {
  return state;
}

export function requireUid() {
  const uid = state.user?.uid;
  if (!uid) throw new Error('No authenticated user.');
  return uid;
}
