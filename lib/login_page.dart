import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
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
  bool isOtpSent = false;
  String? loginType;
  String? emploginType;
  bool isOtpLogin = false;
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _otpFocus = FocusNode();
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? cachedCompanyCode;

  @override
  void initState() {
    super.initState();
    _refreshCaptcha();
    _loadCompanyCode();
    initOneSignal();
  }


  Future<void> initOneSignal() async {
    final prefs = await SharedPreferences.getInstance();
    String? playerId = prefs.getString('pushSubscriptionId');
    // print('playerId1 $playerId');
    if (playerId == null) {
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      OneSignal.initialize("44a2f48d-1d6b-4a00-929b-18b484123c40");
      await OneSignal.Notifications.requestPermission(true);
      Future.delayed(const Duration(seconds: 7), () async {
        String? playerId = OneSignal.User.pushSubscription.id;
        // print('playerId2 $playerId');
        if (playerId != null) {
          await prefs.setString('pushSubscriptionId', playerId);
        }
      });
    }
  }

  Future<void> _login(BuildContext context) async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No internet connection")),
      );
      return;
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();

    String companyCode = prefs.getString('companyCode') ?? '';
    String email = _usernameController.text.trim();
    String loginCompCode = companyCode.isNotEmpty
        ? companyCode.toUpperCase()
        : _companyCodeController.text.trim().toUpperCase();

    /// VALIDATION
    if (email.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("E-mail required")));
      return;
    }

    if (loginCompCode.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Company code required")));
      return;
    }



    setState(() => _isLoading = true);

    var url = Uri.parse(
        "https://hrms.attendify.ai/index.php/Login_api/verify_loginMobileByotp");

    try {
      if (loginType == null) {
        var response = await http.post(url, body: {
          "email": email,
          "loginCompCode": loginCompCode,
        });

        var data = jsonDecode(response.body);

        if (!data["status"]) {
          showError(data["message"]);
        } else {
          setState(() {
            loginType = data["login_type"];
            emploginType = data["login_type"];

            if (loginType == "otp") {
              isOtpSent = true; // OTP already sent from backend
            }
          });

          Future.delayed(Duration(milliseconds: 300), () {
            if (loginType == "password") {
              FocusScope.of(context).requestFocus(_passwordFocus);
            } else if (loginType == "otp") {
              FocusScope.of(context).requestFocus(_otpFocus);
            }
          });

          if (loginType == "otp") {
            showSuccess("OTP sent successfully");
          }
        }

        setState(() => _isLoading = false);
        return;
      }

      if (loginType == "password") {
        String password = _passwordController.text.trim();

        if (password.isEmpty) {
          setState(() => _isLoading = false);
          showError("Password required");
          return;
        }

        var response = await http.post(url, body: {
          "email": email,
          "password": password,
          "action": "password_login",
          "loginCompCode": loginCompCode
        });

        var data = jsonDecode(response.body);

        if (!data["status"]) {
          showError(data["message"]);
        } else {
          await prefs.setString('companyCode', loginCompCode);
          await saveUserData(prefs, data);
          navigateUser(context, data['level_id']);
        }
      } else if (loginType == "otp") {
        if (_otpController.text.trim().isEmpty) {
          showError("Enter OTP");
          setState(() => _isLoading = false);
          return;
        }

        var response = await http.post(url, body: {
          "email": email,
          "loginCompCode": loginCompCode,
          "action": "verify_otp",
          "otp": _otpController.text.trim(),
        });

        var data = jsonDecode(response.body);

        if (!data["status"]) {
          showError(data["message"]);
        } else {
          await prefs.setString('companyCode', loginCompCode);
          await saveUserData(prefs, data);
          navigateUser(context, data['level_id']);
        }
      }
    } catch (e) {
      showError("Error: $e");
    }

    setState(() => _isLoading = false);
  }

  void showError(String msg) {
    Flushbar(
      message: msg,
      duration: Duration(seconds: 2),
      backgroundColor: Colors.red.shade300,
    ).show(context);
  }

  void showSuccess(String msg) {
    Flushbar(
      message: msg,
      duration: Duration(seconds: 2),
    ).show(context);
  }

  Future<void> saveUserData(SharedPreferences prefs, var data) async {

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
    await prefs.setString('user_code', data['user_code'] ?? data['code']);
    await prefs.setString('unique_code', data['unique_code']);
    await prefs.setString('use_api', data['use_api']);
    await prefs.setString('companyDb', data['company_db']);
    await prefs.setString('apiKey', data['apiKey']);
    await prefs.setString('comp_name', data['comp_name'] ?? null);

    sendPlayerIdToBackend(data['user_id']);
  }

  void navigateUser(BuildContext context, String levelId) {

    if (levelId == "6") {
      Navigator.pushReplacementNamed(context, '/home');
    } else if (levelId == "4") {
      Navigator.pushReplacementNamed(context, '/HrDashboard');
    } else {
      Navigator.pushReplacementNamed(context, '/VisitorsFooter');
    }
  }

  Future<void> sendPlayerIdToBackend(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    String? playerId = prefs.getString('pushSubscriptionId');
    String apiKey = prefs.getString('apiKey') ?? "";
    String companyDb = prefs.getString('companyDb') ?? "";

    if (playerId == null) return;

    await http.post(
      Uri.parse("https://hrms.attendify.ai/index.php/MobileApi/update_push_id"),
      headers: {
        "apiKey": apiKey,
        "companyDb": companyDb,
      },
      body: {
        "user_id": userId, // FIXED
        "pushSubscriptionId": playerId,
        "status": "1", // LOGIN
      },
    );
  }

  Future<void> _loadCompanyCode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      cachedCompanyCode = prefs.getString('companyCode');
    });
  }

  void _refreshCaptcha() {
    const String chars =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
    final Random random = Random();

    setState(() {
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
                        textCapitalization: TextCapitalization.characters,
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
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.person),
                        border: UnderlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 10),

                    if (loginType == "password")
                      Column(
                        children: [
                          TextField(
                            controller: _passwordController,
                            focusNode: _passwordFocus,
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

                          /// 🔁 BACK TO OTP
                          if (emploginType == 'otp')
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    loginType = "otp";
                                    isOtpSent = true;
                                  });

                                  Future.delayed(Duration(milliseconds: 200),
                                      () {
                                    FocusScope.of(context)
                                        .requestFocus(_otpFocus);
                                  });
                                },
                                icon: Icon(Icons.arrow_back, size: 18),
                                label: Text("Sign in with other way"),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                ),
                              ),
                            ),
                        ],
                      ),

                    if (loginType == "otp" && isOtpSent)
                      Column(
                        children: [
                          TextField(
                            controller: _otpController,
                            focusNode: _otpFocus,
                            keyboardType: TextInputType.number,
                            maxLength: 5,
                            decoration: const InputDecoration(
                              labelText: 'Enter OTP',
                              prefixIcon: Icon(Icons.lock),
                              border: UnderlineInputBorder(),
                              counterText: "",
                            ),
                          ),

                          ///  SWITCH TO PASSWORD
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  loginType = "password";
                                  isOtpSent = false;
                                });

                                Future.delayed(Duration(milliseconds: 200), () {
                                  FocusScope.of(context)
                                      .requestFocus(_passwordFocus);
                                });
                              },
                              child: Text("Sign in with other way"),
                            ),
                          ),
                        ],
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
                            ? Text("Processing...")
                            : Text(
                                loginType == null
                                    ? "Continue"
                                    : loginType == "password"
                                        ? "Login"
                                        : isOtpSent
                                            ? "Verify OTP"
                                            : "Send OTP",
                              ),
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
          : SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: const Text(
            "Powered by Techkshetra Info Solutions Pvt. Ltd.",
            style: TextStyle(
              color: Colors.black,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
