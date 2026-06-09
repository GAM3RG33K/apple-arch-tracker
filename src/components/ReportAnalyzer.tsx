import React, { useState } from 'react';
import { ParseResult } from '../types';
import { parseTrackerLog } from '../utils/parser';
import { Terminal, Copy, Check, UploadCloud, RefreshCw } from 'lucide-react';

interface ReportAnalyzerProps {
  onAnalysisResult: (result: ParseResult, rawText: string) => void;
}

export default function ReportAnalyzer({ onAnalysisResult }: ReportAnalyzerProps) {
  const [inputText, setInputText] = useState('');
  const [isProcessing, setIsProcessing] = useState(false);

  const handleParse = () => {
    if (!inputText.trim()) return;
    setIsProcessing(true);
    
    // Process completely locally and synchronously
    setTimeout(() => {
      const result = parseTrackerLog(inputText);
      onAnalysisResult(result, inputText);
      setIsProcessing(false);
    }, 400); // slight simulated delay for UX feedback
  };

  return (
    <div className="bg-[#111827] border border-gray-800 rounded-xl overflow-hidden shadow-lg h-full flex flex-col">
      <div className="px-4 py-3 bg-[#0d1525] border-b border-gray-800/60 flex items-center gap-2">
        <Terminal className="w-4 h-4 text-gray-500" />
        <h3 className="text-xs font-mono uppercase tracking-wider font-bold text-white">Manual Log Importer</h3>
      </div>
      
      <div className="p-4 flex-1 flex flex-col h-full">
        <label className="text-xs font-semibold text-gray-300 block mb-2 cursor-pointer">
          Paste RAW Terminal Session Output:
        </label>
        <textarea
          value={inputText}
          onChange={(e) => setInputText(e.target.value)}
          placeholder="PASTE LOG TEXT HERE...
=================================================================================
MODULE 1: MAC OBJECTS & APPLICATIONS
Application Name                                        | Architecture
---------------------------------------------------------------------------------
Docker                                                  | Apple Silicon (arm64)
..."
          className="flex-1 w-full bg-gray-950 border border-gray-800 rounded-lg p-4 text-2xs font-mono text-gray-300 placeholder-gray-700 focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50 resize-none min-h-[300px]"
        />
        
        <div className="mt-4 pt-4 border-t border-gray-850">
          <button
            onClick={handleParse}
            disabled={!inputText.trim() || isProcessing}
            className="w-full flex items-center justify-center gap-2 py-3 px-6 rounded-lg text-sm font-semibold transition-all shadow-lg active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed bg-indigo-600 hover:bg-indigo-500 text-white shadow-indigo-900/20"
          >
            {isProcessing ? (
              <><RefreshCw className="w-4 h-4 animate-spin" /> Processing Audit Log Locally...</>
            ) : (
              <><UploadCloud className="w-4 h-4" /> Parse Report Natively</>
            )}
          </button>
        </div>
      </div>
    </div>
  );
}
