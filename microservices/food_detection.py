import os
from dotenv import load_dotenv  # Import load_dotenv
import base64
from flask import Flask, request, jsonify
from clarifai_grpc.channel.clarifai_channel import ClarifaiChannel
from clarifai_grpc.grpc.api import resources_pb2, service_pb2, service_pb2_grpc
from clarifai_grpc.grpc.api.status import status_code_pb2
import pandas as pd
import requests
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity

app = Flask(__name__)

load_dotenv()  # TODO Load variables from the .env file on the day

# Access variables using os.environ
PAT = os.environ['PAT']
USER_ID = os.environ['USER_ID']
APP_ID = os.environ['APP_ID']
MODEL_ID = os.environ['MODEL_ID']
MODEL_VERSION_ID = os.environ['MODEL_VERSION_ID']

channel = ClarifaiChannel.get_grpc_channel()
stub = service_pb2_grpc.V2Stub(channel)

@app.route('/detect', methods=['POST'])
def detect_concepts():
    if 'image' not in request.form:
        return jsonify({'error': 'No image data provided'}), 400

    base64_image = request.form['image']

    try:
        image_bytes = base64.b64decode(base64_image)

        metadata = (('authorization', 'Key ' + PAT),)
        userDataObject = resources_pb2.UserAppIDSet(user_id=USER_ID, app_id=APP_ID)

        response = stub.PostModelOutputs(
            service_pb2.PostModelOutputsRequest(
                user_app_id=userDataObject,
                model_id=MODEL_ID,
                version_id=MODEL_VERSION_ID,
                inputs=[
                    resources_pb2.Input(
                        data=resources_pb2.Data(
                            image=resources_pb2.Image(
                                base64=image_bytes  # Send directly as base64
                            )
                        )
                    )
                ]
            ),
            metadata=metadata
        )

        if response.status.code != status_code_pb2.SUCCESS:
            raise Exception("Request failed, status: " + response.status.description)

        filtered_concepts = [concept.name for concept in response.outputs[0].data.concepts if concept.value >= 0.50]

        return jsonify(filtered_concepts)  # Return only >50% confidence level concepts

    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/fetch_recommendations', methods=['POST'])
def process_recipes():

    if not request.is_json:
        return jsonify({'error': 'Invalid content type. Expecting application/json'})

    data = request.get_json()  # Get the data
    recipes = data.get('recipes', [])  # Extract the recipes list

    all_recipes = fetch_recipes_from_api()
    recipes_df = pd.DataFrame(all_recipes)  # Create DataFrame directly
    results = []  # Store results to return
    for recipe in recipes:
        target_id = int(recipe['idMeal'])
        recommended_ids = generate_recommendations(target_id, recipes_df)
        results.append(recommended_ids)

    return jsonify({'recommendations': results}), 200

def preprocess_ingredients(ingredients):
    # TODO additional text cleaning logic here if needed
    return ingredients.lower()


def generate_recommendations(target_recipe, recipes_df, num_recommendations=5):
    ingredient_cols = [f'strIngredient{i}' for i in range(1, 21)]
    ingredients_list = recipes_df[ingredient_cols].apply(
        lambda row: ' '.join([ing for ing in row if ing]), axis=1
    )

    vectorizer = TfidfVectorizer(analyzer=preprocess_ingredients)
    recipe_matrix = vectorizer.fit_transform(ingredients_list)
    target_id = target_recipe
    target_index = recipes_df[recipes_df['idMeal'] == str(target_id)].index[0]
    similarities = cosine_similarity(recipe_matrix[target_index], recipe_matrix)

    top_similar = similarities.argsort()[0][-1 - num_recommendations:-1][::-1]
    recommended_ids = recipes_df.iloc[top_similar]['idMeal'].tolist()

    return recommended_ids

def fetch_recipes_from_api():
    api_url = 'https://www.themealdb.com/api/json/v2/9973533/search.php?s='
    response = requests.get(api_url)  # Use requests.get

    if response.status_code == 200:
        data = response.json()
        recipes = data.get('meals', [])  # Extract the 'meals' array
        return recipes
    else:
        raise Exception(f"API request failed with status code: {response.status_code}")

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=1935)
