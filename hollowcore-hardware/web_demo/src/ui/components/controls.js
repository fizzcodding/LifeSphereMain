import { el, mount } from '../../lib/dom.js';
import { icon } from './icon.js';

export function field({ label, type = 'text', value = '', placeholder = '', name, autocomplete }) {
  const input = el('input', { type, value, placeholder, name, autocomplete, id: `f-${name}` });
  const wrapper = el('label', { class: 'field', for: `f-${name}` }, [
    el('span', { class: 'field__label', text: label }),
    input,
  ]);
  return { wrapper, input };
}

export function submitButton(labelText, { variant = 'btn btn--block' } = {}) {
  const label = el('span', { text: labelText });
  const button = el('button', { class: variant, type: 'submit' }, [label]);

  return {
    button,
    setLoading(loading) {
      button.disabled = loading;
      mount(button, loading ? el('span', { class: 'spinner' }) : label);
    },
  };
}

export function iconButton(iconName, { title, onClick, variant = 'btn btn--icon' } = {}) {
  return el(
    'button',
    { class: variant, type: 'button', title, 'aria-label': title, onClick },
    [icon(iconName, 17)],
  );
}

export function emptyState({ iconName, title, description }) {
  return el('div', { class: 'panel empty' }, [
    icon(iconName, 44, 1.4),
    el('h3', { text: title }),
    description && el('p', { text: description }),
  ]);
}

export function loadingState(message = 'Loading…') {
  return el('div', { class: 'view__loading' }, [
    el('span', { class: 'spinner spinner--ink' }),
    el('span', { text: message }),
  ]);
}

export function statusDot(variant = '') {
  return el('span', { class: variant ? `status-dot status-dot--${variant}` : 'status-dot' });
}
