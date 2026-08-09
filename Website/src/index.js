const currentRelease = "1.4.4.1";
const releasePathPattern = /^\/downloads\/(Prompt-Shelf-(\d+\.\d+\.\d+)\.dmg)$/;
const releaseCacheControl = "public, max-age=31536000, immutable";
const releaseSha256 = Object.freeze({
  "1.4.4": "29de8342d05e86af749d871576b72ffe5a6cb99b52617ce3440dae4129fd7c76",
});

function releaseHeaders(object, filename, version) {
  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set("Accept-Ranges", "bytes");
  headers.set("Cache-Control", releaseCacheControl);
  headers.set("Content-Disposition", `attachment; filename="${filename}"`);
  headers.set("Content-Type", "application/x-apple-diskimage");
  headers.set("ETag", object.httpEtag);
  headers.set("Last-Modified", object.uploaded.toUTCString());
  headers.set("X-Content-Type-Options", "nosniff");
  if (releaseSha256[version]) {
    headers.set("X-Checksum-SHA256", releaseSha256[version]);
  }

  return headers;
}

function parseByteRange(headerValue) {
  const match = /^bytes=(\d*)-(\d*)$/i.exec(headerValue.trim());
  if (!match || (!match[1] && !match[2])) {
    return null;
  }

  if (!match[1]) {
    const suffix = Number(match[2]);
    return Number.isSafeInteger(suffix) && suffix > 0 ? { suffix } : null;
  }

  const offset = Number(match[1]);
  if (!Number.isSafeInteger(offset)) {
    return null;
  }

  if (!match[2]) {
    return { offset };
  }

  const end = Number(match[2]);
  if (!Number.isSafeInteger(end) || end < offset) {
    return null;
  }

  return { offset, length: end - offset + 1 };
}

function normalizedRange(range, objectSize) {
  if ("suffix" in range) {
    const length = Math.min(range.suffix, objectSize);
    return { offset: objectSize - length, length };
  }

  const offset = range.offset;
  if (offset >= objectSize) {
    return null;
  }

  const length = Math.min(range.length ?? objectSize - offset, objectSize - offset);
  return { offset, length };
}

async function rangeNotSatisfiable(env, key) {
  const object = await env.RELEASES.head(key);
  const headers = new Headers({
    "Accept-Ranges": "bytes",
    "Cache-Control": "no-store",
  });

  if (object) {
    headers.set("Content-Range", `bytes */${object.size}`);
  }

  return new Response(null, { status: 416, headers });
}

async function serveRelease(request, env, filename, version) {
  if (request.method !== "GET" && request.method !== "HEAD") {
    return new Response("Method Not Allowed", {
      status: 405,
      headers: {
        Allow: "GET, HEAD",
        "Cache-Control": "no-store",
      },
    });
  }

  const key = `releases/${version}/${filename}`;

  if (request.method === "HEAD") {
    const object = await env.RELEASES.head(key);
    if (!object) {
      return new Response("Not Found", {
        status: 404,
        headers: { "Cache-Control": "no-store" },
      });
    }

    const headers = releaseHeaders(object, filename, version);
    headers.set("Content-Length", String(object.size));
    return new Response(null, { status: 200, headers });
  }

  const rangeHeader = request.headers.get("Range");
  const requestedRange = rangeHeader ? parseByteRange(rangeHeader) : null;
  if (rangeHeader && !requestedRange) {
    return rangeNotSatisfiable(env, key);
  }

  let object;

  try {
    object = await env.RELEASES.get(
      key,
      requestedRange ? { range: { ...requestedRange } } : undefined,
    );
  } catch (error) {
    if (rangeHeader) {
      return rangeNotSatisfiable(env, key);
    }
    throw error;
  }

  if (!object) {
    return new Response("Not Found", {
      status: 404,
      headers: { "Cache-Control": "no-store" },
    });
  }

  const headers = releaseHeaders(object, filename, version);
  const range = requestedRange ? normalizedRange(requestedRange, object.size) : null;

  if (requestedRange && !range) {
    return rangeNotSatisfiable(env, key);
  }

  if (range) {
    const end = range.offset + range.length - 1;
    headers.set("Content-Length", String(range.length));
    headers.set("Content-Range", `bytes ${range.offset}-${end}/${object.size}`);
    return new Response(object.body, { status: 206, headers });
  }

  headers.set("Content-Length", String(object.size));
  return new Response(object.body, { status: 200, headers });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    const releaseMatch = url.pathname.match(releasePathPattern);
    if (releaseMatch) {
      return serveRelease(request, env, releaseMatch[1], releaseMatch[2]);
    }

    if (url.pathname === "/" && url.searchParams.get("release") !== currentRelease) {
      url.searchParams.set("release", currentRelease);

      return new Response(null, {
        status: 302,
        headers: {
          Location: url.toString(),
          "Cache-Control": "no-store",
        },
      });
    }

    return env.ASSETS.fetch(request);
  },
};
