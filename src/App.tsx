import React, { useState, useEffect } from 'react';
import { ParseResult } from './types';
import { parseTrackerLog } from './utils/parser';
import ReportAnalyzer from './components/ReportAnalyzer';
import MetricsDashboard from './components/MetricsDashboard';
import RemediationFeed from './components/RemediationFeed';
import { Cpu, Terminal, Download, Github, ChevronRight, Check } from 'lucide-react';

export default function App() {
  const [rawText, setRawText] = useState<string>('');
  const [activeResult, setActiveResult] = useState<ParseResult | null>(null);
  const [isViewerMode, setIsViewerMode] = useState(false);
  const [copied, setCopied] = useState(false);

  // Search & Filter state passed to dashboards
  const [filterType, setFilterType] = useState<'all' | 'application' | 'brew-binary' | 'brew-service' | 'npm-native-addon'>('all');
  const [searchQuery, setSearchQuery] = useState<string>('');

  useEffect(() => {
    // 1. Auto-load from script-generated HTML redirect bridging
    const storedLog = localStorage.getItem('mac-arch-tracker-raw-log');
    if (storedLog) {
      setRawText(storedLog);
      setActiveResult(parseTrackerLog(storedLog));
      setIsViewerMode(true);
      // Clean up so it doesn't persistently load the last scan if refreshed manually
      localStorage.removeItem('mac-arch-tracker-raw-log');
    }
  }, []);

  const handleAnalysisResult = (result: ParseResult, rawLogs: string) => {
    setActiveResult(result);
    setRawText(rawLogs);
    setIsViewerMode(true);
  };

  const copyInstallCommand = () => {
    navigator.clipboard.writeText('curl -sL https://GAM3RG33K.github.io/apple-arch-tracker/arch-tracker.sh | bash -s -- --report');
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  if (isViewerMode && activeResult) {
    return (
      <div className="min-h-screen text-gray-200 bg-[#070b13] flex flex-col font-sans antialiased selection:bg-indigo-600 selection:text-white" id="mac-arch-tracker-root">
        {/* Universal Top Header bar */}
        <header className="border-b border-gray-900 bg-[#090d16] sticky top-0 z-50 shadow-md select-none">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-3.5 flex items-center justify-between">
            <div className="flex items-center gap-2.5">
              <div className="p-2 rounded bg-gradient-to-br from-indigo-500 to-cyan-400 border border-indigo-400/20 text-white shrink-0 shadow-lg shadow-indigo-950/20">
                <Cpu className="w-5 h-5 stroke-[2]" />
              </div>
              <div>
                <div className="flex items-center gap-1.5">
                  <h1 className="text-md sm:text-lg font-display font-bold text-white tracking-tight">
                    Mac Architecture Tracker
                  </h1>
                </div>
                <p className="hidden sm:block text-3xs text-gray-400">
                  Offline Report Diagnostic Viewer
                </p>
              </div>
            </div>

            <div className="flex items-center gap-4.5">
              <button
                onClick={() => setIsViewerMode(false)}
                className="text-2xs font-mono bg-gray-950 hover:bg-gray-900 hover:text-white border border-gray-800 rounded px-2.5 py-1.5 font-medium transition-all"
              >
                &larr; Back to Landing
              </button>
            </div>
          </div>
        </header>

        {/* Dashboard workspace */}
        <main className="flex-1 max-w-7xl w-full mx-auto px-4 sm:px-6 lg:px-8 py-6 space-y-6">
          <MetricsDashboard
            result={activeResult}
            rawLogs={rawText}
            filterType={filterType}
            setFilterType={setFilterType}
            searchQuery={searchQuery}
            setSearchQuery={setSearchQuery}
          />
          <RemediationFeed
            result={activeResult}
            filterType={filterType}
            searchQuery={searchQuery}
          />
        </main>
      </div>
    );
  }

  return (
    <div className="min-h-screen text-gray-200 bg-[#070b13] flex flex-col font-sans antialiased selection:bg-indigo-600 selection:text-white">
      {/* Landing Page Hero */}
      <header className="border-b border-gray-900 bg-[#090d16] relative overflow-hidden">
        {/* Background glow */}
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[800px] h-[300px] bg-indigo-600/10 blur-[100px] rounded-full pointer-events-none"></div>
        
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16 lg:py-24 relative z-10 text-center flex flex-col items-center">
          <div className="p-3 mb-6 rounded-2xl bg-gradient-to-br from-indigo-500/20 to-cyan-400/20 border border-indigo-400/30 text-cyan-400 inline-block shadow-2xl">
            <Cpu className="w-10 h-10 stroke-[1.5]" />
          </div>
          <h1 className="text-4xl sm:text-5xl lg:text-6xl font-display font-extrabold text-white tracking-tight leading-tight mb-4 max-w-3xl">
            Identify Emulated Binaries Slowing Down Your Mac
          </h1>
          <p className="text-lg text-gray-400 max-w-2xl mx-auto mb-10 leading-relaxed">
            A standalone, offline-first command line utility. Audit your entire Apple Silicon system for legacy Intel (x86_64) workloads draining battery and CPU cycles.
          </p>

          {/* Download Command Line */}
          <div className="bg-black/60 border border-gray-800 rounded-xl p-2 pl-4 pr-2 flex items-center justify-between w-full max-w-2xl backdrop-blur-md shadow-2xl">
            <div className="flex items-center gap-3 overflow-hidden">
              <Terminal className="w-5 h-5 text-gray-500 shrink-0" />
              <code className="text-xs sm:text-sm font-mono text-cyan-300 truncate whitespace-nowrap">
                curl -sL https://GAM3RG33K.github.io/apple-arch-tracker/arch-tracker.sh | bash -s -- --report
              </code>
            </div>
            <button
              onClick={copyInstallCommand}
              className="ml-4 shrink-0 bg-indigo-600 hover:bg-indigo-500 text-white p-2 sm:px-4 sm:py-2.5 rounded-lg text-sm font-medium transition flex items-center gap-2"
            >
              {copied ? (
                <><Check className="w-4 h-4" /> <span className="hidden sm:inline">Copied</span></>
              ) : (
                <><Download className="w-4 h-4" /> <span className="hidden sm:inline">Copy Script</span></>
              )}
            </button>
          </div>
          <p className="mt-4 text-xs font-mono text-gray-500">
            Zero telemetry. Zero dependencies. Open source shell logic.
          </p>
        </div>
      </header>

      {/* Manual Upload Section */}
      <main className="flex-1 max-w-4xl w-full mx-auto px-4 py-16">
        <div className="space-y-6">
          <div className="text-center">
            <h2 className="text-2xl font-display font-bold text-white mb-2">View an Existing Report</h2>
            <p className="text-sm text-gray-400">
              Did you run the script manually? Paste your log output here to generate the interactive dashboard natively in your browser.
            </p>
          </div>
          
          <ReportAnalyzer onAnalysisResult={handleAnalysisResult} />
        </div>
      </main>

      <footer className="border-t border-gray-900 bg-[#090d16]/30 py-8 text-center text-xs text-gray-500 font-mono">
        <div className="max-w-7xl mx-auto px-4 flex flex-col items-center gap-2">
          <div className="flex items-center gap-2 text-gray-400">
            <Github className="w-4 h-4" />
            <span>Open Source on GitHub</span>
          </div>
          <p>© {new Date().getFullYear()} Mac Architecture Audit Toolchain.</p>
        </div>
      </footer>
    </div>
  );
}
