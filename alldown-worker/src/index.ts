import defaultRules from "./rules.json";

export interface Env {
  ALLDOWN_RULES: KVNamespace;
  ADMIN_SECRET?: string;
}

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Requested-With",
};

function jsonResponse(data: unknown, status = 200, extraHeaders: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(data, null, 2), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      ...CORS_HEADERS,
      ...extraHeaders,
    },
  });
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);

    // Handle CORS preflight
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: CORS_HEADERS });
    }

    // Health check & welcome
    if (url.pathname === "/" || url.pathname === "/health") {
      return jsonResponse({
        service: "AllDown Dynamic Link Resolver (DLR)",
        status: "healthy",
        version: defaultRules.version,
        time: new Date().toISOString(),
        endpoints: ["GET /api/rules", "POST /api/resolve"],
      });
    }

    // Endpoint 1: GET /api/rules (Model B - Remote Rules Engine)
    if (url.pathname === "/api/rules" && request.method === "GET") {
      try {
        const cachedRules = await env.ALLDOWN_RULES.get("rules", "json");
        const rules = cachedRules || defaultRules;

        // If not seeded in KV yet, seed it in background
        if (!cachedRules) {
          ctx.waitUntil(env.ALLDOWN_RULES.put("rules", JSON.stringify(defaultRules)));
        }

        return jsonResponse(rules, 200, {
          "Cache-Control": "public, max-age=180, s-maxage=180",
        });
      } catch (err: any) {
        return jsonResponse(defaultRules, 200);
      }
    }

    // Endpoint 2: POST /api/resolve (Model A + B Hybrid Resolver)
    if (url.pathname === "/api/resolve" && request.method === "POST") {
      try {
        const body: any = await request.json().catch(() => ({}));
        const inputUrl = (body.url || "").trim();

        if (!inputUrl) {
          return jsonResponse({ success: false, error: "Missing 'url' field in request body." }, 400);
        }

        // 1. Check Vimeo
        const vimeoMatch = inputUrl.match(/vimeo\.com\/(?:channels\/(?:\w+\/)?|groups\/[^\/]*\/videos\/|album\/(?:\d+\/)?video\/|video\/|)(\d+)/) ||
                           inputUrl.match(/player\.vimeo\.com\/video\/(\d+)/);
        if (vimeoMatch) {
          const vimeoId = vimeoMatch[1];
          const resolved = await resolveVimeo(vimeoId);
          if (resolved) return jsonResponse(resolved);
        }

        // 2. Check Dailymotion
        const dailyMatch = inputUrl.match(/dailymotion\.com\/video\/([a-zA-Z0-9]+)/) ||
                            inputUrl.match(/dai\.ly\/([a-zA-Z0-9]+)/) ||
                            inputUrl.match(/dailymotion\.com\/embed\/video\/([a-zA-Z0-9]+)/);
        if (dailyMatch) {
          const dailyId = dailyMatch[1];
          const resolved = await resolveDailymotion(dailyId);
          if (resolved) return jsonResponse(resolved);
        }

        // 3. Check Streamable
        const streamableMatch = inputUrl.match(/streamable\.com\/([a-zA-Z0-9]+)/);
        if (streamableMatch) {
          const streamableId = streamableMatch[1];
          const resolved = await resolveStreamable(streamableId);
          if (resolved) return jsonResponse(resolved);
        }

        return jsonResponse({
          success: false,
          error: "Platform not directly resolvable on edge. Use local client extractor with rules from /api/rules.",
          url: inputUrl,
        }, 404);
      } catch (e: any) {
        return jsonResponse({ success: false, error: e.message || "Internal resolver error" }, 500);
      }
    }

    // Endpoint 3: POST /api/admin/rules (Update rules in KV)
    if (url.pathname === "/api/admin/rules" && request.method === "POST") {
      const authHeader = request.headers.get("Authorization") || "";
      const expectedSecret = env.ADMIN_SECRET || "alldown-secret-key-2026";

      if (authHeader !== `Bearer ${expectedSecret}`) {
        return jsonResponse({ success: false, error: "Unauthorized" }, 401);
      }

      try {
        const newRules = await request.json();
        await env.ALLDOWN_RULES.put("rules", JSON.stringify(newRules, null, 2));
        return jsonResponse({ success: true, message: "Rules successfully updated in Cloudflare KV!", rules: newRules });
      } catch (e: any) {
        return jsonResponse({ success: false, error: e.message }, 400);
      }
    }

    return jsonResponse({ error: "Endpoint not found" }, 404);
  },
};

// --- Extractor implementations ---

