import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui; // For image conversion
import 'package:flutter/material.dart';
import 'package:signature/signature.dart'; // Updated package
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart'; // For timestamping the file name

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // Root widget of the application
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GDPR Consent Form',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: GDPRForm(),
    );
  }
}

class GDPRForm extends StatefulWidget {
  @override
  _GDPRFormState createState() => _GDPRFormState();
}

class _GDPRFormState extends State<GDPRForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  Uint8List? _signatureData;

  // To store Android SDK version
  int _androidSdkInt = 0;

  @override
  void initState() {
    super.initState();
    _initAndroidInfo();
  }

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }

  // Initialize and get Android SDK version
  Future<void> _initAndroidInfo() async {
    if (Platform.isAndroid) {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      setState(() {
        _androidSdkInt = androidInfo.version.sdkInt;
      });
    }
  }

  // Request necessary permissions based on Android version
  Future<bool> _requestPermissions() async {
    if (!Platform.isAndroid) {
      // Permissions are not required on non-Android platforms
      return true;
    }

    if (_androidSdkInt <= 28) {
      // For Android 9 and below, request storage permissions
      PermissionStatus status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
        if (!status.isGranted) {
          return false;
        }
      }
      return true;
    } else {
      // For Android 10 and above, Scoped Storage is enforced
      // No need to request storage permissions for standard directories
      return true;
    }
  }

  // Get the appropriate directory based on Android version
  Future<Directory?> _getSaveDirectory() async {
    if (Platform.isAndroid) {
      if (_androidSdkInt <= 28) {
        // For Android 9 and below, save to public Downloads directory
        // Note: Hardcoding paths is generally discouraged but used here for simplicity
        Directory downloadsDirectory = Directory('/storage/emulated/0/Download');
        if (await downloadsDirectory.exists()) {
          return downloadsDirectory;
        } else {
          // Fallback to external storage directory
          return await getExternalStorageDirectory();
        }
      } else {
        // For Android 10 and above, save to app-specific external directory
        return await getExternalStorageDirectory();
      }
    } else if (Platform.isIOS) {
      // For iOS, save to Documents directory
      return await getApplicationDocumentsDirectory();
    } else {
      // For other platforms, handle accordingly
      return await getApplicationDocumentsDirectory();
    }
  }

  // Function to save text and signature to a PDF
  Future<void> _saveFormAsPdf() async {
    // Check and request permissions
    bool hasPermissions = await _requestPermissions();
    if (!hasPermissions) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Storage permissions are required to save the file.'),
        ),
      );
      return;
    }

    // Validate the form
    if (!(_formKey.currentState?.validate() ?? false)) {
      // If form is not valid, do not proceed
      return;
    }

    // Capture and convert the signature
    await _captureAndConvertSignature();

    if (_signatureData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please provide a signature.'),
        ),
      );
      return;
    }

    // Get the directory to save the file
    Directory? directory = await _getSaveDirectory();
    if (directory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not access the storage directory.'),
        ),
      );
      return;
    }

    // Create a timestamped file name to avoid overwriting
    String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    String fileName = 'gdpr_form_$timestamp.pdf';

    // Full file path
    String filePath = '${directory.path}/$fileName';

    // Generate PDF
    File pdfFile = await _generatePdf(
      _nameController.text,
      _dateController.text,
      _signatureData!,
    );

    // Move the PDF to the desired location
    File savedPdf = await pdfFile.copy(filePath);

    // Notify the user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Form saved successfully at $filePath'),
      ),
    );

    print('File saved at $filePath');
  }

  // Capture the signature as an Image and convert it to Uint8List
  Future<void> _captureAndConvertSignature() async {
    if (_signatureController.isNotEmpty) {
      // Export the signature as an image
      Uint8List? data = await _signatureController.toPngBytes();
      if (data != null) {
        setState(() {
          _signatureData = data;
        });
      }
    }
  }

  // Generate a PDF from the form data
  Future<File> _generatePdf(String name, String date, Uint8List signature) async {
    final pdf = pw.Document();
    final signatureImage = pw.MemoryImage(signature);

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('GDPR Consent Form', style: pw.TextStyle(fontSize: 24)),
            pw.SizedBox(height: 16),
            pw.Text('Όνοματεπώνυμο Ασθενούς: $name', style: pw.TextStyle(fontSize: 18)),
            pw.Text('Ημερομηνία: $date', style: pw.TextStyle(fontSize: 18)),
            pw.SizedBox(height: 16),
            pw.Text('Υπογραφή Ασθενούς:', style: pw.TextStyle(fontSize: 18)),
            pw.SizedBox(height: 8),
            pw.Container(
              height: 100,
              child: pw.Image(signatureImage),
            ),
          ],
        ),
      ),
    );

    // Generate PDF bytes
    final pdfBytes = await pdf.save();

    // Get temporary directory
    final tempDir = await getTemporaryDirectory();
    String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final tempFile = File('${tempDir.path}/gdpr_form_$timestamp.pdf');

    // Write PDF bytes to temporary file
    await tempFile.writeAsBytes(pdfBytes);

    return tempFile;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('GDPR Consent Form'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '9. Δηλώνω ρητά και ανεπιφύλακτα ότι έχω κατανοήσει την σημασία της...',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Όνοματεπώνυμο Ασθενούς',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Παρακαλώ εισάγετε το όνομα';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _dateController,
                decoration: InputDecoration(
                  labelText: 'Ημερομηνία',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );

                  if (pickedDate != null) {
                    String formattedDate = DateFormat('dd/MM/yyyy').format(pickedDate);
                    setState(() {
                      _dateController.text = formattedDate;
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Παρακαλώ εισάγετε την ημερομηνία';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              Text('Υπογραφή Ασθενούς', style: TextStyle(fontSize: 16)),
              SizedBox(height: 8),
              Container(
                color: Colors.grey[200],
                height: 200,
                child: Signature(
                  controller: _signatureController,
                  backgroundColor: Colors.grey[200]!,
                ),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _signatureController.clear();
                        _signatureData = null;
                      });
                    },
                    child: Text('Καθαρισμός Υπογραφής'),
                  ),
                ],
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saveFormAsPdf,
                child: Text('Καταχώρηση'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}