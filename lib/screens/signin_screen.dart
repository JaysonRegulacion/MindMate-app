import 'package:flutter/material.dart';
import 'package:mindmate/screens/home_screen.dart';
import 'package:mindmate/widgets/background.dart';
import 'package:mindmate/widgets/custom_text_field.dart';
import 'package:mindmate/widgets/primary_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mindmate/services/user_session.dart';
import 'signup_screen.dart';
import 'forgotpass_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  // 🔐 Main sign-in process
  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      // 🔹 Attempt online login
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null && mounted) {
        // ✅ Save user credentials locally
        await UserSession.saveUser(response.user!.id, email, password);

        // ✅ Fetch user's first_name from Supabase
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('first_name')
            .eq('id', response.user!.id)
            .maybeSingle();

        if (profile != null && profile['first_name'] != null) {
          await UserSession.saveUserProfile(profile['first_name']);
        }

        // ✅ Navigate to home screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
        return;
      }
    } on AuthException catch (e) {
      // 🔹 Fallback: offline login
      final result = await UserSession.verifyOfflineLogin(email, password);

      if (result == "valid" && mounted) {
        // ✅ Navigate to home screen offline
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
        return;
      }

      if (mounted) {
        String message;
        if (result == "expired") {
          message = "Offline session expired. Please log in online.";
        } else if (result == "invalid") {
          message = "Invalid email or password. Try logging in online.";
        } else {
          message = e.message;
        }

        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding =
        screenWidth < 400 ? 16.0 : screenWidth < 600 ? 24.0 : 40.0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Background(
        gradientColors: const [Color(0xFF4A90E2), Color(0xFF50C9C3)],
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 40,
            ),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 6,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        "Welcome Back",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _emailController,
                        label: "Email",
                        keyboardType: TextInputType.emailAddress,
                        validator: (val) => val == null || !val.contains("@")
                            ? "Enter a valid email"
                            : null,
                        icon: Icons.email,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _passwordController,
                        label: "Password",
                        obscureText: _obscurePassword,
                        validator: (val) => val == null || val.length < 6
                            ? "Password must be at least 6 characters"
                            : null,
                        icon: Icons.lock,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ForgotPasswordScreen(),
                              ),
                            );
                          },
                          child: const Text("Forgot Password?"),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : PrimaryButton(
                              text: "Sign In",
                              onPressed: _signIn,
                              loading: _isLoading,
                            ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Don’t have an account?"),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SignUpScreen(),
                                ),
                              );
                            },
                            child: const Text("Sign Up"),
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
    );
  }
}
