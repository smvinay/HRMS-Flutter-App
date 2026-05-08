import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/toast.dart';
import 'EditEmployeePage.dart';
import 'hr_drawer.dart';
import 'hr_footer.dart';

class MyTeamPage extends StatefulWidget {
  const MyTeamPage({super.key});

  @override
  State<MyTeamPage> createState() => _MyTeamPageState();
}

class _MyTeamPageState extends State<MyTeamPage> {
  List employees = [];
  List filteredEmployees = [];
  String filterStatus = "active";
  TextEditingController searchController = TextEditingController();

  final ImagePicker picker = ImagePicker();
  bool isUploading = false;
  final FocusNode searchFocusNode = FocusNode();
  bool isSearchExpanded = true;

  @override
  void initState() {
    super.initState();
    fetchEmployees();
  }

  @override
  void dispose() {
    searchController.dispose();
    searchFocusNode.dispose();
    super.dispose();
  }

  double _calcScaleFromWidth(double w) {
    const base = 500.0;
    final raw = (w / base);
    return raw.clamp(0.7, 1.2);
  }

  double _s(double size, double scale) {
    return size * scale;
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
        filterEmployees(); // apply default filter
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

  int getReferenceCount(String? photos) {
    if (photos == null || photos.trim().isEmpty) return 0;

    return photos.split(',').where((e) => e.trim().isNotEmpty).length;
  }

  @override
  Widget build(BuildContext context) {
    final scale = _calcScaleFromWidth(
      MediaQuery.of(context).size.width,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Employee',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        backgroundColor: const Color(0xFF0557a2),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: HrDrawer( currentRoute: 'Employee'),
      bottomNavigationBar: const HrFooter(selectedIndex: null),
      body: Stack(
        children: [

          RefreshIndicator(
            onRefresh: fetchEmployees,

            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),

              slivers: [

                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(_s(6, scale)),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [

                          expandableSearch(scale),

                          SizedBox(width: _s(5, scale)),

                          SizedBox(
                            width: 280,
                            child: slidingSegment(scale),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                /// EMPLOYEE LIST
                if (filteredEmployees.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text("No Employees Found"),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        final emp = filteredEmployees[index];

                        return _employeeCard(emp);
                      },
                      childCount: filteredEmployees.length,
                    ),
                  ),
              ],
            ),
          ),

          if (isUploading)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
            ),
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

    final refCount = getReferenceCount(emp["reference_photos"]);

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(

        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditEmployeePage(
                employeeCode: emp["employe_code"],
              ),
            ),
          );
        },

        leading: Stack(
          children: [

            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.blue.shade100,

              backgroundImage:
              (emp["profile_thumbnail"] != null &&
                  emp["profile_thumbnail"]
                      .toString()
                      .trim()
                      .isNotEmpty)
                  ? NetworkImage(profile)
                  : null,

              child:
              (emp["profile_thumbnail"] == null ||
                  emp["profile_thumbnail"]
                      .toString()
                      .trim()
                      .isEmpty)
                  ? Text(
                name.isNotEmpty
                    ? name[0].toUpperCase()
                    : "?",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              )
                  : null,
            ),

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

        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),

        subtitle: Text(department),

        // Optional: remove or keep icon
        trailing: SizedBox(
          width: 50,
          height: 50,
          child: Stack(
            alignment: Alignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  _showImagePickerOptions(emp);
                },
                child: const Icon(Icons.add_a_photo, size: 25),
              ),

              if (refCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$refCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        height: 1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
        enabled: true,
      ),
    );
  }


  Widget expandableSearch(double scale) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: isSearchExpanded ? _s(250, scale) : _s(50, scale),
      height: _s(35, scale),
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
              setState(() {
                // isSearchExpanded = !isSearchExpanded;

                if (!isSearchExpanded) {
                  searchController.clear();
                  searchFocusNode.unfocus();
                  filterEmployees();
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

                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(
                    icon: Icon(
                      Icons.close,
                      size: _s(16, scale),
                    ),
                    onPressed: () {
                      searchController.clear();
                      searchFocusNode.unfocus();

                      setState(() {});

                      filterEmployees();
                    },
                  )
                      : null,
                ),
                onChanged: (val) {
                  setState(() {});
                  filterEmployees();
                },
              ),
            )
        ],
      ),
    );
  }

  Widget slidingSegment(double scale) {
    return Container(
      height: _s(35, scale),
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

              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                left: filterStatus == "active"
                    ? 0
                    : filterStatus == "inactive"
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
                  _segItem("Active", "active", scale),
                  _segItem("Inactive", "inactive", scale),
                  _segItem("All", "all", scale),
                ],
              )
            ],
          );
        },
      ),
    );
  }
  Widget _segItem(String title, String value, double scale) {
    bool active = filterStatus == value;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(_s(20, scale)),
        onTap: () {
          setState(() {
            filterStatus = value;
          });

          filterEmployees();
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
  void _showImagePickerOptions(Map emp) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text("Open Camera"),
                onTap: () {
                  Navigator.pop(context);
                  pickReferenceImage(ImageSource.camera, emp);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo),
                title: const Text("Upload from Gallery"),
                onTap: () {
                  Navigator.pop(context);
                  pickReferenceImage(ImageSource.gallery, emp);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> pickReferenceImage(ImageSource source, Map emp) async {
    final XFile? image = await picker.pickImage(source: source);
    if (image == null) return;

    String path = image.path.toLowerCase();

    ///  VALIDATE FILE TYPE
    if (!(path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png'))) {

      AppToast.show("Only JPG and PNG images are allowed", isError: true);
      return;
    }


    File file = File(image.path);

    final fileSize = await file.length();

    /// Convert to MB properly
    double fileSizeMB = fileSize / (1024 * 1024);

    if (fileSizeMB > 4) {

      AppToast.show( "Selected image size is ${fileSizeMB.toStringAsFixed(1)} MB. "
          "Please upload an image smaller than 4 MB.", isError: true);
      return;
    }

    setState(() => isUploading = true);

    try {
      await uploadReferenceImages(
        [file],
        emp["employe_code"],
        emp["faceApiFolderName"] ?? "",
        emp["reference_photos"] ?? "",
      );
    } catch (e) {
      AppToast.show("Upload failed", isError: true);
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(content: Text("Upload failed")),
      // );
    } finally {
      setState(() => isUploading = false);
    }
  }

  Future<void> uploadReferenceImages(
    List<File> images,
    String employeeCode,
    String faceApiFolderName,
    String oldReference,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    String? apiKey = prefs.getString('apiKey');
    String? companyDb = prefs.getString('companyDb');
    String? cid = prefs.getString('cid');

    var request = http.MultipartRequest(
      'POST',
      Uri.parse(
        'https://hrms.attendify.ai/index.php/mobileApi/save_reference_photos',
      ),
    );

    request.headers.addAll({
      'apiKey': apiKey ?? '',
      'companyDb': companyDb ?? '',
    });

    request.fields['cid'] = cid ?? '';
    request.fields['employee_code'] = employeeCode;
    request.fields['faceApiFolderName'] = faceApiFolderName;
    request.fields['oldreference'] = oldReference;

    for (var img in images) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'reference_photos[]',
          img.path,
        ),
      );
    }

    var response = await request.send();
    var resBody = await response.stream.bytesToString();
    var jsonData = json.decode(resBody);

    if (jsonData['status'] == true) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Reference image uploaded successfully"),
          duration: Duration(seconds: 2),
        ),
      );

      fetchEmployees();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(jsonData['message'] ?? "Upload failed")),
      );
    }
  }
}
