import { initializeFaro, getWebInstrumentations } from '@grafana/faro-web-sdk';
import { TracingInstrumentation } from '@grafana/faro-web-tracing';
import { createRoot } from 'react-dom/client';
import App from './App';
import './index.css';

const faroUrl = import.meta.env.VITE_FARO_URL;

if (faroUrl) {
  initializeFaro({
    url: faroUrl,
    app: {
      name: 'jordan-countdown-frontend',
      version: '1.0.0',
      environment: import.meta.env.MODE,
    },
    instrumentations: [
      ...getWebInstrumentations({ captureConsole: true }),
      new TracingInstrumentation(),
    ],
  });
}

createRoot(document.getElementById('root')!).render(<App />);
