import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'employee_leave_details_page.dart';
import 'global_state.dart';

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
  Set<int> expandedIndex = {};

  Map<String, String> statusMap = {
    "All": "All",
    "0": "Pending",
    "1": "Approved",
    "2": "Rejected"
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

  Widget slidingSegment(double scale) {
    return Container(
      height: _s(40, scale),
      padding: EdgeInsets.all(_s(4, scale)),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(_s(20, scale)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          double width = constraints.maxWidth / 4;

          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                left: filter == "all"
                    ? 0
                    : filter == "approved"
                    ? width
                    : filter == "rejected"
                    ? width * 2
                    : width * 3,
                top: 0,
                bottom: 0,
                child: Container(
                  width: width,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              Row(
                children: [
                  _segItem("All", "all", scale),
                  _segItem("Approved", "approved", scale),
                  _segItem("Rejected", "rejected", scale),
                  _segItem("Pending", "pending", scale),
                ],
              )
            ],
          );
        },
      ),
    );
  }

  Widget _segItem(String title, String value, double scale) {
    bool active = filter == value;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => filter = value);
          applyFilter();
        },
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontSize: _s(12, scale),
              fontWeight: FontWeight.w600,
              color: active ? Colors.black : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }


  Widget expandableSearch(double scale) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: isSearchExpanded ? _s(250, scale) : _s(10, scale),
      height: _s(40, scale),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(_s(10, scale)),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          /// SEARCH ICON
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              setState(() => isSearchExpanded = true);

              ///  AUTO FOCUS AFTER BUILD
              Future.delayed(const Duration(milliseconds: 200), () {
                FocusScope.of(context).requestFocus(searchFocus);
              });
            },
          ),

          /// TEXT FIELD (ONLY WHEN EXPANDED)
          if (isSearchExpanded)
            Expanded(
              child: TextField(
                controller: searchController,
                focusNode: searchFocus,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: "Search...",
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  search = val;
                  applyFilter();
                },
              ),
            ),

          /// CLOSE ICON
          if (isSearchExpanded)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  isSearchExpanded = false;
                  search = "";
                  searchController.clear();
                });

                FocusScope.of(context).unfocus();
                applyFilter();
              },
            )
        ],
      ),
    );
  }


  Widget leaveCard(Map item, int index) {
    int status = int.tryParse(item['approved'].toString()) ?? 0;

    DateTime applieDate = DateTime.parse(item['applied_date']);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        // color: getStatusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          /// TOP ROW
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          formatDate(applieDate.toString()),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    Text(
                      item['type'] ?? "",
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 6),
                    /// PROFILE + USER NAME (NEW TOP SECTION)
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
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
                        const SizedBox(width: 8),
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
                      ],
                    ),

                  ],
                ),
              ),

              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [


                    _statusChip(status),
                    const SizedBox(height: 6),
                    RichText(
                      textAlign: TextAlign.right,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text:
                            "${formatDate(item['from_date'])} - ${formatDate(item['to_date'])} ",
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w400, //  more weight
                              color: Colors.black87,
                            ),
                          ),
                          TextSpan(
                            text:
                            "(${item['days']} ${double.tryParse(item['days'].toString()) == 1 ? 'day' : 'days'})",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // const Icon(Icons.subdirectory_arrow_right, size: 14, color: Colors.grey),
                        // const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item['reporting_to_name'] ?? "",
                            maxLines: 1,
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    // const SizedBox(height: 6),
                    // if (status == 0)
                    //   // Row(
                    //   //   mainAxisAlignment: MainAxisAlignment.end,
                    //     // children: [
                    //       // _actionBtn(
                    //       //   icon: Icons.close,
                    //       //   label: "Reject",
                    //       //   color: Colors.red,
                    //       //   onTap: () => rejectLeave(item['leave_id'].toString()),
                    //       // ),
                    //       // const SizedBox(width: 6),
                    //       // _actionBtn(
                    //       //   icon: Icons.check,
                    //       //   label: "Approve",
                    //       //   color: Colors.green,
                    //       //   onTap: () => approveLeave(item['leave_id'].toString()),
                    //       // ),
                    //     // ],
                    //   ),
                    ],
                ),
              ),
            ],
          ),

          /// REASON + EXPAND
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
                            ? (expandedIndex.contains(index) ? null : 2)
                            : null,
                        overflow: overflow
                            ? (expandedIndex.contains(index)
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
                            if (expandedIndex.contains(index)) {
                              expandedIndex.remove(index);
                            } else {
                              expandedIndex.add(index);
                            }
                          });
                        },
                        child: Icon(
                          expandedIndex.contains(index)
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
                            ? (expandedIndex.contains(index) ? null : 2)
                            : null,
                        overflow: overflow
                            ? (expandedIndex.contains(index)
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
                            if (expandedIndex.contains(index)) {
                              expandedIndex.remove(index);
                            } else {
                              expandedIndex.add(index);
                            }
                          });
                        },
                        child: Icon(
                          expandedIndex.contains(index)
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
      // decoration: BoxDecoration(
      //   color: color.withOpacity(0.12),
      //   borderRadius: BorderRadius.circular(20),
      //   border: Border.all(color: color.withOpacity(0.3)),
      // ),
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

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
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
            'Team Leaves',
            style: TextStyle(
              color: Colors.white,
              fontSize: _s(20, scale),
            ),
          ),
          backgroundColor: const Color(0xFF0557a2),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            fetchLeaves();
          },
          child: Column(
        children: [

          Padding(
            padding: const EdgeInsets.all(8),
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
      width: double.infinity,
      child: Row(
        children: [

          /// SEARCH (always visible)
          Expanded(
            flex: isSearchExpanded ? 6 : 2,
            child: expandableSearch(scale),
          ),

          /// 👉 HIDE OTHER FILTERS WHEN SEARCH IS OPEN
          if (!isSearchExpanded) ...[
            const SizedBox(width: 8),

            /// DATE
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: pickDate,
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          filterDate.isEmpty ? "Date" : selectedDate,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),

                      //  CLEAR BUTTON
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
            ),

            const SizedBox(width: 8),

            /// LEAVE TYPE
            Expanded(
              flex: 2,
              child: premiumDropdown(
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
            Expanded(
              flex: 2,
              child: premiumDropdown(
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
        ],
      ),
    );
  }

  Widget premiumDropdown({
    required String value,
    required Map<String, String> items,
    required Function(String) onChanged,
    required IconData icon,
  }) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down),
          items: items.entries.map((e) {
            return DropdownMenuItem<String>(
              value: e.key, // actual value (0,1,2)
              child: Text(
                e.value, // display text (Pending, Approved)
                style: const TextStyle(fontSize: 12),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }

}