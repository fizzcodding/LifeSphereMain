import './styles/base.css';
import './styles/login.css';
import './styles/shell.css';
import './styles/views.css';
import './styles/result.css';

import { initSession, subscribeSession } from './auth/session-store.js';
import { el, mount } from './lib/dom.js';
import { appShell } from './ui/app-shell.js';
import { loadingState } from './ui/components/controls.js';
import { loadMode } from './ui/components/mode-switch.js';
import { loginView } from './ui/views/login-view.js';

const root = document.getElementById('root');

let mode = loadMode();
let rendered = null;
let shell = null;

function disposeShell() {
  if (shell) {
    shell.dispose();
    shell = null;
  }
}

function renderShell() {
  disposeShell();
  shell = appShell({
    mode,
    onModeChange: (next) => {
      mode = next;
      renderShell();
    },
  });
  mount(root, [shell.node]);
}

function render(state) {
  if (state.status === 'loading') {
    if (rendered === 'loading') return;
    rendered = 'loading';
    disposeShell();
    mount(root, [
      el('div', { style: 'display:grid;place-items:center;min-height:100vh' }, [
        loadingState('Restoring session…'),
      ]),
    ]);
    return;
  }

  if (state.status === 'anonymous') {
    if (rendered === 'anonymous') return;
    rendered = 'anonymous';
    disposeShell();
    mount(root, [loginView()]);
    return;
  }

  if (rendered === 'authenticated') return;
  rendered = 'authenticated';
  renderShell();
}

function renderFatal(message) {
  mount(root, [
    el('div', { style: 'display:grid;place-items:center;min-height:100vh;padding:32px' }, [
      el('div', { class: 'panel', style: 'max-width:520px' }, [
        el('h3', { text: 'Configuration error' }),
        el('p', { style: 'margin-top:10px;line-height:1.6', text: message }),
      ]),
    ]),
  ]);
}

try {
  subscribeSession(render);
  initSession();
} catch (error) {
  renderFatal(error?.message ?? 'Could not start the application.');
}
