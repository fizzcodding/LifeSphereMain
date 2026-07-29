import { el } from '../../lib/dom.js';
import { icon } from './icon.js';
import { statusDot } from './controls.js';

export const MODES = {
  app: 'app',
  result: 'result',
};

const STORAGE_KEY = 'hollowcore.mode';

export function loadMode() {
  const stored = localStorage.getItem(STORAGE_KEY);
  return stored === MODES.result ? MODES.result : MODES.app;
}

export function saveMode(mode) {
  localStorage.setItem(STORAGE_KEY, mode);
}

export function modeSwitch({ mode, onChange }) {
  const appButton = el(
    'button',
    {
      class: 'modeswitch__btn',
      type: 'button',
      'aria-pressed': String(mode === MODES.app),
      onClick: () => onChange(MODES.app),
    },
    [icon('sliders', 14), el('span', { text: 'App Mode' })],
  );

  const resultButton = el(
    'button',
    {
      class: 'modeswitch__btn',
      type: 'button',
      'aria-pressed': String(mode === MODES.result),
      onClick: () => onChange(MODES.result),
    },
    [statusDot(mode === MODES.result ? 'live' : ''), el('span', { text: 'Result Mode' })],
  );

  return el(
    'div',
    { class: 'modeswitch', role: 'group', 'aria-label': 'Interface mode' },
    [appButton, resultButton],
  );
}

export function modeBanner(mode) {
  if (mode === MODES.result) {
    return el('div', { class: 'modebanner' }, [
      el('span', { class: 'modebanner__tag modebanner__tag--readonly', text: 'Read only' }),
      el('span', {}, [
        el('strong', { text: 'Result Mode. ' }),
        'Mirroring live Realtime Database state. Toggle a device in the SphereCore mobile app and the change appears here within milliseconds.',
      ]),
    ]);
  }

  return el('div', { class: 'modebanner' }, [
    el('span', { class: 'modebanner__tag', text: 'Read / write' }),
    el('span', {}, [
      el('strong', { text: 'App Mode. ' }),
      'This browser session is a full SphereCore instance writing to the same Firebase backend as the mobile app.',
    ]),
  ]);
}
