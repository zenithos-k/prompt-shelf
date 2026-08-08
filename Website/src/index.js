const currentRelease = "1.4.3.1";

export default {
  fetch(request, env) {
    const url = new URL(request.url);

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
