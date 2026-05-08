import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'hr_drawer.dart';
import 'hr_emp_att.dart';
import 'hr_footer.dart';
import 'hr_header.dart';

class HrEmployeeAtt extends StatefulWidget {
  const HrEmployeeAtt({super.key});

  @override
  State<HrEmployeeAtt> createState() => _HrEmployeeAttState();
}

class _HrEmployeeAttState extends State<HrEmployeeAtt> {
  List allList = [];
  List filteredList = [];

  bool loading = true;

  String search = "";
  String filter = "all"; // all | present | absent

  bool isSearchExpanded = false;

  List<String> employeeCodes = [];
  int currentIndex = 0;
  final TextEditingController searchController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();
  @override
  void initState() {
    super.initState();
    fetchAttendanceList();
  }
  @override
  void dispose() {
    searchController.dispose();
    searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> fetchAttendanceList() async {
    setState(() => loading = true);

    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('apiKey');
    final cid = prefs.getString('cid');
    final companyDb = prefs.getString('companyDb');

    String date = DateFormat("yyyy-MM-dd").format(selectedDate);

    final url = Uri.parse(
        "https://hrms.attendify.ai/index.php/Dashboard/ajax_attendance_listapi?date=$date&cid=$cid");

    try {
      final response = await http.get(url, headers: {
        'apiKey': apiKey ?? '',
        'companyDb': companyDb ?? '',
      });

      final data = json.decode(response.body);

      setState(() {
        allList = data["data"] ?? [];

        employeeCodes = allList
            .map<String>((e) => e['emp_code'].toString())
            .toList();

        loading = false;
      });

      /// IMPORTANT
      /// Re-apply existing search + filter after date change
      applyFilter();

    } catch (e) {
      setState(() => loading = false);
    }
  }

  void applyFilter() {
    List temp = List.from(allList);

    if (filter == "present") {
      temp = temp.where((e) {
        String status = (e['status_text'] ?? "")
            .toString()
            .trim()
            .toUpperCase();

        return ["PRESENT", "HALF DAY", "IN", "OUT"].contains(status);
      }).toList();

    } else if (filter == "absent") {
      temp = temp.where((e) {
        String status = (e['status_text'] ?? "")
            .toString()
            .trim()
            .toUpperCase();

        return status.isEmpty || status == "ABSENT";
      }).toList();

    }
    /// ✅ ADD THIS BLOCK
    else if (filter == "leave") {
      temp = temp.where((e) {
        String isLeave = (e['is_leave'] ?? "").toString();
        return isLeave != "0" && isLeave.isNotEmpty;
      }).toList();
    }

    if (search.isNotEmpty) {
      temp = temp.where((e) =>
          (e['firstName'] ?? "")
              .toLowerCase()
              .contains(search.toLowerCase())
      ).toList();
    }

    setState(() {
      filteredList = temp;
    });
  }

  double _calcScaleFromWidth(double w) {
    const base = 500.0;
    final raw = (w / base);
    return raw.clamp(0.7, 1.2);
  }

  double _s(double size, double scale) {
    return size * scale;
  }

  String formatTime(String? dateTime) {
    if (dateTime == null || dateTime.isEmpty) return "--";

    try {
      DateTime dt = DateTime.parse(dateTime);
      return TimeOfDay.fromDateTime(dt).format(context);
    } catch (e) {
      return "--";
    }
  }

  Widget getDisplayTime(Map item) {
    String status = (item['status_text'] ?? "").toString().trim();

    String? first = item['first_check_in'];
    String? last = item['last_check_in'];
    String duration = item['duration'] ?? "";

    bool hasFirst = first != null && first.isNotEmpty;
    bool hasLast = last != null && last.isNotEmpty;
    bool hasDuration = duration != "--" && duration != "0.00";

    //  FULL DAY (Present / Half Day)
    if ((status == "Present" || status == "Half Day") && hasFirst && hasLast) {
      return Text(
        "${formatTime(first)} - ${formatTime(last)}",
        style: const TextStyle(fontSize: 11),
      );
    }

    //  IN / OUT (LIVE)
    if (status == "IN" || status == "OUT") {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [

          if (hasFirst)
            Text(
              formatTime(first),
              style: const TextStyle(fontSize: 11),
            ),

        ],
      );
    }

    //  Absent or no data
    return const Text("", style: TextStyle(fontSize: 11));
  }

