import { Sidebar } from "@/components/Sidebar";
import { AppHeader } from "@/components/AppHeader";
import { PlaygroundContent } from "@/components/PlaygroundContent";

const Playground = () => {
  return (
    <div className="flex h-screen bg-background">
      <Sidebar activePage="playground" />
      <div className="flex flex-1 flex-col overflow-hidden">
        <AppHeader title="Playground" />
        <PlaygroundContent />
      </div>
    </div>
  );
};

export default Playground;
