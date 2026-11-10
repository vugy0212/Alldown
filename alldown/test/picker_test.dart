import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('file_picker directory path test', () {
    expect(FilePickerPlatform.instance.getDirectoryPath, isNotNull);
  });
}

