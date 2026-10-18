import 'dart:convert';
import 'dart:io';

/// Reads `test/support/fixtures/<name>` (tests run from the project root).
String readFixture(String name) =>
    File('test/support/fixtures/$name').readAsStringSync();

Object? loadFixture(String name) => jsonDecode(readFixture(name));
