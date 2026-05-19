import type { ChatRequest, ChatResult, EmbedRequest, EmbedResult, LlmAdapter } from '../ollama.js';

export interface RecordedFakeOptions {
  available?: boolean;
  chatResponses?: Map<string, string>;
  defaultChatResponse?: string;
  embedDimension?: number;
}

export class RecordedFakeLlm implements LlmAdapter {
  private available: boolean;
  private chatResponses: Map<string, string>;
  private defaultChatResponse: string;
  private embedDimension: number;

  constructor(opts: RecordedFakeOptions = {}) {
    this.available = opts.available ?? true;
    this.chatResponses = opts.chatResponses ?? new Map();
    this.defaultChatResponse = opts.defaultChatResponse ?? 'recorded response';
    this.embedDimension = opts.embedDimension ?? 384;
  }

  setAvailable(value: boolean): void {
    this.available = value;
  }

  setResponse(matchSubstring: string, response: string): void {
    this.chatResponses.set(matchSubstring, response);
  }

  async isAvailable(): Promise<boolean> {
    return this.available;
  }

  async chat(req: ChatRequest): Promise<ChatResult> {
    if (!this.available) throw new Error('LLM unavailable (recorded fake)');
    let text = this.defaultChatResponse;
    for (const [substr, response] of this.chatResponses) {
      if (req.user.includes(substr)) {
        text = response;
        break;
      }
    }
    return { text, firstTokenMs: 50, totalMs: 120, model: req.model };
  }

  async embed(req: EmbedRequest): Promise<EmbedResult> {
    if (!this.available) throw new Error('LLM unavailable (recorded fake)');
    let seed = 0;
    for (let i = 0; i < req.input.length; i += 1) {
      seed = (seed * 31 + req.input.charCodeAt(i)) >>> 0;
    }
    const embedding = Array.from({ length: this.embedDimension }, (_, i) => {
      seed = (seed * 1103515245 + 12345) >>> 0;
      const v = ((seed % 2_000_000) / 1_000_000) - 1;
      return Math.cos(v + i * 0.001);
    });
    return { embedding, model: req.model };
  }
}
