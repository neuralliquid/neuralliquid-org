import { readFile, readdir } from "node:fs/promises";
import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..", "site");
const required = ["index.html", "privacy/index.html", "terms/index.html", "assets/site.css", "staticwebapp.config.json"];

async function filesUnder(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const nested = await Promise.all(entries.map((entry) => {
    const path = join(directory, entry.name);
    return entry.isDirectory() ? filesUnder(path) : [path];
  }));
  return nested.flat();
}

const files = await filesUnder(root);
const relativeFiles = new Set(files.map((file) => relative(root, file).replaceAll("\\", "/")));
const errors = [];

for (const path of required) {
  if (!relativeFiles.has(path)) errors.push(`Missing required file: ${path}`);
}

for (const file of files.filter((path) => path.endsWith(".html"))) {
  const html = await readFile(file, "utf8");
  const display = relative(root, file).replaceAll("\\", "/");
  for (const fragment of ["<!doctype html>", "<html lang=", "<meta name=\"viewport\"", "<title>", "<main", "</main>", "<footer", "Skip to content"]) {
    if (!html.includes(fragment)) errors.push(`${display}: missing ${fragment}`);
  }
  const links = [...html.matchAll(/(?:href|src)="(\/[^"#?]*)/g)].map((match) => match[1]);
  for (const link of links) {
    const target = link.endsWith("/") ? `${link.slice(1)}index.html` : link.slice(1);
    if (!relativeFiles.has(target)) errors.push(`${display}: broken local reference ${link}`);
  }
}

JSON.parse(await readFile(join(root, "staticwebapp.config.json"), "utf8"));

if (errors.length) {
  console.error(errors.join("\n"));
  process.exit(1);
}

console.log(`Validated ${files.length} static-site files.`);
