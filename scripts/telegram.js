const axios = require("axios");
const dotenv = require("dotenv");

dotenv.config();

const bot_token = process.env.BOT_TOKEN;
const chat_id = process.env.CHAT_ID;

async function sendMessage(message) {
  try {
    const response = await axios.post(
      `https://api.telegram.org/bot${bot_token}/sendMessage`,
      {
        chat_id: chat_id,
        text: message,
      }
    );
    console.log("Message sent successfully:", response.data);
  } catch (error) {
    console.error("Error sending message:", error);
  }
}

async function sendErrorToTelegram(error) {
  const errorMessage = `Error:\n${error.name}: ${error.message}\n\nStack Trace:\n${error.stack}`;
  await sendMessage(errorMessage);
}

module.exports = {
  sendMessage,
  sendErrorToTelegram,
};
