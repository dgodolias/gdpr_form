import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:intl/intl.dart'; // For timestamping the file name

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // Root widget of the application
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Save File Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: SaveFilePage(),
    );
  }
}

class SaveFilePage extends StatefulWidget {
  @override
  _SaveFilePageState createState() => _SaveFilePageState();
}

class _SaveFilePageState extends State<SaveFilePage> {
  // To store Android SDK version
  int _androidSdkInt = 0;

  @override
  void initState() {
    super.initState();
    _initAndroidInfo();
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
      // No need to request storage permissions for app-specific directories
      return true;
    }
  }

  // Get the appropriate directory based on Android version
  Future<Directory?> _getSaveDirectory() async {
    if (Platform.isAndroid) {
      if (_androidSdkInt <= 28) {
        // For Android 9 and below, save to public Downloads directory
        return Directory('/storage/emulated/0/Download');
      } else {
        // For Android 10 and above, save to app-specific external directory
        // Alternatively, implement Storage Access Framework for public directories
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

  // Function to save text to a file
  Future<void> _saveFile() async {
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
    String fileName = 'my_file_$timestamp.txt';

    // Full file path
    String filePath = '${directory.path}/$fileName';

    // Write the text to the file
    File file = File(filePath);
    String fileContent = 'This is the content of the file saved on ${DateTime.now()}';
    try {
      await file.writeAsString(fileContent);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File saved successfully at $filePath'),
        ),
      );
      print('File saved at $filePath');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save the file: $e'),
        ),
      );
      print('Error saving file: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Basic UI with a button to save the file
    return Scaffold(
      appBar: AppBar(
        title: Text('Save File Example'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: _saveFile,
          child: Text('Save File'),
        ),
      ),
    );
  }
}