import type { RaceInput } from "../normalize.js";

type RawRace = {
  date: string;
  name: string;
  classification: string;
  gender: string | null;
  series: string;
};

type RaceLocation = {
  country: string | null;
  city: string | null;
};

const raceLocations: Record<string, RaceLocation> = {
  "World Championships ME - ITT": { country: "Canada", city: "Montreal, QC" },
  "World Championships WE - ITT": { country: "Canada", city: "Montreal, QC" },
  "World Championships MU - ITT": { country: "Canada", city: "Montreal, QC" },
  "World Championships WU - ITT": { country: "Canada", city: "Montreal, QC" },
  "World Championships - Mixed Relay TTT": { country: "Canada", city: "Montreal, QC" },
  "World Championships MJ - ITT": { country: "Canada", city: "Montreal, QC" },
  "World Championships WJ - ITT": { country: "Canada", city: "Montreal, QC" },
  "World Championships MJ - Road Race": { country: "Canada", city: "Montreal, QC" },
  "World Championships WU - Road Race": { country: "Canada", city: "Montreal, QC" },
  "World Championships MU - Road Race": { country: "Canada", city: "Montreal, QC" },
  "World Championships WJ - Road Race": { country: "Canada", city: "Montreal, QC" },
  "World Championships WE - Road Race": { country: "Canada", city: "Montreal, QC" },
  "World Championships ME - Road Race": { country: "Canada", city: "Montreal, QC" },
  "Santos Tour Down Under": { country: "Australia", city: "Adelaide, SA" },
  "Santos Women's Tour Down Under": { country: "Australia", city: "Adelaide, SA" },
  "Mapei Cadel Evans Great Ocean Road Race - Men": {
    country: "Australia",
    city: "Geelong, VIC"
  },
  "Mapei Cadel Evans Great Ocean Road Race - Women": {
    country: "Australia",
    city: "Geelong, VIC"
  },
  "UAE Tour": { country: "United Arab Emirates", city: "Abu Dhabi" },
  "UAE Tour Women": { country: "United Arab Emirates", city: "Abu Dhabi" },
  "Omloop Nieuwsblad": { country: "Belgium", city: "Ghent" },
  "Strade Bianche": { country: "Italy", city: "Siena" },
  "Strade Bianche Donne": { country: "Italy", city: "Siena" },
  "Paris-Nice": { country: "France", city: "Paris to Nice" },
  "Tirreno-Adriatico": { country: "Italy", city: "Italy" },
  "Milano-Sanremo": { country: "Italy", city: "Milan to Sanremo" },
  "Milano-Sanremo Donne": { country: "Italy", city: "Milan to Sanremo" },
  "Volta Ciclista a Catalunya": { country: "Spain", city: "Catalonia" },
  "Ronde Van Brugge - Tour of Bruges": { country: "Belgium", city: "Bruges" },
  "E3 Saxo Classic": { country: "Belgium", city: "Harelbeke" },
  "In Flanders Fields - From Middelkerke to Wevelgem": {
    country: "Belgium",
    city: "Middelkerke to Wevelgem"
  },
  "In Flanders Fields - In Wevelgem": { country: "Belgium", city: "Wevelgem" },
  "Dwars door Vlaanderen - A travers la Flandre": {
    country: "Belgium",
    city: "Waregem"
  },
  "Dwars door Vlaanderen / A travers la Flandre": {
    country: "Belgium",
    city: "Waregem"
  },
  "Ronde van Vlaanderen": { country: "Belgium", city: "Oudenaarde" },
  "Itzulia Basque Country": { country: "Spain", city: "Basque Country" },
  "Itzulia Women": { country: "Spain", city: "Basque Country" },
  "Paris-Roubaix Hauts-de-France": { country: "France", city: "Roubaix" },
  "Paris-Roubaix Femmes Hauts-de-France": { country: "France", city: "Roubaix" },
  "Amstel Gold Race": { country: "Netherlands", city: "Valkenburg" },
  "Amstel Gold Race Ladies Edition": { country: "Netherlands", city: "Valkenburg" },
  "La Flèche Wallonne": { country: "Belgium", city: "Huy" },
  "La Flèche Wallonne Féminine": { country: "Belgium", city: "Huy" },
  "Liège-Bastogne-Liège": { country: "Belgium", city: "Liège" },
  "Liège-Bastogne-Liège Femmes": { country: "Belgium", city: "Liège" },
  "Tour de Romandie": { country: "Switzerland", city: "Romandy" },
  "Tour de Romandie Féminin": { country: "Switzerland", city: "Romandy" },
  "Eschborn-Frankfurt": { country: "Germany", city: "Frankfurt" },
  "Giro d'Italia": { country: "Italy", city: "Italy" },
  "Giro d'Italia Women": { country: "Italy", city: "Italy" },
  "Tour Auvergne-Rhône-Alpes": {
    country: "France",
    city: "Auvergne-Rhone-Alpes"
  },
  "Copenhagen Sprint": { country: "Denmark", city: "Copenhagen" },
  "Tour de Suisse": { country: "Switzerland", city: "Switzerland" },
  "Tour de Suisse Women": { country: "Switzerland", city: "Switzerland" },
  "Tour de France": { country: "France", city: "France" },
  "Tour de France Femmes avec Zwift": { country: "France", city: "France" },
  "DSSK (Donostia San Sebastian Klasikoa)": {
    country: "Spain",
    city: "San Sebastian"
  },
  "Tour de Pologne": { country: "Poland", city: "Poland" },
  "ADAC Cyclassics": { country: "Germany", city: "Hamburg" },
  "Renewi Tour": { country: "Belgium", city: "Benelux" },
  "La Vuelta Ciclista a España": { country: "Spain", city: "Spain" },
  "Bretagne Classic - CIC": { country: "France", city: "Plouay" },
  "Grand Prix Cycliste de Québec": { country: "Canada", city: "Quebec City, QC" },
  "Grand Prix Cycliste de Montréal": { country: "Canada", city: "Montreal, QC" },
  "Il Lombardia": { country: "Italy", city: "Como" },
  "Tour of Guangxi": { country: "China", city: "Guangxi" },
  "Tour of Guangxi Women's WorldTour": { country: "China", city: "Guangxi" },
  "Trofeo Alfredo Binda - Comune di Cittiglio": {
    country: "Italy",
    city: "Cittiglio"
  },
  "Vuelta España Femenina by Carrefour.es": { country: "Spain", city: "Spain" },
  "Vuelta a Burgos Feminas": { country: "Spain", city: "Burgos" },
  "Lloyds Tour of Britain Women": { country: "United Kingdom", city: "Great Britain" },
  "Classic Lorient Agglomération": { country: "France", city: "Lorient" },
  "Tour of Chongming Island": { country: "China", city: "Chongming Island" }
};

