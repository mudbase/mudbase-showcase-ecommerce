import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// The product detail page's rotating photo gallery - the main `imageUrl`
/// followed by every `galleryJson` extra photo (see `Product.images`).
class ImageGallery extends StatefulWidget {
  const ImageGallery({required this.images, super.key});

  final List<String> images;

  @override
  State<ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<ImageGallery> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (widget.images.isEmpty) {
      return AspectRatio(
        aspectRatio: 1,
        child: ColoredBox(
          color: colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.image_outlined,
            size: 48,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) {
              return CachedNetworkImage(
                imageUrl: widget.images[index],
                fit: BoxFit.cover,
                placeholder: (context, url) => ColoredBox(
                  color: colorScheme.surfaceContainerHighest,
                ),
                errorWidget: (context, url, error) => ColoredBox(
                  color: colorScheme.surfaceContainerHighest,
                  child: Icon(Icons.broken_image_outlined,
                      color: colorScheme.onSurfaceVariant),
                ),
              );
            },
          ),
        ),
        if (widget.images.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.images.length, (index) {
              final isActive = index == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isActive ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}
