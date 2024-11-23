from flask import Flask, request, jsonify, g
from mongoengine import connect, DoesNotExist, Document, StringField, ListField, DictField

from models import User
import logging
import jwt
from middlewares import auth_required 
import numpy as np
import pickle 
import csv
import io

import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score
import pickle

app = Flask(__name__)
app.config['SECRET_KEY'] = 'passwordKey'  

connect(
    'test', 
    host='mongodb://localhost:27017/test'
)

@app.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    username = data.get('username')
    email = data.get('email')
    password = data.get('password')

    if not username or not email or not password:
        return jsonify({"status": "error", "message": "All fields are required"}), 400

    if User.objects(username=username).first():
        return jsonify({"status": "error", "message": "Username already exists"}), 400

    if User.objects(email=email).first():
        return jsonify({"status": "error", "message": "Email already exists"}), 400

    user = User(username=username, email=email)
    user.set_password(password)
    user.save()

    return jsonify({"status": "success", "message": "User registered successfully! Login with the same credentials"}), 201

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    email = data.get('email')
    password = data.get('password')

    if not email or not password:
        return jsonify({"status": "error", "message": "Email and password are required"}), 400

    try:
        user = User.objects.get(email=email)
        if not user.check_password(password):
            return jsonify({"status": "error", "message": "Invalid email or password"}), 400

        token = jwt.encode({"id": str(user.id)}, app.config['SECRET_KEY'], algorithm="HS256")

        return jsonify({"status": "success", "token": token}), 200
    except DoesNotExist:
        return jsonify({"status": "error", "message": "Invalid email or password"}), 400


@app.route('/tokenIsValid', methods=['POST'])
def token_is_valid():
    try:
        token = request.headers.get('x-auth-token')
        if not token:
            return jsonify(False)
        
        verified = jwt.decode(token, app.config['SECRET_KEY'], algorithms=["HS256"])
        if not verified:
            return jsonify(False)
        
        user = User.objects.get(id=verified['id'])
        if not user:
            return jsonify(False)
        
        return jsonify(True)
    except jwt.ExpiredSignatureError:
        return jsonify(False)
    except jwt.InvalidTokenError:
        return jsonify(False)
    except DoesNotExist:
        return jsonify(False)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/', methods=['GET'])
@auth_required(app)
def get_user_data():
    try:
        user = g.user
        user_data = user.to_mongo().to_dict()
        user_data.pop('_id')  # Remove _id from the response
        return jsonify({**user_data, "token": g.token})
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    
    
with open('classifier.pkl', 'rb') as model_file:
    model = pickle.load(model_file)

@app.route('/predict', methods=['POST'])
def predict():
    try:
        # Get the data from the request
        data = request.get_json()
        
        # Extract individual x, y, z values
        x = data['x']
        y = data['y']
        z = data['z']
        
        # Prepare the data for the model
        input_data = pd.DataFrame([[x, y, z]], columns=['x', 'y', 'z'])  # Reshape data for model input
        prediction = model.predict(input_data)
        
        print(prediction[0])
        # Return the prediction result
        return jsonify({'label': prediction[0]})
    
    except Exception as e:
        return jsonify({'error': str(e)}), 400

    
    
class AccelerometerData(Document):
    x = StringField(required=True)
    y = StringField(required=True)
    z = StringField(required=True)
    label = StringField(required=True)

@app.route('/upload_csv', methods=['POST'])
def upload_csv():
    try:
        # Parse the CSV string from the request
        data = request.get_json()
        csv_string = data.get('csv_data')
        print(csv_string)
        
        if not csv_string:
            return jsonify({"status": "error", "message": "CSV data is missing"}), 400

        # Read the CSV string using Python's csv module
        csv_reader = csv.DictReader(io.StringIO(csv_string))
        records = [
            AccelerometerData(
                x=row['x'], y=row['y'], z=row['z'], label=row['label']
            )
            for row in csv_reader
        ]

        # Bulk save records to MongoDB
        AccelerometerData.objects.insert(records, load_bulk=False)

        return jsonify({"status": "success", "message": "Data uploaded successfully"}), 200

    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5002, debug=True)