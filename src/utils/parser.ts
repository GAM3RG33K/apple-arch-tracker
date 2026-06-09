import { AuditedItem, ParseResult } from '../types';

/**
 * Extracts recommendations for commonly identified Intel-only software
 */
const getStaticRecommendation = (name: string, type: 'application' | 'brew-binary' | 'brew-service' | 'npm-native-addon'): { issue: string; recommendation: string } => {
  const normName = name.replace(/\.app$/i, '').toLowerCase();

  if (type === 'application') {
    switch (normName) {
      case 'discord':
        return {
          issue: 'Running legacy Intel version of Discord via Rosetta 2 simulation, causing high CPU wakeups.',
          recommendation: 'Download the modern Apple Silicon build from: https://discord.com/download (Select the Apple Silicon version).'
        };
      case 'spotify':
        return {
          issue: 'Spotify is running on Intel emulation, loading slower and using more RAM than necessary.',
          recommendation: 'Get the Apple Silicon version of Spotify from: https://www.spotify.com/download/mac/'
        };
      case 'slack':
        return {
          issue: 'Slack is running in x86_64 simulation mode. Large memory usage is multiplied under Rosetta.',
          recommendation: 'Download the Universal/Apple Silicon Slack client from the Mac App Store or directly from slack.com.'
        };
      case 'zoom':
        return {
          issue: 'Zoom Intel client drains battery quickly during video calls on Apple Silicon.',
          recommendation: 'Download the separate installer labeled "Zoom for IT Admins - Apple Silicon" or reinstall from zoom.us/download.'
        };
      case 'teams':
      case 'microsoft teams':
        return {
          issue: 'Legacy Microsoft Teams client is running on Intel emulation.',
          recommendation: 'Install the new, rebuilt Microsoft Teams app which fully supports native Apple Silicon.'
        };
      case 'virtualbox':
        return {
          issue: 'VirtualBox has limited or non-functional support for virtualization on Apple Silicon chips.',
          recommendation: 'Migrate to modern native hypervisors like UTM (free, mac.getutm.app) or OrbStack (ultra-fast, orbstack.dev).'
        };
      case 'sourcetree':
        return {
          issue: 'Sourcetree Git client running under Intel emulation.',
          recommendation: 'Update Sourcetree to the latest version, which ships as a native Universal Binary.'
        };
      case 'wireshark':
        return {
          issue: 'Wireshark packet capture software running on Intel emulation.',
          recommendation: 'Download Wireshark with the official macOS Arm 64-bit installer.'
        };
      default:
        return {
          issue: `Running ${name} under Intel emulation. Demands extra processing power.`,
          recommendation: `Check the software maker's official downloads site for an Apple Silicon (M1/M2/M3) or 'Universal' macOS copy.`
        };
    }
  }

  if (type === 'brew-binary' || type === 'brew-service') {
    const serviceSuffix = type === 'brew-service' ? ' service' : '';
    switch (normName) {
      case 'redis':
        return {
          issue: `Redis${serviceSuffix} is compiled for x86_64 CPU instructions, dragging heavy read/write throughput down.`,
          recommendation: `Reinstall Redis natively: \n\`\`\`bash\nbrew uninstall redis && brew install redis\n\`\`\``
        };
      case 'postgres':
      case 'postgresql':
        return {
          issue: `PostgreSQL database${serviceSuffix} is executing in Intel emulation. Disastrous for low-latency queries during dev.`,
          recommendation: `Backup your DB, then rebuild PostgreSQL natively: \n\`\`\`bash\nbrew uninstall postgresql && brew install postgresql\n\`\`\``
        };
      case 'mysql':
        return {
          issue: `MySQL server${serviceSuffix} is running on Intel instructions. Drives high CPU usage.`,
          recommendation: `Reinstall MySQL natively: \n\`\`\`bash\nbrew uninstall mysql && brew install mysql\n\`\`\``
        };
      case 'nginx':
        return {
          issue: `Nginx web server${serviceSuffix} is emulating Intel code, increasing latency on static routes.`,
          recommendation: `Reinstall Nginx natively: \n\`\`\`bash\nbrew uninstall nginx && brew install nginx\n\`\`\``
        };
      case 'python':
      case 'python@3.11':
      case 'python@3.10':
      case 'python@3.9':
        return {
          issue: `Python compiler is emulating x86_64, rendering all compiled C extensions slow.`,
          recommendation: `Reinstall python dependencies: \n\`\`\`bash\nbrew reinstall ${normName}\n\`\`\``
        };
      case 'wget':
        return {
          issue: 'Wget is running emulated code.',
          recommendation: `Rebuild wget for Apple Silicon: \n\`\`\`bash\nbrew reinstall wget\n\`\`\``
        };
      default:
        return {
          issue: `${name}${serviceSuffix} is compiled for Intel Only. This suggests Homebrew was installed under a Rosetta terminal session inside /usr/local.`,
          recommendation: `If most of your Brew packages are Intel Only, we recommend installing Homebrew natively into /opt/homebrew: \n\`\`\`bash\n/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"\n\`\`\``
        };
    }
  }

  if (type === 'npm-native-addon') {
    switch (normName.split(' ')[0]) {
      case 'sqlite3':
        return {
          issue: 'The package relies on sqlite3 compiled native addon .node binary compiled for Intel emulation.',
          recommendation: `Re-run npm install under a native terminal window to compile arm64 bindings: \n\`\`\`bash\nnpm rebuild sqlite3 --global\n\`\`\``
        };
      case 'sharp':
        return {
          issue: 'Sharp image processor is utilizing an x86_64 version of libvips, slowing down image conversions completely.',
          recommendation: `Force clean build of native sharp bindings: \n\`\`\`bash\nnpm rebuild sharp --global\n\`\`\``
        };
      case 'node-sass':
        return {
          issue: 'Legacy node-sass compiled binding is emulating Intel code.',
          recommendation: 'node-sass is deprecated. We strongly recommend migrating to the modern, faster native Dart sass library: \n\`\`\`bash\nnpm uninstall -g node-sass && npm install -g sass\n\`\`\''
        };
      case 'canvas':
        return {
          issue: 'Canvas library npm module bindings compiled for Intel nodes.',
          recommendation: `Rebuilt with native arm64 toolchain: \n\`\`\`bash\nnpm rebuild canvas --global\n\`\`\``
        };
      case 'electron':
        return {
          issue: 'Electron binary is launching under Rosetta 2 emulation.',
          recommendation: `Add electron with arm64 native settings or run: \n\`\`\`bash\nnpm install -g electron --arch=arm64\n\`\`\``
        };
      default:
        return {
          issue: `Native C++ addon binaries inside '${name}' are compiled for x86_64 architecture.`,
          recommendation: `Rebuild the module using native arm64 compilers: \n\`\`\`bash\nnpm rebuild ${name.split(' ')[0]} --global\n\`\`\``
        };
    }
  }

  return {
    issue: `Running ${name} under Rosetta emulations.`,
    recommendation: 'Reinstall or rebuild dependencies globally using a native terminal window.'
  };
};

