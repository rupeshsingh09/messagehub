import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  final String firstName;

  const OtpScreen({super.key, required this.phone, this.firstName = ''});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpController = TextEditingController();
  int _timerSeconds = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timerSeconds = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_timerSeconds == 0) timer.cancel();
      else setState(() => _timerSeconds--);
    });
  }

  Future<void> _verifyOtp() async {
    final provider = context.read<ChatProvider>();
    final success = await provider.loginWithOtp(widget.phone, _otpController.text, widget.firstName);
    if (success && mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.error ?? 'Invalid OTP')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Text('Verify Phone', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text('Enter code sent to +91 ${widget.phone}', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 48),
            Pinput(
              length: 6,
              controller: _otpController,
              onCompleted: (_) => _verifyOtp(),
              defaultPinTheme: PinTheme(
                width: 50, height: 60,
                textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: provider.isLoading ? null : _verifyOtp,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A884), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: provider.isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Verify'),
              ),
            ),
            const SizedBox(height: 20),
            if (_timerSeconds > 0) Text('Resend in ${_timerSeconds}s')
            else TextButton(onPressed: () => provider.sendOtp(widget.phone), child: const Text('Resend OTP')),
          ],
        ),
      ),
    );
  }
}
