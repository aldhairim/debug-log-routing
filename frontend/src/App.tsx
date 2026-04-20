import { useEffect, useState } from 'react';
import { CountdownCard } from './components/CountdownCard';
import { JordanRelease } from './types';

export default function App() {
  const [releases, setReleases] = useState<JordanRelease[]>([]);
  const [error, setError] = useState(false);

  useEffect(() => {
    fetch('/api/releases')
      .then((res) => res.json())
      .then(setReleases)
      .catch(() => setError(true));
  }, []);

  return (
    <div className="app">
      <header className="header">
        <h1>Jordan 2026 Releases</h1>
        <p>Countdowns to every drop this year</p>
      </header>
      <main className="grid">
        {error && <p className="error">Failed to load releases.</p>}
        {releases.map((release) => (
          <CountdownCard key={release.id} release={release} />
        ))}
      </main>
    </div>
  );
}
