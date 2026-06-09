import React, { useMemo } from 'react';
import { ParseResult } from '../types';
import { ResponsiveContainer, PieChart, Pie, Cell, Tooltip, Legend } from 'recharts';
import { ShieldAlert, ShieldCheck, ListFilter, Search, Award, Cpu, AlertTriangle } from 'lucide-react';

interface MetricsDashboardProps {
  result: ParseResult;
  rawLogs: string;
  filterType: 'all' | 'application' | 'brew-binary' | 'brew-service' | 'npm-native-addon';
  setFilterType: (val: 'all' | 'application' | 'brew-binary' | 'brew-service' | 'npm-native-addon') => void;
  searchQuery: string;
  setSearchQuery: (val: string) => void;
}

export default function MetricsDashboard({
  result,
  rawLogs,
  filterType,
  setFilterType,
  searchQuery,
  setSearchQuery
}: MetricsDashboardProps) {

  // Dynamically calculate actual totals based on raw logs or compiled results
  const metrics = useMemo(() => {
    let universal = 0;
    let arm64 = 0;
    let intel = result.itemsToMigrate.length; // From current parse result
    let jsOnly = 0;
    let total = 0;

    const lines = rawLogs.split('\n');
    lines.forEach(line => {
      if (line.includes('|')) {
        const parts = line.split('|');
        if (parts.length >= 2) {
          const arch = parts[1].trim().toLowerCase();
          if (arch.includes('universal')) universal++;
          else if (arch.includes('apple silicon') || arch.includes('arm64')) arm64++;
          else if (arch.includes('javascript') || arch.includes('agnostic')) jsOnly++;
        }
      }
    });

    total = universal + arm64 + intel + jsOnly;

    return {
      universal,
      arm64,
      intel,
      jsOnly,
      total,
      nativeRatio: total > 0 ? ((universal + arm64 + jsOnly) / total) * 100 : 100
    };
  }, [result, rawLogs]);

  // Design theme variables for Recharts
  const chartData = useMemo(() => {
    return [
      { name: 'Universal', value: metrics.universal, color: '#10b981' }, 
      { name: 'Silicon Native (arm64)', value: metrics.arm64, color: '#06b6d4' },
      { name: 'Intel Emulated (x86_64)', value: metrics.intel, color: '#f43f5e' },
      { name: 'JavaScript Standard', value: metrics.jsOnly, color: '#f59e0b' }
    ].filter(item => item.value > 0);
  }, [metrics]);

  // Color selection formatting for overall scores
  const scoreColors = (score: string) => {
    const s = score.trim().toUpperCase()[0];
    if (s === 'A') return { text: 'text-emerald-400', border: 'border-emerald-500/30', bg: 'bg-emerald-950/20', shadow: 'shadow-emerald-500/10' };
    if (s === 'B') return { text: 'text-cyan-400', border: 'border-cyan-500/30', bg: 'bg-cyan-950/20', shadow: 'shadow-cyan-500/10' };
    if (s === 'C') return { text: 'text-yellow-400', border: 'border-yellow-500/30', bg: 'bg-yellow-950/20', shadow: 'shadow-yellow-500/10' };
    return { text: 'text-rose-400', border: 'border-rose-500/30', bg: 'bg-rose-950/20', shadow: 'shadow-rose-500/10' };
  };

  const scoreTheme = scoreColors(result.overallRating);

  return (
    <div className="space-y-4" id="metrics-dashboard">
      {/* Overview Block */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        {/* Score Badge */}
        <div className={`col-span-1 border rounded-xl p-4 flex flex-col items-center justify-center text-center shadow-lg relative overflow-hidden backdrop-blur-md ${scoreTheme.border} ${scoreTheme.bg} ${scoreTheme.shadow}`}>
          <div className="absolute top-1.5 right-1.5">
            <Award className="w-4 h-4 text-gray-500/40" />
          </div>
          <span className="text-2xs font-mono uppercase text-gray-400 tracking-wider">Mac Compliance Grade</span>
          <div className={`text-4xl font-display font-extrabold tracking-tight mt-1.5 animate-pulse ${scoreTheme.text}`}>
            {result.overallRating}
          </div>
          <span className="text-3xs text-gray-500 mt-1 font-mono">
            {metrics.intel === 0 ? 'Full Silicon Pure' : `${metrics.intel} Emulated binaries`}
          </span>
        </div>

        {/* Compliance Gauge */}
        <div className="border border-gray-800 bg-[#111827] rounded-xl p-4 flex flex-col justify-between relative shadow-lg">
          <div className="flex items-center justify-between text-2xs uppercase tracking-wider font-semibold text-gray-400 font-mono">
            <span>Silicon Native Ratio</span>
            <Cpu className="w-4 h-4 text-cyan-400" />
          </div>
          <div className="flex items-baseline gap-1 mt-3">
            <span className="text-4xl font-display font-bold text-white tracking-tight">
              {metrics.nativeRatio.toFixed(0)}%
            </span>
          </div>
          <div className="w-full bg-gray-950 h-2.5 rounded-full overflow-hidden mt-3 border border-gray-900">
            <div
              className={`h-full rounded-full transition-all duration-500 ${
                metrics.nativeRatio > 85 ? 'bg-emerald-500' : metrics.nativeRatio > 60 ? 'bg-cyan-500' : 'bg-rose-500'
              }`}
              style={{ width: `${metrics.nativeRatio}%` }}
            ></div>
          </div>
        </div>

        {/* Audited Total Counter */}
        <div className="border border-gray-800 bg-[#111827] rounded-xl p-4 flex flex-col justify-between relative shadow-lg">
          <div className="flex items-center justify-between text-2xs uppercase tracking-wider font-semibold text-gray-400 font-mono">
            <span>Total Units Visited</span>
            <span className="w-1.5 h-1.5 rounded-full bg-green-500 animate-pulse"></span>
          </div>
          <div className="mt-3">
            <span className="text-4xl font-display font-bold text-white tracking-tight">
              {metrics.total}
            </span>
          </div>
          <span className="text-3xs text-gray-500 font-mono block mt-3">
            Includes apps, formula processes, packages.
          </span>
        </div>

        {/* Bottlenecks Counter */}
        <div className="border border-gray-800 bg-[#111827] rounded-xl p-4 flex flex-col justify-between relative shadow-lg">
          <div className="flex items-center justify-between text-2xs uppercase tracking-wider font-semibold text-gray-400 font-mono">
            <span>Emulated Hot daemons</span>
            <AlertTriangle className={`w-4 h-4 ${metrics.intel > 0 ? 'text-rose-500' : 'text-gray-600'}`} />
          </div>
          <div className="mt-3">
            <span className={`text-4xl font-display font-bold tracking-tight ${metrics.intel > 0 ? 'text-rose-500' : 'text-emerald-400'}`}>
              {metrics.intel}
            </span>
          </div>
          <span className="text-3xs text-gray-500 font-mono block mt-3">
            Requires processor compilation overrides.
          </span>
        </div>
      </div>

      {/* Visual Charts Row */}
      <div className="grid grid-cols-1 md:grid-cols-12 gap-4">
        {/* Core Reasons list */}
        <div className="md:col-span-7 border border-gray-800 bg-[#111827] rounded-xl p-5 shadow-lg flex flex-col">
          <label className="text-xs font-mono uppercase text-gray-400 tracking-wider block mb-3 font-semibold">
            Health Check Diagnosis Reasons
          </label>
          <div className="space-y-2.5 flex-1 overflow-y-auto max-h-[175px] scrollbar-thin">
            {result.reasons.map((rec, idx) => (
              <div key={idx} className="flex gap-2.5 items-start p-2.5 rounded-lg bg-gray-950/60 border border-gray-900 text-2xs leading-relaxed text-gray-300">
                {result.overallRating.includes('A') && metrics.intel === 0 ? (
                  <ShieldCheck className="w-4 h-4 text-emerald-400 shrink-0 mt-0.5" />
                ) : (
                  <ShieldAlert className="w-4 h-4 text-indigo-400 shrink-0 mt-0.5" />
                )}
                <span className="font-mono text-gray-300">{rec}</span>
              </div>
            ))}
          </div>
        </div>

        {/* Recharts Pie Visualization */}
        <div className="md:col-span-5 border border-gray-800 bg-[#111827] rounded-xl p-5 shadow-lg h-[240px] flex flex-col">
          <label className="text-xs font-mono uppercase text-gray-400 tracking-wider block mb-1 font-semibold">
            Arch Allocation Share
          </label>
          <div className="flex-1 w-full h-full relative" style={{ minHeight: '130px' }}>
            {chartData.length === 0 ? (
              <div className="absolute inset-0 flex items-center justify-center text-2xs text-gray-500">
                Data pending. Run scan above.
              </div>
            ) : (
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie
                    data={chartData}
                    cx="50%"
                    cy="45%"
                    innerRadius={35}
                    outerRadius={52}
                    paddingAngle={4}
                    dataKey="value"
                  >
                    {chartData.map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={entry.color} />
                    ))}
                  </Pie>
                  <Tooltip
                    contentStyle={{ background: '#090d16', border: '1px solid #1e293b', borderRadius: '6px', fontSize: '10px', fontStyle: 'normal' }}
                    itemStyle={{ color: '#fff' }}
                  />
                  <Legend
                    verticalAlign="bottom"
                    align="center"
                    iconSize={8}
                    iconType="circle"
                    formatter={(value) => <span className="text-3xs font-mono text-gray-400">{value}</span>}
                  />
                </PieChart>
              </ResponsiveContainer>
            )}
          </div>
        </div>
      </div>

      {/* Filter and Search Bar controller */}
      <div className="bg-[#111827] border border-gray-800 rounded-xl p-4 flex flex-col md:flex-row gap-3.5 items-center justify-between shadow-lg select-none">
        {/* Module filter pills */}
        <div className="flex items-center gap-2 overflow-x-auto w-full md:w-auto scrollbar-none pb-1.5 md:pb-0">
          <span className="text-2xs font-mono uppercase text-gray-400 font-semibold flex items-center gap-1.5 mr-1 shrink-0">
            <ListFilter className="w-3.5 h-3.5 text-indigo-400" />
            Category:
          </span>
          <button
            onClick={() => setFilterType('all')}
            className={`px-3 py-1 rounded-full text-2xs font-mono font-medium border cursor-pointer shrink-0 transition-all ${
              filterType === 'all'
                ? 'bg-indigo-600 text-white border-transparent'
                : 'bg-gray-950 text-gray-400 border-gray-900 hover:border-gray-800 hover:text-white'
            }`}
          >
            All Audits
          </button>
          <button
            onClick={() => setFilterType('application')}
            className={`px-3 py-1 rounded-full text-2xs font-mono font-medium border cursor-pointer shrink-0 transition-all ${
              filterType === 'application'
                ? 'bg-[#1e1a3c] text-indigo-300 border-indigo-900/40 hover:border-indigo-800'
                : 'bg-gray-950 text-gray-400 border-gray-900 hover:border-gray-800 hover:text-white'
            }`}
          >
            M1 Applications
          </button>
          <button
            onClick={() => setFilterType('brew-binary')}
            className={`px-3 py-1 rounded-full text-2xs font-mono font-medium border cursor-pointer shrink-0 transition-all ${
              filterType === 'brew-binary'
                ? 'bg-[#16273c] text-cyan-300 border-cyan-900/40 hover:border-cyan-800'
                : 'bg-gray-950 text-gray-400 border-gray-900 hover:border-gray-800 hover:text-white'
            }`}
          >
            Homebrew Packages
          </button>
          <button
            onClick={() => setFilterType('npm-native-addon')}
            className={`px-3 py-1 rounded-full text-2xs font-mono font-medium border cursor-pointer shrink-0 transition-all ${
              filterType === 'npm-native-addon'
                ? 'bg-[#292211] text-amber-300 border-amber-900/40 hover:border-amber-800'
                : 'bg-gray-950 text-gray-400 border-gray-900 hover:border-gray-800 hover:text-white'
            }`}
          >
            NPM Native Addons
          </button>
        </div>

        {/* Search Input Bar */}
        <div className="relative w-full md:w-[240px]">
          <Search className="absolute left-3 top-2.5 w-3.5 h-3.5 text-gray-500" />
          <input
            type="text"
            placeholder="Search active listings..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full text-2xs font-mono pl-9 pr-3.5 py-2 bg-gray-950 border border-gray-900 rounded-lg text-gray-300 placeholder-gray-600 focus:outline-none focus:border-indigo-500"
          />
        </div>
      </div>
    </div>
  );
}
