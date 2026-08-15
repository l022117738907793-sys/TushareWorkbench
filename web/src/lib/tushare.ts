interface TushareData {
  fields: string[];
  items: unknown[][];
}

const cache = new Map<string, { at: number; data: TushareData }>();
let lastCall = 0;

export async function tushareCall(
  apiName: string,
  token: string,
  params: Record<string, string | number>,
  fields = "",
): Promise<TushareData> {
  const key = `${apiName}|${JSON.stringify(params)}`;
  const hit = cache.get(key);
  if (hit && Date.now() - hit.at < 30 * 60 * 1000) {
    return hit.data;
  }
  const wait = Math.max(0, 1100 - (Date.now() - lastCall));
  if (wait > 0) await new Promise((r) => setTimeout(r, wait));
  lastCall = Date.now();
  const res = await fetch("https://api.tushare.pro", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      api_name: apiName,
      token,
      params,
      ...(fields ? { fields } : {}),
    }),
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const json = await res.json();
  if (json.code !== 0) {
    throw new Error(json.msg || `接口 ${apiName} 失败`);
  }
  const data = json.data as TushareData;
  cache.set(key, { at: Date.now(), data });
  return data;
}
