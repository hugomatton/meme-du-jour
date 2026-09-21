-- Local development seed. Runs on `supabase db reset`, never in production.
--
-- The image files themselves are not versioned in this repository: upload them
-- to the public `templates` bucket under the same paths (Supabase dashboard >
-- Storage > templates) or the renderer will show an empty frame.
--
-- Only self-made, Unsplash, Pexels, public domain or CC0 images may be added to
-- the catalogue; `source` and `license` must always be filled in.

insert into public.templates (image_path, width, height, source, license, text_zones) values
(
  'dev/classic-two-lines.jpg', 1200, 1200, 'own', 'own',
  '[
    {"id":"top","x":5,"y":4,"w":90,"h":18,"max_chars":80,"font_size":8,"align":"center",
     "color":"#FFFFFF","stroke":"#000000","uppercase":true,"placeholder":"Texte du haut"},
    {"id":"bottom","x":5,"y":78,"w":90,"h":18,"max_chars":80,"font_size":8,"align":"center",
     "color":"#FFFFFF","stroke":"#000000","uppercase":true,"placeholder":"Texte du bas"}
  ]'::jsonb
),
(
  'dev/split-panels.jpg', 1200, 1200, 'own', 'own',
  '[
    {"id":"left","x":4,"y":35,"w":44,"h":30,"max_chars":60,"font_size":7,"align":"center",
     "color":"#111111","stroke":"#FFFFFF","uppercase":false,"placeholder":"Panneau de gauche"},
    {"id":"right","x":52,"y":35,"w":44,"h":30,"max_chars":60,"font_size":7,"align":"center",
     "color":"#111111","stroke":"#FFFFFF","uppercase":false,"placeholder":"Panneau de droite"}
  ]'::jsonb
),
(
  'dev/single-caption.jpg', 1200, 900, 'own', 'own',
  '[
    {"id":"caption","x":6,"y":70,"w":88,"h":24,"max_chars":120,"font_size":7,"align":"center",
     "color":"#FFFFFF","stroke":"#000000","uppercase":true,"placeholder":"Ta légende"}
  ]'::jsonb
);
