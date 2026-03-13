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
    const respFormatted = await resp.json();
    return respFormatted;
  } catch (error) {
    if (error instanceof TypeError && error.message === "Failed to fetch") {
      return {};
    }
    console.error(`[fetchNui] Error fetching ${eventName}:`, error);
    return {};
  }
};
