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

        // 4. Check Reddit
        const isReddit = inputUrl.includes("reddit.com") || inputUrl.includes("redd.it");
        if (isReddit) {
          const resolved = await resolveReddit(inputUrl);
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
      "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36",
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

  // Attempt to parse master manifest in Worker to get direct sub-playlists
  let directSubStreams: any[] = [];
  let debugM3u8Status = 0;
  let debugM3u8Text = "";
  try {
    const m3u8Res = await fetch(streams[0].url, {
      headers: {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36",
        "Sec-Fetch-Dest": "empty",
        "Sec-Fetch-Mode": "cors",
        "Sec-Fetch-Site": "cross-site",
      },
    });
    debugM3u8Status = m3u8Res.status;
    if (m3u8Res.ok) {
      const m3u8Text = await m3u8Res.text();
      debugM3u8Text = m3u8Text.substring(0, 100);
      const lines = m3u8Text.split("\n").map(l => l.trim());
      for (let i = 0; i < lines.length; i++) {
        if (lines[i].startsWith("#EXT-X-STREAM-INF") && i + 1 < lines.length) {
          const streamInf = lines[i];
          const subUrl = lines[i + 1];
          if (subUrl.startsWith("http")) {
            const resMatch = streamInf.match(/RESOLUTION=(\d+x\d+)/);
            const nameMatch = streamInf.match(/NAME="([^"]+)"/);
            const qual = nameMatch ? `${nameMatch[1]}p` : (resMatch ? resMatch[1] : "HD");
            directSubStreams.push({
              url: subUrl,
              quality: qual,
              resolution: resMatch ? resMatch[1] : undefined,
              format: "HLS",
            });
          }
        }
      }
    } else {
      debugM3u8Text = await m3u8Res.text();
    }
  } catch (err: any) {
    debugM3u8Text = err.message;
  }

  const finalStreams = directSubStreams.length > 0 ? directSubStreams : streams;

  return {
    success: true,
    platform: "Dailymotion",
    id: videoId,
    title,
    author,
    duration,
    durationFormatted: formatDuration(duration),
    thumbnail,
    bestStreamUrl: finalStreams[0].url,
    bestResolution: finalStreams[0].quality,
    streams: finalStreams,
    debugM3u8Status,
    debugM3u8Text: debugM3u8Text.substring(0, 150),
    headers: {
      "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36",
      "Sec-Fetch-Dest": "empty",
      "Sec-Fetch-Mode": "cors",
      "Sec-Fetch-Site": "cross-site",
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

async function resolveReddit(postUrl: string) {
  try {
    let cleanUrl = postUrl.trim();
    if (cleanUrl.includes("redd.it/") || cleanUrl.includes("/s/")) {
      try {
        const headRes = await fetch(cleanUrl, {
          redirect: "follow",
          headers: {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
          },
        });
        if (headRes.url && headRes.url.startsWith("http")) {
          cleanUrl = headRes.url;
        }
      } catch (_) {}
    }

    // Try fetching official oembed for pristine title and author
    let title = "";
    let author = "";
    try {
      const oembedRes = await fetch(`https://www.reddit.com/oembed?url=${encodeURIComponent(cleanUrl)}`, {
        headers: { "User-Agent": "Mozilla/5.0" },
      });
      if (oembedRes.ok) {
        const oembedData: any = await oembedRes.json();
        if (oembedData.title) title = oembedData.title.trim();
        if (oembedData.author_name && oembedData.author_name !== "[account deleted]") {
          author = `u/${oembedData.author_name}`;
        }
      }
    } catch (_) {}

    // Fallback title from URL slug if still empty
    if (!title) {
      try {
        const u = new URL(cleanUrl);
        const segs = u.pathname.split("/").filter(Boolean);
        const commentsIdx = segs.indexOf("comments");
        if (commentsIdx !== -1 && segs.length > commentsIdx + 2) {
          const rawSlug = segs[commentsIdx + 2];
          title = rawSlug.replace(/[_-]+/g, " ").replace(/\b\w/g, c => c.toUpperCase()).trim();
        }
      } catch (_) {}
    }

    const rsUrl = `https://rapidsave.com/info?url=${encodeURIComponent(cleanUrl)}`;
    const rsRes = await fetch(rsUrl, {
      headers: {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      },
    });

    if (!rsRes.ok) return null;
    const html = await rsRes.text();

    if (!title) {
      const ogTitleMatch = html.match(/<meta\s+property=["']og:title["']\s+content=["']([^"']+)["']/i);
      const titleTagMatch = html.match(/<title>([^<]+)<\/title>/i);
      const captionMatch = html.match(/class=["']caption["'][^>]*>([^<]+)</i);
      if (captionMatch && captionMatch[1].trim()) {
        title = captionMatch[1].trim();
      } else if (ogTitleMatch && ogTitleMatch[1].trim()) {
        title = ogTitleMatch[1].trim();
      } else if (titleTagMatch && titleTagMatch[1].trim()) {
        const t = titleTagMatch[1].trim().replace(/\s*-\s*RapidSave.*$/i, "").replace(/\s*-\s*Reddit.*$/i, "").trim();
        if (!t.toLowerCase().includes("download reddit video")) {
          title = t;
        }
      }
    }
    if (!title) title = "Reddit Video";

    if (!author) {
      const subMatch = html.match(/<td>Subreddit:<\/td>\s*<td>([^<]+)<\/td>/i);
      const authorMatch = html.match(/<td>Author:<\/td>\s*<td>([^<]+)<\/td>/i);
      if (authorMatch && authorMatch[1].trim()) {
        author = `u/${authorMatch[1].trim()}`;
      } else if (subMatch && subMatch[1].trim()) {
        author = `r/${subMatch[1].trim()}`;
      } else {
        author = "Reddit User";
      }
    }

    let thumbnail = "";
    const previewMatch = html.match(/class=["'][^"']*preview[^"']*["'][^>]*src=["']([^"']+)["']/i) ||
                         html.match(/<img[^>]+src=["'](https?:\/\/[^"']*(?:thumbs\.redditmedia\.com|preview\.redd\.it)[^"']*)["']/i);
    if (previewMatch) {
      thumbnail = previewMatch[1];
    }

    let bestStreamUrl = "";
    const dlButtonMatch = html.match(/<a[^>]+class=["'][^"']*downloadbutton[^"']*["'][^>]+href=["']([^"']+)["']/i);
    if (dlButtonMatch) {
      const rawHref = dlButtonMatch[1].trim();
      if (rawHref.startsWith("/sd.php")) {
        try {
          const sdRes = await fetch(`https://rapidsave.com${rawHref}`, {
            headers: {
              "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            },
          });
          if (sdRes.ok) {
            const sdHtml = await sdRes.text();
            const sdLinks = [...sdHtml.matchAll(/href=["'](https?:\/\/sd\.rapidsave\.com\/download[^"']+)["']/gi)];
            if (sdLinks.length > 0) {
              const sorted = sdLinks.map(m => m[1]);
              const q1080 = sorted.find(u => u.includes("DASH_1080") || u.includes("1080"));
              const q720 = sorted.find(u => u.includes("DASH_720") || u.includes("720"));
              const q480 = sorted.find(u => u.includes("DASH_480") || u.includes("480"));
              bestStreamUrl = q1080 || q720 || q480 || sorted[0];
            }
          }
        } catch (_) {}
      } else if (rawHref.startsWith("http")) {
        bestStreamUrl = rawHref;
      } else if (rawHref.startsWith("/")) {
        bestStreamUrl = `https://rapidsave.com${rawHref}`;
      }
    }

    if (!bestStreamUrl) {
      const anySd = html.match(/https?:\/\/sd\.rapidsave\.com\/download[^"'\s<>]+/i);
      if (anySd) {
        bestStreamUrl = anySd[0];
      }
    }

    const vMatch = html.match(/https?:\/\/v\.redd\.it\/([a-zA-Z0-9]+)/i) ||
                   cleanUrl.match(/https?:\/\/v\.redd\.it\/([a-zA-Z0-9]+)/i);
    const vId = vMatch ? vMatch[1] : "";
    const hlsUrl = vId ? `https://v.redd.it/${vId}/HLSPlaylist.m3u8` : "";

    if (!bestStreamUrl && !hlsUrl) {
      return null;
    }

    const finalUrl = bestStreamUrl || hlsUrl;
    const isHls = !bestStreamUrl && !!hlsUrl;

    return {
      success: true,
      platform: "Reddit",
      id: vId || "reddit_video",
      title: title.replace(/&amp;/g, "&").replace(/&quot;/g, '"'),
      author,
      duration: 30,
      durationFormatted: "Reddit HD",
      thumbnail,
      bestStreamUrl: finalUrl,
      bestResolution: "HD MP4",
      isHls,
      streams: [
        {
          url: finalUrl,
          quality: "HD",
          format: isHls ? "HLS" : "MP4",
        },
      ],
      headers: {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
        "Referer": "https://rapidsave.com/",
      },
    };
  } catch (err: any) {
    return null;
  }
}
