# rotary_dial

A smooth, customizable rotary dial widget for Flutter that emulates the behavior of a classic rotary telephone.

## Features

- **Realistic Physics**: Smooth rotation with spring-back animation.
- **Customizable Theme**: Control colors, gradients, sizes, strokes, and text styles.
- **Haptic Feedback**: Optional haptic feedback as the dial rotates.
- **Gesture Support**: Configurable hit regions and drag behavior.
- **Responsive**: Automatically adapts to available space or explicit size.

## Getting started

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  rotary_dial: ^1.0.0
```

## Usage

Import the package and use the `RotaryDial` widget:

```dart
import 'package:rotary_dial/rotary_dial.dart';

RotaryDial(
  onDigitSelected: (digit) {
    print('Digit selected: $digit');
  },
  theme: const RotaryDialTheme(
    baseFillColor: Colors.black,
    ringFillColor: Colors.white,
    numberColor: Colors.white,
  ),
)
```

## Customization

The `RotaryDial` appearance can be fully customized using `RotaryDialTheme`:

```dart
RotaryDialTheme(
  baseFillColor: Colors.blueGrey,
  ringFillColor: Colors.amber,
  numberTextStyle: TextStyle(fontSize: 24, color: Colors.white),
  // ... and many more properties
)
```
