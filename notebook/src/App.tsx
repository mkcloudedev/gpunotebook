import { Toaster } from "@/components/ui/toaster";
import { Toaster as Sonner } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter, Routes, Route } from "react-router-dom";
import { Layout } from "./components/Layout";
import { PlaygroundContent } from "./components/PlaygroundContent";
import { NotebooksContent } from "./components/NotebooksContent";
import { NotebookEditorPage } from "./pages/NotebookEditor";
import { AIAssistantContent } from "./components/AIAssistantContent";
import { AutoMLContent } from "./components/AutoMLContent";
import { GPUMonitorContent } from "./components/GPUMonitorContent";
import { FilesContent } from "./components/FilesContent";
import { KaggleContent } from "./components/KaggleContent";
import { ClusterContent } from "./components/ClusterContent";
import { ContainersContent } from "./components/ContainersContent";
import { SettingsContent } from "./components/SettingsContent";
import { HelpContent } from "./components/HelpContent";
import { GPUProvider } from "./contexts/GPUContext";
import NotFound from "./pages/NotFound";

const queryClient = new QueryClient();

const App = () => (
  <QueryClientProvider client={queryClient}>
    <TooltipProvider>
      <GPUProvider>
        <Toaster />
        <Sonner />
        <BrowserRouter>
        <Routes>
          <Route path="/" element={<Layout />}>
            <Route index element={<NotebooksContent />} />
            <Route path="playground" element={<PlaygroundContent />} />
            <Route path="notebook/:id" element={<NotebookEditorPage />} />
            <Route path="ai-assistant" element={<AIAssistantContent />} />
            <Route path="automl" element={<AutoMLContent />} />
            <Route path="gpu" element={<GPUMonitorContent />} />
            <Route path="files" element={<FilesContent />} />
            <Route path="kaggle" element={<KaggleContent />} />
            <Route path="cluster" element={<ClusterContent />} />
            <Route path="containers" element={<ContainersContent />} />
            <Route path="settings" element={<SettingsContent />} />
            <Route path="help" element={<HelpContent />} />
          </Route>
          {/* ADD ALL CUSTOM ROUTES ABOVE THE CATCH-ALL "*" ROUTE */}
          <Route path="*" element={<NotFound />} />
        </Routes>
      </BrowserRouter>
      </GPUProvider>
    </TooltipProvider>
  </QueryClientProvider>
);

export default App;
