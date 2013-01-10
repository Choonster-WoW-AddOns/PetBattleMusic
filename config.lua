local addon, ns = ...

---------------------
-- START OF CONFIG --
---------------------

-- The sound channel to play custom music on. This can be "SFX", "Music", "Ambience" or "Master"
ns.MUSIC_CHANNEL = "SFX"

-- If true, WoW's music will be muted when in pet battles. This only works if you're using the "SFX", "Ambience" or "Master" channels ("Music" replaces the game music).
-- If false, WoW's music will be unaffected.
ns.MUTE_MUSIC = true

-- The number of times the AddOn will try to select a random track different to the previous one before using the last selection anyway
ns.MAX_TRIES = 10

-- The number of seconds to wait between a track ending and a new one being played.
ns.DELAY = 0.5

-- If true, battles against wild pets will use separate music. If false, they will use the general music.
ns.USE_WILD_MUSIC = true

-- If true, battles against trainers will use separate music. If false, they will use the general music.
ns.USE_TRAINER_MUSIC = true

-- If true, battles against other players will use separate music. If false, they will use the same music as trainer battles (controlled by the USE_TRAINER_MUSIC option above).
ns.USE_PLAYER_MUSIC = true

-- If true, special music will be played when you win a battle. If false, no music will play.
ns.USE_VICTORY_MUSIC = true

-- If true, special music will be played when you lose a battle. If false, no music will play. Draws count as defeats.
ns.USE_DEFEAT_MUSIC = true

-------------------
-- END OF CONFIG --
-------------------