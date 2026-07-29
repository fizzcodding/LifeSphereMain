import { el } from '../../lib/dom.js';
import { icon } from './icon.js';

export function pinTile(pin, { readonly = false, onToggle, onEdit, onDelete } = {}) {
  const toggle = el('button', {
    class: readonly ? 'toggle toggle--readonly' : 'toggle',
    type: 'button',
    role: 'switch',
    'aria-checked': String(pin.state),
    'aria-label': `${pin.label} power`,
    disabled: readonly,
  });

  if (!readonly && onToggle) {
    toggle.addEventListener('click', async () => {
      const next = !pin.state;
      toggle.classList.add('toggle--busy');
      toggle.disabled = true;
      try {
        await onToggle(next);
      } finally {
        toggle.classList.remove('toggle--busy');
        toggle.disabled = false;
      }
    });
  }

  const actions = [toggle];

  if (!readonly && (onEdit || onDelete)) {
    const list = el('div', { class: 'pin__menu-list', hidden: true, role: 'menu' }, [
      onEdit &&
        el('button', { type: 'button', role: 'menuitem', text: 'Edit device', onClick: onEdit }),
      onDelete &&
        el('button', {
          class: 'is-danger',
          type: 'button',
          role: 'menuitem',
          text: 'Delete device',
          onClick: onDelete,
        }),
    ]);

    const trigger = el(
      'button',
      {
        class: 'pin__menu-btn',
        type: 'button',
        'aria-label': `More actions for ${pin.label}`,
        'aria-haspopup': 'menu',
        onClick: (event) => {
          event.stopPropagation();
          const willOpen = list.hidden;
          document
            .querySelectorAll('.pin__menu-list')
            .forEach((node) => node.setAttribute('hidden', ''));
          if (willOpen) list.removeAttribute('hidden');
        },
      },
      [icon('more', 17)],
    );

    list.addEventListener('click', () => list.setAttribute('hidden', ''));
    actions.push(el('div', { class: 'pin__menu' }, [trigger, list]));
  }

  return el('article', { class: pin.state ? 'panel pin pin--on' : 'panel pin' }, [
    el('div', { class: 'pin__gpio' }, [
      el('span', { text: String(pin.pin) }),
      el('small', { text: 'GPIO' }),
    ]),
    el('div', { class: 'pin__body' }, [
      el('div', { class: 'pin__label', text: pin.label || 'Unnamed device' }),
      el('div', { class: 'pin__state' }, [
        icon('bulb', 13),
        el('span', { text: pin.state ? 'Active' : 'Inactive' }),
      ]),
    ]),
    el('div', { class: 'pin__actions' }, actions),
  ]);
}
