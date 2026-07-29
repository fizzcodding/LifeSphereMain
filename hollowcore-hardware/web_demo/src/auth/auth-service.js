import {
  createUserWithEmailAndPassword,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut,
} from 'firebase/auth';
import { auth, persistenceReady } from '../firebase/client.js';

const ERROR_MESSAGES = {
  'auth/invalid-email': 'That email address is not valid.',
  'auth/invalid-credential': 'Incorrect email or password.',
  'auth/wrong-password': 'Incorrect email or password.',
  'auth/user-not-found': 'No account exists for that email.',
  'auth/user-disabled': 'This account has been disabled.',
  'auth/too-many-requests': 'Too many attempts. Try again in a few minutes.',
  'auth/network-request-failed': 'Network error. Check your connection and retry.',
  'auth/email-already-in-use': 'An account already exists for that email.',
  'auth/weak-password': 'Password must be at least 6 characters.',
  'auth/operation-not-allowed': 'Email and password sign-in is not enabled for this project.',
};

function describe(error) {
  return ERROR_MESSAGES[error?.code] ?? error?.message ?? 'Unexpected authentication error.';
}

export async function login(email, password) {
  await persistenceReady;
  try {
    await signInWithEmailAndPassword(auth, email, password);
    return null;
  } catch (error) {
    return describe(error);
  }
}

export async function register(email, password) {
  await persistenceReady;
  try {
    await createUserWithEmailAndPassword(auth, email, password);
    return null;
  } catch (error) {
    return describe(error);
  }
}

export async function logout() {
  await signOut(auth);
}

export function observeAuth(callback) {
  return onAuthStateChanged(auth, callback);
}

export function currentUser() {
  return auth.currentUser;
}
