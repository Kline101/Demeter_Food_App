import 'dart:convert';
import 'package:http/http.dart' as http;

class MealService {
  Future<dynamic> fetchMealDetails(String recipeId) async {
    final url = 'https://www.themealdb.com/api/json/v2/9973533/lookup.php?i=$recipeId';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['meals'][0];
    } else {
      throw Exception('Failed to fetch meal details');
    }
  }

  Future<List> fetchRecipes(String cuisine) async {
    final apiUrl = 'https://www.themealdb.com/api/json/v2/9973533/filter.php?a=$cuisine';
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
}

