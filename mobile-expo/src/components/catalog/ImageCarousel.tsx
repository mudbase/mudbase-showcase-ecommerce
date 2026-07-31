import { useRef, useState } from "react";
import { Dimensions, NativeScrollEvent, NativeSyntheticEvent, Pressable, ScrollView, Text, View } from "react-native";
import { Image } from "expo-image";
import { cn } from "@/lib/cn";

interface ImageCarouselProps {
  images: string[];
  alt: string;
}

const screenWidth = Dimensions.get("window").width;

/**
 * Touch-first equivalent of web's ImageCarousel: swipe paging replaces the
 * prev/next hover buttons (there's no cursor on a phone), and dot indicators
 * are tappable to jump to a specific photo, same as the web version's tabs.
 */
export function ImageCarousel({ images, alt }: ImageCarouselProps): React.JSX.Element {
  const [index, setIndex] = useState(0);
  const scrollRef = useRef<ScrollView>(null);
  const carouselWidth = screenWidth - 32;

  const handleMomentumEnd = (event: NativeSyntheticEvent<NativeScrollEvent>): void => {
    const next = Math.round(event.nativeEvent.contentOffset.x / carouselWidth);
    setIndex(next);
  };

  const selectImage = (next: number): void => {
    setIndex(next);
    scrollRef.current?.scrollTo({ x: next * carouselWidth, animated: true });
  };

  if (images.length === 0) {
    return (
      <View style={{ width: carouselWidth, height: carouselWidth }} className="items-center justify-center rounded-lg bg-muted">
        <Text className="text-sm text-muted-foreground">No image</Text>
      </View>
    );
  }

  return (
    <View className="gap-3">
      <ScrollView
        ref={scrollRef}
        horizontal
        pagingEnabled
        showsHorizontalScrollIndicator={false}
        onMomentumScrollEnd={handleMomentumEnd}
        style={{ width: carouselWidth, height: carouselWidth }}
        className="overflow-hidden rounded-lg bg-muted"
      >
        {images.map((src, i) => (
          <Image
            key={src}
            source={src}
            accessibilityLabel={i === 0 ? alt : `${alt} — photo ${i + 1}`}
            style={{ width: carouselWidth, height: carouselWidth }}
            contentFit="cover"
            transition={200}
            cachePolicy="memory-disk"
            priority={i === 0 ? "high" : "normal"}
          />
        ))}
      </ScrollView>

      {images.length > 1 && (
        <View className="flex-row justify-center gap-1.5" accessibilityRole="tablist">
          {images.map((src, i) => (
            <Pressable
              key={src}
              onPress={() => selectImage(i)}
              accessibilityRole="tab"
              accessibilityState={{ selected: i === index }}
              accessibilityLabel={`Show photo ${i + 1} of ${images.length}`}
              hitSlop={8}
              className={cn("h-1.5 rounded-full", i === index ? "w-6 bg-foreground" : "w-1.5 bg-muted-foreground/30")}
            />
          ))}
        </View>
      )}
    </View>
  );
}
