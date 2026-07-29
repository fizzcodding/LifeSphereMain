import {
  HYDRATION_GOAL,
  MEALS,
  addDietItem,
  mapVitals,
  removeDietItem,
  updateHydration,
} from '../../api/vitals-service.js';
import { vitalsRef } from '../../api/paths.js';
import { el, mount } from '../../lib/dom.js';
import { formatRelative } from '../../lib/format.js';
import { subscribe } from '../../realtime/subscription.js';
import { field, iconButton, loadingState } from '../components/controls.js';
import { icon } from '../components/icon.js';
import { showErrorToast } from '../components/toast.js';

const RING_COLORS = {
  hr: 'var(--danger)',
  spo2: 'var(--secondary)',
  temp: 'var(--primary)',
};

const MEAL_ICONS = {
  breakfast: 'sun',
  lunch: 'sun',
  dinner: 'moon',
};

function ring(radius, progress, color) {
  const circumference = 2 * Math.PI * radius;
  const clamped = Math.min(Math.max(progress, 0), 1);
  const ns = 'http://www.w3.org/2000/svg';

  const track = document.createElementNS(ns, 'circle');
  track.setAttribute('cx', '69');
  track.setAttribute('cy', '69');
  track.setAttribute('r', String(radius));
  track.setAttribute('fill', 'none');
  track.setAttribute('stroke', color);
  track.setAttribute('stroke-opacity', '0.12');
  track.setAttribute('stroke-width', '12');

  const value = document.createElementNS(ns, 'circle');
  value.setAttribute('cx', '69');
  value.setAttribute('cy', '69');
  value.setAttribute('r', String(radius));
  value.setAttribute('fill', 'none');
  value.setAttribute('stroke', color);
  value.setAttribute('stroke-width', '12');
  value.setAttribute('stroke-linecap', 'round');
  value.setAttribute('stroke-dasharray', String(circumference));
  value.setAttribute('stroke-dashoffset', String(circumference * (1 - clamped)));
  value.setAttribute('transform', 'rotate(-90 69 69)');
  value.style.transition = 'stroke-dashoffset 420ms cubic-bezier(0.4, 0, 0.2, 1)';

  return [track, value];
}

function ringChart(vitals) {
  const ns = 'http://www.w3.org/2000/svg';
  const svg = document.createElementNS(ns, 'svg');
  svg.setAttribute('width', '138');
  svg.setAttribute('height', '138');
  svg.setAttribute('viewBox', '0 0 138 138');
  svg.setAttribute('role', 'img');
  svg.setAttribute('aria-label', 'Heart rate, oxygen saturation and temperature rings');

  [
    ...ring(60, vitals.hr / 200, RING_COLORS.hr),
    ...ring(45, vitals.spo2 / 100, RING_COLORS.spo2),
    ...ring(30, (vitals.temp - 30) / 10, RING_COLORS.temp),
  ].forEach((node) => svg.append(node));

  return svg;
}

function legendRow(label, value, color) {
  return el('div', { class: 'rings__row' }, [
    el('dt', { text: label }),
    el('dd', { style: `color:${color}`, text: value }),
  ]);
}

