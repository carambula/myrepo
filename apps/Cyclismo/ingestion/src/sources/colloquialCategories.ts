const CATEGORY_PRIORITY = [
  "Grand Tours",
  "Monuments",
  "Cobbled Classics",
  "Ardennes Classics",
  "Italian / Early Classics",
  "World Championships / Olympics",
  "Major 1-Week Stage Races",
  "Other Major WorldTour Classics"
] as const;

type CategoryName = (typeof CATEGORY_PRIORITY)[number];

type CategoryRule = {
  category: CategoryName;
  pattern: RegExp;
};

const CATEGORY_RULES: CategoryRule[] = [
  { category: "Grand Tours", pattern: /\btour de france\b/ },
  { category: "Grand Tours", pattern: /\bgiro d ?italia\b/ },
  { category: "Grand Tours", pattern: /\bvuelta(?: [a-z]+){0,3} espana\b/ },

  { category: "Monuments", pattern: /\b(milan|milano)[ -]?san ?remo\b/ },
  { category: "Monuments", pattern: /\b(tour of flanders|ronde van vlaanderen)\b/ },
  { category: "Monuments", pattern: /\bparis[ -]?roubaix\b/ },
  { category: "Monuments", pattern: /\b(liege|li[eè]ge)[ -]?bastogne[ -]?(liege|li[eè]ge)\b/ },
  { category: "Monuments", pattern: /\b(il lombardia|tour of lombardy)\b/ },

  { category: "Cobbled Classics", pattern: /\bomloop( het)? nieuwsblad\b/ },
  { category: "Cobbled Classics", pattern: /\bkuurne[ -]?brussels[ -]?kuurne\b/ },
  { category: "Cobbled Classics", pattern: /\be3( saxo classic)?\b/ },
  { category: "Cobbled Classics", pattern: /\bgent[ -]?wevelgem\b/ },
  { category: "Cobbled Classics", pattern: /\bdwars door vlaanderen\b/ },
  { category: "Cobbled Classics", pattern: /\b(tour of flanders|ronde van vlaanderen)\b/ },
  { category: "Cobbled Classics", pattern: /\bparis[ -]?roubaix\b/ },
  { category: "Cobbled Classics", pattern: /\bin flanders fields\b.*\bwevelgem\b/ },

  { category: "Ardennes Classics", pattern: /\bamstel gold race\b/ },
  { category: "Ardennes Classics", pattern: /\bla fleche wallonne\b/ },
  { category: "Ardennes Classics", pattern: /\b(liege|li[eè]ge)[ -]?bastogne[ -]?(liege|li[eè]ge)\b/ },

  { category: "Italian / Early Classics", pattern: /\bstrade bianche\b/ },
  { category: "Italian / Early Classics", pattern: /\b(milan|milano)[ -]?san ?remo\b/ },

  { category: "World Championships / Olympics", pattern: /\bworld championships?\b/ },
  { category: "World Championships / Olympics", pattern: /\bolympic road race\b/ },

  { category: "Major 1-Week Stage Races", pattern: /\bparis[ -]?nice\b/ },
  { category: "Major 1-Week Stage Races", pattern: /\btirreno[ -]?adriatico\b/ },
  { category: "Major 1-Week Stage Races", pattern: /\bvolta (ciclista a )?catalunya\b/ },
  { category: "Major 1-Week Stage Races", pattern: /\btour de romandie\b/ },
  { category: "Major 1-Week Stage Races", pattern: /\b(criterium du dauphine|dauphine|tour auvergne rhone alpes)\b/ },
  { category: "Major 1-Week Stage Races", pattern: /\btour de suisse\b/ },
  { category: "Major 1-Week Stage Races", pattern: /\bitzulia( basque country)?\b/ },
  { category: "Major 1-Week Stage Races", pattern: /\buae tour\b/ },

  { category: "Other Major WorldTour Classics", pattern: /\b(clasica|cl[aá]sica).*(san sebastian|san sebasti[áa]n)\b/ },
  { category: "Other Major WorldTour Classics", pattern: /\b(donostia san sebastian klasikoa|dssk)\b/ },
  { category: "Other Major WorldTour Classics", pattern: /\bbretagne classic\b/ },
  { category: "Other Major WorldTour Classics", pattern: /\b(grand prix cycliste de )?quebec\b/ },
  { category: "Other Major WorldTour Classics", pattern: /\b(grand prix cycliste de )?montreal\b/ },
  { category: "Other Major WorldTour Classics", pattern: /\bbinche[ -]?chimay[ -]?binche\b/ }
];

const normalizeName = (value: string) =>
  value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();

export const inferColloquialCategories = (raceName: string): string[] => {
  const normalized = normalizeName(raceName);
  if (!normalized) {
    return [];
  }
  const matches = new Set<CategoryName>();
  for (const rule of CATEGORY_RULES) {
    if (rule.pattern.test(normalized)) {
      matches.add(rule.category);
    }
  }
  return CATEGORY_PRIORITY.filter((category) => matches.has(category));
};

