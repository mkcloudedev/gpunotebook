import { Sidebar } from "@/components/Sidebar";
import { AppHeader } from "@/components/AppHeader";
import { Dashboard } from "@/components/Dashboard";

const Index = () => {
  return (
    <div className="flex h-screen bg-background">
      <Sidebar />
      <div className="flex flex-1 flex-col overflow-hidden">
        <AppHeader title="Home" />
        <Dashboard />
      </div>
    </div>
  );
};

export default Index;
