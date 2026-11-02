
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Student Database',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
        ),
        useMaterial3: true,
      ),
      home: const StudentPage(),
    );
  }
}

class StudentPage extends StatefulWidget {
  const StudentPage({super.key});

  @override
  State<StudentPage> createState() => _StudentPageState();
}

class _StudentPageState extends State<StudentPage> {
  final nameController = TextEditingController();
  final courseController = TextEditingController();

  List<Map<String, dynamic>> localStudents = [];

  final CollectionReference cloudStudents =
      FirebaseFirestore.instance.collection('students');

  @override
  void initState() {
    super.initState();
    loadLocalStudents();
  }

  @override
  void dispose() {
    nameController.dispose();
    courseController.dispose();
    super.dispose();
  }

  // Load SQLite records
  Future<void> loadLocalStudents() async {
    final data = await DatabaseHelper.instance.getStudents();

    if (mounted) {
      setState(() {
        localStudents = data;
      });
    }
  }

  // Show message
  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Add student dialog
  void showStudentDialog({
    String? documentId,
    int? localId,
    String? oldName,
    String? oldCourse,
    required bool isCloud,
  }) {
    nameController.text = oldName ?? '';
    courseController.text = oldCourse ?? '';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            oldName == null ? 'Add Student' : 'Edit Student',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Student Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: courseController,
                decoration: const InputDecoration(
                  labelText: 'Course',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final course = courseController.text.trim();

                if (name.isEmpty || course.isEmpty) {
                  return;
                }

                try {
                  if (isCloud) {
                    if (documentId == null) {
                      await cloudStudents.add({
                        'name': name,
                        'course': course,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                    } else {
                      await cloudStudents.doc(documentId).update({
                        'name': name,
                        'course': course,
                      });
                    }
                  } else {
                    if (localId == null) {
                      await DatabaseHelper.instance
                          .insertStudent(name, course);
                    } else {
                      await DatabaseHelper.instance
                          .updateStudent(localId, name, course);
                    }

                    await loadLocalStudents();
                  }

                  if (!dialogContext.mounted) return;

                  Navigator.pop(dialogContext);

                  if (mounted) {
                    showMessage(
                      oldName == null
                          ? 'Student added successfully!'
                          : 'Student updated successfully!',
                    );
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }

                  if (mounted) {
                    showMessage('Error: $e');
                  }
                }
              },
              child: Text(oldName == null ? 'Add' : 'Update'),
            ),
          ],
        );
      },
    );
  }

  // Delete SQLite student
  Future<void> deleteLocalStudent(int id) async {
    await DatabaseHelper.instance.deleteStudent(id);
    await loadLocalStudents();

    if (mounted) {
      showMessage('Local student deleted!');
    }
  }

  // Delete Firebase student
  Future<void> deleteCloudStudent(String id) async {
    try {
      await cloudStudents.doc(id).delete();

      if (mounted) {
        showMessage('Cloud student deleted!');
      }
    } catch (e) {
      if (mounted) {
        showMessage('Error: $e');
      }
    }
  }

  // SQLite student card
  Widget localStudentCard(Map<String, dynamic> student) {
    final id = student['id'] as int;

    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.deepPurple,
          child: Icon(Icons.person, color: Colors.white),
        ),
        title: Text(student['name']),
        subtitle: Text('Course: ${student['course']}'),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () {
                showStudentDialog(
                  localId: id,
                  oldName: student['name'],
                  oldCourse: student['course'],
                  isCloud: false,
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => deleteLocalStudent(id),
            ),
          ],
        ),
      ),
    );
  }

  // Firebase student card
  Widget cloudStudentCard(
    QueryDocumentSnapshot document,
  ) {
    final data = document.data() as Map<String, dynamic>;

    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.orange,
          child: Icon(Icons.cloud, color: Colors.white),
        ),
        title: Text(data['name'] ?? ''),
        subtitle: Text('Course: ${data['course'] ?? ''}'),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () {
                showStudentDialog(
                  documentId: document.id,
                  oldName: data['name'],
                  oldCourse: data['course'],
                  isCloud: true,
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => deleteCloudStudent(document.id),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EFF8),

      appBar: AppBar(
        title: const Text(
          'Student Database Management',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // SQLite section
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.storage, color: Colors.deepPurple),
                        SizedBox(width: 10),
                        Text(
                          'SQLite - Local Storage',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          showStudentDialog(isCloud: false);
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Local Student'),
                      ),
                    ),

                    const SizedBox(height: 10),

                    if (localStudents.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(15),
                        child: Center(
                          child: Text('No local students found.'),
                        ),
                      )
                    else
                      ...localStudents.map(localStudentCard),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Firebase section
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.cloud, color: Colors.orange),
                        SizedBox(width: 10),
                        Text(
                          'Firebase - Cloud Storage',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          showStudentDialog(isCloud: true);
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Cloud Student'),
                      ),
                    ),

                    const SizedBox(height: 10),

                    StreamBuilder<QuerySnapshot>(
                      stream: cloudStudents
                          .orderBy('createdAt', descending: true)
                          .snapshots(),

                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Text(
                            'Firebase Error: ${snapshot.error}',
                          );
                        }

                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final documents =
                            snapshot.data?.docs ?? [];

                        if (documents.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(15),
                            child: Center(
                              child: Text('No cloud students found.'),
                            ),
                          );
                        }

                        return Column(
                          children: documents
                              .map(cloudStudentCard)
                              .toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
