import type { AthleteInput, RaceInput, TeamInput, RaceParticipantInput } from "../normalize.js";

export const sampleRaces: RaceInput[] = [
  {
    name: "Tour de France",
    series: "WorldTour",
    classification: "UCI WorldTour",
    discipline: "Road",
    raceType: "Stage race",
    startDate: "2026-07-04",
    endDate: "2026-07-26",
    locationCountry: "France",
    locationCity: "Lille",
    organizer: "ASO",
    officialWebsite: "https://www.letour.fr",
    genderDivision: "Men"
  },
  {
    name: "Paris-Roubaix Femmes",
    series: "WorldTour",
    classification: "UCI WorldTour",
    discipline: "Road",
    raceType: "One-day",
    startDate: "2026-04-11",
    endDate: "2026-04-11",
    locationCountry: "France",
    locationCity: "Roubaix",
    organizer: "ASO",
    officialWebsite: "https://www.paris-roubaix-femmes.fr",
    genderDivision: "Women"
  }
];

export const sampleTeams: TeamInput[] = [
  {
    name: "Team Visma | Lease a Bike",
    uciCode: "TVL",
    discipline: "Road",
    region: "Europe",
    website: "https://www.teamvismaleaseabike.com",
    socialHandles: {
      instagram: "https://www.instagram.com/teamvismaleaseabike/"
    }
  },
  {
    name: "SD Worx - Protime",
    uciCode: "SDW",
    discipline: "Road",
    region: "Europe",
    website: "https://www.sdworx.com",
    socialHandles: {
      instagram: "https://www.instagram.com/teamsdworx/"
    }
  }
];

export const sampleAthletes: AthleteInput[] = [
  {
    fullName: "Jonas Vingegaard",
    teamName: "Team Visma | Lease a Bike",
    nationality: "Denmark",
    discipline: "Road",
    dob: "1996-12-10"
  },
  {
    fullName: "Lotte Kopecky",
    teamName: "SD Worx - Protime",
    nationality: "Belgium",
    discipline: "Road",
    dob: "1995-11-10"
  }
];

export const sampleParticipants: RaceParticipantInput[] = [
  {
    raceName: "Tour de France",
    raceStartDate: "2026-07-04",
    athleteName: "Jonas Vingegaard",
    teamName: "Team Visma | Lease a Bike",
    role: "Leader"
  },
  {
    raceName: "Paris-Roubaix Femmes",
    raceStartDate: "2026-04-11",
    athleteName: "Lotte Kopecky",
    teamName: "SD Worx - Protime",
    role: "Leader"
  }
];
