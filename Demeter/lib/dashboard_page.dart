import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:demeter/profile_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'meal_service.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';

class DashboardPage extends StatefulWidget {
  final String? userId;
  const DashboardPage({super.key, required this.userId});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late PageController _pageController;
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _pantryItems = [];
  bool _isLoading = false;
  int _selectedIndex = 0;
  String? _selectedCuisine;
  String? _selectedCategory;
  List<String> _recommendedRecipeIds = [];
  final List<String> _selectedIngredients = [];
  final List<String> _selectedPantryIngredients = [];
  final _searchController = TextEditingController();

  Future<void> _onItemTapped(int index) async {
    setState(() {
      _selectedIndex = index;
      _pageController.jumpToPage(index); // Update PageView
    });

    if (index == 1) { // Check if the camera button is pressed
      _getImageFromCamera();
    }
    if (index == 2) {
      setState(() {
        _selectedIndex = index;
        _isLoading = true; // Mark as loading
        _fetchPantryItems() // Fetch pantry data
            .then((_) => setState(() =>
        _isLoading = false)); // Reset loading state when done
      });
    }
  }

  Future<void> _getImageFromCamera() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      detectImage(image).then((detectedConcepts) {
        String firstItem = detectedConcepts[0];
        // Show the dialog
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
                title: const Text(
                  "Confirm Item",
                  textAlign: TextAlign.center,
                ),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15.0)),
                backgroundColor: Colors.green[300],
                content: Column(
                  mainAxisSize: MainAxisSize.min, // Content takes minimal space
                  children: [
                    Image.file(File(image.path)),
                    Text("Is this the correct item?: $firstItem"),
                  ],
                ),
                actions: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    // Centers the buttons
                    children: [
                      TextButton(
                        child: const Text('Try Again'),
                        onPressed: () {
                          Navigator.of(context).pop(); // Close dialog
                          _getImageFromCamera(); // Retry
                        },
                      ),
                      TextButton(
                        child: const Text('Add To Pantry'),
                        onPressed: () async {
                          // Get amount and unit
                          final result = await _getAmountDialog(context);

                          if (result != null) {
                            final amount = result['amount'];
                            final unit = result['unit'];
                            FirebaseFirestore.instance
                                .collection('userinfo')
                                .doc(widget.userId)
                                .collection('pantry')
                                .doc(firstItem) // Use first detected item
                                .set({
                              'Amount': amount,
                              'unit': unit,
                              'isPermanent': false, // Explicitly include 'isPermanent'
                            });
                            // ignore: use_build_context_synchronously
                            Navigator.of(context).pop(); // Close dialog
                          }
                        },
                      )
                    ],
                  )
                ]
            );
          },
        );
      }).catchError((error) {
        // ignore: avoid_print
        print('Error: $error');
        // TODO Handle errors
      });
    }
    _pageController.jumpToPage(2);
  }

  Future<List<dynamic>> detectImage(XFile image) async {
    const String microserviceUrl = 'http://34.32.158.171:1935/detect';
    List<int> imageBytes = await image.readAsBytes();
    String base64Image = base64Encode(imageBytes);

    try {
      final response = await http.post(
        Uri.parse(microserviceUrl),
        body: {'image': base64Image},
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        _pageController.jumpToPage(2);
        return jsonData as List<dynamic>; // Expect a list from JSON
      } else {
        _pageController.jumpToPage(2);
        throw Exception('Microservice request failed: ${response.statusCode}');
      }
    } catch (error) {
      // ignore: avoid_print
      print('Error calling microservice: $error');
      _pageController.jumpToPage(2);
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _getAmountDialog(BuildContext context) {
    final amountController = TextEditingController();
    String selectedUnit = 'unit'; // Default unit

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder( // Use StatefulBuilder
          builder: (context, setStateForDialog) {
            return AlertDialog(
              content: Row( // Use a Row for side-by-side layout
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded( // Make the TextField take available space
                    child: TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'Enter Amount'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  DropdownButton<String>(
                    value: selectedUnit,
                    items: const [
                      DropdownMenuItem(value: 'g', child: Text('g')),
                      DropdownMenuItem(value: 'ml', child: Text('ml')),
                      DropdownMenuItem(value: 'oz', child: Text('oz')),
                      DropdownMenuItem(value: 'unit', child: Text('unit')),
                    ],
                    onChanged: (value) {
                      setStateForDialog(() { // Update dialog-specific state
                        selectedUnit = value ?? 'unit';
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(null),
                ),
                TextButton(
                  child: const Text('OK'),
                  onPressed: () {
                    final input = amountController.text;
                    final amount = int.tryParse(input);

                    if (amount != null) {
                      Navigator.of(context).pop({
                        'amount': amount,
                        'unit': selectedUnit
                      });
                    } else {
                      Navigator.of(context).pop(null);
                    }
                  },
                ),
              ],
            );
          }, // End of StatefulBuilder builder
        );
      }, // End of showDialog builder
    ); // End of showDialog
  }
  // Function to check if this is the first login
  Future<bool> _isFirstLogin() async {
    final userDoc = await _firestore.collection('userinfo')
        .doc(widget.userId)
        .get();
    return !userDoc.exists; // Return true if the document doesn't exist
  }

  // Function to display the information input dialog
  void _showFirstTimeInputDialog() async {
    bool allowPop = false; // Flag to control popping
    final nameController = TextEditingController();
    final ageController = TextEditingController();
    Map<String, bool> selectedCuisines = {
      'chinese': false,
      'greek': false,
      'italian': false,
      'mexican': false,
      'indian': false,
      'japanese': false,
      'thai': false,
      'filipino' : false
    };

    // TODO Add more controllers when we add additional profile data

    await showDialog(
        context: context,
        barrierDismissible: false, // Prevent tapping outside to dismiss
        builder: (context) =>
            PopScope(
              canPop: allowPop, // Control popping with the flag
              child: AlertDialog(
                title: const Text('Complete Your Profile'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    TextField(
                      key: const Key('nameField'),
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name', hintText: 'Name'),
                    ),
                    TextField(
                      key: const Key('ageField'),
                      controller: ageController,
                      keyboardType: TextInputType.number,
                      // Enforce numeric input
                      decoration: const InputDecoration(labelText: 'Age', hintText: 'Age'),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ], // Allow only digits
                    ),
                    const Text('Select Preset Cuisine Ingredients:'),
                    StatefulBuilder(
                        builder: (context, setState) {
                          return CheckboxListTile(
                            title: const Text('Chinese'),
                            value: selectedCuisines['chinese'] ?? false,
                            onChanged: (bool? value) => setState(() => selectedCuisines['chinese'] = value!),
                          );
                        }
                    ),
                    StatefulBuilder(
                      builder: (context, setState) {
                        return CheckboxListTile(
                          title: const Text('Greek'),
                          value: selectedCuisines['greek'] ?? false,
                          onChanged: (bool? value) => setState(() => selectedCuisines['greek'] = value!),
                        );
                      },
                    ),
                    StatefulBuilder(
                      builder: (context, setState) {
                        return CheckboxListTile(
                          title: const Text('Indian'),
                          value: selectedCuisines['indian'] ?? false,
                          onChanged: (bool? value) => setState(() => selectedCuisines['indian'] = value!),
                        );
                      },
                    ),
                    StatefulBuilder(
                      builder: (context, setState) {
                        return CheckboxListTile(
                          title: const Text('Italian'),
                          value: selectedCuisines['italian'] ?? false,
                          onChanged: (bool? value) => setState(() => selectedCuisines['italian'] = value!),
                        );
                      },
                    ),
                    StatefulBuilder(
                      builder: (context, setState) {
                        return CheckboxListTile(
                          title: const Text('Japanese'),
                          value: selectedCuisines['japanese'] ?? false,
                          onChanged: (bool? value) => setState(() => selectedCuisines['japanese'] = value!),
                        );
                      },
                    ),
                    StatefulBuilder(
                      builder: (context, setState) {
                        return CheckboxListTile(
                          title: const Text('Mexican'),
                          value: selectedCuisines['mexican'] ?? false,
                          onChanged: (bool? value) => setState(() => selectedCuisines['mexican'] = value!),
                        );
                      },
                    ),
                    StatefulBuilder(
                      builder: (context, setState) {
                        return CheckboxListTile(
                          title: const Text('Thai'),
                          value: selectedCuisines['thai'] ?? false,
                          onChanged: (bool? value) => setState(() => selectedCuisines['thai'] = value!),
                        );
                      },
                    ),
                    StatefulBuilder(
                        builder: (context, setState) {
                          return CheckboxListTile(
                            title: const Text('Filipino'),
                            value: selectedCuisines['filipino'] ?? false,
                            onChanged: (bool? value) => setState(() => selectedCuisines['filipino'] = value!),
                          );
                        }
                    ),

                    // TODO Collect other profile data
                  ],
                      ),
                ),

                actions: <Widget>[
                  TextButton(
                    child: const Text('Next'),
                    onPressed: () async {
                      if (nameController.text.isEmpty ||
                          !RegExp(r'^[a-zA-Z ]+$').hasMatch(
                              nameController.text)) {
                        showDialog(
                            context: context,
                            builder: (context) =>
                                AlertDialog(
                                  content: const Text(
                                      "Please only user alphabetical characters"),
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text("OK")
                                    )
                                  ],
                                ));
                        return;
                      }
                      // Age Validation
                      int? age = int.tryParse(ageController.text);
                      if (age == null || age < 1 || age > 122) {
                        showDialog(
                            context: context,
                            builder: (context) =>
                                AlertDialog(
                                  content: const Text(
                                      "Please enter a valid age between 1 and 122."),
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text("OK")
                                    )
                                  ],
                                ));
                        return; // Don't proceed if the age is invalid
                      }
                    await _firestore.collection('userinfo').doc(widget.userId).set({
                    'name': nameController.text,
                    'age': age,
                    'cuisines': selectedCuisines // Add cuisines data
                    });

                  await _syncPantryWithCuisines();

                // Close the dialog
            allowPop = true;
                      // ignore: use_build_context_synchronously
            Navigator.of(context).pop();
          },
        ),
      ],
    ),
            ),
    );
  }

  Future<void> _syncPantryWithCuisines() async {
    final userDoc = await _firestore.collection('userinfo').doc(widget.userId).get();
    final selectedCuisines = userDoc.data()!['cuisines'] as Map<String, dynamic>;
    final permanentIngredientsQuery = await _firestore.collection('permanentIngredients').get();

    for (final cuisineDoc in permanentIngredientsQuery.docs) {
      if (selectedCuisines[cuisineDoc.id] == true) { // Check if cuisine is selected
        final cuisineIngredients = cuisineDoc.data();
        for (final ingredient in cuisineIngredients.entries) {
          if (ingredient.value) {
            // Add the ingredient to the user's pantry
            await _firestore
                .collection('userinfo')
                .doc(widget.userId)
                .collection('pantry')
                .doc(ingredient.key)
                .set({'isPermanent': true});
          }
        }
      }
    }
  }

  Future<void> _fetchPantryItems() async {
    final itemsSnapshot = await _firestore
        .collection('userinfo')
        .doc(widget.userId)
        .collection('pantry')
        .get();

    final pantryItems = itemsSnapshot.docs.map((doc) =>
    {
      'id': doc.id,
      'amount': doc.data()['Amount'],
      'unit': doc.data()['unit'],
      'isPermanent': doc.data()['isPermanent'] ?? false,
    }).toList();

    setState(() {
      _pantryItems = pantryItems;
    });
  }

  void _showEditDialog(String itemId, int currentAmount) async {
    final amountController = TextEditingController(
        text: currentAmount.toString());

    await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Enter New Amount'),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Update'),
              onPressed: () async {
                final input = amountController.text;
                final newAmount = int.tryParse(input);

                if (newAmount != null) {
                  await _firestore
                      .collection('userinfo')
                      .doc(widget.userId)
                      .collection('pantry')
                      .doc(itemId)
                      .update({'Amount': newAmount});
                  _fetchPantryItems(); // Refresh the pantry data
                  // ignore: use_build_context_synchronously
                  Navigator.of(context).pop();
                } else {
                  // Show error if amount is not valid
                  // TODO can add more sophisticated error handling
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(String itemId) async {
    bool shouldDelete = await showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('Confirm Delete'),
            content: const Text('Are you sure you want to delete this item?'),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              TextButton(
                child: const Text('Delete'),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
    ) ?? false; // ?? false handles the case if the user dismisses the dialog

    if (shouldDelete) {
      await _firestore
          .collection('userinfo')
          .doc(widget.userId)
          .collection('pantry')
          .doc(itemId)
          .delete();
      _fetchPantryItems(); // Refresh pantry
    }
  }

  void _showRecipePopup(dynamic mealData) async{
    final String userId = FirebaseAuth.instance.currentUser!.uid;
    bool isFavourited = await _isFavourite(mealData['idMeal'], userId);
    showDialog(
      // ignore: use_build_context_synchronously
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.green[300],
          title: Text(mealData['strMeal']),
          content: SizedBox( // Constrain AlertDialog height
            height: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.network(mealData['strMealThumb']),
                  const SizedBox(height: 10),
                  const Text(
                    'Cuisine:', style: TextStyle(fontWeight: FontWeight.bold),),
                  Text(mealData['strArea']),
                  const SizedBox(height: 5),
                  const Text('Meal Category:',
                    style: TextStyle(fontWeight: FontWeight.bold),),
                  Text(mealData['strCategory']),
                  const SizedBox(height: 5),
                  const Text('Ingredients:',
                    style: TextStyle(fontWeight: FontWeight.bold),),
                  for (int i = 1; i <= 20; i++)
                    if (mealData['strIngredient$i'] != null &&
                        mealData['strIngredient$i'] != '')
                      Text(
                          '${mealData['strMeasure$i']} ${mealData['strIngredient$i']}'
                      ),
                  const SizedBox(height: 10),
                  const Text('Instructions:',
                    style: TextStyle(fontWeight: FontWeight.bold),),
                  for (int i = 0; i < mealData['strInstructions']
                      .split(".")
                      .length; i++)
                    Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                            "${i + 1}. ${mealData['strInstructions'].split(
                                ".")[i].trim()}.")
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Use This Recipe'),
              onPressed: () => _useRecipe(mealData, userId),
            ),
            TextButton(
                child: const Text('Close'),
                onPressed: () => Navigator.of(context).pop()
            ),
            StatefulBuilder(
              builder: (context, setState) {
                return IconButton(
                  icon: Icon(
                    isFavourited ? Icons.favorite : Icons.favorite_border_outlined,
                    color: isFavourited ? Colors.red : Colors.grey,
                  ),
                  onPressed: () async {
                    if (isFavourited) {
                      await _removeFromFavourites(mealData['idMeal'], userId).then((_) {
                        setState(() {
                          isFavourited = !isFavourited;
                        });
                      });
                    } else {
                      await _addToFavourites(mealData, userId).then((_) {
                        setState(() {
                          isFavourited = !isFavourited;
                        });
                      });
                    }
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _useRecipe(dynamic mealData, String userId) async {
    // 1. Get pantry ingredients
    final pantrySnapshot = await FirebaseFirestore.instance
        .collection('userinfo')
        .doc(userId)
        .collection('pantry')
        .get();
    final pantryIngredients = pantrySnapshot.docs.map((doc) => doc.data()).toList();

    final missingIngredients = <String>[];

    // 2. Iterate through recipe ingredients (Collect missing ingredients)
    for (int i = 1; i <= 20; i++) {
      String ingredient = mealData['strIngredient$i'].toLowerCase(); // Convert to lowercase

      if (ingredient != '') {
        // Check if the ingredient document exists in the pantry (case-insensitive)
        final ingredientDoc = await FirebaseFirestore.instance
            .collection('userinfo')
            .doc(userId)
            .collection('pantry')
            .doc(ingredient.toLowerCase()) // Fetch with lowercase name
            .get();

        bool ingredientExists = ingredientDoc.exists;

        if (!ingredientExists) {
          missingIngredients.add(ingredient); // Add the original ingredient name
        }
      }
    }



    // 3. Show dialog for missing ingredients (if any)
    if (missingIngredients.isNotEmpty) {
      final continueAnyways = await _showMissingIngredientsDialog(missingIngredients);
      if (!continueAnyways) {
        return;
      }
    }

    // 4. Update Firestore (only if the user chose to continue)
    for (int i = 1; i <= 20; i++) {
      String ingredient = mealData['strIngredient$i'];
      String measure = mealData['strMeasure$i'];

      if (ingredient != '') {
        final matchingIngredient = pantryIngredients.firstWhere(
              (pantryItem) => pantryItem['name'] == ingredient,
          orElse: () => {'isPermanent': false},
        );

        if (!matchingIngredient['isPermanent']) {
          // Check for matching unit
          String pantryUnit = matchingIngredient['unit'] ?? '';
          if (measure.endsWith(pantryUnit)) { // Units must match

            // Subtract amount from pantry
            int pantryAmount = matchingIngredient['Amount'] ?? 0;
            int recipeAmount = int.tryParse(measure.split(' ')[0]) ?? 0;

            // Calculate potential new amount
            int newAmount = pantryAmount - recipeAmount;

            if (newAmount <= 0) {
              // Delete the document
              FirebaseFirestore.instance
                  .collection('userinfo')
                  .doc(userId)
                  .collection('pantry')
                  .doc(ingredient)
                  .delete();
            } else {
              // Update with the new calculated amount
              FirebaseFirestore.instance
                  .collection('userinfo')
                  .doc(userId)
                  .collection('pantry')
                  .doc(ingredient)
                  .update({
                'Amount': newAmount
              });
            }
          } else {
            // TODO: Handle mismatched units maybe show an alert
          }
        }
      }
    }

    // ignore: use_build_context_synchronously
    Navigator.of(context).pop(); // Close the recipe popup
  }

  Future<bool> _showMissingIngredientsDialog(List<String> missingIngredients) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Missing Ingredients'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('The following ingredients are not found in your pantry:'),
            const SizedBox(height: 5),
            ...missingIngredients.map((ingredient) => Text('- $ingredient')),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: const Text('Continue Anyways'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<bool> _isFavourite(String recipeId, String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('userinfo')
        .doc(userId)
        .collection('favourites')
        .doc(recipeId)
        .get();

    return snapshot.exists ;  // Return 'false' if snapshot.exists is null
  }

  Future<void> _addToFavourites(dynamic mealData, String userId) async {
    try {
      // Create a filtered copy of mealData
      Map<String, dynamic> filteredMealData = Map.from(mealData);

      // Remove specific keys
      filteredMealData.remove('strInstructions');
      filteredMealData.remove('strSource');
      filteredMealData.remove('strYoutube');
      filteredMealData.remove('dateModified');
      filteredMealData.remove('strDrinkAlternate');
      filteredMealData.remove('strImageSource');
      filteredMealData.remove('strTags');
      filteredMealData.remove('strCreativeCommonsConfirmed');

      // Remove strMeasure keys
      for (int i = 1; i <= 20; i++) {
        filteredMealData.remove('strMeasure$i');
        if (filteredMealData['strIngredient$i'] == null ||
            filteredMealData['strIngredient$i'] == '') {
          filteredMealData.remove('strIngredient$i');
        }
      }

      await FirebaseFirestore.instance
          .collection('userinfo')
          .doc(userId)
          .collection('favourites')
          .doc(mealData['idMeal'])
          .set(filteredMealData);
    } catch (e) {
      // ignore: avoid_print
      print('Error adding to favourites: $e');
    }
  }

  Future<void> _removeFromFavourites(String recipeId, String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('userinfo')
          .doc(userId)
          .collection('favourites')
          .doc(recipeId)
          .delete();
    } catch(e) {
      // ignore: avoid_print
      print('Error removing from favourites: $e');
    }
  }

  Future<String> _fetchUserName() async {
    try {
      final userDoc = await _firestore.collection('userinfo')
          .doc(widget.userId)
          .get();

      if (userDoc.exists) {
        return userDoc.data()!['name'] as String;
      } else {
        return 'User';  // Default if name is not found (shouldnt happen)
      }
    } catch (error) {
      // ignore: avoid_print
      print('Error fetching name: $error');
      return 'User';
    }
  }

  @override
  void initState() {
    super.initState();
    _isFirstLogin().then((isFirstLogin) {
      if (isFirstLogin) {
        _showFirstTimeInputDialog();
      }
    });
    _fetchRecommendedMeals();
    _fetchPantryItems();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildRecommendationsBar() {
    if (_isLoading) {
      return const Center(
          child: SizedBox(
              height: 100,
              child: CircularProgressIndicator()
          )
      );
    } else if (_recommendedRecipeIds.isEmpty) {
      return const SizedBox(
          height: 100,
          child: Center(
              child: Text('Something went wrong fetching recommendations.')
          )
      );
    } else {
      return Container(
        height: 200,
        color: Colors.green[300],
        child: Column( // Use Column to arrange children vertically
          children: [
            // Child 1: Title and Refresh Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const Text(
                  'Meal Recommendations',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => _fetchRecommendedMeals(),
                ),
              ], // Closing Row
            ),
            // Child 2: Horizontal Scrolling Recommendations
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: fetchMealDetails(_recommendedRecipeIds), // Fetch details
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: snapshot.data!.length, // Use snapshot.data
                      itemBuilder: (context, index) {
                        var mealData = snapshot.data![index];
                        return InkWell(
                          onTap: () => _showRecipePopup(mealData),
                          child: Container(
                            width: 120,
                            margin: const EdgeInsets.only(right: 5),
                            child: Card(
                              color: Colors.purpleAccent[100],
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Image.network(
                                      mealData['strMealThumb'],
                                      height: 100,
                                      width: 1200,
                                      fit: BoxFit.cover
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    mealData['strMeal'],
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  } else if (snapshot.hasError) {
                    return const Center(child: Text('Error fetching details'));
                  } else {
                    return const Center(child: CircularProgressIndicator());
                  }
                }, // Closing FutureBuilder
              ),
            ),
          ], // Closing Column
        ),
      );
    } // Closing _buildRecommendationsBar
  }

  Future<List> _fetchRecommendedMeals() async {
    final String userId = FirebaseAuth.instance.currentUser!.uid; // Get user ID

    setState(() {
      _isLoading = true; // State update to show loading
    });

    try {
      // 1. Get Firebase references
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final userRef = firestore.collection('userinfo').doc(userId);
      final favouritesRef = userRef.collection('favourites');

      // 2. Fetch favourited recipes
      final favoritesSnapshot = await favouritesRef.get();
      final formattedRecipes = favoritesSnapshot.docs.map((doc) {
        final data = doc.data();  // Get the recipe data

        final ingredients = [for (int i = 1; i <= 20; i++) if (data['strIngredient$i'] != null) data['strIngredient$i']];

        return {
          'idMeal': data['idMeal'],
          'strMeal': data['strMeal'],
          'ingredients': ingredients
        };
      }).toList();

      // 3. Check for Empty Favorites and Fetch From MealDB if Needed
      if (formattedRecipes.isEmpty) {
        // Fetch random meals from MealDB
        const randomMealsUrl = 'https://www.themealdb.com/api/json/v2/9973533/randomselection.php';
        final response = await http.get(Uri.parse(randomMealsUrl));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final meals = data['meals'] as List<dynamic>;

          final List randomMealIds = meals
              .map((meal) => meal['idMeal'])
              .take(5) // Take the first 5 meal IDs
              .toList();

          setState(() {
            _isLoading = false;
            _recommendedRecipeIds = randomMealIds.cast<String>();
          });

          return randomMealIds;
        } else {
          throw Exception('MealDB API request failed: ${response.statusCode}');
        }
      } else {
        // 4. Call microservice (if favourites exist)
        final payload = {'recipes': formattedRecipes};

        const microserviceUrl = 'http://34.32.158.171:1935/fetch_recommendations';
        final response = await http.post(
          Uri.parse(microserviceUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final recommendationsList = data['recommendations'] as List<dynamic>;

          final List allRecommendedIds = recommendationsList
              .expand((recipeRecommendations) => recipeRecommendations.cast<String>())
              .toList();

          setState(() {
            _isLoading = false;
            _recommendedRecipeIds =  allRecommendedIds.cast<String>();
          });

          return allRecommendedIds;
        } else {
          throw Exception('Microservice request failed: ${response.statusCode}');
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      throw Exception('Failed to fetch recommendations: $e');
    }
  }


  Future<List<dynamic>> fetchMealDetails(List<String> recipeIds) async {
    final mealService = MealService();
    List<dynamic> mealDetails = [];

    for (String recipeId in recipeIds) {
      try {
        final meal = await mealService.fetchMealDetails(recipeId);
        mealDetails.add(meal);
      } catch (e) {
        // ignore: avoid_print
        print('Error fetching meal: $e');
      }
    }
    return mealDetails;
  }

  Widget _buildFavouritesBar() {
    final String userId = FirebaseAuth.instance.currentUser!.uid; // Get user ID
    return FutureBuilder<List<dynamic>>( // Use FutureBuilder
        future: _fetchFavourites(userId), // Pass in the userId
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: SizedBox(height: 100, child: CircularProgressIndicator()));
          } else if (snapshot.hasError) {
            return const SizedBox(height: 100, child: Center(child: Text('Error fetching favorites.')));
          } else if (snapshot.hasData && snapshot.data!.isEmpty) {
            return const SizedBox(height: 100, child: Center(child: Text('You have no favorites yet!')));
          } else {
            final favourites = snapshot.data!; // Access favorites data
            return Container(
            height: 200,
              color: Colors.green[300],
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Favourites',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center
                      ),
                      // TODO Remove refresh button or add functionality to refetch favorites
                    ],
                  ),
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: favourites.length,
                    itemBuilder: (context, index) {
                      var favoriteData = favourites[index]; // Get the favorite map

                      return InkWell(
                        onTap: () async {
                          final response = await http.get(Uri.parse('https://www.themealdb.com/api/json/v2/9973533/lookup.php?i=${favoriteData['mealID']}'));

                          if (response.statusCode == 200) {
                            final mealData = jsonDecode(response.body)['meals'][0]; // Parse the response
                            _showRecipePopup(mealData);
                          } else {
                            // TODO Handle error case (show a message)
                          }
                        },
                        child: Container(
                          width: 120,
                          margin: const EdgeInsets.only(right: 5),
                          child: Card(
                            color: Colors.purpleAccent[100],
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Image.network(
                                    favoriteData['strMealThumb'] ?? 'https://placeholder.com/120x100', // placeholder
                                    height: 100,
                                    width: 1200,
                                    fit: BoxFit.cover
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  favoriteData['strMeal'] ?? 'Unknown Meal',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                ),
                ),
                ],
            ),
          );
        }
      }
    );
  }

  Future<List<dynamic>> _fetchFavourites(String userId) async {
    final favouritesRef = FirebaseFirestore.instance
        .collection('userinfo')
        .doc(userId)
        .collection('favourites');
    final snapshot = await favouritesRef.get();

    return snapshot.docs.map((doc) => {
      'mealID': doc.id,
      ...doc.data(), // Spread the existing mealName
    }).toList();
  }

  Widget _buildFilterCard(String title, VoidCallback onPressed, String imageName) {
    return Card(
      color: Colors.green[300],
      child: InkWell(
        onTap: onPressed,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/$imageName',
              height: 120,
            ),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 16), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  void _showCuisineDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder( // Wrap AlertDialog with StatefulBuilder
          builder: (context, setState) => AlertDialog( // Use setState from StatefulBuilder
            backgroundColor: Colors.green[300],
              title: const Text('Select Cuisine'),
              content: SizedBox(
                height: 300,
                width: 300,
                child: FutureBuilder<List<String>>(
                  future: _fetchCuisines(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return ListView.builder(
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          final cuisine = snapshot.data![index];
                          return RadioListTile<String>(
                            title: Text(cuisine),
                            value: cuisine,
                            groupValue: _selectedCuisine,
                            onChanged: (String? value) {
                              setState(() { // Rebuild to update selection
                                _selectedCuisine = value;
                              });
                              setState((){});
                            },
                          );
                        },
                      );
                    } else if (snapshot.hasError) {
                      return const Center(child: Text("Error fetching cuisines."));
                    } else {
                      return const Center(child: CircularProgressIndicator());
                    }
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: _selectedCuisine == null
                ? null // Disable if no cuisine is selected
                : () => _showRecipesDialog(_selectedCuisine!),
            child: const Text('Submit'),
          ),
        ],
      ),
    ),
    );
  }

  void _showCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder( // Wrap AlertDialog with StatefulBuilder
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.green[300],
          title: const Text('Select Category'),
          content: SizedBox(
            height: 300,
            width: 300,
            child: FutureBuilder<List<String>>(
              future: _fetchCategories(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final category = snapshot.data![index];
                      return RadioListTile<String>(
                        title: Text(category),
                        value: category,
                        groupValue: _selectedCategory,
                        onChanged: (String? value) {
                          setState(() {
                            _selectedCategory = value;
                          });
                          setState((){});
                        },
                      );
                    },
                  );
                } else if (snapshot.hasError) {
                  return const Center(child: Text("Error fetching category."));
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: _selectedCategory == null
                  ? null // Disable if no cuisine is selected
                  : () => _showCatRecipesDialog(_selectedCategory!),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  void _showIngredientsDialog() {
    List<String> allIngredients = []; // Stores all ingredients
    List<String> filteredIngredients = []; // Stores filtered ingredients based on search

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          // Load and set initial ingredients list inside StatefulBuilder (only once)
          if (allIngredients.isEmpty) { // Check if ingredients haven't been loaded yet
            _fetchIngredients().then((ingredients) {
              setState(() {
                allIngredients = ingredients;
                filteredIngredients = ingredients;
              });
            });
          }

          return AlertDialog(
            backgroundColor: Colors.green[300],
            title: Column( // Add a column for search field
              children: [
                const Text('Select Ingredient(s)'),
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(hintText: 'Search...'),
                  onChanged: (text) {
                    setState(() {
                      filteredIngredients = allIngredients.where((ingredient) =>
                          ingredient.toLowerCase().contains(text.toLowerCase())
                      ).toList();
                    });
                  },
                ),
              ],
            ),
            content: SizedBox(
                height: 300,
                width: 300,
                child: filteredIngredients.isNotEmpty
                    ? ListView.builder( // Use filtered ingredients list
                    itemCount: filteredIngredients.length,
                    itemBuilder: (context, index) {
                      final ingredient = filteredIngredients[index];
                      return CheckboxListTile(
                        title: Text(ingredient),
                        value: _selectedIngredients.contains(ingredient),
                        onChanged: (value) {
                          setState(() {
                            if (value!) {
                              _selectedIngredients.add(ingredient);
                            } else {
                              _selectedIngredients.remove(ingredient);
                            }
                          });
                        },
                      );
                    })
                    : const Center(child: Text('No ingredients found.')) // Display message if search yields no results
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: _selectedIngredients.isEmpty
              ? null // Disable if no ingredients are selected
              : () => _showIngredientRecipesDialog(_selectedIngredients),
                child: const Text('Submit'),
              ),

            ],
          );
        },
      ),
    );
  }

  void _showAddIngredientsDialog() {
    // Introduce variables for search
    List<String> allIngredients = []; // Stores all ingredients
    List<String> filteredIngredients = []; // Stores filtered ingredients based on search

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          // Load and set initial ingredients list inside StatefulBuilder (only once)
          if (allIngredients.isEmpty) { // Check if ingredients haven't been loaded yet
            _fetchIngredients().then((ingredients) {
              setState(() {
                allIngredients = ingredients;
                filteredIngredients = ingredients;
              });
            });
          }

          return AlertDialog(
            backgroundColor: Colors.green[300],
            title: Column( // Add a column for search field
              children: [
                const Text('Select Ingredient(s)'),
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(hintText: 'Search...'),
                  onChanged: (text) {
                    setState(() {
                      filteredIngredients = allIngredients.where((ingredient) =>
                          ingredient.toLowerCase().contains(text.toLowerCase())
                      ).toList();
                    });
                  },
                ),
              ],
            ),
            content: SizedBox(
                height: 300,
                width: 300,
                child: filteredIngredients.isNotEmpty
                    ? ListView.builder( // Use filtered ingredients list
                    itemCount: filteredIngredients.length,
                    itemBuilder: (context, index) {
                      final ingredient = filteredIngredients[index];
                      return CheckboxListTile(
                        title: Text(ingredient),
                        value: _selectedIngredients.contains(ingredient),
                        onChanged: (value) {
                          setState(() {
                            if (value!) {
                              _selectedIngredients.add(ingredient);
                            } else {
                              _selectedIngredients.remove(ingredient);
                            }
                          });
                        },
                      );
                    })
                    : const Center(child: Text('No ingredients found.')) // Display message if search yields no results
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: _selectedIngredients.isEmpty
                    ? null // Disable if no ingredients are selected
                    : () => _showIngredientAmountsDialog(_selectedIngredients),
                child: const Text('Submit'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showIngredientAmountsDialog(List<String> selectedIngredients) {
    final Map<String, TextEditingController> amountControllers = {};
    final Map<String, String> selectedUnits = {};

    for (var ingredient in selectedIngredients) {
      amountControllers[ingredient] = TextEditingController();
      selectedUnits[ingredient] = 'unit'; // Default unit
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateForDialog) {
          return AlertDialog(
            backgroundColor: Colors.green[300],
            title: const Text('Enter Amounts'),
            content: SizedBox(
              height: 300,
              width: 300,
              child: ListView.builder(
                itemCount: selectedIngredients.length,
                itemBuilder: (context, index) {
                  final ingredient = selectedIngredients[index];
                  return Row(
                    children: [
                      Expanded(child: Text(ingredient)),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          keyboardType: TextInputType.number,
                          controller: amountControllers[ingredient],
                        ),
                      ),
                      const SizedBox(width: 10),
                      DropdownButton<String>(
                        value: selectedUnits[ingredient],
                        items: const [
                          DropdownMenuItem(value: 'g', child: Text('g')),
                          DropdownMenuItem(value: 'ml', child: Text('ml')),
                          DropdownMenuItem(value: 'oz', child: Text('oz')),
                          DropdownMenuItem(value: 'unit', child: Text('unit')),
                        ],
                        onChanged: (value) {
                          setStateForDialog(() { //  Use the dialog's setState
                            selectedUnits[ingredient] = value ?? 'unit';
                          });
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel')
              ),
              TextButton(
                onPressed: () => _submitIngredientsToFirestore(amountControllers, selectedIngredients, selectedUnits),
                child: const Text('Submit'),
              ),
            ],
          );
        },
      ),
    ); // End of showDialog
  }

  void _submitIngredientsToFirestore(Map<String, TextEditingController> amountControllers, List<String> selectedIngredients, Map<String, String> selectedUnits) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    for (var entry in amountControllers.entries) {
      String id = entry.key; // Get the ingredient name
      int amount = int.tryParse(entry.value.text) ?? 0; // Input validation
      bool isPermanent = false; // Assuming false by default

      if (amount > 0) {
        // Add to Firestore
        FirebaseFirestore.instance
            .collection('userinfo')
            .doc(userId)
            .collection('pantry')
            .doc(id)
            .set({
          'Amount': amount,
          'unit': selectedUnits[id], // Store the selected unit directly
          'isPermanent': isPermanent,
        });
      }
    }

    // Close the dialogs
    Navigator.of(context).pop();
    Navigator.of(context).pop();
  }

  void _showPantryIngredientsDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.green[300],
          title: const Text('Select Pantry Ingredient(s)'),
          content: SizedBox(
            height: 300,
            width: 300,
            child: FutureBuilder<List<String>>(
              future: _fetchPantryIngredients(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final pantryingredient = snapshot.data![index];
                      return CheckboxListTile( // Use CheckboxListTile for multiple selection
                        title: Text(pantryingredient),
                        value: _selectedPantryIngredients.contains(pantryingredient), // Check existing selection
                        onChanged: (bool? value) {
                          setState(() {
                            if (value!) {
                              _selectedPantryIngredients.add(pantryingredient);
                            } else {
                              _selectedPantryIngredients.remove(pantryingredient);
                            }
                          });
                        },
                      );
                    },
                  );
                } else if (snapshot.hasError) {
                  return const Center(child: Text("Error fetching category."));
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: _selectedPantryIngredients.isEmpty
                  ? null // Disable if no ingredients are selected
                  : () => _showIngredientRecipesDialog(_selectedPantryIngredients),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRecipesDialog(String filter) {
    Navigator.of(context).pop(); // Close the cuisine dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.green[300],
        title: Text('Recipes from $filter'),
      content: SizedBox(
        height: 300,
        width: 300,
        child: FutureBuilder<List<dynamic>>(
          future: fetchRecipes(filter),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final recipe = snapshot.data![index];
                  return ListTile(
                    title: Text(recipe['strMeal']),
                    onTap: () => _fetchAndShowRecipeDetails(recipe['idMeal']),
                  );
                },
              );
            } else if (snapshot.hasError) {
              return const Center(child: Text("Error fetching recipes."));
            } else {
              return const Center(child: CircularProgressIndicator());
            }
          },
        ),
      ),
    ),
    );
  }

  void _showCatRecipesDialog(String filter) {
    Navigator.of(context).pop(); // Close the cuisine dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.green[300],
        title: Text('Recipes from $filter'),
        content: SizedBox(
          height: 300,
          width: 300,
          child: FutureBuilder<List<dynamic>>(
            future: _fetchCatRecipes(filter),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final recipe = snapshot.data![index];
                    return ListTile(
                      title: Text(recipe['strMeal']),
                      onTap: () => _fetchAndShowRecipeDetails(recipe['idMeal']),
                    );
                  },
                );
              } else if (snapshot.hasError) {
                return const Center(child: Text("Error fetching recipes."));
              } else {
                return const Center(child: CircularProgressIndicator());
              }
            },
          ),
        ),
      ),
    );
  }

  void _showIngredientRecipesDialog(List<String> filter) {
    Navigator.of(context).pop(); // Close the cuisine dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.green[300],
        title: const Text('Recipes from Selected Filters'),
        content: SizedBox(
          height: 300,
          width: 300,
          child: FutureBuilder<List<dynamic>>(
            future: _fetchIngredRecipes(filter),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final recipe = snapshot.data![index];
                    return ListTile(
                      title: Text(recipe['strMeal']),
                      onTap: () => _fetchAndShowRecipeDetails(recipe['idMeal']),
                    );
                  },
                );
              } else if (snapshot.hasError) {
                return const Center(child: Text("Error fetching recipes."));
              } else {
                return const Center(child: CircularProgressIndicator());
              }
            },
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Close'),
            onPressed: () => Navigator.pop(context),
          ),
        ], // Close the 'actions' list
      ),
    );
  }

  Future<List> fetchRecipes(String cuisine) async {
    final apiUrl ='https://www.themealdb.com/api/json/v2/9973533/filter.php?a=$cuisine';
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return jsonData['meals'] as List;
      } else {
        throw Exception('Failed to fetch recipes');
      }
    } catch (error) {
      // ignore: avoid_print
      print('Error fetching recipes: $error');
      return [];
    }
  }

  Future<List> _fetchCatRecipes(String category) async {
    final apiUrl ='https://www.themealdb.com/api/json/v2/9973533/filter.php?c=$category';
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return jsonData['meals'] as List;
      } else {
        throw Exception('Failed to fetch recipes');
      }
    } catch (error) {
      // ignore: avoid_print
      print('Error fetching recipes: $error');
      return [];
    }
  }

  Future<List> _fetchIngredRecipes(List<String> ingredients) async {
    // Build the comma-separated ingredient list for the URL
    final ingredientsQuery = ingredients.join(',');

    final apiUrl ='https://www.themealdb.com/api/json/v2/9973533/filter.php?i=$ingredientsQuery';

    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return jsonData['meals'] as List;
      } else {
        throw Exception('Failed to fetch recipes');
      }
    } catch (error) {
      // ignore: avoid_print
      print('Error fetching recipes: $error');
      return [];
    }
  }

  Future<List<String>> _fetchCuisines() async {
    try {
      final response = await http.get(Uri.parse('https://www.themealdb.com/api/json/v2/9973533/list.php?a=list'));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final cuisines = (jsonData['meals'] as List)
            .map((meal) => meal['strArea'] as String)
            .toList();
        return cuisines;
      } else {
        throw Exception('Failed to fetch cuisines (Status Code: ${response.statusCode})');
      }
    } catch (error) {
      // ignore: avoid_print
      print('Error fetching cuisines: $error');
      return [];
    }
  }

  Future<List<String>> _fetchCategories() async {
    try {
      final response = await http.get(Uri.parse('https://www.themealdb.com/api/json/v2/9973533/list.php?c=list'));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final cuisines = (jsonData['meals'] as List)
            .map((meal) => meal['strCategory'] as String)
            .toList();
        return cuisines;
      } else {
        throw Exception('Failed to fetch categories (Status Code: ${response.statusCode})');
      }
    } catch (error) {
      // ignore: avoid_print
      print('Error categories: $error');
      return [];
    }
  }

  Future<List<String>> _fetchIngredients() async {
    try {
      final response = await http.get(Uri.parse('https://www.themealdb.com/api/json/v2/9973533/list.php?i=list'));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final ingredients = (jsonData['meals'] as List)
            .map((meal) => meal['strIngredient'] as String)
            .toList();

        // Sort the ingredients alphabetically
        ingredients.sort();

        return ingredients;
      } else {
        throw Exception('Failed to fetch categories (Status Code: ${response.statusCode})');
      }
    } catch (error) {
      // ignore: avoid_print
      print('Error categories: $error');
      return []; // Return empty list on error
    }
  }

  Future<List<String>> _fetchPantryIngredients() async {
    try {
      // Get the current user's UUID
      final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

      // Build the Firestore reference
      final pantryRef = FirebaseFirestore.instance
          .collection('userinfo')
          .doc(currentUserId)
          .collection('pantry');

      // Fetch the pantry ingredients
      final pantrySnapshot = await pantryRef.get();

      // Extract ingredients into a list
      final ingredients = pantrySnapshot.docs
          .map((doc) => doc.id) // The document ID is the ingredient name
          .toList();

      // Sort alphabetically
      ingredients.sort();

      return ingredients;
    } catch (error) {
      // ignore: avoid_print
      print('Error fetching pantry ingredients: $error');
      return []; // Return empty list on error
    }
  }

  Future<void> _fetchAndShowRecipeDetails(String idMeal) async {
    final apiUrl = 'https://www.themealdb.com/api/json/v2/9973533/lookup.php?i=$idMeal';
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final recipeDetails = jsonData['meals'][0]; // Get the first meal
        // ignore: use_build_context_synchronously
        Navigator.of(context).pop(); // Close the recipes dialog
        _showRecipePopup(recipeDetails);
      } else {
        // TODO Handle error - Show error message in recipes dialog
      }
    } catch (error) {
      // ignore: avoid_print
      print('Error fetching recipe details: $error');
      // TODO Handle error - Show error message in recipes dialog
    }
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;

    final words = text.split(" ");
    final capitalizedWords = words.map((word) {
      if (word.isNotEmpty) {
        return word[0].toUpperCase() + word.substring(1);
      } else {
        return '';
      }
    });
    return capitalizedWords.join(" ");
  }

  Widget _buildFloatingActionButton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center, // Center horizontally
      children: [
        const Spacer(),
        FloatingActionButton(
          heroTag: "addIngredient",
          child: const Icon(Icons.add),
          onPressed: () => _showAddIngredientsDialog(),
        ),
        const SizedBox(width: 5), // Add spacing between the buttons
        FloatingActionButton(
          heroTag: "barcodeScan",
          child: const Icon(Icons.qr_code_scanner),
          onPressed: () => _showBarcodeScanner(),
        ),
        const Spacer(),
      ],
    );
  }

  void _showBarcodeScanner() async {
    String barcodeScanResult = await FlutterBarcodeScanner.scanBarcode(
      "#ff6666",
      "Cancel",
      true, // Android: Require flash
      ScanMode.BARCODE,
    );

    if (barcodeScanResult != '-1') { // Ensure a valid scan
      _fetchProductDataFromOpenFoodFacts(barcodeScanResult);
    }
  }

  void _fetchProductDataFromOpenFoodFacts(String barcode) async {
    final apiUrl = 'https://world.openfoodfacts.net/api/v2/product/$barcode?fields=product_name,product_quantity,product_quantity_unit';

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final productData = jsonDecode(response.body);
        _showProductConfirmationDialog(productData);
      } else {
        // ignore: use_build_context_synchronously
        _showAlertDialog(context, 'Product not found, try again');
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      _showAlertDialog(context, 'Error fetching product data, try again');
    }
  }

