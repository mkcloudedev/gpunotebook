import { useState, useEffect, useRef } from "react";
import {
  Thermometer,
  Activity,
  HardDrive,
  Zap,
  Cpu,
  AlertCircle,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { Button } from "./ui/button";
import { GPUMonitorBreadcrumb } from "./GPUMonitorBreadcrumb";
import { GPUStatus } from "@/services/gpuService";
import { useGPU } from "@/contexts/GPUContext";

// History length (30 data points = 60 seconds at 2s interval)
const HISTORY_LENGTH = 30;

export const GPUMonitorContent = () => {
  const { gpus: allGpus, processes, isLoading, error, hasGpu, refresh } = useGPU();
  const [selectedGpuIndex, setSelectedGpuIndex] = useState(0);
  const [utilizationHistory, setUtilizationHistory] = useState<number[]>([]);
  const [memoryHistory, setMemoryHistory] = useState<number[]>([]);
  const [temperatureHistory, setTemperatureHistory] = useState<number[]>([]);
  const prevGpusRef = useRef<GPUStatus[]>([]);

  // Get currently selected GPU
  const gpuStatus = allGpus[selectedGpuIndex] || null;

  // Update history when GPU data changes
  useEffect(() => {
    // Only update if gpus actually changed (new data from polling)
    if (allGpus.length > 0 && allGpus !== prevGpusRef.current) {
      const selectedGpu = allGpus[selectedGpuIndex];
      if (selectedGpu) {
        const memoryPercent = selectedGpu.memoryTotal > 0
          ? (selectedGpu.memoryUsed / selectedGpu.memoryTotal) * 100
          : 0;

        setUtilizationHistory((prev) => {
          const next = [...prev, selectedGpu.utilizationGpu];
          return next.slice(-HISTORY_LENGTH);
        });
        setMemoryHistory((prev) => {
          const next = [...prev, memoryPercent];
          return next.slice(-HISTORY_LENGTH);
        });
        setTemperatureHistory((prev) => {
          const next = [...prev, selectedGpu.temperature];
          return next.slice(-HISTORY_LENGTH);
        });
      }
      prevGpusRef.current = allGpus;
    }
  }, [allGpus, selectedGpuIndex]);

  const handleRefresh = () => {
    refresh();
  };

  if (isLoading) {
    return (
      <div className="flex flex-1 items-center justify-center">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary" />
      </div>
    );
  }

  if (!hasGpu || !gpuStatus) {
    return (
      <div className="flex flex-1 flex-col items-center justify-center">
        <Cpu className="h-16 w-16 text-muted-foreground" />
        <h2 className="mt-4 text-xl font-semibold">No GPU Detected</h2>
        <p className="mt-2 text-muted-foreground">
          Connect a CUDA-compatible GPU to view metrics
        </p>
        {error && (
          <div className="mt-4 flex items-center gap-2 rounded-lg border border-destructive/50 bg-destructive/10 px-4 py-2 text-sm text-destructive">
            <AlertCircle className="h-4 w-4" />
            {error}
          </div>
        )}
        <Button className="mt-6" onClick={handleRefresh}>
          <RefreshCw className="mr-2 h-4 w-4" />
          Retry
        </Button>
      </div>
    );
  }

  const memoryPercent = gpuStatus.memoryTotal > 0
    ? (gpuStatus.memoryUsed / gpuStatus.memoryTotal) * 100
    : 0;
  const powerPercent = gpuStatus.powerLimit > 0
    ? (gpuStatus.powerDraw / gpuStatus.powerLimit) * 100
    : 0;

  return (
    <div className="flex flex-1 flex-col overflow-hidden">
      <GPUMonitorBreadcrumb
        gpus={allGpus}
        selectedIndex={selectedGpuIndex}
        onSelectGpu={(index) => {
          setSelectedGpuIndex(index);
          setUtilizationHistory([]);
          setMemoryHistory([]);
          setTemperatureHistory([]);
        }}
        onRefresh={handleRefresh}
      />

      <div className="flex flex-1 overflow-hidden">
        {/* Main content */}
        <div className="flex-1 overflow-auto p-4">
          {/* Metrics Grid - Vehicle-style Gauges */}
          <div className="grid grid-cols-4 gap-4">
            <SpeedometerGauge
              title="GPU Utilization"
              value={gpuStatus.utilizationGpu}
              maxValue={100}
              unit="%"
              subtitle="Compute load"
              color="#3B82F6"
              warningThreshold={70}
              dangerThreshold={90}
              icon={<Activity className="h-3.5 w-3.5" />}
            />
            <SpeedometerGauge
              title="VRAM Usage"
              value={(gpuStatus.memoryUsed || 0) / 1024}
              maxValue={(gpuStatus.memoryTotal || 1) / 1024}
              unit="GB"
              subtitle={`of ${((gpuStatus.memoryTotal || 0) / 1024).toFixed(0)} GB`}
              color="#10B981"
              warningThreshold={70}
              dangerThreshold={90}
              icon={<HardDrive className="h-3.5 w-3.5" />}
            />
            <SpeedometerGauge
              title="Temperature"
              value={gpuStatus.temperature}
              maxValue={100}
              unit="°C"
              subtitle="Core temp"
              color="#F97316"
              warningThreshold={70}
              dangerThreshold={85}
              icon={<Thermometer className="h-3.5 w-3.5" />}
            />
            <SpeedometerGauge
              title="Power Draw"
              value={gpuStatus.powerDraw}
              maxValue={gpuStatus.powerLimit}
              unit="W"
              subtitle={`limit ${gpuStatus.powerLimit}W`}
              color="#EAB308"
              warningThreshold={80}
              dangerThreshold={95}
              icon={<Zap className="h-3.5 w-3.5" />}
            />
          </div>

          {/* History Charts Row */}
          <div className="mt-4 grid grid-cols-2 gap-4">
            <HistoryChart
              title="GPU Utilization History"
              icon={<Activity className="h-4 w-4" />}
              data={utilizationHistory}
              color="#3B82F6"
              currentValue={gpuStatus.utilizationGpu}
              unit="%"
              maxValue={100}
              minValue={0}
              warningThreshold={70}
              dangerThreshold={90}
            />
            <HistoryChart
              title="Temperature History"
              icon={<Thermometer className="h-4 w-4" />}
              data={temperatureHistory}
              color="#F97316"
              currentValue={gpuStatus.temperature}
              unit="°C"
              maxValue={100}
              minValue={30}
              warningThreshold={70}
              dangerThreshold={85}
            />
          </div>
        </div>

        {/* Processes Panel */}
        <div className="w-72 border-l border-border bg-card flex flex-col">
          <div className="flex items-center justify-between border-b border-border p-3">
            <span className="font-semibold text-sm">All GPU Processes</span>
            <span className="text-xs text-muted-foreground">
              {processes.length} active
            </span>
          </div>

          <div className="flex-1 overflow-auto p-2 space-y-1">
            {allGpus.map((gpu, gpuIdx) => {
              const gpuProcesses = processes.filter(p => p.gpuIndex === gpuIdx);
              return (
                <div key={gpu.uuid || gpuIdx}>
                  {/* GPU Header */}
                  <div className="flex items-center gap-2 px-2 py-1.5 bg-muted/50 rounded-md mb-1">
                    <Cpu className="h-3 w-3 text-primary" />
                    <span className="text-xs font-semibold">GPU {gpuIdx}</span>
                    <span className="text-[10px] text-muted-foreground truncate flex-1">
                      {gpu.name.replace("NVIDIA ", "").replace("GeForce ", "")}
                    </span>
                    <span className="text-[10px] text-muted-foreground">
                      {gpuProcesses.length}
                    </span>
                  </div>
                  {/* GPU Processes */}
                  <div className="space-y-1 mb-2">
                    {gpuProcesses.length > 0 ? (
                      gpuProcesses.map((process, index) => (
                        <ProcessRow key={`${process.pid}-${gpuIdx}-${index}`} process={process} />
                      ))
                    ) : (
                      <div className="text-xs text-muted-foreground px-2 py-1">
                        No processes
                      </div>
                    )}
                  </div>
                </div>
              );
            })}
          </div>

          <div className="border-t border-border p-3">
            <div className="rounded-lg border border-primary/30 bg-primary/5 p-3">
              <div className="flex items-center gap-2 mb-3">
                <Zap className="h-4 w-4 text-primary" />
                <span className="text-sm font-medium">Power Summary</span>
              </div>
              <div className="space-y-1 text-xs">
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Current</span>
                  <span>{gpuStatus.powerDraw} W</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Limit</span>
                  <span>{gpuStatus.powerLimit} W</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Efficiency</span>
                  <span className="text-green-500">{powerPercent.toFixed(0)}%</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

// =============================================================================
// SPEEDOMETER GAUGE - Vehicle-style meter
// =============================================================================

interface SpeedometerGaugeProps {
  title: string;
  value: number;
  maxValue: number;
  unit: string;
  subtitle: string;
  color: string;
  warningThreshold?: number;
  dangerThreshold?: number;
  icon: React.ReactNode;
}

const SpeedometerGauge = ({
  title,
  value,
  maxValue,
  unit,
  subtitle,
  color,
  warningThreshold = 70,
  dangerThreshold = 90,
  icon,
}: SpeedometerGaugeProps) => {
  const safeValue = isNaN(value) ? 0 : value;
  const safeMaxValue = isNaN(maxValue) || maxValue === 0 ? 1 : maxValue;
  const percent = Math.min((safeValue / safeMaxValue) * 100, 100);
  const angle = (percent / 100) * 270 - 135; // -135 to 135 degrees

  // Determine color based on thresholds
  const getColor = () => {
    if (percent >= dangerThreshold) return "#EF4444"; // red
    if (percent >= warningThreshold) return "#F59E0B"; // yellow
    return color;
  };

  const currentColor = getColor();

  // Generate tick marks
  const ticks = [];
  for (let i = 0; i <= 10; i++) {
    const tickAngle = (i / 10) * 270 - 135;
    const isMajor = i % 2 === 0;
    const innerRadius = isMajor ? 62 : 66;
    const outerRadius = 72;
    const x1 = 50 + innerRadius * Math.cos((tickAngle * Math.PI) / 180);
    const y1 = 50 + innerRadius * Math.sin((tickAngle * Math.PI) / 180);
    const x2 = 50 + outerRadius * Math.cos((tickAngle * Math.PI) / 180);
    const y2 = 50 + outerRadius * Math.sin((tickAngle * Math.PI) / 180);
    ticks.push({ x1, y1, x2, y2, isMajor, value: Math.round((i / 10) * maxValue) });
  }

  // Arc path for the gauge background
  const describeArc = (x: number, y: number, radius: number, startAngle: number, endAngle: number) => {
    const start = {
      x: x + radius * Math.cos((startAngle * Math.PI) / 180),
      y: y + radius * Math.sin((startAngle * Math.PI) / 180),
    };
    const end = {
      x: x + radius * Math.cos((endAngle * Math.PI) / 180),
      y: y + radius * Math.sin((endAngle * Math.PI) / 180),
    };
    const largeArcFlag = endAngle - startAngle <= 180 ? "0" : "1";
    return `M ${start.x} ${start.y} A ${radius} ${radius} 0 ${largeArcFlag} 1 ${end.x} ${end.y}`;
  };

  return (
    <div className="rounded-xl border border-border bg-gradient-to-b from-card to-background p-4 relative overflow-hidden">
      {/* Glow effect */}
      <div
        className="absolute inset-0 opacity-20 blur-2xl"
        style={{ background: `radial-gradient(circle at 50% 80%, ${currentColor}, transparent 70%)` }}
      />

      {/* Header */}
      <div className="flex items-center justify-between mb-2 relative">
        <div className="flex items-center gap-2">
          <span className="text-sm font-semibold">{title}</span>
        </div>
        <span className={cn(
          "rounded px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider",
          percent >= dangerThreshold ? "bg-red-500/20 text-red-500" :
          percent >= warningThreshold ? "bg-yellow-500/20 text-yellow-500" :
          "bg-green-500/20 text-green-500"
        )}>
          {percent >= dangerThreshold ? "CRITICAL" : percent >= warningThreshold ? "WARNING" : "NORMAL"}
        </span>
      </div>

      {/* Gauge */}
      <div className="relative w-full aspect-square max-w-[160px] mx-auto">
        <svg viewBox="0 0 100 100" className="w-full h-full">
          {/* Outer decorative ring */}
          <circle cx="50" cy="50" r="48" fill="none" stroke="currentColor" strokeOpacity="0.1" strokeWidth="1" />

          {/* Background arc */}
          <path
            d={describeArc(50, 50, 40, -135, 135)}
            fill="none"
            stroke="currentColor"
            strokeOpacity="0.2"
            strokeWidth="8"
            strokeLinecap="round"
          />

          {/* Colored arc segments */}
          <path
            d={describeArc(50, 50, 40, -135, -135 + (270 * warningThreshold) / 100)}
            fill="none"
            stroke={color}
            strokeOpacity="0.3"
            strokeWidth="8"
            strokeLinecap="round"
          />
          <path
            d={describeArc(50, 50, 40, -135 + (270 * warningThreshold) / 100, -135 + (270 * dangerThreshold) / 100)}
            fill="none"
            stroke="#F59E0B"
            strokeOpacity="0.3"
            strokeWidth="8"
            strokeLinecap="round"
          />
          <path
            d={describeArc(50, 50, 40, -135 + (270 * dangerThreshold) / 100, 135)}
            fill="none"
            stroke="#EF4444"
            strokeOpacity="0.3"
            strokeWidth="8"
            strokeLinecap="round"
          />

          {/* Active arc */}
          <path
            d={describeArc(50, 50, 40, -135, -135 + (270 * percent) / 100)}
            fill="none"
            stroke={currentColor}
            strokeWidth="8"
            strokeLinecap="round"
            style={{
              filter: `drop-shadow(0 0 6px ${currentColor})`,
              transition: "all 0.5s ease-out",
            }}
          />

          {/* Tick marks */}
          {ticks.map((tick, i) => (
            <g key={i}>
              <line
                x1={tick.x1}
                y1={tick.y1}
                x2={tick.x2}
                y2={tick.y2}
                stroke="currentColor"
                strokeOpacity={tick.isMajor ? 0.6 : 0.3}
                strokeWidth={tick.isMajor ? 1.5 : 0.75}
              />
              {tick.isMajor && (
                <text
                  x={50 + 52 * Math.cos(((i / 10) * 270 - 135) * Math.PI / 180)}
                  y={50 + 52 * Math.sin(((i / 10) * 270 - 135) * Math.PI / 180)}
                  textAnchor="middle"
                  dominantBaseline="middle"
                  className="fill-muted-foreground"
                  style={{ fontSize: "5px" }}
                >
                  {tick.value}
                </text>
              )}
            </g>
          ))}

          {/* Center circle */}
          <circle cx="50" cy="50" r="20" fill="url(#centerGradient)" />
          <circle cx="50" cy="50" r="18" fill="hsl(var(--card))" />

          {/* Needle */}
          <g
            style={{
              transform: `rotate(${angle}deg)`,
              transformOrigin: '50px 50px',
              transition: 'transform 0.5s ease-out'
            }}
          >
            {/* Needle shadow */}
            <polygon
              points="50,18 47,50 53,50"
              fill="black"
              opacity="0.3"
              transform="translate(1, 1)"
            />
            {/* Needle */}
            <polygon
              points="50,18 47,50 53,50"
              fill={currentColor}
              style={{ filter: `drop-shadow(0 0 4px ${currentColor})` }}
            />
            {/* Needle cap */}
            <circle cx="50" cy="50" r="6" fill={currentColor} />
            <circle cx="50" cy="50" r="4" fill="hsl(var(--card))" />
          </g>

          {/* Gradient definition */}
          <defs>
            <radialGradient id="centerGradient">
              <stop offset="0%" stopColor="hsl(var(--muted))" />
              <stop offset="100%" stopColor="hsl(var(--card))" />
            </radialGradient>
          </defs>
        </svg>

        {/* Center value display */}
        <div className="absolute inset-0 flex flex-col items-center justify-center">
          <div className="text-2xl font-bold tracking-tight" style={{ color: currentColor }}>
            {safeValue.toFixed(0)}
          </div>
          <div className="text-[10px] text-muted-foreground uppercase tracking-wider">{unit}</div>
        </div>
      </div>

      {/* Footer */}
      <div className="flex items-center justify-between mt-2 text-xs">
        <div className="flex items-center gap-1.5 text-muted-foreground">
          {icon}
          <span>{subtitle}</span>
        </div>
        <div className="font-mono text-muted-foreground">
          {percent.toFixed(1)}%
        </div>
      </div>
    </div>
  );
};


// =============================================================================
// ENHANCED HISTORY CHART - Racing Dashboard Style
// =============================================================================

interface HistoryChartProps {
  title: string;
  icon: React.ReactNode;
  data: number[];
  color: string;
  currentValue: number;
  unit: string;
  maxValue?: number;
  minValue?: number;
  warningThreshold?: number;
  dangerThreshold?: number;
}

const HistoryChart = ({
  title,
  icon,
  data,
  color,
  currentValue,
  unit,
  maxValue = 100,
  minValue = 0,
  warningThreshold = 70,
  dangerThreshold = 90,
}: HistoryChartProps) => {
  const percent = ((currentValue - minValue) / (maxValue - minValue)) * 100;
  const getStatusColor = () => {
    if (percent >= dangerThreshold) return "#EF4444";
    if (percent >= warningThreshold) return "#F59E0B";
    return color;
  };
  const statusColor = getStatusColor();

  // Calculate stats
  const avg = data.length > 0 ? data.reduce((a, b) => a + b, 0) / data.length : 0;
  const max = data.length > 0 ? Math.max(...data) : 0;
  const min = data.length > 0 ? Math.min(...data) : 0;

  return (
    <div className="rounded-xl border border-border bg-gradient-to-b from-card to-background overflow-hidden flex flex-col">
      {/* Header */}
      <div className="flex items-center justify-between px-3 py-2 border-b border-border shrink-0">
        <div className="flex items-center gap-2">
          <div
            className="flex h-7 w-7 items-center justify-center rounded-lg"
            style={{ backgroundColor: `${color}20` }}
          >
            <span style={{ color }}>{icon}</span>
          </div>
          <div>
            <div className="font-semibold text-xs">{title}</div>
            <div className="text-[10px] text-muted-foreground">Last {data.length * 2}s</div>
          </div>
        </div>

        {/* Current value badge */}
        <div
          className="flex items-center gap-1.5 rounded-md px-2 py-1"
          style={{ backgroundColor: `${statusColor}15`, border: `1px solid ${statusColor}30` }}
        >
          <div
            className="h-1.5 w-1.5 rounded-full animate-pulse"
            style={{ backgroundColor: statusColor, boxShadow: `0 0 6px ${statusColor}` }}
          />
          <span className="text-base font-bold font-mono" style={{ color: statusColor }}>
            {currentValue.toFixed(1)}
          </span>
          <span className="text-[10px] text-muted-foreground">{unit}</span>
        </div>
      </div>

      {/* Line Chart */}
      <div className="relative px-3 py-2 h-80">
        {data.length === 0 ? (
          <div className="flex w-full h-full items-center justify-center text-muted-foreground text-xs">
            Collecting data...
          </div>
        ) : (
          <svg className="w-full h-full" preserveAspectRatio="none">
            {/* Grid lines */}
            {[0, 25, 50, 75, 100].map((tick) => {
              const y = 100 - tick;
              return (
                <g key={tick}>
                  <line
                    x1="0%"
                    y1={`${y}%`}
                    x2="100%"
                    y2={`${y}%`}
                    stroke="currentColor"
                    strokeOpacity="0.1"
                    strokeDasharray="4 4"
                  />
                  <text
                    x="2"
                    y={`${y}%`}
                    dy="-4"
                    className="fill-muted-foreground"
                    style={{ fontSize: "9px" }}
                  >
                    {Math.round(minValue + (tick / 100) * (maxValue - minValue))}
                  </text>
                </g>
              );
            })}

            {/* Warning threshold line */}
            <line
              x1="0%"
              y1={`${100 - warningThreshold}%`}
              x2="100%"
              y2={`${100 - warningThreshold}%`}
              stroke="#F59E0B"
              strokeOpacity="0.5"
              strokeDasharray="6 3"
              strokeWidth="1"
            />

            {/* Danger threshold line */}
            <line
              x1="0%"
              y1={`${100 - dangerThreshold}%`}
              x2="100%"
              y2={`${100 - dangerThreshold}%`}
              stroke="#EF4444"
              strokeOpacity="0.5"
              strokeDasharray="6 3"
              strokeWidth="1"
            />

            {/* Area fill under line */}
            <defs>
              <linearGradient id={`gradient-${title.replace(/\s/g, '')}`} x1="0" x2="0" y1="0" y2="1">
                <stop offset="0%" stopColor={color} stopOpacity="0.4" />
                <stop offset="100%" stopColor={color} stopOpacity="0.05" />
              </linearGradient>
            </defs>

            {data.length > 1 && (
              <path
                d={`
                  M 0 100
                  ${data.map((v, i) => {
                    const x = (i / (data.length - 1)) * 100;
                    const normalizedV = ((v - minValue) / (maxValue - minValue)) * 100;
                    const y = 100 - Math.min(Math.max(normalizedV, 0), 100);
                    return `L ${x} ${y}`;
                  }).join(' ')}
                  L 100 100 Z
                `}
                fill={`url(#gradient-${title.replace(/\s/g, '')})`}
              />
            )}

            {/* Main line */}
            {data.length > 1 && (
              <polyline
                points={data.map((v, i) => {
                  const x = (i / (data.length - 1)) * 100;
                  const normalizedV = ((v - minValue) / (maxValue - minValue)) * 100;
                  const y = 100 - Math.min(Math.max(normalizedV, 0), 100);
                  return `${x},${y}`;
                }).join(' ')}
                fill="none"
                stroke={statusColor}
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
                style={{
                  filter: `drop-shadow(0 0 4px ${statusColor})`,
                }}
              />
            )}

            {/* Data points */}
            {data.map((v, i) => {
              const x = data.length > 1 ? (i / (data.length - 1)) * 100 : 50;
              const normalizedV = ((v - minValue) / (maxValue - minValue)) * 100;
              const y = 100 - Math.min(Math.max(normalizedV, 0), 100);
              const pointColor = normalizedV >= dangerThreshold ? "#EF4444" :
                                normalizedV >= warningThreshold ? "#F59E0B" : color;

              // Only show every 5th point to avoid clutter
              if (i % 5 !== 0 && i !== data.length - 1) return null;

              return (
                <circle
                  key={i}
                  cx={`${x}%`}
                  cy={`${y}%`}
                  r={i === data.length - 1 ? 4 : 2}
                  fill={pointColor}
                  stroke={i === data.length - 1 ? "white" : "none"}
                  strokeWidth="1"
                  style={{
                    filter: i === data.length - 1 ? `drop-shadow(0 0 4px ${pointColor})` : 'none',
                  }}
                />
              );
            })}

            {/* Current value indicator on the right */}
            {data.length > 0 && (
              <g>
                <line
                  x1="100%"
                  y1={`${100 - percent}%`}
                  x2="97%"
                  y2={`${100 - percent}%`}
                  stroke={statusColor}
                  strokeWidth="2"
                />
              </g>
            )}
          </svg>
        )}
      </div>

      {/* Stats footer */}
      <div className="flex items-center justify-around px-3 py-1.5 border-t border-border bg-muted/30 shrink-0">
        <div className="text-center">
          <span className="text-[9px] uppercase text-muted-foreground mr-1">Min</span>
          <span className="text-xs font-mono font-semibold">{min.toFixed(0)}</span>
        </div>
        <div className="text-center">
          <span className="text-[9px] uppercase text-muted-foreground mr-1">Avg</span>
          <span className="text-xs font-mono font-semibold" style={{ color }}>{avg.toFixed(0)}</span>
        </div>
        <div className="text-center">
          <span className="text-[9px] uppercase text-muted-foreground mr-1">Max</span>
          <span className="text-xs font-mono font-semibold">{max.toFixed(0)}</span>
        </div>
      </div>
    </div>
  );
};

// =============================================================================
// PROCESS ROW
// =============================================================================

interface ProcessRowProps {
  process: GPUProcess;
}

const ProcessRow = ({ process }: ProcessRowProps) => (
  <div className="flex items-center gap-3 border-b border-border py-2">
    <div className="h-2 w-2 rounded-full bg-green-500" />
    <div className="flex-1 min-w-0">
      <div className="truncate text-sm font-medium">{process.name}</div>
      <div className="text-xs text-muted-foreground">PID: {process.pid}</div>
    </div>
    <div className="text-right">
      <div className="text-sm font-medium">{(process.memoryMb / 1024).toFixed(1)} GB</div>
      <div className="text-xs text-muted-foreground">VRAM</div>
    </div>
  </div>
);
