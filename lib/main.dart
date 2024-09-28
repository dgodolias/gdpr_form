import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui; // For image conversion
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  // This widget is the root of your application.

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

  // Controllers for text fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _patronymicController = TextEditingController(); // Πατρώνυμο
  final TextEditingController _dateController = TextEditingController();
  

  // Signature controller
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  // Consent options
  String? _consent5;
  String? _consent6;
  String? _consent7;
  String? _consent8;

  Uint8List? _signatureData;

  // To store Android SDK version
  int _androidSdkInt = 0;

  pw.Font? _customFont; // Declare a variable for the custom font

@override
void initState() {
  super.initState();
  _loadCustomFont();
  _initAndroidInfo();
}

// Load the custom font asynchronously
Future<void> _loadCustomFont() async {
  final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
  setState(() {
    _customFont = pw.Font.ttf(fontData);
  });
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
      return true; // Permissions are not required on non-Android platforms
    }

    if (_androidSdkInt <= 28) {
      PermissionStatus status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
        if (!status.isGranted) {
          return false;
        }
      }
      return true;
    } else {
      return true; // For Android 10 and above, no need to request storage permissions
    }
  }

  // Get the appropriate directory based on Android version
  Future<Directory?> _getSaveDirectory() async {
    if (Platform.isAndroid) {
      if (_androidSdkInt <= 28) {
        Directory downloadsDirectory = Directory('/storage/emulated/0/Download');
        if (await downloadsDirectory.exists()) {
          return downloadsDirectory;
        } else {
          return await getExternalStorageDirectory();
        }
      } else {
        return await getExternalStorageDirectory();
      }
    } else if (Platform.isIOS) {
      return await getApplicationDocumentsDirectory();
    } else {
      return await getApplicationDocumentsDirectory();
    }
  }

  // Function to save text and signature to a PDF
  Future<void> _saveFormAsPdf() async {
    bool hasPermissions = await _requestPermissions();
    if (!hasPermissions) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Storage permissions are required to save the file.')),
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return; // If form is not valid, do not proceed
    }

    await _captureAndConvertSignature();

    if (_signatureData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Παρακαλώ προσθέστε την υπογραφή σας.')),
      );
      return;
    }

    Directory? directory = await _getSaveDirectory();
    if (directory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not access the storage directory.')),
      );
      return;
    }

    String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    String fileName = 'gdpr_form_$timestamp.pdf';
    String filePath = '${directory.path}/$fileName';

    File pdfFile = await _generatePdf(
      _nameController.text,
      _patronymicController.text,
      _dateController.text,
      _signatureData!,
    );

    File savedPdf = await pdfFile.copy(filePath);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Η φόρμα αποθηκεύτηκε με επιτυχία στο $filePath')),
    );

    print('File saved at $filePath');
  }

  // Capture the signature as an Image and convert it to Uint8List
  Future<void> _captureAndConvertSignature() async {
    if (_signatureController.isNotEmpty) {
      Uint8List? data = await _signatureController.toPngBytes();
      if (data != null) {
        setState(() {
          _signatureData = data;
        });
      }
    }
  }

  // Generate a PDF from the form data
    Future<File> _generatePdf(String name, String patronymic, String date, Uint8List signature) async {
      final pdf = pw.Document();
      final signatureImage = pw.MemoryImage(signature);
  
      final ttf = _customFont ?? pw.Font.helvetica(); // Fallback to Helvetica if font isn't loaded
  
      pdf.addPage(
        pw.MultiPage(
          build: (pw.Context context) => [
            pw.Text('ΔΗΛΩΣΗ ΣΥΓΚΑΤΑΘΕΣΗΣ ΕΠΕΞΕΡΓΑΣΙΑΣ ΠΡΟΣΩΠΙΚΩΝ ΔΕΔΟΜΕΝΩΝ',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, font: ttf)),
            pw.SizedBox(height: 16),
            pw.Text('Ο/Η υπογράφων/ουσα δηλώνω ότι:', style: pw.TextStyle(fontSize: 12, font: ttf)),
            pw.SizedBox(height: 8),
            pw.Text(
                '1. Ενημερώθηκα από τον αναφερόμενο δεξιά φορέα, και παρέχω την ρητή συγκατάθεσή μου για την εκ μέρους του συλλογή, τήρηση (σε ηλεκτρονικό ή μη) αρχείο και επεξεργασία προσωπικών δεδομένων μου, και ευαίσθητων, που αφορούν το άτομο μου, τα οποία έχουν συλλεγεί και βρίσκονται στην κατοχή του ή θα συλλεγούν και θα προκύψουν στη συνέχεια και',
                style: pw.TextStyle(fontSize: 12, font: ttf)),
            pw.SizedBox(height: 8),
            pw.Text('PHOTOBIOLOGY LAB Ε.Ε.', style: pw.TextStyle(fontSize: 12, font: ttf)),
            pw.Text('ΙΑΤΡΙΚΗ ΕΤΕΡΟΡΡΥΘΜΗ ΕΤΑΙΡΕΙΑ', style: pw.TextStyle(fontSize: 12, font: ttf)),
            pw.Text('ΔΕΡΜΑΤΟΛΟΓΙΚΟ ΙΑΤΡΕΙΟ', style: pw.TextStyle(fontSize: 12, font: ttf)),
            pw.Text('28ΗΣ ΟΚΤΩΒΡΙΟΥ 25, ΙΩΑΝΝΙΝΑ ΤΗΛ. 2651038040', style: pw.TextStyle(fontSize: 12, font: ttf)),
            pw.Text('ΑΦΜ 800534270', style: pw.TextStyle(fontSize: 12, font: ttf)),
            pw.SizedBox(height: 8),
            pw.Text(
                '2. Συγκατατίθεμαι, συναινώ και αναγνωρίζω ως νόμιμη την επεξεργασία προσωπικών δεδομένων μου καθόσον αυτή είναι απαραίτητη για την προσήκουσα προς εμένα παροχή σχετικών υπηρεσιών και σχετίζεται με την διαφύλαξη ζωτικών εννόμων συμφερόντων μου.',
                style: pw.TextStyle(fontSize: 12, font: ttf)),
            pw.SizedBox(height: 8),
            pw.Text(
                '3. Δηλώνω ρητά και ανεπιφύλακτα ότι παρέχω την ρητή συγκατάθεσή μου στον ως άνω φορέα να διαβιβάζει τα απαραίτητα προσωπικά μου δεδομένα σε συνεργαζόμενους φορείς, όταν αυτό είναι κριθεί απαραίτητο κατά την απόλυτη εκτίμηση του φορέα.',
                style: pw.TextStyle(fontSize: 12, font: ttf)),
            pw.SizedBox(height: 8),
            pw.Text(
                '4. Δηλώνω επίσης ότι πριν και μέσω της υπογραφής της παρούσας έλαβα γνώση από τον ως άνω φορέα των ειδικότερων εννέα δικαιωμάτων που μου παρέχει ο ως άνω κανονισμός, αναλυτικά:',
                style: pw.TextStyle(fontSize: 12, font: ttf)),
            pw.SizedBox(height: 8),
            pw.Bullet(
              text:
                  'Δ1. Το δικαίωμα πληροφόρησης και λήψης επιβεβαίωσης για το εάν τα δεδομένα προσωπικού χαρακτήρα που με αφορούν και βρίσκονται στην κατοχή του υφίστανται επεξεργασία, εντός μηνάς από την υποβολή του αιτήματος.',
              style: pw.TextStyle(fontSize: 12, font: ttf),
            ),
            // Include D2 to D9 similarly
            pw.Bullet(
              text:
                  'Δ2. Το δικαίωμα πρόσβασης μου στα δεδομένα προσωπικού χαρακτήρα και ειδικώς σε πληροφορίες αναφορικά με τους σκοπούς αυτών για τους σκοπούς του φορέα.',
              style: pw.TextStyle(fontSize: 12, font: ttf),
            ),
            pw.Bullet(
              text:
                  'Δ3. Το δικαίωμα προηγούμενης ενημέρωσης μου και συγκατάθεσης μου για την κοινοποίηση/διαβίβαση δεδομένων μου προς πιθανούς αποδέκτες στους οποίους μπορεί να κοινολογηθούν τα δεδομένα προσωπικού χαρακτήρα, ιδίως τους αποδέκτες σε τρίτες χώρες και διεθνείς οργανισμούς.',
              style: pw.TextStyle(fontSize: 12, font: ttf),
            ),
            pw.Bullet(
              text:
                  'Δ4. Το δικαίωμά μου για την υποβολή προς τον ως άνω φορέα αιτήματος περί διόρθωσης ή διαγραφής δεδομένων προσωπικού χαρακτήρα ή περιορισμό της επεξεργασίας αυτών.',
              style: pw.TextStyle(fontSize: 12, font: ttf),
            ),
            pw.Bullet(
              text:
                  'Δ5. Το δικαίωμα λήψης αντιγράφων, και σε ηλεκτρονική μορφή, δεδομένων προσωπικού χαρακτήρα που υποβάλλονται σε επεξεργασία.',
              style: pw.TextStyle(fontSize: 12, font: ttf),
            ),
            pw.Bullet(
              text:
                  'Δ6. Έλαβα επίσης γνώση ότι προσωπικά δεδομένα μου θα αποθηκευτούν για ορισμένο χρονικό διάστημα, σχετιζόμενο με τους σκοπούς της επεξεργασίας αυτών αποκλειστικά για λόγους σχετικούς με το σκοπό του φορέα.',
              style: pw.TextStyle(fontSize: 12, font: ttf),
            ),
            pw.Bullet(
              text:
                  'Δ7. Το δικαίωμά μου να αντιταχθώ στο μέλλον στην επεξεργασία προσωπικών δεδομένων μου από τον υπεύθυνο επεξεργασίας φορέα.',
              style: pw.TextStyle(fontSize: 12, font: ttf),
            ),
            pw.Bullet(
              text:
                  'Δ8. Το δικαίωμά μου να ανακαλέσω την παρούσα συγκατάθεση ανά πάσα στιγμή.',
              style: pw.TextStyle(fontSize: 12, font: ttf),
            ),
            pw.Bullet(
              text:
                  'Δ9. Το δικαίωμα μου να υποβάλλω καταγγελία στην Αρχή Προστασίας Προσωπικών Δεδομένων, ως εποπτική αρχή του υπεύθυνου επεξεργασίας, εάν κρίνω ότι υφίσταται παραβίαση των δικαιωμάτων μου.',
              style: pw.TextStyle(fontSize: 12, font: ttf),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
                '5. Συγκατατίθεμαι στη λήψη φωτογραφιών/μαγνητοσκόπηση μου για το προσωπικό ιατρικό αρχείο: ${_consent5 ?? ''}',
                style: pw.TextStyle(fontSize: 12, font: ttf)),
            pw.Text(
                '6. Συγκατατίθεμαι στη διάθεση των φωτογραφιών/μαγνητοσκόπηση μου για διδασκαλία στα πλαίσια της ιατρικής περίθαλψης όπως περιγράφηκε ανωτέρω: ${_consent6 ?? ''}',
                style: pw.TextStyle(fontSize: 12, font: ttf)),
            pw.Text(
                '7. Συγκατατίθεμαι στη δημοσίευση των φωτογραφιών/μαγνητοσκόπηση μου σε κοινωνικά δίκτυα ή άλλες ιστοσελίδες: ${_consent7 ?? ''}',
                style: pw.TextStyle(fontSize: 12, font: ttf)),
            pw.Text(
                '8. Σε περίπτωση μη αποδοχής της λήψης φωτογραφιών, δεν θα είναι δυνατόν να αξιώσω από τον γιατρό μου ευθύνη σχετικά με το αποτέλεσμα: ${_consent8 ?? ''}',
                style: pw.TextStyle(fontSize: 12, font: ttf)),
            pw.SizedBox(height: 8),
            pw.Text(
                '9. Δηλώνω ρητά και ανεπιφύλακτα ότι έχω κατανοήσει την σημασία της χορηγούμενης εκ μέρους μου συγκατάθεσης στον φορέα περί επεξεργασίας προσωπικών δεδομένων μου και συναινώ ανεπιφύλακτα στη συλλογή, επεξεργασία, διαχείριση και αρχειοθέτηση αυτών εκ μέρους του ως άνω φορέα.',
                style: pw.TextStyle(fontSize: 12, font: ttf)),
            pw.SizedBox(height: 16),
            pw.Text('Στοιχεία Ασθενούς', style: pw.TextStyle(fontSize: 14, font: ttf)),
            pw.Text('Όνοματεπώνυμο Ασθενούς: $name', style: pw.TextStyle(fontSize: 12, font: ttf)),
            pw.Text('Πατρώνυμο: $patronymic', style: pw.TextStyle(fontSize: 12, font: ttf)),
            pw.Text('Ημερομηνία: $date', style: pw.TextStyle(fontSize: 12, font: ttf)),
            pw.SizedBox(height: 16),
            pw.Text('Υπογραφή Ασθενούς:', style: pw.TextStyle(fontSize: 12, font: ttf)),
            pw.Container(height: 100, child: pw.Image(signatureImage)),
          ],
        ),
      );
  
      final outputDir = await getApplicationDocumentsDirectory();
      final outputFile = File('${outputDir.path}/gdpr_form_${DateTime.now().millisecondsSinceEpoch}.pdf');
  
      await outputFile.writeAsBytes(await pdf.save());
      return outputFile;
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
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  'ΔΗΛΩΣΗ ΣΥΓΚΑΤΑΘΕΣΗΣ ΕΠΕΞΕΡΓΑΣΙΑΣ ΠΡΟΣΩΠΙΚΩΝ ΔΕΔΟΜΕΝΩΝ',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                Text('Ο/Η υπογράφων/ουσα δηλώνω ότι:'),
                SizedBox(height: 8),
                Text(
                    '1. Ενημερώθηκα από τον αναφερόμενο δεξιά φορέα, και παρέχω την ρητή συγκατάθεσή μου για την εκ μέρους του συλλογή, τήρηση (σε ηλεκτρονικό ή μη) αρχείο και επεξεργασία προσωπικών δεδομένων μου, και ευαίσθητων, που αφορούν το άτομο μου, τα οποία έχουν συλλεγεί και βρίσκονται στην κατοχή του ή θα συλλεγούν και θα προκύψουν στη συνέχεια και'),
                SizedBox(height: 8),
                Text('PHOTOBIOLOGY LAB Ε.Ε.'),
                Text('ΙΑΤΡΙΚΗ ΕΤΕΡΟΡΡΥΘΜΗ ΕΤΑΙΡΕΙΑ'),
                Text('ΔΕΡΜΑΤΟΛΟΓΙΚΟ ΙΑΤΡΕΙΟ'),
                Text('28ΗΣ ΟΚΤΩΒΡΙΟΥ 25, ΙΩΑΝΝΙΝΑ ΤΗΛ. 2651038040'),
                Text('ΑΦΜ 800534270'),
                SizedBox(height: 8),
                Text(
                    '2. Συγκατατίθεμαι, συναινώ και αναγνωρίζω ως νόμιμη την επεξεργασία προσωπικών δεδομένων μου καθόσον αυτή είναι απαραίτητη για την προσήκουσα προς εμένα παροχή σχετικών υπηρεσιών και σχετίζεται με την διαφύλαξη ζωτικών εννόμων συμφερόντων μου.'),
                SizedBox(height: 8),
                Text(
                    '3. Δηλώνω ρητά και ανεπιφύλακτα ότι παρέχω την ρητή συγκατάθεσή μου στον ως άνω φορέα να διαβιβάζει τα απαραίτητα προσωπικά μου δεδομένα σε συνεργαζόμενους φορείς, όταν αυτό είναι κριθεί απαραίτητο κατά την απόλυτη εκτίμηση του φορέα.'),
                SizedBox(height: 8),
                Text(
                    '4. Δηλώνω επίσης ότι πριν και μέσω της υπογραφής της παρούσας έλαβα γνώση από τον ως άνω φορέα των ειδικότερων εννέα δικαιωμάτων που μου παρέχει ο ως άνω κανονισμός, αναλυτικά:'),
                SizedBox(height: 8),
                Text('Δ1. Το δικαίωμα πληροφόρησης και λήψης επιβεβαίωσης...'),
                // Add the rest of D1-D9 similarly
                Text('Δ2. Το δικαίωμα πρόσβασης μου στα δεδομένα...'),
                Text('Δ3. Το δικαίωμα προηγούμενης ενημέρωσης μου...'),
                Text('Δ4. Το δικαίωμά μου για την υποβολή προς τον φορέα...'),
                Text('Δ5. Το δικαίωμα λήψης αντιγράφων...'),
                Text('Δ6. Έλαβα επίσης γνώση ότι προσωπικά δεδομένα...'),
                Text('Δ7. Το δικαίωμά μου να αντιταχθώ στο μέλλον...'),
                Text('Δ8. Το δικαίωμά μου να ανακαλέσω την παρούσα...'),
                Text('Δ9. Το δικαίωμα μου να υποβάλλω καταγγελία...'),
                SizedBox(height: 8),
                // Consents with NAI/OXI options
                Text(
                  '5. Συγκατατίθεμαι στη λήψη φωτογραφιών/μαγνητοσκόπηση μου για το προσωπικό ιατρικό αρχείο:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        title: const Text('ΝΑΙ'),
                        leading: Radio<String>(
                          value: 'ΝΑΙ',
                          groupValue: _consent5,
                          onChanged: (String? value) {
                            setState(() {
                              _consent5 = value;
                            });
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        title: const Text('ΟΧΙ'),
                        leading: Radio<String>(
                          value: 'ΟΧΙ',
                          groupValue: _consent5,
                          onChanged: (String? value) {
                            setState(() {
                              _consent5 = value;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '6. Συγκατατίθεμαι στη διάθεση των φωτογραφιών/μαγνητοσκόπηση μου για διδασκαλία στα πλαίσια της ιατρικής περίθαλψης όπως περιγράφηκε ανωτέρω:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        title: const Text('ΝΑΙ'),
                        leading: Radio<String>(
                          value: 'ΝΑΙ',
                          groupValue: _consent6,
                          onChanged: (String? value) {
                            setState(() {
                              _consent6 = value;
                            });
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        title: const Text('ΟΧΙ'),
                        leading: Radio<String>(
                          value: 'ΟΧΙ',
                          groupValue: _consent6,
                          onChanged: (String? value) {
                            setState(() {
                              _consent6 = value;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '7. Συγκατατίθεμαι στη δημοσίευση των φωτογραφιών/μαγνητοσκόπηση μου σε κοινωνικά δίκτυα ή άλλες ιστοσελίδες:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        title: const Text('ΝΑΙ'),
                        leading: Radio<String>(
                          value: 'ΝΑΙ',
                          groupValue: _consent7,
                          onChanged: (String? value) {
                            setState(() {
                              _consent7 = value;
                            });
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        title: const Text('ΟΧΙ'),
                        leading: Radio<String>(
                          value: 'ΟΧΙ',
                          groupValue: _consent7,
                          onChanged: (String? value) {
                            setState(() {
                              _consent7 = value;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '8. Σε περίπτωση μη αποδοχής της λήψης φωτογραφιών, δεν θα είναι δυνατόν να αξιώσω από τον γιατρό μου ευθύνη σχετικά με το αποτέλεσμα:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        title: const Text('ΝΑΙ'),
                        leading: Radio<String>(
                          value: 'ΝΑΙ',
                          groupValue: _consent8,
                          onChanged: (String? value) {
                            setState(() {
                              _consent8 = value;
                            });
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        title: const Text('ΟΧΙ'),
                        leading: Radio<String>(
                          value: 'ΟΧΙ',
                          groupValue: _consent8,
                          onChanged: (String? value) {
                            setState(() {
                              _consent8 = value;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Text(
                    '9. Δηλώνω ρητά και ανεπιφύλακτα ότι έχω κατανοήσει την σημασία της χορηγούμενης εκ μέρους μου συγκατάθεσης στον φορέα περί επεξεργασίας προσωπικών δεδομένων μου και συναινώ ανεπιφύλακτα στη συλλογή, επεξεργασία, διαχείριση και αρχειοθέτηση αυτών εκ μέρους του ως άνω φορέα.'),
                SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Όνοματεπώνυμο Ασθενούς',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Παρακαλώ εισάγετε το όνοματεπώνυμο';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _patronymicController,
                  decoration: InputDecoration(
                    labelText: 'Πατρώνυμο',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Παρακαλώ εισάγετε το πατρώνυμο';
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
              ])),
        ));
  }
}
