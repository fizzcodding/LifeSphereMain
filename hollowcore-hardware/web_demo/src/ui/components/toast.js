import { el } from '../../lib/dom.js';

let host = null;

function ensureHost() {
  if (!host) {
    host = el('div', { class: 'toast-host', role: 'status', 'aria-live': 'polite' });
    document.body.append(host);
  }
  return host;
}

function show(message, variant) {
  const toast = el('div', {
    class: variant === 'error' ? 'toast toast--error' : 'toast',
    text: message,
  });
  ensureHost().append(toast);
  setTimeout(() => {
    toast.style.transition = 'opacity 200ms ease-out';
    toast.style.opacity = '0';
    setTimeout(() => toast.remove(), 220);
  }, 2600);
}

export function showSuccessToast(message) {
  show(message, 'success');
}

export function showErrorToast(message) {
  show(message, 'error');
}