/**
 * Highly robust client-side parser that reads formatted log from tracker
 */
export const parseTrackerLog = (log: string): ParseResult => {
  const itemsToMigrate: AuditedItem[] = [];
  const reasons: string[] = [];
  
  let currentModule: 'applications' | 'homebrew' | 'npm' | null = null;
  const lines = log.split('\n');

  let stats = {
    universal: 0,
    arm64: 0,
    intel: 0,
    jsOnly: 0,
    unknown: 0
  };

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();

    if (line.includes('MODULE 1:')) {
      currentModule = 'applications';
      continue;
    } else if (line.includes('MODULE 2:')) {
      currentModule = 'homebrew';
      continue;
    } else if (line.includes('MODULE 3:')) {
      currentModule = 'npm';
      continue;
    }

    if (!line || line.startsWith('===') || line.startsWith('---') || line.startsWith('Application Name') || line.startsWith('Command/Service Name') || line.startsWith('Package Name')) {
      continue;
    }

    // Parse the separated lines: "Item Name             | Architecture"
    if (line.includes('|')) {
      const parts = line.split('|');
      if (parts.length >= 2) {
        const name = parts[0].trim();
        const arch = parts[1].trim();

        if (!name || !arch) continue;

        let type: 'application' | 'brew-binary' | 'brew-service' | 'npm-native-addon' = 'application';
        let detailArch = arch;

        if (currentModule === 'applications') {
          type = 'application';
        } else if (currentModule === 'homebrew') {
          if (name.includes('(Service)')) {
            type = 'brew-service';
          } else {
            type = 'brew-binary';
          }
        } else if (currentModule === 'npm') {
          type = name.includes('[') ? 'npm-native-addon' : 'application'; // Apparent native addon if it has bracketed binaries
        }

        // Count for rating stats
        if (arch.toLowerCase().includes('universal')) {
          stats.universal++;
        } else if (arch.toLowerCase().includes('apple silicon') || arch.toLowerCase().includes('arm64')) {
          stats.arm64++;
        } else if (arch.toLowerCase().includes('intel only') || arch.toLowerCase().includes('x86_64')) {
          stats.intel++;
        } else if (arch.toLowerCase().includes('javascript') || arch.toLowerCase().includes('agnostic')) {
          stats.jsOnly++;
        } else {
          stats.unknown++;
        }

        // If it is Intel, mark for migration list
        if (arch.toLowerCase().includes('intel') || arch.toLowerCase().includes('x86_64')) {
          const defaults = getStaticRecommendation(name, type);
          itemsToMigrate.push({
            id: `item-${currentModule}-${name.toLowerCase().replace(/[^a-z0-9]/g, '-')}-${i}`,
            name,
            architecture: 'Intel Only (x86_64)',
            type,
            issue: defaults.issue,
            recommendation: defaults.recommendation
          });
        }
      }
    }
  }

  // Deduce Rating
  let rating = 'A+';
  const intelCount = stats.intel;
  const nativeCount = stats.universal + stats.arm64 + stats.jsOnly;
  const total = nativeCount + intelCount;

  if (intelCount === 0) {
    rating = 'A+';
    reasons.push('Pristine 100% native environment. Zero Rosetta 2 binaries running on this host.');
  } else {
    const ratio = nativeCount / total;
    if (ratio >= 0.9) {
      rating = 'A-';
      reasons.push('Excellent compliance. Only minor apps or packages still require Intel emulations.');
    } else if (ratio >= 0.75) {
      rating = 'B';
      reasons.push('Good overall performance, but background services or tools exhibit emulation bottlenecks.');
    } else if (ratio >= 0.5) {
      rating = 'C';
      reasons.push('Moderate overhead. Rosetta 2 emulator is working hard. Several primary application workflows are emulated.');
    } else {
      rating = 'F';
      reasons.push('Heavy emulation detected! Your computer is executing most modules in sub-optimal emulated mode.');
    }
  }

  if (intelCount > 0) {
    reasons.push(`Detected ${intelCount} Intel Only (x86_64) elements running under Rosetta emulation payload.`);
  }

  // If there are homebrew intel items, check prefix recommendations
  const brewIntelCount = itemsToMigrate.filter(item => item.type === 'brew-binary' || item.type === 'brew-service').length;
  if (brewIntelCount > 2) {
    reasons.push('Homebrew dependencies show persistent Intel compilation. Standard Rosetta shell installation is highly likely.');
  }

  return {
    overallRating: rating,
    totalIssuesCount: intelCount,
    reasons,
    itemsToMigrate,
    generalAdvice: `### Systems Analyst Diagnosis:
Your system registers **${nativeCount} native packages** and **${intelCount} legacy Intel binaries**. 
${intelCount > 0 ? `
#### Primary Bottlenecks:
1. **Performance Penalties**: Applications running on Rosetta under emulation can take up to 40% performance hits, experience higher battery draw, and suffer startup lag.
2. **Global Package Managers**: ${brewIntelCount > 0 ? `Homebrew packages are compiling or fetching x86_64 formats. This implies Homebrew is executing in \`/usr/local\` rather than the correct Silicon path at \`/opt/homebrew\`.` : `Your CLI packages show occasional obsolete compilation configurations.`}

#### Quick Rebuild Strategies:
* **Homebrew**: Re-install the system package manager under a native terminal console using \`arch -arm64 bash\`.
* **NPM Node Modules**: Running \`npm rebuild\` inside native directories builds specific local dynamic addons dynamically according to Silicon specifications.
` : `Your developer workspace shows pure absolute harmony. No active background daemon, service, or tool uses the emulation processor. This guarantees maximum battery economy, lowest compile latencies, and total native performance!`}
`
  };
};
