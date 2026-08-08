const currentRelease = "1.4.3.2";
const releasePathPattern = /^\/downloads\/(Prompt-Shelf-(\d+\.\d+\.\d+)\.dmg)$/;
const releaseCacheControl = "public, max-age=31536000, immutable";
const releaseSha256 = Object.freeze({
  "1.2.0": "a2ae445ebcf4b13a22f34dac263ec471631b773c255b8d5adb2237309c56fbcb",
  "1.3.0": "986abe6d719b4e3c4821ef0ebe73b5b1ffd6d1f0933f6975766a7580249814a7",
  "1.3.1": "ddb08b7980744152ab9f5ea9d3cf13e713aa52ed971f5c323236436dbca2e388",
  "1.4.0": "a64e43c258124197e3ad1b48228646e829433fca3a5d8be3a4bb9e3699601da2",
  "1.4.1": "5c8baf88d0083de2e03f1e538dc1cf48956383cde92c50f70c5088708759428a",
  "1.4.2": "6ec34f09587a9434e273a5b0dafd90363c8064f4e5bf7ffd73016d6f37e9cf0a",
  "1.4.3": "07f271054492a75c537c04822f51673fb0837f635b2ed70ad5880fe8d02d1c6c",
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
