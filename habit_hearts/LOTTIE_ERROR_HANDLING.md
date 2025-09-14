# Lottie Animation Error Handling in HabitHearts

## Common Issues with Lottie Animations in Flutter

### 1. Red Box with Yellow Text Error

This error typically appears when Flutter cannot properly render a widget, including Lottie animations. It usually indicates one of the following issues:

- **Asset Loading Failure**: The animation file path is incorrect or the file doesn't exist
- **Malformed JSON**: The Lottie JSON file is corrupted or improperly formatted
- **Network Errors**: When loading animations from URLs, network issues can cause failures
- **Format Issues**: Using the wrong decoder for .lottie vs .json files

### 2. .lottie vs .json Format Differences

- **.json files**: Standard Lottie format, can be loaded directly with `Lottie.asset()`
- **.lottie files**: ZIP archives that may contain multiple animations, require a custom decoder
- **.tgs files**: Gzipped Lottie files (Telegram stickers), require `LottieComposition.decodeGZip`

## Solutions Implemented in HabitHearts

### 1. Custom Decoder for .lottie Files

We've implemented a custom decoder in `lib/utils/lottie_decoder.dart`:

```dart
Future<LottieComposition?> lottieFileDecoder(List<int> bytes) {
  return LottieComposition.decodeZip(
    bytes,
    filePicker: (files) {
      // Try to find the main animation file
      return files.firstWhereOrNull(
        (f) => f.name.startsWith('animations/') && f.name.endsWith('.json'),
      ) ??
          files.firstWhereOrNull(
            (f) => f.name.endsWith('.json'),
          ) ??
          files.first; // Fallback to first file if no JSON found
    },
  );
}
```

### 2. Error Handling with Fallback UI

In `lib/widgets/lottie_header_animation.dart`, we've implemented comprehensive error handling:

```dart
Lottie.asset(
  'assets/animations/RW1j2z2aZy.lottie',
  width: 200,
  height: 200,
  fit: BoxFit.contain,
  decoder: lottieFileDecoder, // Custom decoder for .lottie files
  errorBuilder: (context, error, stackTrace) {
    // Fallback to a default animation or image when Lottie fails
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.animation,
            color: Colors.white.withOpacity(0.7),
            size: 80,
          ),
          Text(
            'Animation\nNot Available',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  },
  frameBuilder: (context, child, composition) {
    // Show a loading indicator while the animation is loading
    if (composition == null) {
      return Center(
        child: SizedBox(
          width: 50,
          height: 50,
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }
    return child;
  },
)
```

### 3. Proper Asset Management

In `pubspec.yaml`, we ensure animations are included:

```yaml
flutter:
  assets:
    - assets/images/
    - assets/animations/
```

## Best Practices for Lottie in Flutter

1. **Always implement error handling** using `errorBuilder` and `frameBuilder`
2. **Use appropriate decoders** for different file formats
3. **Provide fallback UI** when animations fail to load
4. **Verify asset paths** in pubspec.yaml
5. **Test with corrupted files** to ensure error handling works
6. **Consider performance** - large animations can impact app performance

## Testing Error Handling

To test the error handling:

1. **Missing Asset Test**: Temporarily rename or remove the .lottie file
2. **Malformed JSON Test**: Corrupt the JSON content in a Lottie file
3. **Network Error Test**: Try loading a Lottie from an invalid URL
4. **Format Error Test**: Try loading a .lottie file without the custom decoder

The implemented solution ensures that even if the Lottie animation fails to load, users will see a graceful fallback UI instead of the red error box.