const resolveLocation = (name: string): RaceLocation => {
  return raceLocations[name] ?? { country: null, city: null };
};

const parseDateRange = (value: string, year: number) => {
  const parts = value.split("-").map((part) => part.trim());
  const parsePart = (part: string, defaultMonth?: string) => {
    const match = part.match(/(\d{1,2})\.(\d{1,2})/);
    if (!match) return null;
    const day = match[1].padStart(2, "0");
    const month = match[2]?.padStart(2, "0") ?? defaultMonth;
    if (!month) return null;
    return `${year}-${month}-${day}`;
  };
  const start = parsePart(parts[0]);
  const end = parts.length > 1 ? parsePart(parts[1], start?.slice(5, 7)) : start;
  if (!start || !end) return null;
  return { start, end };
};

const mapToRace = (raw: RawRace, year: number): RaceInput | null => {
  const parsed = parseDateRange(raw.date, year);
  if (!parsed) return null;
  const location = resolveLocation(raw.name);
  return {
    name: raw.name,
    series: raw.series,
    classification: raw.classification,
    discipline: "Road",
    raceType: parsed.start === parsed.end ? "One-day" : "Stage race",
    startDate: parsed.start,
    endDate: parsed.end,
    locationCountry: location.country,
    locationCity: location.city,
    organizer: "UCI",
    officialWebsite: null,
    genderDivision: raw.gender
  };
};

