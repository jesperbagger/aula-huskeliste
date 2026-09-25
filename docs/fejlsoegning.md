# Fejlsøgning

De fejl, man typisk støder på, og hvordan de løses. Mange af dem er mødt i praksis under opsætningen af det første setup.

## Oracle

**"Out of capacity" eller "This shape is not available in the current availability domain"**
Oracles gratis Ampere-maskiner (A1.Flex) er ofte udsolgt. Vælg `VM.Standard.E2.1.Micro` i stedet. Den er også gratis og er rigelig.

**"Automatically assign public IPv4 address" er gråt og kan ikke vælges**
Opret maskinen alligevel, og tildel IP-adressen bagefter. Se [trin 1, afsnit 3](1-oracle-server.md#3-find-eller-tildel-den-offentlige-ip-adresse).

**Advarsel om "No SSH access" ved oprettelse**
Du har ikke gemt SSH-nøglen. Gå tilbage til *Add SSH keys* → *Generate a key pair for me* → **Save private key**.

**Serveren er pludselig stoppet**
Oracle kan stoppe gratis maskiner, der står ubrugte hen. Start den igen i konsollen (*Instances* → *Start*). Se [trin 1, afsnit 5](1-oracle-server.md#5-anbefalet-undgå-at-serveren-bliver-lukket) om, hvordan du undgår det.

## SSH (forbindelse til serveren)

**"Connection timed out"**
- Tjek, at du bruger den **offentlige** IP-adresse, og at maskinen står som *Running*.
- Tjek, at port 22 er åben i *Security List*. Det er den som standard.

**"Identity file … not accessible: No such file or directory"**
Stien til nøglen er forkert. Skriv den fulde sti, eller gå først til mappen med `cd $HOME\Downloads` (Windows) eller `cd ~/Downloads` (Mac). Tjek filnavnet med `dir *.key` (Windows) eller `ls *.key` (Mac).

**"Permission denied (publickey)"**
Forkert nøglefil eller forkert brugernavn. Brugernavnet på Oracles Ubuntu er `ubuntu`.

**"UNPROTECTED PRIVATE KEY FILE"**
- Mac: `chmod 600 ~/Downloads/ssh-key-XXXX.key`
- Windows (PowerShell): `icacls "$HOME\Downloads\ssh-key-XXXX.key" /inheritance:r /grant:r "$($env:USERNAME):R"`

## Installationsscriptet

**"Kunne ikke hente … Er der udgivet en release?"**
Projektets programfiler er ikke udgivet endnu, eller GitHub er nede. Prøv igen senere.

**"Serveren kunne ikke nås via https://… endnu"**
Næsten altid fordi port 80 og 443 ikke er åbnet i Oracles *Security List*. Se [trin 1, afsnit 4](1-oracle-server.md#4-åbn-port-80-og-443), og kør scriptet igen.

**"aula-mcp startede ikke"**
Se loggen med `sudo journalctl -u aula-mcp -n 50`, og opret gerne en fejlrapport (issue) på GitHub med loggen. Fjern eventuelle hemmeligheder først.

## MitID-login (trin 3)

**"Login blocked by STIL's bot protection"**
Du er ikke på et almindeligt hjemmenetværk. Slå VPN fra, brug ikke arbejdets netværk, og prøv hjemmefra.

**"irm: The term 'irm' is not recognized"**
Du bruger *Kommandoprompt* i stedet for *PowerShell*. Åbn PowerShell fra startmenuen.

**"ssh: The term 'ssh' is not recognized"** (Windows)
Installer *OpenSSH-klient* under **Indstillinger → System → Valgfrie funktioner**.

**"Too many authentication failures"**
Din computer prøver for mange SSH-nøgler. Login-scriptet klarer det selv. Logger du ind manuelt, så tilføj `-o IdentitiesOnly=yes` til ssh-kommandoen.

**Mac: "Bad CPU type" eller programmet lukker med det samme**
Login-programmet kræver macOS 13 (Ventura) eller nyere. Brug en anden computer, eller opdater macOS.

**"Kontrolsummen passer ikke"**
Downloadet blev afbrudt. Kør scriptet igen.

**"Kunne ikke forbinde til serveren, eller installationsscriptet er ikke kørt endnu"**
Tjek IP-adressen og nøglen (se SSH-afsnittet ovenfor), og at trin 2 er gennemført.

## Server og Aula

**"Failed to decrypt token file. Wrong AULA_MCP_KEY, or the key file is missing"**
Login-filerne passer ikke sammen. Kør login-scriptet (trin 3) igen. Det flytter altid begge filer korrekt.

**Mailen "Aula-automation: kræver handling"**
Dit Aula-login er udløbet og kan ikke fornyes automatisk. Kør login-scriptet (trin 3) igen hjemmefra.

**Er alt i orden?**
Log ind på serveren og skriv `aula-status`.

## Claude

**"Custom header names need Anthropic approval"**
Vælg et af standardnavnene i listen: **X-API-Key** (værdi: nøglen) eller **Authorization** (værdi: `Bearer ` + nøglen). Skriv ikke dit eget header-navn.

**Connectoren viser fejl eller ingen værktøjer**
- Tjek, at URL'en slutter på `/mcp`, og at nøglen er kopieret præcist. Skriv `aula-connector` på serveren for at se dem igen.
- Tjek med `aula-status`, at begge tjenester kører.

**"MCP tool call requires approval"**
Sæt Aula-værktøjerne til **Always allow** under connectorens indstillinger.

**Den planlagte opgave gør ingenting eller stopper**
- Slå **Automatically approve** til i opgavens indstillinger.
- Er opgaven oprettet, *før* Aula-connectoren blev tilføjet, har den ikke adgang til Aula. Opret den igen med opsætningsprompten i en ny opgave, og slet den gamle.

**Partneren modtager ikke mailen**
Kig i spam-mappen, og markér mailen som "Ikke spam".

**Mailen kommer en time forkert**
Det burde ikke ske. Opgaverne kører to gange i døgnet (UTC) og tjekker selv dansk tid. Tjek, at cron-udtrykkene er `30 17,18 * * *` og `0 13,14 * * *`.
