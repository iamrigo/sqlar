from aiogram import Bot, Dispatcher, types
from aiogram.filters import CommandStart, Command
from tools.language.handler import MESSAGE
from tools.db import db
from tools.config import BOT_TOKEN, ADMIN_CHATID

bot = Bot(token=BOT_TOKEN)
dp = Dispatcher()

@dp.message(CommandStart())
@dp.message(Command("help"))
async def send_welcome(message: types.Message, bot: Bot):
    if message.chat.id == int(ADMIN_CHATID):
        await message.reply(await MESSAGE('START'))
    else:
        await message.reply(await MESSAGE('BLOCK'))

@dp.message()
async def handle_sql_query(message: types.Message, bot: Bot):
    if message.chat.id != int(ADMIN_CHATID):
        await message.reply(await MESSAGE('BLOCK'))
        return

    try:
        await db.connect()
        query = message.text
        results = await db.execute_query(query)
        response = "\n".join(str(row) for row in results)
        if not response:
            response = await MESSAGE('SUCCESS_NO_MESSAGE')
        await message.reply(response)
    except Exception as e:
        await message.reply(f"{await MESSAGE('ERROR')}\n\n{str(e)}")
    finally:
        await db.disconnect()

async def main():
    await dp.start_polling(bot)

if __name__ == '__main__':
    import asyncio
    asyncio.run(main())