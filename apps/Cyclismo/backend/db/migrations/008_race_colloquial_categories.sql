-- Add colloquial race categorization tags used by the app metadata surfaces.
ALTER TABLE races
  ADD COLUMN IF NOT EXISTS colloquial_categories TEXT[] NOT NULL DEFAULT '{}';

CREATE INDEX IF NOT EXISTS races_colloquial_categories_gin_idx
  ON races USING GIN (colloquial_categories);

-- Backfill existing races with stable categories inferred from race names.
UPDATE races
SET colloquial_categories = (
  ARRAY_REMOVE(
    ARRAY[
      CASE
        WHEN lower(name) LIKE '%tour de france%' OR lower(name) LIKE '%giro d''italia%' OR lower(name) LIKE '%vuelta%'
          THEN 'Grand Tours'
        ELSE NULL
      END,
      CASE
        WHEN lower(name) LIKE '%milano-sanremo%'
          OR lower(name) LIKE '%milan-sanremo%'
          OR lower(name) LIKE '%ronde van vlaanderen%'
          OR lower(name) LIKE '%tour of flanders%'
          OR lower(name) LIKE '%paris-roubaix%'
          OR lower(name) LIKE '%liège-bastogne-liège%'
          OR lower(name) LIKE '%liege-bastogne-liege%'
          OR lower(name) LIKE '%il lombardia%'
          THEN 'Monuments'
        ELSE NULL
      END,
      CASE
        WHEN lower(name) LIKE '%omloop%nieuwsblad%'
          OR lower(name) LIKE '%kuurne%brussels%kuurne%'
          OR lower(name) LIKE '%e3 saxo classic%'
          OR lower(name) LIKE '%gent-wevelgem%'
          OR lower(name) LIKE '%in flanders fields%'
          OR lower(name) LIKE '%dwars door vlaanderen%'
          OR lower(name) LIKE '%ronde van vlaanderen%'
          OR lower(name) LIKE '%tour of flanders%'
          OR lower(name) LIKE '%paris-roubaix%'
          THEN 'Cobbled Classics'
        ELSE NULL
      END,
      CASE
        WHEN lower(name) LIKE '%amstel gold race%'
          OR lower(name) LIKE '%flèche wallonne%'
          OR lower(name) LIKE '%fleche wallonne%'
          OR lower(name) LIKE '%liège-bastogne-liège%'
          OR lower(name) LIKE '%liege-bastogne-liege%'
          THEN 'Ardennes Classics'
        ELSE NULL
      END,
      CASE
        WHEN lower(name) LIKE '%strade bianche%'
          OR lower(name) LIKE '%milano-sanremo%'
          OR lower(name) LIKE '%milan-sanremo%'
          THEN 'Italian / Early Classics'
        ELSE NULL
      END,
      CASE
        WHEN lower(name) LIKE '%world championships%' OR lower(name) LIKE '%olympic road race%'
          THEN 'World Championships / Olympics'
        ELSE NULL
      END,
      CASE
        WHEN lower(name) LIKE '%paris-nice%'
          OR lower(name) LIKE '%tirreno-adriatico%'
          OR lower(name) LIKE '%volta ciclista a catalunya%'
          OR lower(name) LIKE '%volta a catalunya%'
          OR lower(name) LIKE '%tour de romandie%'
          OR lower(name) LIKE '%dauphin%'
          OR lower(name) LIKE '%tour auvergne-rhône-alpes%'
          OR lower(name) LIKE '%tour auvergne-rhone-alpes%'
          OR lower(name) LIKE '%tour de suisse%'
          OR lower(name) LIKE '%itzulia%'
          OR lower(name) LIKE '%uae tour%'
          THEN 'Major 1-Week Stage Races'
        ELSE NULL
      END,
      CASE
        WHEN lower(name) LIKE '%san sebastian%'
          OR lower(name) LIKE '%dssk%'
          OR lower(name) LIKE '%bretagne classic%'
          OR lower(name) LIKE '%grand prix cycliste de québec%'
          OR lower(name) LIKE '%grand prix cycliste de quebec%'
          OR lower(name) LIKE '%grand prix cycliste de montréal%'
          OR lower(name) LIKE '%grand prix cycliste de montreal%'
          OR lower(name) LIKE '%binche%chimay%binche%'
          THEN 'Other Major WorldTour Classics'
        ELSE NULL
      END
    ],
    NULL
  )
)
WHERE coalesce(array_length(colloquial_categories, 1), 0) = 0;