// Helper function to show alert dialog
  void _showAlertDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }


  void _showProductConfirmationDialog(Map<String, dynamic> productData)  {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final String productName = productData['product']['product_name'] ?? 'Unknown Product';
    final String productQuantity = productData['product']['product_quantity'] ?? '';
    final String productQuantityUnit = productData['product']['product_quantity_unit'] ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Product"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Product: $productName'),
            if (productQuantity.isNotEmpty) ...[
              Text('Quantity: $productQuantity $productQuantityUnit'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Update Firestore
              final quantity = int.tryParse(productQuantity) ?? 1; // Parse if possible
              final String quantityUnit = parseUnit(productQuantityUnit);
              FirebaseFirestore.instance
                  .collection('userinfo')
                  .doc(userId)
                  .collection('pantry')
                  .doc(productName)
                  .set({
                'Amount': quantity,
                'unit': quantityUnit,
                'isPermanent': false
              });
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  String parseUnit(String productQuantityUnit) {
    switch (productQuantityUnit.toLowerCase()) {
      case 'kg':
      case 'kilogram': return 'kg';
      case 'g':
      case 'gram': return 'g';
      case 'ml':
      case 'milliliter': return 'ml';
      case 'l':
      case 'liter': return 'L';
    // TODO Add more cases if needed
      default: return "unit"; // Fallback to the original unit
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: FutureBuilder<String>(
          future: _fetchUserName(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/logo.png', height: 40), // logo
                  const SizedBox(width: 10), // Spacing between logo and text
                  Text('Hi ${snapshot.data!}, let\'s cook!'),
                ],
              );
            } else {
              return const Center(child: CircularProgressIndicator());
            }
          },
        ),
        actions: [
        IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              _auth.signOut();
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
            if (index == 3) {
              final currentUserId = FirebaseAuth.instance.currentUser!.uid;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfilePage(
                    userId: currentUserId,
                    shouldResetIndex: true,
                  ),
                ),
              ).then((backButtonPressed) {
                // Check if the back button was explicitly pressed
                if (backButtonPressed != null && backButtonPressed) {
                  setState(() {
                    _pageController.jumpToPage(0);
                  });
                }
              });
            }
          });
        },
        children: [
          // Page 0: Recommendations and Filters
          _selectedIndex == 0
              ? SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 5),
                    _buildRecommendationsBar(),
                    const SizedBox(height: 5),
                    _buildFavouritesBar(),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(10),
                      children: [
                        _buildFilterCard('Cuisine', () => _showCuisineDialog(), 'cuisineimage.png'),
                        _buildFilterCard('Category', () => _showCategoryDialog(), 'categoryimage.png'),
                        _buildFilterCard('All Ingredients', () => _showIngredientsDialog(), 'ingredientsimage.png'),
                        _buildFilterCard('Pantry Filter', () => _showPantryIngredientsDialog(), 'pantryimage.png'),
                      ],
                    ),
                  ],
                ),
              )
              : const Center(child: Text('Empty View')), // not sure why swiping navigation doesnt work without this

          // Page 1:
          GestureDetector(
            // Add Gesture Detector
              onTap: () async {
                await _getImageFromCamera();
                _pageController.jumpToPage(2); // Move to the next page (Pantry)
              },
              child: const Center(child: Icon(Icons.photo_camera_outlined),)
          ),

          // Page 2: Pantry
          _selectedIndex == 2
              ? (_pantryItems.isEmpty
              ? const Center(child: Text('Your pantry is empty!'))
                : Column( // Introduce a Column to arrange legend and grid
                    children: [
                      Card( // Legend as a Card
                        margin: const EdgeInsets.all(10), // Added margin for spacing
                        color: Colors.grey[100],
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                              child: Row(
                              mainAxisAlignment: MainAxisAlignment.center, // Or spaceEvenly
                                children: [
                                // Legend Card
                                  Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                          height: 20,
                                          width: 20,
                                          color: Colors.green[200],
                                        ),
                                        const SizedBox(width: 5),
                                        const Text('Normal Ingredient'),
                                        const SizedBox(width: 10),
                                        Container(
                                          height: 30,
                                          width: 30,
                                          color: Colors.purple[100],
                                        ),
                                        const SizedBox(width: 5),
                                        const Text('Staple Ingredient'),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            ),
                      const SizedBox(height: 10),

                      ElevatedButton(
                        onPressed: () {
                          _fetchPantryItems();
                        },
                        child: const Text('Refresh Your Pantry'),
                      ),

                      const SizedBox(height: 10),

                        Expanded (
                      child : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,

            ),
            itemCount: _pantryItems.length,
            itemBuilder: (context, index) {
            final item = _pantryItems[index];
            return Card(
              color: item['isPermanent'] ? Colors.purple[100] : Colors.green[200],
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // Align title to the left
                  children: [
                    // Ingredient Name
                    Text(
                      _capitalize(item['id']),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2, // Limit to 2 lines
                    ),

                    // Amount
                    Text(
                      item['isPermanent']
                          ? 'Qty: ∞'
                          : 'Qty: ${item['amount'] ?? 0} ${item['unit'] ?? 'unit(s)'}',
                    ),

                    const SizedBox(height: 8),

                    // Action Buttons (Only if not permanent)
                    if (!item['isPermanent'])
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center, // Align buttons to the right
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showEditDialog(item['id'], item['amount']),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            color: Colors.red,
                            onPressed: () => _confirmDelete(item['id']),
                          ),
                        ],
                      ),

                  ],
                ),
              ),
            );
            },
          )
        )
              ]
          )
          )
              : const Center(child: Text('Empty View')), // not sure why swiping navigation doesnt work without this
          const Center(child: Text('Redirecting to Profile...')),
          ],
      ),
      floatingActionButton: _selectedIndex == 2  // Only show when on 'Pantry'
          ? _buildFloatingActionButton()
          : null,
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(canvasColor: Colors.green[300]),
        child: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.restaurant),
              label: 'Recipes',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.photo_camera_outlined),
              label: 'Scan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.food_bank_outlined),
              label: 'Pantry',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Profile',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.purpleAccent[100],
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}
