# Streaming Fallback Updates - March 2026

## Summary
Fixed missing race streamers by adding fallback rules for races on Max and FloBikes streaming services.

## Problem
Trofeo Alfredo Binda and 15 other races in March-April 2026 were missing streaming information, even though they are available on Max or FloBikes in the USA.

## Solution
Updated `ingestion/src/runStreamingIngestion.ts` with expanded fallback rules.

## Changes Made

### Max Streaming (HBO Max)
Added the following races to Max fallback rules:
- **Trofeo Alfredo Binda** - Women's WorldTour race
- **Milano-Sanremo Donne** - Women's Monument
- **Nokere Koerse** - Belgian one-day race
- **Milano-Torino** - Italian classic
- **E3 Saxo Classic** - Belgian cobbled classic
- **Bredene Koksijde Classic** - Belgian race
- **Grand Prix de Denain** - French one-day race
- **Itzulia Basque Country** - Spanish stage race
- **Ronde van Brugge** - Belgian race

### FloBikes Streaming
Added the following races to FloBikes fallback rules:
- **In Flanders Fields / Gent-Wevelgem** - Belgian cobbled classic
- **Volta Ciclista a Catalunya** - Spanish stage race
- **La Flèche Wallonne** - Ardennes classic
- **Liège-Bastogne-Liège** - Monument classic
- **Tour de Romandie** - Swiss stage race

## Races Fixed (Previously Missing Streamers)

### Now on Max (HBO Max)
1. Trofeo Alfredo Binda - Comune di Cittiglio (Women) - March 15, 2026
2. Milano-Sanremo Donne (Women) - March 21, 2026
3. Ronde Van Brugge - Tour of Bruges (Men) - March 25, 2026
4. Ronde van Brugge - Tour of Bruges (Women) - March 26, 2026
5. E3 Saxo Classic (Men) - March 27, 2026
6. Itzulia Basque Country (Men) - April 6, 2026

### Now on FloBikes
1. In Flanders Fields - From Middelkerke to Wevelgem (Men) - March 29, 2026
2. In Flanders Fields - In Wevelgem (Women) - March 29, 2026
3. Volta Ciclista a Catalunya (Men) - March 23, 2026
4. La Flèche Wallonne (Men) - April 22, 2026
5. La Flèche Wallonne Féminine (Women) - April 22, 2026
6. Liège-Bastogne-Liège (Men) - April 26, 2026
7. Liège-Bastogne-Liège Femmes (Women) - April 26, 2026
8. Tour de Romandie (Men) - April 28, 2026

### Already Had Streamers (No Change Needed)
- Milano-Sanremo (Men) - Already matched via Max "milano-san remo" pattern
- Other races already matched by existing patterns

## Testing
After running `npm run bootstrap` in the ingestion folder, all races should now have streaming information populated in the `race_streams` table.

## Notes
- These are fallback rules that apply when the streaming scrapers don't find a match
- The rules use regex patterns to match race names flexibly (handling different spellings, accents, etc.)
- All rules are region-specific for USA (and Canada for FloBikes)
- Max rules cover races typically on HBO Max in the USA
- FloBikes rules cover international cycling races available on FloBikes subscription

## File Changed
- `ingestion/src/runStreamingIngestion.ts`
