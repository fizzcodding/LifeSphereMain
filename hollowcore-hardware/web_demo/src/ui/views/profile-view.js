import { calculateAge, fetchProfile, saveProfile } from '../../api/reminders-service.js';
import { getSession } from '../../auth/session-store.js';
import { el, mount } from '../../lib/dom.js';
import { toDateInputValue } from '../../lib/format.js';
import { field, loadingState, submitButton } from '../components/controls.js';
import { showErrorToast, showSuccessToast } from '../components/toast.js';

export function profileView({ readonly = false } = {}) {
  const body = el('section', { class: 'view' }, [loadingState('Loading profile…')]);
  const session = getSession();

  function render(profile) {
    const nameField = field({
      label: 'Full name',
      name: 'name',
      value: profile.name,
      placeholder: 'Your name',
    });
    const birthField = field({
      label: 'Birth date',
      name: 'birthDate',
      type: 'date',
      value: toDateInputValue(profile.birthDate),
    });
    const phoneField = field({
      label: 'Phonetag (BLE UUID)',
      name: 'phonetag',
      value: profile.phonetag,
      placeholder: 'BLE beacon identifier',
    });

    const age = calculateAge(profile.birthDate);
    const action = submitButton('Save profile', { variant: 'btn' });

    [nameField, birthField, phoneField].forEach(({ input }) => {
      input.disabled = readonly;
    });

    const form = el(
      'form',
      {
        class: 'panel',
        onSubmit: async (event) => {
          event.preventDefault();
          const name = nameField.input.value.trim();
          const birthDate = birthField.input.value;
          if (!name || !birthDate) {
            showErrorToast('Enter a name and birth date.');
            return;
          }

          action.setLoading(true);
          try {
            await saveProfile({
              name,
              birthDate: new Date(birthDate).toISOString(),
              phonetag: phoneField.input.value.trim(),
            });
            showSuccessToast('Profile saved.');
          } catch (_) {
            showErrorToast('Could not save your profile.');
          } finally {
            action.setLoading(false);
          }
        },
      },
      [
        el('div', { class: 'section__title' }, [el('h3', { text: 'Your profile' })]),
        el('div', { class: 'dialog__fields' }, [
          nameField.wrapper,
          el('div', { class: 'form-grid' }, [birthField.wrapper, phoneField.wrapper]),
        ]),
        !readonly && action.button,
      ],
    );

    mount(body, [
      el('header', { class: 'view__head' }, [
        el('div', {}, [
          el('h1', { text: 'Profile' }),
          el('p', { text: 'Identity used by SphereAI to personalise care.' }),
        ]),
      ]),
      el('div', { class: 'grid grid--stats' }, [
        el('div', { class: 'panel stat' }, [
          el('span', { class: 'stat__label', text: 'Signed in as' }),
          el('div', { class: 'stat__foot', style: 'font-size:13px;color:var(--ink)', text: session.user?.email ?? '—' }),
        ]),
        el('div', { class: 'panel stat' }, [
          el('span', { class: 'stat__label', text: 'Age' }),
          el('div', { class: 'stat__value', text: age == null ? '—' : String(age) }),
        ]),
        el('div', { class: 'panel stat' }, [
          el('span', { class: 'stat__label', text: 'User ID' }),
          el('div', {
            class: 'stat__foot',
            style: 'font-family:ui-monospace,monospace;font-size:11px;word-break:break-all',
            text: session.user?.uid ?? '—',
          }),
        ]),
      ]),
      form,
    ]);
  }

  fetchProfile()
    .then(render)
    .catch(() => render({ name: '', birthDate: '', phonetag: '' }));

  return body;
}
