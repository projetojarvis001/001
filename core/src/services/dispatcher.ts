import axios from 'axios';

export class Dispatcher {
  private static groqKey = process.env.GROQ_API_KEY;
  private static visionHost = process.env.VISION_HOST;

  static async route(task: string, complexity: 'low' | 'high' = 'low') {
    // Regra de Negócio: Baixa complexidade ou dados sensíveis -> Mac 2 (Local)
    // Alta complexidade -> Groq (Nuvem)
    if (complexity === 'low') {
      return this.callOllama(task);
    } else {
      return this.callGroq(task);
    }
  }

  private static async callOllama(prompt: string) {
    try {
      const res = await axios.post(`http://${this.visionHost}:11434/api/generate`, {
        model: 'qwen2.5:7b',
        prompt: prompt,
        stream: false
      });
      return res.data.response;
    } catch (e) {
      console.error('[Dispatcher] Falha no Mac 2, escalonando para Groq...');
      return this.callGroq(prompt);
    }
  }

  private static async callGroq(prompt: string) {
    try {
      const res = await axios.post('https://api.groq.com/openai/v1/chat/completions', {
        model: 'llama3-70b-8192',
        messages: [{ role: 'user', content: prompt }]
      }, {
        headers: { Authorization: `Bearer ${this.groqKey}` }
      });
      return res.data.choices[0].message.content;
    } catch (e) {
      return "Erro crítico: Cérebro offline.";
    }
  }
}
