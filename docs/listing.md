# Roblox experience listing

Text to paste in the Creator Hub (Configure Experience > Basic Settings).

## Title

Capture The Flag: Neon Arena

## Description

Grab the enemy flag and run it home before time runs out!

A colorful laser tag capture the flag game for everyone. Two teams, one glowing arena, matches of about 5 minutes. Friendly bots keep every match full, so you can always jump in and play, even when you are the only one online.

- Meet in the lobby, watch the 3, 2, 1 countdown, then race to your base
- Pick a class: Striker, Scout or Guardian, each with its own ability
- Collect blasters: Pulse SMG, Scatter Cannon, Rail Rifle and more
- Level up to unlock new classes, earn coins and spend them on weapons and trails
- Chain tags for streak bonuses and win the MVP spot
- Overtime sudden death when the score is tied
- Quick tutorial for new players, plus settings for reduced flashes, large text and team letters
- Works on phone, tablet, console and computer

Controls: click or tap to shoot, Q for your ability, C for classes, B for the shop, G for settings.


## Settings to check

- Max players: 12 to 16 (the arena is sized for 6v6 to 8v8; bots fill free slots up to the bot target in `Config.lua`)
- Enable "Studio Access to API Services" so progress is saved
- Create the VIP game pass and the developer products, then paste their ids in `src/shared/Monetization.lua`
- Add thumbnails showing a flag run, a lobby countdown and the weapon shop

## Content maturity questionnaire (suggested answers)

- Violence: only cartoon laser tag. Players are tagged by light beams and respawn at once. No blood, no gore, no realistic weapons.
- Blood and gore: none
- Fear: none
- Crude humor, alcohol, drugs, tobacco: none
- Romantic content: none
- Gambling and random paid rewards: none. Every item is bought directly at a shown price, there are no loot boxes or random drops.
- Social features: standard Roblox chat only, no custom chat or user generated content
- Paid items: a VIP game pass and Robux developer products (coin packs and weapons)
- Computer players: bots with made-up names fill matches; they never earn rewards or buy anything

Expected result: suitable for all ages. Confirm the final rating in the Creator Hub questionnaire.

## Short description (ready to paste)

The current text is kept in docs/description.txt, sent by tools/update-listing.sh when the API key allows it.

## Creator Hub form (Configure Experience > Basic Settings)

- Name: Capture The Flag: Neon Arena (28 characters, the limit is 50)
- Description: paste docs/description.txt (765 characters, the limit is 1000)
- Genre: Shooter, sub-genre Team Shooter if offered
- Audience: Public once the content maturity questionnaire is completed (Limited means 16+ only)
- Exclude from recommendations: leave off
- Enable Studio access to API Services: ON (needed to save player progress)
- Meshes / images API: leave off

## If the name or description is rejected

Roblox does not say which one. Common causes: a social media account name in the description (use the Social Links section of the experience page for the YouTube channel instead), words the filter dislikes, or the name and description submitted together. Save the name alone first, then the description, to see which one is refused.
