import { el } from '../../lib/dom.js';

export function openDialog({ title, fields, submitLabel = 'Save', onSubmit }) {
  const host = el('div', { class: 'dialog-host' });
  const error = el('div', { class: 'alert', hidden: true });
  const submit = el('button', { class: 'btn', type: 'submit', text: submitLabel });

  function close() {
    host.remove();
    document.removeEventListener('keydown', onKeydown);
  }

  function onKeydown(event) {
    if (event.key === 'Escape') close();
  }

  const form = el(
    'form',
    {
      class: 'dialog',
      onSubmit: async (event) => {
        event.preventDefault();
        error.hidden = true;
        submit.disabled = true;
        try {
          await onSubmit();
          close();
        } catch (problem) {
          error.textContent = problem?.message ?? 'Could not save changes.';
          error.hidden = false;
          submit.disabled = false;
        }
      },
    },
    [
      el('h3', { text: title }),
      el('div', { class: 'dialog__fields' }, [...fields, error]),
      el('div', { class: 'dialog__actions' }, [
        el('button', {
          class: 'btn btn--outline',
          type: 'button',
          text: 'Cancel',
          onClick: close,
        }),
        submit,
      ]),
    ],
  );

  host.addEventListener('mousedown', (event) => {
    if (event.target === host) close();
  });
  document.addEventListener('keydown', onKeydown);

  host.append(form);
  document.body.append(host);

  const firstInput = form.querySelector('input');
  if (firstInput) firstInput.focus();

  return { close };
}

export function confirmDialog({ title, message, confirmLabel = 'Delete' }) {
  return new Promise((resolve) => {
    const host = el('div', { class: 'dialog-host' });

    function settle(value) {
      host.remove();
      resolve(value);
    }

    host.append(
      el('div', { class: 'dialog' }, [
        el('h3', { text: title }),
        el('p', { style: 'margin-top:10px;font-size:13px;line-height:1.5', text: message }),
        el('div', { class: 'dialog__actions', style: 'margin-top:22px' }, [
          el('button', {
            class: 'btn btn--outline',
            type: 'button',
            text: 'Cancel',
            onClick: () => settle(false),
          }),
          el('button', {
            class: 'btn btn--danger',
            type: 'button',
            text: confirmLabel,
            onClick: () => settle(true),
          }),
        ]),
      ]),
    );

    host.addEventListener('mousedown', (event) => {
      if (event.target === host) settle(false);
    });

    document.body.append(host);
  });
}
