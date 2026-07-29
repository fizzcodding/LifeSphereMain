import { onValue } from 'firebase/database';

export function subscribe(reference, onData, onError) {
  return onValue(
    reference,
    (snapshot) => onData(snapshot.val()),
    (error) => {
      if (onError) onError(error);
    },
  );
}

export function createSubscriptionGroup() {
  const unsubscribers = [];
  return {
    add(unsubscribe) {
      unsubscribers.push(unsubscribe);
      return unsubscribe;
    },
    dispose() {
      while (unsubscribers.length > 0) {
        const unsubscribe = unsubscribers.pop();
        try {
          unsubscribe();
        } catch (_) {
          continue;
        }
      }
    },
  };
}
