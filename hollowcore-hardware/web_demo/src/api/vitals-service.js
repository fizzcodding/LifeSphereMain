import { get, set } from 'firebase/database';
import { userRef } from './paths.js';

export const HYDRATION_GOAL = 2500;
export const MEALS = ['breakfast', 'lunch', 'dinner'];

function readCurrently(source, key) {
  const value = source?.[key];
  if (value && typeof value === 'object' && typeof value.currently === 'number') {
    return value.currently;
  }
  return 0;
}

export function mapVitals(snapshotValue) {
  const data = snapshotValue ?? {};
  const diet = data.diet ?? {};
  const suggestions = data.aiSuggestions ?? {};
  return {
    hr: readCurrently(data, 'hr'),
    spo2: readCurrently(data, 'spo2'),
    temp: readCurrently(data, 'temp'),
    steps: readCurrently(data, 'steps'),
    hydration: readCurrently(data, 'hydration'),
    hydrationUpdatedAt: data.hydration?.lastRecorded ?? null,
    diet: MEALS.reduce((acc, meal) => {
      const items = diet[meal];
      acc[meal] = Array.isArray(items) ? items.filter((item) => item != null) : [];
      return acc;
    }, {}),
    suggestions: Object.values(suggestions).filter(Boolean),
  };
}

export async function updateHydration(delta) {
  const target = userRef('vital32/hydration/currently');
  const snapshot = await get(target);
  const current = snapshot.exists() ? Number(snapshot.val()) || 0 : 0;
  const next = Math.min(Math.max(current + delta, 0), 100000);
  await set(target, next);
  await set(userRef('vital32/hydration/lastRecorded'), new Date().toISOString());
  return next;
}

export async function addDietItem(meal, item) {
  const target = userRef(`vital32/diet/${meal}`);
  const snapshot = await get(target);
  const list = snapshot.exists() && Array.isArray(snapshot.val()) ? snapshot.val() : [];
  await set(target, [...list, item]);
}

export async function removeDietItem(meal, index) {
  const target = userRef(`vital32/diet/${meal}`);
  const snapshot = await get(target);
  if (!snapshot.exists() || !Array.isArray(snapshot.val())) return;
  const list = snapshot.val();
  if (index < 0 || index >= list.length) return;
  await set(target, list.filter((_, position) => position !== index));
}
