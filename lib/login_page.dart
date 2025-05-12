import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
final TextEditingController _usernameController = TextEditingController(text: 'vinay.s@techkshetrainfo.com');
final TextEditingController _companyCodeController = TextEditingController();
final TextEditingController _passwordController = TextEditingController(text: 'Techk@123');
  final TextEditingController _captchaController = TextEditingController();
  bool _isLoading = false;
  
  String _captchaValue =
       "1234"; // Dummy CAPTCHA value (should be fetched from API)

Future<void> _login(BuildContext context) async {
  // Check Internet Connection
  var connectivityResult = await Connectivity().checkConnectivity();
  if (connectivityResult == ConnectivityResult.none) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("No internet connection. Please check your network settings.")),
    );
    return;
  }

  final SharedPreferences prefs = await SharedPreferences.getInstance();

  String companyCode = prefs.getString('companyCode') ?? "";
  String username = _usernameController.text.trim() ?? 'vinay.s@techkshetrainfo.com';
  String password = _passwordController.text.trim() ?? 'Techk@123';
  String loginCompCode = companyCode.isNotEmpty ? companyCode : _companyCodeController.text.trim();
  // String loginCompCode = 'TKIS';

  // Validation
  if (username.isEmpty && password.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("E-mail and Password required")));
    return;
  } else if (username.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("E-mail required")));
    return;
  } else if (password.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Password required")));
    return;
  } else if (loginCompCode.isEmpty || loginCompCode == " ") {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Company code required")));
    return;
  }

  // Save company code
  await prefs.setString('companyCode', loginCompCode);

  setState(() => _isLoading = true);

  var url = Uri.parse("https://app.attendify.ai/template/public/index.php/Login_api/verify_loginMobile");

  try {
    var response = await http.post(url, body: {
      "email": username,
      "password": password,
      "login_type": "2",
      "loginCompCode": loginCompCode
    });

    var data = jsonDecode(response.body);
    // print("Response Data: $data"); // Debugging purpose

    if (data["status"] == false) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data["message"])));
    } else {
      // Store login details in SharedPreferences
      await prefs.setString('token', data['token']);
      await prefs.setString('user_id', data['user_id'].toString());
      await prefs.setString('username', data['username']);
      await prefs.setString('last_name', data['last_name']);
      await prefs.setString('level_id', data['level_id'].toString());
      await prefs.setString('cid', data['cid'].toString());
      await prefs.setString('email', data['email']);
      await prefs.setString('user_profile', data['user_profile']);
      await prefs.setString('department_name', data['department_name']);
      await prefs.setString('department', data['department'].toString());
      await prefs.setString('employe_code', data['code']);
      await prefs.setString('unique_code', data['unique_code']);
      await prefs.setString('use_api', data['use_api']);
      await prefs.setString('companyDb', data['company_db']);
      await prefs.setString('apiKey', data['apiKey']);

      String? pushSubscriptionId = prefs.getString('pushSubscriptionId');

      if (pushSubscriptionId == null || pushSubscriptionId.isEmpty) {
        //await initializeOneSignal();
        pushSubscriptionId = prefs.getString('pushSubscriptionId');
        //await setNotificationIdToken();
      } else {
       // await setNotificationIdToken();
      }

      // Navigate based on user level
      if (data['level_id'].toString() == "6") {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/visitors');
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login Successful")));
    }
  } catch (e) {
    print("Error: $e");
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
  }

  setState(() => _isLoading = false);
}

@override
void initState() {
  super.initState();
  _refreshCaptcha(); // Generate a new CAPTCHA when the page loads
}

  
void _refreshCaptcha() {
  const String chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
  final Random random = Random();

  setState(() {
    _captchaValue = List.generate(5, (index) => chars[random.nextInt(chars.length)]).join();
  });
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image:
                AssetImage("assets/bk_img.png"), // Ensure the image exists
            fit: BoxFit.cover,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Login Title with Logo
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset("assets/hrms_logo.png",
                      height: 50), // Ensure logo.png exists in assets
                  const SizedBox(width: 8),
                ],
              ),
              const SizedBox(height: 10),
              // Subtitle Text
              const Text(
                "Your Intelligent Attendance Partner",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF2C2C2C), // Dark gray color
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 3),

              // Username Input
              TextField(
                controller: _companyCodeController,
                decoration: const InputDecoration(
                  labelText: 'Company Code',
                  prefixIcon: Icon(Icons.code),
                  border: UnderlineInputBorder(),
                ),
              ),
              const SizedBox(height: 3),

              // Username Input
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.person),
                  border: UnderlineInputBorder(),
                ),
              ),
              const SizedBox(height: 3),

              // Password Input
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                  border: UnderlineInputBorder(),
                ),
              ),
              const SizedBox(height: 3),

              // CAPTCHA Input with Refresh Button
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _captchaController,
                      decoration: const InputDecoration(
                        labelText: 'Enter CAPTCHA',
                        prefixIcon: Icon(Icons.verified_user),
                        border: UnderlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                    ),
                    child: Text(
                      _captchaValue,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Color(0xFF0557a2)),
                    onPressed: _refreshCaptcha,
                  ),
                ],
              ),
              const SizedBox(height: 5),

              // Login Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () => _login(context),  // Wrap inside a function
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0557a2), // Button color
                    foregroundColor: Colors.white, // Text color
                    padding: const EdgeInsets.symmetric(
                        vertical: 8), // Button height
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                 child: _isLoading
                ? const Text(
                    "Logging in...",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  )
                : const Text("Login"),

                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
