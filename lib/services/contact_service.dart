import 'package:flutter_contacts/flutter_contacts.dart';

class ContactService {
  /// Clean phone number: remove non-digits, country code (+91), and keep last 10 digits
  static String cleanNumber(String number) {
    // 1. Remove all non-digit characters (spaces, brackets, dashes, etc.)
    String cleaned = number.replaceAll(RegExp(r'\D'), '');

    // 2. Handle Indian country code (+91 or 91)
    if (cleaned.startsWith('91') && cleaned.length > 10) {
      cleaned = cleaned.substring(cleaned.length - 10);
    }

    // 3. If it's still longer than 10 digits (other country codes), just take the last 10
    if (cleaned.length > 10) {
      cleaned = cleaned.substring(cleaned.length - 10);
    }

    return cleaned;
  }

  /// Fetch contacts from device, clean numbers, and return a unique list of 10-digit strings
  static Future<List<String>> getDevicePhoneNumbers() async {
    // Check & Request Permission
    bool permission = await FlutterContacts.requestPermission(readonly: true);
    if (!permission) {
      throw Exception('Contacts permission denied');
    }

    // Fetch contacts with properties (phones)
    List<Contact> contacts = await FlutterContacts.getContacts(withProperties: true);

    Set<String> cleanedNumbers = {};

    for (var contact in contacts) {
      for (var phone in contact.phones) {
        String cleaned = cleanNumber(phone.number);
        
        // Only add if it's exactly 10 digits (valid Indian mobile number format)
        if (cleaned.length == 10) {
          cleanedNumbers.add(cleaned);
        }
      }
    }

    return cleanedNumbers.toList();
  }
}
