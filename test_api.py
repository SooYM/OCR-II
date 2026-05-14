import asyncio
from httpx import AsyncClient
from backend.main import supabase

async def test():
    if supabase:
        res = supabase.table("chat_sessions").select("*").execute()
        if res.data:
            session_id = res.data[0]['id']
            # test the fastAPI logic
            res2 = supabase.table("chat_messages").select("*").eq("session_id", session_id).order("timestamp", asc=True).execute()
            print("Response data:", res2.data)

asyncio.run(test())
