export default {
  fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname === "/" && !url.searchParams.has("release")) {
      url.searchParams.set("release", "1.4.1");

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
