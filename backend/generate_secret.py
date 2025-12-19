import os
import base64
from secrets import token_bytes

def generate_jwt_secret_key(length=32):
    # Generate a random secret key
    secret_key = token_bytes(length)
    # Encode it in base64
    encoded_secret = base64.urlsafe_b64encode(secret_key).decode('utf-8')
    return encoded_secret

# Generate and print the new JWT secret key
new_secret_key = generate_jwt_secret_key()
print("Your new JWT_SECRET_KEY is:", new_secret_key)

# Optionally, you can also save it to an environment file
with open('.env', 'a') as env_file:
    env_file.write(f'JWT_SECRET_KEY={new_secret_key}\n')
