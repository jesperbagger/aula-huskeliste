# Trin 1: Opret en gratis server hos Oracle

Oracle Cloud har et gratis niveau ("Always Free"), hvor en lille server koster 0 kr. Den er rigeligt til Aula-huskeliste. Oracles konsol ændrer udseende en gang imellem, så knapperne kan hedde lidt noget andet, end der står her.

## 1. Opret en konto

1. Gå til [oracle.com/cloud/free](https://www.oracle.com/cloud/free/) og tryk **Start for free**.
2. Udfyld dine oplysninger, og vælg **Denmark** som land.
3. **Home Region**: Vælg en region tæt på, fx *Sweden Central (Stockholm)* eller *Germany Central (Frankfurt)*. Den kan ikke ændres senere.
4. Indtast et betalingskort. Det bruges kun til at bekræfte, at du er en rigtig person. Der kan komme en midlertidig reservation på kortet.
5. Vent på mailen om, at kontoen er klar. Det kan tage et par minutter.

## 2. Opret maskinen

1. Log ind på [cloud.oracle.com](https://cloud.oracle.com).
2. Åbn menuen (☰) → **Compute** → **Instances** → **Create instance**.
3. **Name:** `aula`

### Image and shape

1. Tryk **Edit** ud for *Image and shape*.
2. **Image:** Tryk **Change image** → **Ubuntu** → vælg **Canonical Ubuntu 24.04** → **Select image**.
3. **Shape:** Tryk **Change shape** → **Virtual machine** → **Specialty and previous generation** → vælg **VM.Standard.E2.1.Micro** (mærket *Always free-eligible*) → **Select shape**.

> 💡 Du kan også vælge **Ampere A1.Flex**, hvis den er ledig, da den er større og også gratis. Den er dog ofte udsolgt ("out of capacity"), og scriptet virker med begge.

### Security

Lad standardindstillingerne stå.

### Networking

1. Vælg **Create new virtual cloud network** og **Create new public subnet**.
2. Sørg for, at **Automatically assign public IPv4 address** er slået til.

> Er feltet gråt og kan ikke vælges? Så fortsæt bare. Du tildeler IP-adressen bagefter (se afsnit 3).

### Add SSH keys

1. Vælg **Generate a key pair for me**.
2. Tryk **Save private key**. Filen hedder noget i stil med `ssh-key-2026-01-01.key` og havner i mappen *Overførsler/Downloads*.

> ⚠️ **Gem filen godt**, fx også i din password manager. Uden den kan du ikke komme ind på serveren, og Oracle kan ikke give dig en ny.

### Boot volume

Lad standardindstillingerne stå.

Tryk **Create**. Efter et par minutter står maskinen som **Running**.

## 3. Find (eller tildel) den offentlige IP-adresse

Åbn maskinen. Under **Instance access** eller **Primary VNIC** står **Public IPv4 address**. Skriv den ned, fx `203.0.113.10`.

**Står der ingen offentlig IP-adresse?**

1. Gå til fanen **Networking** (eller **Attached VNICs**) på maskinen og klik på VNIC'en.
2. Vælg **IPv4 Addresses**. Klik på **⋮** ud for den private adresse → **Edit**.
3. Under **Public IP type** vælger du **Ephemeral public IP** → **Update**.

## 4. Åbn port 80 og 443

Serveren skal kunne nås via HTTPS. Port 22 (SSH) er åben i forvejen.

1. På maskinens side: klik på **Subnet**-linket (under *Primary VNIC*).
2. Gå til **Security** eller **Security Lists** → klik på **Default Security List for …**.
3. Tryk **Add Ingress Rules** og udfyld:
   - **Source CIDR:** `0.0.0.0/0`
   - **IP Protocol:** TCP
   - **Destination Port Range:** `80,443`
4. Tryk **Add Ingress Rules**.

## 5. Anbefalet: undgå at serveren bliver lukket

Oracle kan tage gratis maskiner tilbage, hvis de i 7 dage bruger under 20 % CPU og netværk, og det gør denne server. Mange brugere undgår det ved at opgradere kontoen til *Pay As You Go*. Oracle skriver, at Always Free-ressourcer stadig er gratis efter opgradering, men lover ikke udtrykkeligt, at maskinen så aldrig bliver taget tilbage.

Opgraderer du, så lav også en **budget-alarm**:

1. Menuen (☰) → **Billing & Cost Management** → **Budgets** → **Create Budget**.
2. Beløb: fx **1 USD** pr. måned, med mail-advarsel ved 100 %.

Så får du besked med det samme, hvis noget ved en fejl begynder at koste penge. Opret aldrig nye ressourcer, der ikke er mærket *Always Free*.

---

➡️ Næste: [Trin 2 – Installer serveren](../README.md#trin-2-installer-serveren)
