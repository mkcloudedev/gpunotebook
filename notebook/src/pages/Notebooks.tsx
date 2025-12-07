import { Sidebar } from "@/components/Sidebar";
import { AppHeader } from "@/components/AppHeader";
import { NotebooksContent } from "@/components/NotebooksContent";

const Notebooks = () => {
  return (
    <div className="flex h-screen bg-background">
      <Sidebar activePage="notebooks" />
      <div className="flex flex-1 flex-col overflow-hidden">
        <AppHeader title="Notebooks" />
        <NotebooksContent />
      </div>
    </div>
  );
};

export default Notebooks;
