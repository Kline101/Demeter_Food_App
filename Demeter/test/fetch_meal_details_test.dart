import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:demeter/meal_service.dart';
import 'fetch_meal_details_test.mocks.dart';

@GenerateMocks([http.Client])
void main() {
  test('fetchMealDetails returns meal on success', () async {
    final mockClient = MockClient();
    final mealService = MealService();

    when(mockClient.get(any)).thenAnswer((_) async => http.Response(
        '{ "meals": [ { "idMeal": "52806", "strMeal": "Tandoori chicken" } ] }',
        200));

    final result = await mealService.fetchMealDetails('52806');

    expect(result['idMeal'], '52806');
    expect(result['strMeal'], 'Tandoori chicken');
  });
}