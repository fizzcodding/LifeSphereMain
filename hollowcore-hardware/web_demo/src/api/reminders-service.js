import { get, push, remove, set, update } from 'firebase/database';
import { profileRef, reminderRef, remindersRef } from './paths.js';

export const WEEKDAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

export function mapReminders(snapshotValue) {
  if (!snapshotValue) return [];
  return Object.entries(snapshotValue).map(([id, value]) => ({
    id,
    name: value?.name ?? '',
    slot: value?.slot ?? '',
    time: value?.time ?? '',
    days: Array.isArray(value?.days) ? value.days : [],
    note: value?.note ?? '',
  }));
}

export async function addReminder(reminder) {
  await set(push(remindersRef()), reminder);
}

export async function updateReminder(id, data) {
  await update(reminderRef(id), data);
}

export async function deleteReminder(id) {
  await remove(reminderRef(id));
}

export async function fetchProfile() {
  const snapshot = await get(profileRef());
  if (!snapshot.exists()) return { name: '', birthDate: '', phonetag: '' };
  const value = snapshot.val() ?? {};
  return {
    name: value.name ?? '',
    birthDate: value.birthDate ?? '',
    phonetag: value.phonetag ?? '',
  };
}

export async function saveProfile({ name, birthDate, phonetag }) {
  await set(profileRef(), { name, birthDate, phonetag });
}

export function calculateAge(isoDate) {
  if (!isoDate) return null;
  const birth = new Date(isoDate);
  if (Number.isNaN(birth.getTime())) return null;
  const now = new Date();
  let age = now.getFullYear() - birth.getFullYear();
  const beforeBirthday =
    now.getMonth() < birth.getMonth() ||
    (now.getMonth() === birth.getMonth() && now.getDate() < birth.getDate());
  if (beforeBirthday) age -= 1;
  return age;
}
