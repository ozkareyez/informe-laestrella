type ToastType = 'success' | 'error' | 'info';

interface ToastMessage {
  id: number;
  message: string;
  type: ToastType;
}

let toastId = 0;
let listeners: ((msg: ToastMessage) => void)[] = [];

export function toast(message: string, type: ToastType = 'success') {
  const msg: ToastMessage = { id: ++toastId, message, type };
  listeners.forEach(fn => fn(msg));
}

export function onToast(fn: (msg: ToastMessage) => void): () => void {
  listeners = [...listeners, fn];
  return () => {
    listeners = listeners.filter(h => h !== fn);
  };
}

export type { ToastMessage, ToastType };
