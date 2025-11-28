import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mindmate/services/profile_service.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? profile;

  const EditProfileScreen({super.key, this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final ProfileService _service = ProfileService();
  late TextEditingController firstNameController;
  late TextEditingController lastNameController;
  late TextEditingController emailController;
  bool isSaving = false;
  String? avatarUrl;

  List<Map<String, dynamic>> emergencyContacts = [];
  bool isLoadingContacts = true;

  @override
  void initState() {
    super.initState();
    firstNameController =
        TextEditingController(text: widget.profile?['first_name'] ?? '');
    lastNameController =
        TextEditingController(text: widget.profile?['last_name'] ?? '');
    emailController =
        TextEditingController(text: widget.profile?['email'] ?? '');
    avatarUrl = widget.profile?['avatar_url'];
    _loadEmergencyContacts();
  }

  Future<void> _loadEmergencyContacts() async {
    setState(() => isLoadingContacts = true);
    emergencyContacts = await _service.fetchEmergencyContacts();
    setState(() => isLoadingContacts = false);
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked == null) return; // user canceled
    final file = File(picked.path);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Uploading avatar...")),
    );

    try {
      final uploadedUrl = await _service.uploadAvatar(file);
      setState(() => avatarUrl = uploadedUrl);

      await _service.updateUserProfile(
        firstName: firstNameController.text,
        lastName: lastNameController.text,
        avatarUrl: uploadedUrl,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Avatar updated successfully!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  void _showAddOrEditContactDialog({Map<String, dynamic>? contact}) {
    if (contact == null && emergencyContacts.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You can only have up to 3 contacts.")),
      );
      return;
    }

    final nameController = TextEditingController(text: contact?['name'] ?? '');
    final phoneController =
        TextEditingController(text: contact?['phone_number'] ?? '');
    final relationController =
        TextEditingController(text: contact?['relationship'] ?? '');
    bool showError = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(contact == null ? "Add Emergency Contact" : "Edit Contact"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: "Full Name",
                    errorText: showError && nameController.text.isEmpty
                        ? "Required"
                        : null,
                  ),
                ),
                TextField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    labelText: "Phone Number",
                    errorText: showError && phoneController.text.isEmpty
                        ? "Required"
                        : null,
                  ),
                  keyboardType: TextInputType.phone,
                ),
                TextField(
                  controller: relationController,
                  decoration: InputDecoration(
                    labelText: "Relationship",
                    errorText: showError && relationController.text.isEmpty
                        ? "Required"
                        : null,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty ||
                    phoneController.text.isEmpty ||
                    relationController.text.isEmpty) {
                  setState(() => showError = true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Please fill in all contact details.")),
                  );
                  return;
                }

                if (contact == null) {
                  await _service.addEmergencyContact(
                    name: nameController.text,
                    phoneNumber: phoneController.text,
                    relationship: relationController.text,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Contact added successfully")),
                  );
                } else {
                  await _service.updateEmergencyContact(
                    id: contact['id'],
                    name: nameController.text,
                    phoneNumber: phoneController.text,
                    relationship: relationController.text,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Contact updated successfully")),
                  );
                }

                if (mounted) Navigator.pop(context);
                _loadEmergencyContacts();
              },
              child: Text(contact == null ? "Add" : "Save"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteContact(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Contact"),
        content: const Text("Are you sure you want to delete this contact?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Delete")),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _service.deleteEmergencyContact(id);

        // ✅ Update the local list instead of re-fetching
        setState(() {
          emergencyContacts.removeWhere((contact) => contact['id'] == id);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Contact deleted successfully")),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to delete contact: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile"),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _pickAndUploadAvatar,
              child: CircleAvatar(
                radius: 50,
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                backgroundColor: Colors.grey.shade300,
                child: avatarUrl == null
                    ? const Icon(Icons.person, size: 60, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(height: 10),
            const Text("Tap to change avatar",
                style: TextStyle(color: Colors.black54, fontSize: 13)),
            const SizedBox(height: 30),

            TextField(
              controller: firstNameController,
              decoration: const InputDecoration(
                labelText: 'First Name',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: lastNameController,
              decoration: const InputDecoration(
                labelText: 'Last Name',
                prefixIcon: Icon(Icons.badge),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: emailController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),

            // Emergency Contacts Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Emergency Contact(s)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Tooltip(
                  message: emergencyContacts.length >= 3
                      ? "Maximum of 3 contacts reached"
                      : "Add a new emergency contact",
                  child: ElevatedButton.icon(
                    onPressed: emergencyContacts.length >= 3
                        ? null
                        : () => _showAddOrEditContactDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text("Add"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: emergencyContacts.length >= 3
                          ? Colors.grey
                          : Colors.teal,
                      disabledBackgroundColor: Colors.grey.shade400,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            isLoadingContacts
                ? const Center(child: CircularProgressIndicator())
                : emergencyContacts.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          "No emergency contacts yet. Add up to 3 people you trust.",
                          style: TextStyle(color: Colors.black54),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : Column(
                        children: emergencyContacts.map((c) {
                          return Card(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 3,
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              leading: const Icon(Icons.contact_phone,
                                  color: Colors.teal),
                              title: Text(
                                c['name'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                  "${c['relationship']} • ${c['phone_number']}"),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.blueAccent),
                                    onPressed: () =>
                                        _showAddOrEditContactDialog(contact: c),
                                  ),
                                  if (emergencyContacts.length > 1)
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.redAccent),
                                      onPressed: () => _deleteContact(c['id']),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),

            const SizedBox(height: 30),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(isSaving ? "Saving..." : "Save Changes"),
                onPressed: isSaving
                    ? null
                    : () async {
                        setState(() => isSaving = true);
                        await _service.updateUserProfile(
                          firstName: firstNameController.text,
                          lastName: lastNameController.text,
                          avatarUrl: avatarUrl,
                        );
                        setState(() => isSaving = false);
                        if (mounted) Navigator.pop(context);
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
