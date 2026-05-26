import os
import sqlite3
from dotenv import load_dotenv
from supabase import create_client

# Load environment variables
load_dotenv()

users_to_update = [
    {
        "email": "patricia@gmail.com",
        "dob": "1986-01-01",
        "ic_number": "860101-08-1234"
    },
    {
        "email": "michelle@gmail.com",
        "dob": "1980-01-01",
        "ic_number": "800101-08-1234"
    },
    {
        "email": "sabrina@gmail.com",
        "dob": "1980-01-01",
        "ic_number": "800101-07-1234"
    },
    {
        "email": "rachel@gmail.com",
        "dob": "1978-01-01",
        "ic_number": "780101-08-1234"
    },
    {
        "email": "vanessa@gmail.com",
        "dob": "1984-01-01",
        "ic_number": "840101-08-1234"
    },
    {
        "email": "narasimhan@gmail.com",
        "dob": "1983-01-01",
        "ic_number": "830101-08-1235"
    },
    {
        "email": "sanjay@gmail.com",
        "dob": "1986-01-01",
        "ic_number": "860101-08-1235"
    }
]

# 1. Update Supabase
url = os.environ.get("SUPABASE_URL")
key = os.environ.get("SUPABASE_KEY")
if url and key:
    try:
        supabase = create_client(url, key)
        print("[SUPABASE] Updating users...")
        for u in users_to_update:
            # Check if user exists
            res = supabase.table("users").select("id").eq("email", u["email"]).execute()
            if res.data:
                user_id = res.data[0]["id"]
                update_res = supabase.table("users").update({
                    "dob": u["dob"],
                    "ic_number": u["ic_number"]
                }).eq("id", user_id).execute()
                print(f"  Updated user {u['email']} successfully.")
            else:
                print(f"  User {u['email']} not found in Supabase.")
    except Exception as e:
        print(f"[SUPABASE ERROR] {e}")
else:
    print("[SUPABASE] Skipping, credentials not configured.")

# 2. Update SQLite
db_paths = ["medical_reports.db", "backend/medical_reports.db"]
for db_path in db_paths:
    if os.path.exists(db_path):
        try:
            print(f"[SQLITE] Updating users in {db_path}...")
            conn = sqlite3.connect(db_path)
            cursor = conn.cursor()
            for u in users_to_update:
                cursor.execute(
                    "UPDATE users SET dob = ?, ic_number = ? WHERE email = ?",
                    (u["dob"], u["ic_number"], u["email"])
                )
                if cursor.rowcount > 0:
                    print(f"  Updated user {u['email']} successfully.")
                else:
                    # User might not exist locally, that's fine
                    pass
            conn.commit()
            conn.close()
        except Exception as e:
            print(f"[SQLITE ERROR in {db_path}] {e}")
    else:
        print(f"[SQLITE] Database file {db_path} not found.")

print("All updates finished.")