  Widget attendanceRow(Map item, double scale) {

    /// SAFE VALUES
    String status = (item['status_text'] ?? "").toString().trim().toUpperCase();
    String isLeave = (item['is_leave'] ?? "").toString();

    String statusText = (item['status_text'] ?? "").toString();
    String statusTime = (item['status_time'] ?? "").toString();
    String thumb = (item['thumb'] ?? "").toString();
    String firstName = (item['firstName'] ?? "").toString();
    String designation = (item['designationName'] ?? "").toString();

    /// COLOR LOGIC (MATCHING YOUR OLD WORKING CODE)
    Color color;

    switch (status) {
      case "IN":
        color = Colors.blue;
        break;
      case "OUT":
        color = Colors.red;
        break;
      case "PRESENT":
        color = Colors.green;
        break;
      case "HALF DAY":
      case "HALF_DAY":
        color = Colors.orange;
        break;
      case "ABSENT":
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    /// LEAVE OVERRIDE
    if (isLeave.isNotEmpty && isLeave != "0") {
      color = Colors.orange;
    }

    /// BADGE TEXT
    String badgeText = statusText;

    if ((status == "IN" || status == "OUT") && statusTime.isNotEmpty) {
      badgeText = "$statusText $statusTime";
    }

    return GestureDetector(
      onTap: () {
        int index = employeeCodes.indexOf(item['emp_code'].toString());

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EmployeeSwipeScreen(
              employeeList: employeeCodes,
              initialIndex: index,
            ),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: _s(8, scale)),
        padding: EdgeInsets.symmetric(
          horizontal: _s(10, scale),
          vertical: _s(8, scale),
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_s(10, scale)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: _s(6, scale),
            )
          ],
        ),
        child: Row(
          children: [

            /// PROFILE
            CircleAvatar(
              radius: _s(18, scale),
              backgroundColor: Colors.grey.shade200,
              backgroundImage:
              thumb.isNotEmpty ? NetworkImage(thumb) : null,
              child: thumb.isEmpty
                  ? Icon(Icons.person,
                  size: _s(16, scale), color: Colors.grey)
                  : null,
            ),

            SizedBox(width: _s(8, scale)),

            /// NAME + DESIGNATION
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    firstName.isNotEmpty ? firstName : "--",
                    style: TextStyle(
                      fontSize: _s(13, scale),
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  if (designation.isNotEmpty)
                    Text(
                      designation,
                      style: TextStyle(
                        fontSize: _s(11, scale),
                        color: Colors.grey,
                      ),
                    ),
                ],
              ),
            ),

            /// RIGHT SIDE
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [

                /// SAFE TIME DISPLAY
                getDisplayTime(item),

                SizedBox(height: _s(2, scale)),

                /// STATUS BADGE
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: _s(8, scale),
                    vertical: _s(2, scale),
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(.15),
                    borderRadius: BorderRadius.circular(_s(20, scale)),
                  ),
                  child: Text(
                    badgeText.isNotEmpty ? badgeText : "--",
                    style: TextStyle(
                      fontSize: _s(10, scale),
                      color: color,
                    ),
                  ),
                ),

                SizedBox(height: _s(4, scale)),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget filterChips() {
    return Row(
      children: [
        _chip("All", "all"),
        _chip("Present", "present"),
        _chip("Absent", "absent"),
        _chip("Leave", "leave"),
      ],
    );
  }

