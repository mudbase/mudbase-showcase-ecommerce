import { cn } from "@/lib/utils"

interface CategoryFilterProps {
  categories: string[]
  value: string | null
  onChange: (category: string | null) => void
}

export function CategoryFilter({ categories, value, onChange }: CategoryFilterProps): React.JSX.Element {
  return (
    <div className="flex flex-wrap gap-2" role="group" aria-label="Filter by category">
      <button
        type="button"
        onClick={() => onChange(null)}
        className={cn(
          "rounded-full border px-3 py-1 text-sm transition-colors",
          value === null ? "border-primary bg-primary text-primary-foreground" : "border-border hover:bg-accent/10",
        )}
      >
        All
      </button>
      {categories.map((category) => (
        <button
          key={category}
          type="button"
          onClick={() => onChange(category)}
          className={cn(
            "rounded-full border px-3 py-1 text-sm transition-colors",
            value === category ? "border-primary bg-primary text-primary-foreground" : "border-border hover:bg-accent/10",
          )}
        >
          {category}
        </button>
      ))}
    </div>
  )
}
