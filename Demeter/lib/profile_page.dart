import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class ProfilePage extends StatefulWidget {
  final String? userId;
  final bool shouldResetIndex;
  const ProfilePage({super.key, required this.userId, required this.shouldResetIndex});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  List<String> allCuisines = [];
  User? loggedInUser;
  String? userEmail;
  Map<String, bool> selectedCuisines = {};  // User's current selections
  final TextEditingController _newEmailController = TextEditingController();

  void getCurrentUser() {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        loggedInUser = user;
        userEmail = user.email;
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> fetchAllCuisines() async {
    final userDocRef = FirebaseFirestore.instance
        .collection("userinfo")
        .doc(loggedInUser!.uid);

    final userDocSnapshot = await userDocRef.get();

    if (userDocSnapshot.exists) {
      final userData = userDocSnapshot.data() as Map<String, dynamic>;
      final userCuisines = userData['cuisines'] as Map<String, dynamic>;

      setState(() {
        allCuisines = userCuisines.keys.toList();
      });
    } else {
      // TODO Handle the case where the user document doesn't exist
      // ignore: avoid_print
      print('User document not found');
    }
  }



  // Create cuisine widgets
  List<Widget> buildCuisineWidgets(Map<String, dynamic> userData) {
    final userCuisines = userData['cuisines'] as Map<String, dynamic>;

    return allCuisines.map((cuisine) {
      return ChoiceChip(
        label: Text(cuisine[0].toUpperCase() + cuisine.substring(1)),
        selected: userCuisines[cuisine] ?? false,
        onSelected: (bool isSelected) {
          setState(() {
            userCuisines[cuisine] = isSelected;
            _updateCuisineSelection(cuisine, isSelected); // Update Firestore
          });
        },
      );
    }).toList();
  }


  Future<void> _updateCuisineSelection(String cuisine, bool isSelected) async {
    try {
      // Firestore update for cuisine preference
      await _firestore.collection('userinfo').doc(loggedInUser!.uid).update({
        'cuisines.$cuisine': isSelected,
      });

      if (isSelected) {
        await _addIngredientsToPantry(cuisine);
      } else {
        await _removeIngredientsFromPantry(cuisine);
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error updating cuisine selection or pantry: $e');
    }
  }


  Future<void> _addIngredientsToPantry(String cuisine) async {
    try {
      var ingredientsSnapshot = await _firestore
          .collection('permanentIngredients')
          .doc(cuisine)
          .get();

      if (ingredientsSnapshot.exists) {
        var ingredients = ingredientsSnapshot.data() as Map<String, dynamic>;

        // Update the 'pantry' section within the user's document
        loggedInUser!.uid;
        ingredients.forEach((ingredientName, _) {
          _firestore
              .collection('userinfo')
              .doc(loggedInUser!.uid)
              .collection('pantry')
              .doc(ingredientName)
              .set({'isPermanent': true}, SetOptions(merge: true));
        });
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error adding ingredients to pantry: $e');
    }
  }

  Future<void> _removeIngredientsFromPantry(String cuisine) async {
    try {
      var ingredientsSnapshot = await _firestore
          .collection('permanentIngredients')
          .doc(cuisine)
          .get();

      if (ingredientsSnapshot.exists) {
        var ingredients = ingredientsSnapshot.data() as Map<String, dynamic>;

        // Delete ingredients from the 'pantry' section
        ingredients.forEach((ingredientName, _) {
          _firestore
              .collection('userinfo')
              .doc(loggedInUser!.uid)
              .collection('pantry')
              .doc(ingredientName)
              .delete();
        });
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error removing ingredients from pantry: $e');
    }
  }



  void _showEditNameDialog(BuildContext context, String currentName) {
    TextEditingController nameController = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Name"),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: "Enter new name"),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("Update"),
            onPressed: () {
              _updateName(nameController.text.trim());
              Navigator.pop(context);
            },
          )
        ],
      ),
    );
  }


  void _showEditAgeDialog(BuildContext context, String currentAge) {
    TextEditingController ageController = TextEditingController(text: currentAge);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Age"),
        content: TextField(
          controller: ageController,
          decoration: const InputDecoration(hintText: "Enter new age"),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("Update"),
            onPressed: () {
              _updateAge(ageController.text.trim());
              Navigator.pop(context);
            },
          )
        ],
      ),
    );
  }

  Future<void> _updateName(String newName) async {
    await _firestore.collection('userinfo').doc(loggedInUser!.uid).update({
      'name': newName,
    });
  }

  Future<void> _updateAge(String newAge) async {
    int ageAsNumber = int.parse(newAge);
    await _firestore.collection('userinfo').doc(loggedInUser!.uid).update({
      'age': ageAsNumber,
    });
  }

  void _showEditEmailDialog(BuildContext context) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Change Email"),
          content: Column(
            mainAxisSize: MainAxisSize.min, // Shrink-wrap column
            children: [
              TextField(
                controller: _newEmailController,
                decoration: const InputDecoration(hintText: "Enter new email"),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                child: const Text("Update Email"),
                onPressed: () async {
                  // Perform change email process
                  try {
                    await _changeEmail(_newEmailController.text.trim());

                  } catch (error) {
                    // TODO Handle any errors that might occur during the process
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Something went wrong."),
                    ));
                  }
                },
              )
            ],
          ),
        ));
  }

  Future<void> _changeEmail(String newEmail) async {
    try {
      // Reauthenticate for security
      await _reauthenticateUser();

      // Send verification code
      await loggedInUser!.verifyBeforeUpdateEmail(newEmail);

      // Reset the text field
      _newEmailController.clear();

      // Inform user and provide a way to update email after verification
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            "Verification code sent. Please verify to complete the update. You'll be logged out in 5 seconds."),
      ));
      // ignore: use_build_context_synchronously
      Navigator.pop(context);
      await Future.delayed(const Duration(seconds: 5));

      // Log out the user
      await _auth.signOut();
      // ignore: use_build_context_synchronously
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } on FirebaseAuthException catch (e) {
      // TODO Handle errors appropriately
      if (e.code == 'requires-recent-login') {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                "This operation is sensitive and requires recent authentication. Log in again before retrying.")));
      } else {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.message ?? "Something went wrong")));
      }
    }
  }


  Future<void> _reauthenticateUser() async {
    // Create a dialog for password entry
    final TextEditingController passwordController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reauthenticate"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Please enter your password to confirm this action:"),
            const SizedBox(height: 10),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(hintText: "Password"),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text("Confirm"),
            onPressed: () {
              _tryReauthentication(passwordController.text.trim());
              Navigator.pop(context);
            },
          )
        ],
      ),
    );
  }

  Future<void> _tryReauthentication(String password) async {
    try {
      // Reauthenticate with email and password
      AuthCredential credential =
      EmailAuthProvider.credential(email: loggedInUser!.email!, password: password);
      await loggedInUser!.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Incorrect password.")));
      } else {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                "Reauthentication failed. Please try again, or contact support if the issue persists.")));
      }
    }
  }

  void _showChangePasswordDialog(BuildContext context) {
    TextEditingController oldPasswordController = TextEditingController();
    TextEditingController newPasswordController = TextEditingController();
    TextEditingController confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Change Password"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPasswordController,
              obscureText: true,
              decoration: const InputDecoration(hintText: "Old Password"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(hintText: "New Password"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(hintText: "Confirm New Password"),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text("Change"),
            onPressed: () async {
              if (newPasswordController.text.trim() != confirmPasswordController.text.trim()) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("Passwords do not match."),
                ));
                return; // Don't proceed if passwords don't match
              }

              // Call the _changePassword function here
              try {
                await _changePassword(
                    oldPasswordController.text.trim(),
                    newPasswordController.text.trim());
                // ignore: use_build_context_synchronously
                Navigator.pop(context); // Close the dialog
              } catch (error) {
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(error.toString()),
                ));
              }
            },
          )
        ],
      ),
    );
  }

  Future<void> _changePassword(String oldPassword, String newPassword) async {
    // 1. Reauthenticate user with old password
    try {
      AuthCredential credential = EmailAuthProvider.credential(
          email: loggedInUser!.email!, password: oldPassword);
      await loggedInUser!.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        throw Exception('Incorrect password');
      } else {
        throw Exception('Authentication failed. Please try again.');
      }
    }

    // 2. Update password
    try {
      await loggedInUser!.updatePassword(newPassword);
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Password changed successfully."),
      ));
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? "Error updating password");
    }
  }

  @override
  void initState() {
    super.initState();
    getCurrentUser();
    fetchAllCuisines(); // Fetch cuisines on initialization
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
        context: context,
        builder: (context) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera),
                title: const Text('Camera'),
                onTap: () {
                  _pickImage(ImageSource.camera);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () {
                  _pickImage(ImageSource.gallery);
                  Navigator.of(context).pop();
                },
              )
            ],
          );
        });
  }

  Future<void> _pickImage(ImageSource source) async {
    ImagePicker imagePicker = ImagePicker();
    try {
      final pickedImageFile = await imagePicker.pickImage(
          source: source, imageQuality: 50, maxWidth: 500, maxHeight: 500);

      if (pickedImageFile != null) {
        _handleImageUpload(pickedImageFile);
      }
    } catch (e) {
      // Handle any errors
    }
  }

  Future<void> _handleImageUpload(XFile pickedImageFile) async {
    try {
      setState(() {
        // Show loading indicator
      });

      // Upload image to Firebase Storage
      final storageRef = FirebaseStorage.instance.ref().child('profile_images/${loggedInUser!.uid}.png');
      await storageRef.putFile(File(pickedImageFile.path));

      // Get download URL
      final downloadURL = await storageRef.getDownloadURL();

      // Update Firestore user document
      await _firestore
          .collection('userinfo')
          .doc(loggedInUser!.uid)
          .update({'profileImageUrl': downloadURL});
    } catch (e) {
      // Handle errors
    } finally {
      setState(() {
        // Hide loading indicator
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Your Profile"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, widget.shouldResetIndex);  // Pop with result
          },
        ),
      ),
      body: loggedInUser == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<DocumentSnapshot>(
          stream: _firestore
              .collection('userinfo')
              .doc(loggedInUser!.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            var userData = snapshot.data!.data() as Map<String, dynamic>;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Center( // Center Column contents
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [


                    // Update CircleAvatar
                Container(
                decoration: BoxDecoration(
                shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.green,
                    width: 10.0, //  border width
                  ),
                ),
                    child: CircleAvatar(
                      radius: 90.0,
                      backgroundImage: userData['profileImageUrl'] != null
                          ? NetworkImage(userData['profileImageUrl'])
                          : null,
                      child: Stack( // Add a Stack to overlay an edit icon
                        children: [
                          const Align(
                            alignment: Alignment.bottomRight,
                            child: Icon(Icons.edit), // Place an edit icon
                          ),
                          // Make it tappable to change the image
                          Positioned.fill(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(90),
                                onTap: _showImagePickerOptions,
                              ),
                            ),
                          ),
                        ], // children
                      ),
                    ),
                ),

                    const SizedBox(height: 20),
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.85,
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                _showEditNameDialog(context, userData['name']);
                              },
                              // Optional: Visual Feedback
                              borderRadius: BorderRadius.circular(25.0),
                              highlightColor: Colors.grey.withOpacity(0.2),
                              splashColor: Colors.purpleAccent.withOpacity(0.3),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(25.0),
                                  border: Border.all(color: Colors.green),
                                ),
                                padding: const EdgeInsets.all(10.0),
                                child: Text(
                                  userData['name'],
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.purple,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.85,
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _showEditEmailDialog(context),
                              borderRadius: BorderRadius.circular(25.0),
                              highlightColor: Colors.grey.withOpacity(0.2),
                              splashColor: Colors.purpleAccent.withOpacity(0.3),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(25.0),
                                  border: Border.all(color: Colors.green),
                                ),
                                padding: const EdgeInsets.all(10.0),
                                child: Text(
                                  userEmail ?? "Email not found",
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),



                    const SizedBox(height: 20),
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.85,
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _showEditAgeDialog(context, userData['age'].toString()),
                              borderRadius: BorderRadius.circular(25.0),
                              highlightColor: Colors.grey.withOpacity(0.2),
                              splashColor: Colors.purpleAccent.withOpacity(0.3),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(25.0),
                                  border: Border.all(color: Colors.grey),
                                ),
                                padding: const EdgeInsets.all(10.0),
                                child: Text('Age:${userData['age']}',
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.purple),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),


                    const SizedBox(height: 20),
                    ElevatedButton(
                      child: const Text('Change Password'),
                      onPressed: () => _showChangePasswordDialog(context),
                    ),
                    const SizedBox(height: 20),
                    const Text('Your Selected Cuisines', style: TextStyle(fontWeight: FontWeight.bold)),

                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: buildCuisineWidgets(userData),
                    ),
                  ],
                ),
              ),
            );
          }),
    );
  }

}
