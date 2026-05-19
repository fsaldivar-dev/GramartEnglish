import { existsSync, mkdirSync, writeFileSync, readFileSync, unlinkSync } from 'node:fs';
import { dirname, join } from 'node:path';
import hnswlib from 'hnswlib-node';
const { HierarchicalNSW } = hnswlib;

export interface IndexHeader {
  schemaVersion: number;
  dim: number;
  size: number;
  builtAt: string;
}

export interface IndexEntry {
  ragSourceId: number;
  embedding: number[];
}

export interface KnnResult {
  ragSourceId: number;
  distance: number;
}

export class RagIndex {
  private index: HierarchicalNSW | null = null;
  private idMap: number[] = [];
  private dim: number;
  private headerPath: string;
  private indexPath: string;
  private idMapPath: string;

  constructor(
    private storageDir: string,
    private currentSchemaVersion: number,
    dim: number,
  ) {
    this.dim = dim;
    this.headerPath = join(storageDir, 'rag.index.header.json');
    this.indexPath = join(storageDir, 'rag.index.bin');
    this.idMapPath = join(storageDir, 'rag.index.idmap.json');
  }

  isReady(): boolean {
    return this.index !== null;
  }

  size(): number {
    return this.idMap.length;
  }

  /** Returns true if a usable index was loaded, false if a rebuild is required. */
  load(): boolean {
    if (!existsSync(this.headerPath) || !existsSync(this.indexPath) || !existsSync(this.idMapPath)) {
      return false;
    }
    const header = JSON.parse(readFileSync(this.headerPath, 'utf8')) as IndexHeader;
    if (header.schemaVersion !== this.currentSchemaVersion || header.dim !== this.dim) {
      this.discardOnDisk();
      return false;
    }
    const idx = new HierarchicalNSW('cosine', this.dim);
    idx.readIndexSync(this.indexPath, true);
    this.index = idx;
    this.idMap = JSON.parse(readFileSync(this.idMapPath, 'utf8')) as number[];
    return true;
  }

  rebuild(entries: IndexEntry[]): void {
    mkdirSync(dirname(this.indexPath), { recursive: true });
    const idx = new HierarchicalNSW('cosine', this.dim);
    idx.initIndex(Math.max(entries.length, 1));
    this.idMap = [];
    entries.forEach((entry, i) => {
      if (entry.embedding.length !== this.dim) {
        throw new Error(`Embedding dim mismatch at ${entry.ragSourceId}: ${entry.embedding.length} vs ${this.dim}`);
      }
      idx.addPoint(entry.embedding, i);
      this.idMap.push(entry.ragSourceId);
    });
    idx.writeIndexSync(this.indexPath);
    this.index = idx;
    writeFileSync(this.idMapPath, JSON.stringify(this.idMap), 'utf8');
    const header: IndexHeader = {
      schemaVersion: this.currentSchemaVersion,
      dim: this.dim,
      size: entries.length,
      builtAt: new Date().toISOString(),
    };
    writeFileSync(this.headerPath, JSON.stringify(header, null, 2), 'utf8');
  }

  knn(query: number[], k: number): KnnResult[] {
    if (!this.index) throw new Error('Index not loaded; call load() or rebuild()');
    if (this.idMap.length === 0) return [];
    if (query.length !== this.dim) throw new Error(`Query dim mismatch: ${query.length} vs ${this.dim}`);
    const limit = Math.min(k, this.idMap.length);
    const result = this.index.searchKnn(query, limit);
    return result.neighbors.map((internal, i) => {
      const sourceId = this.idMap[internal];
      const distance = result.distances[i];
      if (sourceId === undefined || distance === undefined) {
        throw new Error('HNSW returned out-of-range neighbor');
      }
      return { ragSourceId: sourceId, distance };
    });
  }

  private discardOnDisk(): void {
    for (const p of [this.headerPath, this.indexPath, this.idMapPath]) {
      if (existsSync(p)) unlinkSync(p);
    }
  }
}
