import type { FastifyInstance } from 'fastify';
import type Database from 'better-sqlite3';
import { z } from 'zod';
import { CefrLevel, LessonMode } from '../domain/schemas.js';
import { UserRepository } from '../store/userRepository.js';

const Patch = z
  .object({
    currentLevel: CefrLevel.optional(),
    accessibilityPrefs: z.record(z.string(), z.unknown()).optional(),
    preferredMode: LessonMode.optional(),
  })
  .refine(
    (d) => d.currentLevel !== undefined || d.accessibilityPrefs !== undefined || d.preferredMode !== undefined,
    { message: 'at least one of currentLevel, accessibilityPrefs, or preferredMode must be provided' },
  );

export interface MeRouteDeps {
  db: Database.Database;
}

export async function registerMeRoutes(app: FastifyInstance, deps: MeRouteDeps): Promise<void> {
  const userRepo = new UserRepository(deps.db);

  app.get('/v1/me', async () => {
    return userRepo.ensureSingleton();
  });

  app.patch('/v1/me', async (req, reply) => {
    const parsed = Patch.safeParse(req.body);
    if (!parsed.success) return reply.code(400).send({ code: 'invalid_payload', message: parsed.error.message });
    const user = userRepo.ensureSingleton();
    if (parsed.data.currentLevel) {
      userRepo.setLevel(user.id, parsed.data.currentLevel);
    }
    if (parsed.data.accessibilityPrefs) {
      userRepo.setAccessibilityPrefs(user.id, parsed.data.accessibilityPrefs);
    }
    if (parsed.data.preferredMode) {
      userRepo.setPreferredMode(user.id, parsed.data.preferredMode);
    }
    req.log.info({ patched: Object.keys(parsed.data) }, 'me.patched');
    return userRepo.ensureSingleton();
  });

  app.post('/v1/me/reset', async (req) => {
    // Wipes user-specific tables but preserves the corpus and rag sources.
    deps.db.exec(`
      BEGIN;
      DELETE FROM ai_generations;
      DELETE FROM placement_results;
      DELETE FROM word_mastery;
      DELETE FROM questions;
      DELETE FROM lessons;
      DELETE FROM users;
      COMMIT;
    `);
    const user = userRepo.ensureSingleton();
    req.log.info({ userId: user.id }, 'me.reset');
    return { ok: true, user };
  });
}
