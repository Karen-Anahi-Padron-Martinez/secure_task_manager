'use strict';

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const pinoHttp = require('pino-http');
const { getAllowedOrigins } = require('./config');
const { errorHandler } = require('./middleware/error.middleware');
const authRoutes = require('./routes/auth.routes');
const taskRoutes = require('./routes/task.routes');

const app = express();
const allowedOrigins = getAllowedOrigins();

app.disable('x-powered-by');
app.use(helmet());
app.use(express.json({ limit: '20kb' }));

app.use(cors({
  origin(origin, callback) {
    // No Origin can occur for native apps and local command-line clients.
    if (!origin || allowedOrigins.has(origin)) return callback(null, true);
    // Allow any localhost / 127.0.0.1 port in development (e.g. Flutter Web dev server)
    if (process.env.NODE_ENV === 'development' && /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin)) {
      return callback(null, true);
    }
    return callback(new Error('Origin not allowed.'));
  },
  methods: ['GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

app.use(pinoHttp({
  redact: [
    'req.headers.authorization',
    'req.headers.cookie',
    'req.body.password',
    'req.body.refreshToken',
    'req.query.token',
  ],
  serializers: {
    req(request) {
      return { method: request.method, url: request.url };
    },
  },
}));

app.get('/health', (_req, res) => res.status(200).json({ status: 'ok' }));
app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/tasks', taskRoutes);
app.use(errorHandler);

module.exports = { app };