async function resolveVimeo(videoId: string) {
  const configUrl = `https://player.vimeo.com/video/${videoId}/config`;
  const res = await fetch(configUrl, {
    headers: {
      "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/122.0.0.0 Safari/537.36",
      "Referer": `https://vimeo.com/${videoId}`,
    },
  });

  if (!res.ok) return null;
  const data: any = await res.json();
  const title = data.video?.title || `Vimeo Video (${videoId})`;
  const author = data.video?.owner?.name || "Vimeo Creator";
  const duration = data.video?.duration || 0;
  const thumbnail = data.video?.thumbs?.base || data.video?.thumbs?.["640"] || "";

  const files = data.request?.files?.progressive || [];
  const streams: any[] = [];

  // 1. Check progressive MP4 files
  if (files.length > 0) {
    files.sort((a: any, b: any) => (b.height || 0) - (a.height || 0));
    for (const f of files) {
      streams.push({
        url: f.url,
        quality: f.quality || `${f.height}p`,
        resolution: `${f.width || 0}x${f.height || 0}`,
        fps: f.fps || 30,
        format: "MP4",
        mime: f.mime || "video/mp4",
      });
    }
  }

  // 2. Check HLS stream if progressive is empty
  const hls = data.request?.files?.hls;
  if (hls && hls.cdns) {
    const defaultCdn = hls.default_cdn || Object.keys(hls.cdns)[0];
    const cdnData = hls.cdns[defaultCdn];
    const hlsUrl = cdnData?.url || cdnData?.avc_url;
    if (hlsUrl) {
      streams.push({
        url: hlsUrl,
        quality: "HLS Auto (Adaptive)",
        resolution: `${data.video?.width || 1280}x${data.video?.height || 720}`,
        format: "HLS",
        mime: "application/x-mpegURL",
      });
    }
  }

  if (!streams.length) return null;

  return {
    success: true,
    platform: "Vimeo",
    id: videoId,
    title,
    author,
    duration,
    durationFormatted: formatDuration(duration),
    thumbnail,
    bestStreamUrl: streams[0].url,
    bestResolution: streams[0].quality,
    streams,
    headers: {
      "Referer": `https://vimeo.com/${videoId}`,
      "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/122.0.0.0 Safari/537.36",
    },
  };
}

async function resolveDailymotion(videoId: string) {
  const metaUrl = `https://www.dailymotion.com/player/metadata/video/${videoId}?app=com.dailymotion.neon`;
  const res = await fetch(metaUrl, {
    headers: {
      "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/122.0.0.0 Safari/537.36",
      "Referer": `https://www.dailymotion.com/video/${videoId}`,
    },
  });

  if (!res.ok) return null;
  const data: any = await res.json();
  if (data.error) return null;

  const title = data.title || `Dailymotion Video (${videoId})`;
  const author = data.owner?.screenname || data.owner?.username || "Dailymotion Creator";
  const duration = data.duration || 0;
  const thumbnail = data.posters?.["60"] || data.posters?.["480"] || data.posters?.["1080"] || "";

  const qualities = data.qualities || {};
  const streams: any[] = [];

  for (const [qualityKey, streamList] of Object.entries(qualities)) {
    if (Array.isArray(streamList)) {
      for (const item of streamList) {
        if (item.url) {
          streams.push({
            url: item.url,
            quality: qualityKey,
            type: item.type || "application/x-mpegURL",
            format: item.type?.includes("mp4") ? "MP4" : "HLS",
          });
        }
      }
    }
  }

  if (!streams.length) return null;

  return {
    success: true,
    platform: "Dailymotion",
    id: videoId,
    title,
    author,
    duration,
    durationFormatted: formatDuration(duration),
    thumbnail,
    bestStreamUrl: streams[0].url,
    bestResolution: streams[0].quality,
    streams,
    headers: {
      "Referer": `https://www.dailymotion.com/video/${videoId}`,
      "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/122.0.0.0 Safari/537.36",
    },
  };
}

async function resolveStreamable(videoId: string) {
  const apiUrl = `https://api.streamable.com/videos/${videoId}`;
  const res = await fetch(apiUrl, {
    headers: {
      "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/122.0.0.0 Safari/537.36",
    },
  });

  if (!res.ok) return null;
  const data: any = await res.json();
  const title = data.title || `Streamable Video (${videoId})`;
  const duration = Math.round(data.files?.mp4?.duration || 0);
  const thumbnail = data.thumbnail_url?.startsWith("//") ? `https:${data.thumbnail_url}` : data.thumbnail_url || "";

  const files = data.files || {};
  const mp4Files = files.mp4 || files["mp4-mobile"] || {};
  let streamUrl = mp4Files.url || "";
  if (streamUrl.startsWith("//")) streamUrl = `https:${streamUrl}`;

  if (!streamUrl) return null;

  return {
    success: true,
    platform: "Streamable",
    id: videoId,
    title,
    author: "Streamable",
    duration,
    durationFormatted: formatDuration(duration),
    thumbnail,
    bestStreamUrl: streamUrl,
    bestResolution: `${mp4Files.height || 720}p`,
    streams: [
      {
        url: streamUrl,
        quality: `${mp4Files.height || 720}p`,
        format: "MP4",
        width: mp4Files.width,
        height: mp4Files.height,
      },
    ],
    headers: {
      "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/122.0.0.0 Safari/537.36",
    },
  };
}

function formatDuration(sec: number): string {
  if (!sec || sec <= 0) return "Stream";
  const m = Math.floor(sec / 60);
  const s = Math.floor(sec % 60);
  return `${m.toString().padStart(2, "0")}:${s.toString().padStart(2, "0")}`;
}
