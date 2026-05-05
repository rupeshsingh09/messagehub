import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import '../services/chat_provider.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  final String firstName;

  const OtpScreen({super.key, required this.phone, this.firstName = ''});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpController = TextEditingController();
  final _focusNode = FocusNode();


  int _timerSeconds = 30;
  Timer? _timer;

  bool get _isOtpComplete => _otpController.text.length == 6;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _otpController.addListener(() => setState(() {}));
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _timerSeconds = 30);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_timerSeconds == 0) {
        timer.cancel();
      } else {
        setState(() => _timerSeconds--);
      }
    });
  }

  Future<void> _verifyOtp() async {
    if (!_isOtpComplete) return;
    _focusNode.unfocus();

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final success = await chatProvider.loginWithOtp(
      widget.phone, 
      _otpController.text, 
      widget.firstName,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } else {
      _otpController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            chatProvider.error ?? 'Invalid OTP. Please try again.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _resendOtp() async {
    if (_timerSeconds > 0) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final success = await chatProvider.sendOtp(widget.phone);

    if (!mounted) return;

    if (success) {
      _otpController.clear();
      _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OTP resent successfully!', style: GoogleFonts.poppins()),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(chatProvider.error ?? 'Failed to resend OTP.', style: GoogleFonts.poppins()),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final isLoading = chatProvider.isLoading;

    // Pinput theme
    final defaultPinTheme = PinTheme(
      width: 52,
      height: 60,
      textStyle: GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF1A1A1A),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.shade300, width: 1.5),
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32),

              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  size: 64,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 28),

              // Title
              Text(
                'OTP Verification',
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 10),

              // Subtitle
              Text(
                'Enter the 6-digit code sent to',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '+91 ${widget.phone}',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
              const SizedBox(height: 48),

              // OTP Input (Pinput)
              Pinput(
                length: 6,
                controller: _otpController,
                focusNode: _focusNode,
                autofocus: true,
                defaultPinTheme: defaultPinTheme,
                focusedPinTheme: focusedPinTheme,
                submittedPinTheme: submittedPinTheme,
                keyboardType: TextInputType.number,
                hapticFeedbackType: HapticFeedbackType.lightImpact,
                onCompleted: (_) => _verifyOtp(),
              ),

              const SizedBox(height: 48),

              // Verify Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: (_isOtpComplete && !isLoading) ? _verifyOtp : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.blue.shade100,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          'Verify & Continue',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 28),

              // Resend OTP
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Didn't receive the code? ",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (_timerSeconds > 0)
                    Text(
                      'Resend in ${_timerSeconds}s',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: isLoading ? null : _resendOtp,
                      child: Text(
                        'Resend OTP',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.blue,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}