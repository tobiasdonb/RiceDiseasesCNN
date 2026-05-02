import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image/image.dart' as img;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rice Diseases Classification',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  File? _image;                     // Object untuk menyimpan file foto
  Interpreter? _interpreter;        // Object mesin TFLite
  List<String> _labels = [];        // Tempat menyimpan nama-nama penyakit
  String _hasilPrediksi = "Belum ada prediksi";
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadModel(); // Perbaikan typo: _LoadModel -> _loadModel
  }

  Future<void> _loadModel() async {
    try {
      // Pastikan file model ada di folder assets/
      _interpreter = await Interpreter.fromAsset('assets/model_padi.tflite');

      // Membaca daftar label dari file assets/labels.txt
      final labelText = await rootBundle.loadString('assets/labels.txt');
      _labels = labelText.split('\n').where((e) => e.isNotEmpty).toList();

      setState(() {}); 
    } catch (e) {
      debugPrint('Gagal load model: $e');
      setState(() {
        _hasilPrediksi = "Gagal memuat model";
      });
    }
  }

  Future<void> _prediksiGambar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    
    if (picked != null) {
      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Potong Gambar',
            toolbarColor: Colors.green,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
        ],
      );
      
      if (cropped != null) {
        setState(() {
          _image = File(cropped.path);
          _isLoading = true;
        });
        _runInference(_image!);
      }
    }
  }

  Future<void> _runInference(File imageFile) async {
    if (_interpreter == null) {
      setState(() {
        _hasilPrediksi = "Model belum siap";
        _isLoading = false;
      });
      return;
    }

    try {
      // 1. Load dan Decode Gambar
      final imageBytes = imageFile.readAsBytesSync();
      final img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) throw Exception("Gagal membaca gambar");

      // 2. Resize Gambar ke 224x224
      final img.Image resizedImage = img.copyResize(originalImage, width: 224, height: 224);

      // 3. Konversi ke Input Tensor [1, 224, 224, 3] - Logika lebih ringkas
      var input = [
        List.generate(224, (y) => List.generate(224, (x) {
          final pixel = resizedImage.getPixel(x, y);
          return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
        }))
      ];

      // 4. Siapkan Output Tensor [1, jumlah_kelas]
      var output = List.filled(1 * _labels.length, 0.0).reshape([1, _labels.length]);

      // 5. Jalankan Prediksi
      _interpreter!.run(input, output);

      // 6. Ambil Skor Tertinggi - Logika lebih ringkas menggunakan reduce(max)
      final List<double> results = List<double>.from(output[0]);
      double maxScore = results.reduce(max);
      int maxIndex = results.indexOf(maxScore);

      setState(() {
        _hasilPrediksi = "${_labels[maxIndex]} (${(maxScore * 100).toStringAsFixed(1)}%)";
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error saat prediksi: $e");
      setState(() {
        _hasilPrediksi = "Error: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rice Disease Classifier'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Tampilan Gambar
              Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.green, width: 2),
                  borderRadius: BorderRadius.circular(15),
                  color: Colors.grey[100],
                ),
                child: _image == null
                    ? const Center(child: Text('Belum ada gambar'))
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Image.file(_image!, fit: BoxFit.cover),
                      ),
              ),
              const SizedBox(height: 30),
              
              // Hasil Prediksi
              if (_isLoading)
                const CircularProgressIndicator()
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    _hasilPrediksi,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
              const SizedBox(height: 40),
              
              // Tombol
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _prediksiGambar,
                icon: const Icon(Icons.photo_library),
                label: const Text("Pilih Gambar & Prediksi"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
