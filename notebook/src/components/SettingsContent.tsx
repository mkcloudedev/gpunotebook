import { useState, useEffect, useCallback } from "react";
import {
  Save,
  Eye,
  EyeOff,
  CheckCircle,
  XCircle,
  AlertCircle,
  User,
  Key,
  Loader2,
  Terminal,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { Button } from "./ui/button";
import { Input } from "./ui/input";
import { Label } from "./ui/label";
import { Switch } from "./ui/switch";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "./ui/select";
import { SettingsBreadcrumb } from "./SettingsBreadcrumb";
import { settingsService, AllSettings } from "@/services/settingsService";
import { aiService } from "@/services/aiService";

export const SettingsContent = () => {
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [saveMessage, setSaveMessage] = useState<{ type: "success" | "error"; text: string } | null>(null);

  // AI Providers
  const [claudeKey, setClaudeKey] = useState("");
  const [openaiKey, setOpenaiKey] = useState("");
  const [geminiKey, setGeminiKey] = useState("");

  // Editor
  const [theme, setTheme] = useState("dark");
  const [fontSize, setFontSize] = useState("14");
  const [tabSize, setTabSize] = useState("4");
  const [autoSave, setAutoSave] = useState(true);

  // Kernel
  const [defaultPython, setDefaultPython] = useState("python3.11");
  const [gpuMemory, setGpuMemory] = useState("80");
  const [executionTimeout, setExecutionTimeout] = useState("300");

  // Kaggle
  const [kaggleUsername, setKaggleUsername] = useState("");
  const [kaggleKey, setKaggleKey] = useState("");
  const [kaggleConfigured, setKaggleConfigured] = useState(false);

  // Claude Code
  const [claudeCodeModel, setClaudeCodeModel] = useState("claude-sonnet-4-20250514");
  const [claudeCodeMaxTokens, setClaudeCodeMaxTokens] = useState("32000");
  const [claudeCodeEnabled, setClaudeCodeEnabled] = useState(true);
  const [claudeCodeAvailable, setClaudeCodeAvailable] = useState<boolean | null>(null);
  const [claudeCodeVersion, setClaudeCodeVersion] = useState<string | null>(null);

  // Load settings from API
  const loadSettings = useCallback(async () => {
    try {
      setIsLoading(true);
      const settings = await settingsService.load();

      // API Keys
      setClaudeKey(settings.apiKeys.claude || "");
      setOpenaiKey(settings.apiKeys.openai || "");
      setGeminiKey(settings.apiKeys.gemini || "");

      // Kaggle
      if (settings.apiKeys.kaggle) {
        setKaggleUsername(settings.apiKeys.kaggle.username || "");
        setKaggleKey(settings.apiKeys.kaggle.key || "");
        setKaggleConfigured(!!settings.apiKeys.kaggle.username && !!settings.apiKeys.kaggle.key);
      }

      // Editor
      setTheme(settings.editor.theme);
      setFontSize(String(settings.editor.fontSize));
      setTabSize(String(settings.editor.tabSize));
      setAutoSave(settings.editor.autoSave);

      // Kernel
      setDefaultPython(settings.kernel.defaultPython);
      setGpuMemory(String(settings.kernel.gpuMemoryLimit));
      setExecutionTimeout(String(settings.kernel.executionTimeout));

      // Claude Code
      if (settings.claudeCode) {
        setClaudeCodeModel(settings.claudeCode.model);
        setClaudeCodeMaxTokens(String(settings.claudeCode.maxOutputTokens));
        setClaudeCodeEnabled(settings.claudeCode.enabled);
      }

      // Check Claude Code CLI availability
      const claudeCodeStatus = await aiService.getClaudeCodeStatus();
      setClaudeCodeAvailable(claudeCodeStatus.available);
      setClaudeCodeVersion(claudeCodeStatus.version);
    } catch (err) {
      console.error("Error loading settings:", err);
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    loadSettings();
  }, [loadSettings]);

  const showSaveMessage = (type: "success" | "error", text: string) => {
    setSaveMessage({ type, text });
    setTimeout(() => setSaveMessage(null), 3000);
  };

  const handleSaveAPIKeys = async () => {
    setIsSaving(true);
    try {
      await settingsService.updateApiKeys({
        claude: claudeKey || undefined,
        openai: openaiKey || undefined,
        gemini: geminiKey || undefined,
      });
      showSaveMessage("success", "API keys saved successfully");
    } catch (err) {
      console.error("Error saving API keys:", err);
      showSaveMessage("error", "Failed to save API keys");
    } finally {
      setIsSaving(false);
    }
  };

  const handleSaveKaggle = async () => {
    if (!kaggleUsername || !kaggleKey) return;

    setIsSaving(true);
    try {
      await settingsService.updateApiKeys({
        kaggle: {
          username: kaggleUsername,
          key: kaggleKey,
        },
      });
      setKaggleConfigured(true);
      showSaveMessage("success", "Kaggle credentials saved successfully");
    } catch (err) {
      console.error("Error saving Kaggle credentials:", err);
      showSaveMessage("error", "Failed to save Kaggle credentials");
    } finally {
      setIsSaving(false);
    }
  };

  const handleSaveEditor = async () => {
    setIsSaving(true);
    try {
      await settingsService.updateEditor({
        theme: theme as "dark" | "light" | "system",
        fontSize: parseInt(fontSize),
        tabSize: parseInt(tabSize),
        autoSave,
      });
      showSaveMessage("success", "Editor settings saved");
    } catch (err) {
      console.error("Error saving editor settings:", err);
      showSaveMessage("error", "Failed to save editor settings");
    } finally {
      setIsSaving(false);
    }
  };

  const handleSaveKernel = async () => {
    setIsSaving(true);
    try {
      await settingsService.updateKernel({
        defaultPython,
        gpuMemoryLimit: parseInt(gpuMemory),
        executionTimeout: parseInt(executionTimeout),
      });
      showSaveMessage("success", "Kernel settings saved");
    } catch (err) {
      console.error("Error saving kernel settings:", err);
      showSaveMessage("error", "Failed to save kernel settings");
    } finally {
      setIsSaving(false);
    }
  };

  const handleSaveClaudeCode = async () => {
    setIsSaving(true);
    try {
      await settingsService.updateClaudeCode({
        model: claudeCodeModel,
        maxOutputTokens: parseInt(claudeCodeMaxTokens),
        enabled: claudeCodeEnabled,
      });
      showSaveMessage("success", "Claude Code settings saved");
    } catch (err) {
      console.error("Error saving Claude Code settings:", err);
      showSaveMessage("error", "Failed to save Claude Code settings");
    } finally {
      setIsSaving(false);
    }
  };

  if (isLoading) {
    return (
      <div className="flex flex-1 flex-col overflow-hidden">
        <SettingsBreadcrumb />
        <div className="flex-1 flex items-center justify-center">
          <div className="flex flex-col items-center gap-3">
            <Loader2 className="h-8 w-8 animate-spin text-primary" />
            <p className="text-muted-foreground">Loading settings...</p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-1 flex-col overflow-hidden">
      <SettingsBreadcrumb />

      {/* Save Message Toast */}
      {saveMessage && (
        <div
          className={cn(
            "fixed top-4 right-4 z-50 flex items-center gap-2 rounded-lg px-4 py-3 shadow-lg",
            saveMessage.type === "success"
              ? "bg-green-500/20 border border-green-500/30 text-green-500"
              : "bg-destructive/20 border border-destructive/30 text-destructive"
          )}
        >
          {saveMessage.type === "success" ? (
            <CheckCircle className="h-4 w-4" />
          ) : (
            <XCircle className="h-4 w-4" />
          )}
          <span className="text-sm font-medium">{saveMessage.text}</span>
        </div>
      )}

      <div className="flex-1 overflow-auto p-4">
        <div className="grid gap-4 grid-cols-1 lg:grid-cols-3">
          {/* AI Providers */}
          <SettingsSection title="AI Providers" description="Configure API keys for AI assistants">
            <APIKeyInput
              label="Claude (Anthropic)"
              value={claudeKey}
              onChange={setClaudeKey}
              placeholder="sk-ant-..."
              provider="claude"
            />
            <APIKeyInput
              label="OpenAI"
              value={openaiKey}
              onChange={setOpenaiKey}
              placeholder="sk-..."
              provider="openai"
            />
            <APIKeyInput
              label="Google Gemini"
              value={geminiKey}
              onChange={setGeminiKey}
              placeholder="AIza..."
              provider="gemini"
            />
            <Button className="w-full mt-4" onClick={handleSaveAPIKeys} disabled={isSaving}>
              {isSaving ? (
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              ) : (
                <Save className="mr-2 h-4 w-4" />
              )}
              Save API Keys
            </Button>
          </SettingsSection>

          {/* Editor */}
          <SettingsSection title="Editor" description="Customize the code editor">
            <SettingsSelect
              label="Theme"
              value={theme}
              onChange={setTheme}
              options={[
                { value: "dark", label: "Dark" },
                { value: "light", label: "Light" },
                { value: "system", label: "System" },
              ]}
            />
            <SettingsSelect
              label="Font Size"
              value={fontSize}
              onChange={setFontSize}
              options={[
                { value: "12", label: "12px" },
                { value: "14", label: "14px" },
                { value: "16", label: "16px" },
                { value: "18", label: "18px" },
              ]}
            />
            <SettingsSelect
              label="Tab Size"
              value={tabSize}
              onChange={setTabSize}
              options={[
                { value: "2", label: "2 spaces" },
                { value: "4", label: "4 spaces" },
              ]}
            />
            <SettingsToggle
              label="Auto-save"
              description="Automatically save notebooks"
              checked={autoSave}
              onChange={setAutoSave}
            />
            <Button className="w-full mt-4" variant="secondary" onClick={handleSaveEditor} disabled={isSaving}>
              {isSaving ? (
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              ) : (
                <Save className="mr-2 h-4 w-4" />
              )}
              Save Editor Settings
            </Button>
          </SettingsSection>

          {/* Kernel */}
          <SettingsSection title="Kernel" description="Configure Python kernel settings">
            <SettingsSelect
              label="Default Python"
              value={defaultPython}
              onChange={setDefaultPython}
              options={[
                { value: "python3.11", label: "Python 3.11" },
                { value: "python3.10", label: "Python 3.10" },
                { value: "python3.9", label: "Python 3.9" },
              ]}
            />
            <SettingsSelect
              label="GPU Memory Limit"
              value={gpuMemory}
              onChange={setGpuMemory}
              options={[
                { value: "50", label: "50%" },
                { value: "70", label: "70%" },
                { value: "80", label: "80%" },
                { value: "90", label: "90%" },
                { value: "100", label: "100%" },
              ]}
            />
            <SettingsSelect
              label="Execution Timeout"
              value={executionTimeout}
              onChange={setExecutionTimeout}
              options={[
                { value: "30", label: "30 seconds" },
                { value: "60", label: "60 seconds" },
                { value: "120", label: "2 minutes" },
                { value: "300", label: "5 minutes" },
                { value: "600", label: "10 minutes" },
              ]}
            />
            <Button className="w-full mt-4" variant="secondary" onClick={handleSaveKernel} disabled={isSaving}>
              {isSaving ? (
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              ) : (
                <Save className="mr-2 h-4 w-4" />
              )}
              Save Kernel Settings
            </Button>
          </SettingsSection>

          {/* Claude Code */}
          <SettingsSection title="Claude Code" description="Configure Claude Code CLI settings">
            {/* Status indicator */}
            <div
              className={cn(
                "flex items-center gap-2 rounded-lg border p-3",
                claudeCodeAvailable
                  ? "border-green-500/30 bg-green-500/10"
                  : "border-amber-500/30 bg-amber-500/10"
              )}
            >
              <Terminal className={cn("h-5 w-5", claudeCodeAvailable ? "text-green-500" : "text-amber-500")} />
              <div className="flex-1">
                <p
                  className={cn(
                    "text-sm font-medium",
                    claudeCodeAvailable ? "text-green-500" : "text-amber-500"
                  )}
                >
                  {claudeCodeAvailable === null
                    ? "Checking..."
                    : claudeCodeAvailable
                    ? "CLI Available"
                    : "CLI Not Found"}
                </p>
                {claudeCodeVersion && (
                  <p className="text-xs text-muted-foreground">{claudeCodeVersion}</p>
                )}
              </div>
              {claudeCodeAvailable && <CheckCircle className="h-4 w-4 text-green-500" />}
            </div>

            <SettingsSelect
              label="Model"
              value={claudeCodeModel}
              onChange={setClaudeCodeModel}
              options={[
                { value: "claude-sonnet-4-20250514", label: "Claude Sonnet 4" },
                { value: "claude-opus-4-5-20251101", label: "Claude Opus 4.5" },
                { value: "claude-3-5-sonnet-20241022", label: "Claude 3.5 Sonnet" },
                { value: "claude-3-5-haiku-20241022", label: "Claude 3.5 Haiku" },
              ]}
            />

            <SettingsSelect
              label="Max Output Tokens"
              value={claudeCodeMaxTokens}
              onChange={setClaudeCodeMaxTokens}
              options={[
                { value: "8000", label: "8K" },
                { value: "16000", label: "16K" },
                { value: "32000", label: "32K" },
                { value: "64000", label: "64K" },
              ]}
            />

            <SettingsToggle
              label="Enable Claude Code"
              description="Use CLI instead of API"
              checked={claudeCodeEnabled}
              onChange={setClaudeCodeEnabled}
            />

            <Button className="w-full mt-4" variant="secondary" onClick={handleSaveClaudeCode} disabled={isSaving}>
              {isSaving ? (
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              ) : (
                <Save className="mr-2 h-4 w-4" />
              )}
              Save Claude Code Settings
            </Button>

            {!claudeCodeAvailable && (
              <p className="text-xs text-muted-foreground mt-2">
                Install Claude Code CLI: npm install -g @anthropic-ai/claude-code
              </p>
            )}
          </SettingsSection>

          {/* Kaggle */}
          <SettingsSection title="Kaggle" description="Configure Kaggle API credentials">
            {/* Status indicator */}
            <div
              className={cn(
                "flex items-center gap-2 rounded-lg border p-3",
                kaggleConfigured
                  ? "border-green-500/30 bg-green-500/10"
                  : "border-amber-500/30 bg-amber-500/10"
              )}
            >
              {kaggleConfigured ? (
                <CheckCircle className="h-4 w-4 text-green-500" />
              ) : (
                <AlertCircle className="h-4 w-4 text-amber-500" />
              )}
              <div className="flex-1">
                <p
                  className={cn(
                    "text-sm font-medium",
                    kaggleConfigured ? "text-green-500" : "text-amber-500"
                  )}
                >
                  {kaggleConfigured ? "Connected" : "Not configured"}
                </p>
                {kaggleConfigured && kaggleUsername && (
                  <p className="text-xs text-muted-foreground">Username: {kaggleUsername}</p>
                )}
              </div>
            </div>

            <div className="mt-4">
              <Label>Username</Label>
              <div className="relative mt-1.5">
                <User className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                <Input
                  value={kaggleUsername}
                  onChange={(e) => setKaggleUsername(e.target.value)}
                  placeholder="Your Kaggle username"
                  className="pl-9"
                />
              </div>
            </div>

            <div className="mt-4">
              <Label>API Key</Label>
              <KaggleKeyInput value={kaggleKey} onChange={setKaggleKey} />
            </div>

            <Button
              className="w-full mt-4 bg-cyan-500 hover:bg-cyan-600"
              onClick={handleSaveKaggle}
              disabled={isSaving || !kaggleUsername || !kaggleKey}
            >
              {isSaving ? (
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              ) : (
                <Save className="mr-2 h-4 w-4" />
              )}
              Save Kaggle Credentials
            </Button>

            <Button variant="ghost" size="sm" className="w-full mt-2 text-muted-foreground">
              Get your API key from kaggle.com/settings
            </Button>
          </SettingsSection>
        </div>
      </div>
    </div>
  );
};

// =============================================================================
// SETTINGS SECTION
// =============================================================================

interface SettingsSectionProps {
  title: string;
  description: string;
  children: React.ReactNode;
}

const SettingsSection = ({ title, description, children }: SettingsSectionProps) => (
  <div className="rounded-lg border border-border bg-card">
    <div className="border-b border-border p-4">
      <h3 className="font-semibold">{title}</h3>
      <p className="text-sm text-muted-foreground mt-1">{description}</p>
    </div>
    <div className="p-4 space-y-4">{children}</div>
  </div>
);

// =============================================================================
// API KEY INPUT
// =============================================================================

interface APIKeyInputProps {
  label: string;
  value: string;
  onChange: (value: string) => void;
  placeholder: string;
  provider: string;
}

const APIKeyInput = ({ label, value, onChange, placeholder, provider }: APIKeyInputProps) => {
  const [obscured, setObscured] = useState(true);
  const [testing, setTesting] = useState(false);
  const [testResult, setTestResult] = useState<boolean | null>(null);

  const handleTest = async () => {
    if (!value) return;
    setTesting(true);
    setTestResult(null);
    try {
      const isValid = await settingsService.validateApiKey(
        provider as "claude" | "openai" | "gemini",
        value
      );
      setTestResult(isValid);
    } catch (err) {
      console.error("Error validating API key:", err);
      setTestResult(false);
    } finally {
      setTesting(false);
    }
  };

  return (
    <div>
      <div className="flex items-center gap-2">
        <Label>{label}</Label>
        {testResult !== null && (
          testResult ? (
            <CheckCircle className="h-3.5 w-3.5 text-green-500" />
          ) : (
            <XCircle className="h-3.5 w-3.5 text-destructive" />
          )
        )}
      </div>
      <div className="flex gap-2 mt-1.5">
        <div className="relative flex-1">
          <Input
            type={obscured ? "password" : "text"}
            value={value}
            onChange={(e) => onChange(e.target.value)}
            placeholder={placeholder}
            className="pr-9"
          />
          <button
            type="button"
            onClick={() => setObscured(!obscured)}
            className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
          >
            {obscured ? <Eye className="h-4 w-4" /> : <EyeOff className="h-4 w-4" />}
          </button>
        </div>
        <Button
          variant={testResult === true ? "default" : "secondary"}
          onClick={handleTest}
          disabled={testing || !value}
          className={testResult === true ? "bg-green-500 hover:bg-green-600" : ""}
        >
          {testing ? (
            <Loader2 className="h-4 w-4 animate-spin" />
          ) : testResult === true ? (
            "Valid"
          ) : (
            "Test"
          )}
        </Button>
      </div>
    </div>
  );
};

// =============================================================================
// KAGGLE KEY INPUT
// =============================================================================

interface KaggleKeyInputProps {
  value: string;
  onChange: (value: string) => void;
}

const KaggleKeyInput = ({ value, onChange }: KaggleKeyInputProps) => {
  const [obscured, setObscured] = useState(true);

  return (
    <div className="relative mt-1.5">
      <Key className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
      <Input
        type={obscured ? "password" : "text"}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder="Your Kaggle API key"
        className="pl-9 pr-9"
      />
      <button
        type="button"
        onClick={() => setObscured(!obscured)}
        className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
      >
        {obscured ? <Eye className="h-4 w-4" /> : <EyeOff className="h-4 w-4" />}
      </button>
    </div>
  );
};

// =============================================================================
// SETTINGS SELECT
// =============================================================================

interface SettingsSelectProps {
  label: string;
  value: string;
  onChange: (value: string) => void;
  options: { value: string; label: string }[];
}

const SettingsSelect = ({ label, value, onChange, options }: SettingsSelectProps) => (
  <div className="flex items-center justify-between">
    <Label>{label}</Label>
    <Select value={value} onValueChange={onChange}>
      <SelectTrigger className="w-40">
        <SelectValue />
      </SelectTrigger>
      <SelectContent>
        {options.map((option) => (
          <SelectItem key={option.value} value={option.value}>
            {option.label}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  </div>
);

// =============================================================================
// SETTINGS TOGGLE
// =============================================================================

interface SettingsToggleProps {
  label: string;
  description: string;
  checked: boolean;
  onChange: (checked: boolean) => void;
}

const SettingsToggle = ({ label, description, checked, onChange }: SettingsToggleProps) => (
  <div className="flex items-center justify-between">
    <div>
      <Label>{label}</Label>
      <p className="text-xs text-muted-foreground mt-0.5">{description}</p>
    </div>
    <Switch checked={checked} onCheckedChange={onChange} />
  </div>
);
