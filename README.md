## Vercel deployment

Steps:

1. Create Vercel project from this repo (`nniikk99/t-company-service`).
2. Framework preset: "Other".
3. Build Command: `npm run vercel-build`
4. Output Directory: `build/web`
5. Environment Variables:
   - `SUPABASE_URL` = https://kwunhuzfnjpcoeusnxzy.supabase.co
   - `SUPABASE_ANON_KEY` = <your_anon_key>
   - `FLUTTER_BASE_HREF` = /
6. Deploy. The site will be served at `https://<project>.vercel.app`.

Then update BotFather Mini App URL to the new domain.


