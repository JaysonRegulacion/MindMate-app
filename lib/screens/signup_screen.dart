import 'package:flutter/material.dart';
import 'package:mindmate/widgets/background.dart';
import 'package:mindmate/widgets/custom_text_field.dart';
import 'package:mindmate/widgets/primary_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'signin_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final usernameController = TextEditingController();

  // Emergency Contact
  final emergencyNameController = TextEditingController();
  final emergencyRelationshipController = TextEditingController();
  final emergencyNumberController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool loading = false;

  DateTime? lastResendTime;
  final Duration resendCooldown = const Duration(seconds: 30);

  String capitalize(String text) =>
      text.isEmpty ? '' : text[0].toUpperCase() + text.substring(1).toLowerCase();

  String capitalizeWords(String text) {
    if (text.isEmpty) return '';
      return text
          .split(' ')
          .where((word) => word.isNotEmpty)
          .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
          .join(' ');
  }

  Future<void> signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => loading = true);

    final supabase = Supabase.instance.client;
    final email = emailController.text.trim();
    final firstName = capitalize(firstNameController.text.trim());
    final lastName = capitalize(lastNameController.text.trim());
    final password = passwordController.text.trim();
    final username = usernameController.text.trim();
    final emergencyName = capitalizeWords(emergencyNameController.text.trim());
    final emergencyRelationship = capitalize(emergencyRelationshipController.text.trim());
    final emergencyNumber = emergencyNumberController.text.trim();

    try {

      // 🔹 Check if email already exists and its verification status
      final existingUsers = await supabase.rpc(
        'check_email_status_v2',
        params: {'p_email': email},
      ) as List<dynamic>?; 

      if (existingUsers != null && existingUsers.isNotEmpty) {
        
        final user = existingUsers.first as Map<String, dynamic>;
        final emailVerified = user['email_confirmed_at'] != null;

        if (emailVerified) {
          await _showEmailUsedDialog(email);
          return;
        } else {
          await _showNeedsVerificationDialog(email);
          return;
        }
      }

      final authResponse = await supabase.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: 'mindmate://reset',
        data: {
          'full_name': '$firstName $lastName',
          'first_name': firstName,
          'last_name': lastName,
          'username': username,
          'emergency_name': emergencyName,
          'emergency_relationship': emergencyRelationship,
          'emergency_number': emergencyNumber,
        },
      );

      final user = authResponse.user;
      if (user == null) throw Exception("Signup failed!");
      
      await _showVerificationDialog(user.email!);
    } catch (e) {
      _showSnack("Error: $e");
    } finally {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  Future<void> _showEmailUsedDialog(String email) {
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Email Already Registered'),
        content: Text(
          'The email $email is already in use.\nPlease sign in or use another email.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showNeedsVerificationDialog(String email) {
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Email Needs Verification'),
        content: Text(
          'The email $email is already registered but not verified.\n'
          'Please check your inbox or resend the verification email.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resendVerificationEmail(email, passwordController.text.trim());
            },
            child: const Text('Resend Email'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _resendVerificationEmail(String email, String password) async {
    final now = DateTime.now();
    if (lastResendTime != null && now.difference(lastResendTime!) < resendCooldown) {
      final remaining = resendCooldown - now.difference(lastResendTime!);
      _showSnack("Wait ${remaining.inSeconds}s before resending.");
      return;
    }

    try {
      await Supabase.instance.client.auth.signUp(email: email, password: password);
      lastResendTime = DateTime.now();
      _showSnack("Verification email resent to $email");
    } catch (e) {
      _showSnack("Error resending verification: $e");
    }
  }

  Future<void> _showVerificationDialog(String email) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Verify Your Email'),
        content: Text(
          'We sent a verification link to $email.\n'
          'Please verify before signing in.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const SignInScreen()),
              );
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    usernameController.dispose();
    emergencyNameController.dispose();
    emergencyRelationshipController.dispose();
    emergencyNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Background(
        gradientColors: const [Color(0xFF4A90E2), Color(0xFF50C9C3)], // blue → green
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Card(
                elevation: 10,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Create Account",
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey[900],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Join MindMate to get started",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ✅ FIXED: PageView with bounded height
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.55,
                          child: PageView(
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              SingleChildScrollView(
                                child: Column(
                                  children: [
                                    CustomTextField(
                                      controller: firstNameController,
                                      label: "First Name",
                                      icon: Icons.person_outline,
                                      validator: (v) =>
                                          v!.trim().isEmpty ? 'Enter first name' : null,
                                    ),
                                    const SizedBox(height: 16),

                                    CustomTextField(
                                      controller: lastNameController,
                                      label: "Last Name",
                                      icon: Icons.person_outline,
                                      validator: (v) =>
                                          v!.trim().isEmpty ? 'Enter last name' : null,
                                    ),
                                    const SizedBox(height: 16),

                                    CustomTextField(
                                      controller: emailController,
                                      label: "Email",
                                      icon: Icons.email_outlined,
                                      keyboardType: TextInputType.emailAddress,
                                      validator: (v) {
                                        if (v == null || v.isEmpty) return 'Enter email';
                                        if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w]{2,4}$')
                                            .hasMatch(v)) {
                                          return 'Invalid email';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),

                                    CustomTextField(
                                      controller: passwordController,
                                      label: "Password",
                                      icon: Icons.lock_outline,
                                      obscureText: _obscurePassword,
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          color: Colors.grey[600],
                                        ),
                                        onPressed: () => setState(
                                            () => _obscurePassword = !_obscurePassword),
                                      ),
                                      validator: (v) => v != null && v.length < 6
                                          ? 'Min 6 chars'
                                          : null,
                                    ),
                                    const SizedBox(height: 16),

                                    CustomTextField(
                                      controller: confirmPasswordController,
                                      label: "Confirm Password",
                                      icon: Icons.lock_outline,
                                      obscureText: _obscureConfirmPassword,
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscureConfirmPassword
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                          color: Colors.grey[600],
                                        ),
                                        onPressed: () => setState(() =>
                                          _obscureConfirmPassword =
                                            !_obscureConfirmPassword),
                                      ),
                                      validator: (v) =>
                                        v != passwordController.text
                                          ? 'Passwords don\'t match'
                                          : null,
                                    ),
                                    const SizedBox(height: 16),

                                    Text(
                                      "Emergency Contact",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueGrey[800],
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    CustomTextField(
                                      controller: emergencyNameController,
                                      label: "Full Name",
                                      icon: Icons.person_outline,
                                      validator: (v) =>
                                          v!.trim().isEmpty ? 'Enter contact name' : null,
                                    ),
                                    const SizedBox(height: 16),


                                    CustomTextField(
                                      controller: emergencyRelationshipController,
                                      label: "Relationship",
                                      icon: Icons.group_outlined,
                                      validator: (v) =>
                                          v!.trim().isEmpty ? 'Enter relationship' : null,
                                    ),
                                    const SizedBox(height: 16),

                                    
                                    CustomTextField(
                                      controller: emergencyNumberController,
                                      label: "Contact Number",
                                      icon: Icons.phone_outlined,
                                      keyboardType: TextInputType.phone,
                                      validator: (v) {
                                        if (v == null || v.isEmpty) {
                                          return 'Enter contact number';
                                        }
                                        if (!RegExp(r'^[0-9]{10,15}$').hasMatch(v)) {
                                          return 'Invalid number';
                                        }
                                        return null;
                                      },
                                    ),

                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        PrimaryButton(
                          text: "Sign Up",
                          onPressed:  signUp,
                          loading: loading,
                        ),
                        const SizedBox(height: 16),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Already have an account? "),
                            TextButton(
                              onPressed: () => Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const SignInScreen()),
                              ),
                              child: const Text(
                                "Sign In",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
