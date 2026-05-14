import { Ollama } from 'ollama';

export interface ChatRequest {
  model: string;
  system: string;
  user: string;
}

export interface ChatResult {
  text: string;
  firstTokenMs: number;
  totalMs: number;
  model: string;
}

export interface EmbedRequest {
  model: string;
  input: string;
}

export interface EmbedResult {
  embedding: number[];
  model: string;
}

export interface LlmAdapter {
  isAvailable(): Promise<boolean>;
  chat(req: ChatRequest): Promise<ChatResult>;
  embed(req: EmbedRequest): Promise<EmbedResult>;
}

export class OllamaAdapter implements LlmAdapter {
  private client: Ollama;
  constructor(host: string = process.env.OLLAMA_HOST ?? 'http://127.0.0.1:11434') {
    this.client = new Ollama({ host });
  }

  async isAvailable(): Promise<boolean> {
    try {
      await this.client.list();
      return true;
    } catch {
      return false;
    }
  }

  async chat(req: ChatRequest): Promise<ChatResult> {
    const started = performance.now();
    let firstTokenAt = 0;
    let text = '';
    const stream = await this.client.chat({
      model: req.model,
      messages: [
        { role: 'system', content: req.system },
        { role: 'user', content: req.user },
      ],
      stream: true,
    });
    for await (const part of stream) {
      if (firstTokenAt === 0) firstTokenAt = performance.now();
      text += part.message.content;
    }
    const now = performance.now();
    return {
      text,
      firstTokenMs: Math.round(firstTokenAt - started),
      totalMs: Math.round(now - started),
      model: req.model,
    };
  }

  async embed(req: EmbedRequest): Promise<EmbedResult> {
    const res = await this.client.embed({ model: req.model, input: req.input });
    const first = res.embeddings[0];
    if (!first) throw new Error(`Ollama returned no embedding for model ${req.model}`);
    return { embedding: first, model: req.model };
  }
}
