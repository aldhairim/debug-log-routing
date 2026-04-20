import './tracing';

import express from 'express';
import cors from 'cors';
import { releases } from './releases';
import logger from './logger';

const app = express();
const PORT = process.env.PORT || 3001;

app.use(cors());
app.use(express.json());

app.use((req, _res, next) => {
  logger.info('incoming request', { method: req.method, path: req.path });
  logger.debug('request headers', { headers: req.headers });
  next();
});

app.get('/health', (_req, res) => {
  logger.debug('health check');
  res.json({ status: 'ok' });
});

app.get('/api/releases', (_req, res) => {
  logger.info('fetching releases', { count: releases.length });
  logger.debug('releases response', { releases });
  res.json(releases);
});

app.listen(PORT, () => {
  logger.info(`jordan-countdown-backend listening on port ${PORT}`);
});
