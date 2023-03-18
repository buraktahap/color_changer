import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:palette_generator/palette_generator.dart';
import 'package:path_provider/path_provider.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  File? _firstImage;
  File? _secondImage;
  PaletteGenerator? _palette1;
  PaletteGenerator? _palette2;
  final ImagePicker _picker = ImagePicker();
  Uint8List? _generatedImageData;
  bool _isLoading = false;

  Future<void> _pickFirstImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _firstImage = File(pickedFile.path);
      });
      await _generatePalette(true);
    }
  }

  Future<void> _pickSecondImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _secondImage = File(pickedFile.path);
      });
      await _generatePalette(false);
    }
  }

  Future<void> _generatePalette(bool isFirstImage) async {
    try {
      setState(() {
        _isLoading = true;
      });
      final imageProvider =
          FileImage(isFirstImage ? _firstImage! : _secondImage!);
      final paletteGenerator =
          await PaletteGenerator.fromImageProvider(imageProvider);

      setState(() {
        if (isFirstImage) {
          _palette1 = paletteGenerator;
        } else {
          _palette2 = paletteGenerator;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating palette: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Color _findNearestColor(Color color, List<Color> colorPalette) {
    Color nearestColor = colorPalette[0];
    double minDistance = double.infinity;

    for (final paletteColor in colorPalette) {
      final distance = _colorDistance(color, paletteColor);
      if (distance < minDistance) {
        minDistance = distance;
        nearestColor = paletteColor;
      }
    }
    return nearestColor;
  }

  img.Image recolorImage(
      img.Image source, PaletteGenerator palette1, PaletteGenerator palette2) {
    img.Image newImage = img.Image.from(source);

    final colors1 = palette1.colors.toList();
    final colors2 = palette2.colors.toList();

    // Cache for nearest colors and their replacements
    Map<Color, Color> colorCache = {};

    for (int y = 0; y < newImage.height; y++) {
      for (int x = 0; x < newImage.width; x++) {
        final pixelColor = Color(newImage.getPixel(x, y));

        // If the color is not in the cache, find the nearest color and its replacement
        if (!colorCache.containsKey(pixelColor)) {
          final nearestColor = _findNearestColor(pixelColor, colors2);
          final replacementColor = _findNearestColor(nearestColor, colors1);
          colorCache[pixelColor] = replacementColor;
        }

        // Set the pixel color to the cached replacement color
        newImage.setPixel(x, y, colorCache[pixelColor]!.value);
      }
    }

    return newImage;
  }

  double _colorDistance(Color color1, Color color2) {
    int dr = color1.red - color2.red;
    int dg = color1.green - color2.green;
    int db = color1.blue - color2.blue;
    return (dr * dr + dg * dg + db * db).toDouble();
  }

  Future<void> _generateNewImage() async {
    if (_firstImage == null ||
        _secondImage == null ||
        _palette1 == null ||
        _palette2 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select both images and generate palettes.')),
      );
      return;
    }
    try {
      setState(() {
        _isLoading = true;
      });

      // Load the first and second images
      // final image1 = img.decodeImage(await _firstImage!.readAsBytes());
      final image2 = img.decodeImage(await _secondImage!.readAsBytes());

// Perform the palette-based recoloring
      final transformedImage = recolorImage(image2!, _palette1!, _palette2!);

// Save the modified image locally
      final directory = await getApplicationDocumentsDirectory();
      final generatedImagePath = '${directory.path}/generated_image.png';
      File(generatedImagePath)
          .writeAsBytesSync(img.encodePng(transformedImage));

// Display the generated image
      setState(() {
        _generatedImageData =
            Uint8List.fromList(img.encodePng(transformedImage));
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating image: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading == true
        ? const Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(),
          )
        : SingleChildScrollView(
            child: Column(
              children: [
                TextButton(
                  onPressed: _pickFirstImage,
                  child: const Text('Select First Image'),
                ),
                if (_firstImage != null) Image.file(_firstImage!),
                if (_palette1 != null) ...[
                  const Text('Color Palette 1:'),
                  Wrap(
                    children: _palette1!.colors.map((color) {
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          width: 50,
                          height: 50,
                          color: color,
                        ),
                      );
                    }).toList(),
                  ),
                ],
                TextButton(
                  onPressed: _pickSecondImage,
                  child: const Text('Select Second Image'),
                ),
                if (_secondImage != null) Image.file(_secondImage!),
                if (_palette2 != null) ...[
                  const Text('Color Palette 2:'),
                  Wrap(
                    children: _palette2!.colors.map((color) {
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          width: 50,
                          height: 50,
                          color: color,
                        ),
                      );
                    }).toList(),
                  ),
                ],
                TextButton(
                  onPressed: () => _generateNewImage(),
                  child: const Text('Generate'),
                ),
                if (_generatedImageData != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.memory(_generatedImageData!),
                  ),
              ],
            ),
          );
  }
}
