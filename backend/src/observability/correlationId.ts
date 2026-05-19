import { randomUUID } from 'node:crypto';
import type { FastifyInstance, FastifyRequest } from 'fastify';
import fp from 'fastify-plugin';

declare module 'fastify' {
  interface FastifyRequest {
    correlationId: string;
  }
}

const HEADER = 'x-correlation-id';
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function isValidCorrelationId(value: unknown): value is string {
  return typeof value === 'string' && UUID_RE.test(value);
}

export const correlationIdPlugin = fp(async (app: FastifyInstance) => {
  app.addHook('onRequest', async (req: FastifyRequest, reply) => {
    const raw = req.headers[HEADER];
    const incoming = Array.isArray(raw) ? raw[0] : raw;
    const id = isValidCorrelationId(incoming) ? incoming : randomUUID();
    req.correlationId = id;
    req.log = req.log.child({ correlationId: id });
    reply.header(HEADER, id);
  });
});
