import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../hrPages/employee_leave_details_page.dart';
import '../widgets/toast.dart';
import 'emp_drawer.dart';

class ApplyLeavePage extends StatefulWidget {
  final DateTime? selectedDate;
  final int leaveId;

  const ApplyLeavePage({
    super.key,
    this.selectedDate,
    this.leaveId = 0,
  });

  @override
  State<ApplyLeavePage> createState() => _ApplyLeavePageState();
}

class _ApplyLeavePageState extends State<ApplyLeavePage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  DateTime? fromDate;
  DateTime? toDate;
  double days = 1.0;
  String selectedLeaveType = "";
  String leaveFor = "1";
  final reasonController = TextEditingController();
  late AnimationController _controller;
  late DateTime selectedDateSafe;

  List<dynamic> leaveTypes = [];
  List<dynamic> leaveTypesCounts = [];
  Map<String, dynamic> leaveCount = {};
  bool isLoading = true;

  String? selectedLeaveTypeId = '1';
  List<dynamic> myLeaves = [];
  bool isListLoaded = false;
  bool isWithdrawing = false;
  bool isSubmitting = false;
  bool isModalOpened = false;
  int activeLeaveId = 0;
  Set<String> expandedIndex = <String>{};

  late TextEditingController fromDateController;
  late TextEditingController toDateController;
  late TextEditingController daysController;

  List teamLeaves = [];
  List filteredTeamLeaves = [];
  bool teamLoading = false;

  String teamSearch = "";
  String teamFilter = "all";

  Map<String, String> teamLeaveTypes = {
    "All": "All",
  };

  Map<String, String> teamStatusMap = {
    "All": "All",
    "0": "Pending",
    "1": "Approved",
    "2": "Rejected"
  };

  String selectedTeamLeaveType = "All";
  String selectedTeamStatus = "All";

  final FocusNode leaveTypeFocus = FocusNode();
  final FocusNode reasonFocus = FocusNode();
  final FocusNode fromDateFocus = FocusNode();
  final FocusNode toDateFocus = FocusNode();

  bool leaveTypeError = false;
  bool reasonError = false;
  bool fromDateError = false;
  bool toDateError = false;

  @override
  void initState() {
    super.initState();

    _tabController =
        TabController(length: ((teamLeaves).isNotEmpty) ? 3 : 2, vsync: this);

    fromDateController = TextEditingController();
    toDateController = TextEditingController();
    daysController = TextEditingController();

    selectedDateSafe = widget.selectedDate ?? DateTime.now();

    fromDate = selectedDateSafe;
    toDate = selectedDateSafe;
    days = 1.0;

    updateControllers();
    calculateDays();

    fetchLeaveData();
    fetchTeamLeaves();
  }

  @override
  void dispose() {
    _tabController.dispose();
    fromDateController.dispose();
    toDateController.dispose();
    daysController.dispose();
    reasonController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void updateControllers() {
    fromDateController.text = formatDate(fromDate!);
    toDateController.text = formatDate(toDate!);
    daysController.text =
        days % 1 == 0 ? days.toInt().toString() : days.toString();
  }

  Future<void> fetchLeaveData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      String apiKey = prefs.getString('apiKey') ?? "";
      String companyDb = prefs.getString('companyDb') ?? "";
      String cid = prefs.getString('cid') ?? "";
      String empCode = prefs.getString('employe_code') ?? "";
      String userId = prefs.getString('user_id') ?? "";

      final response = await http.post(
        Uri.parse(
            "https://hrms.attendify.ai/index.php/MobileApi/employeeLeavedetails"),
        headers: {"apiKey": apiKey, "companyDb": companyDb},
        body: {
          "cid": cid,
          "user_id": userId,
          "code": empCode,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          leaveTypes = List.from(data['leaveTypeWise']);
          leaveCount = data['LeavesCount_User'];
          myLeaves = data['userLeaves'];

          // print("myLeaves $myLeaves");

          double pending = (leaveCount['pending'] ?? 0).toDouble();

          if (pending <= 0) {
            leaveTypes.insert(
                0, {"type": "LOP (Loss of Pay)", "type_id": "0", "pending": 0});
          }
        });

        ///  RESET FORM AFTER FETCH
        resetForm();

        if (activeLeaveId != 0 && myLeaves.isNotEmpty && !isModalOpened) {
          isModalOpened = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            openEditLeaveModal(activeLeaveId);
          });
        }
      }
    } catch (e) {
      print(e);
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> fetchTeamLeaves() async {
    setState(() => teamLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      String apiKey = prefs.getString('apiKey') ?? "";
      String companyDb = prefs.getString('companyDb') ?? "";
      String userID = prefs.getString('user_id') ?? "";
      String levelId = prefs.getString('level_id') ?? "";

      final response = await http.get(
        Uri.parse(
          "https://hrms.attendify.ai/index.php/MobileApi/allEmpLeaves?userId=$userID&levelId=$levelId",
        ),
        headers: {
          "apiKey": apiKey,
          "companyDb": companyDb,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // SAVE CURRENT TAB INDEX
        int currentIndex = _tabController.index;

        teamLeaves = data['userLeaves'] ?? [];

        List types = data['leaveType'] ?? [];

        teamLeaveTypes = {
          "All": "All",
          for (var e in types) e['type'].toString(): e['type'].toString()
        };

        applyTeamFilter();

        // NEW TAB COUNT
        int newLength = teamLeaves.isNotEmpty ? 3 : 2;

        // PREVENT INVALID INDEX
        if (currentIndex >= newLength) {
          currentIndex = newLength - 1;
        }

        // RECREATE CONTROLLER
        _tabController.dispose();

        _tabController = TabController(
          length: newLength,
          vsync: this,
          initialIndex: currentIndex,
        );

        setState(() {});
      }
    } catch (e) {
      debugPrint(e.toString());
    }

    setState(() => teamLoading = false);
  }

  void applyTeamFilter() {
    List temp = List.from(teamLeaves);

    if (teamFilter == "approved") {
      temp = temp.where((e) => e['approved'].toString() == "1").toList();
    } else if (teamFilter == "rejected") {
      temp = temp.where((e) => e['approved'].toString() == "2").toList();
    } else if (teamFilter == "pending") {
      temp = temp.where((e) => e['approved'].toString() == "0").toList();
    }

    if (selectedTeamLeaveType != "All") {
      temp = temp.where((e) => e['type'] == selectedTeamLeaveType).toList();
    }

    if (selectedTeamStatus != "All") {
      temp = temp
          .where((e) => e['approved'].toString() == selectedTeamStatus)
          .toList();
    }

    setState(() {
      filteredTeamLeaves = temp;
    });
  }

  void calculateDays() {
    if (leaveFor == "0.5") {
      days = 0.5;
    } else {
      if (fromDate != null && toDate != null) {
        int diff = toDate!.difference(fromDate!).inDays + 1;
        if (diff < 1) diff = 1;
        days = diff.toDouble();
      }
    }

    updateControllers(); //  ADD THIS
  }

  String formatDate(DateTime date) {
    return DateFormat('dd-MM-yyyy').format(date);
  }

  Future<void> pickDate(bool isFrom) async {
    DateTime now = DateTime.now();

    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? fromDate! : toDate!,
      firstDate: isFrom ? now : fromDate!, // key fix
      lastDate: DateTime(2030),
    );

    if (picked == null) return;

    setState(() {
      if (isFrom) {
        fromDate = picked;

        ///  Ensure To Date is not before From Date
        if (toDate == null || toDate!.isBefore(picked)) {
          toDate = picked;
        }

        ///  Half day → force same date
        if (leaveFor == "0.5") {
          toDate = picked;
        }
      } else {
        ///  Block To Date change for Half Day
        if (leaveFor == "0.5") return;

        ///  Ensure To >= From
        if (picked.isBefore(fromDate!)) {
          toDate = fromDate;
        } else {
          toDate = picked;
        }
      }

      calculateDays();
    });
  }

  Color getStatusColor(int status) {
    switch (status) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.red;
      case 3:
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  String getStatusText(int status) {
    switch (status) {
      case 1:
        return "Approved";
      case 2:
        return "Rejected";
      case 3:
        return "Withdrawn";
      default:
        return "Pending";
    }
  }

  Future<void> submit() async {
    if (isSubmitting) return;

    setState(() {
      leaveTypeError = false;
      reasonError = false;
      fromDateError = false;
      toDateError = false;
    });

    if (selectedLeaveTypeId == null || selectedLeaveTypeId!.isEmpty) {
      setState(() => leaveTypeError = true);

      FocusScope.of(context).requestFocus(leaveTypeFocus);

      AppToast.show("Select leave type", isError: true);
      return;
    }

    if (reasonController.text.trim().isEmpty) {
      setState(() => reasonError = true);

      FocusScope.of(context).requestFocus(reasonFocus);

      AppToast.show("Enter reason", isError: true);
      return;
    }

    if (reasonController.text.trim().length < 5) {
      setState(() => reasonError = true);

      FocusScope.of(context).requestFocus(reasonFocus);

      AppToast.show(
        "Reason must be minimum 5 characters",
        isError: true,
      );
      return;
    }

    if (toDate!.isBefore(fromDate!)) {
      setState(() {
        fromDateError = true;
        toDateError = true;
      });

      FocusScope.of(context).requestFocus(toDateFocus);

      AppToast.show("Invalid date range", isError: true);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm"),
        content: const Text("Do you want to apply this leave?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      String apiKey = prefs.getString('apiKey') ?? "";
      String companyDb = prefs.getString('companyDb') ?? "";
      String userId = prefs.getString('user_id') ?? "";
      String cid = prefs.getString('cid') ?? "";
      String empCode = prefs.getString('employe_code') ?? "";

      final response = await http.post(
        Uri.parse("https://hrms.attendify.ai/index.php/MobileApi/apply_leave"),
        headers: {"apiKey": apiKey, "companyDb": companyDb},
        body: {
          "cid": cid,
          "code": empCode,
          "user_id": userId,
          "leave_type": selectedLeaveTypeId ?? "0",
          "leave_for": leaveFor,
          "from_date": DateFormat('yyyy-MM-dd').format(fromDate!),
          "to_date": DateFormat('yyyy-MM-dd').format(toDate!),
          "days": leaveFor == "0.5" ? "0.5" : days.toString(),
          "reason": reasonController.text.trim(),
        },
      );
      final res = jsonDecode(response.body);

      if (res['status'] == true) {
        await fetchLeaveData();
        if (!mounted) return;
        _tabController.animateTo(1);
        AppToast.show("Leave applied successfully");
      } else {
        AppToast.show("Failed to apply leave", isError: true);
      }
    } catch (e) {
      AppToast.show("Something went wrong", isError: true);
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  Widget card({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: child,
    );
  }

  Widget dateBox(String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Ink(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(value), const Icon(Icons.calendar_today, size: 18)],
        ),
      ),
    );
  }

  double _calcScaleFromWidth(double w) {
    const base = 475.0;
    final raw = (w / base);
    return raw.clamp(0.7, 1.2);
  }

  double _s(double size, double scale) {
    return size * scale;
  }

  Future<void> withdrawLeave(String leaveId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm"),
        content: const Text("Are you sure you want to withdraw this leave?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      setState(() => isWithdrawing = true);
      final prefs = await SharedPreferences.getInstance();

      String apiKey = prefs.getString('apiKey') ?? "";
      String companyDb = prefs.getString('companyDb') ?? "";

      final response = await http.post(
        Uri.parse(
            "https://hrms.attendify.ai/index.php/Setting/leave_withdrawn_web"),
        headers: {
          "apiKey": apiKey,
          "companyDb": companyDb,
        },
        body: {
          "id": leaveId,
        },
      );

      final res = jsonDecode(response.body);

      if (res['status'] == true) {
        AppToast.show("Leave withdrawn successfully");

        await fetchLeaveData();
      } else {
        AppToast.show("Failed to withdraw", isError: true);
      }
    } catch (e) {
      AppToast.show("Something went wrong", isError: true);
    } finally {
      setState(() => isWithdrawing = false);
    }
  }

  void openEditLeaveModal(int leaveId) {
    var leave = myLeaves.firstWhere(
      (l) => l['leave_id'].toString() == leaveId.toString(),
      orElse: () => {},
    );

    if (leave.isEmpty) return;

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        pageBuilder: (_, __, ___) {
          return EditLeaveModal(
            leave: leave,
            leaveTypes: leaveTypes,
            onUpdated: () async {
              Navigator.pop(context);

              setState(() {
                activeLeaveId = 0;
                isModalOpened = false;
              });

              await fetchLeaveData();
            },
          );
        },

        ///  SMOOTH ANIMATION
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1), // from bottom
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic, //  smooth open
              reverseCurve: Curves.easeInCubic, //  smooth close
            )),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },

        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = _calcScaleFromWidth(MediaQuery.of(context).size.width);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Leaves',
          style: TextStyle(
            color: Colors.white,
            fontSize: _s(20, scale),
          ),
        ),
        backgroundColor: const Color(0xFF0557a2),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: CustomDrawer(
        currentRoute: '/emp_leave',
      ),
      body: Column(
        children: [
          ///  TOP SPACING
          const SizedBox(height: 5),

          Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: TabBar(
                controller: _tabController,
                dividerColor: Colors.transparent, //  remove bottom line
                indicator: BoxDecoration(
                  color: const Color(0xFF0557a2),
                  borderRadius: BorderRadius.circular(25),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.black54,
                indicatorSize: TabBarIndicatorSize.tab,
                splashBorderRadius: BorderRadius.circular(25),

                tabs: [
                  const Tab(text: "Apply"),
                  const Tab(text: "My Leaves"),
                  if (teamLeaves.isNotEmpty) const Tab(text: "Team Leaves"),
                ],
              )),

          const SizedBox(height: 5),

          ///  TAB CONTENT
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const BouncingScrollPhysics(),
              children: [
                _applyTab(),
                _listTab(),
                if (teamLeaves.isNotEmpty) _teamLeavesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // void resetForm() {
  //   fromDate = selectedDateSafe;
  //   toDate = selectedDateSafe;
  //   leaveFor = "1";
  //   days = 1.0;
  //
  //   selectedLeaveTypeId =
  //       leaveTypes.isNotEmpty ? leaveTypes[0]['type_id'].toString() : null;
  //
  //   reasonController.clear();
  //
  //   updateControllers(); //  must
  //
  //   setState(() {});
  // }

  void resetForm() {
    fromDate = selectedDateSafe;
    toDate = selectedDateSafe;
    leaveFor = "1";
    days = 1.0;

    // REMOVE AUTO SELECT
    selectedLeaveTypeId = null;

    reasonController.clear();

    updateControllers();

    setState(() {});
  }

  Widget _applyTab() {
    final scale = _calcScaleFromWidth(MediaQuery.of(context).size.width);
    Map<String, dynamic>? selectedLeaveData;

    if (selectedLeaveTypeId != null && selectedLeaveTypeId!.isNotEmpty) {
      try {
        selectedLeaveData = leaveTypes.firstWhere(
          (e) => e['type_id'].toString() == selectedLeaveTypeId,
        );
      } catch (e) {
        selectedLeaveData = null;
      }
    }

// AVAILABLE COUNT
    double availableLeave = double.tryParse(
          (selectedLeaveData?['pending'] ?? 0).toString(),
        ) ??
        0;

// SHOW WARNING ONLY AFTER USER SELECTION
    bool showLopWarning = selectedLeaveData != null &&
        selectedLeaveTypeId != "0" &&
        days > availableLeave;

    return RefreshIndicator(
      color: const Color(0xFF0557a2),
      onRefresh: fetchLeaveData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          padding: EdgeInsets.all(_s(12, scale)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_s(12, scale)),
            boxShadow: [
              BoxShadow(color: Colors.black12, blurRadius: _s(6, scale))
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              /// Available Leaves
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF3FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD0E3FF)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    /// 🔹 TOP ROW (AVAILABLE + TAKEN)
                    Row(
                      children: [
                        /// AVAILABLE
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.account_balance_wallet,
                                  color: Color(0xFF0557a2), size: 18),
                              const SizedBox(width: 6),
                              Text(
                                "Available",
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade600),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "${leaveCount['pending'] ?? 0}",
                                style: const TextStyle(
                                  color: Color(0xFF0557a2),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),

                        /// DIVIDER
                        Container(
                          height: 24,
                          width: 1,
                          color: const Color(0xFFD0E3FF),
                        ),

                        /// TAKEN
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Icon(Icons.event_available,
                                  color: Color(0xFF0557a2), size: 18),
                              const SizedBox(width: 6),
                              Text(
                                "Taken",
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade600),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "${leaveCount['used'] ?? 0}",
                                style: const TextStyle(
                                  color: Color(0xFF0557a2),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    /// 🔹 LEAVE TYPES GRID
                    LayoutBuilder(
                      builder: (context, constraints) {
                        double itemWidth = constraints.maxWidth > 650
                            ? constraints.maxWidth / 4
                            : constraints.maxWidth / 2;

                        return Wrap(
                          crossAxisAlignment: WrapCrossAlignment.start,
                          spacing: 8,
                          runSpacing: 6,
                          children: leaveTypes.map((e) {
                            return SizedBox(
                              width: itemWidth - 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: const Color(0xFFD0E3FF)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        e['type'] ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                    Text(
                                      "${e['pending'] ?? 0}",
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: (e['pending'] ?? 0) == 0
                                            ? Colors.red
                                            : const Color(0xFF0557a2),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),

              if (showLopWarning) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.orange.shade300,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange.shade800,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Selected leave exceeds available ${selectedLeaveData?['type'] ?? ''} balance. Additional leave days will be considered as Loss of Pay (LOP).",
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              SizedBox(height: _s(12, scale)),

              /// GRID START
              LayoutBuilder(
                builder: (context, constraints) {
                  int columns = constraints.maxWidth > 700
                      ? 3
                      : constraints.maxWidth > 450
                          ? 2
                          : 1;

                  double itemWidth =
                      (constraints.maxWidth - ((columns - 1) * _s(8, scale))) /
                          columns;

                  return Wrap(
                    spacing: _s(6, scale),
                    runSpacing: _s(6, scale),
                    children: [
                      _wrapItem(
                          itemWidth,
                          _gridField(
                              scale,
                              DropdownButtonFormField<String>(
                                value: selectedLeaveTypeId,
                                hint: const Text("Select Leave Type"),
                                focusNode: leaveTypeFocus,
                                items: leaveTypes
                                    .map<DropdownMenuItem<String>>((e) {
                                  return DropdownMenuItem(
                                    value: e['type_id'].toString(),
                                    child: Text(e['type']),
                                  );
                                }).toList(),
                                onChanged: (v) {
                                  setState(() {
                                    selectedLeaveTypeId = v;
                                  });
                                },
                                decoration: premiumInput(
                                  "Leave Category",
                                  icon: Icons.category,
                                  hasError: leaveTypeError,
                                ),
                              ))),

                      _wrapItem(
                          itemWidth,
                          _gridField(
                            scale,
                            DropdownButtonFormField<String>(
                              value: leaveFor,
                              hint: const Text("Select Type"),
                              items: const [
                                DropdownMenuItem(
                                    value: "1", child: Text("Full Day")),
                                DropdownMenuItem(
                                    value: "0.5", child: Text("Half Day")),
                              ],
                              onChanged: (v) {
                                setState(() {
                                  leaveFor = v!;
                                  if (leaveFor == "0.5") {
                                    toDate = fromDate;
                                  }
                                  calculateDays();
                                });
                              },
                              decoration: premiumInput("Leave For",
                                  icon: Icons.timelapse),
                            ),
                          )),

                      _wrapItem(
                        itemWidth,
                        _gridField(
                          scale,
                          TextFormField(
                            readOnly: true,
                            focusNode: fromDateFocus,
                            controller: fromDateController,
                            onTap: () => pickDate(true),
                            decoration: premiumInput(
                              "From Date",
                              icon: Icons.calendar_today,
                              hasError: fromDateError,
                            ),
                          ),
                        ),
                      ),

                      _wrapItem(
                        itemWidth,
                        _gridField(
                          scale,
                          TextFormField(
                            readOnly: true,
                            focusNode: toDateFocus,
                            controller: toDateController,
                            onTap: leaveFor == "0.5"
                                ? null
                                : () => pickDate(false),
                            decoration: premiumInput(
                              "To Date",
                              icon: Icons.calendar_today,
                              hasError: toDateError,
                            ),
                          ),
                        ),
                      ),

                      _wrapItem(
                        itemWidth,
                        _gridField(
                          scale,
                          TextFormField(
                            readOnly: true,
                            controller: daysController,
                            decoration:
                                premiumInput("Days", icon: Icons.date_range),
                          ),
                        ),
                      ),

                      /// Reason full width always
                      SizedBox(
                        width: constraints.maxWidth,
                        child: _gridField(
                          scale,
                          TextField(
                            controller: reasonController,
                            focusNode: reasonFocus,
                            maxLines: 2,
                            maxLength: 500,
                            decoration: premiumInput(
                              "Reason",
                              icon: Icons.edit,
                              hasError: reasonError,
                            ).copyWith(
                              helperText: "Minimum 5 characters",
                            ),
                            onChanged: (value) {
                              if (value.trim().length >= 5) {
                                setState(() => reasonError = false);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

              SizedBox(height: _s(10, scale)),

              /// Submit Button
              Center(
                child: SizedBox(
                  child: ElevatedButton(
                    onPressed: isSubmitting ? null : submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0557a2),
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            "Apply Leave",
                            style: TextStyle(fontSize: 14, color: Colors.white),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _listTab() {
    return RefreshIndicator(
      color: const Color(0xFF0557a2),
      onRefresh: fetchLeaveData,
      child: myLeaves.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 200),
                Center(child: Text("No leaves found")),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(
                bottom: 10,
                left: 10,
                right: 10,
              ),
              itemCount: myLeaves.length,
              itemBuilder: (context, index) {
                final item = myLeaves[index];

                int status = int.tryParse(item['approved'].toString()) ?? 0;

                DateTime today = DateTime.now();
                DateTime fromDate = DateTime.parse(item['from_date']);

                DateTime appliedDate = DateTime.parse(item['applied_date']);

                DateTime todayDate =
                    DateTime(today.year, today.month, today.day);

                DateTime fromDateOnly =
                    DateTime(fromDate.year, fromDate.month, fromDate.day);

                bool isFutureOrToday = !fromDateOnly.isBefore(todayDate);

                bool showAction =
                    (status == 0) || (status == 1 && isFutureOrToday);

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.15),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// TOP CONTENT
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// LEFT CONTENT
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                /// ROW 1
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item['type'] ?? "",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: getStatusColor(status)
                                            .withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: getStatusColor(status)
                                              .withOpacity(0.3),
                                        ),
                                      ),
                                      child: Text(
                                        getStatusText(status),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: getStatusColor(status),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 3),

                                /// ROW 2
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        item['reporting_to_name'] ?? "",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 10,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          const Icon(
                                            Icons.calendar_today,
                                            size: 12,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              "${formatDate(DateTime.parse(item['from_date']))} → ${formatDate(DateTime.parse(item['to_date']))}"
                                              " (${item['days']} ${double.tryParse(item['days'].toString()) == 1 ? 'day' : 'days'})",
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.end,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      /// APPLIED DATE + ACTIONS
                      Row(
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time,
                                size: 12,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                formatDate(appliedDate),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          if (showAction)
                            GestureDetector(
                              onTap: () {
                                withdrawLeave(
                                  item['leave_id'].toString(),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.deepOrangeAccent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.deepOrangeAccent,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.outbound,
                                  size: 15,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                          if (showAction) const SizedBox(width: 8),
                          if (status == 0)
                            GestureDetector(
                              onTap: () {
                                int leaveId =
                                    int.tryParse(item['leave_id'].toString()) ??
                                        0;

                                openEditLeaveModal(leaveId);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.lightBlueAccent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.lightBlueAccent,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  size: 15,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                        ],
                      ),

                      /// REASON
                      if ((item['reason'] ?? "").toString().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            bool overflow = isTextOverflow(
                              item['reason'],
                              constraints.maxWidth,
                              const TextStyle(
                                fontSize: 11,
                                height: 1.4,
                              ),
                            );

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.notes,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    item['reason'],
                                    maxLines: overflow
                                        ? (expandedIndex
                                                .contains("listreason_$index")
                                            ? null
                                            : 2)
                                        : null,
                                    overflow: overflow
                                        ? (expandedIndex
                                                .contains("listreason_$index")
                                            ? TextOverflow.visible
                                            : TextOverflow.ellipsis)
                                        : TextOverflow.visible,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade700,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                                if (overflow)
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (expandedIndex
                                            .contains("listreason_$index")) {
                                          expandedIndex
                                              .remove("listreason_$index");
                                        } else {
                                          expandedIndex
                                              .add("listreason_$index");
                                        }
                                      });
                                    },
                                    child: Icon(
                                      expandedIndex
                                              .contains("listreason_$index")
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                      size: 18,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],

                      /// REJECT REASON
                      if (status == 2 &&
                          (item['reject_reason'] ?? "")
                              .toString()
                              .isNotEmpty) ...[
                        const SizedBox(height: 10),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            bool overflow = isTextOverflow(
                              item['reject_reason'],
                              constraints.maxWidth,
                              const TextStyle(
                                fontSize: 11,
                                height: 1.4,
                              ),
                            );

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.cancel,
                                  size: 14,
                                  color: Colors.red,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    item['reject_reason'],
                                    maxLines: overflow
                                        ? (expandedIndex
                                                .contains("listreject_$index")
                                            ? null
                                            : 2)
                                        : null,
                                    overflow: overflow
                                        ? (expandedIndex
                                                .contains("listreject_$index")
                                            ? TextOverflow.visible
                                            : TextOverflow.ellipsis)
                                        : TextOverflow.visible,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade700,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                                if (overflow)
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (expandedIndex
                                            .contains("listreject_$index")) {
                                          expandedIndex
                                              .remove("listreject_$index");
                                        } else {
                                          expandedIndex
                                              .add("listreject_$index");
                                        }
                                      });
                                    },
                                    child: Icon(
                                      expandedIndex
                                              .contains("listreject_$index")
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                      size: 18,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _teamLeavesTab() {
    return RefreshIndicator(
      onRefresh: fetchTeamLeaves,
      child: teamLoading
          ? const Center(child: CircularProgressIndicator())
          : filteredTeamLeaves.isEmpty
              ? const Center(child: Text("No team leaves"))
              : ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: filteredTeamLeaves.length,
                  itemBuilder: (context, index) {
                    final item = filteredTeamLeaves[index];

                    return GestureDetector(
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EmployeeLeaveDetailsPage(
                              userId: item['user_id'].toString(),
                              empCode: item['employe_code'] ?? "",
                              item: item,
                            ),
                          ),
                        );

                        if (result == true) {
                          fetchTeamLeaves(); // refresh
                        }
                      },
                      child: leaveCard(item, index),
                    );
                  },
                ),
    );
  }

  Widget leaveCard(Map item, int index) {
    int status = int.tryParse(item['approved'].toString()) ?? 0;
    DateTime appliedDate = DateTime.parse(item['applied_date']);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ///  MAIN ROW
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// AVATAR
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: item['profile_thumbnail'] != null &&
                        item['profile_thumbnail'].toString().isNotEmpty
                    ? NetworkImage(
                        "https://hrms.attendify.ai/photos/${item['profile_thumbnail']}")
                    : null,
                child: (item['profile_thumbnail'] == null ||
                        item['profile_thumbnail'].toString().isEmpty)
                    ? const Icon(Icons.person, size: 18, color: Colors.grey)
                    : null,
              ),

              const SizedBox(width: 10),

              /// RIGHT CONTENT
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// 🔹 ROW 1 → NAME + STATUS
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item['applied_username'] ?? "",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        _statusChip(status),
                      ],
                    ),

                    const SizedBox(height: 3),

                    /// 🔹 ROW 2 → LEAVE TYPE (LEFT) + DATE RANGE (RIGHT)
                    Row(
                      children: [
                        /// LEFT → LEAVE TYPE
                        Expanded(
                          flex: 3,
                          child: Text(
                            item['type'] ?? "",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        /// RIGHT → DATE RANGE
                        Expanded(
                          flex: 10,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 12,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  "${formatDateNew(item['from_date'])} → ${formatDateNew(item['to_date'])} "
                                  "(${item['days']} ${double.tryParse(item['days'].toString()) == 1 ? 'day' : 'days'})",
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.end,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          /// 🔹 ROW 3 → APPLIED DATE + REPORTING
          Row(
            children: [
              /// LEFT → Applied Date
              Row(
                children: [
                  const Icon(Icons.access_time, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    formatDateNew(appliedDate.toString()),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),

              /// RIGHT → Reporting Name (FULL RIGHT ALIGN)
              Expanded(
                child: Text(
                  item['reporting_to_name'] ?? "",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),

          /// 🔹 REASON
          if ((item['reason'] ?? "").toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                bool overflow = isTextOverflow(
                  item['reason'],
                  constraints.maxWidth,
                  TextStyle(fontSize: 11, height: 1.4),
                );

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.notes, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),

                    Expanded(
                      child: Text(
                        item['reason'],
                        maxLines: overflow
                            ? (expandedIndex.contains("reason_$index")
                                ? null
                                : 2)
                            : null,
                        overflow: overflow
                            ? (expandedIndex.contains("reason_$index")
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis)
                            : TextOverflow.visible,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                    ),

                    /// SHOW ICON ONLY IF OVERFLOW
                    if (overflow)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (expandedIndex.contains("reason_$index")) {
                              expandedIndex.remove("reason_$index");
                            } else {
                              expandedIndex.add("reason_$index");
                            }
                          });
                        },
                        child: Icon(
                          expandedIndex.contains("reason_$index")
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 18,
                          color: Colors.grey,
                        ),
                      ),

                    // const SizedBox(width: 6),
                    // _statusChip(status),
                  ],
                );
              },
            ),
          ],

          /// 🔹 REJECT REASON
          if (status == 2 &&
              (item['reject_reason'] ?? "").toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                bool overflow = isTextOverflow(
                  item['reject_reason'],
                  constraints.maxWidth,
                  TextStyle(fontSize: 11, height: 1.4),
                );

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.cancel, size: 14, color: Colors.red),
                    const SizedBox(width: 6),

                    Expanded(
                      child: Text(
                        item['reject_reason'],
                        maxLines: overflow
                            ? (expandedIndex.contains("reject_$index")
                                ? null
                                : 2)
                            : null,
                        overflow: overflow
                            ? (expandedIndex.contains("reject_$index")
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis)
                            : TextOverflow.visible,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                    ),

                    /// SHOW ICON ONLY IF OVERFLOW
                    if (overflow)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (expandedIndex.contains("reject_$index")) {
                              expandedIndex.remove("reject_$index");
                            } else {
                              expandedIndex.add("reject_$index");
                            }
                          });
                        },
                        child: Icon(
                          expandedIndex.contains("reject_$index")
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 18,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  String formatDateNew(String date) {
    DateTime d = DateTime.parse(date);
    return "${d.day}-${d.month}-${d.year}";
  }

  Widget _statusChip(int status) {
    Color color = getStatusColor(status);
    String text = getStatusText(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  bool isTextOverflow(String text, double maxWidth, TextStyle style) {
    final textSpan = TextSpan(text: text, style: style);

    final tp = TextPainter(
      text: textSpan,
      maxLines: 2,
      textDirection: ui.TextDirection.ltr,
    );

    tp.layout(maxWidth: maxWidth);

    return tp.didExceedMaxLines;
  }

  InputDecoration premiumInput(
    String label, {
    IconData? icon,
    bool hasError = false,
    bool isOptional = false,
  }) {
    return InputDecoration(
      /// LABEL WITH RED *
      label: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: label,
              style: TextStyle(
                color: hasError ? Colors.red : Colors.grey.shade700,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (!isOptional)
              const TextSpan(
                text: " *",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),

      filled: true,

      /// LIGHT RED BG WHEN ERROR
      fillColor: hasError ? Colors.red.shade50 : Colors.grey.shade50,

      prefixIcon: icon != null
          ? Icon(
              icon,
              size: 18,
              color: hasError ? Colors.red : Colors.grey.shade600,
            )
          : null,

      contentPadding: const EdgeInsets.symmetric(
        vertical: 14,
        horizontal: 12,
      ),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: hasError ? Colors.red.shade300 : Colors.grey.shade300,
        ),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: hasError ? Colors.red.shade300 : Colors.grey.shade300,
        ),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: hasError ? Colors.red : const Color(0xFF0557a2),
          width: 1.6,
        ),
      ),

      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.red.shade400,
        ),
      ),

      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 1.6,
        ),
      ),
    );
  }

  Widget _wrapItem(double width, Widget child) {
    return SizedBox(
      width: width,
      child: child,
    );
  }

  Widget _gridField(double scale, Widget child) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: _s(6, scale),
        horizontal: _s(6, scale),
      ),
      child: child,
    );
  }
}

class EditLeaveModal extends StatefulWidget {
  final Map leave;
  final List leaveTypes;
  final VoidCallback onUpdated;

  const EditLeaveModal({
    super.key,
    required this.leave,
    required this.leaveTypes,
    required this.onUpdated,
  });

  @override
  State<EditLeaveModal> createState() => _EditLeaveModalState();
}

class _EditLeaveModalState extends State<EditLeaveModal> {
  DateTime? fromDate;
  DateTime? toDate;
  double days = 1.0;
  String leaveFor = "1";
  String? selectedLeaveTypeId;
  final reasonController = TextEditingController();
  bool isSubmitting = false;

  late TextEditingController fromDateController;
  late TextEditingController toDateController;
  late TextEditingController daysController;

  @override
  void initState() {
    super.initState();

    fromDateController = TextEditingController();
    toDateController = TextEditingController();
    daysController = TextEditingController();

    fromDate = DateTime.parse(widget.leave['from_date']);
    toDate = DateTime.parse(widget.leave['to_date']);
    leaveFor = widget.leave['leave_for'];
    selectedLeaveTypeId = widget.leave['leave_type'];
    reasonController.text = widget.leave['reason'] ?? "";

    calculateDays();
    updateControllers();
  }

  void updateControllers() {
    fromDateController.text = formatDate(fromDate!);
    toDateController.text = formatDate(toDate!);
    daysController.text =
        days % 1 == 0 ? days.toInt().toString() : days.toString();
  }

  void calculateDays() {
    if (leaveFor == "0.5") {
      days = 0.5;
    } else {
      if (fromDate != null && toDate != null) {
        int diff = toDate!.difference(fromDate!).inDays + 1;
        if (diff < 1) diff = 1;
        days = diff.toDouble();
      }
    }

    updateControllers();
  }

  String formatDate(DateTime date) {
    return DateFormat('dd-MM-yyyy').format(date);
  }

  Future<void> pickDate(bool isFrom) async {
    DateTime now = DateTime.now();

    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? fromDate! : toDate!,
      firstDate: isFrom ? now : fromDate!, // key fix
      lastDate: DateTime(2030),
    );

    if (picked == null) return;

    setState(() {
      if (isFrom) {
        fromDate = picked;

        ///  Ensure To Date is not before From Date
        if (toDate == null || toDate!.isBefore(picked)) {
          toDate = picked;
        }

        ///  Half day → force same date
        if (leaveFor == "0.5") {
          toDate = picked;
        }
      } else {
        ///  Block To Date change for Half Day
        if (leaveFor == "0.5") return;

        ///  Ensure To >= From
        if (picked.isBefore(fromDate!)) {
          toDate = fromDate;
        } else {
          toDate = picked;
        }
      }

      calculateDays();
    });
  }

  Future<void> updateLeave() async {
    if (isSubmitting) return;

    if (reasonController.text.trim().isEmpty) {
      AppToast.show(
        "Enter reason",
        isError: true,
      );
      return;
    }

    if (reasonController.text.trim().length < 5) {
      AppToast.show(
        "Reason must be minimum 5 characters",
        isError: true,
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm"),
        content: const Text("Do you want to update this leave?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      String apiKey = prefs.getString('apiKey') ?? "";
      String companyDb = prefs.getString('companyDb') ?? "";

      final response = await http.post(
        Uri.parse("https://hrms.attendify.ai/index.php/MobileApi/update_leave"),
        headers: {"apiKey": apiKey, "companyDb": companyDb},
        body: {
          "leave_id": widget.leave['leave_id'],
          "leave_type": selectedLeaveTypeId,
          "leave_for": leaveFor,
          "from_date": DateFormat('yyyy-MM-dd').format(fromDate!),
          "to_date": DateFormat('yyyy-MM-dd').format(toDate!),
          "days": days.toString(),
          "reason": reasonController.text,
        },
      );

      final res = jsonDecode(response.body);

      if (response.statusCode == 200 && res['status'] == true) {
        ///  SUCCESS MESSAGE
        AppToast.show("Leave updated successfully");

        /// small delay for smooth UX
        await Future.delayed(const Duration(milliseconds: 500));

        widget.onUpdated(); // closes modal + refresh
      } else {
        ///  ERROR MESSAGE
        AppToast.show(
          res['message'] ?? "Failed to update leave",
          isError: true,
        );
      }
    } catch (e) {
      AppToast.show("Something went wrong", isError: true);
    } finally {
      widget.onUpdated();
      setState(() => isSubmitting = false);
    }
  }

  ///  SAME DESIGN AS APPLY TAB
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Edit Leave"),
        backgroundColor: const Color(0xFF0557a2),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.all(12),
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
          ),
          child: Column(
            children: [
              ///  SAME GRID LIKE APPLY
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  /// TYPE
                  SizedBox(
                    width: double.infinity,
                    child: DropdownButtonFormField<String>(
                      value: selectedLeaveTypeId,
                      isExpanded: true,
                      hint: const Text("Select Leave Type"),
                      items:
                          widget.leaveTypes.map<DropdownMenuItem<String>>((e) {
                        return DropdownMenuItem(
                          value: e['type_id'].toString(),
                          child: Text(e['type']),
                        );
                      }).toList(),
                      onChanged: (v) {
                        setState(() {
                          selectedLeaveTypeId = v;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: "Leave Category",
                        prefixIcon: const Icon(Icons.category, size: 18),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  /// LEAVE FOR
                  SizedBox(
                    width: double.infinity,
                    child: DropdownButtonFormField<String>(
                      value: leaveFor,
                      items: const [
                        DropdownMenuItem(value: "1", child: Text("Full Day")),
                        DropdownMenuItem(value: "0.5", child: Text("Half Day")),
                      ],
                      onChanged: (v) {
                        setState(() {
                          leaveFor = v!;
                          if (leaveFor == "0.5") toDate = fromDate;
                          calculateDays();
                        });
                      },
                      decoration: InputDecoration(
                        labelText: "Leave For",
                        prefixIcon: Icon(Icons.timelapse, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  /// FROM DATE
                  TextFormField(
                    readOnly: true,
                    controller: TextEditingController(
                      text: formatDate(fromDate!),
                    ),
                    onTap: () => pickDate(true),
                    decoration: InputDecoration(
                      labelText: "From Date",
                      prefixIcon: Icon(Icons.calendar_today, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  /// TO DATE
                  TextFormField(
                    readOnly: true,
                    controller: TextEditingController(
                      text: formatDate(toDate!),
                    ),
                    onTap: leaveFor == "0.5" ? null : () => pickDate(false),
                    decoration: InputDecoration(
                      labelText: "To Date",
                      prefixIcon: Icon(Icons.calendar_today, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  /// DAYS
                  TextFormField(
                    readOnly: true,
                    controller: TextEditingController(
                      text: days % 1 == 0
                          ? days.toInt().toString()
                          : days.toString(),
                    ),
                    decoration: InputDecoration(
                      labelText: "Days",
                      prefixIcon: Icon(Icons.date_range, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  /// REASON
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    maxLength: 500,
                    decoration: InputDecoration(
                      labelText: "Reason",
                      prefixIcon: Icon(Icons.edit, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ).copyWith(
                      helperText: "Minimum 5 characters",
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              ///  BUTTON
              SizedBox(
                child: ElevatedButton(
                  onPressed: updateLeave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0557a2),
                  ),
                  child: isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Update Leave",
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
