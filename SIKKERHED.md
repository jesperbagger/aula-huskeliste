# Privatliv og sikkerhed

Aula indeholder oplysninger om dine børn. Her kan du se, hvor data ligger, hvem der kan se dem, og hvordan de er beskyttet, så du kan tage stilling til, om du er tryg ved løsningen.

## Hvor ligger hvad?

| Data | Hvor | Hvem har adgang |
|---|---|---|
| Dit Aula-login (tokens) | Krypteret på **din egen server** i `/var/lib/aula-mcp` | Kun den, der har din SSH-nøgle |
| Beskeder, opslag, kalender | Hentes fra Aula, når opgaverne kører. Gemmes ikke på serveren. PDF-vedhæftninger, der bliver læst, ligger kun midlertidigt i tjenestens private `/tmp`, som tømmes ved genstart | Claude (Anthropic) læser dem for at lave huskelisten |
| Huskelisten | Din Gmail og de modtagere, du har valgt | Dig og dine modtagere |
| Begivenheder | Den Google-kalender, du har valgt | Alle med adgang til kalenderen |

Udvikleren af dette projekt har **ingen** adgang til dine data eller din server.

## Hvordan er serveren beskyttet?

- **aula-mcp lytter kun internt** på serveren (127.0.0.1) og kan ikke nås direkte udefra.
- **Caddy** står foran med HTTPS. Kun kald, der både bruger den hemmelige sti (48 tegn) og den hemmelige nøgle (64 tegn), slipper igennem. Alle andre får "404 Not Found".
- **Kun læseadgang.** aula-mcp kører uden skrivefunktioner, så Claude kan hverken sende beskeder, melde børn syge eller ændre noget i Aula.
- **Egen systembruger.** aula-mcp kører som brugeren `aula` og kan kun skrive i sin egen mappe.
- **Login fra din egen computer.** MitID-login sker hjemmefra, og login-filerne flyttes krypteret via SSH. Kopien på din computer slettes bagefter.

Vær opmærksom på, at login-filen er krypteret med en nøgle, der ligger på samme server. Den reelle beskyttelse er derfor, at ingen andre kan logge ind på serveren. Pas godt på din SSH-nøgle.

## Hvad ser Claude?

Når de planlagte opgaver kører, læser Claude indholdet af nye beskeder, opslag og kalenderen for at finde huskepunkter. Anthropics vilkår og privatlivspolitik gælder for de data. Opgaverne er skrevet, så:

- **tråde, som Aula har markeret som følsomme, aldrig åbnes,**
- **den fælles mail aldrig genfortæller personlige samtaler** (fx om trivsel eller episoder) og aldrig nævner andre børn eller forældre ved navn,
- **kontaktbogen kun sendes til dig** og aldrig til andre modtagere, og andre børns navne erstattes med "en klassekammerat",
- **push-notifikationer er neutrale**, så indhold ikke står på låseskærmen.

## Gode råd

- Gem SSH-nøglen og connector-oplysningerne i en password manager, og del dem aldrig.
- **Er connector-URL'en eller nøglen blevet delt ved en fejl?** Lav nye på serveren:
  ```bash
  sudo rm /etc/aula-huskeliste/connector.env
  curl -fsSL https://raw.githubusercontent.com/jesperbagger/aula-huskeliste/main/scripts/install-server.sh | bash
  ```
  Opdatér derefter connectoren i Claude med den nye URL og nøgle.

## Sådan fjerner du det hele

1. Slet de planlagte opgaver og Aula-connectoren i Claude.
2. Slet login'et på serveren: `sudo systemctl disable --now aula-mcp && sudo rm -rf /var/lib/aula-mcp`
3. Slet maskinen i Oracle-konsollen (*Instances* → *Terminate*, og vælg at slette boot volume).

## Fandt du et sikkerhedsproblem?

Opret en fejlrapport (issue) på GitHub, men skriv **aldrig** URL'er, nøgler eller personoplysninger i den.
