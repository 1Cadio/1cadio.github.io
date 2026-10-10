# Tux Paint web port

This is a WebAssembly build of the original Tux Paint C sources. The drawing
engine, tools, stamps, starters, templates, sounds, and fonts are compiled
from this tree; the browser page is only the SDL canvas host.

## Build on Windows

1. Install and activate the [Emscripten SDK](https://emscripten.org/docs/getting_started/downloads.html).
2. Install Emscripten and make sure `emcc` and `gperf` are available. The
   build uses Emscripten's SDL2, SDL2_image, SDL2_ttf, SDL2_mixer, and libpng
   ports. The web-specific compatibility layer supplies the SDL2_Pango,
   rotozoom, and image-quantization APIs, so native SDL/Pango development
   libraries are not required.
3. From the repository root, run:

   ```powershell
   .\web\build.ps1
   ```

The output is `web\build\index.html`. Serve that directory over HTTP; opening
the HTML directly from `file:` is not supported because WebAssembly and the
preloaded asset filesystem require HTTP.

The current browser build keeps its virtual filesystem in memory for the
duration of the page session. Browser persistence is not enabled because
mounting IDBFS before SDL startup can prevent the original engine from
creating its canvas.

The Magic tool is present in the interface but its native plugin effects are
not loaded in WebAssembly. Those effects are distributed as dynamically
loaded native libraries, so enabling them requires porting or compiling each
effect as WebAssembly rather than simply loading the original desktop files.

Exporting a picture downloads a PNG through the browser. Printing is not
available in the web build. The generated files are placed in `web\build`;
serve that directory over HTTP, for example with `npx http-server web\build`.
The build uses the original Tux Paint engine and assets; `web\compat` only
provides browser-safe replacements for native APIs that are not available in
WebAssembly.
