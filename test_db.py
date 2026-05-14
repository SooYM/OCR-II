import asyncio
from backend.main import supabase, STORAGE_ENGINE

async def main():
    print(f"Engine: {STORAGE_ENGINE}")
    if supabase:
        res = supabase.table("chat_sessions").select("*").execute()
        print(f"Sessions: {len(res.data)}")
        if res.data:
            session_id = res.data[0]['id']
            msgs = supabase.table("chat_messages").select("*").eq("session_id", session_id).execute()
            print(f"Messages in session {session_id}: {len(msgs.data)}")
            for m in msgs.data:
                print(f"Role: {m['role']}, Content length: {len(m['content'])}")

asyncio.run(main())
