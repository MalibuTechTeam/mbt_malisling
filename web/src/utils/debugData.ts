import { isEnvBrowser } from './misc';

interface DebugEvent<T = any> {
  action: string;
  data: T;
}

/**
 * Emulates dispatching an event using the SendNuiMessage in the lua scripts.
 * This is used when developing in browser
 *
 * @param events - The event(s) to dispatch
 * @param timer - (Optional) Time, in ms, to wait before dispatching the events
 */
export const debugData = <P>(events: DebugEvent<P>[], timer = 1000) => {
  if (import.meta.env.MODE === 'development' && isEnvBrowser()) {
    for (const event of events) {
      setTimeout(() => {
        window.dispatchEvent(
          new MessageEvent('message', {
            data: {
              action: event.action,
              data: event.data,
            },
          }),
        );
      }, timer);
    }
  }
};