export function vital32View({ subscriptions, readonly = false }) {
  const body = el('div', { class: 'view' }, [loadingState('Reading biometrics…')]);

  function render(vitals) {
    const hydrationPercent = Math.min((vitals.hydration / HYDRATION_GOAL) * 100, 100);

    const vitalsPanel = el('div', { class: 'panel' }, [
      el('div', { class: 'rings' }, [
        el('div', { class: 'rings__chart' }, [ringChart(vitals)]),
        el('dl', { class: 'rings__legend' }, [
          legendRow('Heart Rate', `${vitals.hr} BPM`, RING_COLORS.hr),
          legendRow('SpO2', `${vitals.spo2}%`, RING_COLORS.spo2),
          legendRow('Temperature', `${vitals.temp.toFixed(1)} C`, RING_COLORS.temp),
        ]),
      ]),
    ]);

    const hydrationPanel = el('div', { class: 'panel' }, [
      el('div', { class: 'hydration' }, [
        el('div', { class: 'hydration__info' }, [
          el('div', { class: 'section__title' }, [el('h3', { text: 'Hydration' })]),
          el('p', {
            text: `${vitals.hydration} / ${HYDRATION_GOAL} ml today${
              vitals.hydrationUpdatedAt
                ? ` · updated ${formatRelative(new Date(vitals.hydrationUpdatedAt))}`
                : ''
            }`,
          }),
          el('div', { class: 'hydration__bar' }, [
            el('div', { class: 'hydration__fill', style: `width:${hydrationPercent}%` }),
          ]),
        ]),
        !readonly &&
          el('div', { class: 'hydration__actions' }, [
            iconButton('minus', {
              title: 'Remove 250 ml',
              onClick: () => updateHydration(-250).catch(() => showErrorToast('Update failed.')),
            }),
            iconButton('plus', {
              title: 'Add 250 ml',
              onClick: () => updateHydration(250).catch(() => showErrorToast('Update failed.')),
            }),
          ]),
      ]),
    ]);

    const stepsPanel = el('div', { class: 'panel stat' }, [
      el('div', { class: 'stat__top' }, [
        el('span', { class: 'stat__label', text: 'Step count' }),
        icon('steps', 18),
      ]),
      el('div', { class: 'stat__value', text: String(vitals.steps) }),
      el('div', { class: 'stat__foot', text: 'Recorded by Vital32 today' }),
    ]);

    const insights = el('div', { class: 'list' }, [
      el('div', { class: 'section__title' }, [el('h3', { text: 'AI insights' })]),
      ...(vitals.suggestions.length === 0
        ? [
            el('div', { class: 'panel' }, [
              el('p', {
                text: 'No insights yet. Generate them from the SphereCore mobile app.',
              }),
            ]),
          ]
        : vitals.suggestions.map((tip) =>
            el('div', { class: 'panel insight' }, [icon('sparkle', 17), el('p', { text: tip })]),
          )),
    ]);

    const diet = el('div', { class: 'list' }, [
      el('div', { class: 'section__title' }, [el('h3', { text: 'Diet planner' })]),
      ...MEALS.map((meal) => mealPanel(meal, vitals.diet[meal])),
    ]);

    mount(body, [
      el('header', { class: 'view__head' }, [
        el('div', {}, [
          el('h1', { text: 'Vital32' }),
          el('p', { text: 'Live biosensing stream from the wearable node.' }),
        ]),
      ]),
      vitalsPanel,
      el('div', { class: 'grid grid--split' }, [hydrationPanel, stepsPanel]),
      insights,
      diet,
    ]);
  }

  function mealPanel(meal, items) {
    const entry = field({ label: '', name: `meal-${meal}`, placeholder: 'Add food item' });
    entry.wrapper.querySelector('.field__label').classList.add('sr-only');

    const itemList = el(
      'div',
      { class: 'meal__items' },
      items.length === 0
        ? [el('div', { class: 'meal__empty', text: 'Nothing logged yet.' })]
        : items.map((item, index) =>
            el('div', { class: 'meal__item' }, [
              el('span', { text: String(item) }),
              !readonly &&
                iconButton('trash', {
                  title: `Remove ${item}`,
                  variant: 'pin__menu-btn',
                  onClick: () =>
                    removeDietItem(meal, index).catch(() => showErrorToast('Update failed.')),
                }),
            ]),
          ),
    );

    const panelBody = el('div', { class: 'meal__body', hidden: true }, [
      !readonly &&
        el('div', { class: 'meal__add' }, [
          entry.wrapper,
          el('button', {
            class: 'btn btn--sm',
            type: 'button',
            text: 'Add',
            onClick: async () => {
              const value = entry.input.value.trim();
              if (!value) return;
              entry.input.value = '';
              try {
                await addDietItem(meal, value);
              } catch (_) {
                showErrorToast('Could not add item.');
              }
            },
          }),
        ]),
      itemList,
    ]);

    const head = el(
      'button',
      {
        class: 'meal__head',
        type: 'button',
        'aria-expanded': 'false',
        onClick: () => {
          const expanded = panelBody.hidden;
          panelBody.hidden = !expanded;
          head.setAttribute('aria-expanded', String(expanded));
        },
      },
      [
        icon(MEAL_ICONS[meal], 16),
        el('span', { text: meal }),
        el('span', { class: 'meal__count', text: `${items.length} item${items.length === 1 ? '' : 's'}` }),
      ],
    );

    return el('div', { class: 'panel meal' }, [head, panelBody]);
  }

  subscriptions.add(
    subscribe(
      vitalsRef(),
      (value) => render(mapVitals(value)),
      () => render(mapVitals(null)),
    ),
  );

  return body;
}
