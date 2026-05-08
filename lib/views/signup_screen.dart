import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import 'otp_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();

  void _handleSignup() async {
    final name = nameController.text.trim();
    String phone = phoneController.text.trim();

    if (name.isEmpty) { _showError('First Name is required'); return; }
    if (phone.isEmpty) { _showError('Phone Number is required'); return; }

    phone = phone.replaceAll(RegExp(r'\D'), ''); 
    if (phone.startsWith('91') && phone.length > 10) phone = phone.substring(2);
    if (phone.length != 10) { _showError('Enter a valid 10-digit phone number'); return; }

    final provider = context.read<ChatProvider>();
    final success = await provider.sendOtp(phone);

    if (success && mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => OtpScreen(phone: phone, firstName: name)));
    } else if (mounted) {
      _showError(provider.error ?? 'Failed to send OTP');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            children: [
              const SizedBox(height: 60),
              const Icon(Icons.chat_bubble, size: 80, color: Color(0xFF00A884)),
              const SizedBox(height: 32),
              Text('Welcome to MessageHub', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 48),
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Name', prefixIcon: const Icon(Icons.person), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: 'Phone', prefixIcon: const Icon(Icons.phone), prefixText: '+91 ', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: provider.isLoading ? null : _handleSignup,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A884), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: provider.isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
