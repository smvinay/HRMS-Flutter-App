import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:another_flushbar/flushbar.dart';

import 'visitorPages/VisitorsFooter.dart';


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
final TextEditingController _usernameController = TextEditingController();
final TextEditingController _companyCodeController = TextEditingController();
final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _captchaController = TextEditingController();
  bool _isLoading = false;
bool _obscurePassword = true;
String _captchaValue =
       "1234"; // Dummy CAPTCHA value (should be fetched from API)
String? cachedCompanyCode;

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

  String companyCode = prefs.getString('companyCode') ?? '';
  String username = _usernameController.text.trim() ?? '';
  String password = _passwordController.text.trim() ?? '';
  String loginCompCode = companyCode.isNotEmpty
      ? companyCode
      : _companyCodeController.text.trim();

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
  var url = Uri.parse("https://hrms.attendify.ai/index.php/Login_api/verify_loginMobile");

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
      Flushbar(
        message: data["message"],
        duration: Duration(seconds: 2),
        backgroundColor: Colors.red.shade300,
        borderRadius: BorderRadius.circular(8),
        margin: EdgeInsets.all(12),
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
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
      }else if (data['level_id'].toString() == "4") {
        Navigator.pushReplacementNamed(context, '/HrDashboard');
      }  else {
        Navigator.pushReplacementNamed(context, '/VisitorsFooter');
      }

    }
  } catch (e) {
    // print("Error: $e");

    Flushbar(
      message: "Error: $e",
      duration: Duration(seconds: 2),
      backgroundColor: Colors.red.shade300,
      borderRadius: BorderRadius.circular(8),
      margin: EdgeInsets.all(12),
      flushbarPosition: FlushbarPosition.TOP,
    ).show(context);

  }

  setState(() => _isLoading = false);
}

@override
void initState() {
  super.initState();
  _refreshCaptcha();
  _loadCompanyCode();
}

Future<void> _loadCompanyCode() async {
  final prefs = await SharedPreferences.getInstance();
  setState(() {
    cachedCompanyCode = prefs.getString('companyCode');
  });
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

  final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom != 0;

  return Scaffold(
    body: Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage("assets/bk_img.png"),
          fit: BoxFit.cover,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [

            /// FORM AREA
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  /// LOGO
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset("assets/hrms_logo.png", height: 50),
                    ],
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    "Your Intelligent Attendance Partner",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF2C2C2C),
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 25),

                  /// COMPANY CODE
                  if (cachedCompanyCode == null || cachedCompanyCode!.isEmpty)
                    TextField(
                      controller: _companyCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Company Code',
                        prefixIcon: Icon(Icons.code),
                        border: UnderlineInputBorder(),
                      ),
                    ),

                  const SizedBox(height: 10),

                  /// USERNAME
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.person),
                      border: UnderlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 10),

                  /// PASSWORD
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock),
                      border: const UnderlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  /// LOGIN BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : () => _login(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0557a2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const Text("Logging in...")
                          : const Text("Login"),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),

    /// FOOTER (Hides when keyboard opens)
    bottomNavigationBar: isKeyboardOpen
        ? null
        : Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: const Text(
        "Powered by Techkshetra Info Solutions Pvt. Ltd.",
        style: TextStyle(
          color: Colors.black,
          fontSize: 13,
        ),
        textAlign: TextAlign.center,
      ),
    ),
  );
}
}
