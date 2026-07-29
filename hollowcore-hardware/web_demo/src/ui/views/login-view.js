import { login, register } from '../../auth/auth-service.js';
import { el, mount } from '../../lib/dom.js';
import { field, submitButton } from '../components/controls.js';
import { showSuccessToast } from '../components/toast.js';

const PROJECT_ID = import.meta.env.VITE_FIREBASE_PROJECT_ID;

function aside() {
  return el('aside', { class: 'login__aside' }, [
    el('div', { class: 'login__brand' }, [
      el('img', { src: '/images/logo_main.png', alt: '' }),
      el('span', { text: 'HollowCore' }),
    ]),
    el('div', { class: 'login__pitch' }, [
      el('h1', { text: 'Biology-responsive home automation.' }),
      el('p', {
        text:
          'Control panel for the HollowCore automation node. Signs in against the same Firebase project as the SphereCore mobile app, so your existing account and devices carry straight over.',
      }),
    ]),
    el('dl', { class: 'login__specs' }, [
      el('div', { class: 'login__spec' }, [
        el('dt', { text: 'Auth' }),
        el('dd', { text: 'Firebase Email/Password' }),
      ]),
      el('div', { class: 'login__spec' }, [
        el('dt', { text: 'Project' }),
        el('dd', { text: PROJECT_ID ?? 'unset' }),
      ]),
      el('div', { class: 'login__spec' }, [
        el('dt', { text: 'State' }),
        el('dd', { text: 'Realtime Database' }),
      ]),
    ]),
  ]);
}

export function loginView() {
  let isRegister = false;

  const emailField = field({
    label: 'Email',
    type: 'email',
    name: 'email',
    placeholder: 'you@example.com',
    autocomplete: 'email',
  });
  const passwordField = field({
    label: 'Password',
    type: 'password',
    name: 'password',
    placeholder: '••••••••',
    autocomplete: 'current-password',
  });

  const error = el('div', { class: 'alert', hidden: true, role: 'alert' });
  const heading = el('h2', { text: 'Welcome back' });
  const subheading = el('p', { text: 'Sign in to continue.' });
  const action = submitButton('Sign in');
  const altPrompt = el('span', { text: 'New to LifeSphere? ' });
  const altButton = el('button', { type: 'button', text: 'Create an account' });

  function setMode(nextIsRegister) {
    isRegister = nextIsRegister;
    error.hidden = true;
    heading.textContent = isRegister ? 'Create account' : 'Welcome back';
    subheading.textContent = isRegister
      ? 'Set up access to your care dashboard.'
      : 'Sign in to continue.';
    mount(action.button, el('span', { text: isRegister ? 'Create account' : 'Sign in' }));
    altPrompt.textContent = isRegister ? 'Already registered? ' : 'New to LifeSphere? ';
    altButton.textContent = isRegister ? 'Back to sign in' : 'Create an account';
    passwordField.input.setAttribute(
      'autocomplete',
      isRegister ? 'new-password' : 'current-password',
    );
  }

  altButton.addEventListener('click', () => setMode(!isRegister));

  const form = el(
    'form',
    {
      class: 'login__form',
      novalidate: true,
      onSubmit: async (event) => {
        event.preventDefault();
        const email = emailField.input.value.trim();
        const password = passwordField.input.value;

        if (!email || !password) {
          error.textContent = 'Please enter both email and password.';
          error.hidden = false;
          return;
        }

        error.hidden = true;
        action.setLoading(true);
        const message = isRegister ? await register(email, password) : await login(email, password);
        action.setLoading(false);

        if (message) {
          error.textContent = message;
          error.hidden = false;
          return;
        }

        showSuccessToast(isRegister ? 'Account created.' : 'Signed in.');
      },
    },
    [
      el('img', { src: '/images/logo_horizontal.png', alt: 'LifeSphere' }),
      heading,
      subheading,
      el('div', { class: 'login__fields' }, [
        emailField.wrapper,
        passwordField.wrapper,
        error,
        action.button,
      ]),
      el('div', { class: 'login__alt' }, [altPrompt, altButton]),
      el('p', {
        class: 'login__note',
        text:
          'Accounts are shared with the SphereCore mobile app. Use the same credentials you registered there.',
      }),
    ],
  );

  setMode(false);

  return el('div', { class: 'login' }, [aside(), el('main', { class: 'login__main' }, [form])]);
}
