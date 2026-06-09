import React, { useState } from 'react';
import { ParseResult } from '../types';
import Markdown from 'react-markdown';
import { Copy, Check, ChevronDown, ChevronUp, AlertCircle, Info, Beer, Cpu, TerminalSquare, Compass } from 'lucide-react';

interface RemediationFeedProps {
  result: ParseResult;
  filterType: 'all' | 'application' | 'brew-binary' | 'brew-service' | 'npm-native-addon';
  searchQuery: string;
}

export default function RemediationFeed({ result, filterType, searchQuery }: RemediationFeedProps) {
  const [copiedId, setCopiedId] = useState<string | null>(null);
  const [expandedId, setExpandedId] = useState<string | null>(null);

  const handleCopyCommand = (command: string, id: string) => {
    // Extract command from markdown formatting if present
    const cleanCommand = command.replace(/```bash\n|```/g, '').trim();
    navigator.clipboard.writeText(cleanCommand);
    setCopiedId(id);
    setTimeout(() => setCopiedId(null), 2000);
  };

  const getModuleBadge = (type: string) => {
    switch (type) {
      case 'brew-binary':
        return (
          <span className="flex items-center gap-1 text-3xs font-mono font-medium px-2 py-0.5 rounded-full bg-[#16273c] text-cyan-300 border border-cyan-800/40">
            <Beer className="w-3 h-3" /> Formula Binary
          </span>
        );
      case 'brew-service':
        return (
          <span className="flex items-center gap-1 text-3xs font-mono font-medium px-2 py-0.5 rounded-full bg-cyan-950/20 text-cyan-400 border border-cyan-800/30">
            <Beer className="w-3 h-3 animate-pulse" /> Brew Service
          </span>
        );
      case 'npm-native-addon':
        return (
          <span className="flex items-center gap-1 text-3xs font-mono font-medium px-2 py-0.5 rounded-full bg-[#292211] text-amber-300 border border-amber-800/40">
            <TerminalSquare className="w-3 h-3" /> NPM Binary Addon
          </span>
        );
      default:
        return (
          <span className="flex items-center gap-1 text-3xs font-mono font-medium px-2 py-0.5 rounded-full bg-[#1e1a3c] text-indigo-300 border border-indigo-900/40">
            <Compass className="w-3 h-3" /> Application
          </span>
        );
    }
  };

  // Filter & Search Logic
  const filteredItems = result.itemsToMigrate.filter(item => {
    // Filter type matches
    if (filterType !== 'all') {
      if (filterType === 'brew-binary' && item.type !== 'brew-binary' && item.type !== 'brew-service') {
        return false;
      }
      if (filterType !== 'brew-binary' && item.type !== filterType) {
        return false;
      }
    }
    // Search query matches
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      return (
        item.name.toLowerCase().includes(q) ||
        (item.issue && item.issue.toLowerCase().includes(q)) ||
        (item.recommendation && item.recommendation.toLowerCase().includes(q))
      );
    }
    return true;
  });

  return (
    <div className="space-y-4" id="remediation-feed">
      {/* 2. Advisory block (Collapsible) */}
      {result.generalAdvice && (
        <div className="bg-[#090d16] border border-[#1e293b]/60 rounded-xl overflow-hidden shadow-lg">
          <div className="px-5 py-3 bg-[#0d1525] border-b border-gray-800/60 flex items-center gap-2">
            <Cpu className="w-4 h-4 text-cyan-400 animate-pulse" />
            <h3 className="text-xs font-mono uppercase tracking-wider font-bold text-white">
              Systems Analyst Report & Guide
            </h3>
          </div>
          <div className="p-5 overflow-y-auto max-h-[380px] text-xs leading-relaxed text-gray-300 space-y-3 font-paragraph select-text scrollbar-thin">
            <div className="markdown-body prose prose-invert prose-xs max-w-none text-gray-300 font-sans prose-headings:font-display prose-headings:text-white prose-headings:font-bold prose-code:font-mono prose-code:text-[#fcd34d] prose-code:bg-gray-900 prose-code:px-1.5 prose-code:py-0.5 prose-code:rounded">
              <Markdown>{result.generalAdvice}</Markdown>
            </div>
          </div>
        </div>
      )}

      {/* 3. Filtered items list */}
      <div className="space-y-3">
        <div className="flex items-center justify-between px-1">
          <label className="text-xs font-mono uppercase text-gray-400 tracking-wider font-semibold">
            Identified Emulation Issues ({filteredItems.length})
          </label>
          <span className="text-3xs text-gray-500 font-mono">Click card to expand step instructions</span>
        </div>

        {filteredItems.length === 0 ? (
          <div className="p-8 text-center rounded-xl border border-gray-850 bg-[#111827]/40 text-gray-500 select-none space-y-1">
            <AlertCircle className="w-7 h-7 mx-auto stroke-1 text-emerald-500" />
            <p className="text-xs font-semibold text-gray-300">Compliance Clean!</p>
            <p className="text-3xs text-gray-500 leading-normal">
              No Intel emulating binaries found in the active workspace. Everything is executing natively!
            </p>
          </div>
        ) : (
          <div className="grid grid-cols-1 gap-2.5">
            {filteredItems.map((item) => {
              const isExpanded = expandedId === item.id;
              
              // Extract clean CLI recommendation in case it is code-blocked
              const isCommandLine = item.recommendation?.includes('```') || item.recommendation?.includes('brew') || item.recommendation?.includes('npm');

              return (
                <div
                  key={item.id}
                  className={`border rounded-lg transition-all duration-200 bg-[#111827] cursor-pointer overflow-hidden ${
                    isExpanded
                      ? 'border-indigo-500 shadow-lg shadow-indigo-950/10'
                      : 'border-gray-800 hover:border-gray-700 hover:bg-[#151c2e]'
                  }`}
                  onClick={() => setExpandedId(isExpanded ? null : item.id)}
                >
                  {/* Card Header Header Summary */}
                  <div className="p-4 flex items-center gap-3">
                    <div className="p-2 rounded bg-black/40 border border-gray-850 shrink-0 font-mono text-xs font-bold text-rose-400">
                      x86
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex flex-wrap items-center gap-2 mb-0.5">
                        <span className="font-semibold text-xs text-white truncate max-w-[180px]">
                          {item.name}
                        </span>
                        {getModuleBadge(item.type)}
                      </div>
                      <p className="text-2xs text-gray-400 truncate max-w-[340px] leading-normal">
                        {item.issue}
                      </p>
                      {item.path && (
                        <p className="text-3xs text-gray-500 font-mono mt-0.5 truncate max-w-[340px]">
                          {item.path}
                        </p>
                      )}
                    </div>
                    <div className="shrink-0 text-gray-500 hover:text-white transition-colors">
                      {isExpanded ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
                    </div>
                  </div>

                  {/* Expanded Custom Help Feed */}
                  {isExpanded && (
                    <div className="px-4 pb-4 pt-1.5 border-t border-gray-900 bg-gray-950/40 space-y-3 cursor-default" onClick={(e) => e.stopPropagation()}>
                      {/* Diagnostic Summary */}
                      <div className="text-2xs leading-relaxed text-gray-300">
                        <span className="font-semibold text-rose-400 block mb-0.5 font-mono">Emulation Diagnostic:</span>
                        {item.issue}
                      </div>

                      {/* Installation Path */}
                      {item.path && (
                        <div className="text-2xs leading-relaxed text-gray-300">
                          <span className="font-semibold text-gray-400 block mb-0.5 font-mono">Installation Path:</span>
                          <code className="text-cyan-300 font-mono bg-black/40 px-1.5 py-0.5 rounded">{item.path}</code>
                        </div>
                      )}

                      {/* Action command if present */}
                      {item.recommendation && (
                        <div className="space-y-2">
                          <span className="text-2xs font-semibold text-emerald-400 block font-mono">Remediation Script:</span>
                          
                          {isCommandLine ? (
                            <div className="flex items-center bg-black/80 border border-gray-850 rounded overflow-hidden">
                              <code className="flex-1 font-mono text-2xs text-amber-300 p-2.5 whitespace-pre break-all overflow-x-auto">
                                {item.recommendation.replace(/```bash\n|```/g, '').trim()}
                              </code>
                              <button
                                onClick={() => handleCopyCommand(item.recommendation || '', item.id)}
                                className="p-2.5 text-gray-500 hover:text-white hover:bg-gray-900 border-l border-gray-850 cursor-pointer transition-colors"
                              >
                                {copiedId === item.id ? (
                                  <Check className="w-4 h-4 text-green-400" />
                                ) : (
                                  <Copy className="w-4 h-4" />
                                )}
                              </button>
                            </div>
                          ) : (
                            <div className="p-2.5 rounded bg-black/40 border border-gray-900 text-2xs leading-relaxed text-gray-300">
                              {item.recommendation}
                            </div>
                          )}
                        </div>
                      )}

                      {/* General emulation details */}
                      <div className="p-2.5 rounded-md bg-indigo-950/10 border border-indigo-950/40 text-3xs text-indigo-400 leading-normal flex items-start gap-2">
                        <Info className="w-3.5 h-3.5 mt-0.5 shrink-0" />
                        <div>
                          <span className="block font-semibold text-white mb-0.5">Why this matters:</span>
                          Eliminating emulated code frees up processor cycles, reduces launch times, reduces heat dissipation, and gives up to 2x more battery backup.
                        </div>
                      </div>
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
