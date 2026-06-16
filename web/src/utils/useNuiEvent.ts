import { useEffect, useRef } from 'react';

interface NuiMessageData<T = any> {
  action: string;
  data: T;
}

type NuiHandlerSignature<T> = (data: T) => void;

/**
 * A hook that manages event listeners for receiving data from the client scripts
 * @param action The specific `action` that should invoke this handler
 * @param handler The callback function that will handle the data received
 */
export const useNuiEvent = <T = any>(action: string, handler: (data: T) => void) => {
  const savedHandler = useRef<NuiHandlerSignature<T> | undefined>(undefined);

  useEffect(() => {
    savedHandler.current = handler;
  }, [handler]);

  useEffect(() => {
    const eventListener = (event: MessageEvent<NuiMessageData<T>>) => {
      const { action: eventAction, data } = event.data;

      if (savedHandler.current && eventAction === action) {
        // Only fall back to the flat message when `data` is genuinely absent —
        // `data === undefined`. A plain `data || ...` would discard valid falsy
        // payloads from Lua (false / 0 / "") and pass the whole message instead.
        savedHandler.current((data === undefined ? event.data : data) as T);
      }
    };

    window.addEventListener('message', eventListener);
    return () => window.removeEventListener('message', eventListener);
  }, [action]);
};
