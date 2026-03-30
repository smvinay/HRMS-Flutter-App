import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  bool isSearchExpanded = true;

  @override
  void initState() {
    super.initState();
    fetchAttendanceList();
  }

  Future<void> fetchAttendanceList() async {

    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('apiKey');
    final cid = prefs.getString('cid');
    final companyDb = prefs.getString('companyDb');
    String date = DateFormat("yyyy-MM-dd").format(selectedDate);


    final url = Uri.parse(
        "https://hrms.attendify.ai/index.php/Dashboard/ajax_attendance_listapi?date=$date&cid=$cid");

    final response = await http.get(url, headers: {
      'apiKey': apiKey ?? '',
      'companyDb': companyDb ?? '',
    });

    final data = json.decode(response.body);

    setState(() {
      allList = data["data"] ?? [];
      filteredList = List.from(allList); // 🔥 IMPORTANT
      loading = false;
    });
  }

  void applyFilter() {

    List temp = allList;

    /// FILTER
    if (filter == "present") {
      temp = temp.where((e) => e['status_text'] == "IN").toList();
    } else if (filter == "absent") {
      temp = temp.where((e) => e['status_text'] != "IN").toList();
    }

    /// SEARCH
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
    const base = 475.0;
    final raw = (w / base);
    return raw.clamp(0.7, 1.2);
  }

  double _s(double size, double scale) {
    return size * scale;
  }

  Widget attendanceRow(Map item, double scale) {

    bool isIn = item['status_text'] == "IN";
    Color color = isIn ? Colors.green : Colors.red;

    return Container(
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

          CircleAvatar(
            radius: _s(18, scale),
            backgroundColor: Colors.grey.shade200,
            backgroundImage: (item['thumb'] != null && item['thumb'] != "")
                ? NetworkImage(item['thumb'])
                : null,
            child: (item['thumb'] == null || item['thumb'] == "")
                ? Icon(Icons.person, size: _s(16, scale), color: Colors.grey)
                : null,
          ),

          SizedBox(width: _s(8, scale)),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Text(
                  item['firstName'],
                  style: TextStyle(
                    fontSize: _s(13, scale),
                    fontWeight: FontWeight.w600,
                  ),
                ),

                if ((item['designationName'] ?? "").isNotEmpty)
                  Text(
                    item['designationName'],
                    style: TextStyle(
                      fontSize: _s(11, scale),
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [

              Text(
                item['status_time'] ?? "--",
                style: TextStyle(fontSize: _s(11, scale)),
              ),

              SizedBox(height: _s(2, scale)),

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
                  item['status_text'],
                  style: TextStyle(
                    fontSize: _s(10, scale),
                    color: color,
                  ),
                ),
              )
            ],
          )
        ],
      ),
    );
  }
  Widget filterChips() {
    return Row(
      children: [
        _chip("All", "all"),
        _chip("Present", "present"),
        _chip("Absent", "absent"),
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
    return Row(
      children: [

        /// 🔍 SEARCH (fixed size)
        expandableSearch(scale),

        SizedBox(width: _s(5, scale)),

        /// 📅 DATE
        _dateChip(scale),

        SizedBox(width: _s(5, scale)),

        /// 🔥 SEGMENT (auto fit remaining space)
        Expanded(
          child: slidingSegment(scale),
        ),
      ],
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

          IconButton(
            padding: EdgeInsets.zero,
            icon: Icon(Icons.search, size: _s(18, scale)),
            onPressed: () {
              // setState(() {
              //   isSearchExpanded = !isSearchExpanded;
              // });
            },
          ),

          if (isSearchExpanded)
            Expanded(
              child: TextField(
                style: TextStyle(fontSize: _s(12, scale)),
                decoration: InputDecoration(
                  hintText: "Search",
                  hintStyle: TextStyle(fontSize: _s(11, scale)),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: (val) {
                  search = val;
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

          double width = constraints.maxWidth / 3;

          return Stack(
            children: [

              /// 🔥 SLIDING BG (PERFECT WIDTH)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                left: filter == "all"
                    ? 0
                    : filter == "present"
                    ? width
                    : width * 2,
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
                ],
              )
            ],
          );
        },
      ),
    );
  }

  Alignment _getAlignment() {
    switch (filter) {
      case "present":
        return Alignment.center;
      case "absent":
        return Alignment.centerRight;
      default:
        return Alignment.centerLeft;
    }
  }

  Widget _segItem(String title, String value, double scale) {
    bool active = filter == value;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            filter = value;
          });
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

  @override
  Widget build(BuildContext context) {

    final scale = _calcScaleFromWidth(
      MediaQuery.of(context).size.width,
    );

    // if (MediaQuery.of(context).size.width < 360) {
    //   isSearchExpanded = false;
    // }

    return Scaffold(
      appBar: AppBar(title: const Text("Attendance List")),

      body: CustomScrollView(
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

          /// 🔥 HANDLE LOADING / EMPTY
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