import json
from tools.config import LANGUAGE

with open('tools/language/message.json', 'r', encoding='utf-8') as file:
    message = json.load(file)

async def MESSAGE(key: str) -> str:
    text = message[LANGUAGE][str(key)]
    return text