import sys
import os

# Ensure the backend directory is in python path
sys.path.insert(0, os.path.dirname(__file__))

# Import the WSGI middleware adapter and the FastAPI app
from a2wsgi import ASGIMiddleware
from main import app

# Passenger looks for the 'application' variable
application = ASGIMiddleware(app)
