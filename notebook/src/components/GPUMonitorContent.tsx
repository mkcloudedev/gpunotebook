import { useState, useEffect, useCallback, useRef } from "react";
import {
  Thermometer,
  Activity,
  HardDrive,
  Zap,
  RefreshCw,
  Settings,
  Cpu,
  AlertCircle,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { Button } from "./ui/button";
import { GPUMonitorBreadcrumb } from "./GPUMonitorBreadcrumb";
import { gpuService, GPUStatus, GPUProcess, GPUSystemStatus } from "@/services/gpuService";

// History length (30 data points = 60 seconds at 2s interval)
const HISTORY_LENGTH = 30;
const POLL_INTERVAL = 2000;

// Mock data for fallback
const mockGpuStatus: GPUStatus = {
  index: 0,
  name: "NVIDIA GeForce RTX 4090",
  uuid: "mock-uuid",
  temperature: 65,
  utilizationGpu: 78,
  utilizationMemory: 45,
  memoryUsed: 18432,
  memoryTotal: 24576,
  memoryFree: 6144,
  powerDraw: 320,
  powerLimit: 450,
  cudaVersion: "12.1",
  driverVersion: "535.104.05",
};

const mockProcesses: GPUProcess[] = [
  { pid: 12345, name: "python3", memoryMb: 8192, gpuIndex: 0 },
  { pid: 12346, name: "jupyter-lab", memoryMb: 4096, gpuIndex: 0 },
  { pid: 12347, name: "torch-distributed", memoryMb: 6144, gpuIndex: 0 },
];

export const GPUMonitorContent = () => {
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [hasGpu, setHasGpu] = useState(true);
  const [gpuStatus, setGpuStatus] = useState<GPUStatus | null>(null);
  const [processes, setProcesses] = useState<GPUProcess[]>([]);
  const [utilizationHistory, setUtilizationHistory] = useState<number[]>([]);
  const [memoryHistory, setMemoryHistory] = useState<number[]>([]);
  const [temperatureHistory, setTemperatureHistory] = useState<number[]>([]);

  const stopPollingRef = useRef<(() => void) | null>(null);

  // Update history with new data point
  const updateHistory = useCallback((status: GPUStatus) => {
    const memoryPercent = status.memoryTotal > 0
      ? (status.memoryUsed / status.memoryTotal) * 100
      : 0;

    setUtilizationHistory((prev) => {
      const next = [...prev, status.utilizationGpu];
      return next.slice(-HISTORY_LENGTH);
    });
    setMemoryHistory((prev) => {
      const next = [...prev, memoryPercent];
      return next.slice(-HISTORY_LENGTH);
    });
    setTemperatureHistory((prev) => {
      const next = [...prev, status.temperature];
      return next.slice(-HISTORY_LENGTH);
    });
  }, []);

  // Handle status update from polling
  const handleStatusUpdate = useCallback((systemStatus: GPUSystemStatus) => {
    setHasGpu(systemStatus.hasGpu);
    setProcesses(systemStatus.processes);

    if (systemStatus.primaryGpu) {
      setGpuStatus(systemStatus.primaryGpu);
      updateHistory(systemStatus.primaryGpu);
    }

    setIsLoading(false);
    setError(null);
  }, [updateHistory]);

  // Initial load and start polling
  useEffect(() => {
    const startPolling = async () => {
      try {
        // Initial load
        const status = await gpuService.getStatus();
        handleStatusUpdate(status);

        // Load history if available
        try {
          const history = await gpuService.getHistory(0, "1h");
          if (history.length > 0) {
            setUtilizationHistory(history.slice(-HISTORY_LENGTH).map((h) => h.utilizationGpu));
            setMemoryHistory(history.slice(-HISTORY_LENGTH).map((h) => {
              const total = status.primaryGpu?.memoryTotal || 1;
              return (h.memoryUsed / total) * 100;
            }));
            setTemperatureHistory(history.slice(-HISTORY_LENGTH).map((h) => h.temperature));
          }
        } catch (e) {
          // History not available, that's okay
          console.log("GPU history not available, using real-time data");
        }

        // Start real-time polling
        stopPollingRef.current = gpuService.startPolling(handleStatusUpdate, POLL_INTERVAL);
      } catch (err) {
        console.error("Error loading GPU status:", err);
        setError(err instanceof Error ? err.message : "Failed to load GPU status");
        // Use mock data as fallback
        setGpuStatus(mockGpuStatus);
        setProcesses(mockProcesses);
        setHasGpu(true);
        setIsLoading(false);

        // Start simulated updates as fallback
        const interval = setInterval(() => {
          setGpuStatus((prev) => prev ? {
            ...prev,
            temperature: Math.floor(Math.random() * 15 + 60),
            utilizationGpu: Math.floor(Math.random() * 30 + 60),
            powerDraw: Math.floor(Math.random() * 100 + 280),
          } : prev);
          setUtilizationHistory((prev) => [...prev.slice(1), Math.random() * 40 + 50]);
          setMemoryHistory((prev) => [...prev.slice(1), Math.random() * 20 + 60]);
          setTemperatureHistory((prev) => [...prev.slice(1), Math.random() * 15 + 55]);
        }, POLL_INTERVAL);

        stopPollingRef.current = () => clearInterval(interval);
      }
    };

    startPolling();

    return () => {
      if (stopPollingRef.current) {
        stopPollingRef.current();
      }
    };
  }, [handleStatusUpdate]);

  const handleRefresh = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      const status = await gpuService.getStatus();
      handleStatusUpdate(status);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to refresh");
      setIsLoading(false);
    }
  }, [handleStatusUpdate]);

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
        gpuName={gpuStatus.name}
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
              value={gpuStatus.memoryUsed / 1024}
              maxValue={gpuStatus.memoryTotal / 1024}
              unit="GB"
              subtitle={`of ${(gpuStatus.memoryTotal / 1024).toFixed(0)} GB`}
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
            <span className="font-semibold text-sm">GPU Processes</span>
            <span className="text-xs text-muted-foreground">{processes.length} active</span>
          </div>

          <div className="flex-1 overflow-auto p-3 space-y-2">
            {processes.map((process) => (
              <ProcessRow key={process.pid} process={process} />
            ))}
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
  const percent = Math.min((value / maxValue) * 100, 100);
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
            {value.toFixed(0)}
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

      {/* Bar Chart */}
      <div className="flex items-end gap-0.5 px-3 py-2 h-80">
        {data.length === 0 ? (
          <div className="flex w-full h-full items-center justify-center text-muted-foreground text-xs">
            Collecting data...
          </div>
        ) : (
          data.map((v, i) => {
            const normalizedV = ((v - minValue) / (maxValue - minValue)) * 100;
            const barColor = normalizedV >= dangerThreshold ? "#EF4444" :
                            normalizedV >= warningThreshold ? "#F59E0B" : color;
            return (
              <div
                key={i}
                className="flex-1 rounded-t transition-all duration-200"
                style={{
                  height: `${Math.max(normalizedV, 2)}%`,
                  backgroundColor: barColor,
                  opacity: 0.4 + (i / data.length) * 0.6,
                }}
              />
            );
          })
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
