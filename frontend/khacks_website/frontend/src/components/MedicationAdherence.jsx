import React, { useState } from 'react';
import { User, Calendar, AlertTriangle, Info } from 'lucide-react';

const MedicationAdherenceDashboard = () => {
  const [selectedPeriod, setSelectedPeriod] = useState('last7days');
  const [groupBy, setGroupBy] = useState('daily');

  // Sample data for the timeline
  const timelineData = [
    { date: 'Jan 18', morning: 'taken', afternoon: 'taken', night: 'taken' },
    { date: 'Jan 19', morning: 'taken', afternoon: 'delayed', night: 'taken' },
    { date: 'Jan 20', morning: 'taken', afternoon: 'taken', night: 'missed' },
    { date: 'Jan 21', morning: 'delayed', afternoon: 'taken', night: 'taken' },
    { date: 'Jan 22', morning: 'taken', afternoon: 'missed', night: 'taken' },
    { date: 'Jan 23', morning: 'taken', afternoon: 'taken', night: 'delayed' },
    { date: 'Jan 24', morning: 'taken', afternoon: 'taken', night: 'taken' },
  ];

  // Medicine-wise adherence data
  const medicineData = [
    { name: 'Metformin', adherence: 95 },
    { name: 'Lisinopril', adherence: 88 },
    { name: 'Atorvastatin', adherence: 75 },
    { name: 'Amlodipine', adherence: 90 },
    { name: 'Omeprazole', adherence: 65 },
  ];

  const getStatusColor = (status) => {
    switch (status) {
      case 'taken':
        return 'bg-green-500';
      case 'delayed':
        return 'bg-orange-400';
      case 'missed':
        return 'bg-red-400';
      default:
        return 'bg-gray-300';
    }
  };

  const getAdherenceColor = (adherence) => {
    if (adherence >= 90) return 'bg-green-500';
    if (adherence >= 75) return 'bg-orange-400';
    return 'bg-red-400';
  };

  return (
    <div className="min-h-screen bg-gray-50 p-6">
      {/* Header */}
      <div className="bg-white rounded-lg shadow-sm p-6 mb-6">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-4">
            <div className="w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center">
              <User className="w-6 h-6 text-blue-600" />
            </div>
            <div>
              <h1 className="text-2xl font-semibold text-gray-900">Patient P1 - Adherence Report</h1>
              <p className="text-gray-500">Last 7 Days Selected</p>
            </div>
          </div>
          <div className="px-4 py-2 bg-green-100 text-green-700 rounded-full font-medium flex items-center gap-2">
            <span className="w-2 h-2 bg-green-500 rounded-full"></span>
            Low Risk
          </div>
        </div>
      </div>

      {/* Filters */}
      <div className="bg-white rounded-lg shadow-sm p-6 mb-6">
        <div className="flex flex-wrap items-center gap-6 mb-6">
          <div className="flex items-center gap-3">
            <span className="text-gray-700 font-medium">Quick Select:</span>
            <button
              onClick={() => setSelectedPeriod('today')}
              className={`px-4 py-2 rounded-lg font-medium transition ${
                selectedPeriod === 'today'
                  ? 'bg-blue-600 text-white'
                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
              }`}
            >
              Today
            </button>
            <button
              onClick={() => setSelectedPeriod('last7days')}
              className={`px-4 py-2 rounded-lg font-medium transition ${
                selectedPeriod === 'last7days'
                  ? 'bg-blue-600 text-white'
                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
              }`}
            >
              Last 7 Days
            </button>
            <button
              onClick={() => setSelectedPeriod('last30days')}
              className={`px-4 py-2 rounded-lg font-medium transition ${
                selectedPeriod === 'last30days'
                  ? 'bg-blue-600 text-white'
                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
              }`}
            >
              Last 30 Days
            </button>
          </div>
          <div className="flex items-center gap-3">
            <span className="text-gray-700 font-medium">Custom:</span>
            <button className="px-4 py-2 bg-gray-100 text-gray-700 rounded-lg flex items-center gap-2 hover:bg-gray-200">
              <Calendar className="w-4 h-4" />
              From
            </button>
            <span className="text-gray-400">→</span>
            <button className="px-4 py-2 bg-gray-100 text-gray-700 rounded-lg flex items-center gap-2 hover:bg-gray-200">
              <Calendar className="w-4 h-4" />
              To
            </button>
          </div>
        </div>

        <div className="flex items-center gap-3">
          <span className="text-gray-700 font-medium">Group by:</span>
          <button
            onClick={() => setGroupBy('daily')}
            className={`px-4 py-2 rounded-lg font-medium transition ${
              groupBy === 'daily'
                ? 'bg-gray-200 text-gray-900'
                : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
            }`}
          >
            Daily
          </button>
          <button
            onClick={() => setGroupBy('weekly')}
            className={`px-4 py-2 rounded-lg font-medium transition ${
              groupBy === 'weekly'
                ? 'bg-gray-200 text-gray-900'
                : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
            }`}
          >
            Weekly
          </button>
          <button
            onClick={() => setGroupBy('monthly')}
            className={`px-4 py-2 rounded-lg font-medium transition ${
              groupBy === 'monthly'
                ? 'bg-gray-200 text-gray-900'
                : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
            }`}
          >
            
            Monthly
          </button>
        </div>
      </div>

      {/* Main Content Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
        {/* Adherence Breakdown */}
        <div className="bg-white rounded-lg shadow-sm p-6">
          <h2 className="text-xl font-semibold text-gray-900 mb-6">Adherence Breakdown</h2>
          <div className="flex justify-center mb-6">
            <svg width="250" height="250" viewBox="0 0 250 250">
              <circle
                cx="125"
                cy="125"
                r="90"
                fill="none"
                stroke="#3B82F6"
                strokeWidth="30"
                strokeDasharray="424 565"
                transform="rotate(-90 125 125)"
              />
              <circle
                cx="125"
                cy="125"
                r="90"
                fill="none"
                stroke="#F59E0B"
                strokeWidth="30"
                strokeDasharray="85 565"
                strokeDashoffset="-424"
                transform="rotate(-90 125 125)"
              />
              <circle
                cx="125"
                cy="125"
                r="90"
                fill="none"
                stroke="#EF4444"
                strokeWidth="30"
                strokeDasharray="56 565"
                strokeDashoffset="-509"
                transform="rotate(-90 125 125)"
              />
            </svg>
          </div>
          <div className="flex justify-center gap-6 mb-4">
            <div className="flex items-center gap-2">
              <div className="w-4 h-4 bg-blue-500 rounded"></div>
              <span className="text-gray-700">Taken</span>
            </div>
            <div className="flex items-center gap-2">
              <div className="w-4 h-4 bg-orange-400 rounded"></div>
              <span className="text-gray-700">Delayed</span>
            </div>
            <div className="flex items-center gap-2">
              <div className="w-4 h-4 bg-red-400 rounded"></div>
              <span className="text-gray-700">Missed</span>
            </div>
          </div>
        </div>

        {/* Daily Adherence Timeline */}
        <div className="bg-white rounded-lg shadow-sm p-6">
          <h2 className="text-xl font-semibold text-gray-900 mb-6">Daily Adherence Timeline</h2>
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="text-gray-600 text-sm">
                  <th className="text-left pb-4 font-medium">Date</th>
                  <th className="text-center pb-4 font-medium">Morning</th>
                  <th className="text-center pb-4 font-medium">Afternoon</th>
                  <th className="text-center pb-4 font-medium">Night</th>
                </tr>
              </thead>
              <tbody>
                {timelineData.map((row, idx) => (
                  <tr key={idx} className="border-t border-gray-100">
                    <td className="py-3 text-gray-700 font-medium">{row.date}</td>
                    <td className="py-3">
                      <div className={`h-10 rounded-lg ${getStatusColor(row.morning)}`}></div>
                    </td>
                    <td className="py-3">
                      <div className={`h-10 rounded-lg ${getStatusColor(row.afternoon)}`}></div>
                    </td>
                    <td className="py-3">
                      <div className={`h-10 rounded-lg ${getStatusColor(row.night)}`}></div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>

      {/* Bottom Section */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Risk Indicator */}
        <div className="bg-white rounded-lg shadow-sm p-6">
          <h2 className="text-xl font-semibold text-gray-900 mb-6">Risk Indicator</h2>
          
          <div className="mb-6">
            <div className="relative w-full h-32">
              <svg width="100%" height="130" viewBox="0 0 200 130">
                <defs>
                  <linearGradient id="gaugeGradient" x1="0%" y1="0%" x2="100%" y2="0%">
                    <stop offset="0%" stopColor="#22C55E" />
                    <stop offset="50%" stopColor="#F59E0B" />
                    <stop offset="100%" stopColor="#EF4444" />
                  </linearGradient>
                </defs>
                <path
                  d="M 20 110 A 80 80 0 0 1 180 110"
                  fill="none"
                  stroke="url(#gaugeGradient)"
                  strokeWidth="20"
                  strokeLinecap="round"
                />
                <line
                  x1="100"
                  y1="110"
                  x2="50"
                  y2="70"
                  stroke="#1F2937"
                  strokeWidth="3"
                  strokeLinecap="round"
                />
                <circle cx="100" cy="110" r="8" fill="#1F2937" />
              </svg>
            </div>
            <div className="flex justify-between text-sm text-gray-600 px-4">
              <span>Low</span>
              <span>Medium</span>
              <span>High</span>
            </div>
          </div>

          <div className="text-center mb-6">
            <div className="inline-flex items-center gap-2 px-4 py-2 bg-green-100 text-green-700 rounded-full font-medium mb-2">
              <span className="w-2 h-2 bg-green-500 rounded-full"></span>
              Low Risk
            </div>
            <div className="text-5xl font-bold text-gray-900 mb-2">92%</div>
            <div className="text-gray-600">Overall Adherence</div>
          </div>

          <div className="space-y-3">
            <div className="flex items-start gap-2 p-3 bg-orange-50 rounded-lg">
              <AlertTriangle className="w-5 h-5 text-orange-500 shrink-0 mt-0.5" />
              <p className="text-sm text-orange-700">Morning shows higher missed frequency</p>
            </div>
            <div className="flex items-start gap-2 p-3 bg-orange-50 rounded-lg">
              <AlertTriangle className="w-5 h-5 text-orange-500 shrink-0 mt-0.5" />
              <p className="text-sm text-orange-700">Weekends lower than weekdays</p>
            </div>
          </div>
        </div>

        {/* Medicine-wise Adherence */}
        <div className="bg-white rounded-lg shadow-sm p-6">
          <h2 className="text-xl font-semibold text-gray-900 mb-6">Medicine-wise Adherence</h2>
          <div className="space-y-4">
            {medicineData.map((medicine, idx) => (
              <div key={idx}>
                <div className="flex justify-between items-center mb-2">
                  <span className="text-gray-700 font-medium">{medicine.name}</span>
                  <span className="text-gray-600 text-sm">{medicine.adherence}%</span>
                </div>
                <div className="w-full bg-gray-200 rounded-full h-3">
                  <div
                    className={`h-3 rounded-full ${getAdherenceColor(medicine.adherence)}`}
                    style={{ width: `${medicine.adherence}%` }}
                  ></div>
                </div>
              </div>
            ))}
          </div>
          <div className="mt-6 p-3 bg-red-50 rounded-lg flex items-start gap-2">
            <Info className="w-5 h-5 text-red-500 shrink-0 mt-0.5" />
            <p className="text-sm text-red-700">Omeprazole shows lowest compliance rate</p>
          </div>
        </div>

        {/* Adherence Trend */}
        <div className="bg-white rounded-lg shadow-sm p-6">
          <h2 className="text-xl font-semibold text-gray-900 mb-6">Adherence Trend</h2>
          
          <div className="mb-4 p-3 bg-blue-50 rounded-lg">
            <p className="text-sm text-blue-700">Adherence remains stable during selected period</p>
          </div>

          <div className="relative h-64 mb-4">
            <svg width="100%" height="100%" viewBox="0 0 300 200" preserveAspectRatio="none">
              <defs>
                <linearGradient id="trendGradient" x1="0%" y1="0%" x2="0%" y2="100%">
                  <stop offset="0%" stopColor="#93C5FD" stopOpacity="0.5" />
                  <stop offset="100%" stopColor="#93C5FD" stopOpacity="0.1" />
                </linearGradient>
              </defs>
              <path
                d="M 0 80 Q 75 70 150 60 T 300 40"
                fill="url(#trendGradient)"
                stroke="none"
              />
              <path
                d="M 0 80 Q 75 70 150 60 T 300 40"
                fill="none"
                stroke="#3B82F6"
                strokeWidth="3"
              />
            </svg>
            <div className="absolute top-0 left-0 right-0 flex justify-between text-xs text-gray-500 px-2">
              <span>100%</span>
            </div>
            <div className="absolute top-1/4 left-0 right-0 flex justify-between text-xs text-gray-500 px-2">
              <span>75%</span>
            </div>
            <div className="absolute top-1/2 left-0 right-0 flex justify-between text-xs text-gray-500 px-2">
              <span>50%</span>
            </div>
            <div className="absolute top-3/4 left-0 right-0 flex justify-between text-xs text-gray-500 px-2">
              <span>25%</span>
            </div>
            <div className="absolute bottom-0 left-0 right-0 flex justify-between text-xs text-gray-500 px-2">
              <span>0%</span>
            </div>
          </div>

          <div className="flex justify-between text-sm text-gray-600 px-2">
            <span>Week 1</span>
            <span>Week 3</span>
            <span>Week 5</span>
            <span>Week 7</span>
          </div>
        </div>
      </div>
    </div>
  );
};

export default MedicationAdherenceDashboard;