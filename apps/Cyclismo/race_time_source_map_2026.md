# 2026 Race Time Source Map

Generated from `Cyclismo/bootstrap_database.json` plus source-system mapping.

## Coverage summary

- Total races: **82**
- With existing stream mapping in DB (`raceStreams`): **35**
- Without stream mapping in DB: **47**
- Series breakdown: UCI WorldTour **36**, UCI Women's WorldTour **27**, UCI World Championships **13**, Life Time Grand Prix **6**

## Source rules

- `raceSource`: primary lookup source for race start time-of-day (PCS search for road races; official event page for Life Time GP).
- `streamSources`: broadcaster pages to use for stream start windows when that race has known streamer coverage.
- `raceStartField`: expected from race page/schedule.
- `streamStartField`: conditional by broadcaster/region.

## Per-race mapping

| Race | Date | Series | raceSource | streamSources | Confidence |
| --- | --- | --- | --- | --- | --- |
| Santos Women's Tour Down Under | 2026-01-17 | UCI Women's WorldTour | https://www.procyclingstats.com/search.php?term=Santos%20Women%27s%20Tour%20Down%20Under%202026 |  | high |
| Santos Tour Down Under | 2026-01-20 | UCI WorldTour | https://www.procyclingstats.com/search.php?term=Santos%20Tour%20Down%20Under%202026 |  | high |
| Mapei Cadel Evans Great Ocean Road Race - Women | 2026-01-31 | UCI Women's WorldTour | https://www.procyclingstats.com/search.php?term=Mapei%20Cadel%20Evans%20Great%20Ocean%20Road%20Race%20-%20Women%202026 |  | high |
| Mapei Cadel Evans Great Ocean Road Race - Men | 2026-02-01 | UCI WorldTour | https://www.procyclingstats.com/search.php?term=Mapei%20Cadel%20Evans%20Great%20Ocean%20Road%20Race%20-%20Men%202026 |  | high |
| UAE Tour Women | 2026-02-05 | UCI Women's WorldTour | https://www.procyclingstats.com/search.php?term=UAE%20Tour%20Women%202026 | https://www.max.com/sports/cycling | high |
| UAE Tour | 2026-02-16 | UCI WorldTour | https://www.procyclingstats.com/search.php?term=UAE%20Tour%202026 | https://www.max.com/sports/cycling | high |
| Omloop Nieuwsblad | 2026-02-28 | UCI WorldTour | https://www.procyclingstats.com/search.php?term=Omloop%20Nieuwsblad%202026 | https://www.flobikes.com/events | high |
| Omloop Nieuwsblad | 2026-02-28 | UCI Women's WorldTour | https://www.procyclingstats.com/search.php?term=Omloop%20Nieuwsblad%202026 | https://www.flobikes.com/events | high |
| Strade Bianche | 2026-03-07 | UCI WorldTour | https://www.procyclingstats.com/search.php?term=Strade%20Bianche%202026 | https://www.max.com/sports/cycling | high |
| Strade Bianche Donne | 2026-03-07 | UCI Women's WorldTour | https://www.procyclingstats.com/search.php?term=Strade%20Bianche%20Donne%202026 | https://www.max.com/sports/cycling | high |
| Paris-Nice | 2026-03-08 | UCI WorldTour | https://www.procyclingstats.com/search.php?term=Paris-Nice%202026 | https://www.peacocktv.com/sports/cycling | high |
| Tirreno-Adriatico | 2026-03-09 | UCI WorldTour | https://www.procyclingstats.com/search.php?term=Tirreno-Adriatico%202026 | https://www.max.com/sports/cycling | high |
| Trofeo Alfredo Binda - Comune di Cittiglio | 2026-03-15 | UCI Women's WorldTour | https://www.procyclingstats.com/search.php?term=Trofeo%20Alfredo%20Binda%20-%20Comune%20di%20Cittiglio%202026 |  | high |
| Milano-Sanremo | 2026-03-21 | UCI WorldTour | https://www.procyclingstats.com/search.php?term=Milano-Sanremo%202026 |  | high |
| Milano-Sanremo Donne | 2026-03-21 | UCI Women's WorldTour | https://www.procyclingstats.com/search.php?term=Milano-Sanremo%20Donne%202026 |  | high |
| Volta Ciclista a Catalunya | 2026-03-23 | UCI WorldTour | https://www.procyclingstats.com/search.php?term=Volta%20Ciclista%20a%20Catalunya%202026 |  | high |
| Ronde Van Brugge - Tour of Bruges | 2026-03-25 | UCI WorldTour | https://www.procyclingstats.com/search.php?term=Ronde%20Van%20Brugge%20-%20Tour%20of%20Bruges%202026 |  | high |
| Ronde van Brugge - Tour of Bruges | 2026-03-26 | UCI Women's WorldTour | https://www.procyclingstats.com/search.php?term=Ronde%20van%20Brugge%20-%20Tour%20of%20Bruges%202026 |  | high |
| E3 Saxo Classic | 2026-03-27 | UCI WorldTour | https://www.procyclingstats.com/search.php?term=E3%20Saxo%20Classic%202026 |  | high |
| In Flanders Fields - From Middelkerke to Wevelgem | 2026-03-29 | UCI WorldTour | https://www.procyclingstats.com/search.php?term=In%20Flanders%20Fields%20-%20From%20Middelkerke%20to%20Wevelgem%202026 |  | high |
| In Flanders Fields - In Wevelgem | 2026-03-29 | UCI Women's WorldTour | https://www.procyclingstats.com/search.php?term=In%20Flanders%20Fields%20-%20In%20Wevelgem%202026 |  | high |
| Dwars door Vlaanderen - A travers la Flandre | 2026-04-01 | UCI WorldTour | https://www.procyclingstats.com/search.php?term=Dwars%20door%20Vlaanderen%20-%20A%20travers%20la%20Flandre%202026 | https://www.flobikes.com/events | high |
| Dwars door Vlaanderen / A travers la Flandre | 2026-04-01 | UCI Women's WorldTour | https://www.procyclingstats.com/search.php?term=Dwars%20door%20Vlaanderen%20/%20A%20travers%20la%20Flandre%202026 | https://www.flobikes.com/events | high |
| Ronde van Vlaanderen | 2026-04-05 | UCI WorldTour | https://www.procyclingstats.com/search.php?term=Ronde%20van%20Vlaanderen%202026 | https://www.flobikes.com/events | high |
| Ronde van Vlaanderen | 2026-04-05 | UCI Women's WorldTour | https://www.procyclingstats.com/search.php?term=Ronde%20van%20Vlaanderen%202026 | https://www.flobikes.com/events | high |
| Itzulia Basque Country | 2026-04-06 | UCI WorldTour | https://www.procyclingstats.com/search.php?term=Itzulia%20Basque%20Country%202026 |  | high |
| Paris-Roubaix Femmes Hauts-de-France | 2026-04-12 | UCI Women's WorldTour | https://www.procyclingstats.com/search.php?term=Paris-Roubaix%20Femmes%20Hauts-de-France%202026 | https://www.peacocktv.com/sports/cycling | high |
| Paris-Roubaix Hauts-de-France | 2026-04-12 | UCI WorldTour | https://www.procyclingstats.com/search.php?term=Paris-Roubaix%20Hauts-de-France%202026 | https://www.peacocktv.com/sports/cycling | high |
| Sea Otter Gravel | 2026-04-16 | Life Time Grand Prix | https://www.seaotterclassic.com/gravel/ |  | medium |
| Amstel Gold Race | 2026-04-19 | UCI WorldTour | https://www.procyclingstats.com/search.php?term=Amstel%20Gold%20Race%202026 | https://www.flobikes.com/events | high |
| Amstel Gold Race Ladies Edition | 2026-04-19 | UCI Women's WorldTour | https://www.procyclingstats.com/search.php?term=Amstel%20Gold%20Race%20Ladies%20Edition%202026 | https://www.flobikes.com/events | high |
| La Flèche Wallonne | 2026-04-22 | UCI WorldTour | https://www.procyclingstats.com/search.php?term=La%20Fl%C3%A8che%20Wallonne%202026 |  | high |
| La Flèche Wallonne Féminine | 2026-04-22 | UCI Women's WorldTour | https://www.procyclingstats.com/search.php?term=La%20Fl%C3%A8che%20Wallonne%20F%C3%A9minine%202026 |  | high |
| Liège-Bastogne-Liège | 2026-04-26 | UCI WorldTour | https://www.procyclingstats.com/search.php?term=Li%C3%A8ge-Bastogne-Li%C3%A8ge%202026 |  | high |
| Liège-Bastogne-Liège Femmes | 2026-04-26 | UCI Women's WorldTour | https://www.procyclingstats.com/search.php?term=Li%C3%A8ge-Bastogne-Li%C3%A8ge%20Femmes%202026 |  | high |
| Tour de Romandie | 2026-04-28 | UCI WorldTour | https://www.procyclingstats.com/search.php?term=Tour%20de%20Romandie%202026 |  | high |
| Eschborn-Frankfurt | 2026-05-01 | UCI WorldTour | https://www.procyclingstats.com/search.php?term=Eschborn-Frankfurt%202026 |  | high |
| Vuelta España Femenina by Carrefour.es | 2026-05-03 | UCI Women's WorldTour | https://www.procyclingstats.com/search.php?term=Vuelta%20Espa%C3%B1a%20Femenina%20by%20Carrefour.es%202026 | https://www.peacocktv.com/sports/cycling | high |
| Giro d'Italia | 2026-05-08 | UCI WorldTour | https://www.procyclingstats.com/search.php?term=Giro%20d%27Italia%202026 | https://www.max.com/sports/cycling | high |
| Itzulia Women | 2026-05-15 | UCI Women's WorldTour | https://www.procyclingstats.com/search.php?term=Itzulia%20Women%202026 |  | high |
| Vuelta a Burgos Feminas | 2026-05-21 | UCI Women's WorldTour | https://www.procyclingstats.com/search.php?term=Vuelta%20a%20Burgos%20Feminas%202026 |  | high |
| Giro d'Italia Women | 2026-05-30 | UCI Women's WorldTour | https://www.procyclingstats.com/search.php?term=Giro%20d%27Italia%20Women%202026 | https://www.max.com/sports/cycling | high |
| UNBOUND Gravel 200 | 2026-05-30 | Life Time Grand Prix | https://www.unboundgravel.com/ |  | medium |
| Tour Auvergne-Rhône-Alpes | 2026-06-07 | UCI WorldTour | https://www.procyclingstats.com/search.php?term=Tour%20Auvergne-Rh%C3%B4ne-Alpes%202026 |  | high |
| Copenhagen Sprint | 2026-06-13 | UCI Women's WorldTour | https://www.procyclingstats.com/search.php?term=Copenhagen%20Sprint%202026 |  | high |
| Copenhagen Sprint | 2026-06-14 | UCI WorldTour | https://www.procyclingstats.com/search.php?term=Copenhagen%20Sprint%202026 |  | high |
| Tour de Suisse | 2026-06-17 | UCI WorldTour | https://www.procyclingstats.com/search.php?term=Tour%20de%20Suisse%202026 |  | high |
| Tour de Suisse Women | 2026-06-17 | UCI Women's WorldTour | https://www.procyclingstats.com/search.php?term=Tour%20de%20Suisse%20Women%202026 |  | high |
| Tour de France | 2026-07-04 | UCI WorldTour | https://www.procyclingstats.com/search.php?term=Tour%20de%20France%202026 | https://www.peacocktv.com/sports/cycling | high |
| DSSK (Donostia San Sebastian Klasikoa) | 2026-08-01 | UCI WorldTour | https://www.procyclingstats.com/search.php?term=DSSK%20%28Donostia%20San%20Sebastian%20Klasikoa%29%202026 |  | high |
| Tour de France Femmes avec Zwift | 2026-08-01 | UCI Women's WorldTour | https://www.procyclingstats.com/search.php?term=Tour%20de%20France%20Femmes%20avec%20Zwift%202026 | https://www.peacocktv.com/sports/cycling | high |
| Tour de Pologne | 2026-08-03 | UCI WorldTour | https://www.procyclingstats.com/search.php?term=Tour%20de%20Pologne%202026 |  | high |
| Leadville Trail 100 MTB | 2026-08-15 | Life Time Grand Prix | https://www.leadvilleraceseries.com/mtb/leadvilletrail100mtb/ |  | medium |
| ADAC Cyclassics | 2026-08-16 | UCI WorldTour | https://www.procyclingstats.com/search.php?term=ADAC%20Cyclassics%202026 |  | high |
| Lloyds Tour of Britain Women | 2026-08-19 | UCI Women's WorldTour | https://www.procyclingstats.com/search.php?term=Lloyds%20Tour%20of%20Britain%20Women%202026 |  | high |
| Renewi Tour | 2026-08-19 | UCI WorldTour | https://www.procyclingstats.com/search.php?term=Renewi%20Tour%202026 |  | high |
| La Vuelta Ciclista a España | 2026-08-22 | UCI WorldTour | https://www.procyclingstats.com/search.php?term=La%20Vuelta%20Ciclista%20a%20Espa%C3%B1a%202026 |  | high |
| Classic Lorient Agglomération | 2026-08-29 | UCI Women's WorldTour | https://www.procyclingstats.com/search.php?term=Classic%20Lorient%20Agglom%C3%A9ration%202026 |  | high |
| Bretagne Classic - CIC | 2026-08-30 | UCI WorldTour | https://www.procyclingstats.com/search.php?term=Bretagne%20Classic%20-%20CIC%202026 | https://www.flobikes.com/events | high |
| Tour de Romandie Féminin | 2026-09-04 | UCI Women's WorldTour | https://www.procyclingstats.com/search.php?term=Tour%20de%20Romandie%20F%C3%A9minin%202026 |  | high |
| Grand Prix Cycliste de Québec | 2026-09-11 | UCI WorldTour | https://www.procyclingstats.com/search.php?term=Grand%20Prix%20Cycliste%20de%20Qu%C3%A9bec%202026 |  | high |
| Grand Prix Cycliste de Montréal | 2026-09-13 | UCI WorldTour | https://www.procyclingstats.com/search.php?term=Grand%20Prix%20Cycliste%20de%20Montr%C3%A9al%202026 |  | high |
| Chequamegon MTB Fest | 2026-09-19 | Life Time Grand Prix | https://www.cheqmtbfest.com/ |  | medium |
| World Championships ME - ITT | 2026-09-20 | UCI World Championships | https://www.procyclingstats.com/search.php?term=World%20Championships%20ME%20-%20ITT%202026 | https://www.flobikes.com/events | medium |
| World Championships WE - ITT | 2026-09-20 | UCI World Championships | https://www.procyclingstats.com/search.php?term=World%20Championships%20WE%20-%20ITT%202026 | https://www.flobikes.com/events | medium |
| World Championships MU - ITT | 2026-09-21 | UCI World Championships | https://www.procyclingstats.com/search.php?term=World%20Championships%20MU%20-%20ITT%202026 | https://www.flobikes.com/events | medium |
| World Championships WU - ITT | 2026-09-21 | UCI World Championships | https://www.procyclingstats.com/search.php?term=World%20Championships%20WU%20-%20ITT%202026 | https://www.flobikes.com/events | medium |
| World Championships - Mixed Relay TTT | 2026-09-22 | UCI World Championships | https://www.procyclingstats.com/search.php?term=World%20Championships%20-%20Mixed%20Relay%20TTT%202026 | https://www.flobikes.com/events | medium |
| World Championships MJ - ITT | 2026-09-22 | UCI World Championships | https://www.procyclingstats.com/search.php?term=World%20Championships%20MJ%20-%20ITT%202026 | https://www.flobikes.com/events | medium |
| World Championships WJ - ITT | 2026-09-22 | UCI World Championships | https://www.procyclingstats.com/search.php?term=World%20Championships%20WJ%20-%20ITT%202026 | https://www.flobikes.com/events | medium |
| World Championships MJ - Road Race | 2026-09-24 | UCI World Championships | https://www.procyclingstats.com/search.php?term=World%20Championships%20MJ%20-%20Road%20Race%202026 | https://www.flobikes.com/events | medium |
| World Championships WU - Road Race | 2026-09-24 | UCI World Championships | https://www.procyclingstats.com/search.php?term=World%20Championships%20WU%20-%20Road%20Race%202026 | https://www.flobikes.com/events | medium |
| World Championships MU - Road Race | 2026-09-25 | UCI World Championships | https://www.procyclingstats.com/search.php?term=World%20Championships%20MU%20-%20Road%20Race%202026 | https://www.flobikes.com/events | medium |
| World Championships WJ - Road Race | 2026-09-25 | UCI World Championships | https://www.procyclingstats.com/search.php?term=World%20Championships%20WJ%20-%20Road%20Race%202026 | https://www.flobikes.com/events | medium |
| World Championships WE - Road Race | 2026-09-26 | UCI World Championships | https://www.procyclingstats.com/search.php?term=World%20Championships%20WE%20-%20Road%20Race%202026 | https://www.flobikes.com/events | medium |
| World Championships ME - Road Race | 2026-09-27 | UCI World Championships | https://www.procyclingstats.com/search.php?term=World%20Championships%20ME%20-%20Road%20Race%202026 | https://www.flobikes.com/events | medium |
| Il Lombardia | 2026-10-10 | UCI WorldTour | https://www.procyclingstats.com/search.php?term=Il%20Lombardia%202026 |  | high |
| Little Sugar MTB | 2026-10-11 | Life Time Grand Prix | https://www.littlesugarmtb.com/ |  | medium |
| Tour of Chongming Island | 2026-10-13 | UCI Women's WorldTour | https://www.procyclingstats.com/search.php?term=Tour%20of%20Chongming%20Island%202026 |  | high |
| Tour of Guangxi | 2026-10-13 | UCI WorldTour | https://www.procyclingstats.com/search.php?term=Tour%20of%20Guangxi%202026 |  | high |
| Big Sugar Gravel | 2026-10-17 | Life Time Grand Prix | https://www.bigsugargravel.com/ |  | medium |
| Tour of Guangxi Women's WorldTour | 2026-10-18 | UCI Women's WorldTour | https://www.procyclingstats.com/search.php?term=Tour%20of%20Guangxi%20Women%27s%20WorldTour%202026 |  | high |
