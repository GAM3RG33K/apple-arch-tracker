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
