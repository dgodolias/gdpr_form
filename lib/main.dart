import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;  // Import this for image conversion
import 'package:flutter/material.dart';
import 'package:flutter_signature_pad/flutter_signature_pad.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GDPR Form',
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
  final _signatureKey = GlobalKey<SignatureState>();
  Uint8List? _signatureData;

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
                ),
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
                  key: _signatureKey,
                  onSign: () async {
                    // Signature captured
                  },
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState?.validate() ?? false) {
                    _captureAndConvertSignature();
                  }
                },
                child: Text('Καταχώρηση'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Capture the signature as Image and convert it to Uint8List
  Future<void> _captureAndConvertSignature() async {
    // Step 1: Capture the signature as an Image
    final signatureImage = await _signatureKey.currentState?.getData();
    if (signatureImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please provide a signature')),
      );
      return;
    }

    // Step 2: Convert the Image to Uint8List
    final ui.Image image = signatureImage;
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List imageBytes = byteData!.buffer.asUint8List();

    // Save the signature image as a PDF
    _signatureData = imageBytes;
    await _showPreviewDialog(context);
  }

  // Show a dialog with the preview message and save the PDF
  Future<void> _showPreviewDialog(BuildContext context) async {
    final name = _nameController.text;
    final date = _dateController.text;

    if (_signatureData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please provide a signature')),
      );
      return;
    }

    final pdfFile = await _generatePdf(name, date, _signatureData!);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Form Preview'),
        content: Text('The form has been saved successfully.'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
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
            pw.Text('GDPR Consent Form'),
            pw.SizedBox(height: 16),
            pw.Text('Όνοματεπώνυμο Ασθενούς: $name'),
            pw.Text('Ημερομηνία: $date'),
            pw.SizedBox(height: 16),
            pw.Text('Υπογραφή Ασθενούς:'),
            pw.Container(height: 100, child: pw.Image(signatureImage)),
          ],
        ),
      ),
    );

    final outputDir = await getApplicationDocumentsDirectory();
    final outputFile = File('${outputDir.path}/gdpr_form_${DateTime.now().millisecondsSinceEpoch}.pdf');

    await outputFile.writeAsBytes(await pdf.save());
    return outputFile;
  }
}
