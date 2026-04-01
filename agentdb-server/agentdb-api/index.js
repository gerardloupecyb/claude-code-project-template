import express from 'express';
import { QdrantClient } from '@qdrant/js-client-rest';
import { v4 as uuidv4 } from 'uuid';

const app = express();
app.use(express.json({ limit: '2mb' }));

const qdrant = new QdrantClient({ url: process.env.QDRANT_URL || 'http://localhost:6333' });
const EMBEDDING_URL = process.env.EMBEDDING_URL || 'http://localhost:8080';
const API_KEY = process.env.AGENTDB_API_KEY;
const PORT = parseInt(process.env.PORT || '3100');

// nomic-embed-text-v1.5 outputs 768 dimensions
const VECTOR_SIZE = 768;

// Auth middleware — skip if no key configured (dev mode)
app.use((req, res, next) => {
  if (req.path === '/health') return next();
  if (!API_KEY) return next();
  const key =
    req.headers['x-agentdb-key'] ||
    (req.headers['authorization'] || '').replace('Bearer ', '');
  if (key !== API_KEY) return res.status(401).json({ error: 'Unauthorized' });
  next();
});

// Call HuggingFace TEI embedding service
async function embed(text) {
  const res = await fetch(`${EMBEDDING_URL}/embed`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ inputs: text }),
    signal: AbortSignal.timeout(30_000),
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Embedding service error ${res.status}: ${body}`);
  }
  const data = await res.json();
  // TEI returns [[vector]] for single input
  return Array.isArray(data[0]) ? data[0] : data;
}

// Create Qdrant collection if it doesn't exist
async function ensureCollection(namespace) {
  const { collections } = await qdrant.getCollections();
  if (!collections.some((c) => c.name === namespace)) {
    await qdrant.createCollection(namespace, {
      vectors: { size: VECTOR_SIZE, distance: 'Cosine' },
    });
  }
}

// POST /entries — embed + upsert an entry
app.post('/entries', async (req, res) => {
  try {
    const { title, content, domain, classification, date, author, namespace, tags, metadata } =
      req.body;
    if (!title || !content || !namespace) {
      return res.status(400).json({ error: 'title, content, and namespace are required' });
    }

    const id = req.body.id || uuidv4();
    const vector = await embed(`${title}\n\n${content}`);

    await ensureCollection(namespace);
    await qdrant.upsert(namespace, {
      wait: true,
      points: [
        {
          id,
          vector,
          payload: {
            title,
            domain: domain || 'general',
            classification: classification || 'project',
            date: date || new Date().toISOString().slice(0, 10),
            author: author || '',
            namespace,
            tags: tags || [],
            content_preview: content.slice(0, 300),
            ...(metadata || {}),
          },
        },
      ],
    });

    res.json({ id, namespace });
  } catch (err) {
    console.error('POST /entries:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// POST /search — semantic search with namespace + scope support
app.post('/search', async (req, res) => {
  try {
    const { query, namespace, scope = 'project', min_score = 0.6, limit = 10, domain } = req.body;
    if (!query) return res.status(400).json({ error: 'query is required' });

    const vector = await embed(query);

    let namespaces = [];
    if (scope === 'project' && namespace) namespaces = [namespace];
    else if (scope === 'global') namespaces = ['global'];
    else if (scope === 'all' && namespace) namespaces = [namespace, 'global'];
    else namespaces = [namespace || 'global'];
    namespaces = [...new Set(namespaces)];

    const { collections } = await qdrant.getCollections();
    const existingNames = new Set(collections.map((c) => c.name));

    const results = [];
    for (const ns of namespaces) {
      if (!existingNames.has(ns)) continue;
      const filter = domain
        ? { must: [{ key: 'domain', match: { value: domain } }] }
        : undefined;
      const hits = await qdrant.search(ns, {
        vector,
        limit: parseInt(limit),
        score_threshold: parseFloat(min_score),
        with_payload: true,
        filter,
      });
      results.push(...hits.map((h) => ({ id: h.id, score: h.score, namespace: ns, ...h.payload })));
    }

    results.sort((a, b) => b.score - a.score);
    res.json(results.slice(0, limit));
  } catch (err) {
    console.error('POST /search:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// GET /entries?namespace=&domain=&limit=50 — list entries
app.get('/entries', async (req, res) => {
  try {
    const { namespace, domain, limit = '50' } = req.query;
    if (!namespace) return res.status(400).json({ error: 'namespace query param required' });

    await ensureCollection(namespace);
    const filter = domain
      ? { must: [{ key: 'domain', match: { value: domain } }] }
      : undefined;
    const result = await qdrant.scroll(namespace, {
      limit: parseInt(limit),
      with_payload: true,
      filter,
    });
    res.json(result.points.map((p) => ({ id: p.id, ...p.payload })));
  } catch (err) {
    console.error('GET /entries:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// DELETE /entries/:id?namespace= — delete an entry
app.delete('/entries/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { namespace } = req.query;
    if (!namespace) return res.status(400).json({ error: 'namespace query param required' });
    await qdrant.delete(namespace, { wait: true, points: [id] });
    res.json({ deleted: id, namespace });
  } catch (err) {
    console.error('DELETE /entries:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// POST /reindex — drop and recreate a namespace collection (used before bulk re-push)
app.post('/reindex', async (req, res) => {
  try {
    const { namespace } = req.body;
    if (!namespace) return res.status(400).json({ error: 'namespace is required' });
    const { collections } = await qdrant.getCollections();
    if (collections.some((c) => c.name === namespace)) {
      await qdrant.deleteCollection(namespace);
    }
    await qdrant.createCollection(namespace, {
      vectors: { size: VECTOR_SIZE, distance: 'Cosine' },
    });
    res.json({ status: 'ready', namespace });
  } catch (err) {
    console.error('POST /reindex:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// POST /debug — raw similarity scores for diagnostics
app.post('/debug', async (req, res) => {
  try {
    const { query, namespace } = req.body;
    if (!query || !namespace) {
      return res.status(400).json({ error: 'query and namespace are required' });
    }
    const vector = await embed(query);
    const { collections } = await qdrant.getCollections();
    if (!collections.some((c) => c.name === namespace)) return res.json([]);
    const hits = await qdrant.search(namespace, {
      vector,
      limit: 20,
      score_threshold: 0,
      with_payload: true,
    });
    res.json(hits.map((h) => ({ score: h.score, id: h.id, title: h.payload?.title })));
  } catch (err) {
    console.error('POST /debug:', err.message);
    res.status(500).json({ error: err.message });
  }
});

app.get('/health', (_req, res) => res.json({ status: 'ok' }));

app.listen(PORT, () => console.log(`agentdb-api listening on :${PORT}`));
