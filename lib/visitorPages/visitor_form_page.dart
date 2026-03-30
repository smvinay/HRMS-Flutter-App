import 'dart:async';

import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'VisitorDrawerPage.dart';
import 'visitor_header.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:another_flushbar/flushbar.dart';



class VisitorFormPage extends StatefulWidget {
  const VisitorFormPage({super.key});

  @override
  State<VisitorFormPage> createState() => _VisitorFormPageState();
}

class _VisitorFormPageState extends State<VisitorFormPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  bool _keyboardVisible = false;
  List<Visitor> _visitors = [];
  List<Employee> _employees = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  int _selectedIndex = 0;
  Map<int, Employee?> _selectedEmployeeByIndex = {};
  Timer? _refreshTimer;
  bool _isFetchingNew = false;
  final FocusNode _employeeFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  Map<String, String?> _errors = {};
  late Map<int, TextEditingController> nameControllers = {};
  late Map<int, TextEditingController> phoneControllers = {};
  late Map<int, TextEditingController> emailControllers = {};
  late Map<int, TextEditingController> purposeControllers = {};
  late Map<int, TextEditingController> fromControllers = {};
  Employee? _loggedInEmployee;
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _loadVisitorData();
    loadEmployees();

    // start periodic background poll
    _startAutoRefresh();
  }

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding.instance.window.viewInsets.bottom;

    final isKeyboardOpen = bottomInset > 0;

    if (isKeyboardOpen != _keyboardVisible) {
      setState(() {
        _keyboardVisible = isKeyboardOpen;
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _employeeFocus.dispose();
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    for (final controller in nameControllers.values) {
      controller.dispose();
    }
    for (final controller in phoneControllers.values) {
      controller.dispose();
    }
    for (final controller in emailControllers.values) {
      controller.dispose();
    }
    for (final controller in purposeControllers.values) {
      controller.dispose();
    }
    for (final controller in fromControllers.values) {
      controller.dispose();
    }

    nameControllers.clear();
    phoneControllers.clear();
    emailControllers.clear();
    purposeControllers.clear();
    fromControllers.clear();

    super.dispose();
  }
  void _startAutoRefresh() {
    // cancel any existing timer
    _refreshTimer?.cancel();

    // run every 1 second (adjust duration if needed)
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_isFetchingNew) return;
      _isFetchingNew = true;

      try {
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString('cid');
        final apiKey = prefs.getString('apiKey');
        final companyDb = prefs.getString('companyDb');

        if (userId == null || apiKey == null || companyDb == null) return;

        // fetch remote list (this returns List<Visitor>)
        final fetched = await fetchVisitors(userId, apiKey, companyDb);

        // merge only new visitors into local state
        _mergeNewVisitors(fetched);

      } catch (e) {
        // ignore silently — background poll shouldn't disturb UI
        // optionally log: print('poll error: $e');
      } finally {
        _isFetchingNew = false;
      }
    });
  }

  void _mergeNewVisitors(List<Visitor> fetched) {
    if (fetched.isEmpty) return;

    final existingIds = _visitors.map((v) => v.guestId).toSet();

    final List<Visitor> newOnes =
    fetched.where((f) => !existingIds.contains(f.guestId)).toList();

    if (newOnes.isEmpty) return;

    setState(() {

      int startIndex = _visitors.length;

      /// add visitors at END
      _visitors.addAll(newOnes);

      /// create controllers for new visitors
      for (int i = 0; i < newOnes.length; i++) {

        int index = startIndex + i;

        final v = newOnes[i];

        nameControllers[index] = TextEditingController(
            text: '${v.firstName ?? ''} ${v.lastName ?? ''}'.trim());

        phoneControllers[index] =
            TextEditingController(text: v.contact ?? '');

        emailControllers[index] =
            TextEditingController(text: v.email ?? '');

        purposeControllers[index] =
            TextEditingController(text: v.purposeOfVisit ?? '');

        fromControllers[index] =
            TextEditingController(text: v.guestFrom ?? '');

        _selectedEmployeeByIndex[index] = null;
      }
    });
  }
  void _loadVisitorData() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('cid');
    String? apiKey = prefs.getString('apiKey');
    String? companyDb = prefs.getString('companyDb');

    if (userId != null && apiKey != null && companyDb != null) {
      try {
        final visitors = await fetchVisitors(userId, apiKey, companyDb);
        setState(() {
          _visitors = visitors;

          for (int i = 0; i < visitors.length; i++) {
            nameControllers[i] ??= TextEditingController(
                text:
                '${visitors[i].firstName ?? ''} ${visitors[i].lastName ?? ''}'
                    .trim());
            phoneControllers[i] ??=
                TextEditingController(text: visitors[i].contact ?? '');
            emailControllers[i] ??=
                TextEditingController(text: visitors[i].email ?? '');
            purposeControllers[i] ??= TextEditingController(
                text: visitors[i].purposeOfVisit ?? '');
            fromControllers[i] ??=
                TextEditingController(text: visitors[i].guestFrom ?? '');
            _selectedEmployeeByIndex[i] ??= null;
          }
          _isLoading = false;
          if (_visitors.isNotEmpty &&
              _selectedIndex >= _visitors.length) {
            _selectedIndex = 0;
          }
        });
      } catch (e) {
        setState(() => _isLoading = false);
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> loadEmployees() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('cid');
    String? userName = prefs.getString('username');
    String? logincode = prefs.getString('code');
    String? apiKey = prefs.getString('apiKey');
    String? companyDb = prefs.getString('companyDb');
    if (userId != null && apiKey != null && companyDb != null) {
      try {
        final employees =
        await fetchEmployees(userId, apiKey, companyDb);

        Employee? loggedUser;

        // if (loggedUser == null) {
          loggedUser = Employee(
            id: userId,
            employeCode:logincode ?? "SELF",
            firstName: userName ?? "Receptionist",
            lastName: "",
            userProfile: null,
            profileThumbnail: null,
          );

          employees.insert(0, loggedUser);
        // }
        setState(() {
          _employees = employees;
          _loggedInEmployee = loggedUser;
        });
      } catch (_) {}
    }
  }

  double _calcScaleFromWidth(double w) {
    const base = 475.0;
    final raw = (w / base);
    return raw.clamp(0.7, 1.2);
  }

  double _s(double size, double scale) {
    return size * scale;
  }

  @override
  Widget build(BuildContext context) {

    final size = MediaQuery.of(context).size;
    final scale = _calcScaleFromWidth(size.width);

    /// Detect keyboard globally
    final bool keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    final isWide = size.width > 900;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _visitors.isEmpty
              ? const Center(child: Text('No visitors found.'))
              : isWide
              ? _buildLandscapeLayout(scale)
              : _buildPortraitLayout(scale, keyboardOpen), // pass it
        ),
      ),
    );
  }

  Widget _buildPortraitLayout(double scale, bool keyboardOpen) {

    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 650;

    return Column(
      children: [

        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                key: ValueKey(_selectedIndex),
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 24 : 14,
                  vertical: 12,
                ),
                child: _buildVisitorForm(context, _selectedIndex, isTablet),
              ),
            ),
          ),
        ),

        /// hide visitor cards when keyboard opens
        if (!_keyboardVisible) ...[
          const Divider(height: 1),
          _buildTopVisitorScroller(isTablet, scale),
        ]
      ],
    );
  }

  Widget _buildLandscapeLayout(double scale) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 650;



    return Row(
      children: [

        /// LEFT SIDE VISITOR CARDS
        Container(
          width: 260,
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(
              right: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _visitors.length,
            itemBuilder: (context, index) {
              final v = _visitors[index];
              final isSelected = index == _selectedIndex;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFE8F1FF)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF0557A2)
                          : Colors.grey.shade200,
                    ),
                  ),

                  child: Stack(
                    children: [

                      Row(
                        children: [

                          /// FACE
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              v.detected_face != null && v.detected_face!.isNotEmpty
                                  ? 'https://hrms.attendify.ai/guest_faces/${v.detected_face}'
                                  : 'https://via.placeholder.com/80',
                              width: isTablet ? 80 : 65,
                              height: isTablet ? 80 : 65,
                              fit: BoxFit.cover,
                            ),
                          ),

                          const SizedBox(width: 10),

                          /// NAME + TIME
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [

                                Text(
                                  v.firstName?.isNotEmpty == true
                                      ? v.firstName!
                                      : "Visitor ${index + 1}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),

                                const SizedBox(height: 4),

                                Text(
                                  v.checkInTime?.split(" ").last ?? "-",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),

                              ],
                            ),
                          ),
                        ],
                      ),

                      /// ARCHIVE BUTTON
                      Positioned(
                        right: 0,
                        top: 0,
                        child: InkWell(
                          onTap: () {
                            _archiveVisitor(v.guestId, index);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.archive_outlined,
                              size: 18,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ),

                    ],
                  ),
                ),
              );
            },
          ),
        ),

        /// RIGHT SIDE FORM
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: SingleChildScrollView(
              key: ValueKey(_selectedIndex),
              padding: const EdgeInsets.all(15),
              child: _buildVisitorForm(
                  context, _selectedIndex, isTablet),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopVisitorScroller(bool isTablet , double scale) {
    final cardWidth = isTablet ? 110.0 : 110.0;

    return SizedBox(
      height: isTablet ? _s(170, scale) :  _s(250, scale),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        scrollDirection: Axis.horizontal,
        itemCount: _visitors.length,
        itemBuilder: (context, index) {
          final v = _visitors[index];



          final isSelected = index == _selectedIndex;

          // ✅ Show name if exists else serial number
          final displayName =
          (v.firstName != null && v.firstName!.trim().isNotEmpty)
              ? v.firstName!
              : "Visitor ${index + 1}";

          // ✅ Extract only time (HH:mm:ss)
          String displayTime = "- - -";
          if (v.checkInTime != null && v.checkInTime!.contains(" ")) {
            displayTime = v.checkInTime!.split(" ")[1]; // only time
          }

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedIndex = index;
              });
              _centerCard(index, cardWidth);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.only(right: 8),
              width: cardWidth,
              padding: const EdgeInsets.all(8),
              transform: Matrix4.identity()
                ..scale(isSelected ? 1.06 : 1.0),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFE8F1FF) // ✅ Light blue active color
                    : Colors.white,
                borderRadius: BorderRadius.circular(8),
                // border: Border.all(
                //   color: isSelected
                //       ? const Color(0xFF0557A2) : Colors.white,
                //   width: isSelected ? 1.5 : 1,
                // ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? const Color(0xFF0557A2).withOpacity(0.15)
                        : Colors.black.withOpacity(0.05),
                    blurRadius: isSelected ? 12 : 6,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      /// IMAGE
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          v.detected_face != null && v.detected_face!.isNotEmpty
                              ? 'https://hrms.attendify.ai/guest_faces/${v.detected_face}'
                              : 'https://via.placeholder.com/80',
                          width: 95,
                          height: 95,
                          fit: BoxFit.cover,
                        ),
                      ),

                      const SizedBox(height: 8),

                      /// NAME
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: _s(14, scale),
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      /// TIME
                      Text(
                        displayTime,
                        style: TextStyle(
                          fontSize: _s(12, scale),
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),

                  /// ARCHIVE BUTTON
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: InkWell(
                      onTap: () {
                        _archiveVisitor(v.guestId, index);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.archive_outlined,
                          size: 15,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  Widget _buildVisitorForm(BuildContext context, int index, bool isTablet) {

    final scale = _calcScaleFromWidth(MediaQuery.of(context).size.width);

    final visitor = _visitors[index];

    final headerTitle =
    (visitor.firstName != null && visitor.firstName!.trim().isNotEmpty)
        ? visitor.firstName!
        : "Visitor ${index + 1}";

    return Card(
      elevation: _s(0, scale),
      color: Colors.white,
      margin: EdgeInsets.symmetric(vertical: _s(1, scale)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_s(12, scale)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          // horizontal: isTablet ? _s(, scale) : _s(2, scale),
          // vertical: isTablet ? _s(4, scale) : _s(4, scale),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [


            /// NAME + IMAGE
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,

              children: [

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, // 👈 add this
                    children: [

                     Text(
                          headerTitle,
                          style: TextStyle(
                            fontSize: isTablet ? _s(22, scale) : _s(18, scale),
                            fontWeight: FontWeight.bold,
                          ),
                        ),


                      _buildTextField(
                        context,
                        'Name',
                        nameControllers[index]!,
                        "name",
                      ),

                      SizedBox(height: _s(5, scale)),

                      _buildTextField(
                        context,
                        'Phone',
                        phoneControllers[index]!,
                        "phone",
                        keyboard: TextInputType.number,
                      ),
                    ],
                  ),
                ),

                SizedBox(width: _s(8, scale)),

                /// VISITOR IMAGE
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_s(10, scale)),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_s(10, scale)),
                    child: Image.network(
                      visitor.detected_face != null &&
                          visitor.detected_face!.isNotEmpty
                          ? 'https://hrms.attendify.ai/guest_faces/${visitor.detected_face}'
                          : 'https://via.placeholder.com/100',
                      width: isTablet ? _s(130, scale) : _s(130, scale),
                      height: isTablet ? _s(135, scale) : _s(145, scale),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: _s(5, scale)),

            _buildTextField(
              context,
              'Email',
              emailControllers[index]!,
              "email",
              keyboard: TextInputType.emailAddress,
              isOptional: true,
            ),

            SizedBox(height: _s(5, scale)),

            _buildTextField(
              context,
              'Organisation',
              fromControllers[index]!,
              "from",
            ),

            SizedBox(height: _s(5, scale)),

            _buildTextField(
              context,
              'Purpose',
              purposeControllers[index]!,
              "purpose",
            ),

            SizedBox(height: _s(5, scale)),

            emplyeesList(context, index),

            SizedBox(height: _s(15, scale)),

            /// SAVE BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await submitVisitorData(context, visitor, index);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0557a2),
                  padding: EdgeInsets.symmetric(vertical: _s(14, scale)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_s(10, scale)),
                  ),
                  elevation: _s(2, scale),
                ),
                child: Text(
                  'Save Visitor',
                  style: TextStyle(
                    fontSize: _s(16, scale),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildTextField(
      BuildContext context,
      String label,
      TextEditingController controller,
      String fieldKey, {
        TextInputType keyboard = TextInputType.text,
        bool isOptional = false,
      }) {
    final scale = _calcScaleFromWidth(MediaQuery.of(context).size.width);

    return Container(
      margin: EdgeInsets.only(bottom: _s(4, scale)),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(_s(6, scale)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        autovalidateMode: AutovalidateMode.onUserInteraction,

        inputFormatters: fieldKey == "phone"
            ? [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ]
            : null,

        onChanged: (value) {
          if (fieldKey == "phone") {
            if (value.length != 10) {
              setState(() {
                _errors[fieldKey] = "Phone number must be 10 digits";
              });
            } else {
              setState(() {
                _errors.remove(fieldKey);
              });
            }
          }
        },

        onEditingComplete: () {
          controller.text = controller.text.trim();
        },

        style: TextStyle(fontSize: _s(15, scale)),

        decoration: InputDecoration(
          labelText: label,

          labelStyle: TextStyle(
            fontSize: _s(15, scale),
            fontWeight: FontWeight.w500,
          ),

          floatingLabelStyle: TextStyle(
            color: _errors[fieldKey] != null
                ? Colors.red
                : const Color(0xFF0557a2),
            fontSize: _s(15, scale),
            fontWeight: FontWeight.w500,
          ),

          errorText: _errors[fieldKey],

          contentPadding: EdgeInsets.symmetric(
            horizontal: _s(8, scale),
            vertical: _s(5, scale),
          ),

          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }

  Future<void> _archiveVisitor(String guestId, int index) async {

    /// CONFIRMATION DIALOG
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Archive Visitor"),
          content: const Text("Are you sure you want to archive this visitor?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              // style: ElevatedButton.styleFrom(
              //   backgroundColor: Colors.orange,
              // ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Archive"),
            ),
          ],
        );
      },
    );

    /// If user cancels
    if (confirm != true) return;

    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('apiKey');
    final companyDb = prefs.getString('companyDb');

    if (apiKey == null || companyDb == null) return;

    const flag = "1";

    final url = Uri.parse(
        "https://hrms.attendify.ai/index.php/Guest/markArchiveVisitor");

    try {

      final response = await http.post(
        url,
        headers: {
          'apiKey': apiKey,
          'companyDb': companyDb,
        },
        body: {
          'guestid': guestId,
          'flag': flag,
        },
      );

      final data = json.decode(response.body);

      if (data['status'] == true) {

        /// REMOVE VISITOR FROM LIST (Better UX)
        setState(() {
          _visitors.removeAt(index);

          if (_selectedIndex >= _visitors.length) {
            _selectedIndex = _visitors.isNotEmpty
                ? _visitors.length - 1
                : 0;
          }
        });

        _showflashbar("Visitor archived", Colors.green.shade300);

      } else {
        _showflashbar("Archive failed", Colors.red.shade300);
      }

    } catch (e) {
      _showflashbar("Network error", Colors.red.shade300);
    }
  }

  Widget emplyeesList(BuildContext context, int index) {

    final scale = _calcScaleFromWidth(MediaQuery.of(context).size.width);

    return Container(
      margin: EdgeInsets.only(bottom: _s(12, scale)),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(_s(6, scale)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),

      child: DropdownSearch<Employee>(
        items: _employees,
        selectedItem: _selectedEmployeeByIndex[index] ?? _loggedInEmployee,

        itemAsString: (Employee e) =>
        "${e.firstName} ${e.lastName == "null" ? "" : e.lastName ?? ""}",

        clearButtonProps: const ClearButtonProps(
          isVisible: false,
        ),

        /// SELECTED ITEM VIEW
        dropdownBuilder: (context, selectedItem) {

          if (selectedItem == null) {
            return const SizedBox();
          }

          return Row(
            children: [

              CircleAvatar(
                radius: 16,
                backgroundImage: selectedItem.profileThumbnail != null
                    ? NetworkImage(
                    "https://hrms.attendify.ai/photos/${selectedItem.profileThumbnail}")
                    : null,
                backgroundColor: Colors.grey.shade300,
                child: selectedItem.profileThumbnail == null
                    ? const Icon(Icons.person, size: 15, color: Colors.white)
                    : null,
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  selectedItem.firstName,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        },

        /// POPUP LIST
        popupProps: PopupProps.menu(
          showSearchBox: true,

          searchFieldProps: const TextFieldProps(
            decoration: InputDecoration(
              hintText: "Search employee...",
              border: InputBorder.none,
            ),
          ),

          itemBuilder: (context, employee, isSelected) {

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFE8F1FF)
                    : Colors.transparent,
              ),

              child: Row(
                children: [

                  CircleAvatar(
                    radius: 16,
                    backgroundImage: employee.profileThumbnail != null
                        ? NetworkImage(
                        "https://hrms.attendify.ai/photos/${employee.profileThumbnail}")
                        : null,
                    backgroundColor: Colors.grey.shade300,
                    child: employee.profileThumbnail == null
                        ? const Icon(Icons.person,
                        size: 14, color: Colors.white)
                        : null,
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Text(
                      employee.firstName,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        /// VALUE CHANGE
        onChanged: (Employee? val) {

          setState(() {
            _selectedEmployeeByIndex[index] = val;
            _errors["employee"] = null;
          });

          _employeeFocus.unfocus();
        },

        /// DECORATION
        dropdownDecoratorProps: DropDownDecoratorProps(

          dropdownSearchDecoration: InputDecoration(

            labelText: "Host Name",

            floatingLabelBehavior: FloatingLabelBehavior.auto,

            labelStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),

            floatingLabelStyle: TextStyle(
              color: _errors["employee"] != null
                  ? Colors.red
                  : const Color(0xFF0557a2),
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),

            errorText: _errors["employee"],

            contentPadding: EdgeInsets.symmetric(
              horizontal: _s(8, scale),
              vertical: _s(5, scale),
            ),

            /// REMOVE BORDER
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,

            filled: false,
          ),
        ),
      ),
    );
  }
  void _showflashbar(String message, Color color) {
    Flushbar(
      message: message,
      duration: const Duration(seconds: 2),
      backgroundColor: color,
      borderRadius: BorderRadius.circular(8),
      margin: const EdgeInsets.all(12),
      flushbarPosition: FlushbarPosition.TOP,
    ).show(context);
  }

  Future<List<Visitor>> fetchVisitors(
      String userId, String apiKey, String companyDb) async {
    final url = Uri.parse(
        'https://hrms.attendify.ai/index.php/Guest/index?user_id=$userId');
    final response = await http.get(url, headers: {
      'apiKey': apiKey,
      'companyDb': companyDb,
    });
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body)['data'];
      return data.map((json) => Visitor.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load visitors');
    }
  }

  Future<List<Employee>> fetchEmployees(
      String userId, String apiKey, String companyDb) async {
    final response = await http.get(
      Uri.parse(
          'https://hrms.attendify.ai/index.php/Dashboard/getUsers?user_id=$userId'),
      headers: {
        'apiKey': apiKey,
        'companyDb': companyDb,
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List users = data['data'];
      return users.map((e) => Employee.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load employees');
    }
  }

  Future<void> submitVisitorData(
      BuildContext context, Visitor visitor, int index) async {

    bool isValid = true;

    _errors.clear();

    final name = nameControllers[index]!.text.trim();
    final phone = phoneControllers[index]!.text.trim();
    final email = emailControllers[index]!.text.trim();
    final purpose = purposeControllers[index]!.text.trim();
    final from = fromControllers[index]!.text.trim();

    final selectedEmployee = _selectedEmployeeByIndex[index];

    if (name.isEmpty) {
      _errors["name"] = "Name is required";
      isValid = false;
    }

    if (phone.isEmpty) {
      _errors["phone"] = "Phone is required";
      isValid = false;
    } else if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      _errors["phone"] = "Enter valid phone number";
      isValid = false;
    }

    if (email.isNotEmpty &&
        !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      _errors["email"] = "Invalid email format";
      isValid = false;
    }

    // if (purpose.isEmpty) {
    //   _errors["purpose"] = "Purpose is required";
    //   isValid = false;
    // }

    // if (from.isEmpty) {
    //   _errors["from"] = "From field is required";
    //   isValid = false;
    // }

    // if (selectedEmployee == null) {
    //   _errors["employee"] = "Please select employee";
    //   isValid = false;
    // }

    if (!isValid) {
      setState(() {});
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('apiKey');
    final companyDb = prefs.getString('companyDb');
    final id = prefs.getString('user_id');

    /// determine user id
    String? userId = selectedEmployee?.id ?? id;
    String? status = selectedEmployee?.id != null ? '0' :  '1';

    if (apiKey == null || companyDb == null) {
      _showflashbar("Authentication error", Colors.red.shade300);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final url = Uri.parse(
          'https://hrms.attendify.ai/index.php/Guest/update_guest_mobile');

      final response = await http.post(
        url,
        headers: {
          'apiKey': apiKey,
          'companyDb': companyDb,
        },
        body: {
          'first_name': name,
          'contact': phone,
          'email': email,
          'purpose': purpose,
          'guestfrom': from,
          'guestID': visitor.id,
          'user_id': userId,
          'status' : status
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == true) {

          _showflashbar(
              "Data submitted successfully",
              Colors.green.shade300);

          /// ✅ OPTION 1: REMOVE VISITOR (Better UX)
          setState(() {

            _visitors.removeAt(index);

            /// rebuild controller maps to fix index shift
            Map<int, TextEditingController> newName = {};
            Map<int, TextEditingController> newPhone = {};
            Map<int, TextEditingController> newEmail = {};
            Map<int, TextEditingController> newPurpose = {};
            Map<int, TextEditingController> newFrom = {};
            Map<int, Employee?> newEmp = {};

            int i = 0;

            nameControllers.forEach((key, value) {
              if (key != index) {
                newName[i] = value;
                i++;
              }
            });

            i = 0;
            phoneControllers.forEach((key, value) {
              if (key != index) {
                newPhone[i] = value;
                i++;
              }
            });

            i = 0;
            emailControllers.forEach((key, value) {
              if (key != index) {
                newEmail[i] = value;
                i++;
              }
            });

            i = 0;
            purposeControllers.forEach((key, value) {
              if (key != index) {
                newPurpose[i] = value;
                i++;
              }
            });

            i = 0;
            fromControllers.forEach((key, value) {
              if (key != index) {
                newFrom[i] = value;
                i++;
              }
            });

            i = 0;
            _selectedEmployeeByIndex.forEach((key, value) {
              if (key != index) {
                newEmp[i] = value;
                i++;
              }
            });

            nameControllers = newName;
            phoneControllers = newPhone;
            emailControllers = newEmail;
            purposeControllers = newPurpose;
            fromControllers = newFrom;
            _selectedEmployeeByIndex = newEmp;

            if (_selectedIndex >= _visitors.length) {
              _selectedIndex = _visitors.isNotEmpty ? _visitors.length - 1 : 0;
            }
          });

          /// If no visitors left
          if (_visitors.isEmpty) {
            _showflashbar("All visitors completed",
                Colors.green.shade300);
          }

        } else {
          _showflashbar(
              data['message'] ?? 'Submission failed',
              Colors.red.shade300);
        }
      }
    } catch (e) {
      print(e);

      _showflashbar("Something went wrong", Colors.red.shade300);
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _centerCard(int index, double cardWidth) {
    final screenWidth = MediaQuery.of(context).size.width;
    final targetOffset =
        index * (cardWidth + 10) - (screenWidth / 2 - cardWidth / 2);
    final maxScroll = _scrollController.position.maxScrollExtent;
    final offset = targetOffset.clamp(0.0, maxScroll);
    _scrollController.animateTo(offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut);
  }
}

class Visitor {
  final String id;
  final String guestId;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? contact;
  final String? imagePath;
  final String? detected_face;
  final String? checkInTime;
  final String? purposeOfVisit;
  final String? guestFrom;

  Visitor({
    required this.id,
    required this.guestId,
    this.firstName,
    this.lastName,
    this.email,
    this.contact,
    this.imagePath,
    this.detected_face,
    this.checkInTime,
    this.purposeOfVisit,
    this.guestFrom,
  });

  factory Visitor.fromJson(Map<String, dynamic> json) {
    return Visitor(
      id: json['id'] ?? '',
      guestId: json['guestid'] ?? '',
      firstName: json['first_name'],
      lastName: json['last_name'],
      email: json['email'],
      contact: json['contact'],
      imagePath: json['image_path'],
      detected_face: json['detected_face'],
      checkInTime: json['check_in_time'],
      purposeOfVisit: json['purpose_of_visit'],
      guestFrom: json['guestfrom'],
    );
  }
}

class Employee {
  final String id;
  final String employeCode;
  final String firstName;
  final String? lastName;
  final String? userProfile;
  final String? profileThumbnail;

  Employee({
    required this.id,
    required this.employeCode,
    required this.firstName,
    this.lastName,
    this.userProfile,
    this.profileThumbnail,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'],
      employeCode: json['employe_code'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      userProfile: json['user_profile'],
      profileThumbnail: json['profile_thumbnail'],
    );
  }
}
