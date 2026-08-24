// Bundle único del servidor MCP: sin dependencias en runtime, reproducible (CI comprueba `git diff --exit-code dist/`).
import { build } from "esbuild";
import { readFileSync, chmodSync, mkdirSync } from "node:fs";

const pkg = JSON.parse(readFileSync(new URL("./package.json", import.meta.url), "utf8"));
mkdirSync("dist", { recursive: true });

await build({
  entryPoints: ["src/index.ts"],
  bundle: true,
  platform: "node",
  target: "node18",
  format: "esm",
  outfile: "dist/server.js",
  minify: false,
  sourcemap: false,
  legalComments: "none",
  banner: {
    js: [
      "import { createRequire as __sddCreateRequire } from 'node:module';",
      "const require = __sddCreateRequire(import.meta.url);",
    ].join("\n"),
  },
  define: { "process.env.SDD_VERSION": JSON.stringify(pkg.version) },
  logLevel: "info",
});

chmodSync("dist/server.js", 0o755);
