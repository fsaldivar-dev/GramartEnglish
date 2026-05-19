import pino, { type Logger } from 'pino';

export function createLogger(level: string = process.env.LOG_LEVEL ?? 'info'): Logger {
  const isDev = process.env.NODE_ENV !== 'production';
  return pino({
    level,
    base: { service: 'gramart-english-backend' },
    timestamp: pino.stdTimeFunctions.isoTime,
    transport: isDev
      ? { target: 'pino-pretty', options: { colorize: true, translateTime: 'SYS:HH:MM:ss.l' } }
      : undefined,
  });
}

export type { Logger };
