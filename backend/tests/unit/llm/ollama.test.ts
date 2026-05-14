import { describe, it, expect } from 'vitest';
import { RecordedFakeLlm } from '../../../src/llm/__fakes__/recorded.js';

describe('RecordedFakeLlm', () => {
  it('reports available by default', async () => {
    const fake = new RecordedFakeLlm();
    expect(await fake.isAvailable()).toBe(true);
  });

  it('returns the default response when no match', async () => {
    const fake = new RecordedFakeLlm({ defaultChatResponse: 'hello' });
    const res = await fake.chat({ model: 'm', system: 's', user: 'unknown' });
    expect(res.text).toBe('hello');
    expect(res.firstTokenMs).toBeGreaterThan(0);
    expect(res.model).toBe('m');
  });

  it('returns the matched response when user text contains the trigger', async () => {
    const fake = new RecordedFakeLlm();
    fake.setResponse('ephemeral', 'Lasting briefly.');
    const res = await fake.chat({ model: 'm', system: 's', user: 'Define ephemeral please' });
    expect(res.text).toBe('Lasting briefly.');
  });

  it('throws when marked unavailable', async () => {
    const fake = new RecordedFakeLlm({ available: false });
    expect(await fake.isAvailable()).toBe(false);
    await expect(fake.chat({ model: 'm', system: 's', user: 'x' })).rejects.toThrow();
  });

  it('produces deterministic embeddings of the requested dimension', async () => {
    const fake = new RecordedFakeLlm({ embedDimension: 16 });
    const a = await fake.embed({ model: 'm', input: 'word' });
    const b = await fake.embed({ model: 'm', input: 'word' });
    expect(a.embedding).toHaveLength(16);
    expect(a.embedding).toEqual(b.embedding);
    const c = await fake.embed({ model: 'm', input: 'different' });
    expect(c.embedding).not.toEqual(a.embedding);
  });
});
