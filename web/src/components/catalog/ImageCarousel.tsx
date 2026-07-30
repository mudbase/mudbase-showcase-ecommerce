"use client"

import { useEffect, useRef, useState } from "react"
import Image from "next/image"
import { ChevronLeft, ChevronRight } from "lucide-react"
import { cn } from "@/lib/utils"

const AUTOPLAY_INTERVAL_MS = 4000

interface ImageCarouselProps {
  images: string[]
  alt: string
}

export function ImageCarousel({ images, alt }: ImageCarouselProps): React.JSX.Element {
  const [index, setIndex] = useState(0)
  const [isPaused, setIsPaused] = useState(false)
  const reducedMotionRef = useRef(false)

  useEffect(() => {
    reducedMotionRef.current = window.matchMedia("(prefers-reduced-motion: reduce)").matches
  }, [])

  useEffect(() => {
    if (images.length <= 1 || isPaused || reducedMotionRef.current) return
    const id = setInterval(() => {
      setIndex((current) => (current + 1) % images.length)
    }, AUTOPLAY_INTERVAL_MS)
    return () => clearInterval(id)
  }, [images.length, isPaused])

  // A user picking a specific photo is a deliberate override of the slideshow, so autoplay
  // stops for good on this mount rather than resuming and undoing their choice a few seconds later.
  const selectImage = (next: number): void => {
    setIndex(next)
    setIsPaused(true)
  }

  if (images.length === 0) {
    return (
      <div className="flex aspect-square items-center justify-center rounded-lg bg-muted text-sm text-muted-foreground">
        No image
      </div>
    )
  }

  return (
    <div className="space-y-3">
      <div className="group relative aspect-square overflow-hidden rounded-lg bg-muted">
        {images.map((src, i) => (
          <Image
            key={src}
            src={src}
            alt={i === 0 ? alt : `${alt} — photo ${i + 1}`}
            fill
            priority={i === 0}
            sizes="(min-width: 768px) 50vw, 100vw"
            className={cn(
              "object-cover transition-opacity duration-500",
              i === index ? "opacity-100" : "opacity-0",
            )}
          />
        ))}

        {images.length > 1 && (
          <>
            <button
              type="button"
              aria-label="Previous photo"
              onClick={() => selectImage((index - 1 + images.length) % images.length)}
              className="absolute left-2 top-1/2 flex h-8 w-8 -translate-y-1/2 items-center justify-center rounded-full bg-background/80 opacity-0 shadow-sm transition-opacity group-hover:opacity-100 focus-visible:opacity-100"
            >
              <ChevronLeft className="h-4 w-4" />
            </button>
            <button
              type="button"
              aria-label="Next photo"
              onClick={() => selectImage((index + 1) % images.length)}
              className="absolute right-2 top-1/2 flex h-8 w-8 -translate-y-1/2 items-center justify-center rounded-full bg-background/80 opacity-0 shadow-sm transition-opacity group-hover:opacity-100 focus-visible:opacity-100"
            >
              <ChevronRight className="h-4 w-4" />
            </button>
          </>
        )}
      </div>

      {images.length > 1 && (
        <div className="flex justify-center gap-1.5" role="tablist" aria-label="Product photos">
          {images.map((src, i) => (
            <button
              key={src}
              type="button"
              role="tab"
              aria-selected={i === index}
              aria-label={`Show photo ${i + 1} of ${images.length}`}
              onClick={() => selectImage(i)}
              className={cn(
                "h-1.5 rounded-full transition-all",
                i === index ? "w-6 bg-foreground" : "w-1.5 bg-muted-foreground/30 hover:bg-muted-foreground/50",
              )}
            />
          ))}
        </div>
      )}
    </div>
  )
}
