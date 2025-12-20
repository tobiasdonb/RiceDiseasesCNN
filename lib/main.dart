import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Interpreter? interpreter;
  List<String> labels = [];
  File? imageFile;
  String predictionText = "Belum ada prediksi";
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  Future<void> loadModel() async {
    try {
      interpreter = await Interpreter.fromAsset('assets/model_padi.tflite');
      final labelData = await rootBundle.loadString('assets/labels.txt');
      labels = labelData.split('\n').where((e) => e.isNotEmpty).toList();
    } catch (e) {
      debugPrint("Error load model: $e");
    }
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Potong Gambar',
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
        ],
      );
      if (cropped != null) {
        setState(() {
          imageFile = File(cropped.path);
          isLoading = true;
        });
        runPrediction(imageFile!);
      }
    }
  }

  void runPrediction(File file) {
    try {
      final bytes = file.readAsBytesSync();
      img.Image? original = img.decodeImage(bytes);
      if (original == null) return;

      img.Image resized = img.copyResize(original, width: 224, height: 224);
      var input = [List.generate(224, (y) => List.generate(224, (x) {
        final p = resized.getPixel(x, y);
        return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
      }))];

      var output = List.generate(1, (_) => List.filled(9, 0.0));
      interpreter?.run(input, output);
      int idx = output[0].indexOf(output[0].reduce(max));

      setState(() {
        predictionText = "${labels[idx]} (${(output[0][idx] * 100).toStringAsFixed(1)}%)";
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Klasifikasi Penyakit Padi')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Column(
              children: [
                const SizedBox(height: 40),

                imageFile != null
                    ? Image.file(imageFile!, height: 200)
                    : const Icon(Icons.image, size: 200, color: Colors.grey),

                const SizedBox(height: 20),
                Text(
                  predictionText,
                  style: const TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: pickImage,
                  child: const Text('Pilih Gambar'),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}