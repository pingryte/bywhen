import { defineConfig } from "vite";
import elmPlugin from "vite-plugin-elm";

export default defineConfig({
  plugins: [elmPlugin()],
  root: "frontend",
  publicDir: "public",
  build: { outDir: "dist", emptyOutDir: true },
  server: { fs: { allow: [".."] } },
});
