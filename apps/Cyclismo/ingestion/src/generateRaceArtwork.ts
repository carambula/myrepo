import fs from "node:fs/promises";
import path from "node:path";
import dotenv from "dotenv";

type BootstrapRace = {
  raceId?: string;
  race_id?: string;
  name?: string;
  locationCity?: string | null;
  location_city?: string | null;
  locationCountry?: string | null;
  location_country?: string | null;
  imageUrl?: string | null;
  image_url?: string | null;
  artworkVariants?: {
    portraitUrl?: string;
    landscapeUrl?: string;
    squareUrl?: string;
    promptTemplate?: string;
    generatedAt?: string;
  };
};

type BootstrapPayload = {
  races?: BootstrapRace[];
};

type ArtworkFormat = "portrait" | "landscape" | "square";

dotenv.config();

const FORMAT_SIZE: Record<ArtworkFormat, string> = {
  portrait: "1024x1536",
  landscape: "1536x1024",
  square: "1024x1024"
};

const FORMAT_FILENAME_SUFFIX: Record<ArtworkFormat, string> = {
  portrait: "portrait",
  landscape: "landscape",
  square: "square"
};

const PROJECT_ROOT = path.resolve(process.cwd(), "..");
const BOOTSTRAP_PATH = path.resolve(PROJECT_ROOT, "Cyclismo", "bootstrap_database.json");
const OUTPUT_DIR = path.resolve(PROJECT_ROOT, "bootstrap_web", "public", "race_artwork");
const OUTPUT_URL_PREFIX = "/race_artwork";

const OPENAI_API_URL = "https://api.openai.com/v1/images/generations";
const OPENAI_MODEL = process.env.OPENAI_IMAGE_MODEL ?? "gpt-image-1";
const RACE_ARTWORK_BASE_URL = (process.env.RACE_ARTWORK_BASE_URL ?? "").trim();

const joinUrl = (baseUrl: string, relativePath: string) =>
  `${baseUrl.replace(/\/+$/, "")}/${relativePath.replace(/^\/+/, "")}`;

const toLocationText = (race: BootstrapRace): string => {
  const city = (race.locationCity ?? race.location_city ?? "").trim();
  const country = (race.locationCountry ?? race.location_country ?? "").trim();
  if (city && country) return `${city}, ${country}`;
  if (country) return country;
  if (city) return city;
  return "the race location";
};

const escapePromptValue = (value: string): string => value.replace(/\s+/g, " ").trim();

const buildPrompt = (raceName: string, locationText: string, format: ArtworkFormat): string => {
  const safeName = escapePromptValue(raceName);
  const safeLocation = escapePromptValue(locationText);
  return `Classic tourism style illustration for ${safeName} in ${safeLocation} featuring a road cycling race with lettering of ${safeName}, make it feel charming and in the flavor of historic cycling posters and art, feature notable architecture and/or national colors in ${format} format with no border.`;
};

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

const fileExists = async (filePath: string): Promise<boolean> => {
  try {
    await fs.access(filePath);
    return true;
  } catch {
    return false;
  }
};

const generateImage = async (apiKey: string, prompt: string, size: string): Promise<Buffer> => {
  const response = await fetch(OPENAI_API_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      model: OPENAI_MODEL,
      prompt,
      size
    })
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`OpenAI image generation failed (${response.status}): ${body}`);
  }

  const json = (await response.json()) as {
    data?: Array<{ b64_json?: string }>;
  };
  const b64 = json.data?.[0]?.b64_json;
  if (!b64) {
    throw new Error("OpenAI image generation returned no image data.");
  }
  return Buffer.from(b64, "base64");
};

const parseArgs = () => {
  const args = new Set(process.argv.slice(2));
  return {
    overwrite: args.has("--overwrite")
  };
};

const run = async () => {
  const { overwrite } = parseArgs();
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) {
    throw new Error("OPENAI_API_KEY is required.");
  }

  const raw = await fs.readFile(BOOTSTRAP_PATH, "utf8");
  const bootstrap = JSON.parse(raw) as BootstrapPayload;
  const races = bootstrap.races ?? [];
  if (!races.length) {
    console.log("No races found in bootstrap_database.json.");
    return;
  }

  await fs.mkdir(OUTPUT_DIR, { recursive: true });

  let generatedCount = 0;
  let skippedCount = 0;
  const generatedAt = new Date().toISOString();

  for (let i = 0; i < races.length; i += 1) {
    const race = races[i];
    const raceId = race.raceId ?? race.race_id;
    const raceName = (race.name ?? "").trim();
    if (!raceId || !raceName) {
      skippedCount += 1;
      continue;
    }

    const locationText = toLocationText(race);
    const variants: Record<ArtworkFormat, string> = {
      portrait: "",
      landscape: "",
      square: ""
    };

    for (const format of Object.keys(FORMAT_SIZE) as ArtworkFormat[]) {
      const filename = `${raceId}_${FORMAT_FILENAME_SUFFIX[format]}.png`;
      const outputPath = path.join(OUTPUT_DIR, filename);
      const urlPath = `${OUTPUT_URL_PREFIX}/${filename}`;

      if (!overwrite && (await fileExists(outputPath))) {
        variants[format] = urlPath;
        skippedCount += 1;
        continue;
      }

      const prompt = buildPrompt(raceName, locationText, format);
      const size = FORMAT_SIZE[format];

      console.log(
        `[${i + 1}/${races.length}] Generating ${format} artwork for "${raceName}" (${locationText})`
      );
      const image = await generateImage(apiKey, prompt, size);
      await fs.writeFile(outputPath, image);
      variants[format] = urlPath;
      generatedCount += 1;

      // Keep request pace moderate for large race sets.
      await sleep(200);
    }

    race.artworkVariants = {
      portraitUrl: variants.portrait || race.artworkVariants?.portraitUrl,
      landscapeUrl: variants.landscape || race.artworkVariants?.landscapeUrl,
      squareUrl: variants.square || race.artworkVariants?.squareUrl,
      promptTemplate:
        'Classic tourism style illustration for [race name] in [location city, country] featuring a road cycling race with lettering of [race name], make it feel charming and in the flavor of historic cycling posters and art, feature notable architecture and/or national colors in [format] format with no border.',
      generatedAt
    };

    // Default app/admin artwork uses landscape.
    const preferredLandscape = variants.landscape || race.artworkVariants?.landscapeUrl;
    if (preferredLandscape && RACE_ARTWORK_BASE_URL) {
      const absolute = joinUrl(RACE_ARTWORK_BASE_URL, preferredLandscape);
      race.imageUrl = absolute;
      race.image_url = absolute;
    }
  }

  await fs.writeFile(BOOTSTRAP_PATH, JSON.stringify(bootstrap, null, 2), "utf8");

  console.log(`Done. Generated: ${generatedCount}, skipped existing: ${skippedCount}`);
  console.log(`Artwork files: ${OUTPUT_DIR}`);
  console.log(`Updated bootstrap: ${BOOTSTRAP_PATH}`);
};

run().catch((error) => {
  console.error("Race artwork generation failed:", error);
  process.exitCode = 1;
});
