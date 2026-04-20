import { useEffect, useState } from 'react';
import { JordanRelease } from '../types';

interface TimeLeft {
  days: number;
  hours: number;
  minutes: number;
  seconds: number;
}

function getTimeLeft(releaseDate: string): TimeLeft {
  const diff = new Date(releaseDate).getTime() - Date.now();
  if (diff <= 0) return { days: 0, hours: 0, minutes: 0, seconds: 0 };
  return {
    days: Math.floor(diff / (1000 * 60 * 60 * 24)),
    hours: Math.floor((diff / (1000 * 60 * 60)) % 24),
    minutes: Math.floor((diff / (1000 * 60)) % 60),
    seconds: Math.floor((diff / 1000) % 60),
  };
}

function pad(n: number) {
  return String(n).padStart(2, '0');
}

export function CountdownCard({ release }: { release: JordanRelease }) {
  const [timeLeft, setTimeLeft] = useState<TimeLeft | null>(
    release.releaseDate ? getTimeLeft(release.releaseDate) : null
  );

  useEffect(() => {
    if (!release.releaseDate) return;
    const interval = setInterval(() => {
      setTimeLeft(getTimeLeft(release.releaseDate!));
    }, 1000);
    return () => clearInterval(interval);
  }, [release.releaseDate]);

  const releaseLabel = release.tbd
    ? 'Date TBD'
    : new Date(release.releaseDate! + 'T00:00:00').toLocaleDateString('en-US', {
        month: 'long',
        day: 'numeric',
        year: 'numeric',
      });

  return (
    <div className="card">
      <div className="card-name">{release.name}</div>
      <div className="card-date">{releaseLabel}</div>
      {release.tbd || !timeLeft ? (
        <div className="card-tbd">Stay tuned</div>
      ) : (
        <div className="countdown">
          <div className="unit">
            <span className="value">{timeLeft.days}</span>
            <span className="label">days</span>
          </div>
          <div className="unit">
            <span className="value">{pad(timeLeft.hours)}</span>
            <span className="label">hrs</span>
          </div>
          <div className="unit">
            <span className="value">{pad(timeLeft.minutes)}</span>
            <span className="label">min</span>
          </div>
          <div className="unit">
            <span className="value">{pad(timeLeft.seconds)}</span>
            <span className="label">sec</span>
          </div>
        </div>
      )}
    </div>
  );
}
