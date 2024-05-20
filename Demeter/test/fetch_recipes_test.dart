import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:demeter/meal_service.dart';
import 'fetch_recipes_test.mocks.dart';

@GenerateMocks([http.Client])
void main() {
  test('fetchRecipes returns recipes on success', () async {
    final mockClient = MockClient();
    final mealService = MealService();

    when(mockClient.get(any)).thenAnswer((_) async =>
        http.Response(
            '{ "meals": [ { "strMeal": "Budino Di Ricotta", "idMeal": "52961" } ] }',
            200));
    final result = await mealService.fetchRecipes('Italian');
    expect(result.length, 20); // Expect 20 meal from Italian
    // ignore: avoid_print
    print(result[0]);
    expect(result[0]['idMeal'], '52961');
    expect(result[0]['strMeal'], 'Budino Di Ricotta');
  });
}
