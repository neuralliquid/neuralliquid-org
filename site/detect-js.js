// Adds `.js` to <html> before first paint (see src/layouts/BaseLayout.astro's
// <head>). Shipped as an external file, not an inline <script>, on purpose:
// staticwebapp.config.json's CSP sets script-src 'self' with no
// 'unsafe-inline' — an inline script would be silently blocked in
// production while working fine in `pnpm preview` (which doesn't apply
// those headers), which would silently kill every .reveal entrance
// animation with no visible error. A same-origin external file is allowed
// under 'self' with no CSP exception needed.
document.documentElement.classList.add("js");
