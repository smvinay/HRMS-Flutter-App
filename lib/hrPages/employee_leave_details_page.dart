import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/toast.dart';

class EmployeeLeaveDetailsPage extends StatefulWidget {
  final String userId;
  final String empCode;
  final Map item;

  const EmployeeLeaveDetailsPage({
    super.key,
    required this.userId,
    required this.empCode,
    required this.item,
  });

  @override
  State<EmployeeLeaveDetailsPage> createState() =>
      _EmployeeLeaveDetailsPageState();
}

class _EmployeeLeaveDetailsPageState
    extends State<EmployeeLeaveDetailsPage> {
  List myLeaves = [];
  bool loading = true;
  Set<String> expandedIndex = <String>{};
  Map currentItem = {};

  @override
  void initState() {
    super.initState();
    currentItem = Map.from(widget.item); //  copy
    fetchHistory();
  }

  Future<void> fetchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      String apiKey = prefs.getString('apiKey') ?? "";
      String companyDb = prefs.getString('companyDb') ?? "";
      String cid = prefs.getString('cid') ?? "";

      final response = await http.post(
        Uri.parse(
            "https://hrms.attendify.ai/index.php/MobileApi/employeeLeavedetails"),
        headers: {"apiKey": apiKey, "companyDb": companyDb},
        body: {
          "cid": cid,
          "user_id": widget.userId,
          "code": widget.empCode,
        },
      );

      final data = jsonDecode(response.body);

      setState(() {
        myLeaves = data['userLeaves'] ?? [];
        loading = false;
      });
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  int parseStatus(val) =>
      int.tryParse(val?.toString() ?? '0') ?? 0;

  double _s(double size, double scale) => size * scale;

  @override
  Widget build(BuildContext context) {
    double scale = 1;
    int status = parseStatus(widget.item['approved']);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Leave Details',
          style: TextStyle(
            color: Colors.white,
            fontSize: _s(20, scale),
          ),
        ),
        backgroundColor: const Color(0xFF0557a2),
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      body: Column(
        children: [

          ///  TOP CARD (REUSE YOUR DESIGN)
          Container(
            margin: const EdgeInsets.all(10),
            child: leaveTopCard(currentItem, parseStatus(currentItem['approved'])),
          ),

          ///  HISTORY
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
              padding: const EdgeInsets.all(10),
              children: [

                ///  HEADER
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: const [
                      Expanded(flex: 4, child: Text("Type", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                      Expanded(flex: 8, child: Text("Date", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                      Expanded(flex: 2, child: Text("Days", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                      Expanded(flex: 4, child: Text("Status", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                ///  DATA ROWS
                ...myLeaves.map((item) {
                  int s = parseStatus(item['approved']);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: BorderDirectional(
                        bottom: BorderSide(
                          color: Colors.grey.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [

                        /// TYPE
                        Expanded(
                          flex: 4,
                          child: Text(
                            item['type'] ?? "",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),

                        /// DATE
                        Expanded(
                          flex: 8,
                          child: Text(
                            "${formatDate(item['from_date'])} - ${formatDate(item['to_date'])}",
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ),

                        /// DAYS
                        Expanded(
                          flex: 2,
                          child: Text(
                            "${item['days']}",
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),

                        /// STATUS
                        Expanded(
                          flex: 4,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: getStatusColor(s).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                getStatusText(s),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: getStatusColor(s),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget leaveTopCard(Map item, int status) {
    int index = 1;
    int status = int.tryParse(item['approved'].toString()) ?? 0;

    DateTime appliedDate = DateTime.parse(item['applied_date']);

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
                  ],
                );
              },
            ),
          ],


          const SizedBox(height: 8),
          if (status == 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _actionBtn(
                  icon: Icons.close,
                  label: "Reject",
                  color: Colors.red,
                  onTap: () => rejectLeave(item['leave_id'].toString()),
                ),
                const SizedBox(width: 6),
                _actionBtn(
                  icon: Icons.check,
                  label: "Approve",
                  color: Colors.green,
                  onTap: () => approveLeave(item['leave_id'].toString()),
                ),
              ],
            ),


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

  String formatDate(String date) {
    DateTime d = DateTime.parse(date);
    return "${d.day}-${d.month}-${d.year}";
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

        setState(() {
          currentItem['approved'] = "1"; //  update status
        });

        fetchHistory();
        Navigator.pop(context, true);

        AppToast.show("Leave Approved");

      } else {
        AppToast.show(data['message'] ?? "Failed", isError: true);
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

        setState(() {
          currentItem['approved'] = "2"; //  update status
          currentItem['reject_reason'] = remark;
        });

        fetchHistory();
        Navigator.pop(context, true);
        AppToast.show("Leave Rejected");

      }else {
        AppToast.show(data['message'] ?? "Failed", isError: true);

      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }
}