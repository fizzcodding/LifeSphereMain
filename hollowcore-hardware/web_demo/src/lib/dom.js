export function el(tag, props = {}, children = []) {
  const node = document.createElement(tag);

  Object.entries(props).forEach(([key, value]) => {
    if (value == null || value === false) return;
    if (key === 'class') {
      node.className = value;
    } else if (key === 'html') {
      node.innerHTML = value;
    } else if (key === 'text') {
      node.textContent = value;
    } else if (key === 'dataset') {
      Object.entries(value).forEach(([dataKey, dataValue]) => {
        node.dataset[dataKey] = dataValue;
      });
    } else if (key.startsWith('on') && typeof value === 'function') {
      node.addEventListener(key.slice(2).toLowerCase(), value);
    } else {
      node.setAttribute(key, value === true ? '' : value);
    }
  });

  toArray(children).forEach((child) => {
    if (child == null || child === false) return;
    node.append(typeof child === 'string' || typeof child === 'number' ? String(child) : child);
  });

  return node;
}

export function toArray(value) {
  if (Array.isArray(value)) return value.flat(Infinity);
  return [value];
}

export function clear(node) {
  while (node.firstChild) node.removeChild(node.firstChild);
  return node;
}

export function mount(node, children) {
  clear(node);
  toArray(children).forEach((child) => {
    if (child == null || child === false) return;
    node.append(child);
  });
  return node;
}
