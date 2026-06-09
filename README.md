# Mac Architecture Tracker

A standalone, offline-first command line utility designed to audit your entire Apple Silicon system for legacy Intel (x86_64) workloads draining battery and CPU cycles. Features zero telemetry, zero dependencies, and 100% open-source shell logic, accompanied by a visual HTML dashboard generator.

## Features

- **Application Bundles**: Scans `/Applications` recursively to check Mach-O binary architectures using native `lipo` and `file`.
- **Homebrew Inventory**: Checks Formulae, Casks, and background Services natively out of the box.
- **Global NPM Modules**: Explores global `node_modules` searching for pre-compiled `*.node` native bindings.
- **Visual HTML Export**: Auto-generates an HTML bridged-viewer summarizing emulated bottlenecks via a comprehensive layout without relying on cloud services.

## Installation / Usage

Run the scanner locally directly via cURL:

```bash
curl -sL https://GAM3RG33K.github.io/apple-arch-tracker/arch-tracker.sh | bash -s -- --report
```

*Note: Generating a report (`--report`) uses an offline strategy to render the results inside a locally bridging Web UI!*

## Local Flags & Manual Access

To download and run locally instead of piped bash execution, or to see manual granular flags:

```bash
wget https://GAM3RG33K.github.io/apple-arch-tracker/arch-tracker.sh
chmod +x arch-tracker.sh
./arch-tracker.sh --help
```

Available granular module isolation options:
- `-a, --apps`: Scan macOS Application bundles only.
- `-b, --brew`: Scan Homebrew formulae, casks, and background services.
- `-n, --npm`: Scan globally installed NPM packages for binary addons.

## Enabling GitHub Pages Hosting for the Dashboard UI

To have your repository host the `/public/arch-tracker.sh` file and the Vite React application:

1. Setup the project and build the static assets:
```bash
npm install
npm run build
```

2. This will generate a `/dist` directory containing your HTML, CSS, JavaScript, and the `arch-tracker.sh` script.
3. Commit these changes and push to GitHub.
4. On your GitHub repository pages:
   - Go to **Settings** > **Pages**
   - Under "Build and deployment", set the **Source** to `Deploy from a branch`
   - Set the **Branch** to `gh-pages` (if you are utilizing a deployment action) or select the folder (like `main` branch, `/docs` folder depending on your setup. A common approach is pushing the contents of `/dist` to a branch called `gh-pages`).

A common automated GitHub Action workflow (`.github/workflows/deploy.yml`):
```yaml
name: Deploy static content to Pages

on:
  push:
    branches: ["main"]
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: "pages"
  cancel-in-progress: true

jobs:
  deploy:
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      - name: Set up Node
        uses: actions/setup-node@v3
        with:
          node-version: 18
      - name: Install dependencies
        run: npm ci
      - name: Build
        run: npm run build
      - name: Setup Pages
        uses: actions/configure-pages@v3
      - name: Upload artifact
        uses: actions/upload-pages-artifact@v2
        with:
          path: './dist'
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v2
```

Once deployed, the command `curl -sL https://GAM3RG33K.github.io/apple-arch-tracker/arch-tracker.sh | bash` will successfully download the installer, and the HTML output script will smoothly bounce your local data over to your active page at `https://GAM3RG33K.github.io/apple-arch-tracker/`.
