import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'employee_leave_details_page.dart';
import '../global_state.dart';
import 'hr_drawer.dart';
import 'hr_footer.dart';

class TeamLeaves extends StatefulWidget {
  const TeamLeaves({Key? key}) : super(key: key);

  @override
  State<TeamLeaves> createState() => _TeamLeavesState();
}

class _TeamLeavesState extends State<TeamLeaves> {
  List allLeaves = [];
  List filteredLeaves = [];
  bool loading = true;
  String search = "";
  String filter = "all";
  bool isSearchExpanded = false;

  String selectedDate = "";
  String filterDate = "";
  String selectedLeaveType = "All";
  String selectedStatus = "All";
  Map<String, String> leaveTypes = {
    "All": "All",
  };
  int pendingCount = 0;
  Set<String> expandedIndex = <String>{};

  Map<String, String> statusMap = {
    "All": "All",
    "0": "Pending",
    "1": "Approved",
    "2": "Rejected",
    "3": "Withdrawn"
  };

  TextEditingController searchController = TextEditingController();
  FocusNode searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    fetchLeaves();
  }

  Future<void> fetchLeaves() async {
    setState(() => loading = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      String apiKey = prefs.getString('apiKey') ?? "";
      String companyDb = prefs.getString('companyDb') ?? "";
      String userID = prefs.getString('user_id') ?? "";
      String levelId = prefs.getString('level_id') ?? "";

      final response = await http.get(
        Uri.parse(
            "https://hrms.attendify.ai/index.php/MobileApi/allEmpLeaves?userId=$userID&levelId=$levelId"),
        headers: {"apiKey": apiKey, "companyDb": companyDb},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        /// LEAVES
        allLeaves = data['userLeaves'] ?? [];
        pendingCount = data['pendingLeavesCount'] ?? 0;
        pendingLeaveNotifier.value = data['pendingLeavesCount'] ?? 0;
        ///  LEAVE TYPES (convert to Map)
        List types = data['leaveType'] ?? [];

        leaveTypes = {
          "All": "All",
          for (var e in types)
            e['type'].toString(): e['type'].toString()
        };

        applyFilter();
      }
    } catch (e) {
      debugPrint(e.toString());
    }

    setState(() => loading = false);
  }

  void applyFilter() {
    List temp = List.from(allLeaves);

    if (filter == "approved") {
      temp = temp.where((e) => e['approved'].toString() == "1").toList();
    } else if (filter == "rejected") {
      temp = temp.where((e) => e['approved'].toString() == "2").toList();
    } else if (filter == "pending") {
      temp = temp.where((e) => e['approved'].toString() == "0").toList();
    }

    if (search.isNotEmpty) {
      temp = temp.where((e) {
        String name = (e['applied_username'] ?? "").toLowerCase();
        // String reason = (e['reason'] ?? "").toLowerCase();
        return name.contains(search.toLowerCase());
            // reason.contains(search.toLowerCase());
      }).toList();
    }

    if (filterDate.isNotEmpty) {
      temp = temp.where((e) {
        String applied = (e['applied_date'] ?? "").split(" ")[0];
        return applied == filterDate;
      }).toList();
    }

    if (selectedLeaveType != "All") {
      temp = temp.where((e) {
        return (e['type'] ?? "") == selectedLeaveType;
      }).toList();
    }

    if (selectedStatus != "All") {
      temp = temp.where((e) {
        return e['approved'].toString() == selectedStatus;
      }).toList();
    }

    setState(() {
      filteredLeaves = temp;
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

  String formatDate(String date) {
    DateTime d = DateTime.parse(date);
    return "${d.day}-${d.month}-${d.year}";
  }

  Future<void> approveLeave(String id) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Approve Leave"),
        content: const Text("Are you sure you want to approve this leave?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Approve"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _callLeaveApproveApi(id);
  }

  Future<void> _callLeaveApproveApi(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      String apiKey = prefs.getString('apiKey') ?? "";
      String companyDb = prefs.getString('companyDb') ?? "";
      String cid = prefs.getString('cid') ?? "";
      String userId = prefs.getString('user_id') ?? "";
      String firstName = prefs.getString('first_name') ?? "";

      final response = await http.post(
        Uri.parse(
            "https://hrms.attendify.ai/index.php/Setting/leave_approve"),
        headers: {
          "apiKey": apiKey,
          "companyDb": companyDb,
        },
        body: {
          "id": id,
          "cid": cid,
          "user_id": userId,
          "first_name": firstName,
        },
      );

      final data = jsonDecode(response.body);

      if (data['status'] == true) {
        fetchLeaves();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Leave Approved"),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? "Failed"),
          ),
        );
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> rejectLeave(String id) async {
    TextEditingController remarkController = TextEditingController();

    bool? confirm = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Reject Leave"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Rejection Reason",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: remarkController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: "Enter remark...",
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (remarkController.text.trim().isEmpty) return;
              Navigator.pop(context, true);
            },
            child: const Text("Reject"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _callLeaveRejectApi(id, remarkController.text.trim());
  }

  Future<void> _callLeaveRejectApi(String id, String remark) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      String apiKey = prefs.getString('apiKey') ?? "";
      String companyDb = prefs.getString('companyDb') ?? "";
      String user_id = prefs.getString('user_id') ?? "";
      String comp_name = prefs.getString('comp_name') ?? "";

      final response = await http.post(
        Uri.parse(
            "https://hrms.attendify.ai/index.php/Setting/leave_reject"),
        headers: {
          "apiKey": apiKey,
          "companyDb": companyDb,
        },
        body: {
          "id": id,
          "reject_reason": remark,
          "user_id": user_id,
          "comp_name": comp_name,
        },
      );

      final data = jsonDecode(response.body);

      if (data['status'] == true) {
        fetchLeaves();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Leave Rejected"),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? "Failed"),
          ),
        );
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  double _s(double size, double scale) => size * scale;

  Widget expandableSearch(double scale) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: _s(210, scale),
      height: _s(40, scale),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(_s(20, scale)),
      ),
      child: Row(
        children: [

          /// SEARCH ICON
          Padding(
            padding: EdgeInsets.only(
              left: _s(10, scale),
            ),
            child: Icon(
              Icons.search,
              size: _s(18, scale),
              color: Colors.grey.shade600,
            ),
          ),

          SizedBox(width: _s(6, scale)),

          /// SEARCH FIELD
          Expanded(
            child: TextField(
              controller: searchController,
              focusNode: searchFocus,
              maxLength: 150,
              buildCounter: (
                  context, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) {
                return null;
              },
              style: TextStyle(
                fontSize: _s(12, scale),
              ),
              decoration: InputDecoration(
                hintText: "Search",
                hintStyle: TextStyle(
                  fontSize: _s(11, scale),
                  color: Colors.grey,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  vertical: _s(10, scale),
                ),
                suffixIcon: search.isNotEmpty
                    ? IconButton(
                  icon: Icon(
                    Icons.close,
                    size: _s(16, scale),
                  ),
                  onPressed: () {
                    searchController.clear();
                    searchFocus.unfocus();

                    setState(() {
                      search = "";
                    });

                    applyFilter();
                  },
                )
                    : null,
              ),
              onChanged: (val) {
                setState(() {
                  search = val;
                });

                applyFilter();
              },
            ),
          ),
        ],
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
                                  "${formatDate(item['from_date'])} → ${formatDate(item['to_date'])} "
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
                    formatDate(appliedDate.toString()),
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
                            ? (expandedIndex.contains("reason_$index") ? null : 2)
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
          if (status == 2 && (item['reject_reason'] ?? "").toString().isNotEmpty) ...[
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
                            ? (expandedIndex.contains("reject_$index") ? null : 2)
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

  Widget _statusChip(int status) {
    Color color = getStatusColor(status);
    String text = getStatusText(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
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
      textDirection: TextDirection.ltr,
    );

    tp.layout(maxWidth: maxWidth);

    return tp.didExceedMaxLines;
  }

  Future<void> pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        selectedDate =
        "${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}";

        filterDate =
        "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });

      applyFilter();
    }
  }

  @override
  Widget build(BuildContext context) {
    double scale = 1;

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
        drawer: HrDrawer( currentRoute :'Leaves'),
      bottomNavigationBar: const HrFooter(selectedIndex: null),
        body: RefreshIndicator(
          onRefresh: () async {
            fetchLeaves();
          },
          child: Column(
        children: [

          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.all(5),
            child: topFilters(scale),
          ),

          if (loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (filteredLeaves.isEmpty)
            const Expanded(child: Center(child: Text("No leaves found")))
          else
            Expanded(
              child: ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: filteredLeaves.length,
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EmployeeLeaveDetailsPage(
                          userId: filteredLeaves[i]['user_id'].toString(),
                          empCode: filteredLeaves[i]['employe_code'] ?? "",
                          item: filteredLeaves[i],
                        ),
                      ),
                    );

                    if (result == true) {
                      fetchLeaves(); //  refresh list
                    }
                  },
                  child: leaveCard(filteredLeaves[i], i),
                ),
                ),
              ),
        ],
      ),
      ),
    );
  }

  Widget topFilters(double scale) {
    return SizedBox(
      height: 50, // important for proper layout
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [

            /// SEARCH
            expandableSearch(scale),
            // SizedBox(
            //   height: 40,
            // width : 200,
            //   // width: isSearchExpanded ? 350 : 160,
            //   child: expandableSearch(scale),
            // ),

            // if (!isSearchExpanded) ...[
              const SizedBox(width: 8),

              /// DATE
              SizedBox(
                width: 150,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GestureDetector(
                      onTap: pickDate,
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(50),
                          // border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                filterDate.isEmpty ? "" : selectedDate,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            if (filterDate.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    filterDate = "";
                                  });
                                  applyFilter();
                                },
                                child: const Icon(Icons.close, size: 16),
                              ),
                          ],
                        ),
                      ),
                    ),

                    /// LABEL
                    Positioned(
                      left: 12,
                      top: -8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        color: Colors.white,
                        child: const Text(
                          "Date",
                          style: TextStyle(fontSize: 11, color: Colors.black),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              /// LEAVE TYPE
              SizedBox(
                width: 150,
                child: premiumDropdown(
                  label: "Leave Type",
                  value: selectedLeaveType,
                  items: leaveTypes,
                  icon: Icons.category,
                  onChanged: (val) {
                    setState(() => selectedLeaveType = val);
                    applyFilter();
                  },
                ),
              ),

              const SizedBox(width: 8),

              /// STATUS
              SizedBox(
                width: 150,
                child: premiumDropdown(
                  label: "Status",
                  value: selectedStatus,
                  items: statusMap,
                  icon: Icons.flag,
                  onChanged: (val) {
                    setState(() => selectedStatus = val);
                    applyFilter();
                  },
                ),
              ),
            ],
          // ],
        ),
      ),
    );
  }


  Widget premiumDropdown({
    required String label,
    required String value,
    required Map<String, String> items,
    required Function(String) onChanged,
    required IconData icon,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        /// MAIN FIELD
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(50),
            // border: Border.all(color: Colors.grey.shade400),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down),
                    items: items.entries.map((e) {
                      return DropdownMenuItem<String>(
                        value: e.key,
                        child: Text(
                          e.value,
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) onChanged(val);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        /// FLOATING LABEL (ATTACHED TO BORDER)
        Positioned(
          left: 12,
          top: -8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            color: Colors.white,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ],
    );
  }

}