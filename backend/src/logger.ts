import winston from 'winston';
import { OpenTelemetryTransportV3 } from '@opentelemetry/winston-transport';

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console(),
    new OpenTelemetryTransportV3({ level: 'info' }),
  ],
});

export default logger;
