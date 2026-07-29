import { logout } from '../auth/auth-service.js';
import { getSession } from '../auth/session-store.js';
import { el, mount } from '../lib/dom.js';
import { observeConnection } from '../realtime/connection-monitor.js';
import { createSubscriptionGroup } from '../realtime/subscription.js';
import { iconButton, statusDot } from './components/controls.js';
import { icon } from './components/icon.js';
import { MODES, modeBanner, modeSwitch, saveMode } from './components/mode-switch.js';
import { showSuccessToast } from './components/toast.js';
import { dashboardView } from './views/dashboard-view.js';
import { profileView } from './views/profile-view.js';
import { remindersView } from './views/reminders-view.js';
import { resultView } from './views/result-view.js';
import { vital32View } from './views/vital32-view.js';

const APP_ROUTES = [
  { id: 'dashboard', label: 'Devices', icon: 'chip', render: dashboardView },
  { id: 'vital32', label: 'Vital32', icon: 'pulse', render: vital32View },
  { id: 'reminders', label: 'Reminders', icon: 'pill', render: remindersView },
  { id: 'profile', label: 'Profile', icon: 'user', render: profileView },
];

const RESULT_ROUTES = [
  { id: 'live', label: 'Live results', icon: 'broadcast', render: resultView },
  { id: 'vital32', label: 'Vital32', icon: 'pulse', render: vital32View },
  { id: 'reminders', label: 'Reminders', icon: 'pill', render: remindersView },
];

export function appShell({ mode, onModeChange }) {
  const session = getSession();
  const routes = mode === MODES.result ? RESULT_ROUTES : APP_ROUTES;
  let activeId = routes[0].id;
  let viewSubscriptions = createSubscriptionGroup();
  const shellSubscriptions = createSubscriptionGroup();

  const connectionDot = statusDot();
  const connectionLabel = el('span', { text: 'Connecting…' });
  const nav = el('nav', { class: 'sidenav', 'aria-label': 'Sections' });
  const outlet = el('div', { style: 'flex:1;min-width:0' });

  function renderNav() {
    mount(nav, [
      el('span', {
        class: 'sidenav__label',
        text: mode === MODES.result ? 'Live view' : 'Control',
      }),
      ...routes.map((route) =>
        el(
          'button',
          {
            class: 'sidenav__item',
            type: 'button',
            'aria-current': route.id === activeId ? 'page' : null,
            onClick: () => navigate(route.id),
          },
          [icon(route.icon, 16), el('span', { text: route.label })],
        ),
      ),
    ]);
  }

  function navigate(id) {
    activeId = id;
    viewSubscriptions.dispose();
    viewSubscriptions = createSubscriptionGroup();

    const route = routes.find((candidate) => candidate.id === id) ?? routes[0];
    mount(outlet, [
      route.render({ subscriptions: viewSubscriptions, readonly: mode === MODES.result }),
    ]);
    renderNav();
  }

  shellSubscriptions.add(
    observeConnection((connected) => {
      connectionDot.className = connected ? 'status-dot status-dot--live' : 'status-dot status-dot--down';
      connectionLabel.textContent = connected ? 'Realtime connected' : 'Reconnecting…';
    }),
  );

  const shell = el('div', { class: 'shell' }, [
    el('header', { class: 'topbar' }, [
      el('div', { class: 'topbar__brand' }, [
        el('img', { src: '/images/logo_main.png', alt: '' }),
        el('strong', { text: 'HollowCore' }),
      ]),
      el('div', { class: 'topbar__spacer' }),
      modeSwitch({
        mode,
        onChange: (next) => {
          if (next === mode) return;
          saveMode(next);
          onModeChange(next);
        },
      }),
      el('div', { class: 'topbar__meta' }, [connectionDot, connectionLabel]),
      el('div', { class: 'topbar__user' }, [
        el('span', { class: 'topbar__email', text: session.user?.email ?? '' }),
        iconButton('logout', {
          title: 'Sign out',
          variant: 'pin__menu-btn',
          onClick: async () => {
            viewSubscriptions.dispose();
            shellSubscriptions.dispose();
            await logout();
            showSuccessToast('Signed out.');
          },
        }),
      ]),
    ]),
    modeBanner(mode),
    el('div', { class: 'shell__body' }, [nav, outlet]),
  ]);

  navigate(activeId);

  const closeMenus = (event) => {
    if (!event.target.closest('.pin__menu')) {
      document
        .querySelectorAll('.pin__menu-list')
        .forEach((node) => node.setAttribute('hidden', ''));
    }
  };

  document.addEventListener('mousedown', closeMenus);
  shellSubscriptions.add(() => document.removeEventListener('mousedown', closeMenus));

  return {
    node: shell,
    dispose: () => {
      viewSubscriptions.dispose();
      shellSubscriptions.dispose();
    },
  };
}
