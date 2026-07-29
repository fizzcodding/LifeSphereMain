import { initializeApp } from 'firebase/app';
import { browserLocalPersistence, getAuth, setPersistence } from 'firebase/auth';
import { getDatabase } from 'firebase/database';
import { getFirebaseConfig } from './config.js';

const app = initializeApp(getFirebaseConfig());

export const auth = getAuth(app);
export const database = getDatabase(app);

export const persistenceReady = setPersistence(auth, browserLocalPersistence).catch(() => {});

export default app;
