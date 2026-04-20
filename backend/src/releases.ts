export interface JordanRelease {
  id: number;
  name: string;
  releaseDate: string | null; // ISO date string, null if TBD
  tbd: boolean;
}

export const releases: JordanRelease[] = [
  { id: 1,  name: "Jordan 6 Cap & Gown",       releaseDate: "2026-04-02", tbd: false },
  { id: 2,  name: "Jordan 4 Toro Bravo",        releaseDate: "2026-05-02", tbd: false },
  { id: 3,  name: "Jordan 4 Nigel Sylvester",   releaseDate: "2026-05-09", tbd: false },
  { id: 4,  name: "Jordan 1 Low Bred",          releaseDate: "2026-05-16", tbd: false },
  { id: 5,  name: "Jordan 3 True Blue",         releaseDate: "2026-07-18", tbd: false },
  { id: 6,  name: "Jordan 6 Oreo",              releaseDate: null,         tbd: true  },
  { id: 7,  name: "Jordan 8 Chrome",            releaseDate: "2026-09-12", tbd: false },
  { id: 8,  name: "Jordan 1 Royal Blue",        releaseDate: "2026-10-10", tbd: false },
  { id: 9,  name: "Jordan 6 White Infrared",    releaseDate: "2026-11-07", tbd: false },
  { id: 10, name: "Jordan 4 Bred",              releaseDate: "2026-11-26", tbd: false },
  { id: 11, name: "Jordan 11 Space Jams",       releaseDate: "2026-12-12", tbd: false },
];
