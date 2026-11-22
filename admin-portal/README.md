# MindPal Admin Portal

Admin website for MindPal (PTUT-PRJ-056). React + Vite + TypeScript, charts with Recharts.
It shows counts only. It never shows journal or reflection text.

## Run locally
1. Start the backend (`dotnet run` in `backend/MindPal.Api`) with `Admin:Email` and `Admin:Password` set in user secrets.
2. In this folder:
   ```
   npm install
   npm run dev
   ```
3. Open http://localhost:5173 and sign in with the admin account.

The API address is read from `VITE_API_BASE_URL` (default `http://localhost:5141`). Copy `.env.example` to `.env` to change it.

## Sample-data mode (no server)
`VITE_MOCK=1 npm run dev` shows the portal with made-up data. Used only for screenshots.

## Deploy (Vercel)
- Framework: Vite. Build command `npm run build`, output `dist` (already in `vercel.json`).
- Set `VITE_API_BASE_URL` to the deployed API address.
- On the API, set `Cors:AdminOrigins` to the portal address (for example `https://mindpal-admin.vercel.app`).

## Security notes
- Only accounts with the `admin` role can sign in; others are signed out at once.
- The access token is kept in memory; the refresh token in sessionStorage (cleared when the tab closes).
- The server checks the admin role again on every request.
