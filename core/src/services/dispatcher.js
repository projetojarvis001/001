const axios = require('axios');

class Dispatcher {
  static async route(task, complexity = 'low') {
    const visionHost = process.env.VISION_HOST;
    const groqKey = process.env.GROQ_API_KEY;

    if (complexity === 'low') {
      try {
        const res = await axios.post(`http://${visionHost}:11434/api/generate`, {
          model: 'qwen2.5:7b',
          prompt: task,
          stream: false
        });
        return res.data.response;
      } catch (e) {
        console.error('[Dispatcher] Mac 2 falhou, tentando Groq...');
        return this.callGroq(task, groqKey);
      }
    } else {
      return this.callGroq(task, groqKey);
    }
  }

  static async callGroq(prompt, key) {
    try {
      const res = await axios.post('https://api.groq.com/openai/v1/chat/completions', {
        model: 'llama3-70b-8192',
        messages: [{ role: 'user', content: prompt }]
      }, {
        headers: { Authorization: `Bearer ${key}` }
      });
      return res.data.choices[0].message.content;
    } catch (e) {
      return "Sistemas operando em modo de contingência.";
    }
  }
}

module.exports = { Dispatcher };
