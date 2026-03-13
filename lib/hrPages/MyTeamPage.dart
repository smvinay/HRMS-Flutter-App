import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'EditEmployeePage.dart';
import 'hr_drawer.dart';
import 'hr_footer.dart';
import 'hr_header.dart';

class MyTeamPage extends StatefulWidget {
  const MyTeamPage({super.key});

  @override
  State<MyTeamPage> createState() => _MyTeamPageState();
}

class _MyTeamPageState extends State<MyTeamPage> {

  List employees = [];
  List filteredEmployees = [];
  String filterStatus = "all";
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchEmployees();
  }

  Future<void> fetchEmployees() async {

    final prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('apiKey');
    String? companyDb = prefs.getString('companyDb');
    String? cid = prefs.getString('cid');
    String? level_id = prefs.getString('level_id');

    final response = await http.get(
      Uri.parse(
          "https://hrms.attendify.ai/index.php/mobileApi/getAllUsers?cid=$cid&level_id=$level_id"),
      headers: {
        'apiKey': apiKey ?? '',
        'companyDb': companyDb ?? '',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      setState(() {
        employees = data["data"];
        filteredEmployees = employees;
      });
    }
  }

  void filterEmployees() {
    String query = searchController.text.toLowerCase();

    setState(() {
      filteredEmployees = employees.where((emp) {

        final name = (emp["first_name"] ?? "").toLowerCase();
        final status = emp["trash"];
        bool searchMatch = name.contains(query);
        bool statusMatch = filterStatus == "all" ||
            (filterStatus == "active" && status == "0") ||
            (filterStatus == "inactive" && status == "1");

        return searchMatch && statusMatch;

      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: const HrHeader(),
      drawer: HrDrawer(),
      bottomNavigationBar: const HrFooter(selectedIndex: 0),
      body: Column(
        children: [

          /// TOP FILTERS
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [

                /// SEARCH
                Expanded(
                  child: TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      hintText: "Search employee",
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      filterEmployees();
                    },
                  ),
                ),

                const SizedBox(width: 10),

                /// STATUS FILTER
                DropdownButton<String>(
                  value: filterStatus,
                  items: const [
                    DropdownMenuItem(
                      value: "all",
                      child: Text("All"),
                    ),
                    DropdownMenuItem(
                      value: "active",
                      child: Text("Active"),
                    ),
                    DropdownMenuItem(
                      value: "inactive",
                      child: Text("Inactive"),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      filterStatus = value!;
                    });
                    filterEmployees();
                  },
                )
              ],
            ),
          ),

          /// EMPLOYEE LIST
          Expanded(
            child: ListView.builder(
              itemCount: filteredEmployees.length,
              itemBuilder: (context, index) {

                final emp = filteredEmployees[index];

                return _employeeCard(emp);
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _employeeCard(Map emp) {

    String name = "${emp["first_name"] ?? ""}".trim();
    String department = emp["departmentname"] ?? "";

    bool isActive = emp["trash"] == "0";

    String profile =
        "https://hrms.attendify.ai/photos/${emp["profile_thumbnail"] ?? ""}";

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(

        /// PROFILE + STATUS DOT
        leading: Stack(
          children: [

            CircleAvatar(
              radius: 24,
              backgroundImage: NetworkImage(profile),
            ),

            /// STATUS DOT
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                height: 12,
                width: 12,
                decoration: BoxDecoration(
                  color: isActive ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),

        /// NAME + DEPARTMENT
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),

        subtitle: Text(department),

        /// EDIT ICON
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EditEmployeePage(
                  employeeCode: emp["employe_code"],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}