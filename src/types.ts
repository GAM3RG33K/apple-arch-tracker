export interface ScriptConfig {
  scanApplications: boolean;
  scanHomebrew: boolean;
  scanNpmGlobals: boolean;
  customPath: string;
  outputFormat: 'terminal' | 'markdown' | 'csv';
  excludeFolders: string;
  enableColors: boolean;
}

export interface AuditedItem {
  id: string;
  name: string;
  architecture: 'Universal' | 'Apple Silicon (arm64)' | 'Intel Only (x86_64)' | 'JavaScript (Platform Agnostic)' | 'Unknown' | string;
  details?: string;
  type: 'application' | 'brew-binary' | 'brew-service' | 'npm-native-addon';
  issue?: string;
  recommendation?: string;
  path?: string;
}

export interface ParseResult {
  overallRating: string;
  totalIssuesCount: number;
  reasons: string[];
  itemsToMigrate: AuditedItem[];
  generalAdvice: string;
}

export interface MachineProfile {
  id: string;
  title: string;
  desc: string;
  icon: string;
  stats: {
    universal: number;
    arm64: number;
    intel: number;
    jsOnly: number;
  };
  log: string;
}