const worldChampionships: RawRace[] = [
  { date: "20.09", name: "World Championships ME - ITT", classification: "WC", gender: "Men", series: "UCI World Championships" },
  { date: "20.09", name: "World Championships WE - ITT", classification: "WC", gender: "Women", series: "UCI World Championships" },
  { date: "21.09", name: "World Championships MU - ITT", classification: "WC", gender: "Men U23", series: "UCI World Championships" },
  { date: "21.09", name: "World Championships WU - ITT", classification: "WC", gender: "Women U23", series: "UCI World Championships" },
  { date: "22.09", name: "World Championships - Mixed Relay TTT", classification: "WC", gender: "Mixed", series: "UCI World Championships" },
  { date: "22.09", name: "World Championships MJ - ITT", classification: "WC", gender: "Men Junior", series: "UCI World Championships" },
  { date: "22.09", name: "World Championships WJ - ITT", classification: "WC", gender: "Women Junior", series: "UCI World Championships" },
  { date: "24.09", name: "World Championships MJ - Road Race", classification: "WC", gender: "Men Junior", series: "UCI World Championships" },
  { date: "24.09", name: "World Championships WU - Road Race", classification: "WC", gender: "Women U23", series: "UCI World Championships" },
  { date: "25.09", name: "World Championships MU - Road Race", classification: "WC", gender: "Men U23", series: "UCI World Championships" },
  { date: "25.09", name: "World Championships WJ - Road Race", classification: "WC", gender: "Women Junior", series: "UCI World Championships" },
  { date: "26.09", name: "World Championships WE - Road Race", classification: "WC", gender: "Women", series: "UCI World Championships" },
  { date: "27.09", name: "World Championships ME - Road Race", classification: "WC", gender: "Men", series: "UCI World Championships" }
];