  Widget _chip(String title, String value) {
    bool active = filter == value;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(title),
        selected: active,
        onSelected: (_) {
          setState(() {
            filter = value;
          });
          applyFilter();
        },
      ),
    );
  }

  Widget searchBox() {
    return TextField(
      decoration: InputDecoration(
        hintText: "Search employee...",
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (val) {
        search = val;
        applyFilter();
      },
    );
  }

  Widget topControls(double scale) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [

          expandableSearch(scale),

          SizedBox(width: _s(5, scale)),

          _dateChip(scale),

          SizedBox(width: _s(5, scale)),

          SizedBox(
            width: 350,
            child: slidingSegment(scale),
          ),
        ],
      ),
    );
  }

  Widget _dateChip(double scale) {
    return InkWell(
      onTap: _selectDate,
      borderRadius: BorderRadius.circular(_s(20, scale)),
      child: Container(
        height: _s(40, scale),
        padding: EdgeInsets.symmetric(horizontal: _s(10, scale)),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(_s(20, scale)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today,
                size: _s(15, scale), color: Colors.blue),

            SizedBox(width: _s(6, scale)),

            Text(
              selectedDateStr,
              style: TextStyle(
                fontSize: _s(12, scale),
                fontWeight: FontWeight.w500,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget segmentedFilter() {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _segmentItem("All", "all"),
          _segmentItem("Present", "present"),
          _segmentItem("Absent", "absent"),
        ],
      ),
    );
  }

  Widget _segmentItem(String title, String value) {
    bool isActive = filter == value;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            filter = value;
          });
          applyFilter();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 2,
          width: filter == "all"
              ? 40
              : filter == "present"
              ? 60
              : 60,
          margin: EdgeInsets.only(
            left: filter == "all"
                ? 10
                : filter == "present"
                ? 70
                : 130,
          ),
          color: Colors.blue,
        ),
      ),
    );
  }

  String selectedDateStr =
  DateFormat("dd MMM").format(DateTime.now());

  DateTime selectedDate = DateTime.now();

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
        selectedDateStr = DateFormat("dd MMM").format(picked);
      });
      searchFocusNode.unfocus();
      fetchAttendanceList(); // reload data
    }
  }


  Widget expandableSearch(double scale) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: isSearchExpanded ? _s(200, scale) : _s(50, scale),
      height: _s(40, scale),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(_s(20, scale)),
      ),
      child: Row(
        children: [

          /// SEARCH ICON
          IconButton(
            padding: EdgeInsets.zero,
            icon: Icon(Icons.search, size: _s(18, scale)),
            onPressed: () {
              setState(() {
                isSearchExpanded = !isSearchExpanded;
                if (!isSearchExpanded) {
                  search = "";
                  searchController.clear();
                  /// UNFOCUS
                  searchFocusNode.unfocus();

                  applyFilter();
                }
              });
            },
          ),

          if (isSearchExpanded)
            Expanded(
              child: TextField(
                controller: searchController,
                focusNode: searchFocusNode,
                maxLength: 150,
                buildCounter: (
                    context, {
                      required currentLength,
                      required isFocused,
                      maxLength,
                    }) {
                  return null;
                },
                style: TextStyle(fontSize: _s(12, scale)),
                decoration: InputDecoration(
                  hintText: "Search",
                  hintStyle: TextStyle(fontSize: _s(11, scale)),
                  border: InputBorder.none,
                  isDense: true,

                  suffixIcon: search.isNotEmpty
                      ? IconButton(
                    icon: Icon(
                      Icons.close,
                      size: _s(16, scale),
                    ),
                    onPressed: () {

                      /// CLEAR TEXT
                      searchController.clear();

                      /// REMOVE FOCUS + CLOSE KEYBOARD
                      searchFocusNode.unfocus();

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
            )
        ],
      ),
    );
  }

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

              ///  SLIDING BG (PERFECT WIDTH)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                left: filter == "all"
                    ? 0
                    : filter == "present"
                    ? width
                    : filter == "absent"
                    ? width * 2
                    : width * 3,
                top: 0,
                bottom: 0,
                child: Container(
                  width: width,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(_s(16, scale)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: _s(4, scale),
                      )
                    ],
                  ),
                ),
              ),

              Row(
                children: [
                  _segItem("All", "all", scale),
                  _segItem("Present", "present", scale),
                  _segItem("Absent", "absent", scale),
                  _segItem("Leave", "leave", scale),
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
      child: InkWell(
        borderRadius: BorderRadius.circular(_s(20, scale)),
        onTap: () {
          setState(() {
            filter = value;
          });
          applyFilter();
        },
        child: Container(
          alignment: Alignment.center,
          height: double.infinity,
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

  @override
  Widget build(BuildContext context) {
    final scale = _calcScaleFromWidth(
      MediaQuery.of(context).size.width,
    );

    if (MediaQuery.of(context).size.width < 360) {
      isSearchExpanded = false;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Attendance',
          style: TextStyle(
            color: Colors.white,
            fontSize: _s(20, scale),
          ),
        ),
        backgroundColor: const Color(0xFF0557a2),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: HrDrawer(currentRoute: 'Attendance',),
      bottomNavigationBar: const HrFooter(selectedIndex: 0),

        body: RefreshIndicator(
          onRefresh: fetchAttendanceList,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(), //  IMPORTANT
            slivers: [

          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyHeader(
              child: Container(
                color: Colors.white,
                padding: EdgeInsets.all(_s(10, scale)),
                child: topControls(scale),
              ),
            ),
          ),

          ///  HANDLE LOADING / EMPTY
          if (loading || filteredList.isEmpty)
            SliverToBoxAdapter(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : const Center(child: Text("No Data")),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  return attendanceRow(filteredList[index], scale);
                },
                childCount: filteredList.length,
              ),
            ),
        ],
      ),
      ),
    );
  }

}

class _StickyHeader extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyHeader({required this.child});

  @override
  double get minExtent => 60;

  @override
  double get maxExtent => 60;

  @override
  Widget build(context, shrinkOffset, overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(_) => true;
}