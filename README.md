# Aula-huskeliste

**Få en kort mail hver aften om, hvad dine børn skal huske i morgen – hentet direkte fra Aula.**

Aula-huskeliste læser beskeder, opslag og kalender i Aula og sender dig en overskuelig huskeliste kl. 19.30. Nye arrangementer lægges automatisk i din Google-kalender, og skriver skolen i kontaktbogen, får du besked senest kl. 15.30.

> Et fritidsprojekt af en forælder til andre forældre. Det er ikke lavet af eller godkendt af Aula, KL, STIL eller Netcompany. Se [Vigtigt at vide](#vigtigt-at-vide), før du går i gang.

## Det får du

- **Huskeliste kl. 19.30** med det, der skal huskes i morgen: medbringe cykelhjelm, idrætstøj, sedler der skal afleveres, aflyste timer, arrangementer. Kun når der er noget. Ellers hører du intet.
- **Besked samme aften, som noget annonceres**, og igen aftenen før. Så kan du planlægge og nå at deltage.
- **Automatisk i Google-kalenderen**: bålhygge, forældremøder, motionsdage osv. med påmindelse aftenen før, uden dubletter.
- **Kontaktbog kl. 15.00**: skriver læreren noget nyt, får du beskeden, før du henter.
- **Hensyn til privatlivet**: tråde, som Aula har markeret som følsomme, springes over. Den fælles mail genfortæller aldrig personlige samtaler, og kontaktbogen går kun til dig.

Eksempel på en aftenmail:

```
Husk til i morgen – torsdag d. 24. september

I MORGEN
Emma (2.B):
- Tjek postmappen: seddel om skolefoto kommer med hjem (opslag fra klasselæreren)

KOMMENDE
- Torsdag d. 8. oktober: skolefoto for 2.B (Emma) – lagt i kalenderen
```

## Sådan virker det

```
Aula ──► din egen server (gratis hos Oracle) ──► Claude (planlagte opgaver) ──► mail + Google-kalender
```

1. **Din egen server** kører det åbne projekt [aula-mcp](https://github.com/Casperjuel/aula-mcp), som forbinder til Aula med dit MitID-login. Kun du har adgang til serveren.
2. **Claude** (Cowork) kalder serveren to gange om dagen, læser det nye i Aula og skriver huskelisten.
3. **Gmail og Google Kalender** i Claude sender mailen og opretter begivenhederne.

## Det skal du bruge

| | |
|---|---|
| ⏱️ **Tid** | Ca. 1 time første gang |
| 💻 **En computer** | Windows 10/11 eller Mac med macOS 13 eller nyere – og du skal være på dit **hjemmenetværk** (ikke VPN eller arbejde), når du logger ind med MitID |
| 📱 **MitID-appen** | Den, du bruger til Aula |
| ☁️ **Oracle Cloud-konto** | Gratis ("Always Free"). Kræver et betalingskort til verifikation |
| 🤖 **Claude-abonnement** | Et betalt abonnement med Cowork, planlagte opgaver og custom connectors. Tjek på [claude.ai](https://claude.ai), hvilke abonnementer der har det |
| 📧 **Gmail og Google Kalender** | Forbundet i Claude under Indstillinger → Connectors |

**Pris:** Serveren er gratis inden for Oracles Always Free-grænser. Du betaler kun dit Claude-abonnement.

---

## Trin 1: Opret en gratis server hos Oracle

Detaljeret vejledning med alle klik: [docs/1-oracle-server.md](docs/1-oracle-server.md)

Kort fortalt:

1. Opret en konto på [oracle.com/cloud/free](https://www.oracle.com/cloud/free/). Vælg en hjemmeregion i nærheden, fx *Sweden Central (Stockholm)* eller *Germany Central (Frankfurt)*. Den kan ikke ændres senere.
2. Opret en maskine under **Compute → Instances → Create instance**:
   - **Image:** Canonical Ubuntu 24.04
   - **Shape:** `VM.Standard.E2.1.Micro` (mærket *Always Free*)
   - **SSH keys:** vælg *Generate a key pair for me* og tryk **Save private key**. Gem filen godt. Uden den kan du ikke komme ind på serveren.
3. Sørg for, at maskinen har en **offentlig IP-adresse**, og skriv den ned.
4. Åbn **port 80 og 443** i netværkets *Security List*, så HTTPS virker.

## Trin 2: Installer serveren

Log ind på serveren fra din computer.

**Windows** (PowerShell):
```powershell
ssh -i $HOME\Downloads\ssh-key-XXXX.key ubuntu@DIN-IP
```

**Mac** (Terminal):
```bash
chmod 600 ~/Downloads/ssh-key-XXXX.key
ssh -i ~/Downloads/ssh-key-XXXX.key ubuntu@DIN-IP
```

Svar `yes` første gang. Når du står på serveren, kører du denne ene kommando:

```bash
curl -fsSL https://raw.githubusercontent.com/jesperbagger/aula-huskeliste/main/scripts/install-server.sh | bash
```

Scriptet installerer alt, sætter HTTPS op og laver en hemmelig adgangsnøgle. Til sidst viser det tre oplysninger: **Connector-URL**, **Header-navn** og **Header-værdi**. Gem dem i din password manager. Du kan altid se dem igen med kommandoen `aula-connector` på serveren.

## Trin 3: Log ind med MitID

Aula tillader kun MitID-login fra almindelige hjemmeforbindelser, ikke fra servere. Derfor logger du ind fra din egen computer, og scriptet flytter login'et sikkert over på serveren bagefter.

**Windows** – åbn PowerShell og kør:
```powershell
irm https://raw.githubusercontent.com/jesperbagger/aula-huskeliste/main/scripts/login-windows.ps1 | iex
```

**Mac** – åbn Terminal og kør:
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/jesperbagger/aula-huskeliste/main/scripts/login-mac.sh)"
```

Scriptet spørger om serverens IP-adresse og din SSH-nøgle. Derefter beder det om dit MitID-brugernavn ("MitID username") og viser en QR-kode, som du scanner med MitID-appen. Når det er færdigt, ligger login'et kun på serveren. Kopien på din computer slettes automatisk.

## Trin 4: Tilføj Aula i Claude

1. Gå til [claude.ai](https://claude.ai) → **Indstillinger → Connectors → Add custom connector**.
2. **Navn:** `Aula` · **URL:** din Connector-URL fra trin 2.
3. **Authentication:** *No sign-in*.
4. **Request headers → Add header:** vælg **X-API-Key** i listen og indsæt din Header-værdi. Findes X-API-Key ikke i listen, så vælg **Authorization** og skriv `Bearer ` foran nøglen.

   > Lav ikke et custom header-navn. Det kræver godkendelse fra Anthropic.
5. Tryk **Add**. Du skal nu se en liste med Aula-værktøjer.
6. Sæt værktøjerne til **Always allow** (dropdown-menuen ud for "Other tools"). De kan kun læse, ikke skrive eller sende noget i Aula.

## Trin 5: Opret de planlagte opgaver

1. Åbn filen [templates/opsaetning-prompt.md](templates/opsaetning-prompt.md) og kopiér alt under stregen.
2. Start en ny opgave i **Claude Cowork** og indsæt teksten.
3. Claude finder dine børn i Aula, spørger om mailadresser og kalender og opretter opgaverne.
4. Slå **Automatically approve** til på opgaverne, hvis Claude beder om det. Ellers stopper de ved første kørsel.
5. Sig ja til en testkørsel, og tjek din mail.

Færdig! 🎉

---

## Vedligeholdelse

| Situation | Det gør du |
|---|---|
| Du får mailen **"Aula-automation: kræver handling"** | Dit Aula-login er udløbet. Kør login-scriptet fra trin 3 igen hjemmefra. |
| Du vil se, om alt kører | Log ind på serveren og skriv `aula-status` |
| Du har glemt connector-oplysningerne | Skriv `aula-connector` på serveren |
| Opdatering til ny version | Kør installationskommandoen fra trin 2 igen. Dine indstillinger bevares. |

**Undgå at Oracle lukker serveren.** Oracle kan tage gratis maskiner tilbage, hvis de bruger meget lidt CPU og netværk i 7 dage, og det gør denne. Mange brugere undgår det ved at opgradere kontoen til *Pay As You Go*. Always Free-ressourcer koster stadig 0 kr., men Oracle garanterer det ikke. Opret også en **budget-alarm** (fx 1 USD) under *Billing → Budgets*, så du opdager det med det samme, hvis noget ved en fejl begynder at koste penge.

## Fejlsøgning

Se [docs/fejlsoegning.md](docs/fejlsoegning.md). Den dækker de fejl, man typisk møder undervejs: Oracle-kapacitet, manglende offentlig IP, SSH-timeout, "bot protection" ved login, certifikatfejl, connector-fejl og opgaver der stopper.

## Vigtigt at vide

- **Uofficielt.** aula-mcp bruger Aulas interne API, ikke et officielt API. Aula kan ændre det når som helst, så løsningen holder op med at virke, indtil aula-mcp bliver opdateret.
- **Dit ansvar.** Du kører din egen server med dit eget login. Ingen andre, heller ikke udvikleren af dette projekt, har adgang til dine data.
- **Data sendes til Claude.** Når opgaverne kører, læser Claude (Anthropic) indholdet af beskeder og opslag for at lave huskelisten. Det er dit valg, om du er tryg ved det. Læs [SIKKERHED.md](SIKKERHED.md).
- **Ingen garanti.** Projektet leveres, som det er. Tjek altid Aula selv ved vigtige ting.

## Tak til

- [Casper Juel](https://github.com/Casperjuel) for [aula-mcp](https://github.com/Casperjuel/aula-mcp) (MIT), som gør det hele muligt.
- [scaarup/aula](https://github.com/scaarup/aula), som aula-mcp bygger videre på.
- [Alexander Høier](https://github.com/A-Hoier) for idéen og inspirationen fra [Aula-AI.d](https://github.com/A-Hoier/Aula-AI.d).

## Licens

MIT © 2026 Jesper Bagger. Se [LICENSE](LICENSE) og [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

---

<details>
<summary>For vedligeholdere: sådan udgives en ny version</summary>

Programfilerne bygges automatisk fra kildekoden i aula-mcp af en GitHub Action:

1. Gå til **Actions → Byg og udgiv → Run workflow**.
2. Angiv versionsnummer (fx `v1.1.0`) og hvilken aula-mcp commit eller tag der skal bygges fra.
3. Når workflowet er færdigt, ligger filerne under **Releases**, og installations- og login-scripts bruger dem automatisk.

Vejledningssiden (`docs/index.html`) genereres ud fra `docs/_side.html` og opsætningsprompten. Kør `python3 scripts/byg-vejledning.py` efter ændringer i en af dem. Siden vises via GitHub Pages (Settings → Pages → Deploy from a branch → `main` / `docs`).

</details>
