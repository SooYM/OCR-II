import sys
import os

# Check if virtual environment python interpreter exists and redirect if we are not running it
venv_python = os.path.join(os.path.dirname(__file__), 'venv', 'bin', 'python')
if os.path.exists(venv_python) and sys.executable != venv_python:
    os.execv(venv_python, [venv_python] + sys.argv)

# Ensure the backend directory is in python path
sys.path.insert(0, os.path.dirname(__file__))

# Import the WSGI middleware adapter and the FastAPI app
from a2wsgi import ASGIMiddleware
from main import app

# Passenger looks for the 'application' variable
application = ASGIMiddleware(app)