const worldTourMen: RawRace[] = [
  { date: "20.01 - 25.01", name: "Santos Tour Down Under", classification: "2.UWT", gender: "Men", series: "UCI WorldTour" },
  { date: "01.02", name: "Mapei Cadel Evans Great Ocean Road Race - Men", classification: "1.UWT", gender: "Men", series: "UCI WorldTour" },
  { date: "16.02 - 22.02", name: "UAE Tour", classification: "2.UWT", gender: "Men", series: "UCI WorldTour" },
  { date: "28.02", name: "Omloop Nieuwsblad", classification: "1.UWT", gender: "Men", series: "UCI WorldTour" },
  { date: "07.03", name: "Strade Bianche", classification: "1.UWT", gender: "Men", series: "UCI WorldTour" },
  { date: "08.03 - 15.03", name: "Paris-Nice", classification: "2.UWT", gender: "Men", series: "UCI WorldTour" },
  { date: "09.03 - 15.03", name: "Tirreno-Adriatico", classification: "2.UWT", gender: "Men", series: "UCI WorldTour" },
  { date: "21.03", name: "Milano-Sanremo", classification: "1.UWT", gender: "Men", series: "UCI WorldTour" },
  { date: "23.03 - 29.03", name: "Volta Ciclista a Catalunya", classification: "2.UWT", gender: "Men", series: "UCI WorldTour" },
  { date: "25.03", name: "Ronde Van Brugge - Tour of Bruges", classification: "1.UWT", gender: "Men", series: "UCI WorldTour" },
  { date: "27.03", name: "E3 Saxo Classic", classification: "1.UWT", gender: "Men", series: "UCI WorldTour" },
  { date: "29.03", name: "In Flanders Fields - From Middelkerke to Wevelgem", classification: "1.UWT", gender: "Men", series: "UCI WorldTour" },
  { date: "01.04", name: "Dwars door Vlaanderen - A travers la Flandre", classification: "1.UWT", gender: "Men", series: "UCI WorldTour" },
  { date: "05.04", name: "Ronde van Vlaanderen", classification: "1.UWT", gender: "Men", series: "UCI WorldTour" },
  { date: "06.04 - 11.04", name: "Itzulia Basque Country", classification: "2.UWT", gender: "Men", series: "UCI WorldTour" },
  { date: "12.04", name: "Paris-Roubaix Hauts-de-France", classification: "1.UWT", gender: "Men", series: "UCI WorldTour" },
  { date: "19.04", name: "Amstel Gold Race", classification: "1.UWT", gender: "Men", series: "UCI WorldTour" },
  { date: "22.04", name: "La Flèche Wallonne", classification: "1.UWT", gender: "Men", series: "UCI WorldTour" },
  { date: "26.04", name: "Liège-Bastogne-Liège", classification: "1.UWT", gender: "Men", series: "UCI WorldTour" },
  { date: "28.04 - 03.05", name: "Tour de Romandie", classification: "2.UWT", gender: "Men", series: "UCI WorldTour" },
  { date: "01.05", name: "Eschborn-Frankfurt", classification: "1.UWT", gender: "Men", series: "UCI WorldTour" },
  { date: "08.05 - 31.05", name: "Giro d'Italia", classification: "2.UWT", gender: "Men", series: "UCI WorldTour" },
  { date: "07.06 - 14.06", name: "Tour Auvergne-Rhône-Alpes", classification: "2.UWT", gender: "Men", series: "UCI WorldTour" },
  { date: "14.06", name: "Copenhagen Sprint", classification: "1.UWT", gender: "Men", series: "UCI WorldTour" },
  { date: "17.06 - 21.06", name: "Tour de Suisse", classification: "2.UWT", gender: "Men", series: "UCI WorldTour" },
  { date: "04.07 - 26.07", name: "Tour de France", classification: "2.UWT", gender: "Men", series: "UCI WorldTour" },
  { date: "01.08", name: "DSSK (Donostia San Sebastian Klasikoa)", classification: "1.UWT", gender: "Men", series: "UCI WorldTour" },
  { date: "03.08 - 09.08", name: "Tour de Pologne", classification: "2.UWT", gender: "Men", series: "UCI WorldTour" },
  { date: "16.08", name: "ADAC Cyclassics", classification: "1.UWT", gender: "Men", series: "UCI WorldTour" },
  { date: "19.08 - 23.08", name: "Renewi Tour", classification: "2.UWT", gender: "Men", series: "UCI WorldTour" },
  { date: "22.08 - 13.09", name: "La Vuelta Ciclista a España", classification: "2.UWT", gender: "Men", series: "UCI WorldTour" },
  { date: "30.08", name: "Bretagne Classic - CIC", classification: "1.UWT", gender: "Men", series: "UCI WorldTour" },
  { date: "11.09", name: "Grand Prix Cycliste de Québec", classification: "1.UWT", gender: "Men", series: "UCI WorldTour" },
  { date: "13.09", name: "Grand Prix Cycliste de Montréal", classification: "1.UWT", gender: "Men", series: "UCI WorldTour" },
  { date: "10.10", name: "Il Lombardia", classification: "1.UWT", gender: "Men", series: "UCI WorldTour" },
  { date: "13.10 - 18.10", name: "Tour of Guangxi", classification: "2.UWT", gender: "Men", series: "UCI WorldTour" }
];

