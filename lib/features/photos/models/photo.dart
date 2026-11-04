class Photo {
  const Photo({
    required this.id,
    required this.author,
    required this.width,
    required this.height,
  });

  final String id;
  final String author;
  final int width;
  final int height;

  String get thumbnailUrl => 'https://picsum.photos/id/$id/400/400';

  String get fullScreenUrl {
    final longestSide = width > height ? width : height;
    final scale = longestSide > 1600 ? 1600 / longestSide : 1.0;
    final targetWidth = (width * scale).round().clamp(1, 1600);
    final targetHeight = (height * scale).round().clamp(1, 1600);
    return 'https://picsum.photos/id/$id/$targetWidth/$targetHeight';
  }

  String get semanticLabel => 'Photo by $author';
}
