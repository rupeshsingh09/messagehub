import 'package:flutter_contacts/flutter_contacts.dart';

class ContactService {
  /// Clean phone number: remove non-digits, country code (+91), and keep last 10 digits
  static String cleanNumber(String number) {
    if (number.isEmpty) return '';
    
    // 1. Remove all non-digit characters (spaces, hyphens, brackets, +, etc.)
    String cleaned = number.replaceAll(RegExp(r'\D'), '');

    // 2. Remove '91' country code if it exists and number is longer than 10 digits
    if (cleaned.length > 10 && cleaned.startsWith('91')) {
      cleaned = cleaned.substring(cleaned.length - 10);
    }

    // 3. Keep only the last 10 digits (handles leading zeros like '073...' or other country codes)
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