const worldTourWomen: RawRace[] = [
  { date: "17.01 - 19.01", name: "Santos Women's Tour Down Under", classification: "2.WWT", gender: "Women", series: "UCI Women's WorldTour" },
  { date: "31.01", name: "Mapei Cadel Evans Great Ocean Road Race - Women", classification: "1.WWT", gender: "Women", series: "UCI Women's WorldTour" },
  { date: "05.02 - 08.02", name: "UAE Tour Women", classification: "2.WWT", gender: "Women", series: "UCI Women's WorldTour" },
  { date: "28.02", name: "Omloop Nieuwsblad", classification: "1.WWT", gender: "Women", series: "UCI Women's WorldTour" },
  { date: "07.03", name: "Strade Bianche Donne", classification: "1.WWT", gender: "Women", series: "UCI Women's WorldTour" },
  { date: "15.03", name: "Trofeo Alfredo Binda - Comune di Cittiglio", classification: "1.WWT", gender: "Women", series: "UCI Women's WorldTour" },
  { date: "21.03", name: "Milano-Sanremo Donne", classification: "1.WWT", gender: "Women", series: "UCI Women's WorldTour" },
  { date: "26.03", name: "Ronde van Brugge - Tour of Bruges", classification: "1.WWT", gender: "Women", series: "UCI Women's WorldTour" },
  { date: "29.03", name: "In Flanders Fields - In Wevelgem", classification: "1.WWT", gender: "Women", series: "UCI Women's WorldTour" },
  { date: "01.04", name: "Dwars door Vlaanderen / A travers la Flandre", classification: "1.WWT", gender: "Women", series: "UCI Women's WorldTour" },
  { date: "05.04", name: "Ronde van Vlaanderen", classification: "1.WWT", gender: "Women", series: "UCI Women's WorldTour" },
  { date: "12.04", name: "Paris-Roubaix Femmes Hauts-de-France", classification: "1.WWT", gender: "Women", series: "UCI Women's WorldTour" },
  { date: "19.04", name: "Amstel Gold Race Ladies Edition", classification: "1.WWT", gender: "Women", series: "UCI Women's WorldTour" },
  { date: "22.04", name: "La Flèche Wallonne Féminine", classification: "1.WWT", gender: "Women", series: "UCI Women's WorldTour" },
  { date: "26.04", name: "Liège-Bastogne-Liège Femmes", classification: "1.WWT", gender: "Women", series: "UCI Women's WorldTour" },
  { date: "03.05 - 10.05", name: "Vuelta España Femenina by Carrefour.es", classification: "2.WWT", gender: "Women", series: "UCI Women's WorldTour" },
  { date: "15.05 - 17.05", name: "Itzulia Women", classification: "2.WWT", gender: "Women", series: "UCI Women's WorldTour" },
  { date: "21.05 - 24.05", name: "Vuelta a Burgos Feminas", classification: "2.WWT", gender: "Women", series: "UCI Women's WorldTour" },
  { date: "30.05 - 07.06", name: "Giro d'Italia Women", classification: "2.WWT", gender: "Women", series: "UCI Women's WorldTour" },
  { date: "13.06", name: "Copenhagen Sprint", classification: "1.WWT", gender: "Women", series: "UCI Women's WorldTour" },
  { date: "17.06 - 21.06", name: "Tour de Suisse Women", classification: "2.WWT", gender: "Women", series: "UCI Women's WorldTour" },
  { date: "01.08 - 09.08", name: "Tour de France Femmes avec Zwift", classification: "2.WWT", gender: "Women", series: "UCI Women's WorldTour" },
  { date: "19.08 - 23.08", name: "Lloyds Tour of Britain Women", classification: "2.WWT", gender: "Women", series: "UCI Women's WorldTour" },
  { date: "29.08", name: "Classic Lorient Agglomération", classification: "1.WWT", gender: "Women", series: "UCI Women's WorldTour" },
  { date: "04.09 - 06.09", name: "Tour de Romandie Féminin", classification: "2.WWT", gender: "Women", series: "UCI Women's WorldTour" },
  { date: "13.10 - 15.10", name: "Tour of Chongming Island", classification: "2.WWT", gender: "Women", series: "UCI Women's WorldTour" },
  { date: "18.10", name: "Tour of Guangxi Women's WorldTour", classification: "1.WWT", gender: "Women", series: "UCI Women's WorldTour" }
];

export const buildUciManualRaces = (year: number) => {
  const championships = worldChampionships
    .map((race) => mapToRace(race, year))
    .filter((race): race is RaceInput => race !== null);
  const men = worldTourMen
    .map((race) => mapToRace(race, year))
    .filter((race): race is RaceInput => race !== null);
  const women = worldTourWomen
    .map((race) => mapToRace(race, year))
    .filter((race): race is RaceInput => race !== null);

  return { championships, men, women };
};
