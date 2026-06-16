/**
 * Simple wrapper around fetch API tailored for FiveM NUI.
 * This function can be used to send data to the client script.
 *
 * @param eventName - The endpoint event name
 * @param data - Data to send to the client script
 * @param mockData - Mock data to return if in browser environment
 */
export const fetchNui = async (eventName: string, data?: any, mockData?: any): Promise<any> => {
  const options = {
    method: 'post',
    headers: {
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: JSON.stringify(data),
  };

  if (import.meta.env.MODE === 'development' && (window as any).invokeNative === undefined) {
    if (mockData) return mockData;
    return {};
  }

  const resourceName = (window as any).GetParentResourceName ? (window as any).GetParentResourceName() : 'mbt_malisling';

  try {
    const resp = await fetch(`https://${resourceName}/${eventName}`, options);
    // FiveM NUI callbacks frequently reply with an empty body (or non-JSON if the
    // Lua callback errored). Read text first and only parse when there's content,
    // so a blank/garbage reply degrades to {} instead of throwing on resp.json().
    const text = await resp.text();
    if (!text) return {};
    try {
      return JSON.parse(text);
    } catch {
      console.error(`[fetchNui] ${eventName}: non-JSON reply (status ${resp.status})`);
      return {};
    }
  } catch (error) {
    if (error instanceof TypeError && error.message === "Failed to fetch") {
      return {};
    }
    console.error(`[fetchNui] Error fetching ${eventName}:`, error);
    return {};
  }
};
